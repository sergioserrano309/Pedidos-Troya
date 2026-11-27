import { supabase } from '../config/supabaseClient.js';
import * as XLSX from 'xlsx';
import { serialExcelDeDia, diaPedidoLocal } from '../lib/fechas.js';
import { soloFecha, construirMapaUltimaFechaPorProceso, fechaFinProceso, calcularDiasPorProceso } from '../lib/procesoDias.js';
import { fetchLineasInyeccionERP, fetchEstadoSincronizacion } from './inyeccionService.js';
import { filasInyeccionERP } from '../lib/inyeccion.js';
import { porcentajeReal } from '../lib/calculations.js';
import { fetchTodosLosCambiosERP } from './cambiosErpService.js';
import { fetchTiposCierre, etiquetaTipoCierre } from './cierreForzadoService.js';
import { filasCambiosERP } from '../lib/cambiosErp.js';

const PAGE_SIZE = 1000;

async function fetchTodasLasOrdenes() {
  let allOrders = [];
  let page = 0;
  let usarAtributos = true;
  while (true) {
    // vw_pedido_progreso_atributos (082) = la misma vista + vira/acabado/
    // esterilla/marquilla. Si aún no existe, se usa la de siempre y esas
    // cuatro columnas del Excel salen con "—".
    let { data, error } = await supabase
      .from(usarAtributos ? 'vw_pedido_progreso_atributos' : 'vw_pedido_progreso')
      .select('*')
      .order('order_number', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (error && usarAtributos) {
      usarAtributos = false;
      allOrders = [];
      page = 0;
      continue;
    }
    if (error) throw new Error('No se pudieron cargar las órdenes.');
    if (!data || data.length === 0) break;
    allOrders = allOrders.concat(data);
    page++;
  }
  return allOrders;
}

/** Sí/No para las columnas Vira/Acabado/Esterilla/Marquilla; '—' si el dato no llegó (vista 082 ausente). */
function siNoExcel(valor) {
  if (valor === undefined || valor === null) return '—';
  return valor ? 'Sí' : 'No';
}

// Solo lo que el Excel usa. vw_historial tiene columnas calculadas muy caras
// (bloqueos, despachos); con select('*') se calculan para cada fila y las
// últimas páginas terminaban en timeout (500). Pidiendo solo estas, la base
// no las evalúa.
const COLUMNAS_HISTORIAL_EXCEL =
  'id, tipo, order_number, size, quantity, from_process, to_process, causal, ' +
  'failed_process, action, observation, user_name, created_at, precio_cop, valor_cop';

const REINTENTOS_PAGINA = 3;

const esperar = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Historial completo, de lo más nuevo a lo más viejo. Pagina por fecha
 * ("lo más viejo que lo último recibido") y no por posición, así cada página
 * cuesta lo mismo aunque haya decenas de miles de registros. Cada página se
 * reintenta si falla antes de rendirse.
 */
async function fetchTodoElHistorial() {
  const todo = [];
  const vistos = new Set();
  let cursor = null;
  let incluirIgual = true;

  while (true) {
    let data = null;
    for (let intento = 1; intento <= REINTENTOS_PAGINA; intento++) {
      let consulta = supabase
        .from('vw_historial')
        .select(COLUMNAS_HISTORIAL_EXCEL)
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(PAGE_SIZE);
      if (cursor) {
        consulta = incluirIgual ? consulta.lte('created_at', cursor) : consulta.lt('created_at', cursor);
      }
      const respuesta = await consulta;
      if (!respuesta.error) {
        data = respuesta.data || [];
        break;
      }
      if (intento === REINTENTOS_PAGINA) throw new Error('No se pudo cargar el historial.');
      await esperar(1000 * intento);
    }

    // lte repite las filas que comparten la fecha del borde; se descartan.
    let nuevas = 0;
    for (const fila of data) {
      const clave = `${fila.tipo}|${fila.id}`;
      if (vistos.has(clave)) continue;
      vistos.add(clave);
      todo.push(fila);
      nuevas++;
    }

    if (data.length < PAGE_SIZE) break;
    // Si toda la página ya se había visto (más de PAGE_SIZE filas con la
    // misma fecha exacta), se salta esa fecha para no quedar en bucle.
    incluirIgual = nuevas > 0;
    cursor = data[data.length - 1].created_at;
  }
  return todo;
}

/**
 * Lee una vista/tabla por páginas de PAGE_SIZE. Cada página se reintenta y,
 * si sigue fallando, la descarga se detiene con un error claro: antes la hoja
 * salía vacía en silencio y parecía que no había datos.
 */
async function fetchPaginadoEstricto(nombre, crearConsulta) {
  let todo = [];
  let page = 0;
  while (true) {
    let data = null;
    for (let intento = 1; intento <= REINTENTOS_PAGINA; intento++) {
      const respuesta = await crearConsulta().range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
      if (!respuesta.error) {
        data = respuesta.data || [];
        break;
      }
      console.error(`[excel] Falló ${nombre} (página ${page + 1}, intento ${intento}):`, respuesta.error);
      if (intento === REINTENTOS_PAGINA) {
        throw new Error(`No se pudo cargar ${nombre}. La hoja no se generó para no entregarla incompleta.`);
      }
      await esperar(1000 * intento);
    }
    if (data.length === 0) break;
    todo = todo.concat(data);
    if (data.length < PAGE_SIZE) break;
    page++;
  }
  return todo;
}

/**
 * Estado de despacho por pedido, para las columnas F_Despacho y
 * "Unidades Despachadas" de la hoja Órdenes. Una fila por pedido con
 * despachos; los pedidos que nunca han salido simplemente no aparecen.
 */
async function fetchTodoElEstadoDespacho() {
  const mapa = {};
  let page = 0;
  while (true) {
    const { data, error } = await supabase
      .from('vw_pedido_despacho_estado')
      .select('order_number, unidades_despachadas, unidades_solicitadas, pedido_completo, fecha_ultimo_despacho, porcentaje_despachado')
      .order('order_number', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (error) return mapa;
    if (!data || data.length === 0) break;
    data.forEach((f) => {
      mapa[String(f.order_number)] = f;
    });
    page++;
  }
  return mapa;
}

async function fetchTodosLosDestinos() {
  const { data, error } = await supabase
    .from('order_destino')
    .select('order_number, destino, es_automatico');
  if (error) return {};
  const mapa = {};
  data?.forEach((d) => {
    mapa[d.order_number] = { destino: d.destino, es_automatico: d.es_automatico };
  });
  return mapa;
}

/**
 * Un registro por despacho, con kilos, unidades, órdenes, comentario y
 * factura, desde el mismo RPC del listado Despachado (listar_despachos_registro).
 *
 * Se usa en vez de leer las tablas de despachos o vw_despacho_orden_detalle:
 * con el filtro de pedidos ocultos (058) cada fila de despachos/despacho_bultos
 * recorre todos los pedidos, y con el volumen actual Supabase corta la consulta
 * por tiempo (57014) incluso en la primera página. El RPC primero recorta los
 * despachos de la página y recién después agrega, por eso sí responde.
 */
async function fetchRegistrosDespachosExcel() {
  const TAMANO = 50;
  const vistos = new Set();
  const todos = [];
  let offset = 0;
  while (true) {
    let data = null;
    for (let intento = 1; intento <= REINTENTOS_PAGINA; intento++) {
      const respuesta = await supabase.rpc('listar_despachos_registro', {
        p_orden: '',
        p_fecha: '',
        p_consecutivo: '',
        p_cliente: '',
        p_factura: '',
        p_offset: offset,
        p_limit: TAMANO
      });
      if (!respuesta.error) {
        data = respuesta.data || [];
        break;
      }
      console.error(`[excel] Falló el listado de despachos (desde ${offset}, intento ${intento}):`, respuesta.error);
      if (intento === REINTENTOS_PAGINA) {
        throw new Error('No se pudo cargar el listado de despachos. La hoja no se generó para no entregarla incompleta.');
      }
      await esperar(1000 * intento);
    }
    data.forEach((r) => {
      if (vistos.has(r.id)) return;
      vistos.add(r.id);
      todos.push(r);
    });
    if (data.length < TAMANO) break;
    offset += TAMANO;
  }
  return todos;
}

/**
 * Detalle despacho x orden para la hoja "Despachos": una fila por despacho x
 * orden, con las mismas columnas de vw_despacho_orden_detalle (054/055). Los
 * atributos de la orden salen de `ordenes` (vw_pedido_progreso_atributos) y el
 * avance de despacho de `estadoDespacho`.
 */
async function fetchTodoElDetalleDespachos(registros, ordenes, estadoDespacho, itemsDespachados) {
  const asignaciones = await fetchPaginadoEstricto('los bultos por orden', () =>
    supabase
      .from('despacho_orden_bultos')
      .select('despacho_id, order_number, bulto_numero')
      .order('id', { ascending: true })
  );

  const ordenPorNumero = new Map(ordenes.map((o) => [String(o.order_number), o]));

  const unidadesPorOrden = new Map();
  itemsDespachados.forEach((it) => {
    const clave = `${it.despacho_id}|${it.order_number}`;
    unidadesPorOrden.set(clave, (unidadesPorOrden.get(clave) || 0) + (it.cantidad ?? 0));
  });

  const bultosPorOrden = new Map();
  asignaciones.forEach((a) => {
    const clave = `${a.despacho_id}|${a.order_number}`;
    if (!bultosPorOrden.has(clave)) bultosPorOrden.set(clave, []);
    bultosPorOrden.get(clave).push(a.bulto_numero);
  });

  const filas = [];
  registros.forEach((d) => {
    (d.order_numbers || []).forEach((numeroOrden) => {
      const o = ordenPorNumero.get(String(numeroOrden));
      const estado = estadoDespacho[String(numeroOrden)];
      const clave = `${d.id}|${numeroOrden}`;
      const asignados = (bultosPorOrden.get(clave) || []).sort((x, y) => x - y);

      filas.push({
        despacho_id: d.id,
        consecutivo: d.consecutivo,
        fecha_despacho: d.confirmed_at || d.created_at,
        revisado: d.revisado,
        order_number: numeroOrden,
        cliente: o?.cliente ?? null,
        nombre_referencia: o?.nombre_referencia ?? null,
        material: o?.material ?? null,
        color: o?.color ?? null,
        vira: !!o?.vira,
        acabado: !!o?.acabado,
        esterilla: !!o?.esterilla,
        marquilla: !!o?.marquilla,
        unidades_orden_despacho: unidadesPorOrden.get(clave) ?? 0,
        bultos_asignados: asignados.join(', '),
        numero_bultos: asignados.length,
        kilos_despacho: d.peso_total ?? 0,
        unidades_despacho: d.total_unidades ?? 0,
        // % real (sin tope de 100), desde las unidades.
        porcentaje_despachado: porcentajeReal(estado?.unidades_despachadas, estado?.unidades_solicitadas),
        pedido_completo: estado?.pedido_completo ?? false,
        bultos_despacho: d.total_bultos
      });
    });
  });

  // Más reciente primero; D2 antes que D10 en el orden numérico.
  filas.sort(
    (a, b) =>
      String(b.consecutivo).localeCompare(String(a.consecutivo), undefined, { numeric: true }) ||
      String(a.order_number).localeCompare(String(b.order_number), undefined, { numeric: true })
  );
  return filas;
}

/**
 * Unidades por despacho x orden x talla. Es lo que se pivota en las
 * columnas de talla de la hoja "Despachos".
 */
async function fetchTodosLosItemsDespachados() {
  return fetchPaginadoEstricto('las unidades despachadas', () =>
    supabase
      .from('despacho_orden_items')
      .select('despacho_id, order_number, talla, cantidad')
      .order('id', { ascending: true })
  );
}

/**
 * Todas las tallas que existen en la base, ordenadas como números
 * (35 antes que 36, y 36 antes que 100 — que es lo que un orden
 * alfabético no hace).
 */
async function fetchTodasLasTallas() {
  const { data, error } = await supabase.from('vw_tallas_disponibles').select('talla');
  if (error) return [];
  return (data || [])
    .map((f) => String(f.talla))
    .sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));
}

