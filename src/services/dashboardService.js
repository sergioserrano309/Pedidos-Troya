import { supabase } from '../config/supabaseClient.js';

/**
 * Lectura de los datos del Dashboard de unidades (SQL 084). Solo lectura.
 * Las dos vistas se descargan completas (pedidos desde el 3095) y la pantalla
 * agrupa y filtra en el navegador: cambiar de agrupación o de filtro no genera
 * consultas nuevas.
 *
 * Se pagina de a 1000 (tope por consulta de Supabase) con un orden de varias
 * columnas para que las páginas no se mezclen.
 */

const LOTE = 1000;

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

function errorLegible(error, vista) {
  const codigo = String(error?.code || '');
  const msg = String(error?.message || '').toLowerCase();
  if (codigo === 'PGRST205' || codigo === '42P01' || msg.includes('could not find the table') || msg.includes('does not exist')) {
    return new Error(`Falta crear la vista ${vista} en Supabase (SQL 084).`);
  }
  return new Error('No se pudieron cargar los datos del dashboard.');
}

/** Una fila por línea viva (pedido x talla). */
export async function fetchLineasDashboard() {
  try {
    return await leerTodo(() =>
      supabase
        .from('vw_dashboard_lineas')
        .select('*')
        .order('order_number', { ascending: false })
        .order('talla', { ascending: true })
        .order('item_id', { ascending: true })
    );
  } catch (err) {
    console.error('[dashboardService] Error leyendo vw_dashboard_lineas:', err);
    throw errorLegible(err, 'vw_dashboard_lineas');
  }
}

/** Una fila por (despacho x talla) despachada. */
export async function fetchDespachosDashboard() {
  try {
    return await leerTodo(() =>
      supabase
        .from('vw_dashboard_despachos')
        .select('*')
        .order('despacho_id', { ascending: true })
        .order('item_id', { ascending: true })
    );
  } catch (err) {
    console.error('[dashboardService] Error leyendo vw_dashboard_despachos:', err);
    throw errorLegible(err, 'vw_dashboard_despachos');
  }
}

/**
 * Pedidos (desde el 3095) con cambios de Access pendientes de revisar. Es solo
 * una nota informativa: si falla devuelve [] y el dashboard sigue.
 * @returns {Promise<string[]>}
 */
export async function fetchPedidosConCambiosPendientes() {
  try {
    const filas = await leerTodo(() =>
      supabase
        .from('erp_cambios')
        .select('id, pedido')
        .eq('estado', 'pendiente')
        .order('id', { ascending: true })
    );
    return [...new Set(filas
      .map((f) => String(f.pedido))
      .filter((p) => /^\d+$/.test(p) && Number(p) >= 3095))];
  } catch (err) {
    console.error('[dashboardService] No se pudieron leer los cambios pendientes:', err);
    return [];
  }
}
