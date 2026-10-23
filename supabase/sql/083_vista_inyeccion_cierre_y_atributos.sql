-- =====================================================================
-- 083_vista_inyeccion_cierre_y_atributos.sql
-- Ajusta la vista Inyeccion (080) para que se comporte como las demas:
--
--   1. CIERRE FORZADO / CANCELADOS: un pedido cerrado a la fuerza (057), lo
--      que incluye los cancelados en Access que el sistema cierra con
--      "Cancelado en Troya" (072), ya NO aparece en Activas de Inyeccion y
--      pasa a Completadas, igual que en las otras vistas. Se agregan
--      cierre_forzado (real, antes era siempre false), cierre_forzado_motivo,
--      cierre_forzado_at y cierre_forzado_por.
--   2. FILTROS Si/No: se agregan vira, acabado, esterilla y marquilla por
--      pedido (alguna linea = Si), como en vw_pedido_progreso_atributos (082).
--
-- Es la misma vista de 080 con columnas nuevas al final (create or replace;
-- las columnas existentes no cambian de orden ni de tipo). Solo lectura.
-- Reversa: 083_revertir_vista_inyeccion_cierre_y_atributos.sql (deja la
-- vista como quedo en 080).
-- =====================================================================

create or replace view public.vw_pedido_inyeccion
with (security_invoker = true)
as
with g as (
  select
    p."PedidoNo"::text                                  as order_number,
    max(p."Cliente")                                    as cliente,
    max(p."FechaP")                                     as fecha_pedido,
    max(p."NombreR")                                    as nombre_referencia,
    max(p."MaterialP")                                  as material,
    max(p."ColorP")                                     as color,
    sum(coalesce(p."CantidadP", 0))                     as solicitado,
    sum(coalesce(p."Total01Iny", 0))                    as inyectado,
    bool_or(lower(coalesce(p."Vira"::text, ''))      in ('true', 't', '1', 'si', 'sí')) as vira,
    bool_or(lower(coalesce(p."Acabado"::text, ''))   in ('true', 't', '1', 'si', 'sí')) as acabado,
    bool_or(lower(coalesce(p."Esterilla"::text, '')) in ('true', 't', '1', 'si', 'sí')) as esterilla,
    bool_or(lower(coalesce(p."Marquilla"::text, '')) in ('true', 't', '1', 'si', 'sí')) as marquilla
  from public.p_pedidosh p
  where coalesce(p."Cancelado", false) = false
    and case when p."PedidoNo"::text ~ '^[0-9]+$' then p."PedidoNo"::text::bigint end >= 3095
  group by p."PedidoNo"::text
)
select
  g.order_number,
  g.cliente,
  g.fecha_pedido,
  g.nombre_referencia,
  g.material,
  g.color,
  g.solicitado::numeric                               as total_solicitado,
  g.inyectado::numeric                                as total_procesado,
  greatest(g.solicitado - g.inyectado, 0)::numeric    as total_pendiente,
  case when g.solicitado > 0
    then least(round(g.inyectado::numeric / g.solicitado::numeric * 100), 100)
    else 0
  end                                                 as porcentaje_completado,
  case when g.solicitado > 0 and g.inyectado >= g.solicitado
    then 'Completado' else 'En Proceso'
  end                                                 as estatus_general,
  'Inyeccion'::text                                   as etapa_actual,
  extract(day from (now() - g.fecha_pedido))::int     as dias_orden,
  (pcf.order_number is not null)                      as cierre_forzado,
  -- Nuevas (083), siempre al final:
  pcf.motivo                                          as cierre_forzado_motivo,
  pcf.cerrado_at                                      as cierre_forzado_at,
  cpr.name                                            as cierre_forzado_por,
  coalesce(g.vira, false)                             as vira,
  coalesce(g.acabado, false)                          as acabado,
  coalesce(g.esterilla, false)                        as esterilla,
  coalesce(g.marquilla, false)                        as marquilla
from g
left join public.pedido_cierre_forzado pcf on pcf.order_number = g.order_number
left join public.profiles cpr on cpr.id = pcf.cerrado_por;

grant select on public.vw_pedido_inyeccion to authenticated;
revoke select on public.vw_pedido_inyeccion from anon;

comment on view public.vw_pedido_inyeccion is
  'Avance de Inyeccion (ERP) por pedido desde p_pedidosh (CantidadP vs Total01Iny), pedidos >= 3095, sin lineas canceladas. Incluye cierre forzado (057/072) y vira/acabado/esterilla/marquilla (083). Solo lectura.';

-- =====================================================================
-- PRUEBA SEGURA (solo lectura):
--   -- El 3853 (cancelado en Access) debe salir con cierre_forzado = true:
--   select order_number, porcentaje_completado, cierre_forzado, cierre_forzado_motivo
--     from public.vw_pedido_inyeccion where order_number = '3853';
--   -- Cuantos pedidos cerrados a la fuerza hay (debe coincidir con la tabla):
--   select count(*) from public.vw_pedido_inyeccion where cierre_forzado;
-- =====================================================================