/**
 * Unidades solicitadas por orden x talla (columnas de talla de la hoja Órdenes).
 * Sale de p_pedidosh (tabla simple, sin cálculos) con solo 4 columnas, sin las
 * líneas canceladas. La base ya oculta los pedidos anteriores al corte (058).
 *
 * Para no alargar la descarga: la primera página va sola y las demás se piden
 * de a 8 EN PARALELO; además generarExcel la lanza al empezar, así se descarga
 * mientras se baja el historial. Estricta como las demás: si una página falla
 * tras reintentar, la descarga se detiene (no se entrega con tallas a medias).
 * @returns {Promise<Map<string, Map<string, number>>>} orden -> (talla -> unidades)
 */
async function fetchSolicitadoPorOrdenTalla() {
  const LOTE_PARALELO = 8;
  const leerPagina = async (pagina) => {
    for (let intento = 1; intento <= REINTENTOS_PAGINA; intento++) {
      const { data, error } = await supabase
        .from('p_pedidosh')
        .select('PedidoNo, Talla, CantidadP, Cancelado')
        .order('PedidoNo', { ascending: false })
        .order('Talla', { ascending: true })
        .order('DetalleVira', { ascending: true })
        .order('item_id', { ascending: true })
        .range(pagina * PAGE_SIZE, (pagina + 1) * PAGE_SIZE - 1);
      if (!error) return data || [];
      console.error(`[excel] Falló lo solicitado por talla (página ${pagina + 1}, intento ${intento}):`, error);
      if (intento === REINTENTOS_PAGINA) {
        throw new Error('No se pudo cargar lo solicitado por talla. El Excel no se generó para no entregarlo incompleto.');
      }
      await esperar(1000 * intento);
    }
    return [];
  };

  const filas = [];
  const primera = await leerPagina(0);
  filas.push(...primera);
  let hayMas = primera.length === PAGE_SIZE;
  for (let desde = 1; hayMas; desde += LOTE_PARALELO) {
    const paginas = await Promise.all(
      Array.from({ length: LOTE_PARALELO }, (_, i) => leerPagina(desde + i))
    );
    paginas.forEach((pg) => filas.push(...pg));
    hayMas = paginas[paginas.length - 1].length === PAGE_SIZE;
  }

  const mapa = new Map();
  filas.forEach((f) => {
    if (f.Cancelado) return;
    const orden = String(f.PedidoNo);
    const talla = String(f.Talla ?? '').trim();
    if (!talla) return;
    if (!mapa.has(orden)) mapa.set(orden, new Map());
    const porTalla = mapa.get(orden);
    porTalla.set(talla, (porTalla.get(talla) || 0) + (Number(f.CantidadP) || 0));
  });
  return mapa;
}

