-- =====================================================================
-- 085_vista_dashboard_proceso.sql
-- Dashboard operativo de Refilado / Acabado / Mateado (fase 1).
-- Vista de SOLO LECTURA. No toca p_pedidosh ni el dashboard 084.
--
-- Una fila por (proceso, pedido) con pendiente > 0:
--   suela, material, color, origen, llegada al area, entrada/salida/
--   pendiente, destino confirmado, y las tallas pendientes en JSON.
-- El numero de pedido viaja para el envio; la UI no lo pinta.
--
-- REGLAS (PLAN_DASHBOARD_PROCESOS.md)
--   * Refilado: entrada = CantidadP. No ve auto-enrutados.
--   * Acabado / Mateado: entrada solo desde Refilado (from_process).
--     Incluye movimientos automaticos (el sistema envio como Refilado).
--   * Sin reproceso / devoluciones.
--   * Sin cierre forzado ni lineas canceladas.
--   * Llegada al area = hora del lote MAS VIEJO que todavia tiene
--     pendiente (FIFO de entradas vs salidas). En Refilado no hay
--     movimiento de entrada: se usa created_at de la linea
--     (o FechaP si no hay created_at). Validar en planta.
--
-- security_invoker: mismas politicas de lectura que las tablas.
-- Reversa: 085_revertir_vista_dashboard_proceso.sql
-- =====================================================================

