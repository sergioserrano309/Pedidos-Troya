-- =====================================================================
-- 029_despachos_rls.sql
-- RLS del modulo Despachos. Empaque (y Validador emulando Empaque) puede
-- ver todo. Las 3 tablas "de hechos ya creados" (despachos/
-- despacho_ordenes/despacho_bultos) NO tienen politica de insert/update/
-- delete para authenticated — solo se escriben via el RPC crear_despacho
-- (030, security definer), igual que p_pedidosh es de solo lectura para
-- la app y log_eliminaciones solo se llena via su propia funcion.
--
-- despacho_orden_bultos es la unica tabla con escritura directa: el
-- borrador de asignacion es editable libremente MIENTRAS el despacho no
-- este confirmado, y se congela por completo despues (ver justificacion
-- en 027).
-- =====================================================================

alter table public.despachos enable row level security;
alter table public.despacho_ordenes enable row level security;
alter table public.despacho_bultos enable row level security;
alter table public.despacho_orden_bultos enable row level security;

-- ---------------------------------------------------------------------
-- despachos
-- ---------------------------------------------------------------------
drop policy if exists "despachos_select_empaque" on public.despachos;
create policy "despachos_select_empaque"
on public.despachos
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('empaque', 'validador')
  )
);

-- ---------------------------------------------------------------------
-- despacho_ordenes
-- ---------------------------------------------------------------------
drop policy if exists "despacho_ordenes_select_empaque" on public.despacho_ordenes;
create policy "despacho_ordenes_select_empaque"
on public.despacho_ordenes
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('empaque', 'validador')
  )
);

-- ---------------------------------------------------------------------
-- despacho_bultos
-- ---------------------------------------------------------------------
drop policy if exists "despacho_bultos_select_empaque" on public.despacho_bultos;
create policy "despacho_bultos_select_empaque"
on public.despacho_bultos
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('empaque', 'validador')
  )
);

-- ---------------------------------------------------------------------
-- despacho_orden_bultos — la unica con escritura directa (RLS + trigger
-- de 027 juntas hacen el "borrador editable solo mientras no confirmado")
-- ---------------------------------------------------------------------
drop policy if exists "despacho_orden_bultos_select_empaque" on public.despacho_orden_bultos;
create policy "despacho_orden_bultos_select_empaque"
on public.despacho_orden_bultos
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('empaque', 'validador')
  )
);

drop policy if exists "despacho_orden_bultos_insert_borrador" on public.despacho_orden_bultos;
create policy "despacho_orden_bultos_insert_borrador"
on public.despacho_orden_bultos
for insert
to authenticated
with check (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('empaque', 'validador')
  )
  and exists (
    select 1 from public.despachos d
    where d.id = despacho_id and d.asignacion_confirmada = false
  )
);

drop policy if exists "despacho_orden_bultos_update_borrador" on public.despacho_orden_bultos;
create policy "despacho_orden_bultos_update_borrador"
on public.despacho_orden_bultos
for update
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('empaque', 'validador')
  )
  and exists (
    select 1 from public.despachos d
    where d.id = despacho_id and d.asignacion_confirmada = false
  )
)
with check (
  exists (
    select 1 from public.despachos d
    where d.id = despacho_id and d.asignacion_confirmada = false
  )
);

drop policy if exists "despacho_orden_bultos_delete_borrador" on public.despacho_orden_bultos;
create policy "despacho_orden_bultos_delete_borrador"
on public.despacho_orden_bultos
for delete
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('empaque', 'validador')
  )
  and exists (
    select 1 from public.despachos d
    where d.id = despacho_id and d.asignacion_confirmada = false
  )
);

-- Sin insert/update/delete para despachos/despacho_ordenes/despacho_bultos:
-- solo el RPC crear_despacho (030, security definer) las escribe.
grant select on public.despachos, public.despacho_ordenes, public.despacho_bultos to authenticated;
revoke insert, update, delete on public.despachos, public.despacho_ordenes, public.despacho_bultos from authenticated, anon;

grant select, insert, update, delete on public.despacho_orden_bultos to authenticated;
