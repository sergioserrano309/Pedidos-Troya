-- =====================================================================
-- 067_despachado_filtro_cliente.sql
-- Filtro por cliente en Órdenes → Despachos → Despachado.
--
-- El despacho NO tiene cliente propio. El cliente vive en el pedido
-- (p_pedidosh."Cliente"). El vínculo es:
--   despachos → despacho_ordenes.order_number → p_pedidosh."PedidoNo".
-- Un despacho puede mezclar pedidos de varios clientes: entra en el
-- filtro si AL MENOS un pedido es de ese cliente. La fila sigue siendo
-- el despacho completo.
--
-- QUE CAMBIA
--   1. listar_despachos_registro gana p_cliente (igualdad exacta). El
--      recorte de despacho_id sigue ocurriendo ANTES de agregar bultos,
--      kilos, unidades y el badge N de M (mismo diseño que 065).
--   2. Vista vw_clientes_despachados: clientes distintos que ya tienen
--      al menos un despacho, para el desplegable. No es vw_clientes
--      (011), que lista todos los de p_pedidosh aunque nunca se hayan
--      despachado.
--
-- La hora del listado NO es un cambio de base: created_at ya es
-- timestamptz. La columna Hora la pinta solo el listado.
--
-- SECURITY INVOKER: mismas RLS que 065 (empaque / validador / propuesta
-- leen despacho_ordenes; cualquier autenticado lee p_pedidosh).
--
-- REQUIERE 065 (y por tanto 016, 053, 062). Reemplaza la firma de 5
-- argumentos: PostgREST no admite dos sobrecargas si el cliente manda
-- el parámetro nuevo.
-- Reversa: 067_revertir_despachado_filtro_cliente.sql
-- =====================================================================

begin;

drop function if exists public.listar_despachos_registro(text, text, text, integer, integer);

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
  -- Igualdad exacta contra p_pedidosh."Cliente" (el mismo texto del
  -- desplegable). btrim solo decide si el filtro está vacío.
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
       -- Empieza por el índice de cliente y de ahí a despacho_ordenes,
       -- no al revés: si no, un cliente poco frecuente recorrería
       -- despachos recientes hasta llenar la página.
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

-- Clientes que ya salieron en al menos un despacho. DISTINCT: un
-- despacho con varias tallas del mismo pedido no duplica el nombre.
create or replace view public.vw_clientes_despachados
with (security_invoker = true) as
select distinct ph."Cliente" as cliente
  from public.despacho_ordenes o
  join public.p_pedidosh ph
    on ph."PedidoNo"::text = o.order_number
 where ph."Cliente" is not null
   and ph."Cliente" <> ''
 order by 1;

grant select on public.vw_clientes_despachados to authenticated;

comment on view public.vw_clientes_despachados is
  'Clientes distintos con al menos un despacho. Alimenta el filtro de Despachos > Despachado. No incluye clientes que solo tienen pedidos sin despachar (esos están en vw_clientes).';

commit;
