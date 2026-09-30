-- =====================================================================
-- 057_cierre_forzado.sql
-- Cierre forzado de un pedido por el Validador.
--
-- Caso: un pedido se despacha parcialmente 1, 2, n veces y nunca se
-- termina de entregar. No debe quedar "Activo" para siempre. El Validador
-- lo puede cerrar a la fuerza:
--   - pasa a "Completadas" para TODOS los usuarios (aunque no llegue al 100%),
--   - queda marcado como cerrado a la fuerza (con motivo, quien y cuando),
--   - nadie puede registrar ni eliminar movimientos ni despachos sobre el,
--   - el Validador lo puede reabrir (prender y apagar, como el visto bueno
--     de un despacho, 053).
--
-- 100% ADITIVO: tabla nueva, columnas nuevas AL FINAL de la vista, RPCs y
-- triggers nuevos. No se altera ningun calculo ni regla existente. Como
-- Try 6 y produccion comparten Supabase, esto aplica a ambos al correrlo.
--
-- OJO: la vista se redefine con la MISMA definicion de 021 (ultima vez que
-- se creo) + 4 columnas al final. Si alguien la modifico a mano en
-- Supabase despues de 021, revisar antes de correr.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tabla. Una fila = pedido cerrado a la fuerza. Reabrir = borrar la fila.
-- ---------------------------------------------------------------------
create table if not exists public.pedido_cierre_forzado (
  order_number text primary key,
  motivo       text not null,
  cerrado_por  uuid not null references public.profiles(id),
  cerrado_at   timestamptz not null default now()
);

alter table public.pedido_cierre_forzado enable row level security;

drop policy if exists "pedido_cierre_forzado_select" on public.pedido_cierre_forzado;
create policy "pedido_cierre_forzado_select"
  on public.pedido_cierre_forzado
  for select
  to authenticated
  using (true);

-- Solo lectura directa: la escritura pasa unicamente por los RPC de abajo.
revoke insert, update, delete on public.pedido_cierre_forzado from authenticated, anon;
grant select on public.pedido_cierre_forzado to authenticated;

comment on table public.pedido_cierre_forzado is
  'Pedidos cerrados a la fuerza por el Validador (057). Su sola existencia bloquea registros y borrados sobre el pedido.';

-- ---------------------------------------------------------------------
-- 2. RPC cerrar / reabrir. Solo Validador. Dejan huella en audit_validador.
-- ---------------------------------------------------------------------
create or replace function public.cerrar_pedido_forzado(
  p_order_number text,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede cerrar un pedido a la fuerza.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar el motivo del cierre.';
  end if;

  if not exists (select 1 from public.p_pedidosh where "PedidoNo"::text = p_order_number) then
    raise exception 'El pedido % no existe.', p_order_number;
  end if;

  if exists (select 1 from public.pedido_cierre_forzado where order_number = p_order_number) then
    raise exception 'El pedido % ya esta cerrado a la fuerza.', p_order_number;
  end if;

  insert into public.pedido_cierre_forzado (order_number, motivo, cerrado_por)
  values (p_order_number, trim(p_motivo), v_perfil_id);

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (v_perfil_id, 'cerrar_forzado', 'Validador', p_order_number, null, trim(p_motivo));
end;
$$;

create or replace function public.reabrir_pedido_forzado(
  p_order_number text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede reabrir un pedido cerrado a la fuerza.';
  end if;

  delete from public.pedido_cierre_forzado where order_number = p_order_number;

  if not found then
    raise exception 'El pedido % no esta cerrado a la fuerza.', p_order_number;
  end if;

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (v_perfil_id, 'reabrir_forzado', 'Validador', p_order_number, null, null);
end;
$$;

grant execute on function public.cerrar_pedido_forzado(text, text) to authenticated;
grant execute on function public.reabrir_pedido_forzado(text) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Candado en la BASE (no solo en pantalla): ningun registro nuevo ni
--    borrado de movimientos / items de despacho sobre un pedido cerrado.
--    Como trigger, cubre cualquier via (RPC de borrado 055, insert directo,
--    crear_despacho, borrar un despacho) sin reescribir esas funciones.
-- ---------------------------------------------------------------------
create or replace function public.fn_bloquear_pedido_cerrado_forzado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order text;
begin
  v_order := case when tg_op = 'DELETE' then old.order_number::text else new.order_number::text end;

  if exists (select 1 from public.pedido_cierre_forzado where order_number = v_order) then
    raise exception 'El pedido % fue cerrado a la fuerza por el Validador: no admite registros ni eliminaciones. Pidele al Validador que lo reabra.', v_order;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_bloquear_movimientos_pedido_cerrado on public.production_movements;
create trigger trg_bloquear_movimientos_pedido_cerrado
  before insert or delete on public.production_movements
  for each row
  execute function public.fn_bloquear_pedido_cerrado_forzado();

drop trigger if exists trg_bloquear_despacho_items_pedido_cerrado on public.despacho_orden_items;
create trigger trg_bloquear_despacho_items_pedido_cerrado
  before insert or delete on public.despacho_orden_items
  for each row
  execute function public.fn_bloquear_pedido_cerrado_forzado();

-- ---------------------------------------------------------------------
-- 4. La vista expone el estado (columnas nuevas AL FINAL, ver 053).
--    Definicion identica a 021 salvo el join y las 4 columnas finales.
-- ---------------------------------------------------------------------
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
  greatest(op.total_solicitado - coalesce(mo.out_empaque, 0), 0)::numeric as total_pendiente,
  case when op.total_solicitado > 0
    then least(round((coalesce(mo.out_empaque, 0)::numeric / op.total_solicitado::numeric) * 100), 100)
    else 0
  end as porcentaje_completado,
  case
    when op.total_solicitado > 0 and coalesce(mo.out_empaque, 0) >= op.total_solicitado then 'Completado'
    else 'En Proceso'
  end as estatus_general,
  case
    when op.total_solicitado > 0 and coalesce(mo.out_empaque, 0) >= op.total_solicitado then 'Fin'
    else coalesce(op.etapa_actual, 'R')
  end as etapa_actual,
  extract(day from (case when op.total_solicitado > 0 and coalesce(mo.out_empaque, 0) >= op.total_solicitado and mo.fecha_fin is not null then mo.fecha_fin else now() end) - op.fecha_pedido)::int as dias_orden,
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
  dc.es_automatico as destino_es_automatico,
  -- Nuevas (057), siempre al final:
  (pcf.order_number is not null) as cierre_forzado,
  pcf.motivo                     as cierre_forzado_motivo,
  pcf.cerrado_at                 as cierre_forzado_at,
  cpr.name                       as cierre_forzado_por
from orden_progreso op
left join movimientos_orden_calc mo on mo.order_number = op.order_number
left join destino_calc dc on dc.order_number = op.order_number
left join public.pedido_cierre_forzado pcf on pcf.order_number = op.order_number
left join public.profiles cpr on cpr.id = pcf.cerrado_por;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo. Completado/Fin/% global = paso por Empaque (021). cierre_forzado* (057): el Validador cerro el pedido sin completarlo; no altera ningun calculo, solo lo marca.';

-- ---------------------------------------------------------------------
-- 5. Realtime: que los demas usuarios vean el cierre/reapertura al instante.
-- ---------------------------------------------------------------------
do $$
begin
  alter publication supabase_realtime add table public.pedido_cierre_forzado;
exception when duplicate_object then
  null;
end $$;
