-- =====================================================================
-- 058_revertir_ocultar_pedidos.sql
-- Deshace por completo 058_ocultar_pedidos_anteriores.sql: quita los
-- filtros, la vista y las funciones. No toca ningun dato; todo vuelve a
-- mostrarse exactamente como antes.
-- =====================================================================

begin;

drop policy if exists "oculto_pedidos_anteriores" on public.p_pedidosh;
drop policy if exists "oculto_pedidos_anteriores" on public.production_movements;
drop policy if exists "oculto_pedidos_anteriores" on public.returns;
drop policy if exists "oculto_pedidos_anteriores" on public.order_destino;
drop policy if exists "oculto_pedidos_anteriores" on public.pedido_cierre_forzado;
drop policy if exists "oculto_pedidos_anteriores" on public.despacho_ordenes;
drop policy if exists "oculto_pedidos_anteriores" on public.despacho_orden_items;
drop policy if exists "oculto_pedidos_anteriores" on public.despacho_orden_bultos;
drop policy if exists "oculto_pedidos_anteriores" on public.despachos;
drop policy if exists "oculto_pedidos_anteriores" on public.despacho_bultos;
drop policy if exists "oculto_pedidos_anteriores" on public.audit_validador;
drop policy if exists "oculto_pedidos_anteriores" on public.log_eliminaciones;

drop function if exists public.fn_snapshot_despacho_oculto(jsonb);
drop function if exists public.fn_despacho_oculto(uuid);
drop view if exists public.vw_pedidos_ocultos;
drop function if exists public.fn_fecha_corte_visible();

commit;
