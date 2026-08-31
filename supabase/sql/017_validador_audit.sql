-- =====================================================================
-- 017_validador_audit.sql
-- Tablas y RLS para rol Validador (maestro con auditoría completa)
-- =====================================================================

-- Tabla: user_roles (usuario puede tener múltiples roles)
create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('Refilado', 'Acabado', 'Mateado', 'Empaque', 'Validador')),
  activo boolean default true,
  creado_en timestamptz default now(),
  unique(user_id, role)
);

alter table public.user_roles enable row level security;

create policy "user_roles_select_own_or_validador"
on public.user_roles
for select
to authenticated
using (
  user_id = auth.uid() or
  exists (
    select 1 from public.user_roles ur2
    where ur2.user_id = auth.uid() and ur2.role = 'Validador' and ur2.activo = true
  )
);

grant select on public.user_roles to authenticated;

-- Tabla: audit_validador (log de intervenciones del validador)
create table if not exists public.audit_validador (
  id uuid primary key default gen_random_uuid(),
  validador_id uuid not null references public.profiles(id),
  accion text not null,                    -- 'procesar_orden', 'eliminar_movimiento', 'crear_regla', etc
  rol_actuante text not null,              -- 'Refilado', 'Acabado', 'Empaque' (rol con el que actuó)
  orden_id text,                           -- referencia a la orden
  item_id text,                            -- referencia al item (talla) si aplica
  detalle jsonb,                           -- snapshot de qué cambió
  razon text,                              -- por qué intervino (opcional)
  creado_en timestamptz default now()
);

alter table public.audit_validador enable row level security;

create policy "audit_validador_select_validador_only"
on public.audit_validador
for select
to authenticated
using (
  exists (
    select 1 from public.user_roles ur
    where ur.user_id = auth.uid() and ur.role = 'Validador' and ur.activo = true
  )
);

grant select on public.audit_validador to authenticated;

-- Función para registrar auditoría del validador
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
  'Roles de usuarios. Un usuario puede tener múltiples roles (ej: Refilado + Validador).';

comment on table public.audit_validador is
  'Log de auditoría de intervenciones del validador. Registra cada acción para trazabilidad.';
