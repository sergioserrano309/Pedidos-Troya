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

// Páginas que se piden a la vez (antes eran una tras otra: con miles de filas eso era lo más lento).
const PAGINAS_EN_PARALELO = 4;

async function leerPagina(construirConsulta, pagina) {
  const { data, error } = await construirConsulta().range(pagina * LOTE, (pagina + 1) * LOTE - 1);
  if (error) throw error;
  return data || [];
}

async function leerEnParalelo(construirConsulta) {
  const filas = await leerPagina(construirConsulta, 0);
  let hayMas = filas.length === LOTE;
  for (let desde = 1; hayMas; desde += PAGINAS_EN_PARALELO) {
    const paginas = await Promise.all(
      Array.from({ length: PAGINAS_EN_PARALELO }, (_, i) => leerPagina(construirConsulta, desde + i))
    );
    paginas.forEach((pg) => filas.push(...pg));
    hayMas = paginas[paginas.length - 1].length === LOTE;
  }
  return filas;
}

/** La forma de siempre: una página tras otra (más lenta, pero la que menos carga le pone a la base). */
async function leerSecuencial(construirConsulta) {
  const filas = [];
  for (let pagina = 0; ; pagina++) {
    const pg = await leerPagina(construirConsulta, pagina);
    filas.push(...pg);
    if (pg.length < LOTE) break;
  }
  return filas;
}

/**
 * Lee todo en paralelo (rápido). Si la base no aguanta varias consultas pesadas a la vez
 * y alguna falla, se repite desde cero una página a la vez, como antes.
 */
async function leerTodo(construirConsulta) {
  try {
    return await leerEnParalelo(construirConsulta);
  } catch (err) {
    console.warn('[dashboardService] La lectura en paralelo falló; se repite una página a la vez.', err);
    return leerSecuencial(construirConsulta);
  }
}

