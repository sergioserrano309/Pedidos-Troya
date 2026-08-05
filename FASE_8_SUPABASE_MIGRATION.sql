-- =====================================================================
-- FASE 8 (corrección): SUPABASE MIGRATION
-- Agrega a vw_pedido_progreso cifras ESPECIFICAS POR PROCESO
-- (refilado/acabado/mateado/empaque), para corregir:
--   1. El % / Total Suelas / Procesadas / Pendientes que ve cada rol en
--      la lista de órdenes ahora refleja SOLO su propio proceso, no el
--      pedido completo.
--   2. Bug de visibilidad: una orden ya no desaparece de un rol cuando
--      parte de lo que le enviaron avanzó al siguiente proceso pero aún
--      queda pendiente en el suyo.
-- =====================================================================
--
-- INSTRUCCIONES:
-- 1. Ve a Supabase Dashboard > SQL Editor
-- 2. Copia TODO el contenido de este archivo
-- 3. Pégalo en el editor SQL
-- 4. Haz click en "Run" (ejecutar)
-- 5. Espera a que complete (debe decir "Success")
-- 6. Vuelve a npm run dev para ver los cambios
--
-- =====================================================================

-- Primero elimina la vista existente
drop view if exists public.vw_pedido_progreso cascade;

-- Luego crea la nueva vista con permisos RLS
create view public.vw_pedido_progreso
with (security_invoker = true)
as
with orden_progreso as (
  select
    order_number::text as order_number,
    max(cliente)        as cliente,
    max(fecha_pedido)   as fecha_pedido,
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
    end as porcentaje_completado
  from public.vw_item_progreso
  group by order_number::text
),
etapa_maxima_calc as (
  select
    order_number::text as order_number,
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
fecha_fin_calc as (
  select
    pm.order_number::text as order_number,
    max(pm.created_at) as fecha_fin
  from public.production_movements pm
  where pm.to_process = 'Empaque'
  group by pm.order_number::text
),
-- Entradas/salidas por ORDEN (no por item) para cada uno de los 4
-- procesos, agregando production_movements directamente en una sola
-- pasada. Evita unir con vw_item_progreso a nivel de item (que ya hace su
-- propia agregacion de production_movements) para no duplicar el costo
-- de la consulta bajo RLS.
movimientos_orden_calc as (
  select
    order_number::text as order_number,
    sum(quantity) filter (where to_process = 'Refilado')   as in_refilado,
    sum(quantity) filter (where to_process = 'Acabado')    as in_acabado,
    sum(quantity) filter (where to_process = 'Mateado')    as in_mateado,
    sum(quantity) filter (where to_process = 'Empaque')    as in_empaque,
    sum(quantity) filter (where from_process = 'Refilado') as out_refilado,
    sum(quantity) filter (where from_process = 'Acabado')  as out_acabado,
    sum(quantity) filter (where from_process = 'Mateado')  as out_mateado,
    sum(quantity) filter (where from_process = 'Empaque')  as out_empaque
  from public.production_movements
  group by order_number::text
)
select
  op.order_number,
  op.cliente,
  op.fecha_pedido,
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
    else coalesce(em.etapa_actual, 'R')
  end as etapa_actual,
  extract(day from (case when op.porcentaje_completado = 100 and ff.fecha_fin is not null then ff.fecha_fin else now() end) - op.fecha_pedido)::int as dias_orden,
  -- Cifras y visibilidad especificas de CADA proceso (usadas por
  -- ordersService.js segun el rol del usuario, en vez de las globales de
  -- arriba, para que Acabado/Mateado/Empaque/Refilado vean solo lo que
  -- realmente les compete a ellos).
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
  end as porcentaje_empaque
from orden_progreso op
left join etapa_maxima_calc em on em.order_number = op.order_number
left join fecha_fin_calc ff on ff.order_number = op.order_number
left join movimientos_orden_calc mo on mo.order_number = op.order_number;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo para las cards del dashboard. Calculado en cada consulta, nunca almacenado. Incluye estatus general, etapa actual, dias transcurridos y cifras especificas por proceso (refilado/acabado/mateado/empaque) calculadas contra el total del pedido completo, para que cada rol vea el contexto completo del pedido y su % pueda llegar a 100%.';

-- Restaurar permisos RLS
grant select on public.vw_pedido_progreso to authenticated, anon;
