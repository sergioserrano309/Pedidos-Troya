import { supabase } from '../config/supabaseClient.js';

/**
 * Valida el código de acceso del usuario contra la base de datos.
 * @param {string} userId - ID del usuario (profiles.id)
 * @param {string} code - Código ingresado por el usuario
 * @returns {Promise<boolean>}
 */
export async function validarCodigoAcceso(userId, code) {
  const { data, error } = await supabase
    .from('access_codes')
    .select('id')
    .eq('user_id', userId)
    .eq('code', code.trim())
    .maybeSingle();

  if (error) {
    console.error('[accessCodeService] Error validando código:', error);
    return false;
  }

  return !!data;
}
