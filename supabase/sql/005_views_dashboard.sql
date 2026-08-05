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
-- item_id ya NO se calcula aqui: es una columna generada+almacenada en
-- p_pedidosh (ver supabase/sql/016_item_id_materializado.sql), calculada
-- una sola vez por fila en vez de en cada consulta (generar_item_id hace
-- SHA-256 + un ciclo de 64 pasos en PL/pgSQL; recalcularlo miles de
-- veces por consulta era la causa principal de la lentitud del listado).
-- ---------------------------------------------------------------------
create or replace view public.vw_pedidos_con_id
with (security_invoker = true) as
select pp.*
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
-- Incluye: etapa máxima alcanzada, fecha de finalización, y días transcurridos.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedido_progreso
with (security_invoker = true) as
with orden_progreso as (
  -- Fusionado en un solo paso por vw_item_progreso (antes eran dos CTEs
  -- separados que leian/unian TODO otra vez cada uno: el doble de
  -- trabajo para exactamente los mismos datos).
  select
    order_number::text as order_number,
    max(cliente)        as cliente,
    max(fecha_pedido)   as fecha_pedido,
    max(nombre_referencia) as nombre_referencia,
    max(material)       as material,
    max(color)          as color,
    count(*)            as total_items,
    sum(cantidad_solicitada) as total_solicitado,
    sum(cantidad_procesada)  as total_procesado,
    sum(cantidad_devuelta)   as total_devuelto,
    sum(cantidad_pendiente)  as total_pendiente,
    case
      when sum(cantidad_solicitada) > 0
        then least(round((sum(cantidad_procesada)::numeric / sum(cantidad_solicitada)::numeric) * 100), 100)
      else 0
    end as porcentaje_completado,
    case
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 4 then 'E'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 3 then 'A'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 2 then 'M'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 1 then 'R'
      else 'Sin Procesar'
    end as etapa_actual
  from public.vw_item_progreso
  group by order_number::text
),
-- Entradas/salidas por ORDEN (no por item) para cada uno de los 4
-- procesos, agregando production_movements directamente en una sola
-- pasada (incluye fecha_fin, fusionado aqui mismo para no leer
-- production_movements dos veces). Evita unir con vw_item_progreso a
-- nivel de item (que ya hace su propia agregacion de production_movements)
-- para no duplicar el costo de la consulta bajo RLS.
movimientos_orden_calc as (
  select
    order_number::text as order_number,
    sum(quantity) filter (where to_process = 'Refilado')   as in_refilado,
    sum(quantity) filter (where to_process = 'Acabado')    as in_acabado,
    sum(quantity) filter (where to_process = 'Mateado')    as in_mateado,
    sum(quantity) filter (where to_process = 'Empaque')    as in_empaque,
    -- out_refilado EXCLUYE los movimientos automáticos (es_automatico):
    -- el enrutamiento por regla no es trabajo que Refilado haya hecho,
    -- así que no debe sumar a su propio "Procesado".
    sum(quantity) filter (where from_process = 'Refilado' and not es_automatico) as out_refilado,
    sum(quantity) filter (where from_process = 'Acabado')  as out_acabado,
    sum(quantity) filter (where from_process = 'Mateado')  as out_mateado,
    sum(quantity) filter (where from_process = 'Empaque')  as out_empaque,
    max(created_at) filter (where to_process = 'Empaque')  as fecha_fin
  from public.production_movements
  group by order_number::text
),
destino_calc as (
  select order_number, es_automatico
  from public.order_destino
)
select
  op.order_number,
  op.cliente,
  op.fecha_pedido,
  op.nombre_referencia,
  op.material,
  op.color,
  op.total_solicitado,
  op.total_procesado,
  op.total_devuelto,
  op.total_pendiente,
  op.porcentaje_completado,
  case
    when op.porcentaje_completado = 100 then 'Completado'
    else 'En Proceso'
  end as estatus_general,
  case
    when op.porcentaje_completado = 100 then 'Fin'
    else coalesce(op.etapa_actual, 'R')
  end as etapa_actual,
  extract(day from (case when op.porcentaje_completado = 100 and mo.fecha_fin is not null then mo.fecha_fin else now() end) - op.fecha_pedido)::int as dias_orden,
  -- Cifras especificas de CADA proceso, calculadas contra el TOTAL del
  -- pedido completo (op.total_solicitado): un pedido completo va SIEMPRE
  -- a Acabado O a Mateado (nunca dividido entre ambos), y siempre termina
  -- pasando por Empaque, asi que el % de "mi proceso" si puede llegar a
  -- 100% de forma consistente. "entrada_X" (solo Acabado/Mateado/Empaque)
  -- se expone aparte unicamente para decidir VISIBILIDAD en
  -- ordersService.js (si algo me ha sido enviado realmente), sin afectar
  -- las cifras mostradas al usuario.
  (op.total_solicitado + coalesce(mo.in_refilado, 0)) as total_refilado,
  coalesce(mo.out_refilado, 0) as procesado_refilado,
  greatest(op.total_solicitado + coalesce(mo.in_refilado, 0) - coalesce(mo.out_refilado, 0), 0) as pendiente_refilado,
  case when (op.total_solicitado + coalesce(mo.in_refilado, 0)) > 0
    then least(round((coalesce(mo.out_refilado, 0)::numeric / (op.total_solicitado + coalesce(mo.in_refilado, 0))::numeric) * 100), 100)
    else 0
  end as porcentaje_refilado,
  coalesce(mo.in_acabado, 0) as entrada_acabado,
  op.total_solicitado as total_acabado,
  coalesce(mo.out_acabado, 0) as procesado_acabado,
  greatest(op.total_solicitado - coalesce(mo.out_acabado, 0), 0) as pendiente_acabado,
  case when op.total_solicitado > 0
    then least(round((coalesce(mo.out_acabado, 0)::numeric / op.total_solicitado::numeric) * 100), 100)
    else 0
  end as porcentaje_acabado,
  coalesce(mo.in_mateado, 0) as entrada_mateado,
  op.total_solicitado as total_mateado,
  coalesce(mo.out_mateado, 0) as procesado_mateado,
  greatest(op.total_solicitado - coalesce(mo.out_mateado, 0), 0) as pendiente_mateado,
  case when op.total_solicitado > 0
    then least(round((coalesce(mo.out_mateado, 0)::numeric / op.total_solicitado::numeric) * 100), 100)
    else 0
  end as porcentaje_mateado,
  coalesce(mo.in_empaque, 0) as entrada_empaque,
  op.total_solicitado as total_empaque,
  coalesce(mo.out_empaque, 0) as procesado_empaque,
  greatest(op.total_solicitado - coalesce(mo.out_empaque, 0), 0) as pendiente_empaque,
  case when op.total_solicitado > 0
    then least(round((coalesce(mo.out_empaque, 0)::numeric / op.total_solicitado::numeric) * 100), 100)
    else 0
  end as porcentaje_empaque,
  -- true si el destino de este pedido se confirmó por una regla de
  -- enrutamiento automático (no por un click humano). Refilado NO debe
  -- ver estos pedidos en su listado (ver ordersService.js).
  dc.es_automatico as destino_es_automatico
from orden_progreso op
left join movimientos_orden_calc mo on mo.order_number = op.order_number
left join destino_calc dc on dc.order_number = op.order_number;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo para las cards del dashboard. Calculado en cada consulta, nunca almacenado. Incluye estatus general, etapa actual, dias transcurridos y cifras especificas por proceso (refilado/acabado/mateado/empaque) para que cada rol vea solo lo que le compete.';

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
