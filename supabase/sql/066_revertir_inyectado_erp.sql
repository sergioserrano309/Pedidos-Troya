-- =====================================================================
-- 066_revertir_inyectado_erp.sql
-- Deshace la INFRAESTRUCTURA de 066: elimina las funciones y las dos
-- tablas nuevas (erp_sync_estado y erp_inyectado_log).
--
-- IMPORTANTE - ESTO NO DEVUELVE LOS VALORES DE Total01Iny:
--   Las funciones solo modificaron la columna "Total01Iny" de p_pedidosh.
--   Si ademas quiere volver esos valores a como estaban ANTES, ejecute
--   PRIMERO, por cada corrida a deshacer (el corrida_id sale de
--   erp_inyectado_log):
--
--     select public.erp_revertir_corrida('<corrida_id>');
--
--   y recien despues este archivo (que borra el log y con el, la posibilidad
--   de revertir). Para ver las corridas:
--
--     select corrida_id, min(registrado_at), count(*) as cambios
--       from public.erp_inyectado_log group by corrida_id order by 2 desc;
--
-- Si solo quiere PAUSAR (sin borrar nada): update public.erp_sync_estado set activo = false;
-- =====================================================================

begin;

drop function if exists public.erp_revertir_corrida(uuid);
drop function if exists public.erp_registrar_corrida(jsonb);
drop function if exists public.erp_actualizar_inyectado(jsonb);

drop table if exists public.erp_inyectado_log;
drop table if exists public.erp_sync_estado;

commit;
