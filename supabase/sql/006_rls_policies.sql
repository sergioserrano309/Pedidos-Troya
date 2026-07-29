-- =====================================================================
-- 006_rls_policies.sql
-- Row Level Security: define quien puede leer/escribir cada tabla.
-- Regla critica: "Pedidos Prueba" queda con SOLO SELECT (sin politicas
-- de insert/update/delete) => bloqueado a nivel de base de datos para
-- cualquier conexion que no use la service_role key.
--
-- IMPORTANTE: ejecutar despues de 001-005. Si "Pedidos Prueba" ya tenia
-- RLS/policies previas creadas por el proceso de sincronizacion, revisa
-- que no entren en conflicto con "pedidos_prueba_select_authenticated".
-- =====================================================================

-- ---------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_authenticated" on public.profiles;
create policy "profiles_select_authenticated"
on public.profiles
for select
to authenticated
using (true);

-- Sin políticas de insert/update/delete: la gestión de perfiles se hace
-- desde Supabase Studio / service_role (ver 007_seed_profiles_example.sql).

grant select on public.profiles to authenticated;

-- ---------------------------------------------------------------------
-- "Pedidos Prueba" (SOLO LECTURA — regla critica de negocio)
-- ---------------------------------------------------------------------
alter table public."Pedidos Prueba" enable row level security;

drop policy if exists "pedidos_prueba_select_authenticated" on public."Pedidos Prueba";
create policy "pedidos_prueba_select_authenticated"
on public."Pedidos Prueba"
for select
to authenticated
using (true);

-- Sin políticas de insert/update/delete => bloqueado para roles
-- "authenticated"/"anon". Solo service_role (usado por la sincronizacion
-- del ERP) puede escribir, porque service_role ignora RLS.

grant select on public."Pedidos Prueba" to authenticated;
revoke insert, update, delete on public."Pedidos Prueba" from authenticated, anon;

-- ---------------------------------------------------------------------
-- production_movements
-- ---------------------------------------------------------------------
alter table public.production_movements enable row level security;

drop policy if exists "movements_select_authenticated" on public.production_movements;
create policy "movements_select_authenticated"
on public.production_movements
for select
to authenticated
using (true);

-- Un usuario solo puede insertar un movimiento como si mismo (user_id)
-- y unicamente si su rol coincide con el proceso de origen (from_process).
-- Ej: un usuario con role='refilado' solo puede insertar
-- from_process='Refilado'.
drop policy if exists "movements_insert_own_role" on public.production_movements;
create policy "movements_insert_own_role"
on public.production_movements
for insert
to authenticated
with check (
  user_id = (select id from public.profiles where auth_id = auth.uid())
  and exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid()
      and lower(pr.role) = lower(production_movements.from_process)
  )
);

-- Sin update/delete: historial inmutable.

grant select, insert on public.production_movements to authenticated;
revoke update, delete on public.production_movements from authenticated, anon;

-- ---------------------------------------------------------------------
-- returns (solo rol Comercial puede ver/crear devoluciones)
-- ---------------------------------------------------------------------
alter table public.returns enable row level security;

drop policy if exists "returns_select_comercial" on public.returns;
create policy "returns_select_comercial"
on public.returns
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'comercial'
  )
);

drop policy if exists "returns_insert_comercial" on public.returns;
create policy "returns_insert_comercial"
on public.returns
for insert
to authenticated
with check (
  user_id = (select id from public.profiles where auth_id = auth.uid())
  and exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'comercial'
  )
);

-- Sin update/delete: historial de devoluciones inmutable.

grant select, insert on public.returns to authenticated;
revoke update, delete on public.returns from authenticated, anon;

-- ---------------------------------------------------------------------
-- Vistas calculadas: permitir SELECT a usuarios autenticados.
-- Las vistas se crearon con security_invoker = true (ver
-- 005_views_dashboard.sql), por lo que respetan las políticas RLS de
-- las tablas base segun el usuario que consulta, no segun el dueño de
-- la vista.
-- ---------------------------------------------------------------------
grant select on public.vw_pedidos_con_id to authenticated;
grant select on public.vw_item_stage to authenticated;
grant select on public.vw_item_progreso to authenticated;
grant select on public.vw_pedido_progreso to authenticated;
grant select on public.vw_historial to authenticated;

grant execute on function public.generar_item_id(text, text, text, text, text) to authenticated;
