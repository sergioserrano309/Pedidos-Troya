-- =====================================================================
-- 054_despacho_orden_detalle.sql
-- Fuente de la hoja "Despachos" del Excel del Validador.
--
-- Una fila por DESPACHO x ORDEN, que es el grano en el que el usuario
-- quiere cruzar todo: cada fila dice que salio de esa orden en esa
-- salida, con que atributos, en que bultos y dentro de que despacho.
--
-- Las columnas de talla NO van aqui: son dinamicas (una por cada talla
-- que exista en la base) y armarlas en SQL exigiria crosstab. Se pivotan
-- en el cliente con despacho_orden_items, que ya es accesible.
--
-- OJO con los totales del despacho (kilos_despacho, unidades_despacho):
-- se REPITEN en cada fila del mismo despacho, por pedido explicito del
-- usuario. Sumarlos en una tabla dinamica multiplica. Los nombres los
-- dicen, y el Excel los rotula igual.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Vira / Acabado / Esterilla / Marquilla se leen como Si/No, igual que
-- en la cartilla de la orden. El repo declara esas columnas como text
-- (009) pero la base real podria tenerlas boolean — ya nos paso con
-- "PedidoNo". El cast a text y la lista de valores falsos cubren los dos
-- casos sin tener que averiguarlo.
-- ---------------------------------------------------------------------
create or replace function public.fn_es_si(p_valor text)
returns boolean
language sql
immutable
as $$
  select case
    when p_valor is null then false
    when lower(btrim(p_valor)) in ('', 'no', 'n', 'false', 'f', '0') then false
    else true
  end;
$$;

comment on function public.fn_es_si(text) is
  'Normaliza a booleano los campos Si/No de p_pedidosh (Vira, Acabado, Esterilla, Marquilla), sirvan como text o como boolean.';

-- ---------------------------------------------------------------------
-- Todas las tallas que existen en la base. El Excel arma una columna por
-- cada una, aunque en un despacho concreto vaya en cero: asi la hoja
-- tiene siempre las mismas columnas y se puede pivotar.
-- ---------------------------------------------------------------------
create or replace view public.vw_tallas_disponibles
with (security_invoker = true) as
select distinct "Talla"::text as talla
from public.p_pedidosh
where "Talla" is not null and btrim("Talla"::text) <> '';

grant select on public.vw_tallas_disponibles to authenticated;

-- ---------------------------------------------------------------------
-- El detalle en si.
-- ---------------------------------------------------------------------
create or replace view public.vw_despacho_orden_detalle
with (security_invoker = true) as
with atributos as (
  select
    "PedidoNo"::text                                as order_number,
    max("Cliente")                                  as cliente,
    max("NombreR")                                  as nombre_referencia,
    max("MaterialP")                                as material,
    max("ColorP")                                   as color,
    bool_or(public.fn_es_si("Vira"::text))          as vira,
    bool_or(public.fn_es_si("Acabado"::text))       as acabado,
    bool_or(public.fn_es_si("Esterilla"::text))     as esterilla,
    bool_or(public.fn_es_si("Marquilla"::text))     as marquilla
  from public.p_pedidosh
  group by "PedidoNo"::text
),
items as (
  select despacho_id, order_number, sum(cantidad) as unidades
    from public.despacho_orden_items
   group by despacho_id, order_number
),
asignaciones as (
  select despacho_id,
         order_number,
         string_agg(bulto_numero::text, ', ' order by bulto_numero) as bultos_asignados,
         count(*)                                                   as numero_bultos
    from public.despacho_orden_bultos
   group by despacho_id, order_number
),
kilos as (
  select despacho_id, sum(peso) as peso_total
    from public.despacho_bultos
   group by despacho_id
),
unidades_despacho as (
  select despacho_id, sum(cantidad) as unidades
    from public.despacho_orden_items
   group by despacho_id
)
select
  d.id                                          as despacho_id,
  d.consecutivo,
  coalesce(d.confirmed_at, d.created_at)        as fecha_despacho,
  d.revisado,
  do2.order_number,
  a.cliente,
  a.nombre_referencia,
  a.material,
  a.color,
  coalesce(a.vira, false)                       as vira,
  coalesce(a.acabado, false)                    as acabado,
  coalesce(a.esterilla, false)                  as esterilla,
  coalesce(a.marquilla, false)                  as marquilla,
  coalesce(i.unidades, 0)                       as unidades_orden_despacho,
  coalesce(asg.bultos_asignados, '')            as bultos_asignados,
  coalesce(asg.numero_bultos, 0)                as numero_bultos,
  coalesce(k.peso_total, 0)                     as kilos_despacho,
  coalesce(ud.unidades, 0)                      as unidades_despacho,
  coalesce(e.porcentaje_despachado, 0)          as porcentaje_despachado,
  coalesce(e.pedido_completo, false)            as pedido_completo
from public.despacho_ordenes do2
join public.despachos d on d.id = do2.despacho_id
-- "PedidoNo" es bigint en la base real aunque 009 lo declare text: el
-- join va contra la version ya casteada del CTE.
left join atributos a           on a.order_number   = do2.order_number
left join items i               on i.despacho_id    = do2.despacho_id
                               and i.order_number   = do2.order_number
left join asignaciones asg      on asg.despacho_id  = do2.despacho_id
                               and asg.order_number = do2.order_number
left join kilos k               on k.despacho_id    = d.id
left join unidades_despacho ud  on ud.despacho_id   = d.id
left join public.vw_pedido_despacho_estado e on e.order_number = do2.order_number;

grant select on public.vw_despacho_orden_detalle to authenticated;

comment on view public.vw_despacho_orden_detalle is
  'Una fila por despacho x orden para la hoja Despachos del Excel. kilos_despacho y unidades_despacho son totales DEL DESPACHO repetidos en cada fila: no se deben sumar.';
