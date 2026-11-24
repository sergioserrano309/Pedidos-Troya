-- =====================================================================
-- 090_revertir_completado_por_talla_y_tope_refilado.sql
-- Deja el calculo como estaba antes del 090:
--   - vw_pedido_progreso vuelve a calcular pendientes, %, estado y etapa Fin
--     con la SUMA de pares (formulas de 057). Las 5 columnas tallas_* se
--     conservan porque una vista no puede perder columnas con create or
--     replace; quedan solo informativas.
--   - vw_pedido_rol_gate vuelve a la version de 046.
--   - Se quita el candado de Refilado y la funcion del 25%.
-- NO borra datos. Ojo: si ya se registro mas de lo pedido en alguna talla,
-- al revertir esa suma puede tapar tallas incompletas (el motivo del 090).
-- vw_pedido_progreso_atributos se deja como esta (ya incluye las columnas
-- nuevas; no hace falta tocarla).
-- =====================================================================

begin;

drop trigger if exists trg_validar_tope_refilado on public.production_movements;
drop function if exists public.fn_validar_tope_refilado();

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
),
-- NUEVO (090): una fila por TALLA. Las lineas que comparten item_id comparten
-- movimientos, asi que se suman sus pedidos y se cuentan una sola vez.
tallas as (
  -- Misma fuente y mismo filtro (sin canceladas) que vw_item_progreso, pero sin
  -- recorrer sus agregados otra vez (esta vista es la central de la app).
  select
    p."PedidoNo"::text as order_number,
    p.item_id,
    sum(coalesce(p."CantidadP", 0)) as sol
  from public.p_pedidosh p
  where coalesce(p."Cancelado", false) = false
  group by p."PedidoNo"::text, p.item_id
),
mov_talla as (
  select
    m.item_id,
    sum(m.quantity) filter (where m.to_process = 'Refilado')   as in_r,
    sum(m.quantity) filter (where m.from_process = 'Refilado' and not m.es_automatico) as out_r,
    sum(m.quantity) filter (where m.from_process = 'Acabado')  as out_a,
    sum(m.quantity) filter (where m.from_process = 'Mateado')  as out_m,
    sum(m.quantity) filter (where m.from_process = 'Empaque')  as out_e
  from public.production_movements m
  group by m.item_id
),
cobertura as (
  select
    t.order_number,
    count(*) as n_tallas,
    -- Refilado: lo que debe cubrir cada talla es lo pedido + lo que le regresaron
    sum(t.sol + coalesce(x.in_r, 0))                                 as base_r,
    sum(least(coalesce(x.out_r, 0), t.sol + coalesce(x.in_r, 0)))    as cub_r,
    sum(greatest(t.sol + coalesce(x.in_r, 0) - coalesce(x.out_r, 0), 0)) as pend_r,
    count(*) filter (where coalesce(x.out_r, 0) >= t.sol + coalesce(x.in_r, 0)) as ok_r,
    -- Acabado / Mateado / Empaque: lo pedido por talla
    sum(least(coalesce(x.out_a, 0), t.sol))                          as cub_a,
    sum(greatest(t.sol - coalesce(x.out_a, 0), 0))                   as pend_a,
    count(*) filter (where coalesce(x.out_a, 0) >= t.sol)            as ok_a,
    sum(least(coalesce(x.out_m, 0), t.sol))                          as cub_m,
    sum(greatest(t.sol - coalesce(x.out_m, 0), 0))                   as pend_m,
    count(*) filter (where coalesce(x.out_m, 0) >= t.sol)            as ok_m,
    sum(least(coalesce(x.out_e, 0), t.sol))                          as cub_e,
    sum(greatest(t.sol - coalesce(x.out_e, 0), 0))                   as pend_e,
    count(*) filter (where coalesce(x.out_e, 0) >= t.sol)            as ok_e
  from tallas t
  left join mov_talla x on x.item_id = t.item_id
  group by t.order_number
)
select
  op.order_number,
  op.cliente,
  op.fecha_pedido,
  op.nombre_referencia,
  op.material,
  op.color,
  op.total_solicitado,
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
  dc.es_automatico as destino_es_automatico,
  (pcf.order_number is not null) as cierre_forzado,
  pcf.motivo                     as cierre_forzado_motivo,
  pcf.cerrado_at                 as cierre_forzado_at,
  cpr.name                       as cierre_forzado_por,
  -- Las 5 columnas de 090 se conservan (una vista no puede perder columnas): solo informativas.
  coalesce(cb.n_tallas, 0)::bigint as tallas_total,
  coalesce(cb.ok_r, 0)::bigint     as tallas_ok_refilado,
  coalesce(cb.ok_a, 0)::bigint     as tallas_ok_acabado,
  coalesce(cb.ok_m, 0)::bigint     as tallas_ok_mateado,
  coalesce(cb.ok_e, 0)::bigint     as tallas_ok_empaque
from orden_progreso op
left join movimientos_orden_calc mo on mo.order_number = op.order_number
left join destino_calc dc on dc.order_number = op.order_number
left join cobertura cb on cb.order_number = op.order_number
left join public.pedido_cierre_forzado pcf on pcf.order_number = op.order_number
left join public.profiles cpr on cpr.id = pcf.cerrado_por;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo. Completado/Fin/% global = paso por Empaque (021). cierre_forzado* (057). tallas_* (090, conservadas, informativas).';

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
      case when g.fecha_proceso is not null then dp.fecha_despacho end
    else
      g.fecha_proceso
  end as fecha_liquidacion
from gate g
left join despacho_por_orden dp on dp.order_number = g.order_number;

grant select on public.vw_pedido_rol_gate to authenticated;

comment on view public.vw_pedido_rol_gate is
  'Fecha de liquidacion por (pedido, rol). Empaque (fix 046): exige 100% procesado Y pedido despachado COMPLETO sumando todas sus remesas; la fecha es la del despacho que lo completo.';

drop function if exists public.fn_extra_refilado(integer);

commit;
