import { supabase } from '../config/supabaseClient.js';

/**
 * Servicio de órdenes de producción.
 *
 * Todo el cálculo de progreso vive en las vistas SQL
 * (vw_pedido_progreso / vw_item_progreso, ver supabase/sql/005_views_dashboard.sql)
 * para cumplir la regla de negocio: "el progreso nunca se almacena,
 * siempre se calcula". Este servicio solo consulta esas vistas y aplica
 * la visibilidad por rol.
 *
 * Visibilidad por rol (sección 6 del documento):
 *   - refilado / comercial: ven TODAS las órdenes.
 *   - acabado / mateado / empaque: solo ven órdenes que tengan al menos
 *     un ítem cuya etapa_actual coincida con su proceso.
 */

const ROLE_TO_PROCESS = {
  acabado: 'Acabado',
  mateado: 'Mateado',
  empaque: 'Empaque'
};

const PAGE_SIZE = 20;

/**
 * @param {{ role: string }} user
 * @param {'activas'|'completadas'} tab
 * @param {{ page?: number, filters?: { orden?: string, cliente?: string, material?: string, color?: string } }} options
 */
export async function fetchOrders(user, tab = 'activas', options = {}) {
  const { page = 0, filters = {} } = options;
  const { orden = '', cliente = '', material = '', color = '' } = filters;

  let query = supabase.from('vw_pedido_progreso').select('*', { count: 'exact' });

  const proceso = ROLE_TO_PROCESS[user.role];
  if (proceso) {
    const orderNumbers = await obtenerPedidosVisiblesParaProceso(proceso);
    if (orderNumbers.length === 0) {
      return { orders: [], count: 0 };
    }
    query = query.in('order_number', orderNumbers);
  }

  if (tab === 'completadas') {
    query = query.eq('porcentaje_completado', 100);
  } else {
    query = query.lt('porcentaje_completado', 100);
  }

  if (orden.trim()) {
    query = query.ilike('order_number', `%${orden.trim()}%`);
  }
  if (cliente.trim()) {
    query = query.ilike('cliente', `%${cliente.trim()}%`);
  }
  if (material.trim()) {
    query = query.ilike('material', `%${material.trim()}%`);
  }
  if (color.trim()) {
    query = query.ilike('color', `%${color.trim()}%`);
  }

  query = query
    .order('order_number', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1);

  const { data, error, count } = await query;

  if (error) {
    console.error('[ordersService] Error obteniendo órdenes:', error);
    throw new Error('No se pudieron cargar las órdenes.');
  }

  return { orders: data || [], count: count || 0 };
}

/**
 * Detalle completo de una orden: todos sus ítems con progreso calculado.
 * @param {string} orderNumber
 */
export async function fetchOrderDetail(orderNumber) {
  const { data, error } = await supabase
    .from('vw_item_progreso')
    .select('*')
    .eq('order_number', orderNumber)
    .order('talla', { ascending: true });

  if (error) {
    console.error('[ordersService] Error obteniendo detalle de orden:', error);
    throw new Error('No se pudo cargar el detalle de la orden.');
  }

  return data || [];
}

async function obtenerPedidosVisiblesParaProceso(proceso) {
  const { data, error } = await supabase
    .from('vw_item_progreso')
    .select('order_number')
    .eq('etapa_actual', proceso);

  if (error) {
    console.error('[ordersService] Error obteniendo visibilidad por proceso:', error);
    return [];
  }

  return [...new Set((data || []).map((row) => row.order_number))];
}