async function fetchTodasLasEliminaciones() {
  let all = [];
  let page = 0;
  while (true) {
    const { data, error } = await supabase
      // La vista resuelve el usuario a nombre y desempaqueta el snapshot
      // según de dónde venga el borrado (042). Trae las mismas filas que
      // la tabla cruda, así que la hoja Eliminaciones no cambia.
      .from('vw_log_eliminaciones')
      .select('*')
      .order('eliminado_en', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (error) return [];
    if (!data || data.length === 0) break;
    all = all.concat(data);
    page++;
  }
  return all;
}

/**
 * Lo despachado de un pedido, con la misma convención de las demás
 * columnas F_: fecha solo al 100%.
 */
function despachoDeOrden(orderNumber, estadoDespacho) {
  const estado = estadoDespacho[String(orderNumber)];
  if (!estado) return { fecha: '—', unidades: 0 };
  return {
    fecha: estado.pedido_completo ? soloFecha(estado.fecha_ultimo_despacho) : '—',
    unidades: estado.unidades_despachadas ?? 0
  };
}

function formatearHora24(fecha) {
  if (!fecha) return '—';
  try {
    const d = new Date(fecha);
    return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  } catch {
    return String(fecha);
  }
}

/**
 * Devuelve un objeto Date real (no texto) para que Excel lo reconozca
 * como fecha y lo pueda formatear/ordenar/filtrar como tal.
 */
function obtenerDateObject(fecha) {
  if (!fecha) return null;
  try {
    return new Date(fecha);
  } catch {
    return null;
  }
}

// Fechas de solo-día como número de serie de Excel (entero) + formato de
// fecha. Con Date la librería xlsx deja la medianoche local de Colombia
// unos segundos antes de la medianoche y Excel muestra el día anterior
// (ver lib/fechas.js). Las columnas con hora real (despachos, eliminaciones)
// siguen como Date y no tienen ese problema.
const FORMATO_FECHA_EXCEL = 'm/d/yy';

function diaExcel(valor) {
  return valor instanceof Date ? serialExcelDeDia(valor) : valor;
}

function formatearColumnasFecha(ws, encabezados) {
  if (!ws || !ws['!ref']) return;
  const rango = XLSX.utils.decode_range(ws['!ref']);
  for (let c = rango.s.c; c <= rango.e.c; c++) {
    const titulo = ws[XLSX.utils.encode_cell({ r: rango.s.r, c })]?.v;
    if (!encabezados.includes(titulo)) continue;
    for (let r = rango.s.r + 1; r <= rango.e.r; r++) {
      const celda = ws[XLSX.utils.encode_cell({ r, c })];
      if (celda && celda.t === 'n') celda.z = FORMATO_FECHA_EXCEL;
    }
  }
}

/**
 * Formato fecha + hora para una columna con hora real (p. ej. "Actualizado").
 * No es lo mismo que formatearColumnasFecha: esa es solo de día.
 */
function formatearColumnaFechaHora(ws, titulo, formato = 'dd/mm/yyyy hh:mm') {
  if (!ws || !ws['!ref']) return;
  const rango = XLSX.utils.decode_range(ws['!ref']);
  for (let c = rango.s.c; c <= rango.e.c; c++) {
    if (ws[XLSX.utils.encode_cell({ r: rango.s.r, c })]?.v !== titulo) continue;
    for (let r = rango.s.r + 1; r <= rango.e.r; r++) {
      const celda = ws[XLSX.utils.encode_cell({ r, c })];
      if (celda && (celda.t === 'n' || celda.t === 'd')) celda.z = formato;
    }
  }
}

/**
 * Hojas que salen del historial de movimientos: una por proceso
 * (Refilado, Acabado, Mateado, Empaque) y la de Inyección (devoluciones).
 */
function agregarHojasHistorial(libro, historial, mapaOrdenes) {
  // === HOJAS DE PROCESOS ===
  const procesos = ['Refilado', 'Acabado', 'Mateado', 'Empaque'];

  procesos.forEach((proceso) => {
    const filasMovimientos = historial
      .filter((h) => h.tipo === 'movimiento' && h.from_process === proceso)
      .map((h) => {
        const orden = mapaOrdenes[h.order_number];
        const usuario = h.observation?.includes('Enrutamiento automático') ? 'Regla' : (h.user_name || '—');

        return {
          'Orden': h.order_number,
          'Nombre Suel': orden?.nombre_referencia || '—',
          'Material': orden?.material || '—',
          'Color': orden?.color || '—',
          'Talla': h.size || '—',
          'Cantidad': h.quantity,
          'Precio por Par': h.precio_cop ?? '—',
          'Comisión': h.valor_cop ?? '—',
          'Enviado a': h.to_process || '—',
          'Usuario': usuario,
          'Fecha': serialExcelDeDia(soloFecha(h.created_at)),
          'Hora': formatearHora24(h.created_at),
          'Observaciones': h.observation || '—'
        };
      });

    if (filasMovimientos.length > 0) {
      const ws = XLSX.utils.json_to_sheet(filasMovimientos);
      formatearColumnasFecha(ws, ['Fecha']);
      XLSX.utils.book_append_sheet(libro, ws, proceso);
    }
  });

  // === HOJA INYECCIÓN ===
  const filasInyeccion = historial
    .filter((h) => h.tipo === 'devolucion' && h.failed_process === 'Inyección')
    .map((h) => {
      const orden = mapaOrdenes[h.order_number];
      return {
        'Orden': h.order_number,
        'Nombre Suel': orden?.nombre_referencia || '—',
        'Material': orden?.material || '—',
        'Color': orden?.color || '—',
        'Talla': h.size || '—',
        'Cantidad': h.quantity,
        'Causal': h.causal || '—',
        'Acción': h.action || '—',
        'Usuario': h.user_name || '—',
        'Fecha': serialExcelDeDia(soloFecha(h.created_at)),
        'Hora': formatearHora24(h.created_at),
        'Observaciones': h.observation || '—'
      };
    });

  const wsInyeccion = XLSX.utils.json_to_sheet(filasInyeccion);
  formatearColumnasFecha(wsInyeccion, ['Fecha']);
  XLSX.utils.book_append_sheet(libro, wsInyeccion, 'Inyección');
}

function descargarLibro(libro, prefijo) {
  const fecha = new Date();
  const fechaStr = `${fecha.getFullYear()}-${String(fecha.getMonth() + 1).padStart(2, '0')}-${String(fecha.getDate()).padStart(2, '0')}`;
  XLSX.writeFile(libro, `${prefijo}_${fechaStr}.xlsx`);
}

/**
 * Excel de movimientos: solo las hojas que salen del historial. Va aparte
 * de generarExcel porque el historial es lo más pesado de descargar.
 */
export async function generarExcelHistorial() {
  const libro = XLSX.utils.book_new();
  const ordenes = await fetchTodasLasOrdenes();
  const historial = await fetchTodoElHistorial();

  const mapaOrdenes = {};
  ordenes.forEach((o) => {
    mapaOrdenes[o.order_number] = o;
  });

  agregarHojasHistorial(libro, historial, mapaOrdenes);
  descargarLibro(libro, 'Movimientos_Produccion');
}

export async function generarExcel() {
  const libro = XLSX.utils.book_new();
  // Se descarga en paralelo con lo demás (ver fetchSolicitadoPorOrdenTalla).
  const solicitadoPorTallaPromesa = fetchSolicitadoPorOrdenTalla();
  solicitadoPorTallaPromesa.catch(() => {}); // si otro paso falla antes, evita el aviso de "promesa sin atender"
  const ordenes = await fetchTodasLasOrdenes();
  const historial = await fetchTodoElHistorial();
  const destinos = await fetchTodosLosDestinos();
  const eliminaciones = await fetchTodasLasEliminaciones();
  const estadoDespacho = await fetchTodoElEstadoDespacho();
  const itemsDespachados = await fetchTodosLosItemsDespachados();
  const registrosDespachos = await fetchRegistrosDespachosExcel();
  const detalleDespachos = await fetchTodoElDetalleDespachos(registrosDespachos, ordenes, estadoDespacho, itemsDespachados);
  // Comentario y factura de cada salida (062 y 068), por despacho_id.
  const comentariosDespachos = new Map(
    registrosDespachos.filter((r) => r.comentario).map((r) => [r.id, r.comentario])
  );
  const facturasDespachos = new Map(
    registrosDespachos.filter((r) => r.numero_factura).map((r) => [r.id, r.numero_factura])
  );
  const tallas = await fetchTodasLasTallas();
  const solicitadoPorTalla = await solicitadoPorTallaPromesa;
  const lineasInyeccionERP = await fetchLineasInyeccionERP();
  const estadoSincronizacionERP = await fetchEstadoSincronizacion();
  const cambiosERP = await fetchTodosLosCambiosERP();
  // Tipo de cada cierre a la fuerza (087); si falla, sale "Sin clasificar".
  const tiposCierre = await fetchTiposCierre();

  const mapaUltimaFecha = construirMapaUltimaFechaPorProceso(historial);

  // IDs de despacho (consecutivo, p. ej. "D1028") por orden, sin repetir y
  // en orden numérico (D2 antes que D10, que un orden alfabético no da).
  const despachosPorOrden = new Map();
  detalleDespachos.forEach((d) => {
    if (!d.consecutivo) return;
    const clave = String(d.order_number);
    if (!despachosPorOrden.has(clave)) despachosPorOrden.set(clave, new Set());
    despachosPorOrden.get(clave).add(String(d.consecutivo));
  });
  despachosPorOrden.forEach((ids, clave) => {
    despachosPorOrden.set(
      clave,
      [...ids].sort((a, b) => a.localeCompare(b, undefined, { numeric: true }))
    );
  });

  // Tallas de las columnas de la hoja Órdenes: las de la base (como la hoja Despachos) más
  // cualquiera que aparezca en los pedidos y no esté en esa lista; en orden numérico.
  const tallasOrdenes = [...new Set([
    ...tallas,
    ...[...solicitadoPorTalla.values()].flatMap((m) => [...m.keys()])
  ])].sort((a, b) => a.localeCompare(b, undefined, { numeric: true }));

  // === HOJA ÓRDENES ===
  const hojaCórdenes = ordenes.map((orden) => {
    const destino = destinos[orden.order_number];
    const tieneRegla = destino?.es_automatico === true ? 'Sí' : 'No';
    const procesoProceso = tieneRegla === 'Sí' ? (destino.destino || '—') : 'No';

    const dias = calcularDiasPorProceso(orden, mapaUltimaFecha);

    return {
      'Orden': orden.order_number,
      'Cliente': orden.cliente || '—',
      'Nombre Suel': orden.nombre_referencia || '—',
      'Material': orden.material || '—',
      'Color': orden.color || '—',
      'Vira': siNoExcel(orden.vira),
      'Acabado': siNoExcel(orden.acabado),
      'Esterilla': siNoExcel(orden.esterilla),
      'Marquilla': siNoExcel(orden.marquilla),
      'Fecha': serialExcelDeDia(diaPedidoLocal(orden.fecha_pedido)),
      'Total Solicita': orden.total_solicitado ?? 0,
      'Total Procese': orden.total_procesado ?? 0,
      'Total Pendier': orden.total_pendiente ?? 0,
      // % reales (sin tope de 100): pares procesados / pares pedidos. Las columnas
      // F_ (fecha al 100%) siguen usando el % por talla de la vista.
      '% Completad': porcentajeReal(orden.total_procesado, orden.total_solicitado),
      'Total Items': orden.total_items ?? 0,
      'Regla': tieneRegla,
      'ReglaProceso': procesoProceso,
      'P_Refilado': orden.procesado_refilado ?? 0,
      'P_Acabado': orden.procesado_acabado ?? 0,
      'P_Empaque': orden.procesado_empaque ?? 0,
      'P_Mateado': orden.procesado_mateado ?? 0,
      '%_Refilado': porcentajeReal(orden.procesado_refilado, orden.total_refilado),
      '%_Acabado': porcentajeReal(orden.procesado_acabado, orden.total_acabado),
      '%_Empaque': porcentajeReal(orden.procesado_empaque, orden.total_empaque),
      '%_Mateado': porcentajeReal(orden.procesado_mateado, orden.total_mateado),
      'F_Refilado': diaExcel(fechaFinProceso(orden, 'Refilado', 'porcentaje_refilado', mapaUltimaFecha)),
      'F_Acabado': diaExcel(fechaFinProceso(orden, 'Acabado', 'porcentaje_acabado', mapaUltimaFecha)),
      'F_Empaque': diaExcel(fechaFinProceso(orden, 'Empaque', 'porcentaje_empaque', mapaUltimaFecha)),
      'F_Mateado': diaExcel(fechaFinProceso(orden, 'Mateado', 'porcentaje_mateado', mapaUltimaFecha)),
      'D_Refilado': dias.dRefilado,
      'D_Acabado': dias.dAcabado,
      'D_Mateado': dias.dMateado,
      'D_Empaque': dias.dEmpaque,
      // Misma lectura que F_Refilado/F_Acabado/F_Empaque/F_Mateado: la
      // fecha solo aparece cuando el proceso llegó al 100%. Mientras el
      // pedido siga con saldo por despachar, queda en blanco aunque ya
      // haya salido parte — que es justo lo que distingue "despachado"
      // de "despachado a medias".
      'F_Despacho': diaExcel(despachoDeOrden(orden.order_number, estadoDespacho).fecha),
      // Todos los despachos en los que está la orden (los mismos IDs que
      // la hoja Despachos), no solo el que la completó.
      'Despachos': (despachosPorOrden.get(String(orden.order_number)) || []).join(', ') || '—',
      'Unidades Despachadas': despachoDeOrden(orden.order_number, estadoDespacho).unidades,
      // Cierre forzado por el Validador (057). Solo informativo: viene de
      // vw_pedido_progreso y no altera ninguna otra columna. El cierre es
      // un instante real (timestamptz), por eso va por soloFecha (día
      // local) como las fechas de movimientos, con el mismo formato de
      // 'Fecha'. Sin cierre, las dos columnas de detalle dicen "No".
      'CerradaF': orden.cierre_forzado ? 'Sí' : 'No',
      'FechaCerradaF': orden.cierre_forzado
        ? (serialExcelDeDia(soloFecha(orden.cierre_forzado_at)) ?? '—')
        : 'No',
      'MotivoCierreF': orden.cierre_forzado ? (orden.cierre_forzado_motivo || '—') : 'No',
      // Cancelado / No se terminó de despachar / Otro motivo operativo (087).
      'TipoCierreF': orden.cierre_forzado ? etiquetaTipoCierre(tiposCierre.get(String(orden.order_number))) : 'No'
    };
  });
  // Unidades solicitadas por talla, DESPUÉS de TipoCierreF (cero donde la orden no pidió esa talla).
  // Los nombres de talla son números ('35'): JavaScript los pondría PRIMERO en la fila, por eso
  // el orden de las columnas se indica explícitamente con `header`.
  hojaCórdenes.forEach((fila, i) => {
    const porTalla = solicitadoPorTalla.get(String(ordenes[i].order_number));
    tallasOrdenes.forEach((talla) => {
      fila[talla] = porTalla?.get(talla) ?? 0;
    });
  });
  const wsOrdenes = XLSX.utils.json_to_sheet(hojaCórdenes, {
    header: [...Object.keys(hojaCórdenes[0] || {}).filter((k) => !tallasOrdenes.includes(k)), ...tallasOrdenes]
  });
  formatearColumnasFecha(wsOrdenes, ['Fecha', 'F_Refilado', 'F_Acabado', 'F_Empaque', 'F_Mateado', 'F_Despacho', 'FechaCerradaF']);
  XLSX.utils.book_append_sheet(libro, wsOrdenes, 'Órdenes');

  // === HOJA INYECCIÓN ERP ===
  // Total Inyectado tal como viene de Access (columna Total01Iny), por
  // pedido y talla, desde el pedido 3095. Es informativo y NO es la hoja
  // "Inyección" de arriba (esa lista devoluciones cuyo proceso fallido fue
  // Inyección). Las columnas "Actualizado" y "Estado del dato" dicen cuándo
  // confirmó el sincronizador por última vez que esto coincidía con Access y
  // si hay una falla que revisar.
  const wsInyeccionERP = XLSX.utils.json_to_sheet(filasInyeccionERP(lineasInyeccionERP, estadoSincronizacionERP));
  formatearColumnasFecha(wsInyeccionERP, ['Fecha Pedido']);
  formatearColumnaFechaHora(wsInyeccionERP, 'Actualizado');
  XLSX.utils.book_append_sheet(libro, wsInyeccionERP, 'Inyección ERP');

  // === HOJA CAMBIOS ERP ===
  // Diferencias que el detector encontró entre Access y el programa (Fase 1:
  // solo se registran, ningún pedido se modifica). Incluye las ya resueltas
  // como historial. Si no se pudo leer, la hoja sale vacía.
  const wsCambiosERP = XLSX.utils.json_to_sheet(filasCambiosERP(cambiosERP));
  formatearColumnaFechaHora(wsCambiosERP, 'Detectado');
  formatearColumnaFechaHora(wsCambiosERP, 'Última revisión');
  formatearColumnaFechaHora(wsCambiosERP, 'Resuelto');
  XLSX.utils.book_append_sheet(libro, wsCambiosERP, 'Cambios ERP');

  // === HOJA DESPACHOS ===
  // Una fila por despacho x orden. Las columnas de talla se arman aquí
  // (no en SQL) porque son dinámicas: una por cada talla de la base.
  const unidadesPorTalla = new Map();
  itemsDespachados.forEach((it) => {
    const clave = `${it.despacho_id}|${it.order_number}|${it.talla}`;
    unidadesPorTalla.set(clave, (unidadesPorTalla.get(clave) || 0) + (it.cantidad ?? 0));
  });

  const filasDespachos = detalleDespachos.map((d) => {
    const fila = {
      'ID Despacho': d.consecutivo,
      'ID Orden': d.order_number,
      'Cliente': d.cliente || '—',
      'Nombre Suela': d.nombre_referencia || '—',
      'Material': d.material || '—',
      'Color': d.color || '—',
      'Vira': d.vira ? 'Sí' : 'No',
      'Acabado': d.acabado ? 'Sí' : 'No',
      'Esterilla': d.esterilla ? 'Sí' : 'No',
      'Marquilla': d.marquilla ? 'Sí' : 'No'
    };

    fila['Unidades (Orden en Despacho)'] = d.unidades_orden_despacho ?? 0;
    fila['Fecha Despacho'] = obtenerDateObject(d.fecha_despacho);
    fila['Bultos Asignados'] = d.bultos_asignados || '—';
    // Dos preguntas distintas que antes se confundían en una sola
    // columna: en cuántos bultos va ESTA orden, y cuántos bultos tiene
    // el despacho entero.
    fila['Nº de Bultos (Orden)'] = d.numero_bultos ?? 0;
    // Totales DEL DESPACHO, repetidos en cada fila del mismo despacho
    // por pedido del usuario. No se deben sumar en tabla dinámica.
    fila['Bultos del Despacho'] = d.bultos_despacho ?? 0;
    fila['Kilos del Despacho'] = Number(d.kilos_despacho ?? 0);
    fila['Unidades del Despacho'] = d.unidades_despacho ?? 0;
    fila['% Despachado de la Orden'] = d.porcentaje_despachado ?? 0;
    fila['Orden Completa'] = d.pedido_completo ? 'Sí' : 'No';
    // Comentario de la salida (062), repetido en cada fila del mismo
    // despacho como los totales del despacho. Vacío si no tiene.
    fila['Comentario'] = comentariosDespachos.get(d.despacho_id) || '';
    // Número de factura (068), misma repetición por filas del despacho.
    fila['FV'] = facturasDespachos.get(d.despacho_id) || '';

    // Las tallas van de últimas: son muchas columnas y dejaban los datos
    // del despacho fuera de la pantalla. La suma de estas columnas es
    // "Unidades (Orden en Despacho)", que viene calculada de la vista;
    // si algún día dejaran de cuadrar, es señal de que un item quedó
    // fuera del pivote. Cero donde esa orden no despachó esa talla.
    tallas.forEach((talla) => {
      fila[talla] = unidadesPorTalla.get(`${d.despacho_id}|${d.order_number}|${talla}`) ?? 0;
    });

    return fila;
  });

  // Las tallas son números ('35') y JavaScript pone esas claves PRIMERO en la fila: sin indicar el
  // orden, las columnas de talla salían al principio de la hoja. Con `header` quedan después de FV.
  const wsDespachos = XLSX.utils.json_to_sheet(filasDespachos, {
    header: [...Object.keys(filasDespachos[0] || {}).filter((k) => !tallas.includes(k)), ...tallas]
  });
  XLSX.utils.book_append_sheet(libro, wsDespachos, 'Despachos');

  // === HOJA ELIMINACIONES ===
  // Solo movimientos de producción: los despachos borrados tienen otra
  // forma de snapshot y viven en su propia hoja. Antes caían aquí y
  // salían como filas con Orden "—", Talla "—" y Cantidad 0.
  const filasEliminaciones = eliminaciones
    .filter((elim) => elim.tabla_origen === 'production_movements')
    .map((elim) => {
      const snapshot = elim.snapshot || {};
      return {
        'Fecha Eliminación': obtenerDateObject(elim.eliminado_en),
        'ID Eliminación': elim.id,
        'Orden': snapshot.order_number || '—',
        'Talla': snapshot.size || '—',
        'Cantidad': snapshot.quantity ?? 0,
        'Proceso Origen': snapshot.from_process || '—',
        'Proceso Destino': snapshot.to_process || '—',
        'Referencia': snapshot.reference || '—',
        'Usuario': snapshot.user_id || '—',
        'Motivo': elim.motivo || '—'
      };
    });

  const wsEliminaciones = XLSX.utils.json_to_sheet(filasEliminaciones);
  XLSX.utils.book_append_sheet(libro, wsEliminaciones, 'Eliminaciones');

  // === HOJA ELIMINACIONES D (despachos eliminados) ===
  // El snapshot guarda el despacho completo con sus órdenes, bultos e
  // items (039 y 046), así que la hoja puede decir qué se perdió y no
  // solo que algo se borró.
  const filasEliminacionesD = eliminaciones
    .filter((elim) => elim.tabla_origen === 'despachos')
    .map((elim) => {
      const snapshot = elim.snapshot || {};
      const items = snapshot.items || [];
      const bultos = snapshot.bultos || [];
      const ordenes = (snapshot.ordenes || []).map((o) => o.order_number);

      return {
        'Fecha Eliminación': obtenerDateObject(elim.eliminado_en),
        'ID Eliminación': elim.id,
        'ID Despacho': snapshot.despacho?.consecutivo || elim.referencia || '—',
        'Órdenes': ordenes.join(', ') || '—',
        'Nº de Órdenes': ordenes.length,
        'Nº de Bultos': bultos.length,
        'Kilos': bultos.reduce((sum, b) => sum + Number(b.peso || 0), 0),
        'Unidades': items.reduce((sum, i) => sum + Number(i.cantidad || 0), 0),
        'Fecha Despacho': obtenerDateObject(
          snapshot.despacho?.confirmed_at || snapshot.despacho?.created_at
        ),
        'Usuario': elim.usuario_nombre || '—',
        'Rol': elim.usuario_rol || '—',
        'Motivo': elim.motivo || '—'
      };
    });

  const wsEliminacionesD = XLSX.utils.json_to_sheet(filasEliminacionesD);
  XLSX.utils.book_append_sheet(libro, wsEliminacionesD, 'EliminacionesD');

  // Descargar
  descargarLibro(libro, 'Ordenes_Produccion');
}
