import { supabase } from '../config/supabaseClient.js';
import { prepararLineas } from '../lib/dashboard.js';

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
  operativo: 'Otro motivo operativo',
  despachado_troya_total: 'Cerrado y despachado en Troya (total)',
  despachado_troya_parcial: 'Cerrado y despachado en Troya (parcial)'
};

/** Los dos tipos "despachado en Troya" (089). */
export const TIPOS_TROYA = ['despachado_troya_total', 'despachado_troya_parcial'];

/** Explicación corta de cada tipo (la misma de la ventana de cierre). */
export const TIPOS_CIERRE_AYUDA = {
  cancelado: 'El pedido se canceló. No cuenta como pendiente en el Dashboard.',
  no_terminado: 'No se despachó completo y ya no se va a despachar más. NO cuenta como pendiente.',
  operativo: 'Cualquier otra razón de la operación. Sí cuenta como pendiente.',
  despachado_troya_total: 'Todo lo que faltaba salió en Troya. Cuenta como despachado, no como pendiente.',
  despachado_troya_parcial: 'Una parte salió en Troya; tú repartes lo que faltaba por talla: despachado en Troya, sigue pendiente o ya no se despachará.'
};

/** Texto de un tipo de cierre; "Sin clasificar" si es un cierre anterior a 087. */
export function etiquetaTipoCierre(tipo) {
  return TIPOS_CIERRE[tipo] || 'Sin clasificar';
}

/**
 * @param {{ fechaTroya?: string|null, lineas?: Array<{item_id:string, despachado_troya:number, no_se_despacha:number}> }} [extra]
 *   Solo para los tipos "despachado en Troya" (089).
 */
export async function cerrarPedidoForzado(orderNumber, motivo, tipo, extra = {}) {
  const { error } = await supabase.rpc('cerrar_pedido_forzado', {
    p_order_number: String(orderNumber),
    p_motivo: motivo,
    p_tipo: tipo,
    p_fecha_troya: TIPOS_TROYA.includes(tipo) ? (extra.fechaTroya || null) : null,
    p_lineas: tipo === 'despachado_troya_parcial' ? (extra.lineas || []) : null
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

/**
 * Igual que fetchTiposCierre, pero devuelve null si la consulta falla (para no
 * mostrar todo como "Sin clasificar" por un error): lo usa el filtro Estado.
 * @returns {Promise<Map<string, string|null>|null>}
 */
export async function fetchTiposCierreONulo() {
  const mapa = new Map();
  const { data, error } = await supabase.from('pedido_cierre_forzado').select('order_number, tipo_cierre');
  if (error) {
    console.error('[cierreForzadoService] Error leyendo los tipos de cierre:', error);
    return null;
  }
  (data || []).forEach((f) => mapa.set(String(f.order_number), f.tipo_cierre || null));
  return mapa;
}

/** Cambia el tipo de un cierre ya hecho (089). Deja huella en la auditoría. */
export async function cambiarTipoCierreForzado(orderNumber, tipo, extra = {}) {
  const { error } = await supabase.rpc('cambiar_tipo_cierre_forzado', {
    p_order_number: String(orderNumber),
    p_tipo: tipo,
    p_fecha_troya: TIPOS_TROYA.includes(tipo) ? (extra.fechaTroya || null) : null,
    p_lineas: tipo === 'despachado_troya_parcial' ? (extra.lineas || []) : null
  });
  if (error) {
    console.error('[cierreForzadoService] Error cambiando el tipo del cierre:', error);
    throw new Error(error.message || 'No se pudo cambiar el tipo del cierre.');
  }
}

/**
 * Tallas de un pedido con lo que falta por despachar y, si ya hay un cierre
 * parcial, lo guardado. Para la tabla del cierre "despachado en Troya".
 * @returns {Promise<Array<{ item_id: string, talla: string, falta: number, despachado_troya: number, no_se_despacha: number }>>}
 */
export async function fetchTallasParaCierre(orderNumber) {
  const { data, error } = await supabase
    .from('vw_dashboard_lineas')
    .select('item_id, talla, solicitado, despachado, troya_despachado, troya_no_se_despacha')
    .eq('order_number', String(orderNumber))
    .order('talla', { ascending: true });
  if (error) {
    console.error('[cierreForzadoService] Error leyendo las tallas del pedido:', error);
    throw new Error('No se pudieron leer las tallas del pedido.');
  }
  return (data || []).map((l) => ({
    item_id: l.item_id,
    talla: String(l.talla ?? ''),
    falta: Math.max((Number(l.solicitado) || 0) - (Number(l.despachado) || 0), 0),
    despachado_troya: Number(l.troya_despachado) || 0,
    no_se_despacha: Number(l.troya_no_se_despacha) || 0
  }));
}

/**
 * Pares "despachados en Troya" (089) por pedido, para sumarlos a DESP. en
 * Control Central. Usa las mismas reglas del Dashboard de unidades
 * (prepararLineas): total = todo lo que faltaba; parcial = lo escrito por
 * talla; un pedido cancelado en Access no suma. Solo lectura.
 * Si falla (p. ej. el SQL 089 aún no está ejecutado) devuelve un mapa vacío:
 * DESP. sigue mostrando los despachos reales.
 * @param {string[]} orderNumbers
 * @returns {Promise<Map<string, number>>}
 */
export async function fetchTroyaPorPedidos(orderNumbers) {
  const mapa = new Map();
  if (!orderNumbers?.length) return mapa;

  const { data, error } = await supabase
    .from('vw_dashboard_lineas')
    .select('order_number, solicitado, despachado, cancelado_access, tipo_cierre, troya_despachado, troya_no_se_despacha')
    .in('order_number', orderNumbers.map(String))
    .in('tipo_cierre', TIPOS_TROYA);
  if (error) {
    console.error('[cierreForzadoService] Error leyendo despachado en Troya:', error);
    return mapa;
  }

  prepararLineas(data || [], '').forEach((l) => {
    if (l.enTroya > 0) mapa.set(l.order_number, (mapa.get(l.order_number) || 0) + l.enTroya);
  });
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
    .select('tipo_cierre, fecha_despacho_troya')
    .eq('order_number', String(orderNumber))
    .maybeSingle();

  return {
    motivo: data.cierre_forzado_motivo || '',
    cerradoAt: data.cierre_forzado_at,
    cerradoPor: data.cierre_forzado_por || '',
    tipo: fila?.tipo_cierre || null,
    fechaTroya: fila?.fecha_despacho_troya || null
  };
}
