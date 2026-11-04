-- =====================================================================
-- 084_vistas_dashboard_unidades.sql
-- Datos del Dashboard de unidades (pestana nueva del Validador).
-- Dos vistas de SOLO LECTURA; no tocan tablas, vistas ni datos existentes.
--
-- vw_dashboard_lineas     una fila por LINEA viva del pedido (pedido x talla):
--                         solicitado, despachado hasta hoy, atributos
--                         (cliente, suela, material, color, vira, acabado,
--                         esterilla, marquilla), fecha del pedido y el
--                         estado del pedido (cerrado a la fuerza / cancelado
--                         en Access).
-- vw_dashboard_despachos  una fila por (despacho x talla) despachada, con la
--                         fecha real del despacho (la del PDF) y los mismos
--                         atributos. Alimenta la lectura "flujo" del Despachado.
--
-- REGLAS (acordadas con el usuario)
--   * Solo pedidos desde el 3095.
--   * Lineas: sin las canceladas (p_pedidosh."Cancelado").
--   * cancelado_access = Access tiene el pedido CANCELADO (erp_cambios tipo
--     'cancelado' sin resolver). El dashboard no cuenta esos pedidos como
--     solicitado ni pendiente; el cruce con Access manda sobre cualquier etiqueta.
--   * cierre_forzado = el pedido esta cerrado a la fuerza (057/072). Cuenta
--     igual; solo se marca para poder filtrarlo.
--   * Despachos eliminados no existen (sus filas se borran al eliminarlos).
--   * Devoluciones no se tocan.
--
-- "Cancelado en Access" se toma de erp_cambios (tipo 'cancelado' en estado
-- pendiente / aplicado / rechazado): 'resuelto' significa que Access ya lo
-- dejo activo otra vez.
--
-- security_invoker: respeta las mismas politicas de lectura de las tablas
-- (el Validador puede leer todas; incluye el ocultamiento de pedidos viejos).
-- Reversa: 084_revertir_vistas_dashboard_unidades.sql
-- =====================================================================

create or replace view public.vw_dashboard_lineas
with (security_invoker = true)
as
with vivas as (
  select p.*
    from public.p_pedidosh p
   where coalesce(p."Cancelado", false) = false
     and case when p."PedidoNo"::text ~ '^[0-9]+$' then p."PedidoNo"::text::bigint end >= 3095
),
despachado as (
  select doi.item_id, sum(doi.cantidad)::numeric as despachado
    from public.despacho_orden_items doi
   group by doi.item_id
),
cancelados as (
  select distinct c.pedido
    from public.erp_cambios c
   where c.tipo = 'cancelado'
     and c.estado in ('pendiente', 'aplicado', 'rechazado')
),
numeradas as (
  -- Si dos lineas vivas compartieran item_id, lo despachado se asigna a UNA
  -- sola para no contarlo dos veces.
  select v.*,
         row_number() over (partition by v.item_id order by v."Talla", v."DetalleVira") as rn
    from vivas v
)
select
  n."PedidoNo"::text                                   as order_number,
  n.item_id                                            as item_id,
  n."Talla"::text                                      as talla,
  n."Cliente"                                          as cliente,
  n."NombreR"                                          as nombre_suela,
  n."MaterialP"                                        as material,
  n."ColorP"                                           as color,
  lower(coalesce(n."Vira"::text, ''))      in ('true', 't', '1', 'si', 'sí') as vira,
  lower(coalesce(n."Acabado"::text, ''))   in ('true', 't', '1', 'si', 'sí') as acabado,
  lower(coalesce(n."Esterilla"::text, '')) in ('true', 't', '1', 'si', 'sí') as esterilla,
  lower(coalesce(n."Marquilla"::text, '')) in ('true', 't', '1', 'si', 'sí') as marquilla,
  n."FechaP"                                           as fecha_pedido,
  coalesce(n."CantidadP", 0)::numeric                  as solicitado,
  case when n.rn = 1 then coalesce(d.despachado, 0) else 0 end as despachado,
  (pcf.order_number is not null)                       as cierre_forzado,
  (can.pedido is not null)                             as cancelado_access
from numeradas n
left join despachado d on d.item_id = n.item_id
left join public.pedido_cierre_forzado pcf on pcf.order_number = n."PedidoNo"::text
left join cancelados can on can.pedido = n."PedidoNo"::text;

