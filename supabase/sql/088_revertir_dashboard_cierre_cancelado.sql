-- Reversa de 088: vuelve las dos vistas del dashboard a como quedaron en 084
-- (cancelado_access = solo lo cancelado en Access). No toca datos.
-- Hacer esto ANTES de revertir 087 (la columna tipo_cierre no se puede borrar
-- mientras una vista la use).

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
