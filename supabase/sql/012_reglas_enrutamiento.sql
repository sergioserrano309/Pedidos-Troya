-- =====================================================================
-- 012_reglas_enrutamiento.sql
-- Reglas de enrutamiento automático: algunos pedidos (identificados por
-- Nombre Suela / Material / Color, o cualquier combinación de esos 3)
-- deben saltarse la confirmación manual de destino y enrutarse directo a
-- Mateado o Empaque. Cada columna nula = "cualquiera" (comodín).
--
-- Por ahora solo Refilado puede crear/eliminar reglas (mas adelante se
-- migrará a un rol "validador" — ver comentario en la policy de insert).
-- =====================================================================

create table if not exists public.reglas_enrutamiento (
  id uuid primary key default gen_random_uuid(),
  nombre_referencia text,
  material text,
  color text,
  destino text not null check (destino in ('Acabado', 'Mateado', 'Empaque')),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),

  -- Al menos un criterio debe estar definido (no tiene sentido una regla
  -- que coincida con TODO).
  constraint chk_reglas_al_menos_un_criterio check (
    nombre_referencia is not null or material is not null or color is not null
  )
);

create index if not exists idx_reglas_nombre_referencia on public.reglas_enrutamiento(nombre_referencia);
create index if not exists idx_reglas_material on public.reglas_enrutamiento(material);
create index if not exists idx_reglas_color on public.reglas_enrutamiento(color);

alter table public.reglas_enrutamiento enable row level security;

drop policy if exists "reglas_select_authenticated" on public.reglas_enrutamiento;
create policy "reglas_select_authenticated"
on public.reglas_enrutamiento
for select
to authenticated
using (true);

-- IMPORTANTE: cuando se cree el rol "validador", cambiar 'refilado' por
-- 'validador' en esta policy (o agregar el segundo rol con "or").
drop policy if exists "reglas_insert_refilado" on public.reglas_enrutamiento;
create policy "reglas_insert_refilado"
on public.reglas_enrutamiento
for insert
to authenticated
with check (
  created_by = (select id from public.profiles where auth_id = auth.uid())
  and exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'refilado'
  )
);

drop policy if exists "reglas_delete_refilado" on public.reglas_enrutamiento;
create policy "reglas_delete_refilado"
on public.reglas_enrutamiento
for delete
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'refilado'
  )
);

grant select, insert, delete on public.reglas_enrutamiento to authenticated;
revoke update on public.reglas_enrutamiento from authenticated, anon;
