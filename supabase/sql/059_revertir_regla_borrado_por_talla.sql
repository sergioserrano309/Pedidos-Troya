-- =====================================================================
-- 059_revertir_regla_borrado_por_talla.sql
-- REVERSA de 059_regla_borrado_por_talla.sql (2026-10-02).
-- Restaura TEXTUALMENTE la regla anterior de 055 para eliminar registros:
--   bloquea si hay un movimiento posterior de la misma talla (014/055-a)
--   o si OTRO proceso registro despues en la misma orden (055-b),
--   ademas de talla despachada (046) y autoria.
-- Reemplaza: vw_historial (columna tiene_movimiento_posterior) y
-- eliminar_movimiento_con_motivo(uuid, text). No toca ningun dato.
-- Despues de correrlo, revertir tambien el texto del tooltip en
-- src/ui/historyPage.js (ver git: cambio "059").
-- =====================================================================

begin;

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
  (h.tipo = 'movimiento' and (
     exists (
       select 1 from public.production_movements m2
       where m2.item_id = h.item_id
         and m2.created_at > h.created_at
     )
     or exists (
       select 1 from public.production_movements m3
       where m3.order_number = h.order_number
         and m3.created_at > h.created_at
         and m3.from_process is distinct from h.from_process
     )
   )) as tiene_movimiento_posterior,
  -- Las dos ultimas columnas son de 049 (el despacho concreto en que
  -- salio ESTE registro de Empaque). Van despues de
  -- tiene_movimiento_posterior y no se pueden mover: create or replace
  -- view no deja reordenar ni quitar columnas, solo agregar al final.
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
  -- Fecha en que ESTA talla salio (la ultima vez, si salio en varias remesas).
  select doi.item_id,
         max(coalesce(d.confirmed_at, d.created_at)) as fecha_despacho
  from public.despacho_orden_items doi
  join public.despachos d on d.id = doi.despacho_id
  group by doi.item_id
) tal on tal.item_id = h.item_id
left join public.vw_pedido_despacho_estado est on est.order_number = h.order_number
left join public.vw_movimiento_despacho md on md.movimiento_id = h.id;

comment on view public.vw_historial is
  'Linea de tiempo de production_movements + returns. fecha_despacho = talla (decide el bloqueo por despacho); despacho_consecutivo / despacho_fecha_registro = remesa concreta de ESTE registro (049); despacho_confirmado = completitud del pedido; tiene_movimiento_posterior (055) bloquea la ORDEN entera cuando otro proceso ya registro sobre ella.';

create or replace function public.eliminar_movimiento_con_motivo(p_movimiento_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registro public.production_movements;
  v_perfil_id uuid;
  v_consecutivos text;
  v_otro_proceso text;
begin
  select id into v_perfil_id from public.profiles where auth_id = auth.uid();
  if v_perfil_id is null then
    raise exception 'Usuario no valido.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este registro.';
  end if;

  select * into v_registro from public.production_movements where id = p_movimiento_id;
  if v_registro.id is null then
    raise exception 'El registro no existe o ya fue eliminado.';
  end if;

  if v_registro.user_id is distinct from v_perfil_id then
    raise exception 'Solo puedes eliminar registros que tu mismo creaste.';
  end if;

  -- Bloqueo por talla despachada (046).
  select string_agg(distinct d.consecutivo, ', ')
    into v_consecutivos
    from public.despacho_orden_items doi
    join public.despachos d on d.id = doi.despacho_id
   where doi.item_id = v_registro.item_id;

  if v_consecutivos is not null then
    raise exception 'No puedes eliminar este registro: la talla % del pedido % ya fue despachada (%). Elimina primero ese despacho en Despachos > Despachado.',
      v_registro.size, v_registro.order_number, v_consecutivos;
  end if;

  -- (a) Movimiento posterior de la MISMA talla (014).
  if exists (
    select 1 from public.production_movements m2
    where m2.item_id = v_registro.item_id
      and m2.created_at > v_registro.created_at
  ) then
    raise exception 'No puedes eliminar este registro: ya se genero otro movimiento posterior para esta talla.';
  end if;

  -- (b) Otro proceso ya trabajo sobre la orden (055): se bloquea la
  --     orden completa, no solo la talla.
  select m3.from_process
    into v_otro_proceso
    from public.production_movements m3
   where m3.order_number = v_registro.order_number
     and m3.created_at > v_registro.created_at
     and m3.from_process is distinct from v_registro.from_process
   order by m3.created_at
   limit 1;

  if v_otro_proceso is not null then
    raise exception 'No puedes eliminar este registro: % ya proceso unidades del pedido %. Cuando otro proceso trabaja sobre la orden, queda bloqueada completa.',
      v_otro_proceso, v_registro.order_number;
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('production_movements', v_registro.id, to_jsonb(v_registro), v_perfil_id, trim(p_motivo));

  delete from public.production_movements where id = p_movimiento_id;
end;
$$;

grant execute on function public.eliminar_movimiento_con_motivo(uuid, text) to authenticated;

comment on function public.eliminar_movimiento_con_motivo(uuid, text) is
  'Elimina un movimiento con motivo obligatorio y snapshot en log_eliminaciones. Bloquea si la TALLA fue despachada (046), si hay un movimiento posterior de esa talla (014), o si OTRO proceso ya registro sobre la orden (055).';

commit;
