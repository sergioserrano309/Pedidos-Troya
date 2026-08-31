-- =====================================================================
-- 020_ensure_validador_tablas.sql
-- Version idempotente de 017: seguro de correr sin importar que parte
-- ya se haya ejecutado antes (usa IF NOT EXISTS / DROP POLICY IF EXISTS
-- en todo, a diferencia de 017 que fallaba si una politica ya existia).
-- =====================================================================

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('Refilado', 'Acabado', 'Mateado', 'Empaque', 'Validador')),
  activo boolean default true,
  creado_en timestamptz default now(),
  unique(user_id, role)
);

alter table public.user_roles enable row level security;

drop policy if exists "user_roles_select_own_or_validador" on public.user_roles;
create policy "user_roles_select_own_or_validador"
on public.user_roles
for select
to authenticated
using (
  user_id = auth.uid() or
  exists (
    select 1 from public.profiles p
    where p.auth_id = auth.uid() and p.role = 'validador'
  )
);

grant select on public.user_roles to authenticated;

create table if not exists public.audit_validador (
  id uuid primary key default gen_random_uuid(),
  validador_id uuid not null references public.profiles(id),
  accion text not null,
  rol_actuante text not null,
  orden_id text,
  item_id text,
  detalle jsonb,
  razon text,
  creado_en timestamptz default now()
);

alter table public.audit_validador enable row level security;

drop policy if exists "audit_validador_select_validador_only" on public.audit_validador;
create policy "audit_validador_select_validador_only"
on public.audit_validador
for select
to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.auth_id = auth.uid() and p.role = 'validador'
  )
);

grant select on public.audit_validador to authenticated;

create or replace function public.registrar_audit_validador(
  p_accion text,
  p_rol_actuante text,
  p_orden_id text,
  p_item_id text,
  p_detalle jsonb,
  p_razon text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_validador_id uuid;
begin
  select id into v_validador_id from public.profiles where auth_id = auth.uid();

  if v_validador_id is null then
    return;
  end if;

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, item_id, detalle, razon)
  values (v_validador_id, p_accion, p_rol_actuante, p_orden_id, p_item_id, p_detalle, p_razon);
end;
$$;

grant execute on function public.registrar_audit_validador(text, text, text, text, jsonb, text) to authenticated;

comment on table public.user_roles is
  'Roles de usuarios (no usada actualmente para logica de negocio — Validador es rol independiente en profiles.role, ver 019).';

comment on table public.audit_validador is
  'Log de auditoria de intervenciones del validador. Visibilidad: solo profiles.role = validador.';
