import { supabase } from '../config/supabaseClient.js';
import * as XLSX from 'xlsx';
import { soloFecha, construirMapaUltimaFechaPorProceso, fechaFinProceso, calcularDiasPorProceso } from '../lib/procesoDias.js';

const PAGE_SIZE = 1000;

async function fetchTodasLasOrdenes() {
  let allOrders = [];
  let page = 0;
  while (true) {
    const { data, error } = await supabase
      .from('vw_pedido_progreso')
      .select('*')
      .order('order_number', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (error) throw new Error('No se pudieron cargar las órdenes.');
    if (!data || data.length === 0) break;
    allOrders = allOrders.concat(data);
    page++;
  }
  return allOrders;
}

async function fetchTodoElHistorial() {
  let allHistory = [];
  let page = 0;
  while (true) {
    const { data, error } = await supabase
      .from('vw_historial')
      .select('*')
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (error) throw new Error('No se pudo cargar el historial.');
    if (!data || data.length === 0) break;
    allHistory = allHistory.concat(data);
    page++;
  }
  return allHistory;
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
      .select('order_number, unidades_despachadas, pedido_completo, fecha_ultimo_despacho')
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
 * Detalle despacho x orden (054) para la hoja "Despachos".
 */
async function fetchTodoElDetalleDespachos() {
  let all = [];
  let page = 0;
  while (true) {
    const { data, error } = await supabase
      .from('vw_despacho_orden_detalle')
      .select('*')
      .order('consecutivo', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (error) return all;
    if (!data || data.length === 0) break;
    all = all.concat(data);
    page++;
  }
  return all;
}

/**
 * Unidades por despacho x orden x talla. Es lo que se pivota en las
 * columnas de talla de la hoja "Despachos".
 */
async function fetchTodosLosItemsDespachados() {
  let all = [];
  let page = 0;
  while (true) {
    const { data, error } = await supabase
      .from('despacho_orden_items')
      .select('despacho_id, order_number, talla, cantidad')
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);
    if (error) return all;
    if (!data || data.length === 0) break;
    all = all.concat(data);
    page++;
  }
  return all;
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

export async function generarExcel() {
  const libro = XLSX.utils.book_new();
  const ordenes = await fetchTodasLasOrdenes();
  const historial = await fetchTodoElHistorial();
  const destinos = await fetchTodosLosDestinos();
  const eliminaciones = await fetchTodasLasEliminaciones();
  const estadoDespacho = await fetchTodoElEstadoDespacho();
  const detalleDespachos = await fetchTodoElDetalleDespachos();
  const itemsDespachados = await fetchTodosLosItemsDespachados();
  const tallas = await fetchTodasLasTallas();

  const mapaOrdenes = {};
  ordenes.forEach((o) => {
    mapaOrdenes[o.order_number] = o;
  });

  const mapaUltimaFecha = construirMapaUltimaFechaPorProceso(historial);

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
      'Fecha': soloFecha(orden.fecha_pedido),
      'Total Solicita': orden.total_solicitado ?? 0,
      'Total Procese': orden.total_procesado ?? 0,
      'Total Pendier': orden.total_pendiente ?? 0,
      '% Completad': orden.porcentaje_completado ?? 0,
      'Total Items': orden.total_items ?? 0,
      'Regla': tieneRegla,
      'ReglaProceso': procesoProceso,
      'P_Refilado': orden.procesado_refilado ?? 0,
      'P_Acabado': orden.procesado_acabado ?? 0,
      'P_Empaque': orden.procesado_empaque ?? 0,
      'P_Mateado': orden.procesado_mateado ?? 0,
      '%_Refilado': orden.porcentaje_refilado ?? 0,
      '%_Acabado': orden.porcentaje_acabado ?? 0,
      '%_Empaque': orden.porcentaje_empaque ?? 0,
      '%_Mateado': orden.porcentaje_mateado ?? 0,
      'F_Refilado': fechaFinProceso(orden, 'Refilado', 'porcentaje_refilado', mapaUltimaFecha),
      'F_Acabado': fechaFinProceso(orden, 'Acabado', 'porcentaje_acabado', mapaUltimaFecha),
      'F_Empaque': fechaFinProceso(orden, 'Empaque', 'porcentaje_empaque', mapaUltimaFecha),
      'F_Mateado': fechaFinProceso(orden, 'Mateado', 'porcentaje_mateado', mapaUltimaFecha),
      'D_Refilado': dias.dRefilado,
      'D_Acabado': dias.dAcabado,
      'D_Mateado': dias.dMateado,
      'D_Empaque': dias.dEmpaque,
      // Misma lectura que F_Refilado/F_Acabado/F_Empaque/F_Mateado: la
      // fecha solo aparece cuando el proceso llegó al 100%. Mientras el
      // pedido siga con saldo por despachar, queda en blanco aunque ya
      // haya salido parte — que es justo lo que distingue "despachado"
      // de "despachado a medias".
      'F_Despacho': despachoDeOrden(orden.order_number, estadoDespacho).fecha,
      'Unidades Despachadas': despachoDeOrden(orden.order_number, estadoDespacho).unidades
    };
  });
  const wsOrdenes = XLSX.utils.json_to_sheet(hojaCórdenes);
  XLSX.utils.book_append_sheet(libro, wsOrdenes, 'Órdenes');

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
          'Fecha': soloFecha(h.created_at),
          'Hora': formatearHora24(h.created_at),
          'Observaciones': h.observation || '—'
        };
      });

    if (filasMovimientos.length > 0) {
      const ws = XLSX.utils.json_to_sheet(filasMovimientos);
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
        'Fecha': soloFecha(h.created_at),
        'Hora': formatearHora24(h.created_at),
        'Observaciones': h.observation || '—'
      };
    });

  const wsInyeccion = XLSX.utils.json_to_sheet(filasInyeccion);
  XLSX.utils.book_append_sheet(libro, wsInyeccion, 'Inyección');

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

  const wsDespachos = XLSX.utils.json_to_sheet(filasDespachos);
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
  const fecha = new Date();
  const fechaStr = `${fecha.getFullYear()}-${String(fecha.getMonth() + 1).padStart(2, '0')}-${String(fecha.getDate()).padStart(2, '0')}`;
  XLSX.writeFile(libro, `Ordenes_Produccion_${fechaStr}.xlsx`);
}
