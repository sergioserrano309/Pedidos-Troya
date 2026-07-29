import { supabase } from '../config/supabaseClient.js';
import { nombreProcesoDeRol, destinosPermitidos } from '../lib/roles.js';

/**
 * Servicio de movimientos de producción.
 *
 * IMPORTANTE: esto es lo ÚNICO que avanza la producción. Nunca se
 * modifica "Pedidos Prueba". Cada llamada aquí hace un INSERT en
 * production_movements (tabla append-only, ver RLS en
 * supabase/sql/006_rls_policies.sql).
 */

/**
 * @param {object} params
 * @param {object} params.item     Fila de vw_item_progreso (debe incluir item_id, order_number, referencia/nombre_referencia, talla, cantidad_pendiente)
 * @param {number} params.cantidad Cantidad a procesar ahora
 * @param {string} params.destino  Proceso destino ('Acabado' | 'Mateado' | 'Empaque' | 'Completado')
 * @param {string} [params.observacion]
 * @param {{ id: string, role: string }} params.user Usuario autenticado (perfil)
 */
export async function registrarMovimiento({ item, cantidad, destino, observacion, user }) {
  const origen = nombreProcesoDeRol(user.role);

  if (!origen) {
    throw new Error('Tu rol no tiene permitido procesar ítems.');
  }

  const permitidos = destinosPermitidos(user.role);
  if (!permitidos.includes(destino)) {
    throw new Error(`Tu rol (${user.role}) no puede enviar a "${destino}".`);
  }

  const qty = Number(cantidad);
  if (!Number.isFinite(qty) || qty <= 0) {
    throw new Error('La cantidad debe ser un número mayor a 0.');
  }

  if (qty > item.cantidad_pendiente) {
    throw new Error(
      `No puedes procesar ${qty} unidades: solo quedan ${item.cantidad_pendiente} pendientes.`
    );
  }

  const { data, error } = await supabase
    .from('production_movements')
    .insert({
      item_id: item.item_id,
      order_number: item.order_number,
      reference: item.nombre_referencia || item.referencia || null,
      size: String(item.talla ?? ''),
      quantity: qty,
      from_process: origen,
      to_process: destino,
      user_id: user.id,
      observation: observacion || null
    })
    .select()
    .single();

  if (error) {
    console.error('[movementsService] Error registrando movimiento:', error);
    throw new Error('No se pudo registrar el procesamiento. Intenta nuevamente.');
  }

  return data;
}
