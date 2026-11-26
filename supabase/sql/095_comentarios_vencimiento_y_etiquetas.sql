-- =====================================================================
-- 095_comentarios_vencimiento_y_etiquetas.sql
--
-- Comentarios de orden (093/094): fecha de vencimiento del accionable y
-- etiquetas de rol con "@".
--
-- REGLAS (decididas con el usuario, 2026-11-26)
--   - Un comentario accionable NUEVO exige fecha de vencimiento (hoy o futura,
--     hora de Colombia). Los accionables anteriores quedan sin fecha.
--   - Un comentario NO accionable no lleva fecha.
--   - Dentro del texto se puede etiquetar a un ROL con "@" (Propuesta,
--     Despachos, Validador, Refilado, Acabado, Mateado, Comercial). Se pueden
--     etiquetar todos aunque algunos no puedan leer Control Central.
--   - Fecha y etiquetas, como el texto, no se editan despues de enviadas.
--
-- Roles guardados con el nombre de la base (Despachos = 'empaque').
--
-- Reversa: 095_revertir_comentarios_vencimiento_y_etiquetas.sql
-- Todo va en UNA transaccion.
-- =====================================================================

begin;

alter table public.pedido_comentarios
  add column if not exists fecha_vencimiento date,
  add column if not exists roles_etiquetados text[] not null default '{}';

alter table public.pedido_comentarios
  drop constraint if exists pedido_comentarios_vencimiento_valido;
alter table public.pedido_comentarios
  add constraint pedido_comentarios_vencimiento_valido
  check (fecha_vencimiento is null or accionable);

-- Candado de inmutabilidad (reemplaza el de 094): tampoco cambian fecha ni etiquetas.
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
     or new.accionable is distinct from old.accionable
     or new.fecha_vencimiento is distinct from old.fecha_vencimiento
     or new.roles_etiquetados is distinct from old.roles_etiquetados then
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

-- Agregar: ahora recibe fecha de vencimiento y roles etiquetados.
drop function if exists public.agregar_comentario_pedido(text, text, boolean);

create or replace function public.agregar_comentario_pedido(
  p_order_number text,
  p_texto text,
  p_accionable boolean default false,
  p_fecha_vencimiento date default null,
  p_roles_etiquetados text[] default '{}'
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
  v_accionable boolean := coalesce(p_accionable, false);
  v_roles text[];
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

  if v_accionable then
    if p_fecha_vencimiento is null then
      raise exception 'Un accionable necesita fecha de vencimiento.';
    end if;
    if p_fecha_vencimiento < (now() at time zone 'America/Bogota')::date then
      raise exception 'La fecha de vencimiento no puede ser anterior a hoy.';
    end if;
  elsif p_fecha_vencimiento is not null then
    raise exception 'Solo un accionable lleva fecha de vencimiento.';
  end if;

  select coalesce(array_agg(distinct lower(r)), '{}') into v_roles
    from unnest(coalesce(p_roles_etiquetados, '{}')) as r;
  if exists (
    select 1 from unnest(v_roles) as r
     where r not in ('propuesta', 'empaque', 'validador', 'refilado', 'acabado', 'mateado', 'comercial')
  ) then
    raise exception 'Rol etiquetado no valido.';
  end if;

  insert into public.pedido_comentarios
    (order_number, texto, created_by, autor_nombre, autor_rol, accionable, fecha_vencimiento, roles_etiquetados)
  values
    (trim(p_order_number), v_texto, v_perfil_id, v_nombre, v_rol, v_accionable,
     case when v_accionable then p_fecha_vencimiento else null end, v_roles)
  returning id into v_id;

  return v_id;
end;
$$;

revoke all on function public.agregar_comentario_pedido(text, text, boolean, date, text[]) from public, anon;
grant execute on function public.agregar_comentario_pedido(text, text, boolean, date, text[]) to authenticated;

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (despues de ejecutar)
--   select count(*) from public.pedido_comentarios where fecha_vencimiento is not null;  -- 0
-- Luego, desde la app: comentario accionable con fecha y un @Rol; mirar el color del boton.
-- =====================================================================
