import { supabase } from '../config/supabaseClient.js';
import * as XLSX from 'xlsx';

const PAGE_SIZE = 1000;

/**
 * Obtiene todas las órdenes (sin filtrar por rol ni tab).
 * Pagina en bloques para traer todo el historial.
 */
async function fetchTodasLasOrdenes() {
  let allOrders = [];
  let page = 0;

  while (true) {
    const { data, error } = await supabase
      .from('vw_pedido_progreso')
      .select('*')
      .order('order_number', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);

    if (error) {
      console.error('[excelService] Error obteniendo órdenes:', error);
      throw new Error('No se pudieron cargar las órdenes.');
    }

    if (!data || data.length === 0) break;
    allOrders = allOrders.concat(data);
    page++;
  }

  return allOrders;
}

/**
 * Obtiene todo el historial (movimientos + devoluciones).
 * Pagina en bloques sin filtro de user_id (comercial acceso completo).
 */
async function fetchTodoElHistorial() {
  let allHistory = [];
  let page = 0;

  while (true) {
    const { data, error } = await supabase
      .from('vw_historial')
      .select('*')
      .order('created_at', { ascending: false })
      .range(page * PAGE_SIZE, (page + 1) * PAGE_SIZE - 1);

    if (error) {
      console.error('[excelService] Error obteniendo historial:', error);
      throw new Error('No se pudo cargar el historial.');
    }

    if (!data || data.length === 0) break;
    allHistory = allHistory.concat(data);
    page++;
  }

  return allHistory;
}

function formatearFecha(fecha) {
  if (!fecha) return '—';
  try {
    return new Date(fecha).toLocaleDateString('es-CO');
  } catch {
    return String(fecha);
  }
}

function formatearHora24(fecha) {
  if (!fecha) return '—';
  try {
    const d = new Date(fecha);
    const horas = String(d.getHours()).padStart(2, '0');
    const minutos = String(d.getMinutes()).padStart(2, '0');
    return `${horas}:${minutos}`;
  } catch {
    return String(fecha);
  }
}

export async function generarExcel() {
  const libro = XLSX.utils.book_new();

  // Cargar datos
  const ordenes = await fetchTodasLasOrdenes();
  const historial = await fetchTodoElHistorial();

  // === HOJA 1: ÓRDENES ===
  const hojaCórdenes = ordenes.map((orden) => ({
    'Orden': orden.order_number,
    'Cliente': orden.cliente || '—',
    'Fecha': formatearFecha(orden.fecha_pedido),
    'Total Solicitado': orden.total_solicitado ?? 0,
    'Total Procesado': orden.total_procesado ?? 0,
    'Total Pendiente': orden.total_pendiente ?? 0,
    '% Completado': orden.porcentaje_completado ?? 0,
    'Total Ítems': orden.total_items ?? 0
  }));
  const wsOrdenes = XLSX.utils.json_to_sheet(hojaCórdenes);
  XLSX.utils.book_append_sheet(libro, wsOrdenes, 'Órdenes');

  // === HOJAS DE PROCESOS ===
  const procesos = ['Refilado', 'Acabado', 'Mateado', 'Empaque'];

  procesos.forEach((proceso) => {
    const filasMovimientos = historial
      .filter((h) => h.tipo === 'movimiento' && h.from_process === proceso)
      .map((h) => ({
        'Orden': h.order_number,
        'Talla': h.size || '—',
        'Cantidad': h.quantity,
        'Enviado a': h.to_process || '—',
        'Usuario': h.user_name || '—',
        'Fecha': formatearFecha(h.created_at),
        'Hora': formatearHora24(h.created_at),
        'Observaciones': h.observation || '—'
      }));

    if (filasMovimientos.length > 0) {
      const ws = XLSX.utils.json_to_sheet(filasMovimientos);
      XLSX.utils.book_append_sheet(libro, ws, proceso);
    }
  });

  // === HOJA: INYECCIÓN (devoluciones) ===
  const filasInyeccion = historial
    .filter((h) => h.tipo === 'devolucion' && h.failed_process === 'Inyección')
    .map((h) => ({
      'Orden': h.order_number,
      'Talla': h.size || '—',
      'Cantidad': h.quantity,
      'Causal': h.causal || '—',
      'Acción': h.action || '—',
      'Usuario': h.user_name || '—',
      'Fecha': formatearFecha(h.created_at),
      'Hora': formatearHora24(h.created_at),
      'Observaciones': h.observation || '—'
    }));

  if (filasInyeccion.length > 0 || true) {
    // Agregar hoja aunque esté vacía (placeholder para futuro)
    const ws = XLSX.utils.json_to_sheet(filasInyeccion);
    XLSX.utils.book_append_sheet(libro, ws, 'Inyección');
  }

  // Descargar
  const fecha = new Date();
  const fechaStr = `${fecha.getFullYear()}-${String(fecha.getMonth() + 1).padStart(2, '0')}-${String(fecha.getDate()).padStart(2, '0')}`;
  const nombreArchivo = `Ordenes_Produccion_${fechaStr}.xlsx`;
  XLSX.writeFile(libro, nombreArchivo);
}
