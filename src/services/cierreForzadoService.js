import { supabase } from '../config/supabaseClient.js';

/**
 * Cierre forzado de un pedido por el Validador (supabase/sql/057_cierre_forzado.sql).
 * La escritura pasa SOLO por los RPC (que exigen rol validador); el candado
 * de "no registrar ni borrar" vive en triggers de la base.
 */

/**
 * Por qué se cierra un pedido a la fuerza (087). El Validador lo elige al
 * cerrar; "cancelado" no cuenta como pendiente en el Dashboard.
 */
export const TIPOS_CIERRE = {
  cancelado: 'Cancelado',
  no_terminado: 'No se terminó de despachar',
  operativo: 'Otro motivo operativo'
};

/** Texto de un tipo de cierre; "Sin clasificar" si es un cierre anterior a 087. */
export function etiquetaTipoCierre(tipo) {
  return TIPOS_CIERRE[tipo] || 'Sin clasificar';
}

export async function cerrarPedidoForzado(orderNumber, motivo, tipo) {
  const { error } = await supabase.rpc('cerrar_pedido_forzado', {
    p_order_number: String(orderNumber),
    p_motivo: motivo,
    p_tipo: tipo
  });
  if (error) {
    console.error('[cierreForzadoService] Error cerrando pedido:', error);
    throw new Error(error.message || 'No se pudo cerrar el pedido.');
  }
}

/** Clasifica un cierre que estaba sin clasificar (cierres anteriores a 087). */
export async function clasificarCierreForzado(orderNumber, tipo) {
  const { error } = await supabase.rpc('clasificar_cierre_forzado', {
    p_order_number: String(orderNumber),
    p_tipo: tipo
  });
  if (error) {
    console.error('[cierreForzadoService] Error clasificando el cierre:', error);
    throw new Error(error.message || 'No se pudo clasificar el cierre.');
  }
}

/**
 * Tipo de cierre de cada pedido cerrado a la fuerza, para el Excel. Si falla
 * devuelve un mapa vacío (la columna sale "Sin clasificar") y la descarga sigue.
 * @returns {Promise<Map<string, string|null>>}
 */
export async function fetchTiposCierre() {
  const mapa = new Map();
  const { data, error } = await supabase.from('pedido_cierre_forzado').select('order_number, tipo_cierre');
  if (error) {
    console.error('[cierreForzadoService] Error leyendo los tipos de cierre:', error);
    return mapa;
  }
  (data || []).forEach((f) => mapa.set(String(f.order_number), f.tipo_cierre || null));
  return mapa;
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
 * @returns {Promise<{ motivo: string, cerradoAt: string, cerradoPor: string, tipo: string|null }|null>}
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

  // El tipo (087) vive en la tabla del cierre; si no se puede leer, queda sin clasificar.
  const { data: fila } = await supabase
    .from('pedido_cierre_forzado')
    .select('tipo_cierre')
    .eq('order_number', String(orderNumber))
    .maybeSingle();

  return {
    motivo: data.cierre_forzado_motivo || '',
    cerradoAt: data.cierre_forzado_at,
    cerradoPor: data.cierre_forzado_por || '',
    tipo: fila?.tipo_cierre || null
  };
}
