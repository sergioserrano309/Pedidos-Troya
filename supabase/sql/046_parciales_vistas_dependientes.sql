-- =====================================================================
-- 046_parciales_vistas_dependientes.sql
-- Ajusta todo lo que quedo colgando del cambio a despachos parciales:
--   1. vw_despachos_registro  -> unidades reales + contador de completos
--   2. vw_historial           -> despacho por TALLA, badge por PEDIDO,
--                                y tiene_movimiento_posterior (Fase 9)
--   3. vw_pedido_rol_gate     -> comision de Empaque solo con pedido completo
--   4. eliminar_movimiento_con_motivo -> bloqueo por talla, no por orden
--   5. eliminar_despacho_con_motivo   -> snapshot con el desglose
-- =====================================================================

-- Soporta el correlacionado de tiene_movimiento_posterior y la regla de
-- "movimiento posterior" del RPC de borrado.
create index if not exists idx_movements_item_created
  on public.production_movements(item_id, created_at);

-- ---------------------------------------------------------------------
-- 1. vw_despachos_registro
--
-- total_unidades dejaba de cuadrar con parciales: sumaba TODO el pedido
-- ("CantidadP" de p_pedidosh) aunque solo hubiera salido una parte.
-- Ahora suma lo realmente despachado. Se agregan ademas las columnas del
-- contador "N de M completos" que muestra RegistrosD.
--
-- Cambia el conjunto de columnas -> drop + create.
-- ---------------------------------------------------------------------
drop view if exists public.vw_despachos_registro;

create view public.vw_despachos_registro
with (security_invoker = true) as
with ordenes as (
  select do2.despacho_id,
         count(*)                                              as numero_ordenes,
         array_agg(do2.order_number order by do2.order_number)  as order_numbers,
         count(*) filter (where e.pedido_completo)              as pedidos_completos
    from public.despacho_ordenes do2
    left join public.vw_pedido_despacho_estado e on e.order_number = do2.order_number
   group by do2.despacho_id
),
bultos as (
  select db.despacho_id, sum(db.peso) as peso_total
    from public.despacho_bultos db
   group by db.despacho_id
),
unidades as (
  select doi.despacho_id, sum(doi.cantidad) as total_unidades
    from public.despacho_orden_items doi
   group by doi.despacho_id
)
select d.id,
       d.numero_despacho,
       d.consecutivo,
       d.created_at,
       d.created_by,
       pr.name                                       as creado_por_nombre,
       d.total_bultos,
       coalesce(b.peso_total, 0)                     as peso_total,
       coalesce(o.numero_ordenes, 0)                 as numero_ordenes,
       coalesce(o.order_numbers, array[]::text[])    as order_numbers,
       coalesce(u.total_unidades, 0)                 as total_unidades,
       coalesce(o.pedidos_completos, 0)              as pedidos_completos,
       d.asignacion_confirmada,
       d.confirmed_at
  from public.despachos d
  left join public.profiles pr on pr.id = d.created_by
  left join ordenes  o on o.despacho_id = d.id
  left join bultos   b on b.despacho_id = d.id
  left join unidades u on u.despacho_id = d.id;

grant select on public.vw_despachos_registro to authenticated;

comment on view public.vw_despachos_registro is
  'Una fila por despacho. total_unidades = lo realmente despachado (despacho_orden_items), no el total del pedido. pedidos_completos alimenta el contador "N de M completos" de RegistrosD.';

-- ---------------------------------------------------------------------
-- 2. vw_historial
--
-- Dos cambios de significado y una columna nueva:
--   - fecha_despacho pasa a ser la del despacho de ESA TALLA (item_id),
--     no la del pedido entero. Con parciales, decir "la orden salio" en
--     un registro de una talla que aun no sale seria falso.
--   - despacho_confirmado pasa a ser pedido_completo del PEDIDO, que es
--     lo que el usuario pidio: el badge dice No hasta que salga todo.
--   - tiene_movimiento_posterior (NUEVA, al final) expone la regla de
--     014:66-72 para que la UI pueda deshabilitar el boton antes de que
--     el usuario escriba un motivo en vano.
--
-- create or replace view permite cambiar las EXPRESIONES y agregar
-- columnas al final; lo que no permite es reordenar ni renombrar. Los
-- tipos de fecha_despacho (timestamptz) y despacho_confirmado (boolean)
-- se mantienen.
-- ---------------------------------------------------------------------
create or replace view public.vw_historial
with (security_invoker = true) as
select
  h.id,
  h.tipo,
  h.order_number,
  h.item_id,
  h.reference,
  h.size,
  h.quantity,
  h.from_process,
  h.to_process,
  h.causal,
  h.failed_process,
  h.action,
  h.observation,
  h.user_id,
  pr.name as user_name,
  pr.role as user_role,
  h.created_at,
  coalesce(ep.paso_refilado, false) as paso_refilado,
  coalesce(ep.paso_mateado, false) as paso_mateado,
  coalesce(ep.paso_acabado, false) as paso_acabado,
  coalesce(ep.paso_empaque, false) as paso_empaque,
  h.precio_cop,
  h.valor_cop,
  tal.fecha_despacho,
  coalesce(est.pedido_completo, false) as despacho_confirmado,
  (h.tipo = 'movimiento' and exists (
     select 1 from public.production_movements m2
     where m2.item_id = h.item_id and m2.created_at > h.created_at
   )) as tiene_movimiento_posterior
