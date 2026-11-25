-- =====================================================================
-- 093_comentarios_pedido.sql
--
-- Comentarios por orden en Control Central, tipo chat con historial.
--
-- REGLAS (decididas con el usuario, 2026-11-25)
--   - Escriben y leen: Propuesta, Empaque (Despachos) y Validador, que son
--     quienes ven Control Central.
--   - Cada comentario guarda quien lo escribio (nombre y rol) y la fecha/hora.
--   - NO se editan: solo se agregan y se eliminan.
--   - Eliminar NO borra la fila: queda marcada como eliminada, con quien la
--     elimino y cuando, y el historial la sigue mostrando.
--   - Eliminar: el autor del comentario o el Validador.
--   - Maximo 255 caracteres por comentario (igual que los de Despachos).
--
-- NO TOCA ninguna tabla ni funcion existente.
-- Reversa: 093_revertir_comentarios_pedido.sql
-- Todo va en UNA transaccion: si algo falla, no se aplica nada.
-- =====================================================================

begin;

create table if not exists public.pedido_comentarios (
  id uuid primary key default gen_random_uuid(),
  order_number text not null,
  texto text not null,
  created_by uuid not null references public.profiles(id),
  autor_nombre text not null,
  autor_rol text not null,
  created_at timestamptz not null default now(),
  eliminado boolean not null default false,
  eliminado_por uuid references public.profiles(id),
  eliminado_nombre text,
  eliminado_at timestamptz,
  constraint pedido_comentarios_texto_valido
    check (char_length(texto) between 1 and 255)
);

create index if not exists idx_pedido_comentarios_orden
  on public.pedido_comentarios(order_number, created_at);

comment on table public.pedido_comentarios is
  'Historial de comentarios por orden de Control Central (093). No se editan; eliminar = marcar eliminado.';

-- RLS: leen Propuesta, Empaque y Validador; nadie escribe directo (solo las funciones).
alter table public.pedido_comentarios enable row level security;
drop policy if exists "pedido_comentarios_select" on public.pedido_comentarios;
create policy "pedido_comentarios_select" on public.pedido_comentarios
  for select to authenticated
  using (exists (
    select 1 from public.profiles pr
     where pr.auth_id = auth.uid()
       and lower(pr.role) in ('propuesta', 'empaque', 'validador')
  ));
grant select on public.pedido_comentarios to authenticated;
revoke insert, update, delete on public.pedido_comentarios from authenticated, anon;

-- Candado de inmutabilidad: ni siquiera las funciones pueden cambiar el texto,
-- el autor o la fecha; lo unico que puede pasar es eliminado false -> true.
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
     or new.created_at is distinct from old.created_at then
    raise exception 'Los comentarios no se pueden editar.';
  end if;
  if old.eliminado and not new.eliminado then
    raise exception 'Un comentario eliminado no se puede restaurar.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_pedido_comentarios_inmutable on public.pedido_comentarios;
create trigger trg_pedido_comentarios_inmutable
  before update or delete on public.pedido_comentarios
  for each row
  execute function public.fn_pedido_comentarios_inmutable();

-- Agregar un comentario.
create or replace function public.agregar_comentario_pedido(p_order_number text, p_texto text)
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

  insert into public.pedido_comentarios (order_number, texto, created_by, autor_nombre, autor_rol)
  values (trim(p_order_number), v_texto, v_perfil_id, v_nombre, v_rol)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.agregar_comentario_pedido(text, text) from public, anon;
grant execute on function public.agregar_comentario_pedido(text, text) to authenticated;

-- Eliminar (marcar) un comentario: el autor o el Validador.
create or replace function public.eliminar_comentario_pedido(p_comentario_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_nombre text;
  v_rol text;
  v_autor uuid;
  v_eliminado boolean;
begin
  select pr.id, pr.name, lower(pr.role) into v_perfil_id, v_nombre, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('propuesta', 'empaque', 'validador') then
    raise exception 'Tu rol no puede eliminar comentarios en Control Central.';
  end if;

  select c.created_by, c.eliminado into v_autor, v_eliminado
    from public.pedido_comentarios c where c.id = p_comentario_id for update;
  if not found then
    raise exception 'El comentario no existe.';
  end if;
  if v_eliminado then
    raise exception 'El comentario ya estaba eliminado.';
  end if;
  if v_autor <> v_perfil_id and v_rol <> 'validador' then
    raise exception 'Solo quien lo escribio o el Validador puede eliminar este comentario.';
  end if;

  update public.pedido_comentarios
     set eliminado = true,
         eliminado_por = v_perfil_id,
         eliminado_nombre = v_nombre,
         eliminado_at = now()
   where id = p_comentario_id;
end;
$$;

revoke all on function public.eliminar_comentario_pedido(uuid) from public, anon;
grant execute on function public.eliminar_comentario_pedido(uuid) to authenticated;

-- En vivo: un comentario nuevo o eliminado se refleja en los demas.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'pedido_comentarios'
  ) then
    alter publication supabase_realtime add table public.pedido_comentarios;
  end if;
end
$$;

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (despues de ejecutar)
--   select count(*) from public.pedido_comentarios;   -- 0
-- Luego, desde la app: comentar una orden, eliminarlo y ver que queda tachado.
-- =====================================================================
