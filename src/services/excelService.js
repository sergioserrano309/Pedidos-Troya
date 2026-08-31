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

async function fetchTodasLasEliminaciones() {
  let all = [];
  let page = 0;
  while (true) {
    const { data, error } = await supabase
      .from('log_eliminaciones')
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
      'D_Empaque': dias.dEmpaque
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

  // === HOJA ELIMINACIONES ===
  const filasEliminaciones = eliminaciones.map((elim) => {
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

  // Descargar
  const fecha = new Date();
  const fechaStr = `${fecha.getFullYear()}-${String(fecha.getMonth() + 1).padStart(2, '0')}-${String(fecha.getDate()).padStart(2, '0')}`;
  XLSX.writeFile(libro, `Ordenes_Produccion_${fechaStr}.xlsx`);
}
