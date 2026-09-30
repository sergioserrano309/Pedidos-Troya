import { supabase } from '../config/supabaseClient.js';

/**
 * Cierre forzado de un pedido por el Validador (supabase/sql/057_cierre_forzado.sql).
 * La escritura pasa SOLO por los RPC (que exigen rol validador); el candado
 * de "no registrar ni borrar" vive en triggers de la base.
 */

export async function cerrarPedidoForzado(orderNumber, motivo) {
  const { error } = await supabase.rpc('cerrar_pedido_forzado', {
    p_order_number: String(orderNumber),
    p_motivo: motivo
  });
  if (error) {
    console.error('[cierreForzadoService] Error cerrando pedido:', error);
    throw new Error(error.message || 'No se pudo cerrar el pedido.');
  }
}

export async function reabrirPedidoForzado(orderNumber) {
  const { error } = await supabase.rpc('reabrir_pedido_forzado', {
    p_order_number: String(orderNumber)
  });
  if (error) {
    console.error('[cierreForzadoService] Error reabriendo pedido:', error);
    throw new Error(error.message || 'No se pudo reabrir el pedido.');
  }
}

/**
 * Números de pedido cerrados a la fuerza. Lo usa Despachos para no ofrecer
 * "A Despachar" pedidos cerrados (vw_pedidos_por_despachar es vp.* de la
 * vista y no se toca). Si falla devuelve [] y la base igual bloquea el
 * despacho con su trigger.
 * @returns {Promise<string[]>}
 */
export async function fetchPedidosCerradosForzado() {
  const { data, error } = await supabase.from('pedido_cierre_forzado').select('order_number');
  if (error) {
    console.error('[cierreForzadoService] Error leyendo pedidos cerrados:', error);
    return [];
  }
  return (data || []).map((r) => String(r.order_number));
}

/**
 * Estado de cierre forzado de UN pedido (para el detalle de la orden).
 * @returns {Promise<{ motivo: string, cerradoAt: string, cerradoPor: string }|null>}
 */
export async function fetchCierreForzadoDePedido(orderNumber) {
  const { data, error } = await supabase
    .from('vw_pedido_progreso')
    .select('cierre_forzado, cierre_forzado_motivo, cierre_forzado_at, cierre_forzado_por')
    .eq('order_number', String(orderNumber))
    .maybeSingle();
  if (error) {
    console.error('[cierreForzadoService] Error leyendo el cierre del pedido:', error);
    return null;
  }
  if (!data?.cierre_forzado) return null;
  return {
    motivo: data.cierre_forzado_motivo || '',
    cerradoAt: data.cierre_forzado_at,
    cerradoPor: data.cierre_forzado_por || ''
  };
}
