-- =====================================================================
-- 074_revertir_cantidades_erp.sql
-- Deshace 074: elimina las funciones de evaluacion/impacto de cantidades.
-- NO revierte las cantidades ya aplicadas con el boton Aplicar.
--
-- ANTES, si quiere devolver las cantidades aplicadas a como estaban:
--   select id, pedido, talla, valor_programa as anterior, valor_access as nueva
--     from public.erp_cambios where estado = 'aplicado' and tipo = 'cantidad';
--   select public.erp_revertir_cambio_interno(<id>, 'manual');
--
-- DESPUES de este archivo, ejecute de nuevo 073_botones_aplicar_descartar_erp.sql
-- (es repetible) para restaurar las funciones de aplicar y deshacer de 073.
-- =====================================================================

begin;

drop function if exists public.erp_impacto_cambios(bigint[]);
drop function if exists public.erp_evaluar_cantidad(bigint);
drop function if exists public.erp_estado_talla(text, text);

commit;