from (
  select
    m.id,
    'movimiento'::text as tipo,
    m.order_number,
    m.item_id,
    m.reference,
    m.size,
    m.quantity,
    m.from_process,
    m.to_process,
    null::text as causal,
    null::text as failed_process,
    null::text as action,
    m.observation,
    m.user_id,
    m.created_at,
    m.precio_cop,
    m.valor_cop
  from public.production_movements m

  union all

  select
    r.id,
    'devolucion'::text as tipo,
    r.order_number,
    r.item_id,
    null::text as reference,
    r.size,
    r.quantity,
    r.failed_process as from_process,
    coalesce(r.reprocess_destination, 'N/A') as to_process,
    r.causal,
    r.failed_process,
    r.action,
    r.observation,
    r.user_id,
    r.created_at,
    null::numeric as precio_cop,
    null::numeric as valor_cop
  from public.returns r
) h
left join public.profiles pr on pr.id = h.user_id
left join public.vw_pedido_estado_procesos ep on ep.order_number = h.order_number
left join (
  -- Fecha en que ESTA talla salio (la ultima vez, si salio en varias remesas).
  select doi.item_id,
         max(coalesce(d.confirmed_at, d.created_at)) as fecha_despacho
  from public.despacho_orden_items doi
  join public.despachos d on d.id = doi.despacho_id
  group by doi.item_id
) tal on tal.item_id = h.item_id
left join public.vw_pedido_despacho_estado est on est.order_number = h.order_number;

comment on view public.vw_historial is
  'Linea de tiempo de production_movements + returns. Desde 046: fecha_despacho es la de la TALLA (item_id) y despacho_confirmado es la completitud del PEDIDO. tiene_movimiento_posterior expone la regla de borrado de 014 para la UI.';

-- ---------------------------------------------------------------------
-- 3. vw_pedido_rol_gate — comision de Empaque con parciales
--
-- Antes (040) bastaba con que el pedido apareciera en cualquier despacho
-- confirmado. Con parciales eso pagaria la comision completa al primer
-- envio parcial. Ahora se exige pedido_completo, y la fecha es la del
-- despacho que lo COMPLETO (fecha_ultimo_despacho).
--
-- Refilado/Acabado/Mateado no se tocan: siguen con fecha_proceso.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedido_rol_gate
with (security_invoker = true) as
with totales as (
  select order_number::text as order_number, sum(cantidad_solicitada) as total_solicitado
  from public.vw_item_progreso
  group by order_number::text
),
movs as (
  select
    m.order_number,
    lower(m.from_process) as rol,
    m.id,
    m.created_at,
    sum(m.quantity) over (
      partition by m.order_number, m.from_process
      order by m.created_at, m.id
      rows between unbounded preceding and current row
    ) as acumulado
  from public.production_movements m
  where not m.es_automatico
),
gate as (
  select
    mv.order_number,
    mv.rol,
    t.total_solicitado,
    min(mv.created_at) filter (where mv.acumulado >= t.total_solicitado) as fecha_proceso
  from movs mv
  join totales t on t.order_number = mv.order_number
  where t.total_solicitado > 0
  group by mv.order_number, mv.rol, t.total_solicitado
),
despacho_por_orden as (
  select e.order_number, e.fecha_ultimo_despacho as fecha_despacho
  from public.vw_pedido_despacho_estado e
  where e.pedido_completo
)
select
  g.order_number,
  g.rol,
  g.total_solicitado,
  case
    when g.rol = 'empaque' then
      -- Las DOS condiciones: 100% procesado Y pedido completo despachado.
      case when g.fecha_proceso is not null then dp.fecha_despacho end
    else
      g.fecha_proceso
  end as fecha_liquidacion
from gate g
left join despacho_por_orden dp on dp.order_number = g.order_number;

grant select on public.vw_pedido_rol_gate to authenticated;

comment on view public.vw_pedido_rol_gate is
  'Fecha de liquidacion por (pedido, rol). Empaque (fix 046): exige 100% procesado Y pedido despachado COMPLETO sumando todas sus remesas; la fecha es la del despacho que lo completo.';

