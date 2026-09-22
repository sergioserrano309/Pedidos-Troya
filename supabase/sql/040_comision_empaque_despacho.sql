-- =====================================================================
-- 040_comision_empaque_despacho.sql
-- Cambio de regla de negocio: la comisión de EMPAQUE solo cuenta en
-- Compensación cuando se cumplen LAS DOS condiciones:
--   (i)  el pedido está 100% procesado por Empaque, y
--   (ii) el pedido fue despachado (existe en un despacho confirmado).
--
-- Y el mes al que pertenece esa comisión pasa a ser el MES DEL DESPACHO,
-- no el del movimiento de empaque. Así una comisión nunca aparece
-- retroactivamente dentro de un mes ya cerrado.
--
-- Qué NO cambia:
--   - valor_cop / precio_cop por movimiento: siguen congelándose en el
--     INSERT (trigger de 024). El dinero por registro es el mismo.
--   - vw_compensacion_lineas (025): no se toca. Ya filtra por
--     "fecha_liquidacion is not null", así que hereda el cambio solo.
--   - compensacionPage.js: no se toca. Ya agrupa por claveMes(fecha_liquidacion).
--   - Refilado / Acabado / Mateado: su fecha_liquidacion sigue siendo
--     exactamente la de antes (la del movimiento que cruzó el 100%).
--
-- Nota de RLS: ambas vistas son security_invoker = true y las tablas de
-- despachos solo son legibles por empaque/validador (029). Por eso el
-- join es LEFT y nunca INNER: para un usuario de Refilado el join
-- devuelve 0 filas, pero su rama del CASE no lo usa, así que su
-- compensación queda intacta. El GRANT sí es amplio a authenticated
-- (029:138), de modo que no hay error de permisos, solo cero filas.
-- =====================================================================

-- ---------------------------------------------------------------------
-- vw_pedido_rol_gate — misma firma de columnas que 025 (create or
-- replace no permite renombrar ni reordenar). Solo cambia CÓMO se
-- calcula fecha_liquidacion para el rol 'empaque'.
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
  -- Idéntico al SELECT final de 025, pero nombrando la fecha como
  -- fecha_proceso: sigue siendo "cuándo este rol completó el 100%".
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
  -- Solo despachos CONFIRMADOS. Si un pedido estuviera en varios
  -- despachos (Fase 2 de despachos parciales), se toma el primero.
  select
    do2.order_number,
    min(coalesce(d.confirmed_at, d.created_at)) as fecha_despacho
  from public.despacho_ordenes do2
  join public.despachos d on d.id = do2.despacho_id
  where d.asignacion_confirmada
  group by do2.order_number
)
select
  g.order_number,
  g.rol,
  g.total_solicitado,
  case
    when g.rol = 'empaque' then
      -- Se exigen LAS DOS condiciones: si el pedido no llegó al 100%
      -- procesado, no liquida aunque figure despachado; y si no está
      -- despachado, fecha_despacho es null y tampoco liquida.
      case when g.fecha_proceso is not null then dp.fecha_despacho end
    else
      g.fecha_proceso
  end as fecha_liquidacion
from gate g
left join despacho_por_orden dp on dp.order_number = g.order_number;

grant select on public.vw_pedido_rol_gate to authenticated;

comment on view public.vw_pedido_rol_gate is
  'Fecha de liquidacion por (pedido, rol). Refilado/Acabado/Mateado: fecha en que el rol completo el 100% del pedido. Empaque (fix 040): exige 100% procesado Y despacho confirmado, y la fecha es la DEL DESPACHO. Null = todavia no liquidable.';

-- ---------------------------------------------------------------------
-- vw_historial — se agregan fecha_despacho y despacho_confirmado AL
-- FINAL (create or replace view solo permite agregar columnas al final,
-- nunca reordenar — misma restricción documentada en 026).
--
-- Aquí NO se filtra por asignacion_confirmada: RegistrosO debe poder
-- mostrar el badge "No" si un despacho quedara sin confirmar.
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
  dsp.fecha_despacho,
  dsp.despacho_confirmado
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
  select
    do2.order_number,
    min(coalesce(d.confirmed_at, d.created_at)) as fecha_despacho,
    bool_or(d.asignacion_confirmada)            as despacho_confirmado
  from public.despacho_ordenes do2
  join public.despachos d on d.id = do2.despacho_id
  group by do2.order_number
) dsp on dsp.order_number = h.order_number;

comment on view public.vw_historial is
  'Linea de tiempo combinada de production_movements + returns. Incluye paso_refilado/mateado/acabado/empaque, precio_cop/valor_cop congelados, y (fix 040) fecha_despacho / despacho_confirmado del pedido para la pestana RegistrosO.';
