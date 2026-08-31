-- =====================================================================
-- 018_fix_etapa_fin.sql
-- BUG: etapa_actual se marcaba 'Fin' apenas porcentaje_completado (global)
-- llegaba a 100%, pero ese % global se calcula sumando TODO movimiento
-- del item sin importar el proceso — así que un item que Refilado apenas
-- movió (manual o automáticamente) a Acabado/Mateado YA cuenta como
-- "100% procesado" aunque Acabado/Mateado no hayan hecho nada, y mucho
-- menos haya pasado por Empaque.
--
-- Ejemplo real: pedido 3145 se auto-enrutó completo a Mateado (regla).
-- El movimiento Refilado -> Mateado ya sumaba el 100% de las unidades,
-- así que el pedido se marcaba "Fin" / "Completado" sin que Mateado
-- hubiera procesado una sola unidad.
--
-- FIX: 'Fin' ahora requiere que las unidades que salieron de Empaque
-- (mo.out_empaque) cubran el total solicitado del pedido. Es decir,
-- 'Fin' = ya pasó realmente por Empaque, no solo "salió de Refilado".
--
-- NO se toca porcentaje_completado ni estatus_general (Completado/En
-- Proceso): esos siguen igual, a petición explícita, para no afectar el
-- badge que ya usan Refilado/Acabado/Mateado/Empaque.
-- =====================================================================

create or replace view public.vw_pedido_progreso
with (security_invoker = true)
as
with orden_progreso as (
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
movimientos_orden_calc as (
  select
    order_number::text as order_number,
    sum(quantity) filter (where to_process = 'Refilado')   as in_refilado,
    sum(quantity) filter (where to_process = 'Acabado')    as in_acabado,
    sum(quantity) filter (where to_process = 'Mateado')    as in_mateado,
    sum(quantity) filter (where to_process = 'Empaque')    as in_empaque,
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
  -- FIX: 'Fin' solo si realmente paso por Empaque (out_empaque cubre el
  -- total solicitado), no solo porque el % global (que suma cualquier
  -- movimiento) llego a 100.
  case
    when op.total_solicitado > 0 and coalesce(mo.out_empaque, 0) >= op.total_solicitado then 'Fin'
    else coalesce(op.etapa_actual, 'R')
  end as etapa_actual,
  extract(day from (case when op.total_solicitado > 0 and coalesce(mo.out_empaque, 0) >= op.total_solicitado and mo.fecha_fin is not null then mo.fecha_fin else now() end) - op.fecha_pedido)::int as dias_orden,
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
  dc.es_automatico as destino_es_automatico
from orden_progreso op
left join movimientos_orden_calc mo on mo.order_number = op.order_number
left join destino_calc dc on dc.order_number = op.order_number;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo. etapa_actual solo es Fin cuando realmente paso por Empaque completo (fix 018). porcentaje_completado/estatus_general sin cambios.';
