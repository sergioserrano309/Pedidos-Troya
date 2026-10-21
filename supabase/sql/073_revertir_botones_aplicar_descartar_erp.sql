-- =====================================================================
-- 073_revertir_botones_aplicar_descartar_erp.sql
-- Deshace 073: elimina las funciones de los botones Aplicar y Descartar y
-- devuelve el "deshacer" a la version de 072. NO reabre los pedidos que el
-- Validador cerro con el boton Aplicar ni cambia las diferencias descartadas.
--
-- Despues de este archivo, ejecute de nuevo 072_cancelados_erp.sql (es
-- repetible) para restaurar la version de erp_revertir_cambio_interno de 072.
--
-- Si hay diferencias descartadas que quiere volver a ver como pendientes:
--   update public.erp_cambios set estado = 'pendiente'
--    where estado = 'rechazado' and historial @> '[{"accion":"descartado"}]';
-- =====================================================================

begin;

drop function if exists public.erp_aplicar_cambio(bigint);
drop function if exists public.erp_aplicar_cambio_interno(bigint, uuid);
drop function if exists public.erp_descartar_cambio(bigint);
drop function if exists public.erp_descartar_cambio_interno(bigint, uuid);

commit;
