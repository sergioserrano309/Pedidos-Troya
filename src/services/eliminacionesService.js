import { supabase } from '../config/supabaseClient.js';

/**
 * Lectura del log de eliminaciones (tabla log_eliminaciones de 014, vista
 * vw_log_eliminaciones de 042). Cubre a TODOS los usuarios y ambos tipos
 * de borrado: movimientos de producción y despachos completos.
 *
 * Solo lectura: la tabla nunca se escribe desde el cliente — la llenan
 * las funciones security definer eliminar_movimiento_con_motivo (014/041)
 * y eliminar_despacho_con_motivo (039).
 */

const PAGE_SIZE = 50;

/**
 * @param {{ page?: number, filters?: { tipo?: string, referencia?: string, desde?: string, hasta?: string } }} options
 */
export async function fetchEliminaciones(options = {}) {
  const { page = 0, filters = {} } = options;
  const { tipo = '', referencia = '', desde = '', hasta = '' } = filters;

  let query = supabase.from('vw_log_eliminaciones').select('*', { count: 'exact' });

  if (tipo.trim()) query = query.eq('tabla_origen', tipo.trim());
  if (referencia.trim()) query = query.ilike('referencia', `%${referencia.trim()}%`);
  if (desde.trim()) query = query.gte('eliminado_en', `${desde}T00:00:00`);
  if (hasta.trim()) query = query.lte('eliminado_en', `${hasta}T23:59:59.999`);

  query = query
    .order('eliminado_en', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE - 1);

  const { data, error, count } = await query;

  if (error) {
    console.error('[eliminacionesService] Error obteniendo eliminaciones:', error);
    throw new Error('No se pudo cargar el historial de eliminaciones.');
  }

  return { eliminaciones: data || [], count: count || 0, pageSize: PAGE_SIZE };
}
