-- =====================================================================
-- 035_rls_precios_suelas.sql
-- Activa RLS de solo lectura en las 6 tablas de precios de suelas
-- (precios_suelas + catálogos), restringido a usuarios autenticados con
-- rol 'propuesta'. Mismo patrón que returns_select_comercial en
-- 006_rls_policies.sql. Solo SELECT: esta fase es una calculadora en
-- pantalla, no edita precios.
-- =====================================================================

-- ---------------------------------------------------------------------
-- precios_suelas
-- ---------------------------------------------------------------------
alter table public.precios_suelas enable row level security;

drop policy if exists "precios_suelas_select_propuesta" on public.precios_suelas;
create policy "precios_suelas_select_propuesta"
on public.precios_suelas
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

grant select on public.precios_suelas to authenticated;

-- ---------------------------------------------------------------------
-- referencias
-- ---------------------------------------------------------------------
alter table public.referencias enable row level security;

drop policy if exists "referencias_select_propuesta" on public.referencias;
create policy "referencias_select_propuesta"
on public.referencias
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

grant select on public.referencias to authenticated;

-- ---------------------------------------------------------------------
-- materiales
-- ---------------------------------------------------------------------
alter table public.materiales enable row level security;

drop policy if exists "materiales_select_propuesta" on public.materiales;
create policy "materiales_select_propuesta"
on public.materiales
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

grant select on public.materiales to authenticated;

-- ---------------------------------------------------------------------
-- colores
-- ---------------------------------------------------------------------
alter table public.colores enable row level security;

drop policy if exists "colores_select_propuesta" on public.colores;
create policy "colores_select_propuesta"
on public.colores
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

grant select on public.colores to authenticated;

-- ---------------------------------------------------------------------
-- clientes
-- ---------------------------------------------------------------------
alter table public.clientes enable row level security;

drop policy if exists "clientes_select_propuesta" on public.clientes;
create policy "clientes_select_propuesta"
on public.clientes
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

grant select on public.clientes to authenticated;

-- ---------------------------------------------------------------------
-- tallas
-- ---------------------------------------------------------------------
alter table public.tallas enable row level security;

drop policy if exists "tallas_select_propuesta" on public.tallas;
create policy "tallas_select_propuesta"
on public.tallas
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

grant select on public.tallas to authenticated;
