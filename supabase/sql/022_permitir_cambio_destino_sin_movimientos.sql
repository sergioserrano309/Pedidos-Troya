-- =====================================================================
-- 022_permitir_cambio_destino_sin_movimientos.sql
-- Hasta ahora order_destino no permitía update/delete: una vez
-- confirmado, el destino era inmutable para siempre (ver
-- supabase/sql/010_order_destino.sql). Eso es correcto en general, pero
-- deja sin salida el caso de un error humano de Refilado (confirmó
-- Acabado cuando debía ser Mateado) SIEMPRE que aún no se haya procesado
-- nada de esa orden.
--
-- Regla de negocio: el destino puede reemplazarse (borrar + volver a
-- insertar, ver cambiarDestinoOrden en destinoService.js) mientras
-- production_movements no tenga NINGUNA fila para ese order_number. En
-- cuanto exista un solo movimiento, esta política deja de aplicar y el
-- destino vuelve a ser inmutable (comportamiento original, sin cambios).
--
-- Los destinos asignados automáticamente por una regla de enrutamiento
-- (es_automatico = true) NO se ven afectados por esta migración: el
-- front (orderDetail.js) nunca ofrece la opción de cambiarlos, sin
-- importar si tienen o no movimientos — decisión explícita del negocio,
-- no una limitación técnica de esta política.
-- =====================================================================

drop policy if exists "order_destino_delete_sin_movimientos" on public.order_destino;
create policy "order_destino_delete_sin_movimientos"
on public.order_destino
for delete
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('refilado', 'validador')
  )
  and not exists (
    select 1 from public.production_movements pm
    where pm.order_number = order_destino.order_number
  )
);

grant delete on public.order_destino to authenticated;

comment on policy "order_destino_delete_sin_movimientos" on public.order_destino is
  'Permite a Refilado/Validador borrar (para luego re-insertar) el destino de una orden SOLO si aun no tiene ningun movimiento registrado. Ver cambiarDestinoOrden en src/services/destinoService.js (fix 022).';
