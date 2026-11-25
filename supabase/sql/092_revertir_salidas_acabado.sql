-- =====================================================================
-- 092_revertir_salidas_acabado.sql
-- Quita por completo el modulo Salidas(A) (092). No toca Despachos, Empaque ni
-- ningun movimiento de produccion.
--
-- OJO: borra las salidas de Acabado ya creadas (sus tablas). Si necesitas
-- conservarlas, exporta antes:  select * from public.vw_salidas_a_registro;
-- El historial de eliminaciones (log_eliminaciones, tabla_origen = 'salidas_a')
-- NO se borra.
-- =====================================================================

begin;

-- Candado sobre los registros de Acabado (el unico que vive fuera de las tablas nuevas).
drop trigger if exists trg_validar_saldo_acabado_al_borrar on public.production_movements;
drop function if exists public.fn_validar_saldo_acabado_al_borrar();

-- Realtime
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'salidas_a'
  ) then
    alter publication supabase_realtime drop table public.salidas_a;
  end if;
end
$$;

drop view if exists public.vw_salidas_a_registro;
drop view if exists public.vw_pedido_salida_a_estado;
drop view if exists public.vw_pedidos_por_salir_a;
drop view if exists public.vw_item_salida_a_saldo;

drop function if exists public.crear_salida_a(text[], integer, numeric[], jsonb, jsonb, text);
drop function if exists public.eliminar_salida_a_con_motivo(uuid, text);
drop function if exists public.marcar_salida_a_revisada(uuid, boolean);
drop function if exists public.editar_comentario_salida_a(uuid, text);

drop table if exists public.salida_a_orden_items;
drop table if exists public.salida_a_orden_bultos;
drop table if exists public.salida_a_bultos;
drop table if exists public.salida_a_ordenes;
drop table if exists public.salidas_a;

drop function if exists public.fn_validar_saldo_salida_a_item();
drop function if exists public.fn_bloquear_borrado_salida_a_revisada();
drop function if exists public.fn_salida_a_inicio();
drop table if exists public.salidas_a_config;
drop sequence if exists public.salidas_a_numero_seq;

commit;
