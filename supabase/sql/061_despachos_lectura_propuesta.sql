-- =====================================================================
-- 061_despachos_lectura_propuesta.sql
-- El rol 'propuesta' pasa a poder VER la pestaña Despachos > Despachado
-- (solo lectura). Las 5 tablas de despachos tenian RLS de SELECT
-- unicamente para empaque/validador (029, 044); las vistas del listado y
-- del detalle son security_invoker, asi que heredaban esa restriccion y
-- Propuesta veria el listado vacio.
--
-- ALCANCE: SOLO SELECT. No se agrega ninguna politica de insert/update/
-- delete ni se toca ninguna funcion:
--   - crear_despacho / eliminar_despacho_con_motivo siguen exigiendo
--     empaque o validador (030/039/045/048/051).
--   - marcar_despacho_revisado sigue exigiendo validador (053).
-- Es decir, Propuesta no puede eliminar ni dar visto bueno aunque
-- llamara a los RPC directamente. La pantalla solo esconde los controles.
--
-- Politicas ADITIVAS: las de empaque/validador existentes no se tocan
-- (en Postgres varias politicas de SELECT se combinan con OR).
-- Mismo patron que 035_rls_precios_suelas.sql.
--
-- Reversible con 061_revertir_despachos_lectura_propuesta.sql.
-- =====================================================================

drop policy if exists "despachos_select_propuesta" on public.despachos;
create policy "despachos_select_propuesta"
on public.despachos
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

drop policy if exists "despacho_ordenes_select_propuesta" on public.despacho_ordenes;
create policy "despacho_ordenes_select_propuesta"
on public.despacho_ordenes
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

drop policy if exists "despacho_bultos_select_propuesta" on public.despacho_bultos;
create policy "despacho_bultos_select_propuesta"
on public.despacho_bultos
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

drop policy if exists "despacho_orden_bultos_select_propuesta" on public.despacho_orden_bultos;
create policy "despacho_orden_bultos_select_propuesta"
on public.despacho_orden_bultos
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);

drop policy if exists "despacho_orden_items_select_propuesta" on public.despacho_orden_items;
create policy "despacho_orden_items_select_propuesta"
on public.despacho_orden_items
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'propuesta'
  )
);
