-- =====================================================================
-- 015_indices_performance.sql
-- p_pedidosh no tenía NINGÚN índice (ni siquiera en PedidoNo), a pesar de
-- que vw_item_progreso/vw_pedido_progreso lo agrupan y filtran por
-- PedidoNo en cada consulta, y los dropdowns de filtro hacen DISTINCT
-- sobre NombreR/MaterialP/ColorP/Cliente. Sin índice, cada llamada
-- escanea la tabla completa. También faltaban índices sobre
-- from_process/to_process en production_movements, usados en cada
-- FILTER (WHERE ...) de las vistas.
--
-- Crear índices es una operación segura y reversible: no borra ni
-- modifica ningún dato, solo acelera las búsquedas.
-- =====================================================================

create index if not exists idx_pedidosh_pedidono on public.p_pedidosh ("PedidoNo");
create index if not exists idx_pedidosh_nombrer on public.p_pedidosh ("NombreR");
create index if not exists idx_pedidosh_materialp on public.p_pedidosh ("MaterialP");
create index if not exists idx_pedidosh_colorp on public.p_pedidosh ("ColorP");
create index if not exists idx_pedidosh_cliente on public.p_pedidosh ("Cliente");
create index if not exists idx_pedidosh_cancelado on public.p_pedidosh ("Cancelado");

create index if not exists idx_movements_from_process on public.production_movements (from_process);
create index if not exists idx_movements_to_process on public.production_movements (to_process);
