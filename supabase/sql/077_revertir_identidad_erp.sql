-- =====================================================================
-- 077_revertir_identidad_erp.sql
-- Deshace 077: elimina las funciones de evaluacion de identidad y las ayudas.
-- NO restaura el material, color o referencia que el Validador ya aplico
-- con el boton Aplicar.
--
-- ANTES, si quiere devolver esos datos a como estaban:
--   select id, pedido, talla, campo, valor_programa as anterior, valor_access as nuevo
--     from public.erp_cambios where estado = 'aplicado' and tipo = 'identidad';
--   select public.erp_revertir_cambio_interno(<id de UNA talla del pedido>, 'manual');
--   (deshace todas las tallas de ese pedido aplicadas juntas)
--
-- DESPUES de este archivo, ejecute de nuevo en este orden (son repetibles):
--   1) 075_lineas_sobrantes_erp.sql   (restaura evaluar, aplicar y deshacer de 075)
--   2) 073_botones_aplicar_descartar_erp.sql  (restaura erp_descartar_cambio_interno de 073)
-- =====================================================================

begin;

drop function if exists public.erp_evaluar_identidad(bigint);
drop function if exists public.erp_grupo_identidad(bigint);
drop function if exists public.erp_item_id_congelado();
drop function if exists public.erp_columna_identidad(text);

commit;
