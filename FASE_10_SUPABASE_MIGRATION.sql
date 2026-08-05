-- =====================================================================
-- FASE 10: SUPABASE MIGRATION
-- 1. Enrutamiento automático: pedidos que cumplen una regla de
--    reglas_enrutamiento se enrutan solos (Refilado nunca los ve).
-- 2. Eliminación de registros propios en "Registros", con motivo
--    obligatorio y log de auditoría (log_eliminaciones).
--
-- IMPORTANTE: el orden de este archivo importa. Ejecuta TODO de una
-- sola vez (no por partes) porque la vista al final depende de las
-- columnas creadas al principio.
--
-- INSTRUCCIONES:
-- 1. Ve a Supabase Dashboard > SQL Editor
-- 2. Copia TODO el contenido de este archivo
-- 3. Pégalo en el editor SQL
-- 4. Haz click en "Run" (ejecutar)
-- 5. Espera a que complete (debe decir "Success")
-- 6. Si ya tenías pedidos viejos que cumplen alguna regla y quieres que
--    se enruten retroactivamente, ejecuta además (una sola vez):
--       select public.backfill_auto_enrutamiento();
-- 7. Vuelve a npm run dev para ver los cambios
-- =====================================================================


-- ---------------------------------------------------------------------
-- PARTE 1: Enrutamiento automático
-- ---------------------------------------------------------------------

alter table public.production_movements
  alter column user_id drop not null;

alter table public.production_movements
  add column if not exists es_automatico boolean not null default false;

alter table public.order_destino
  alter column confirmed_by drop not null;

alter table public.order_destino
  add column if not exists es_automatico boolean not null default false;

create or replace function public.aplicar_regla_enrutamiento(p_fila public.p_pedidosh)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_regla record;
  v_item_id text;
  v_cantidad integer;
begin
  if coalesce(p_fila."Cancelado", false) then
    return;
  end if;

  v_cantidad := coalesce(p_fila."CantidadP", 0);
  if v_cantidad <= 0 then
    return;
  end if;

  select r.*
  into v_regla
  from public.reglas_enrutamiento r
  where (r.nombre_referencia is null or r.nombre_referencia = p_fila."NombreR")
    and (r.material is null or r.material = p_fila."MaterialP")
    and (r.color is null or r.color = p_fila."ColorP")
  order by
    (case when r.nombre_referencia is not null then 1 else 0 end
     + case when r.material is not null then 1 else 0 end
     + case when r.color is not null then 1 else 0 end) desc,
    r.created_at asc
  limit 1;

  if v_regla.id is null then
    return;
  end if;

  v_item_id := public.generar_item_id(
    p_fila."PedidoNo"::text,
    p_fila."Referencia",
    p_fila."Talla"::text,
    p_fila."MaterialP",
    p_fila."ColorP"
  );

  insert into public.production_movements (
    item_id, order_number, reference, size, quantity,
    from_process, to_process, user_id, observation, es_automatico
  ) values (
    v_item_id,
    p_fila."PedidoNo"::text,
    p_fila."NombreR",
    p_fila."Talla"::text,
    v_cantidad,
    'Refilado',
    v_regla.destino,
    null,
    'Enrutamiento automático por regla de enrutamiento',
    true
  );

  insert into public.order_destino (order_number, destino, confirmed_by, es_automatico)
  values (p_fila."PedidoNo"::text, v_regla.destino, null, true)
  on conflict (order_number) do nothing;
end;
$$;

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

drop trigger if exists trg_auto_enrutar_pedido on public.p_pedidosh;
create trigger trg_auto_enrutar_pedido
after insert on public.p_pedidosh
for each row
execute function public.fn_auto_enrutar_pedido();

create or replace function public.backfill_auto_enrutamiento()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fila public.p_pedidosh;
  v_contador integer := 0;
begin
  for v_fila in
    select p.*
    from public.p_pedidosh p
    where not exists (
      select 1 from public.production_movements m
      where m.item_id = public.generar_item_id(
        p."PedidoNo"::text, p."Referencia", p."Talla"::text, p."MaterialP", p."ColorP"
      )
    )
  loop
    perform public.aplicar_regla_enrutamiento(v_fila);
    v_contador := v_contador + 1;
  end loop;

  return v_contador;
end;
$$;

grant execute on function public.backfill_auto_enrutamiento() to authenticated;


-- ---------------------------------------------------------------------
-- PARTE 2: Actualiza vw_pedido_progreso (excluye lo automático del
-- "Procesado" de Refilado, expone destino_es_automatico)
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
    sum(quantity) filter (where from_process = 'Refilado' and not es_automatico) as out_refilado,
    sum(quantity) filter (where from_process = 'Acabado')  as out_acabado,
    sum(quantity) filter (where from_process = 'Mateado')  as out_mateado,
    sum(quantity) filter (where from_process = 'Empaque')  as out_empaque
  from public.production_movements
  group by order_number::text
),
destino_calc as (
  select order_number, es_automatico
  from public.order_destino
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
  end as porcentaje_empaque,
  dc.es_automatico as destino_es_automatico
from orden_progreso op
left join etapa_maxima_calc em on em.order_number = op.order_number
left join fecha_fin_calc ff on ff.order_number = op.order_number
left join movimientos_orden_calc mo on mo.order_number = op.order_number
left join destino_calc dc on dc.order_number = op.order_number;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo. Excluye movimientos automaticos del Procesado de Refilado; expone destino_es_automatico para ocultar pedidos auto-enrutados del listado de Refilado.';

grant select on public.vw_pedido_progreso to authenticated, anon;


-- ---------------------------------------------------------------------
-- PARTE 3: Eliminación de registros con motivo obligatorio
-- ---------------------------------------------------------------------

create table if not exists public.log_eliminaciones (
  id uuid primary key default gen_random_uuid(),
  tabla_origen text not null,
  registro_id uuid not null,
  snapshot jsonb not null,
  eliminado_por uuid not null references public.profiles(id),
  motivo text not null,
  eliminado_en timestamptz not null default now()
);

alter table public.log_eliminaciones enable row level security;

drop policy if exists "log_eliminaciones_select_authenticated" on public.log_eliminaciones;
create policy "log_eliminaciones_select_authenticated"
on public.log_eliminaciones
for select
to authenticated
using (true);

grant select on public.log_eliminaciones to authenticated;

create or replace function public.eliminar_movimiento_con_motivo(p_movimiento_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registro public.production_movements;
  v_perfil_id uuid;
begin
  select id into v_perfil_id from public.profiles where auth_id = auth.uid();
  if v_perfil_id is null then
    raise exception 'Usuario no válido.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este registro.';
  end if;

  select * into v_registro from public.production_movements where id = p_movimiento_id;
  if v_registro.id is null then
    raise exception 'El registro no existe o ya fue eliminado.';
  end if;

  if v_registro.user_id is distinct from v_perfil_id then
    raise exception 'Solo puedes eliminar registros que tú mismo creaste.';
  end if;

  if exists (
    select 1 from public.production_movements m2
    where m2.item_id = v_registro.item_id
      and m2.created_at > v_registro.created_at
  ) then
    raise exception 'No puedes eliminar este registro: ya se generó otro movimiento posterior para esta talla.';
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('production_movements', v_registro.id, to_jsonb(v_registro), v_perfil_id, trim(p_motivo));

  delete from public.production_movements where id = p_movimiento_id;
end;
$$;

grant execute on function public.eliminar_movimiento_con_motivo(uuid, text) to authenticated;
