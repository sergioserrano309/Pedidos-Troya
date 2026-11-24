-- =====================================================================
-- 091_revertir_envio_enrutado_manual.sql
-- Deja el enrutamiento como estaba antes del 091:
--   - fn_auto_enrutar_pedido() vuelve a aplicar las REGLAS (013) a pedidos nuevos.
--   - Se quitan enrutar_pedido_manual y deshacer_envio_enrutado.
--   - vw_pedido_progreso conserva las 2 columnas nuevas (una vista no puede perder
--     columnas con create or replace) pero quedan vacias (false / null).
--   - Las columnas order_destino.enrutado_por/enrutado_at NO se borran (inofensivas).
-- No borra datos: los pedidos ya enviados con Envio Enrutado siguen siendo
-- movimientos automaticos, igual que los de una regla.
-- =====================================================================

begin;

create or replace function public.fn_auto_enrutar_pedido()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.aplicar_regla_enrutamiento(NEW);
  return NEW;
end;
$$;

drop function if exists public.enrutar_pedido_manual(text, text);
drop function if exists public.deshacer_envio_enrutado(text);

create or replace view public.vw_pedido_progreso
with (security_invoker = true)
as
with orden_progreso as (
  select
    order_number::text as order_number,
    max(cliente)        as cliente,
    max(fecha_pedido)   as fecha_pedido,
    max(nombre_referencia) as nombre_referencia,
    max(material)       as material,
    max(color)          as color,
    count(*)            as total_items,
    sum(cantidad_solicitada) as total_solicitado,
    sum(cantidad_devuelta)   as total_devuelto,
    case
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 4 then 'E'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 3 then 'A'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 2 then 'M'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 1 then 'R'
      else 'Sin Procesar'
    end as etapa_actual
  from public.vw_item_progreso
  group by order_number::text
),
movimientos_orden_calc as (
  select
    order_number::text as order_number,
    sum(quantity) filter (where to_process = 'Refilado')   as in_refilado,
    sum(quantity) filter (where to_process = 'Acabado')    as in_acabado,
    sum(quantity) filter (where to_process = 'Mateado')    as in_mateado,
    sum(quantity) filter (where to_process = 'Empaque')    as in_empaque,
    sum(quantity) filter (where from_process = 'Refilado' and not es_automatico) as out_refilado,
    sum(quantity) filter (where from_process = 'Acabado')  as out_acabado,
    sum(quantity) filter (where from_process = 'Mateado')  as out_mateado,
    sum(quantity) filter (where from_process = 'Empaque')  as out_empaque,
    max(created_at) filter (where to_process = 'Empaque')  as fecha_fin
  from public.production_movements
  group by order_number::text
),
destino_calc as (
  select order_number, es_automatico
  from public.order_destino
),
-- NUEVO (090): una fila por TALLA. Las lineas que comparten item_id comparten
-- movimientos, asi que se suman sus pedidos y se cuentan una sola vez.
tallas as (
  -- Misma fuente y mismo filtro (sin canceladas) que vw_item_progreso, pero sin
  -- recorrer sus agregados otra vez (esta vista es la central de la app).
  select
    p."PedidoNo"::text as order_number,
    p.item_id,
    sum(coalesce(p."CantidadP", 0)) as sol
  from public.p_pedidosh p
  where coalesce(p."Cancelado", false) = false
  group by p."PedidoNo"::text, p.item_id
),
mov_talla as (
  select
    m.item_id,
    sum(m.quantity) filter (where m.to_process = 'Refilado')   as in_r,
    sum(m.quantity) filter (where m.from_process = 'Refilado' and not m.es_automatico) as out_r,
    sum(m.quantity) filter (where m.from_process = 'Acabado')  as out_a,
    sum(m.quantity) filter (where m.from_process = 'Mateado')  as out_m,
    sum(m.quantity) filter (where m.from_process = 'Empaque')  as out_e
  from public.production_movements m
  group by m.item_id
),
cobertura as (
  select
    t.order_number,
    count(*) as n_tallas,
    -- Refilado: lo que debe cubrir cada talla es lo pedido + lo que le regresaron
    sum(t.sol + coalesce(x.in_r, 0))                                 as base_r,
    sum(least(coalesce(x.out_r, 0), t.sol + coalesce(x.in_r, 0)))    as cub_r,
    sum(greatest(t.sol + coalesce(x.in_r, 0) - coalesce(x.out_r, 0), 0)) as pend_r,
    count(*) filter (where coalesce(x.out_r, 0) >= t.sol + coalesce(x.in_r, 0)) as ok_r,
    -- Acabado / Mateado / Empaque: lo pedido por talla
    sum(least(coalesce(x.out_a, 0), t.sol))                          as cub_a,
    sum(greatest(t.sol - coalesce(x.out_a, 0), 0))                   as pend_a,
    count(*) filter (where coalesce(x.out_a, 0) >= t.sol)            as ok_a,
    sum(least(coalesce(x.out_m, 0), t.sol))                          as cub_m,
    sum(greatest(t.sol - coalesce(x.out_m, 0), 0))                   as pend_m,
    count(*) filter (where coalesce(x.out_m, 0) >= t.sol)            as ok_m,
    sum(least(coalesce(x.out_e, 0), t.sol))                          as cub_e,
    sum(greatest(t.sol - coalesce(x.out_e, 0), 0))                   as pend_e,
    count(*) filter (where coalesce(x.out_e, 0) >= t.sol)            as ok_e
  from tallas t
  left join mov_talla x on x.item_id = t.item_id
  group by t.order_number
)
select
  op.order_number,
  op.cliente,
  op.fecha_pedido,
  op.nombre_referencia,
  op.material,
  op.color,
  op.total_solicitado,
  coalesce(mo.out_empaque, 0)::numeric as total_procesado,
  op.total_devuelto,
  -- Lo que falta, TALLA POR TALLA (un exceso en una talla no tapa otra).
  coalesce(cb.pend_e, 0)::numeric as total_pendiente,
  case when op.total_solicitado > 0
    then (case when coalesce(cb.cub_e, 0) >= op.total_solicitado then 100
               else least(round(coalesce(cb.cub_e, 0)::numeric / op.total_solicitado::numeric * 100), 99) end)
    else 0
  end as porcentaje_completado,
  case
    when op.total_solicitado > 0 and coalesce(cb.ok_e, 0) = coalesce(cb.n_tallas, -1) then 'Completado'
    else 'En Proceso'
  end as estatus_general,
  case
    when op.total_solicitado > 0 and coalesce(cb.ok_e, 0) = coalesce(cb.n_tallas, -1) then 'Fin'
    else coalesce(op.etapa_actual, 'R')
  end as etapa_actual,
  extract(day from (case when op.total_solicitado > 0 and coalesce(cb.ok_e, 0) = coalesce(cb.n_tallas, -1) and mo.fecha_fin is not null then mo.fecha_fin else now() end) - op.fecha_pedido)::int as dias_orden,
  (op.total_solicitado + coalesce(mo.in_refilado, 0)) as total_refilado,
  coalesce(mo.out_refilado, 0) as procesado_refilado,
  coalesce(cb.pend_r, 0)::numeric as pendiente_refilado,
  case when coalesce(cb.base_r, 0) > 0
    then (case when coalesce(cb.cub_r, 0) >= cb.base_r then 100
               else least(round(coalesce(cb.cub_r, 0)::numeric / cb.base_r::numeric * 100), 99) end)
    else 0
  end as porcentaje_refilado,
  coalesce(mo.in_acabado, 0) as entrada_acabado,
  op.total_solicitado as total_acabado,
  coalesce(mo.out_acabado, 0) as procesado_acabado,
  coalesce(cb.pend_a, 0)::numeric as pendiente_acabado,
  case when op.total_solicitado > 0
    then (case when coalesce(cb.cub_a, 0) >= op.total_solicitado then 100
               else least(round(coalesce(cb.cub_a, 0)::numeric / op.total_solicitado::numeric * 100), 99) end)
    else 0
  end as porcentaje_acabado,
  coalesce(mo.in_mateado, 0) as entrada_mateado,
  op.total_solicitado as total_mateado,
  coalesce(mo.out_mateado, 0) as procesado_mateado,
  coalesce(cb.pend_m, 0)::numeric as pendiente_mateado,
  case when op.total_solicitado > 0
    then (case when coalesce(cb.cub_m, 0) >= op.total_solicitado then 100
               else least(round(coalesce(cb.cub_m, 0)::numeric / op.total_solicitado::numeric * 100), 99) end)
    else 0
  end as porcentaje_mateado,
  coalesce(mo.in_empaque, 0) as entrada_empaque,
  op.total_solicitado as total_empaque,
  coalesce(mo.out_empaque, 0) as procesado_empaque,
  coalesce(cb.pend_e, 0)::numeric as pendiente_empaque,
  case when op.total_solicitado > 0
    then (case when coalesce(cb.cub_e, 0) >= op.total_solicitado then 100
               else least(round(coalesce(cb.cub_e, 0)::numeric / op.total_solicitado::numeric * 100), 99) end)
    else 0
  end as porcentaje_empaque,
  dc.es_automatico as destino_es_automatico,
  -- 057, siempre al final:
  (pcf.order_number is not null) as cierre_forzado,
  pcf.motivo                     as cierre_forzado_motivo,
  pcf.cerrado_at                 as cierre_forzado_at,
  cpr.name                       as cierre_forzado_por,
  -- NUEVAS (090): tallas con el proceso cubierto / tallas del pedido.
  coalesce(cb.n_tallas, 0)::bigint as tallas_total,
  coalesce(cb.ok_r, 0)::bigint     as tallas_ok_refilado,
  coalesce(cb.ok_a, 0)::bigint     as tallas_ok_acabado,
  coalesce(cb.ok_m, 0)::bigint     as tallas_ok_mateado,
  coalesce(cb.ok_e, 0)::bigint     as tallas_ok_empaque,
  -- NUEVAS (091): el pedido fue enviado con "Envio Enrutado" por Refilado (no por una regla).
  false                            as enrutado_manual,
  null::text                       as enrutado_destino
