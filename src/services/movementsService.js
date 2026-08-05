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
 * Registra VARIOS movimientos (una talla cada uno) en un solo viaje a la
 * base de datos, en vez de uno por talla. Cada fila sigue quedando como
 * un registro independiente en production_movements/Registros — la
 * diferencia es que se envían todos juntos, mucho más rápido que hacer
 * N llamadas seguidas.
 * @param {Array<{ item: object, cantidad: number, pendiente?: number }>} seleccion
 * @param {{ destino: string, observacion?: string, user: { id: string, role: string } }} opciones
 */
export async function registrarMovimientosLote(seleccion, { destino, observacion, user }) {
  const origen = nombreProcesoDeRol(user.role);

  if (!origen) {
    throw new Error('Tu rol no tiene permitido procesar ítems.');
  }

  const permitidos = destinosPermitidos(user.role);
  if (!permitidos.includes(destino)) {
    throw new Error(`Tu rol (${user.role}) no puede enviar a "${destino}".`);
  }

  const filas = seleccion.map(({ item, cantidad, pendiente }) => {
    const qty = Number(cantidad);
    if (!Number.isFinite(qty) || qty <= 0) {
      throw new Error(`Talla ${item.talla}: la cantidad debe ser un número mayor a 0.`);
    }

    const limite = pendiente !== undefined ? pendiente : item.cantidad_pendiente;
    if (qty > limite) {
      throw new Error(
        `Talla ${item.talla}: no puedes procesar ${qty} unidades, solo quedan ${limite} pendientes en este proceso.`
      );
    }

    return {
      item_id: item.item_id,
      order_number: item.order_number,
      reference: item.nombre_referencia || item.referencia || null,
      size: String(item.talla ?? ''),
      quantity: qty,
      from_process: origen,
      to_process: destino,
      user_id: user.id,
      observation: observacion || null
    };
  });

  const { data, error } = await supabase.from('production_movements').insert(filas).select();

  if (error) {
    console.error('[movementsService] Error registrando movimientos en lote:', error);
    throw new Error('No se pudo registrar el procesamiento. Intenta nuevamente.');
  }

  return data;
}

/**
 * Elimina un movimiento propio, con motivo obligatorio (ver
 * supabase/sql/014_eliminacion_registros.sql). Solo funciona si:
 *   - el movimiento lo creó el usuario actual, y
 *   - es el movimiento más reciente de esa talla (nada se creó después
 *     basándose en él).
 * Queda registrado en log_eliminaciones automáticamente.
 * @param {string} movimientoId
 * @param {string} motivo
 */
export async function eliminarMovimientoConMotivo(movimientoId, motivo) {
  const { error } = await supabase.rpc('eliminar_movimiento_con_motivo', {
    p_movimiento_id: movimientoId,
    p_motivo: motivo
  });

  if (error) {
    console.error('[movementsService] Error eliminando movimiento:', error);
    throw new Error(error.message || 'No se pudo eliminar el registro.');
  }
}