-- ---------------------------------------------------------------------
-- 4. eliminar_movimiento_con_motivo — bloqueo por TALLA
--
-- 041 bloqueaba si la ORDEN aparecia en cualquier despacho. Con
-- parciales eso congelaria el pedido entero apenas saliera un par. Ahora
-- se mira el item_id: si de la orden 3121 salio la talla 35 pero no la
-- 36, se bloquea la 35 y se permite la 36.
-- ---------------------------------------------------------------------
create or replace function public.eliminar_movimiento_con_motivo(p_movimiento_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registro public.production_movements;
  v_perfil_id uuid;
  v_consecutivos text;
begin
  select id into v_perfil_id from public.profiles where auth_id = auth.uid();
  if v_perfil_id is null then
    raise exception 'Usuario no valido.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este registro.';
  end if;

  select * into v_registro from public.production_movements where id = p_movimiento_id;
  if v_registro.id is null then
    raise exception 'El registro no existe o ya fue eliminado.';
  end if;

  if v_registro.user_id is distinct from v_perfil_id then
    raise exception 'Solo puedes eliminar registros que tu mismo creaste.';
  end if;

  -- Bloqueo por talla despachada (046, antes era por orden completa).
  select string_agg(distinct d.consecutivo, ', ')
    into v_consecutivos
    from public.despacho_orden_items doi
    join public.despachos d on d.id = doi.despacho_id
   where doi.item_id = v_registro.item_id;

  if v_consecutivos is not null then
    raise exception 'No puedes eliminar este registro: la talla % del pedido % ya fue despachada (%). Elimina primero ese despacho en RegistrosD.',
      v_registro.size, v_registro.order_number, v_consecutivos;
  end if;

  if exists (
    select 1 from public.production_movements m2
    where m2.item_id = v_registro.item_id
      and m2.created_at > v_registro.created_at
  ) then
    raise exception 'No puedes eliminar este registro: ya se genero otro movimiento posterior para esta talla.';
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('production_movements', v_registro.id, to_jsonb(v_registro), v_perfil_id, trim(p_motivo));

  delete from public.production_movements where id = p_movimiento_id;
end;
$$;

grant execute on function public.eliminar_movimiento_con_motivo(uuid, text) to authenticated;

comment on function public.eliminar_movimiento_con_motivo(uuid, text) is
  'Elimina un movimiento con motivo obligatorio y snapshot en log_eliminaciones. Bloquea si la TALLA ya fue despachada (046) o si existe un movimiento posterior para ella (014).';

-- ---------------------------------------------------------------------
-- 5. eliminar_despacho_con_motivo — snapshot con el desglose por talla
-- ---------------------------------------------------------------------
create or replace function public.eliminar_despacho_con_motivo(
  p_despacho_id uuid,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_snapshot jsonb;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('empaque', 'validador') then
    raise exception 'No tienes permiso para eliminar despachos.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este despacho.';
  end if;

  select jsonb_build_object(
           'despacho', to_jsonb(d),
           'ordenes', coalesce(
             (select jsonb_agg(to_jsonb(o) order by o.order_number)
                from public.despacho_ordenes o where o.despacho_id = d.id), '[]'::jsonb),
           'items', coalesce(
             (select jsonb_agg(to_jsonb(it) order by it.order_number, it.talla)
                from public.despacho_orden_items it where it.despacho_id = d.id), '[]'::jsonb),
           'bultos', coalesce(
             (select jsonb_agg(to_jsonb(b) order by b.bulto_numero)
                from public.despacho_bultos b where b.despacho_id = d.id), '[]'::jsonb),
           'asignaciones', coalesce(
             (select jsonb_agg(to_jsonb(ob) order by ob.order_number, ob.bulto_numero)
                from public.despacho_orden_bultos ob where ob.despacho_id = d.id), '[]'::jsonb)
         )
    into v_snapshot
    from public.despachos d
   where d.id = p_despacho_id;

  if v_snapshot is null then
    raise exception 'El despacho no existe o ya fue eliminado.';
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('despachos', p_despacho_id, v_snapshot, v_perfil_id, trim(p_motivo));

  -- Las 4 tablas hijas caen por cascade (027 + 044).
  delete from public.despachos where id = p_despacho_id;
end;
$$;

grant execute on function public.eliminar_despacho_con_motivo(uuid, text) to authenticated;

comment on function public.eliminar_despacho_con_motivo(uuid, text) is
  'Elimina un despacho COMPLETO con motivo, dejando snapshot (despacho + ordenes + items por talla + bultos + asignaciones) en log_eliminaciones. Al borrarlo, sus unidades vuelven a estar disponibles para despachar.';
