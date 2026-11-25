-- =====================================================================
-- 094_comentarios_accionables.sql
--
-- Comentarios de orden (093) con "Accionable" Si/No.
--
-- REGLAS (decididas con el usuario, 2026-11-25)
--   - Al agregar un comentario se elige si implica un accionable (algo que
--     la operacion debe hacer). Por defecto No.
--   - Un comentario accionable se puede CERRAR; queda quien lo cerro y cuando.
--   - Cerrar lo pueden hacer Propuesta, Empaque (Despachos) y Validador
--     (los mismos roles que ven y comentan en Control Central).
--   - Cerrar no se deshace (igual que los comentarios: no se editan).
--   - Un comentario eliminado ya no se puede cerrar.
--   - "Accionable" no se puede cambiar despues de escrito el comentario.
--
-- Reversa: 094_revertir_comentarios_accionables.sql
-- Todo va en UNA transaccion.
-- =====================================================================

begin;

alter table public.pedido_comentarios
  add column if not exists accionable boolean not null default false,
  add column if not exists cerrado boolean not null default false,
  add column if not exists cerrado_por uuid references public.profiles(id),
  add column if not exists cerrado_nombre text,
  add column if not exists cerrado_at timestamptz;

alter table public.pedido_comentarios
  drop constraint if exists pedido_comentarios_cierre_valido;
alter table public.pedido_comentarios
  add constraint pedido_comentarios_cierre_valido
  check (not cerrado or accionable);

-- Candado de inmutabilidad (reemplaza el de 093): ademas del texto, autor y fecha,
-- tampoco cambia "accionable"; solo pueden pasar eliminado false->true y cerrado false->true.
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

-- Agregar: ahora recibe si es accionable (la firma de 2 parametros se reemplaza).
drop function if exists public.agregar_comentario_pedido(text, text);

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

-- Cerrar un accionable.
create or replace function public.cerrar_comentario_pedido(p_comentario_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_nombre text;
  v_rol text;
  v_accionable boolean;
  v_cerrado boolean;
  v_eliminado boolean;
begin
  select pr.id, pr.name, lower(pr.role) into v_perfil_id, v_nombre, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('propuesta', 'empaque', 'validador') then
    raise exception 'Tu rol no puede cerrar accionables en Control Central.';
  end if;

  select c.accionable, c.cerrado, c.eliminado into v_accionable, v_cerrado, v_eliminado
    from public.pedido_comentarios c where c.id = p_comentario_id for update;
  if not found then
    raise exception 'El comentario no existe.';
  end if;
  if v_eliminado then
    raise exception 'El comentario fue eliminado.';
  end if;
  if not v_accionable then
    raise exception 'Este comentario no es un accionable.';
  end if;
  if v_cerrado then
    raise exception 'El accionable ya estaba cerrado.';
  end if;

  update public.pedido_comentarios
     set cerrado = true,
         cerrado_por = v_perfil_id,
         cerrado_nombre = v_nombre,
         cerrado_at = now()
   where id = p_comentario_id;
end;
$$;

revoke all on function public.cerrar_comentario_pedido(uuid) from public, anon;
grant execute on function public.cerrar_comentario_pedido(uuid) to authenticated;

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (despues de ejecutar)
--   select count(*) from public.pedido_comentarios where accionable;  -- 0 (los anteriores quedan en No)
-- Luego, desde la app: comentar con Accionable = Si, cerrarlo y ver quien lo cerro.
-- =====================================================================