create or replace view public.vw_dashboard_proceso
with (security_invoker = true)
as
with lineas as (
  -- Una fila por item_id vivo. Si dos lineas compartieran item_id,
  -- nos quedamos con una para no duplicar pendientes.
  select distinct on (p.item_id)
         p."PedidoNo"::text                                   as order_number,
         p.item_id                                            as item_id,
         p."Talla"::text                                      as talla,
         p."NombreR"                                          as nombre_suela,
         p."MaterialP"                                        as material,
         p."ColorP"                                           as color,
         p."Referencia"                                       as referencia,
         coalesce(p."CantidadP", 0)::numeric                  as solicitado,
         coalesce(p.created_at, (p."FechaP")::timestamptz)    as llegada_linea
    from public.p_pedidosh p
   where coalesce(p."Cancelado", false) = false
     and p.item_id is not null
   order by p.item_id, p."Talla"
),
vivas as (
  select l.*
    from lineas l
   where not exists (
           select 1
             from public.pedido_cierre_forzado f
            where f.order_number = l.order_number
         )
),
out_refilado as (
  select m.item_id, sum(m.quantity)::numeric as cantidad
    from public.production_movements m
   where m.from_process = 'Refilado'
     and coalesce(m.es_automatico, false) = false
   group by m.item_id
),
ent_acabado as (
  select m.item_id,
         m.id,
         m.created_at,
         m.quantity::numeric as quantity,
         sum(m.quantity::numeric) over (
           partition by m.item_id
           order by m.created_at, m.id
         ) as acum
    from public.production_movements m
   where m.to_process = 'Acabado'
     and m.from_process = 'Refilado'
),
out_acabado as (
  select m.item_id, sum(m.quantity)::numeric as cantidad
    from public.production_movements m
   where m.from_process = 'Acabado'
   group by m.item_id
),
ent_mateado as (
  select m.item_id,
         m.id,
         m.created_at,
         m.quantity::numeric as quantity,
         sum(m.quantity::numeric) over (
           partition by m.item_id
           order by m.created_at, m.id
         ) as acum
    from public.production_movements m
   where m.to_process = 'Mateado'
     and m.from_process = 'Refilado'
),
out_mateado as (
  select m.item_id, sum(m.quantity)::numeric as cantidad
    from public.production_movements m
   where m.from_process = 'Mateado'
   group by m.item_id
),
llegada_acabado as (
  select e.item_id, min(e.created_at) as llegada_pendiente
    from ent_acabado e
    left join out_acabado o on o.item_id = e.item_id
   where e.acum > coalesce(o.cantidad, 0)
   group by e.item_id
),
llegada_mateado as (
  select e.item_id, min(e.created_at) as llegada_pendiente
    from ent_mateado e
    left join out_mateado o on o.item_id = e.item_id
   where e.acum > coalesce(o.cantidad, 0)
   group by e.item_id
),
in_acabado as (
  select item_id, sum(quantity) as entrada, min(created_at) as primera
    from ent_acabado
   group by item_id
),
in_mateado as (
  select item_id, sum(quantity) as entrada, min(created_at) as primera
    from ent_mateado
   group by item_id
),
talla_refilado as (
  select v.order_number,
         v.item_id,
         v.talla,
         v.nombre_suela,
         v.material,
         v.color,
         v.referencia,
         v.solicitado                                         as entrada,
         coalesce(o.cantidad, 0)                              as salida,
         greatest(v.solicitado - coalesce(o.cantidad, 0), 0)  as pendiente,
         v.llegada_linea                                      as llegada_pendiente
    from vivas v
    left join out_refilado o on o.item_id = v.item_id
    left join public.order_destino d on d.order_number = v.order_number
   where coalesce(d.es_automatico, false) = false
     and greatest(v.solicitado - coalesce(o.cantidad, 0), 0) > 0
),
talla_acabado as (
  select v.order_number,
         v.item_id,
         v.talla,
         v.nombre_suela,
         v.material,
         v.color,
         v.referencia,
         coalesce(i.entrada, 0)                               as entrada,
         coalesce(o.cantidad, 0)                              as salida,
         greatest(coalesce(i.entrada, 0) - coalesce(o.cantidad, 0), 0) as pendiente,
         coalesce(lg.llegada_pendiente, i.primera)            as llegada_pendiente
    from vivas v
    join in_acabado i on i.item_id = v.item_id
    left join out_acabado o on o.item_id = v.item_id
    left join llegada_acabado lg on lg.item_id = v.item_id
   where greatest(coalesce(i.entrada, 0) - coalesce(o.cantidad, 0), 0) > 0
),
talla_mateado as (
  select v.order_number,
         v.item_id,
         v.talla,
         v.nombre_suela,
         v.material,
         v.color,
         v.referencia,
         coalesce(i.entrada, 0)                               as entrada,
         coalesce(o.cantidad, 0)                              as salida,
         greatest(coalesce(i.entrada, 0) - coalesce(o.cantidad, 0), 0) as pendiente,
         coalesce(lg.llegada_pendiente, i.primera)            as llegada_pendiente
    from vivas v
    join in_mateado i on i.item_id = v.item_id
    left join out_mateado o on o.item_id = v.item_id
    left join llegada_mateado lg on lg.item_id = v.item_id
   where greatest(coalesce(i.entrada, 0) - coalesce(o.cantidad, 0), 0) > 0
),
tallas as (
  select 'Refilado'::text as proceso, 'Pedido'::text as origen, t.* from talla_refilado t
  union all
  select 'Acabado'::text, 'Refilado'::text, t.* from talla_acabado t
  union all
  select 'Mateado'::text, 'Refilado'::text, t.* from talla_mateado t
),
pedidos as (
  select
    t.proceso,
    t.origen,
    t.order_number,
    max(t.nombre_suela)                                       as nombre_suela,
    max(t.material)                                           as material,
    max(t.color)                                              as color,
    min(t.llegada_pendiente)                                  as llegada_al_area,
    sum(t.entrada)                                            as entrada,
    sum(t.salida)                                             as salida,
    sum(t.pendiente)                                          as pendiente,
    jsonb_agg(
      jsonb_build_object(
        'item_id', t.item_id,
        'talla', t.talla,
        'entrada', t.entrada,
        'salida', t.salida,
        'pendiente', t.pendiente,
        'referencia', t.referencia
      )
      order by
        case when t.talla ~ '^[0-9]+(\.[0-9]+)?$' then t.talla::numeric end nulls last,
        t.talla
    )                                                         as tallas
    from tallas t
   group by t.proceso, t.origen, t.order_number
)
select
  p.proceso,
  p.origen,
  p.order_number,
  p.nombre_suela,
  p.material,
  p.color,
  p.llegada_al_area,
  p.entrada,
  p.salida,
  p.pendiente,
  p.tallas,
  d.destino,
  coalesce(d.es_automatico, false)                            as destino_es_automatico
from pedidos p
left join public.order_destino d on d.order_number = p.order_number;

grant select on public.vw_dashboard_proceso to authenticated;
revoke select on public.vw_dashboard_proceso from anon;

comment on view public.vw_dashboard_proceso is
  'Dashboard operativo (085): una fila por (proceso, pedido) con pendiente > 0. Tallas en JSON. Refilado no incluye auto-enrutados. Acabado/Mateado solo entran desde Refilado. Solo lectura.';

-- =====================================================================
-- PRUEBAS SEGURAS (solo lectura):
--   select proceso, count(*), sum(pendiente)
--     from public.vw_dashboard_proceso group by 1;
--   select proceso, nombre_suela, material, color, pendiente, destino,
--          jsonb_array_length(tallas) as n_tallas
--     from public.vw_dashboard_proceso
--    where proceso = 'Refilado'
--    order by llegada_al_area nulls last
--    limit 10;
-- =====================================================================
