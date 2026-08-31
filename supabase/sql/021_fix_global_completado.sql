-- =====================================================================
-- 021_fix_global_completado.sql
-- Misma causa raiz que 018 (etapa_actual), pero ahora tambien en
-- total_procesado / total_pendiente / porcentaje_completado / estatus_general:
-- estos campos sumaban CUALQUIER movimiento (aunque solo fuera Refilado
-- moviendo el lote a Acabado/Mateado), asi que un pedido auto-enrutado
-- a Mateado ya aparecia "100% / Completado" en la hoja "Ordenes" del
-- Excel y en Control Central, aunque Mateado no hubiera procesado nada
-- y el pedido nunca hubiera pasado por Empaque.
--
-- FIX: estos 4 campos globales ahora se calculan igual que
-- porcentaje_empaque/pendiente_empaque (es decir: "completado" =
-- "empacado"), consistente con la regla de etapa_actual='Fin' de 018.
--
-- Esto SI afecta a Comercial (unico rol, ademas de Validador, que ve
-- estos campos crudos sin remapear — Refilado/Acabado/Mateado/Empaque ya
-- ven su propio porcentaje_X remapeado en ordersService.js, no estos).
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
    sum(cantidad_devuelta)   as total_devuelto,
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
  -- "Completado" ahora significa "empacado" (paso por Empaque), no
  -- "salio de Refilado". Antes: sum(cantidad_procesada) de vw_item_progreso
  -- (contaba cualquier movimiento, se disparaba a 100% con un solo salto).
  -- Cast ::numeric explicito: el tipo original de esta columna (via
  -- sum(bigint) -> numeric) no se puede cambiar con CREATE OR REPLACE VIEW.
  coalesce(mo.out_empaque, 0)::numeric as total_procesado,
  op.total_devuelto,
  greatest(op.total_solicitado - coalesce(mo.out_empaque, 0), 0)::numeric as total_pendiente,
  case when op.total_solicitado > 0
    then least(round((coalesce(mo.out_empaque, 0)::numeric / op.total_solicitado::numeric) * 100), 100)
    else 0
  end as porcentaje_completado,
  case
    when op.total_solicitado > 0 and coalesce(mo.out_empaque, 0) >= op.total_solicitado then 'Completado'
    else 'En Proceso'
  end as estatus_general,
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
  'Progreso agregado por PedidoNo. Completado/Fin/% global = paso por Empaque (fix 021, consistente con etapa_actual de 018). Afecta a Comercial y Validador (unicos roles sin remapeo per-proceso); Refilado/Acabado/Mateado/Empaque siguen viendo su propio % (columnas procesado_X/porcentaje_X, sin cambios).';
