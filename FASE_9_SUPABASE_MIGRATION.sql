-- =====================================================================
-- FASE 9: SUPABASE MIGRATION
-- 1. Agrega "nombre_referencia" (NombreR) a vw_pedido_progreso, para el
--    nuevo filtro/columna "Nombre Suela" en el listado de órdenes.
-- 2. Crea la tabla order_destino: Refilado confirma UNA SOLA VEZ el
--    destino (Acabado/Mateado/Empaque) de TODO un pedido, desde el
--    encabezado del detalle de la orden.
-- =====================================================================
--
-- INSTRUCCIONES:
-- 1. Ve a Supabase Dashboard > SQL Editor
-- 2. Copia TODO el contenido de este archivo
-- 3. Pégalo en el editor SQL
-- 4. Haz click en "Run" (ejecutar)
-- 5. Espera a que complete (debe decir "Success")
-- 6. Vuelve a npm run dev para ver los cambios
--
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. vw_pedido_progreso: agrega nombre_referencia
-- ---------------------------------------------------------------------

drop view if exists public.vw_pedido_progreso cascade;

create view public.vw_pedido_progreso
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
    sum(cantidad_procesada)  as total_procesado,
    sum(cantidad_devuelta)   as total_devuelto,
    sum(cantidad_pendiente)  as total_pendiente,
    case
      when sum(cantidad_solicitada) > 0
        then least(round((sum(cantidad_procesada)::numeric / sum(cantidad_solicitada)::numeric) * 100), 100)
      else 0
    end as porcentaje_completado
  from public.vw_item_progreso
  group by order_number::text
),
etapa_maxima_calc as (
  select
    order_number::text as order_number,
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
fecha_fin_calc as (
  select
    pm.order_number::text as order_number,
    max(pm.created_at) as fecha_fin
  from public.production_movements pm
  where pm.to_process = 'Empaque'
  group by pm.order_number::text
),
movimientos_orden_calc as (
  select
    order_number::text as order_number,
    sum(quantity) filter (where to_process = 'Refilado')   as in_refilado,
    sum(quantity) filter (where to_process = 'Acabado')    as in_acabado,
    sum(quantity) filter (where to_process = 'Mateado')    as in_mateado,
    sum(quantity) filter (where to_process = 'Empaque')    as in_empaque,
    sum(quantity) filter (where from_process = 'Refilado') as out_refilado,
    sum(quantity) filter (where from_process = 'Acabado')  as out_acabado,
    sum(quantity) filter (where from_process = 'Mateado')  as out_mateado,
    sum(quantity) filter (where from_process = 'Empaque')  as out_empaque
  from public.production_movements
  group by order_number::text
)
select
  op.order_number,
  op.cliente,
  op.fecha_pedido,
  op.nombre_referencia,
  op.material,
  op.color,
  op.total_solicitado,
  op.total_procesado,
  op.total_devuelto,
  op.total_pendiente,
  op.porcentaje_completado,
  case
    when op.porcentaje_completado = 100 then 'Completado'
    else 'En Proceso'
  end as estatus_general,
  case
    when op.porcentaje_completado = 100 then 'Fin'
    else coalesce(em.etapa_actual, 'R')
  end as etapa_actual,
  extract(day from (case when op.porcentaje_completado = 100 and ff.fecha_fin is not null then ff.fecha_fin else now() end) - op.fecha_pedido)::int as dias_orden,
  (op.total_solicitado + coalesce(mo.in_refilado, 0)) as total_refilado,
  coalesce(mo.out_refilado, 0) as procesado_refilado,
  greatest(op.total_solicitado + coalesce(mo.in_refilado, 0) - coalesce(mo.out_refilado, 0), 0) as pendiente_refilado,
  case when (op.total_solicitado + coalesce(mo.in_refilado, 0)) > 0
    then least(round((coalesce(mo.out_refilado, 0)::numeric / (op.total_solicitado + coalesce(mo.in_refilado, 0))::numeric) * 100), 100)
    else 0
  end as porcentaje_refilado,
  coalesce(mo.in_acabado, 0) as entrada_acabado,
  op.total_solicitado as total_acabado,
  coalesce(mo.out_acabado, 0) as procesado_acabado,
  greatest(op.total_solicitado - coalesce(mo.out_acabado, 0), 0) as pendiente_acabado,
  case when op.total_solicitado > 0
    then least(round((coalesce(mo.out_acabado, 0)::numeric / op.total_solicitado::numeric) * 100), 100)
    else 0
  end as porcentaje_acabado,
  coalesce(mo.in_mateado, 0) as entrada_mateado,
  op.total_solicitado as total_mateado,
  coalesce(mo.out_mateado, 0) as procesado_mateado,
  greatest(op.total_solicitado - coalesce(mo.out_mateado, 0), 0) as pendiente_mateado,
  case when op.total_solicitado > 0
    then least(round((coalesce(mo.out_mateado, 0)::numeric / op.total_solicitado::numeric) * 100), 100)
    else 0
  end as porcentaje_mateado,
  coalesce(mo.in_empaque, 0) as entrada_empaque,
  op.total_solicitado as total_empaque,
  coalesce(mo.out_empaque, 0) as procesado_empaque,
  greatest(op.total_solicitado - coalesce(mo.out_empaque, 0), 0) as pendiente_empaque,
  case when op.total_solicitado > 0
    then least(round((coalesce(mo.out_empaque, 0)::numeric / op.total_solicitado::numeric) * 100), 100)
    else 0
  end as porcentaje_empaque
from orden_progreso op
left join etapa_maxima_calc em on em.order_number = op.order_number
left join fecha_fin_calc ff on ff.order_number = op.order_number
left join movimientos_orden_calc mo on mo.order_number = op.order_number;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo para las cards del dashboard. Calculado en cada consulta, nunca almacenado. Incluye nombre_referencia, estatus general, etapa actual, dias transcurridos y cifras especificas por proceso.';

grant select on public.vw_pedido_progreso to authenticated, anon;

-- ---------------------------------------------------------------------
-- 2. order_destino: confirmacion unica del destino de todo el pedido
-- ---------------------------------------------------------------------

create table if not exists public.order_destino (
  order_number text primary key,
  destino text not null check (destino in ('Acabado', 'Mateado', 'Empaque')),
  confirmed_by uuid not null references public.profiles(id),
  confirmed_at timestamptz not null default now()
);

alter table public.order_destino enable row level security;

drop policy if exists "order_destino_select_authenticated" on public.order_destino;
create policy "order_destino_select_authenticated"
on public.order_destino
for select
to authenticated
using (true);

drop policy if exists "order_destino_insert_refilado" on public.order_destino;
create policy "order_destino_insert_refilado"
on public.order_destino
for insert
to authenticated
with check (
  confirmed_by = (select id from public.profiles where auth_id = auth.uid())
  and exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'refilado'
  )
);

grant select, insert on public.order_destino to authenticated;
revoke update, delete on public.order_destino from authenticated, anon;
