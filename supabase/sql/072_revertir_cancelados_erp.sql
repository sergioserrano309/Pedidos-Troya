-- =====================================================================
-- 072_revertir_cancelados_erp.sql
-- Deshace la INFRAESTRUCTURA de 072. NO reabre los pedidos que el sistema
-- ya cerro por cancelacion.
--
-- ANTES de ejecutar este archivo, si quiere reabrir los pedidos cerrados
-- por el sistema (cerrado_por vacio y motivo "Cancelado en Troya"):
--
--   select order_number, cerrado_at from public.pedido_cierre_forzado
--    where cerrado_por is null and motivo = 'Cancelado en Troya';
--
--   delete from public.pedido_cierre_forzado
--    where cerrado_por is null and motivo = 'Cancelado en Troya';
--
-- Despues de este archivo, vuelva a ejecutar 069_cambios_erp.sql (es
-- repetible) para restaurar erp_registrar_cambios a su version anterior.
--
-- La columna pedido_cierre_forzado.cerrado_por queda admitiendo vacio (es
-- inofensivo). Solo si NO queda ningun cierre con cerrado_por vacio puede
-- volver a exigirla:
--   alter table public.pedido_cierre_forzado alter column cerrado_por set not null;
--
-- Si solo quiere PAUSAR los cierres (sin borrar nada):
--   update public.erp_cambios_estado
--      set aplicar_campos = array_remove(aplicar_campos, 'Cancelado');
-- =====================================================================

begin;

-- Restaura el deshacer de 071 como funcion principal.
drop function if exists public.erp_revertir_cambio_interno(bigint, text);
do $$
begin
  if to_regprocedure('public.erp_revertir_texto_interno(bigint,text)') is not null then
    alter function public.erp_revertir_texto_interno(bigint, text) rename to erp_revertir_cambio_interno;
  end if;
end $$;

-- Restaura la funcion que llama el script como la de 071 (solo textos).
drop function if exists public.erp_aplicar_cambios();
do $$
begin
  if to_regprocedure('public.erp_aplicar_textos()') is not null then
    alter function public.erp_aplicar_textos() rename to erp_aplicar_cambios;
  end if;
end $$;

drop function if exists public.erp_aplicar_cancelados();

commit;
