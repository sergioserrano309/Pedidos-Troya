import { supabase } from '../config/supabaseClient.js';

/**
 * Servicio de devoluciones (solo rol Comercial, reforzado también por
 * RLS en supabase/sql/006_rls_policies.sql).
 *
 * - action = 'MOLIDO': la cantidad se pierde/descarta. No se crea
 *   ningún movimiento adicional; solo queda registrada en `returns`
 *   para trazabilidad (aparece en el stat "Devuelto" pero NO se suma
 *   de vuelta a "Pendiente", según la fórmula exacta de la sección 10
 *   del documento).
 * - action = 'REPROCESO': la cantidad se suma de vuelta a "Pendiente"
 *   y el ítem vuelve a aparecer en la cola del proceso indicado en
 *   `reprocess_destination` (esto lo resuelve automáticamente
 *   vw_item_stage combinando movements + returns).
 */

/**
 * @param {object} params
 * @param {object} params.item                Fila de vw_item_progreso
 * @param {number} params.cantidad
 * @param {'QA_INTERNO'|'CLIENTE'} params.causal
 * @param {'Inyección'|'Refilado'|'Acabado'|'Mateado'} params.procesoFalla
 * @param {'MOLIDO'|'REPROCESO'} params.accion
 * @param {'Refilado'|'Acabado'|'Mateado'|null} params.destinoReproceso  Requerido solo si accion === 'REPROCESO'
 * @param {string} [params.observacion]
 * @param {{ id: string, role: string }} params.user
 */
export async function registrarDevolucion({
  item,
  cantidad,
  causal,
  procesoFalla,
  accion,
  destinoReproceso,
  observacion,
  user
}) {
  if (user.role !== 'comercial') {
    throw new Error('Solo el rol Comercial puede registrar devoluciones.');
  }

  const qty = Number(cantidad);
  if (!Number.isFinite(qty) || qty <= 0) {
    throw new Error('La cantidad a devolver debe ser mayor a 0.');
  }

  if (!causal) throw new Error('Selecciona un causal.');
  if (!procesoFalla) throw new Error('Selecciona el proceso que falló.');
  if (!accion) throw new Error('Selecciona una acción (Molido o Reproceso).');

  if (accion === 'REPROCESO' && !destinoReproceso) {
    throw new Error('Selecciona a qué proceso enviar el reproceso.');
  }

  const { data, error } = await supabase
    .from('returns')
    .insert({
      item_id: item.item_id,
      order_number: item.order_number,
      size: String(item.talla ?? ''),
      quantity: qty,
      causal,
      failed_process: procesoFalla,
      action: accion,
      reprocess_destination: accion === 'REPROCESO' ? destinoReproceso : null,
      observation: observacion || null,
      user_id: user.id
    })
    .select()
    .single();

  if (error) {
    console.error('[returnsService] Error registrando devolución:', error);
    throw new Error('No se pudo registrar la devolución. Intenta nuevamente.');
  }

  return data;
}
