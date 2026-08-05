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
  const { error } = await supabase
    .from('order_destino')
    .insert({ order_number: orderNumber, destino, confirmed_by: user.id });

  if (error) {
    console.error('[destinoService] Error confirmando destino de la orden:', error);
    throw new Error('No se pudo confirmar el destino del pedido. Intenta nuevamente.');
  }
}