from orden_progreso op
left join movimientos_orden_calc mo on mo.order_number = op.order_number
left join destino_calc dc on dc.order_number = op.order_number
left join cobertura cb on cb.order_number = op.order_number
left join public.pedido_cierre_forzado pcf on pcf.order_number = op.order_number
left join public.profiles cpr on cpr.id = pcf.cerrado_por;

;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo (090). enrutado_manual/enrutado_destino quedaron vacias al revertir 091.';

drop view if exists public.vw_pedido_progreso_atributos;

create view public.vw_pedido_progreso_atributos
with (security_invoker = true)
as
select
  vp.*,
  coalesce(a.vira, false)       as vira,
  coalesce(a.acabado, false)    as acabado,
  coalesce(a.esterilla, false)  as esterilla,
  coalesce(a.marquilla, false)  as marquilla
from public.vw_pedido_progreso vp
left join (
  select
    p."PedidoNo"::text as order_number,
    bool_or(lower(coalesce(p."Vira"::text, ''))       in ('true', 't', '1', 'si', 'sí')) as vira,
    bool_or(lower(coalesce(p."Acabado"::text, ''))    in ('true', 't', '1', 'si', 'sí')) as acabado,
    bool_or(lower(coalesce(p."Esterilla"::text, ''))  in ('true', 't', '1', 'si', 'sí')) as esterilla,
    bool_or(lower(coalesce(p."Marquilla"::text, ''))  in ('true', 't', '1', 'si', 'sí')) as marquilla
  from public.p_pedidosh p
  where coalesce(p."Cancelado", false) = false
  group by p."PedidoNo"::text
) a on a.order_number = vp.order_number;

grant select on public.vw_pedido_progreso_atributos to authenticated;
revoke select on public.vw_pedido_progreso_atributos from anon;

comment on view public.vw_pedido_progreso_atributos is
  'vw_pedido_progreso + vira/acabado/esterilla/marquilla por pedido (alguna linea = Si). Solo lectura; la usan los filtros Si/No (082, recreada en 090 para incluir las columnas tallas_*).';

commit;
