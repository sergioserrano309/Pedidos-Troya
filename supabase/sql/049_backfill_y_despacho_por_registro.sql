-- =====================================================================
-- 049_backfill_y_despacho_por_registro.sql
--
-- 1. RELLENO de despachos creados antes de 044.
--    Esos despachos no tienen filas en despacho_orden_items (la tabla no
--    existia), asi que el sistema los leia como "no salio nada": su
--    pedido reaparecia en "A Despachar", el badge decia No, RegistrosD
--    mostraba 0 unidades y la comision de Empaque del pedido desaparecia.
--    Antes de 044 solo se podian despachar pedidos al 100%, asi que a
--    cada uno se le carga el pedido completo.
--    Idempotente: solo toca despachos que no tienen NINGUNA fila de items.
--
-- 2. ID DE DESPACHO POR REGISTRO (vw_movimiento_despacho).
--    Cada registro de Empaque se asigna al despacho en que salieron sus
--    unidades, en orden de llegada: lo primero empacado es lo primero
--    despachado. Si un registro salio repartido en dos remesas, lleva
--    los dos IDs ("D1021, D1023").
--
-- 3. vw_historial gana dos columnas al final: despacho_consecutivo y
--    despacho_fecha_registro (la fecha de ESA remesa, coherente con el
--    ID). fecha_despacho se conserva tal cual, porque es la que decide
--    el bloqueo de borrado por talla (046) y esa regla no cambia.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Relleno
-- ---------------------------------------------------------------------
insert into public.despacho_orden_items (despacho_id, order_number, item_id, talla, cantidad)
select do2.despacho_id, s.order_number, s.item_id, s.talla, s.cantidad_solicitada
from public.despacho_ordenes do2
join public.vw_item_despacho_saldo s on s.order_number = do2.order_number
where s.cantidad_solicitada > 0
  and not exists (
    select 1 from public.despacho_orden_items x
    where x.despacho_id = do2.despacho_id
  )
on conflict (despacho_id, item_id) do nothing;

-- ---------------------------------------------------------------------
-- 2. Registro de Empaque -> despacho(s), en orden de llegada
--
-- Cada registro ocupa un tramo [desde, hasta) de las unidades empacadas
-- de su talla; cada despacho ocupa un tramo [desde, hasta) de las
-- unidades despachadas de esa misma talla. Un registro pertenece a los
-- despachos cuyos tramos se cruzan con el suyo.
--
-- No excluye es_automatico, igual que cantidad_empacada en
-- vw_item_despacho_saldo (044): ambos deben contar las mismas unidades
-- o los tramos no cuadran.
-- ---------------------------------------------------------------------
create or replace view public.vw_movimiento_despacho
with (security_invoker = true) as
with movs as (
  select
    m.id,
    m.item_id,
    coalesce(sum(m.quantity) over (
      partition by m.item_id order by m.created_at, m.id
      rows between unbounded preceding and 1 preceding
    ), 0) as desde,
    sum(m.quantity) over (
      partition by m.item_id order by m.created_at, m.id
      rows between unbounded preceding and current row
    ) as hasta
  from public.production_movements m
  where m.from_process = 'Empaque'
),
desp as (
  select
    doi.item_id,
    d.consecutivo,
    d.numero_despacho,
    coalesce(d.confirmed_at, d.created_at) as fecha,
    coalesce(sum(doi.cantidad) over (
      partition by doi.item_id order by d.numero_despacho
      rows between unbounded preceding and 1 preceding
    ), 0) as desde,
    sum(doi.cantidad) over (
      partition by doi.item_id order by d.numero_despacho
      rows between unbounded preceding and current row
    ) as hasta
  from public.despacho_orden_items doi
  join public.despachos d on d.id = doi.despacho_id
)
select
  mv.id                                                        as movimiento_id,
  string_agg(dp.consecutivo, ', ' order by dp.numero_despacho) as despacho_consecutivo,
  max(dp.fecha)                                                as despacho_fecha
from movs mv
join desp dp
  on dp.item_id = mv.item_id
 and dp.desde < mv.hasta
 and dp.hasta > mv.desde
group by mv.id;

grant select on public.vw_movimiento_despacho to authenticated;

comment on view public.vw_movimiento_despacho is
  'Despacho(s) en que salieron las unidades de cada registro de Empaque, asignando en orden de llegada (primero empacado, primero despachado).';

-- ---------------------------------------------------------------------
-- 3. vw_historial — mismas columnas que 046 + dos al final
-- ---------------------------------------------------------------------
create or replace view public.vw_historial
with (security_invoker = true) as
select
  h.id,
  h.tipo,
  h.order_number,
  h.item_id,
  h.reference,
  h.size,
  h.quantity,
  h.from_process,
  h.to_process,
  h.causal,
  h.failed_process,
  h.action,
  h.observation,
  h.user_id,
  pr.name as user_name,
  pr.role as user_role,
  h.created_at,
  coalesce(ep.paso_refilado, false) as paso_refilado,
  coalesce(ep.paso_mateado, false) as paso_mateado,
  coalesce(ep.paso_acabado, false) as paso_acabado,
  coalesce(ep.paso_empaque, false) as paso_empaque,
  h.precio_cop,
  h.valor_cop,
  tal.fecha_despacho,
  coalesce(est.pedido_completo, false) as despacho_confirmado,
  (h.tipo = 'movimiento' and exists (
     select 1 from public.production_movements m2
     where m2.item_id = h.item_id and m2.created_at > h.created_at
   )) as tiene_movimiento_posterior,
  md.despacho_consecutivo,
  md.despacho_fecha as despacho_fecha_registro
from (
  select
    m.id,
    'movimiento'::text as tipo,
    m.order_number,
    m.item_id,
    m.reference,
    m.size,
    m.quantity,
    m.from_process,
    m.to_process,
    null::text as causal,
    null::text as failed_process,
    null::text as action,
    m.observation,
    m.user_id,
    m.created_at,
    m.precio_cop,
    m.valor_cop
  from public.production_movements m

  union all

  select
    r.id,
    'devolucion'::text as tipo,
    r.order_number,
    r.item_id,
    null::text as reference,
    r.size,
    r.quantity,
    r.failed_process as from_process,
    coalesce(r.reprocess_destination, 'N/A') as to_process,
    r.causal,
    r.failed_process,
    r.action,
    r.observation,
    r.user_id,
    r.created_at,
    null::numeric as precio_cop,
    null::numeric as valor_cop
  from public.returns r
) h
left join public.profiles pr on pr.id = h.user_id
left join public.vw_pedido_estado_procesos ep on ep.order_number = h.order_number
left join (
  select doi.item_id,
         max(coalesce(d.confirmed_at, d.created_at)) as fecha_despacho
  from public.despacho_orden_items doi
  join public.despachos d on d.id = doi.despacho_id
  group by doi.item_id
) tal on tal.item_id = h.item_id
left join public.vw_pedido_despacho_estado est on est.order_number = h.order_number
left join public.vw_movimiento_despacho md on md.movimiento_id = h.id;

comment on view public.vw_historial is
  'Linea de tiempo de production_movements + returns. fecha_despacho = talla (decide el bloqueo de borrado); despacho_consecutivo / despacho_fecha_registro = remesa concreta de ESTE registro (049); despacho_confirmado = completitud del pedido.';
