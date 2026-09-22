-- =====================================================================
-- 041_bloquear_borrado_despachado.sql
-- No se puede eliminar un movimiento de producción si su orden ya está
-- en un despacho. Primero hay que eliminar el despacho en RegistrosD, y
-- después sí el registro en RegistrosO.
--
-- Por qué aplica a TODOS los roles y no solo a Empaque:
-- borrar un movimiento de Refilado de una orden ya despachada corrompe
-- igual el progreso del pedido (vw_pedido_progreso) y, desde 040, la
-- fecha de liquidación de la comisión. El daño no depende de qué proceso
-- generó el registro, sino de que la mercancía ya salió.
--
-- Orden de las validaciones: la de despacho va ANTES de la de
-- "movimiento posterior". Una orden despachada está al 100%, así que casi
-- siempre existe también un movimiento posterior para esa talla — si esa
-- validación disparara primero, el usuario recibiría un mensaje que no le
-- dice qué hacer. Así recibe el accionable: elimine primero el despacho.
--
-- Resto del cuerpo: idéntico a 014.
-- =====================================================================

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

  -- ---- NUEVO (041): la orden no puede estar despachada ----
  select string_agg(d.consecutivo, ', ' order by d.consecutivo)
    into v_consecutivos
    from public.despacho_ordenes do2
    join public.despachos d on d.id = do2.despacho_id
   where do2.order_number = v_registro.order_number;

  if v_consecutivos is not null then
    raise exception 'No puedes eliminar este registro: la orden % ya fue despachada (%). Elimina primero ese despacho en RegistrosD.',
      v_registro.order_number, v_consecutivos;
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

comment on function public.eliminar_movimiento_con_motivo(uuid, text) is
  'Elimina un movimiento de produccion con motivo obligatorio, dejando snapshot en log_eliminaciones. Bloquea el borrado si la orden ya esta en un despacho (fix 041): hay que eliminar el despacho primero.';
