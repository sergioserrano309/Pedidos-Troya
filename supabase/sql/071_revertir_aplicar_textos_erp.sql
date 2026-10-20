-- =====================================================================
-- 071_revertir_aplicar_textos_erp.sql
-- Deshace la INFRAESTRUCTURA de 071: elimina la funcion generica, las ayudas
-- y la columna de interruptores. NO devuelve los valores ya cambiados.
--
-- Para devolver los datos a como estaban ANTES, ejecute PRIMERO, por cada
-- cambio aplicado:
--
--   select id, pedido, talla, campo, valor_programa as anterior, valor_access as nuevo
--     from public.erp_cambios where estado = 'aplicado' and tipo = 'texto';
--
--   select public.erp_revertir_cambio_interno(<id>, 'manual');
--
-- y recien despues este archivo.
--
-- Despues de este archivo vuelve a regir 070: ejecute de nuevo
-- 070_aplicar_cliente_erp.sql (es repetible) para recuperar la funcion y el
-- interruptor solo de Cliente.
--
-- Si solo quiere PAUSAR (sin borrar nada):
--   update public.erp_cambios_estado set aplicar_campos = '{}';
-- =====================================================================

begin;

drop function if exists public.erp_aplicar_cambios();
drop function if exists public.erp_valor_cmp(text, text);
drop function if exists public.erp_campo_columna(text);

alter table public.erp_cambios_estado drop column if exists aplicar_campos;

commit;
