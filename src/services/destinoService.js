import { supabase } from '../config/supabaseClient.js';

/**
 * Destino (Acabado/Mateado/Empaque) confirmado UNA SOLA VEZ por Refilado
 * para TODO un pedido, ya que un pedido nunca se reparte entre Acabado y
 * Mateado (ver supabase/sql/010_order_destino.sql). Evita preguntar el
 * destino en cada ítem procesado.
 */

/**
 * @param {string} orderNumber
 * @returns {Promise<{ destino: string, confirmed_by: string|null, confirmed_at: string, es_automatico: boolean } | null>}
 */
export async function fetchDestinoOrden(orderNumber) {
  const { data, error } = await supabase
    .from('order_destino')
    .select('destino, confirmed_by, confirmed_at, es_automatico')
    .eq('order_number', orderNumber)
    .maybeSingle();

  if (error) {
    console.error('[destinoService] Error obteniendo destino de la orden:', error);
    return null;
  }

  return data;
}

/**
 * @param {string} orderNumber
 * @param {'Acabado'|'Mateado'|'Empaque'} destino
 * @param {{ id: string }} user
 */
export async function confirmarDestinoOrden(orderNumber, destino, user) {
  // Primero verificar si el destino ya fue confirmado para esta orden
  const existing = await fetchDestinoOrden(orderNumber);

  if (existing) {
    // Si ya existe y es el mismo, no es error (idempotente)
    if (existing.destino === destino) {
      return;
    }
    // Si es diferente, es un error
    throw new Error(`El destino de esta orden ya fue confirmado como ${existing.destino}. No se puede cambiar.`);
  }

  // Si no existe, proceder con el insert
  const { error } = await supabase
    .from('order_destino')
    .insert({ order_number: orderNumber, destino, confirmed_by: user.id });

  if (error) {
    console.error('[destinoService] Error confirmando destino de la orden:', error);
    // Mensaje más específico basado en el tipo de error
    if (error.message?.includes('not authenticated')) {
      throw new Error('No tienes permiso para confirmar el destino. Solo Refilado puede hacerlo.');
    }
    if (error.message?.includes('duplicate')) {
      throw new Error(`El destino de esta orden ya fue confirmado previamente.`);
    }
    throw new Error('No se pudo confirmar el destino del pedido. Intenta nuevamente.');
  }
}

/**
 * Reemplaza el destino de una orden que ya tenía uno confirmado (por
 * error humano de Refilado). Solo es posible mientras no exista ningún
 * movimiento registrado para esa orden — la autoridad real de esa regla
 * vive en la política RLS de DELETE (ver
 * supabase/sql/022_permitir_cambio_destino_sin_movimientos.sql), no aquí:
 * si ya hay movimientos, el DELETE simplemente falla en la base de datos
 * sin importar qué haya decidido el cliente.
 * @param {string} orderNumber
 * @param {'Acabado'|'Mateado'|'Empaque'} nuevoDestino
 * @param {{ id: string }} user
 */
export async function cambiarDestinoOrden(orderNumber, nuevoDestino, user) {
  // OJO: cuando la política RLS de delete bloquea la operación (porque
  // ya hay movimientos), Supabase NO devuelve error — simplemente borra
  // 0 filas en silencio. Por eso se pide .select() de vuelta: es la
  // única forma de distinguir "bloqueado por RLS" de "sí se borró", y
  // evitar que el insert de abajo falle después con un error confuso de
  // clave duplicada en vez de un mensaje claro.
  const { data: filasEliminadas, error: deleteError } = await supabase
    .from('order_destino')
    .delete()
    .eq('order_number', orderNumber)
    .select();

  if (deleteError) {
    console.error('[destinoService] Error eliminando destino previo de la orden:', deleteError);
    throw new Error('No se pudo cambiar el destino. Intenta nuevamente.');
  }

  if (!filasEliminadas || filasEliminadas.length === 0) {
    throw new Error('No se pudo cambiar el destino: ya hay movimientos registrados para este pedido.');
  }

  const { error } = await supabase
    .from('order_destino')
    .insert({ order_number: orderNumber, destino: nuevoDestino, confirmed_by: user.id });

  if (error) {
    console.error('[destinoService] Error confirmando el nuevo destino de la orden:', error);
    throw new Error('No se pudo confirmar el nuevo destino del pedido. Intenta nuevamente.');
  }
}
