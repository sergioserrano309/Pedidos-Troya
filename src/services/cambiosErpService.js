import { supabase } from '../config/supabaseClient.js';

/**
 * Lectura de erp_cambios (Fase 1): diferencias entre Access y el programa que
 * registra el detector. SOLO LECTURA: ninguna función escribe, y nada de esto
 * entra en producción, porcentajes ni despachos.
 *
 * Toda función tolera errores (devuelve null o []): la nota, la insignia y el
 * panel son informativos y nunca deben impedir abrir un pedido.
 */

const LOTE = 1000; // tope de filas por consulta de Supabase

const COLUMNAS = 'id, pedido, talla, tipo, campo, clave_linea, valor_access, valor_programa, ambiguo, estado, '
  + 'detectado_at, ultima_revision_at, revisiones_consecutivas, resuelto_at, contexto';

async function leerTodo(construirConsulta) {
  const filas = [];
  for (let desde = 0; ; desde += LOTE) {
    const { data, error } = await construirConsulta().range(desde, desde + LOTE - 1);
    if (error) throw error;
    filas.push(...(data || []));
    if (!data || data.length < LOTE) break;
  }
  return filas;
}

function consultaBase() {
  // id al final: orden estable entre páginas.
  return supabase
    .from('erp_cambios')
    .select(COLUMNAS)
    .order('detectado_at', { ascending: false })
    .order('id', { ascending: false });
}

/**
 * Diferencias de UN pedido (para la nota del detalle). Todas las que no están
 * resueltas; las resueltas solo se ven en el panel y el Excel.
 * @returns {Promise<Array>} [] si no hay o si la consulta falla.
 */
export async function fetchCambiosDePedido(orderNumber) {
  try {
    const { data, error } = await supabase
      .from('erp_cambios')
      .select(COLUMNAS)
      .eq('pedido', String(orderNumber))
      .in('estado', ['pendiente', 'aplicado', 'rechazado'])
      .order('talla', { ascending: true, nullsFirst: true })
      .order('id', { ascending: true });
    if (error) throw error;
    return data || [];
  } catch (err) {
    console.error('[cambiosErpService] Error obteniendo cambios del pedido:', err);
    return [];
  }
}

/**
 * Cuántas diferencias pendientes tiene cada pedido de la página visible
 * (para la insignia ⚠ del listado).
 * @param {Array<string|number>} orderNumbers
 * @returns {Promise<Map<string, number>>} vacío si no hay o si falla.
 */
export async function fetchPendientesPorPedidos(orderNumbers) {
  const ids = [...new Set((orderNumbers || []).map(String).filter(Boolean))];
  const mapa = new Map();
  if (ids.length === 0) return mapa;
  try {
    const { data, error } = await supabase
      .from('erp_cambios')
      .select('pedido')
      .in('pedido', ids)
      .eq('estado', 'pendiente')
      .limit(5000);
    if (error) throw error;
    (data || []).forEach((f) => mapa.set(f.pedido, (mapa.get(f.pedido) || 0) + 1));
  } catch (err) {
    console.error('[cambiosErpService] Error obteniendo pendientes por pedido:', err);
  }
  return mapa;
}

/**
 * Todas las diferencias (también las resueltas) para el panel del Validador.
 * @returns {Promise<Array|null>} null si la consulta falla: el panel lo avisa.
 */
export async function fetchCambiosPanel() {
  try {
    return await leerTodo(consultaBase);
  } catch (err) {
    console.error('[cambiosErpService] Error obteniendo cambios para el panel:', err);
    return null;
  }
}

/** Para la hoja "Cambios ERP" del Excel: [] si falla (la hoja sale vacía). */
export async function fetchTodosLosCambiosERP() {
  const filas = await fetchCambiosPanel();
  return filas || [];
}

/**
 * Estado del detector (erp_cambios_estado, una sola fila). Solo el Validador
 * puede leerla (RLS). null si no se pudo leer.
 */
export async function fetchEstadoDetector() {
  try {
    const { data, error } = await supabase
      .from('erp_cambios_estado')
      .select('activo, ultima_ejecucion, ultimo_resultado, lineas_access, lineas_supabase, cambios_pendientes, nuevas, resueltas')
      .eq('id', 1)
      .maybeSingle();
    if (error) throw error;
    return data || null;
  } catch (err) {
    console.error('[cambiosErpService] Error obteniendo el estado del detector:', err);
    return null;
  }
}
