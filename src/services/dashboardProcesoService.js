import { supabase } from '../config/supabaseClient.js';
import { destinosDashboardProceso, nombreProcesoDeRol } from '../lib/roles.js';
import { registrarMovimientosLote } from './movementsService.js';
import { confirmarDestinoOrden, fetchDestinoOrden } from './destinoService.js';

/**
 * Lectura y envío del dashboard operativo (SQL 085).
 * No escribe en p_pedidosh. Un envío = un movimiento de una talla.
 */

const PAGE_SIZE = 30;

function errorVista(error) {
  const codigo = String(error?.code || '');
  const msg = String(error?.message || '').toLowerCase();
  if (codigo === 'PGRST205' || codigo === '42P01' || msg.includes('could not find the table') || msg.includes('does not exist')) {
    return new Error('Falta crear la vista vw_dashboard_proceso en Supabase (SQL 085).');
  }
  return new Error('No se pudieron cargar los pedidos del área.');
}

/**
 * @param {'Refilado'|'Acabado'|'Mateado'} proceso
 * @param {number} page
 * @returns {Promise<{ pedidos: object[], hayMas: boolean }>}
 */
export async function fetchPedidosDashboardProceso(proceso, page = 0) {
  const { data, error } = await supabase
    .from('vw_dashboard_proceso')
    .select('*')
    .eq('proceso', proceso)
    .order('llegada_al_area', { ascending: true, nullsFirst: false })
    .order('order_number', { ascending: true })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE);

  if (error) {
    console.error('[dashboardProcesoService] Error leyendo vw_dashboard_proceso:', error);
    throw errorVista(error);
  }

  const filas = data || [];
  const hayMas = filas.length > PAGE_SIZE;
  return { pedidos: filas.slice(0, PAGE_SIZE), hayMas };
}

export const TAMANO_PAGINA_DASHBOARD_PROCESO = PAGE_SIZE;

/**
 * Confirma destino si hace falta y registra UN movimiento de esa talla.
 * Refilado no puede mandar a Empaque desde este dashboard.
 *
 * @param {{
 *   pedido: object,
 *   talla: object,
 *   cantidad: number,
 *   destino: string,
 *   user: { id: string, role: string }
 * }} args
 */
export async function enviarTallaDashboardProceso({ pedido, talla, cantidad, destino, user }) {
  const permitidos = destinosDashboardProceso(user.role);
  if (!permitidos.includes(destino)) {
    throw new Error('Ese destino no está permitido en este dashboard.');
  }

  const pendiente = Number(talla.pendiente) || 0;
  const qty = Number(cantidad) || 0;
  if (qty <= 0) {
    throw new Error('Escribe cuántos pares vas a enviar.');
  }
  if (qty > pendiente) {
    throw new Error(`Solo quedan ${pendiente} pares pendientes en esa talla.`);
  }

  if (user.role === 'refilado') {
    const actual = pedido.destino || (await fetchDestinoOrden(pedido.order_number))?.destino || null;
    if (actual && actual !== destino) {
      throw new Error(`Este pedido ya se envía a ${actual}.`);
    }
    if (!actual) {
      await confirmarDestinoOrden(pedido.order_number, destino, user);
    }
  }

  const item = {
    item_id: talla.item_id,
    order_number: pedido.order_number,
    talla: talla.talla,
    nombre_referencia: talla.referencia || pedido.nombre_suela,
    cantidad_pendiente: pendiente
  };

  await registrarMovimientosLote(
    [{ item, cantidad: qty, pendiente }],
    { destino, observacion: null, user }
  );
}

export function procesoDeUsuario(user) {
  return nombreProcesoDeRol(user?.role);
}
