-- =====================================================================
-- 080_vista_pedido_inyeccion.sql
-- Vista de SOLO LECTURA con el avance de Inyeccion (ERP) por pedido,
-- para la vista "Rol Activo: Inyeccion" del Validador en Activas y
-- Completadas (tarjeta de la orden).
--
-- DE DONDE SALE
--   Directo de p_pedidosh: CantidadP (solicitado) y Total01Iny (lo que
--   Access reporta como inyectado, lo actualiza el script de la oficina
--   cada 5 min). No usa movimientos de produccion ni cambia ningun dato.
--
-- COLUMNAS
--   Mismos nombres que usa la tarjeta de la orden (vw_pedido_progreso):
--   order_number, cliente, fecha_pedido, nombre_referencia, material,
--   color, total_solicitado, total_procesado (= inyectado),
--   total_pendiente, porcentaje_completado, estatus_general,
--   etapa_actual ('Inyeccion'), dias_orden, cierre_forzado (siempre false).
--   Asi el listado y los filtros reutilizan el mismo codigo.
--
-- REGLAS
--   - Solo pedidos desde el 3095 (alcance de Inyeccion, igual que el
--     Control Central) y sin lineas canceladas.
--   - % = inyectado / solicitado, entero y con tope 100 (igual que la
--     columna I% de Control Central).
--   - "Completado" = inyectado >= solicitado.
--   - security_invoker: respeta las mismas politicas de lectura de
--     p_pedidosh (incluido el ocultamiento de pedidos anteriores, 058).
--
-- NO TOCA: p_pedidosh, vw_pedido_progreso ni ninguna otra vista.
-- Reversa: 080_revertir_vista_pedido_inyeccion.sql
-- =====================================================================

create or replace view public.vw_pedido_inyeccion
with (security_invoker = true)
as
select
  p."PedidoNo"::text                                  as order_number,
  max(p."Cliente")                                    as cliente,
  max(p."FechaP")                                     as fecha_pedido,
  max(p."NombreR")                                    as nombre_referencia,
  max(p."MaterialP")                                  as material,
  max(p."ColorP")                                     as color,
  sum(coalesce(p."CantidadP", 0))::numeric            as total_solicitado,
  sum(coalesce(p."Total01Iny", 0))::numeric           as total_procesado,
  greatest(sum(coalesce(p."CantidadP", 0)) - sum(coalesce(p."Total01Iny", 0)), 0)::numeric
                                                      as total_pendiente,
  case when sum(coalesce(p."CantidadP", 0)) > 0
    then least(round(sum(coalesce(p."Total01Iny", 0))::numeric / sum(coalesce(p."CantidadP", 0))::numeric * 100), 100)
    else 0
  end                                                 as porcentaje_completado,
  case when sum(coalesce(p."CantidadP", 0)) > 0
        and sum(coalesce(p."Total01Iny", 0)) >= sum(coalesce(p."CantidadP", 0))
    then 'Completado' else 'En Proceso'
  end                                                 as estatus_general,
  'Inyeccion'::text                                   as etapa_actual,
  extract(day from (now() - max(p."FechaP")))::int    as dias_orden,
  false                                               as cierre_forzado
from public.p_pedidosh p
where coalesce(p."Cancelado", false) = false
  and case when p."PedidoNo"::text ~ '^[0-9]+$' then p."PedidoNo"::text::bigint end >= 3095
group by p."PedidoNo"::text;

grant select on public.vw_pedido_inyeccion to authenticated;
revoke select on public.vw_pedido_inyeccion from anon;

comment on view public.vw_pedido_inyeccion is
  'Avance de Inyeccion (ERP) por pedido desde p_pedidosh (CantidadP vs Total01Iny), pedidos >= 3095, sin lineas canceladas. Solo lectura; alimenta la vista Rol Activo = Inyeccion del Validador (080).';

-- =====================================================================
-- PRUEBA SEGURA (solo lectura). Debe devolver filas y los totales
-- deben coincidir con la columna I% de Control Central:
--   select order_number, total_solicitado, total_procesado,
--          porcentaje_completado, estatus_general
--     from public.vw_pedido_inyeccion order by order_number desc limit 10;
--   select estatus_general, count(*) from public.vw_pedido_inyeccion group by 1;
-- =====================================================================