grant select on public.vw_dashboard_lineas to authenticated;
revoke select on public.vw_dashboard_lineas from anon;

comment on view public.vw_dashboard_lineas is
  'Dashboard de unidades (084): una fila por linea viva (pedido x talla) desde el 3095, con solicitado, despachado, atributos y estado del pedido (cierre forzado / cancelado en Access). Solo lectura.';

-- ---------------------------------------------------------------------

create or replace view public.vw_dashboard_despachos
with (security_invoker = true)
as
with atributos as (
  -- Atributos por item_id (preferir la linea viva si la linea tambien esta oculta).
  select distinct on (p.item_id)
         p.item_id,
         p."Cliente"    as cliente,
         p."NombreR"    as nombre_suela,
         p."MaterialP"  as material,
         p."ColorP"     as color,
         lower(coalesce(p."Vira"::text, ''))      in ('true', 't', '1', 'si', 'sí') as vira,
         lower(coalesce(p."Acabado"::text, ''))   in ('true', 't', '1', 'si', 'sí') as acabado,
         lower(coalesce(p."Esterilla"::text, '')) in ('true', 't', '1', 'si', 'sí') as esterilla,
         lower(coalesce(p."Marquilla"::text, '')) in ('true', 't', '1', 'si', 'sí') as marquilla,
         p."FechaP"     as fecha_pedido
    from public.p_pedidosh p
   order by p.item_id, coalesce(p."Cancelado", false) asc
),
cancelados as (
  select distinct c.pedido
    from public.erp_cambios c
   where c.tipo = 'cancelado'
     and c.estado in ('pendiente', 'aplicado', 'rechazado')
)
select
  d.consecutivo                                        as consecutivo,
  doi.despacho_id                                      as despacho_id,
  doi.order_number                                     as order_number,
  doi.item_id                                          as item_id,
  doi.talla                                            as talla,
  doi.cantidad::numeric                                as cantidad,
  d.created_at                                         as fecha_despacho,
  a.cliente, a.nombre_suela, a.material, a.color,
  coalesce(a.vira, false)       as vira,
  coalesce(a.acabado, false)    as acabado,
  coalesce(a.esterilla, false)  as esterilla,
  coalesce(a.marquilla, false)  as marquilla,
  a.fecha_pedido,
  (pcf.order_number is not null)                       as cierre_forzado,
  (can.pedido is not null)                             as cancelado_access
from public.despacho_orden_items doi
join public.despachos d on d.id = doi.despacho_id
left join atributos a on a.item_id = doi.item_id
left join public.pedido_cierre_forzado pcf on pcf.order_number = doi.order_number
left join cancelados can on can.pedido = doi.order_number
where case when doi.order_number ~ '^[0-9]+$' then doi.order_number::bigint end >= 3095;

grant select on public.vw_dashboard_despachos to authenticated;
revoke select on public.vw_dashboard_despachos from anon;

comment on view public.vw_dashboard_despachos is
  'Dashboard de unidades (084): una fila por (despacho x talla) con la fecha real del despacho y los atributos del pedido. Solo lectura.';

-- =====================================================================
-- PRUEBAS SEGURAS (solo lectura):
--   -- 1. Totales: deben ser coherentes con lo que ve en Despachos.
--   select sum(solicitado) sol, sum(despachado) desp,
--          sum(greatest(solicitado - despachado, 0)) pend
--     from public.vw_dashboard_lineas where not cancelado_access;
--   -- 2. Lo despachado en flujo no puede ser menor que lo de las lineas vivas:
--   select sum(cantidad) from public.vw_dashboard_despachos;
--   -- 3. Lineas con el mismo item_id (debe dar 0 filas):
--   select item_id, count(*) from public.vw_dashboard_lineas group by 1 having count(*) > 1;
--   -- 4. Cancelados en Access y cuantos de ellos estan cerrados a la fuerza:
--   select count(distinct order_number) pedidos, count(distinct order_number) filter (where cierre_forzado) cerrados
--     from public.vw_dashboard_lineas where cancelado_access;
--   -- 5. Pedido de ejemplo (3478 / 3853):
--   select order_number, talla, solicitado, despachado, cierre_forzado, cancelado_access
--     from public.vw_dashboard_lineas where order_number in ('3478', '3853') order by 1, 2;
-- =====================================================================
