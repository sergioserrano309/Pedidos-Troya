-- =====================================================================
-- 023_compensacion_precios.sql
-- Precio por par procesado (COP), segun rol (Refilado/Acabado/Mateado/
-- Empaque), y reglas de excepcion que sobreescriben ese precio base
-- segun Tipo de usuario + Nombre Suela/Material/Color/Destino — mismo
-- patron que reglas_enrutamiento (012), con tipo_usuario y destino como
-- criterios adicionales.
--
-- A diferencia de reglas_enrutamiento (select abierto a authenticated),
-- AMBAS tablas de este archivo son invisibles por RLS para cualquier rol
-- que no sea 'validador': exponen informacion sensible de nomina (cuanto
-- gana cada rol por par). El "$" ya calculado de la produccion de cada
-- operario se expone por separado, ya congelado en cada movimiento (ver
-- 024_compensacion_movimientos_precio.sql), sin que el operario necesite
-- acceso directo a estas tablas.
-- =====================================================================

create table if not exists public.precios_por_par (
  rol text primary key check (rol in ('refilado', 'acabado', 'mateado', 'empaque')),
  precio numeric(12,2) not null check (precio >= 0),
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

insert into public.precios_por_par (rol, precio) values
  ('refilado', 81),
  ('acabado', 848),
  ('mateado', 81),
  ('empaque', 66)
on conflict (rol) do nothing;

alter table public.precios_por_par enable row level security;

drop policy if exists "precios_select_validador_only" on public.precios_por_par;
create policy "precios_select_validador_only"
on public.precios_por_par
for select
to authenticated
using (
  exists (select 1 from public.profiles p where p.auth_id = auth.uid() and p.role = 'validador')
);

drop policy if exists "precios_update_validador_only" on public.precios_por_par;
create policy "precios_update_validador_only"
on public.precios_por_par
for update
to authenticated
using (
  exists (select 1 from public.profiles p where p.auth_id = auth.uid() and p.role = 'validador')
)
with check (
  exists (select 1 from public.profiles p where p.auth_id = auth.uid() and p.role = 'validador')
);

grant select, update on public.precios_por_par to authenticated;
revoke insert, delete on public.precios_por_par from authenticated, anon;

-- ---------------------------------------------------------------------
-- reglas_precios: mirror de reglas_enrutamiento (012), + tipo_usuario y
-- destino como criterios adicionales, y precio en vez de destino-target.
-- ---------------------------------------------------------------------

create table if not exists public.reglas_precios (
  id uuid primary key default gen_random_uuid(),
  tipo_usuario text not null check (tipo_usuario in ('refilado', 'acabado', 'mateado', 'empaque')),
  nombre_referencia text,
  material text,
  color text,
  destino text check (destino in ('Acabado', 'Mateado', 'Empaque')),
  precio numeric(12,2) not null check (precio >= 0),
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),

  -- Ademas de tipo_usuario (siempre obligatorio), al menos un criterio
  -- de suela debe estar definido (no tiene sentido una regla que
  -- coincida con CUALQUIER suela de ese rol).
  constraint chk_reglas_precios_al_menos_un_criterio check (
    nombre_referencia is not null or material is not null or color is not null or destino is not null
  )
);

create index if not exists idx_reglas_precios_tipo_usuario on public.reglas_precios(tipo_usuario);
create index if not exists idx_reglas_precios_nombre_referencia on public.reglas_precios(nombre_referencia);
create index if not exists idx_reglas_precios_material on public.reglas_precios(material);
create index if not exists idx_reglas_precios_color on public.reglas_precios(color);
create index if not exists idx_reglas_precios_destino on public.reglas_precios(destino);

alter table public.reglas_precios enable row level security;

drop policy if exists "reglas_precios_select_validador_only" on public.reglas_precios;
create policy "reglas_precios_select_validador_only"
on public.reglas_precios
for select
to authenticated
using (
  exists (select 1 from public.profiles p where p.auth_id = auth.uid() and p.role = 'validador')
);

drop policy if exists "reglas_precios_insert_validador_only" on public.reglas_precios;
create policy "reglas_precios_insert_validador_only"
on public.reglas_precios
for insert
to authenticated
with check (
  created_by = (select id from public.profiles where auth_id = auth.uid())
  and exists (select 1 from public.profiles p where p.auth_id = auth.uid() and p.role = 'validador')
);

drop policy if exists "reglas_precios_delete_validador_only" on public.reglas_precios;
create policy "reglas_precios_delete_validador_only"
on public.reglas_precios
for delete
to authenticated
using (
  exists (select 1 from public.profiles p where p.auth_id = auth.uid() and p.role = 'validador')
);

grant select, insert, delete on public.reglas_precios to authenticated;
revoke update on public.reglas_precios from authenticated, anon;

comment on table public.precios_por_par is
  'Precio COP por par procesado, por rol. Editable solo por Validador. Invisible por RLS para cualquier otro rol. Cada cambio se audita via audit_validador (accion=precio_actualizado, ver src/services/preciosService.js).';
comment on table public.reglas_precios is
  'Excepciones de precio por Tipo de usuario + Nombre Suela/Material/Color/Destino (comodin=null, gana la mas especifica). Editable solo por Validador. Mirror de reglas_enrutamiento (012).';
