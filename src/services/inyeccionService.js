import { supabase } from '../config/supabaseClient.js';
import { aplicaInyeccion, PRIMER_PEDIDO_INYECCION } from '../lib/inyeccion.js';

/**
 * Lectura de Inyección (ERP): columna Total01Iny de p_pedidosh, tal como
 * llegó de Access en la última carga. SOLO LECTURA y solo para el Validador:
 * no escribe nada y no entra en ningún cálculo de producción.
 *
 * p_pedidosh no tiene llave primaria, así que se pagina con un orden de
 * varias columnas (determinista salvo filas idénticas, que son
 * intercambiables) y se excluyen las líneas canceladas, igual que el resto
 * de la app (ver vw_item_progreso).
 */

const LOTE = 1000; // tope de filas por consulta de Supabase

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

function consultaBase(columnas) {
  return supabase
    .from('p_pedidosh')
    .select(columnas)
    .order('PedidoNo', { ascending: false })
    .order('Talla', { ascending: true })
    .order('DetalleVira', { ascending: true })
    .order('item_id', { ascending: true });
}

/**
 * Total inyectado de cada pedido (suma de sus tallas) para las órdenes que
 * se ven en pantalla. Los pedidos anteriores al 3095 se ignoran.
 *
 * @param {Array<string|number>} orderNumbers
 * @returns {Promise<Map<string, number>|null>} null si la consulta falla: la
 *   pantalla muestra "—" en vez de romperse. Un pedido sin líneas no aparece
 *   en el mapa (se toma como 0).
 */
export async function fetchInyectadoPorPedidos(orderNumbers) {
  const aplicables = [...new Set((orderNumbers || []).filter(aplicaInyeccion).map(String))];
  const mapa = new Map();
  if (aplicables.length === 0) return mapa;

  try {
    const filas = await leerTodo(() =>
      consultaBase('PedidoNo, Total01Iny, Cancelado').in('PedidoNo', aplicables)
    );
    filas.forEach((f) => {
      if (f.Cancelado) return;
      const pedido = String(f.PedidoNo);
      mapa.set(pedido, (mapa.get(pedido) || 0) + Number(f.Total01Iny || 0));
    });
    return mapa;
  } catch (err) {
    console.error('[inyeccionService] Error obteniendo Total Inyectado:', err);
    return null;
  }
}

/**
 * Estado de la sincronización del Total Inyectado (erp_sync_estado, una sola
 * fila): hora de la última corrida del script de la oficina, resultado e
 * interruptor. Solo el Validador puede leerla (RLS). Devuelve null si no se
 * pudo leer, y quien la use lo trata como "no se pudo verificar".
 */
export async function fetchEstadoSincronizacion() {
  try {
    const { data, error } = await supabase
      .from('erp_sync_estado')
      .select('activo, ultima_ejecucion, ultima_actualizacion, ultimo_resultado')
      .eq('id', 1)
      .maybeSingle();
    if (error) throw error;
    return data || null;
  } catch (err) {
    console.error('[inyeccionService] Error obteniendo el estado de la sincronización:', err);
    return null;
  }
}

/**
 * Todas las líneas (pedido x talla) desde el 3095, para la hoja "Inyección
 * ERP" del Excel. Si falla, devuelve [] y la hoja sale vacía en vez de
 * impedir la descarga (mismo criterio que las demás hojas).
 */
export async function fetchLineasInyeccionERP() {
  try {
    const filas = await leerTodo(() =>
      consultaBase('PedidoNo, FechaP, Cliente, NombreR, MaterialP, ColorP, Talla, DetalleVira, CantidadP, Total01Iny, Cancelado')
        .gte('PedidoNo', PRIMER_PEDIDO_INYECCION)
    );
    // El filtro numérico se repite aquí por si PedidoNo fuera texto.
    return filas.filter((f) => !f.Cancelado && aplicaInyeccion(f.PedidoNo));
  } catch (err) {
    console.error('[inyeccionService] Error obteniendo líneas para el Excel:', err);
    return [];
  }
}
