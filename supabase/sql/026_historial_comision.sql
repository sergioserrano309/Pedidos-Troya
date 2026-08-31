-- =====================================================================
-- 026_historial_comision.sql
-- Agrega 2 columnas a vw_historial (precio_cop, valor_cop) para que
-- Registros muestre, por cada registro de produccion, el valor por par
-- y el total (P*Q) ya congelado — visible SIEMPRE, exista o no haya
-- terminado el pedido (es pura informacion de seguimiento 1 a 1, no
-- depende de si ese pedido+rol ya es liquidable para Compensacion, ver
-- 025_compensacion_vistas.sql).
--
-- IMPORTANTE: la definicion de vw_historial en el repo (005_views_dashboard.sql)
-- estaba DESACTUALIZADA respecto a la base de datos real — en algun
-- momento se agrego, fuera de las migraciones versionadas, un
-- LEFT JOIN a vw_pedido_estado_procesos (columnas paso_refilado/
-- paso_mateado/paso_acabado/paso_empaque, usadas por historyPage.js
-- para los badges de Validador). Este archivo reemplaza vw_historial
-- preservando EXACTAMENTE esa estructura real (confirmada via
-- pg_get_viewdef en Supabase antes de escribir esto), solo agregando
-- precio_cop/valor_cop — no se toca vw_pedido_estado_procesos, que
-- sigue definida donde sea que haya quedado.
--
-- OJO: precio_cop/valor_cop van AL FINAL de la lista de columnas, no en
-- medio. CREATE OR REPLACE VIEW no permite reordenar columnas
-- existentes (falla con "cannot change name of view column X to Y" si
-- una columna vieja queda en una posicion distinta) — solo permite
-- AGREGAR columnas nuevas al final.
-- =====================================================================

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
  h.valor_cop
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
left join public.vw_pedido_estado_procesos ep on ep.order_number = h.order_number;

comment on view public.vw_historial is
  'Linea de tiempo combinada de production_movements + returns para la pantalla de Historial. Inmutable (solo SELECT). Incluye paso_refilado/mateado/acabado/empaque (via vw_pedido_estado_procesos) y precio_cop/valor_cop ya congelados para movimientos (null para devoluciones/automaticos, fix 026).';
