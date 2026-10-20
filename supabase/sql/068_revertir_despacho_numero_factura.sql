-- =====================================================================
-- 068_revertir_despacho_numero_factura.sql
-- Deshace 068: quita editar_factura_despacho, restaura listar a la
-- firma de 067 (sin p_factura ni numero_factura), vuelve a pintar
-- vw_despachos_registro como en 064 y elimina la columna.
--
-- No borra filas de audit_validador con accion editar_factura_despacho.
-- =====================================================================

begin;

drop function if exists public.editar_factura_despacho(uuid, text);

drop function if exists public.listar_despachos_registro(text, text, text, text, text, integer, integer);

create or replace function public.listar_despachos_registro(
  p_orden text default '',
  p_fecha text default '',
  p_consecutivo text default '',
  p_cliente text default '',
  p_offset integer default 0,
  p_limit integer default 31
)
returns table (
  id uuid,
  numero_despacho integer,
  consecutivo text,
  created_at timestamptz,
  created_by uuid,
  creado_por_nombre text,
  total_bultos integer,
  peso_total numeric,
  numero_ordenes bigint,
  order_numbers text[],
  total_unidades bigint,
  pedidos_completos bigint,
  asignacion_confirmada boolean,
  confirmed_at timestamptz,
  revisado boolean,
  revisado_at timestamptz,
  revisado_por_nombre text,
  comentario text
)
language plpgsql
stable
security invoker
set search_path = public
as $$
declare
  v_orden text := btrim(coalesce(p_orden, ''));
  v_fecha_txt text := btrim(coalesce(p_fecha, ''));
  v_fecha date;
  v_consecutivo text := btrim(coalesce(p_consecutivo, ''));
  v_cliente text := coalesce(p_cliente, '');
  v_offset integer := greatest(0, coalesce(p_offset, 0));
  v_limit integer := greatest(1, least(coalesce(p_limit, 31), 100));
begin
  if v_fecha_txt <> '' then
    v_fecha := v_fecha_txt::date;
  end if;

  return query
  with filtrados as materialized (
    select d.id,
           d.numero_despacho,
           d.consecutivo,
           d.created_at,
           d.created_by,
           d.total_bultos,
           d.asignacion_confirmada,
           d.confirmed_at,
           d.revisado,
           d.revisado_at,
           d.revisado_por,
           d.comentario
      from public.despachos d
     where (v_orden = '' or exists (
             select 1
               from public.despacho_ordenes o
              where o.despacho_id = d.id
                and o.order_number = v_orden
           ))
       and (v_fecha_txt = '' or (
             d.created_at >= v_fecha::timestamp
             and d.created_at < (v_fecha + 1)::timestamp
           ))
       and (v_consecutivo = '' or d.consecutivo ilike '%' || v_consecutivo || '%')
       and (btrim(v_cliente) = '' or d.id in (
             select oc.despacho_id
               from public.p_pedidosh ph
               join public.despacho_ordenes oc
                 on oc.order_number = ph."PedidoNo"::text
              where ph."Cliente" = v_cliente
           ))
     order by d.created_at desc
     limit v_limit
    offset v_offset
  ),
  pedidos_pagina as (
    select distinct o.order_number
      from public.despacho_ordenes o
     where o.despacho_id in (select f.id from filtrados f)
  ),
  solicitado as (
    select ph."PedidoNo"::text as order_number,
           ph.item_id,
           coalesce(ph."CantidadP", 0) as solicitada
      from public.p_pedidosh ph
     where ph."PedidoNo"::text in (select p.order_number from pedidos_pagina p)
       and coalesce(ph."Cancelado", false) = false
  ),
  despachado as (
    select doi.item_id,
           sum(doi.cantidad) as despachada
      from public.despacho_orden_items doi
     where doi.order_number in (select p.order_number from pedidos_pagina p)
     group by doi.item_id
  ),
  estado as (
    select s.order_number,
           (bool_and(coalesce(des.despachada, 0) >= s.solicitada)
            and sum(coalesce(des.despachada, 0)) > 0) as pedido_completo
      from solicitado s
      left join despachado des on des.item_id = s.item_id
     group by s.order_number
  ),
  ordenes as (
    select o.despacho_id,
           count(*) as numero_ordenes,
           array_agg(o.order_number order by o.order_number) as order_numbers,
           count(*) filter (where coalesce(e.pedido_completo, false)) as pedidos_completos
      from public.despacho_ordenes o
      left join estado e on e.order_number = o.order_number
     where o.despacho_id in (select f.id from filtrados f)
     group by o.despacho_id
  ),
  bultos as (
    select db.despacho_id,
           sum(db.peso) as peso_total
      from public.despacho_bultos db
     where db.despacho_id in (select f.id from filtrados f)
     group by db.despacho_id
  ),
  unidades as (
    select doi.despacho_id,
           sum(doi.cantidad)::bigint as total_unidades
      from public.despacho_orden_items doi
     where doi.despacho_id in (select f.id from filtrados f)
     group by doi.despacho_id
  )
  select f.id,
         f.numero_despacho,
         f.consecutivo,
         f.created_at,
         f.created_by,
         pr.name as creado_por_nombre,
         f.total_bultos,
         coalesce(b.peso_total, 0)::numeric as peso_total,
         coalesce(ord.numero_ordenes, 0) as numero_ordenes,
         coalesce(ord.order_numbers, array[]::text[]) as order_numbers,
         coalesce(u.total_unidades, 0) as total_unidades,
         coalesce(ord.pedidos_completos, 0) as pedidos_completos,
         f.asignacion_confirmada,
         f.confirmed_at,
         f.revisado,
         f.revisado_at,
         rv.name as revisado_por_nombre,
         f.comentario
    from filtrados f
    left join public.profiles pr on pr.id = f.created_by
    left join public.profiles rv on rv.id = f.revisado_por
    left join ordenes ord on ord.despacho_id = f.id
    left join bultos b on b.despacho_id = f.id
    left join unidades u on u.despacho_id = f.id
   order by f.created_at desc;
end;
$$;

grant execute on function public.listar_despachos_registro(text, text, text, text, integer, integer)
  to authenticated;

comment on function public.listar_despachos_registro(text, text, text, text, integer, integer) is
  'Listado paginado de Despachos > Despachado. Recorta despacho_id (orden exacta / fecha / consecutivo / cliente exacto vía p_pedidosh) ANTES de agregar. Un despacho con varios clientes entra si alguno coincide. Misma forma de fila que 065.';

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

alter table public.despachos
  drop constraint if exists despachos_numero_factura_formato;

alter table public.despachos
  drop column if exists numero_factura;

commit;
