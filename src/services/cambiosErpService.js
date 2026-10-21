import { supabase } from '../config/supabaseClient.js';

/**
 * Lectura de erp_cambios (Fase 1): diferencias entre Access y el programa que
 * registra el detector. Las funciones de lectura NO escriben, y nada de esto
 * entra en producción, porcentajes ni despachos. La única escritura es
 * revertirCambioErp (Fase 2, botón "Deshacer" del Validador).
 *
 * Toda lectura tolera errores (devuelve null o []): la nota, la insignia y el
 * panel son informativos y nunca deben impedir abrir un pedido.
 */

const LOTE = 1000; // tope de filas por consulta de Supabase

const COLUMNAS = 'id, pedido, talla, tipo, campo, clave_linea, valor_access, valor_programa, ambiguo, estado, '
  + 'detectado_at, ultima_revision_at, revisiones_consecutivas, resuelto_at, aplicado_at, aplicado_por, contexto';

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
 * Deshace un cambio de texto ya aplicado (función erp_revertir_cambio, SQL
 * 070/071; solo el Validador). Restaura el valor anterior y deja el cambio
 * como "deshecho" para que el detector no lo vuelva a aplicar. Lanza el
 * mensaje de la base si no se puede (p. ej. el dato cambió después).
 */
export async function revertirCambioErp(idCambio) {
  const { data, error } = await supabase.rpc('erp_revertir_cambio', { p_id: idCambio });
  if (error) throw new Error(error.message || 'No se pudo deshacer el cambio.');
  return data;
}

/**
 * Botón "Aplicar" (función erp_aplicar_cambio, SQL 073; solo el Validador):
 * aplica a mano un cambio pendiente. Hoy solo el CANCELADO: cierra el pedido a
 * la fuerza con motivo "Cancelado en Troya", firmado por quien hace clic.
 * Lanza el mensaje de la base si no se puede.
 */
export async function aplicarCambioErp(idCambio) {
  const { data, error } = await supabase.rpc('erp_aplicar_cambio', { p_id: idCambio });
  if (error) throw new Error(error.message || 'No se pudo aplicar el cambio.');
  return data;
}

/**
 * Botón "Descartar" (función erp_descartar_cambio, SQL 073; solo el
 * Validador): rechaza una diferencia pendiente. No toca ningún pedido.
 */
export async function descartarCambioErp(idCambio) {
  const { data, error } = await supabase.rpc('erp_descartar_cambio', { p_id: idCambio });
  if (error) throw new Error(error.message || 'No se pudo descartar el cambio.');
  return data;
}

/**
 * Campos de texto cuya aplicación automática está encendida
 * (erp_cambios_estado.aplicar_campos). Consulta aparte y tolerante: si la
 * columna aún no existe (SQL 071 sin ejecutar) o falla, devuelve null.
 * @returns {Promise<string[]|null>} [] = todo apagado.
 */
export async function fetchCamposAplicables() {
  try {
    const { data, error } = await supabase
      .from('erp_cambios_estado')
      .select('aplicar_campos')
      .eq('id', 1)
      .maybeSingle();
    if (error) throw error;
    return data && Array.isArray(data.aplicar_campos) ? data.aplicar_campos : null;
  } catch (err) {
    console.error('[cambiosErpService] Error leyendo los interruptores de campos:', err);
    return null;
  }
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
