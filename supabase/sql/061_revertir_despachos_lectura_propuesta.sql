-- =====================================================================
-- 061_revertir_despachos_lectura_propuesta.sql
-- Deshace 061_despachos_lectura_propuesta.sql: el rol 'propuesta' vuelve
-- a no poder leer las tablas de despachos. No toca las politicas de
-- empaque/validador.
-- =====================================================================

drop policy if exists "despachos_select_propuesta" on public.despachos;
drop policy if exists "despacho_ordenes_select_propuesta" on public.despacho_ordenes;
drop policy if exists "despacho_bultos_select_propuesta" on public.despacho_bultos;
drop policy if exists "despacho_orden_bultos_select_propuesta" on public.despacho_orden_bultos;
drop policy if exists "despacho_orden_items_select_propuesta" on public.despacho_orden_items;
