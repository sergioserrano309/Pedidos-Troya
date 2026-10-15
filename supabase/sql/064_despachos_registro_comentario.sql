-- =====================================================================
-- 064_despachos_registro_comentario.sql
-- Expone despachos.comentario en vw_despachos_registro para que el
-- listado Despachos > Despachado pueda mostrar un indicador (icono)
-- cuando la salida tiene comentario, sin consultar la tabla aparte.
--
-- QUE CAMBIA
--   vw_despachos_registro gana la columna comentario AL FINAL (create
--   or replace permite agregar al final; no reordena ni renombra).
--
-- REQUIERE 062 (columna despachos.comentario) y la vista de 053.
-- NO TOCA RLS, RPCs ni datos existentes.
-- =====================================================================

begin;

create or replace view public.vw_despachos_registro
with (security_invoker = true) as
with ordenes as (
  select do2.despacho_id,
         count(*)                                              as numero_ordenes,
         array_agg(do2.order_number order by do2.order_number)  as order_numbers,
         count(*) filter (where e.pedido_completo)              as pedidos_completos
    from public.despacho_ordenes do2
    left join public.vw_pedido_despacho_estado e on e.order_number = do2.order_number
   group by do2.despacho_id
),
bultos as (
  select db.despacho_id, sum(db.peso) as peso_total
    from public.despacho_bultos db
   group by db.despacho_id
),
unidades as (
  select doi.despacho_id, sum(doi.cantidad) as total_unidades
    from public.despacho_orden_items doi
   group by doi.despacho_id
)
select d.id,
       d.numero_despacho,
       d.consecutivo,
       d.created_at,
       d.created_by,
       pr.name                                       as creado_por_nombre,
       d.total_bultos,
       coalesce(b.peso_total, 0)                     as peso_total,
       coalesce(o.numero_ordenes, 0)                 as numero_ordenes,
       coalesce(o.order_numbers, array[]::text[])    as order_numbers,
       coalesce(u.total_unidades, 0)                 as total_unidades,
       coalesce(o.pedidos_completos, 0)              as pedidos_completos,
       d.asignacion_confirmada,
       d.confirmed_at,
       d.revisado,
       d.revisado_at,
       rv.name                                       as revisado_por_nombre,
       d.comentario
  from public.despachos d
  left join public.profiles pr on pr.id = d.created_by
  left join public.profiles rv on rv.id = d.revisado_por
  left join ordenes  o on o.despacho_id = d.id
  left join bultos   b on b.despacho_id = d.id
  left join unidades u on u.despacho_id = d.id;

grant select on public.vw_despachos_registro to authenticated;

comment on view public.vw_despachos_registro is
  'Una fila por despacho. total_unidades = lo realmente despachado (despacho_orden_items), no el total del pedido. pedidos_completos alimenta el contador "N de M completos". revisado es el visto bueno del Validador (053). comentario es el texto opcional de la salida (062/064).';

commit;
