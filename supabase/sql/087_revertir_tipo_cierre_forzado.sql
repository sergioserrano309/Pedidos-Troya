-- Reversa de 087: deja el cierre a la fuerza como estaba en 057 (sin tipo).
-- Se pierde la clasificacion guardada (la columna se borra); los cierres en si
-- no se tocan.
begin;

drop function if exists public.clasificar_cierre_forzado(text, text);
drop function if exists public.cerrar_pedido_forzado(text, text, text);

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

grant execute on function public.cerrar_pedido_forzado(text, text) to authenticated;

drop trigger if exists trg_tipo_cierre_automatico on public.pedido_cierre_forzado;
drop function if exists public.fn_tipo_cierre_automatico();

alter table public.pedido_cierre_forzado drop constraint if exists pedido_cierre_forzado_tipo_check;
alter table public.pedido_cierre_forzado drop column if exists tipo_cierre;

commit;
