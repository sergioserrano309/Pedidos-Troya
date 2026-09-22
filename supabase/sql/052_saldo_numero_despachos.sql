-- =====================================================================
-- 052_saldo_numero_despachos.sql
-- vw_item_despacho_saldo gana una columna al final: en cuántos
-- despachos distintos ha salido esa talla de ese pedido. Alimenta la
-- columna "Contador" de "Crear Salida", que deja ver de un vistazo si
-- una talla ya se repartió en varias remesas.
--
-- Se agrega AL FINAL porque create or replace view no permite reordenar
-- ni quitar columnas existentes. El resto de la definición es idéntico
-- a 044.
-- =====================================================================

create or replace view public.vw_item_despacho_saldo
with (security_invoker = true) as
select
  ip.item_id,
  ip.order_number::text                        as order_number,
  ip.talla::text                               as talla,
  ip.referencia,
  ip.material,
  ip.color,
  ip.cantidad_solicitada,
  coalesce(emp.cantidad_empacada, 0)           as cantidad_empacada,
  coalesce(des.cantidad_despachada, 0)         as cantidad_despachada,
  greatest(
    coalesce(emp.cantidad_empacada, 0) - coalesce(des.cantidad_despachada, 0),
    0
  )                                            as cantidad_disponible,
  coalesce(des.numero_despachos, 0)            as numero_despachos
from public.vw_item_progreso ip
left join (
  select item_id, sum(quantity) as cantidad_empacada
  from public.production_movements
  where from_process = 'Empaque'
  group by item_id
) emp on emp.item_id = ip.item_id
left join (
  select
    item_id,
    sum(cantidad)               as cantidad_despachada,
    count(distinct despacho_id) as numero_despachos
  from public.despacho_orden_items
  group by item_id
) des on des.item_id = ip.item_id;

grant select on public.vw_item_despacho_saldo to authenticated;

comment on view public.vw_item_despacho_saldo is
  'Saldo despachable por talla: empacada - despachada = disponible, mas en cuantos despachos distintos ha salido (numero_despachos, 052).';
