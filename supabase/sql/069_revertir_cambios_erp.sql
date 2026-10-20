-- =====================================================================
-- 069_revertir_cambios_erp.sql
-- Deshace 069: elimina la funcion y las dos tablas nuevas
-- (erp_cambios y erp_cambios_estado). La fase 1 no modifica ningun pedido,
-- asi que no hay datos de produccion que restaurar; solo se pierde el
-- historial de diferencias detectadas.
--
-- Si solo quiere PAUSAR el detector (sin borrar nada):
--   update public.erp_cambios_estado set activo = false;
-- =====================================================================

begin;

drop function if exists public.erp_registrar_cambios(jsonb, jsonb);
drop table if exists public.erp_cambios;
drop table if exists public.erp_cambios_estado;

commit;
