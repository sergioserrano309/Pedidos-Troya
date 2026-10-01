-- =====================================================================
-- 058_ocultar_pedidos_anteriores.sql
-- Oculta de la plataforma TODO pedido con fecha anterior al corte
-- (hoy: 2026-08-01) y todos sus registros: movimientos de cada proceso,
-- devoluciones, destino, despachos, auditoria y eliminaciones.
--
-- NO BORRA NI EDITA NINGUN DATO. Solo agrega filtros de LECTURA (RLS
-- "restrictive") para los usuarios autenticados de la plataforma:
--   - p_pedidosh, production_movements y las demas tablas NO se tocan.
--   - El script de sincronizacion (service_role) ignora RLS: sigue viendo
--     y escribiendo todo igual que antes.
--   - Las funciones security definer (crear_despacho, triggers, etc.)
--     tambien ignoran RLS: no cambia su comportamiento.
--
-- CRITERIO
--   Un pedido esta OCULTO si la fecha MAS RECIENTE de sus filas en
--   p_pedidosh ("FechaP") es anterior al corte. Pedidos sin fecha
--   (FechaP vacia) quedan VISIBLES.
--   La fecha de corte vive en UN solo lugar: fn_fecha_corte_visible().
--
-- DESPACHOS que mezclan pedidos viejos y nuevos: el despacho sigue
-- visible mostrando solo los pedidos nuevos; desaparece solo si TODOS
-- sus pedidos estan ocultos. (Kilos/bultos del despacho siguen siendo
-- los del despacho completo.)
--
-- REVERSA: 058_revertir_ocultar_pedidos.sql (quita todo lo de aqui).
--
-- SEGURIDAD DEL SCRIPT: va dentro de una transaccion y termina forzando
-- la evaluacion de la vista nueva; si algo falla (por ejemplo, si
-- "FechaP" no fuera convertible a fecha), TODO se deshace y no queda nada
-- a medias.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Fecha de corte (unico lugar donde se cambia).
-- ---------------------------------------------------------------------
-- "FechaP" es la fecha de Access guardada como timestamptz a MEDIANOCHE
-- UTC (1/08/2026 -> 2026-08-01T00:00:00Z). Por eso el corte es medianoche
-- UTC: los pedidos del 1/08 quedan visibles y los del 31/07 ocultos.
-- Para cambiarlo, edite solo la fecha de abajo (y deje el +00).
create or replace function public.fn_fecha_corte_visible()
returns timestamptz
language sql
immutable
as $$
  select timestamptz '2026-08-01 00:00:00+00';
$$;

-- ---------------------------------------------------------------------
-- 2. Pedidos ocultos. security_invoker = false A PROPOSITO: la vista se
--    ejecuta con los permisos de su dueno, o sea sin los filtros de RLS.
--    Si no, al ocultar p_pedidosh la vista dejaria de ver los pedidos
--    viejos y entonces ya no los reconoceria como ocultos.
--    Solo expone numeros de pedido.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedidos_ocultos
with (security_invoker = false) as
select "PedidoNo"::text as order_number
from public.p_pedidosh
group by "PedidoNo"::text
having max("FechaP") < public.fn_fecha_corte_visible();

revoke all on public.vw_pedidos_ocultos from public, anon;
grant select on public.vw_pedidos_ocultos to authenticated;

comment on view public.vw_pedidos_ocultos is
  'Pedidos que la plataforma NO muestra (058): fecha mas reciente anterior a fn_fecha_corte_visible(). Sin fecha = visible.';

-- ---------------------------------------------------------------------
-- 3. Funciones auxiliares (security definer: leen despacho_ordenes sin
--    pasar por el filtro que ellas mismas ayudan a aplicar).
-- ---------------------------------------------------------------------
-- Un despacho esta oculto si tiene pedidos y TODOS estan ocultos.
create or replace function public.fn_despacho_oculto(p_despacho_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.despacho_ordenes o where o.despacho_id = p_despacho_id)
     and not exists (
       select 1 from public.despacho_ordenes o
        where o.despacho_id = p_despacho_id
          and o.order_number::text not in (select order_number from public.vw_pedidos_ocultos)
     );
$$;

-- Lo mismo para el snapshot guardado al eliminar un despacho (log_eliminaciones).
create or replace function public.fn_snapshot_despacho_oculto(p_snapshot jsonb)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_array_length(coalesce(p_snapshot -> 'ordenes', '[]'::jsonb)) > 0
     and not exists (
       select 1
         from jsonb_array_elements(p_snapshot -> 'ordenes') e
        where (e ->> 'order_number') is distinct from null
          and (e ->> 'order_number') not in (select order_number from public.vw_pedidos_ocultos)
     );
$$;

