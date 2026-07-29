-- =====================================================================
-- 001_profiles.sql
-- Tabla de perfiles: vincula cada usuario de Supabase Auth con un rol
-- de negocio (Refilado, Acabado, Mateado, Empaque, Comercial).
-- =====================================================================

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null,
  -- Se guarda en espejo del email de auth.users para poder mostrarlo en
  -- la UI (historial, topbar) sin necesitar acceso al schema "auth".
  email text not null unique,
  role text not null check (role in ('refilado', 'acabado', 'mateado', 'empaque', 'comercial')),
  created_at timestamptz not null default now()
);

create index if not exists idx_profiles_auth_id on public.profiles(auth_id);
create index if not exists idx_profiles_role on public.profiles(role);

alter table public.profiles enable row level security;

-- Las politicas de acceso (RLS) se definen centralizadamente en
-- 006_rls_policies.sql para tener toda la seguridad en un solo lugar.
