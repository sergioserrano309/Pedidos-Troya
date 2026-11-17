-- =====================================================================
-- 086_despachos_ocultos_rapido.sql
-- Acelera el filtro de pedidos ocultos (058) sobre despachos y
-- despacho_bultos. NO cambia que se ve y que no: solo COMO se calcula.
--
-- PROBLEMA
--   Las politicas de despachos y despacho_bultos llamaban a
--   fn_despacho_oculto(id) UNA VEZ POR FILA, y cada llamada recorria y
--   agrupaba todo p_pedidosh (vw_pedidos_ocultos). Con miles de filas,
--   Supabase cortaba la consulta por tiempo (57014), incluso en la primera
--   pagina. Afectaba al Excel (hoja Despachos) y puede afectar pantallas.
--
-- QUE CAMBIA
--   1. Vista nueva vw_despachos_ocultos: los despachos cuyos pedidos estan
--      TODOS ocultos (misma regla de fn_despacho_oculto, calculada UNA vez
--      para todos en vez de una por fila).
--   2. Las dos politicas restrictivas pasan a "not exists" contra esa vista,
--      igual que las demas tablas de despachos (despacho_ordenes, etc.).
--
-- NO TOCA datos, fn_despacho_oculto (queda intacta), ni las otras politicas.
-- SEGURIDAD: va en una transaccion; si algo falla, no queda nada a medias.
-- REVERSA: 086_revertir_despachos_ocultos_rapido.sql
-- =====================================================================

begin;

-- security_invoker = false A PROPOSITO (igual que vw_pedidos_ocultos): corre
-- con los permisos del dueno, sin los filtros de RLS. Si no, al ocultar
-- despacho_ordenes la vista no vería los pedidos viejos y no los reconoceria.
-- Solo expone ids de despacho.
create or replace view public.vw_despachos_ocultos
with (security_invoker = false) as
select o.despacho_id
from public.despacho_ordenes o
group by o.despacho_id
having bool_and(o.order_number::text in (select h.order_number from public.vw_pedidos_ocultos h));

revoke all on public.vw_despachos_ocultos from public, anon;
grant select on public.vw_despachos_ocultos to authenticated;

comment on view public.vw_despachos_ocultos is
  'Despachos que la plataforma NO muestra (058/086): tienen pedidos y TODOS estan ocultos. Misma regla que fn_despacho_oculto, calculada de una vez.';

drop policy if exists "oculto_pedidos_anteriores" on public.despachos;
create policy "oculto_pedidos_anteriores"
  on public.despachos
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_despachos_ocultos h where h.despacho_id = despachos.id));

drop policy if exists "oculto_pedidos_anteriores" on public.despacho_bultos;
create policy "oculto_pedidos_anteriores"
  on public.despacho_bultos
  as restrictive
  for select
  to authenticated
  using (not exists (select 1 from public.vw_despachos_ocultos h where h.despacho_id = despacho_bultos.despacho_id));

-- Fuerza a evaluar la vista nueva: si fallara, todo se deshace.
select count(*) as despachos_ocultos from public.vw_despachos_ocultos;

commit;
