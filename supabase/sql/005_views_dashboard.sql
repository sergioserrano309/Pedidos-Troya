-- =====================================================================
-- 005_views_dashboard.sql
-- Vistas de solo lectura que calculan el progreso de produccion en
-- tiempo real (NUNCA almacenado) combinando:
--   p_pedidosh (solo lectura) + production_movements + returns
--
-- IMPORTANTE: si el nombre real de tu tabla en Supabase no es
-- exactamente "p_pedidosh",
-- ajusta las referencias en este archivo y en
-- src/services/ordersService.js (constante PEDIDOS_TABLE).
-- =====================================================================

-- ---------------------------------------------------------------------
-- vw_pedidos_con_id
-- p_pedidosh + el item_id determinista calculado para cada fila.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedidos_con_id
with (security_invoker = true) as
select
  pp.*,
  public.generar_item_id(
    pp."PedidoNo"::text,
    pp."Referencia",
    pp."Talla"::text,
    pp."MaterialP",
    pp."ColorP"
  ) as item_id
from public.p_pedidosh pp;

-- ---------------------------------------------------------------------
-- vw_item_stage
-- Etapa actual de cada item: el evento mas reciente entre sus
-- movimientos normales (production_movements.to_process) Y sus
-- devoluciones con reproceso (returns.reprocess_destination cuando
-- action = 'REPROCESO'), ya que un reproceso reenvia el item a otro
-- proceso igual que un movimiento normal.
-- Un item sin ningun evento aun se considera en 'Refilado' (etapa
-- inicial), lo cual se resuelve con COALESCE en las vistas que la usan.
-- ---------------------------------------------------------------------
create or replace view public.vw_item_stage
with (security_invoker = true) as
select distinct on (eventos.item_id)
  eventos.item_id,
  eventos.order_number,
  eventos.etapa_actual,
  eventos.ultima_actualizacion
from (
  select item_id, order_number, to_process as etapa_actual, created_at as ultima_actualizacion
  from public.production_movements
  union all
  select item_id, order_number, reprocess_destination as etapa_actual, created_at as ultima_actualizacion
  from public.returns
  where action = 'REPROCESO'
) eventos
order by eventos.item_id, eventos.ultima_actualizacion desc;

-- ---------------------------------------------------------------------
-- vw_item_progreso
-- Progreso calculado por item (fila individual de p_pedidosh).
-- Usada en el detalle de orden y para filtrar que ve cada rol segun
-- su etapa_actual.
-- ---------------------------------------------------------------------
create or replace view public.vw_item_progreso
with (security_invoker = true) as
select
  p.item_id,
  p."PedidoNo"           as order_number,
  p."FechaP"             as fecha_pedido,
  p."Cliente"            as cliente,
  p."Referencia"         as referencia,
  p."NombreR"            as nombre_referencia,
  p."Talla"              as talla,
  p."MaterialP"          as material,
  p."ColorP"             as color,
  p."Vira"               as vira,
  p."DetalleVira"        as detalle_vira,
  p."Acabado"            as acabado_spec,
  p."DetalleAcab"        as detalle_acabado,
  p."Esterilla"          as esterilla,
  p."DetalleEsterilla"   as detalle_esterilla,
  p."Marquilla"          as marquilla,
  p."CantidadP"          as cantidad_solicitada,
  coalesce(mv.procesado, 0)     as cantidad_procesada,
  coalesce(rt.devuelto, 0)      as cantidad_devuelta,
  coalesce(rt.reprocesado, 0)   as cantidad_reprocesada,
  coalesce(st.etapa_actual, 'Refilado') as etapa_actual,
  st.ultima_actualizacion,
  -- Formula exacta de la seccion 10 del documento:
  --   Pending = Requested - Processed + Reprocessed
  -- (las devoluciones MOLIDO no se sacan del calculo, ver seccion 10)
  greatest(coalesce(p."CantidadP", 0) - coalesce(mv.procesado, 0) + coalesce(rt.reprocesado, 0), 0) as cantidad_pendiente,
  -- Completion = Processed / Requested * 100
  case
    when coalesce(p."CantidadP", 0) > 0
      then least(round((coalesce(mv.procesado, 0)::numeric / p."CantidadP"::numeric) * 100), 100)
    else 0
  end as porcentaje_completado
from public.vw_pedidos_con_id p
left join (
  select item_id, sum(quantity) as procesado
  from public.production_movements
  group by item_id
) mv on mv.item_id = p.item_id
left join (
  select
    item_id,
    sum(quantity) as devuelto,
    sum(quantity) filter (where action = 'REPROCESO') as reprocesado
  from public.returns
  group by item_id
) rt on rt.item_id = p.item_id
left join public.vw_item_stage st on st.item_id = p.item_id
where coalesce(p."Cancelado", false) = false;

comment on view public.vw_item_progreso is
  'Progreso calculado por item, nunca almacenado. Combina p_pedidosh (solo lectura) + production_movements + returns. Filtra pedidos cancelados.';

-- ---------------------------------------------------------------------
-- vw_pedido_progreso
-- Progreso agregado por PedidoNo (usado en las cards del dashboard).
-- ---------------------------------------------------------------------
create or replace view public.vw_pedido_progreso
with (security_invoker = true) as
select
  order_number,
  max(cliente)        as cliente,
  max(fecha_pedido)   as fecha_pedido,
  count(*)            as total_items,
  sum(cantidad_solicitada) as total_solicitado,
  sum(cantidad_procesada)  as total_procesado,
  sum(cantidad_devuelta)   as total_devuelto,
  sum(cantidad_pendiente)  as total_pendiente,
  case
    when sum(cantidad_solicitada) > 0
      then least(round((sum(cantidad_procesada)::numeric / sum(cantidad_solicitada)::numeric) * 100), 100)
    else 0
  end as porcentaje_completado
from public.vw_item_progreso
group by order_number;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo para las cards del dashboard. Calculado en cada consulta, nunca almacenado.';

-- ---------------------------------------------------------------------
-- vw_historial
-- Une production_movements + returns en una sola línea de tiempo para
-- la pantalla de Historial, con el nombre del usuario ya resuelto.
--
-- Como la vista se crea con security_invoker = true, las políticas RLS
-- de "returns" (solo Comercial) se siguen aplicando automáticamente:
-- un usuario que no sea Comercial simplemente no verá filas tipo
-- 'devolucion' al consultar esta vista.
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
  h.created_at
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
    m.created_at
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
    r.created_at
  from public.returns r
) h
left join public.profiles pr on pr.id = h.user_id;

comment on view public.vw_historial is
  'Linea de tiempo combinada de production_movements + returns para la pantalla de Historial. Inmutable (solo SELECT).';
