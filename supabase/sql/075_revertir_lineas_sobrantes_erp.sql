-- =====================================================================
-- 075_revertir_lineas_sobrantes_erp.sql
-- Deshace 075: elimina las funciones de evaluacion de lineas que sobran.
-- NO muestra de nuevo las lineas que el Validador ya oculto con el boton
-- Aplicar (siguen con Cancelado = true).
--
-- ANTES, si quiere volver a mostrar las lineas ocultas:
--   select id, pedido, talla, clave_linea, valor_programa as unidades
--     from public.erp_cambios where estado = 'aplicado' and tipo = 'linea_sobrante';
--   select public.erp_revertir_cambio_interno(<id>, 'manual');
--
-- DESPUES de este archivo, ejecute de nuevo en este orden (son repetibles):
--   1) 074_cantidades_erp.sql   (restaura aplicar, deshacer e impacto de 074)
--   2) 072_cancelados_erp.sql   (restaura erp_registrar_cambios de 072)
-- =====================================================================

begin;

drop function if exists public.erp_impacto_cambios(bigint[]);
drop function if exists public.erp_evaluar_cambio(bigint);
drop function if exists public.erp_evaluar_linea_sobrante(bigint);
drop function if exists public.erp_buscar_linea(text, text, text, integer, boolean);

commit;
