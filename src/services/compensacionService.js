import { supabase } from '../config/supabaseClient.js';
import { esRolDeProceso } from '../lib/roles.js';
import { esValidador, rolEfectivo } from './validatorService.js';

/**
 * Compensación por rol (ver supabase/sql/025_compensacion_vistas.sql):
 * cada línea de vw_compensacion_lineas ya viene con su valor congelado
 * (precio vigente cuando se hizo ese registro) y solo aparece una vez
 * que el pedido completo (todas sus tallas) llegó al 100% para ese rol
 * — no antes.
 *
 * Mismo patrón de visibilidad que historyService.js: un operario normal
 * solo ve sus propias líneas (.eq('user_id', ...)); Validador actuando
 * como un rol específico ve la nómina completa de ese rol (todos los
 * operarios). "Validador (vista maestra)" no tiene contenido propio
 * aquí — retorna [] (no es un rol de proceso).
 *
 * @param {{ id: string }} user
 * @returns {Promise<Array>}
 */
export async function fetchCompensacionLineas(user) {
  const rol = rolEfectivo();
  if (!esRolDeProceso(rol)) return [];

  let query = supabase
    .from('vw_compensacion_lineas')
    .select('*')
    .eq('rol', rol)
    .order('fecha_liquidacion', { ascending: true });

  if (!esValidador()) {
    query = query.eq('user_id', user.id);
  }

  const { data, error } = await query;

  if (error) {
    console.error('[compensacionService] Error obteniendo líneas de compensación:', error);
    throw new Error('No se pudo cargar la compensación.');
  }

  return data || [];
}
