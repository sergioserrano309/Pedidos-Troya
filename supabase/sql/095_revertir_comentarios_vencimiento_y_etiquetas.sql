-- Reversa de 095_comentarios_vencimiento_y_etiquetas.sql (pierde fecha de vencimiento y
-- etiquetas; los comentarios de 093/094 se conservan).
begin;

drop function if exists public.agregar_comentario_pedido(text, text, boolean, date, text[]);

create or replace function public.agregar_comentario_pedido(
  p_order_number text,
  p_texto text,
  p_accionable boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_nombre text;
  v_rol text;
  v_texto text;
  v_id uuid;
begin
  select pr.id, pr.name, lower(pr.role) into v_perfil_id, v_nombre, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('propuesta', 'empaque', 'validador') then
    raise exception 'Tu rol no puede comentar en Control Central.';
  end if;

  v_texto := trim(coalesce(p_texto, ''));
  if v_texto = '' then
    raise exception 'Escribe el comentario.';
  end if;
  if char_length(v_texto) > 255 then
    raise exception 'El comentario no puede superar 255 caracteres (tiene %).', char_length(v_texto);
  end if;
  if coalesce(trim(p_order_number), '') = '' then
    raise exception 'Falta la orden.';
  end if;

  insert into public.pedido_comentarios (order_number, texto, created_by, autor_nombre, autor_rol, accionable)
  values (trim(p_order_number), v_texto, v_perfil_id, v_nombre, v_rol, coalesce(p_accionable, false))
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.agregar_comentario_pedido(text, text, boolean) from public, anon;
grant execute on function public.agregar_comentario_pedido(text, text, boolean) to authenticated;

create or replace function public.fn_pedido_comentarios_inmutable()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Los comentarios no se borran: se marcan como eliminados.';
  end if;
  if new.order_number is distinct from old.order_number
     or new.texto is distinct from old.texto
     or new.created_by is distinct from old.created_by
     or new.autor_nombre is distinct from old.autor_nombre
     or new.autor_rol is distinct from old.autor_rol
     or new.created_at is distinct from old.created_at
     or new.accionable is distinct from old.accionable then
    raise exception 'Los comentarios no se pueden editar.';
  end if;
  if old.eliminado and not new.eliminado then
    raise exception 'Un comentario eliminado no se puede restaurar.';
  end if;
  if old.cerrado and not new.cerrado then
    raise exception 'Un accionable cerrado no se puede reabrir.';
  end if;
  if new.cerrado and not old.cerrado and old.eliminado then
    raise exception 'Un comentario eliminado no se puede cerrar.';
  end if;
  return new;
end;
$$;

alter table public.pedido_comentarios drop constraint if exists pedido_comentarios_vencimiento_valido;
alter table public.pedido_comentarios
  drop column if exists fecha_vencimiento,
  drop column if exists roles_etiquetados;

commit;