function errorLegible(error, vista) {
  const codigo = String(error?.code || '');
  const msg = String(error?.message || '').toLowerCase();
  if (codigo === 'PGRST205' || codigo === '42P01' || msg.includes('could not find the table') || msg.includes('does not exist')) {
    return new Error(`Falta crear la vista ${vista} en Supabase (SQL 084).`);
  }
  // El código ayuda a saber qué falló (permisos, tiempo agotado, vista sin crear…).
  return new Error(`No se pudieron cargar los datos del dashboard.${codigo ? ` (código ${codigo})` : ''}`);
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

const TIPOS_TROYA = ['despachado_troya_total', 'despachado_troya_parcial'];
const LOTE_IN = 100; // valores por filtro .in() (evita direcciones enormes)

/** [inicio, fin) del día de Colombia (UTC-5, sin horario de verano) como instantes ISO. */
function limitesDia(dia) {
  const inicio = new Date(`${dia}T00:00:00-05:00`);
  return [inicio.toISOString(), new Date(inicio.getTime() + 86400000).toISOString()];
}

/** Parte una lista en trozos de `tam`. */
function trozos(lista, tam) {
  const r = [];
  for (let i = 0; i < lista.length; i += tam) r.push(lista.slice(i, i + tam));
  return r;
}

/**
 * Una fila por (despacho x talla) despachada.
 * dia ('AAAA-MM-DD', día de Colombia): solo los despachos de ese día, filtrados en la base (es lo
 * que usa Empaque: no baja todo el historial). Sin `dia`, todos.
 */
export async function fetchDespachosDashboard({ dia = '' } = {}) {
  try {
    return await leerTodo(() => {
      let consulta = supabase
        .from('vw_dashboard_despachos')
        .select('*')
        .order('despacho_id', { ascending: true })
        .order('item_id', { ascending: true });
      if (dia) {
        const [inicio, fin] = limitesDia(dia);
        consulta = consulta.gte('fecha_despacho', inicio).lt('fecha_despacho', fin);
      }
      return consulta;
    });
  } catch (err) {
    console.error('[dashboardService] Error leyendo vw_dashboard_despachos:', err);
    throw errorLegible(err, 'vw_dashboard_despachos');
  }
}

/**
 * Líneas de los pedidos "cerrados y despachados en Troya" (lo único de las líneas que entra en
 * Despachado por fecha de despacho). Versión liviana de Empaque: primero se buscan esos pedidos en la
 * tabla de cierres (pocos) y solo se piden sus líneas, en vez de recorrer toda la vista de líneas.
 * Con `dia`, solo los que salieron en Troya ese día.
 */
export async function fetchLineasTroyaDashboard({ dia = '' } = {}) {
  try {
    let cierres = supabase.from('pedido_cierre_forzado').select('order_number').in('tipo_cierre', TIPOS_TROYA);
    if (dia) cierres = cierres.eq('fecha_despacho_troya', dia);
    const { data, error } = await cierres;
    if (error) throw error;
    const pedidos = [...new Set((data || []).map((f) => String(f.order_number)))];
    const filas = [];
    for (const lote of trozos(pedidos, LOTE_IN)) {
      filas.push(...await leerTodo(() =>
        supabase
          .from('vw_dashboard_lineas')
          .select('*')
          .in('order_number', lote)
          .order('order_number', { ascending: false })
          .order('talla', { ascending: true })
          .order('item_id', { ascending: true })
      ));
    }
    return filas;
  } catch (err) {
    console.error('[dashboardService] Error leyendo las líneas de Troya:', err);
    throw errorLegible(err, 'vw_dashboard_lineas');
  }
}

/**
 * Bultos y kilos de cada despacho (para agrupar el dashboard "por despacho").
 * Si falla devuelve un mapa vacío: la tabla sigue sin esas dos columnas.
 * @returns {Promise<Map<string, { bultos: number, kilos: number }>>} consecutivo -> datos
 */
export async function fetchInfoDespachosDashboard({ consecutivos = null } = {}) {
  const mapa = new Map();
  try {
    // consecutivos: solo esos despachos (los del día de Empaque); null = todos.
    const consulta = (lote) => leerTodo(() => {
      let q = supabase
        .from('vw_despachos_registro')
        .select('consecutivo, total_bultos, peso_total')
        .order('created_at', { ascending: false })
        .order('consecutivo', { ascending: true });
      if (lote) q = q.in('consecutivo', lote);
      return q;
    });
    const filas = consecutivos
      ? (await Promise.all(trozos(consecutivos, LOTE_IN).map(consulta))).flat()
      : await consulta(null);
    filas.forEach((f) => mapa.set(String(f.consecutivo), {
      bultos: Number(f.total_bultos) || 0,
      kilos: Number(f.peso_total) || 0
    }));
  } catch (err) {
    console.error('[dashboardService] Error leyendo bultos y kilos por despacho:', err);
  }
  return mapa;
}

/**
 * Qué bultos lleva cada orden en cada despacho (para "Bultos (por cliente)").
 * Si falla devuelve un mapa vacío: la columna de bultos sale con "—".
 * @returns {Promise<Map<string, number[]>>} 'despacho_id|orden' -> números de bulto
 */
export async function fetchBultosPorOrdenDespacho({ despachoIds = null } = {}) {
  const mapa = new Map();
  try {
    // despachoIds: solo esos despachos (los del día de Empaque); null = todos.
    const consulta = (lote) => leerTodo(() => {
      let q = supabase
        .from('despacho_orden_bultos')
        .select('despacho_id, order_number, bulto_numero')
        .order('id', { ascending: true });
      if (lote) q = q.in('despacho_id', lote);
      return q;
    });
    const filas = despachoIds
      ? (await Promise.all(trozos(despachoIds, LOTE_IN).map(consulta))).flat()
      : await consulta(null);
    filas.forEach((f) => {
      const clave = `${f.despacho_id}|${f.order_number}`;
      if (!mapa.has(clave)) mapa.set(clave, []);
      mapa.get(clave).push(Number(f.bulto_numero));
    });
  } catch (err) {
    console.error('[dashboardService] Error leyendo los bultos por orden:', err);
  }
  return mapa;
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