revoke all on function public.fn_despacho_oculto(uuid) from public, anon;
revoke all on function public.fn_snapshot_despacho_oculto(jsonb) from public, anon;
grant execute on function public.fn_despacho_oculto(uuid) to authenticated;
grant execute on function public.fn_snapshot_despacho_oculto(jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Filtros de lectura (RESTRICTIVE: se suman a las politicas que ya
--    existen, no las reemplazan; un usuario solo ve lo que ambas dejan).
-- ---------------------------------------------------------------------

-- La tabla de pedidos: de aqui cuelgan Ordenes, Control Central,
-- A Despachar, filtros desplegables, Compensacion, Excel, etc.
drop policy if exists "oculto_pedidos_anteriores" on public.p_pedidosh;
create policy "oculto_pedidos_anteriores"
  on public.p_pedidosh
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = "PedidoNo"::text));

-- Registros por pedido.
drop policy if exists "oculto_pedidos_anteriores" on public.production_movements;
create policy "oculto_pedidos_anteriores"
  on public.production_movements
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = production_movements.order_number::text));

drop policy if exists "oculto_pedidos_anteriores" on public.returns;
create policy "oculto_pedidos_anteriores"
  on public.returns
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = returns.order_number::text));

drop policy if exists "oculto_pedidos_anteriores" on public.order_destino;
create policy "oculto_pedidos_anteriores"
  on public.order_destino
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = order_destino.order_number::text));

drop policy if exists "oculto_pedidos_anteriores" on public.pedido_cierre_forzado;
create policy "oculto_pedidos_anteriores"
  on public.pedido_cierre_forzado
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = pedido_cierre_forzado.order_number::text));

-- Despachos: lineas por pedido.
drop policy if exists "oculto_pedidos_anteriores" on public.despacho_ordenes;
create policy "oculto_pedidos_anteriores"
  on public.despacho_ordenes
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = despacho_ordenes.order_number::text));

drop policy if exists "oculto_pedidos_anteriores" on public.despacho_orden_items;
create policy "oculto_pedidos_anteriores"
  on public.despacho_orden_items
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = despacho_orden_items.order_number::text));

drop policy if exists "oculto_pedidos_anteriores" on public.despacho_orden_bultos;
create policy "oculto_pedidos_anteriores"
  on public.despacho_orden_bultos
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = despacho_orden_bultos.order_number::text));

-- Despachos: el despacho entero desaparece solo si TODOS sus pedidos estan ocultos.
drop policy if exists "oculto_pedidos_anteriores" on public.despachos;
create policy "oculto_pedidos_anteriores"
  on public.despachos
  as restrictive
  for select
  to authenticated
  using (not public.fn_despacho_oculto(id));

drop policy if exists "oculto_pedidos_anteriores" on public.despacho_bultos;
create policy "oculto_pedidos_anteriores"
  on public.despacho_bultos
  as restrictive
  for select
  to authenticated
  using (not public.fn_despacho_oculto(despacho_id));

-- Auditoria del Validador (orden_id vacio = visible).
drop policy if exists "oculto_pedidos_anteriores" on public.audit_validador;
create policy "oculto_pedidos_anteriores"
  on public.audit_validador
  as restrictive
  for select
  to authenticated
  using (orden_id is null or not exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = orden_id::text));

-- Eliminaciones: de movimientos (pedido en el snapshot) o de despachos
-- (todos los pedidos del snapshot ocultos).
drop policy if exists "oculto_pedidos_anteriores" on public.log_eliminaciones;
create policy "oculto_pedidos_anteriores"
  on public.log_eliminaciones
  as restrictive
  for select
  to authenticated
  using (
    not (
      (tabla_origen = 'production_movements'
        and exists (select 1 from public.vw_pedidos_ocultos h where h.order_number = (snapshot ->> 'order_number')))
      or
      (tabla_origen = 'despachos' and public.fn_snapshot_despacho_oculto(snapshot))
    )
  );

-- ---------------------------------------------------------------------
-- 5. Prueba dentro de la transaccion: fuerza a evaluar la vista. Si la
--    conversion de fecha falla, TODO el script se deshace.
-- ---------------------------------------------------------------------
select count(*) as pedidos_que_se_ocultaran from public.vw_pedidos_ocultos;

commit;

-- =====================================================================
-- VERIFICACION (ejecutar DESPUES, aparte). El editor de Supabase corre
-- como dueno y no aplica filtros; esto simula un usuario autenticado.
-- Ejecuta cada bloque por separado y compara:
--
--   begin;
--   set local role authenticated;
--   select count(distinct "PedidoNo") as pedidos_visibles from public.p_pedidosh;
--   select count(*) as movimientos_visibles from public.production_movements;
--   rollback;
--
--   select count(distinct "PedidoNo") as pedidos_totales from public.p_pedidosh;
--   select count(*) as movimientos_totales from public.production_movements;
--
-- Los "visibles" deben ser MENORES que los "totales" (la diferencia son
-- los pedidos/movimientos anteriores al corte).
-- =====================================================================
