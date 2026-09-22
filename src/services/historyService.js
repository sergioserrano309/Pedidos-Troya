import { supabase } from '../config/supabaseClient.js';

/**
 * Servicio de historial (sección 12 + 15 del documento).
 *
 * - Comercial: ve todo el historial, sin filtros (movimientos + devoluciones).
 * - Otros roles: solo ven su propio historial (filtro por user_id), y las
 *   filas de tipo "devolucion" quedan automáticamente ocultas para ellos
 *   por la RLS de la tabla `returns` (ver vw_historial).
 *
 * El historial es inmutable: este servicio solo hace SELECT.
 */

const PAGE_SIZE = 50;

/**
 * @param {{ id: string, role: string }} user
 * @param {{ page?: number, orden?: string, fecha?: string, proceso?: string, despacho?: string }} options
 */
export async function fetchHistory(user, options = {}) {
  const { page = 0, orden = '', fecha = '', proceso = '', despacho = '' } = options;

  let query = supabase
    .from('vw_historial')
    .select('*', { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1);

  if (user.role !== 'comercial' && user.role !== 'validador') {
    query = query.eq('user_id', user.id);
  }

  if (orden.trim()) {
    query = query.ilike('order_number', `%${orden.trim()}%`);
  }

  // ID de despacho (049): cada registro de Empaque lleva el/los
  // consecutivos de la remesa en que salieron sus unidades. ilike para
  // que "d1021" o "1021" encuentren "D1021" (y "D1021, D1023").
  if (despacho.trim()) {
    query = query.ilike('despacho_consecutivo', `%${despacho.trim()}%`);
  }

  if (fecha) {
    const inicio = `${fecha}T00:00:00`;
    const fin = `${fecha}T23:59:59.999`;
    query = query.gte('created_at', inicio).lte('created_at', fin);
  }

  // Filtro por proceso (solo relevante para comercial/validador, que ven
  // registros de TODOS los procesos a la vez).
  if (proceso.trim()) {
    query = query.eq('from_process', proceso.trim());
  }

  const { data, error, count } = await query;

  if (error) {
    console.error('[historyService] Error obteniendo historial:', error);
    throw new Error('No se pudo cargar el historial.');
  }

  return { history: data || [], count: count || 0 };
}
