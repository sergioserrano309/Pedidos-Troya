-- =====================================================================
-- 070_revertir_aplicar_cliente_erp.sql
-- Deshace la INFRAESTRUCTURA de 070: elimina las funciones nuevas y la
-- columna del interruptor. NO devuelve los nombres de cliente ya cambiados.
--
-- Para devolver los clientes a como estaban ANTES, ejecute PRIMERO, por cada
-- cambio aplicado (los ids salen de la pestana Cambios ERP o de esta consulta):
--
--   select id, pedido, valor_programa as cliente_anterior, valor_access as cliente_nuevo
--     from public.erp_cambios where estado = 'aplicado' and campo = 'Cliente';
--
--   select public.erp_revertir_cambio_interno(<id>, 'manual');
--
-- y recien despues este archivo.
--
-- Si solo quiere PAUSAR la aplicacion (sin borrar nada):
--   update public.erp_cambios_estado set aplicar_cliente = false;
-- =====================================================================

begin;

drop function if exists public.erp_revertir_cambio(bigint);
drop function if exists public.erp_revertir_cambio_interno(bigint, text);
drop function if exists public.erp_aplicar_cambios_cliente();
drop function if exists public.erp_norm_texto(text);

alter table public.erp_cambios_estado drop column if exists aplicar_cliente;

commit;
