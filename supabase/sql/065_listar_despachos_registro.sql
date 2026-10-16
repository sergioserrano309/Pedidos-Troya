-- =====================================================================
-- 065_listar_despachos_registro.sql
-- RPC de lectura para el acordeón Despachos > Despachado.
--
-- PROBLEMA
--   El listado llamaba vw_despachos_registro con LIMIT 30 al final.
--   Esa vista agrega TODOS los despachos (órdenes, bultos, unidades) y
--   para el badge "N de M completos" se une a vw_pedido_despacho_estado,
--   que a su vez recorre vw_item_despacho_saldo → vw_item_progreso →
--   production_movements. Filtrar por orden iba sobre el arreglo ya
--   armado (order_numbers @> {3449}), así que el índice
--   idx_despacho_ordenes_order_number no se usaba. Paginar no recortaba
--   el trabajo: cada tecla del filtro reconstruía el universo entero.
--
-- QUE CAMBIA
--   1. Primero se eligen los despacho_id (fecha / consecutivo / orden
--      vía despacho_ordenes.order_number) y se recortan con
--      ORDER BY created_at DESC LIMIT/OFFSET.
--   2. Recién después se agregan bultos, kilos, unidades y la lista de
--      órdenes, SOLO para esos ids (CTE filtrados MATERIALIZED).
--   3. pedido_completo se calcula solo para los pedidos de esa página,
--      comparando p_pedidosh vs despacho_orden_items, sin pasar por
--      vw_item_progreso.
--
-- NO TOCA vw_despachos_registro (064): sigue existiendo. El frontend
-- usa este RPC y, si aún no está aplicado, cae a la vista.
--
-- SECURITY INVOKER: mismas políticas RLS que la vista (empaque /
-- validador / propuesta). No abre escritura.
--
-- REQUIERE 016 (item_id en p_pedidosh), 053 (revisado) y 062 (comentario).
-- Reversa: 065_revertir_listar_despachos_registro.sql
-- =====================================================================

begin;

create or replace function public.listar_despachos_registro(
  p_orden text default '',
  p_fecha text default '',
  p_consecutivo text default '',
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
       -- Mismo criterio que el cliente (ILIKE sobre D1021). El recorte
       -- de 31 filas ya ocurrió: un seq scan de despachos es barato.
       and (v_consecutivo = '' or d.consecutivo ilike '%' || v_consecutivo || '%')
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

grant execute on function public.listar_despachos_registro(text, text, text, integer, integer)
  to authenticated;

comment on function public.listar_despachos_registro(text, text, text, integer, integer) is
  'Listado paginado de Despachos > Despachado. Recorta despacho_id (orden exacta / fecha / consecutivo) ANTES de agregar bultos, kilos, unidades y el badge N de M. Misma forma de fila que vw_despachos_registro (064).';

commit;
