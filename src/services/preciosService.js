import { supabase } from '../config/supabaseClient.js';
import { registrarAuditValidador } from './validatorService.js';
import { ROLE_LABELS } from '../lib/roles.js';

/**
 * Precio COP por par procesado, por rol (ver
 * supabase/sql/023_compensacion_precios.sql). Invisible por RLS para
 * cualquier rol distinto de validador — fetchPreciosPorPar() retorna []
 * silenciosamente para cualquier otro usuario, en vez de lanzar error.
 */
export async function fetchPreciosPorPar() {
  const { data, error } = await supabase
    .from('precios_por_par')
    .select('rol, precio, updated_at')
    .order('rol');

  if (error) {
    console.error('[preciosService] Error obteniendo precios:', error);
    return [];
  }

  return data || [];
}

/**
 * Actualiza el precio de un rol y deja registro en audit_validador
 * (reutiliza el log de auditoría ya existente, no crea uno nuevo — ver
 * accion='precio_actualizado').
 * @param {'refilado'|'acabado'|'mateado'|'empaque'} rol
 * @param {number} nuevoPrecio
 * @param {{ id: string }} user
 */
export async function actualizarPrecioPorPar(rol, nuevoPrecio, user) {
  const { data: actual, error: errorLectura } = await supabase
    .from('precios_por_par')
    .select('precio')
    .eq('rol', rol)
    .maybeSingle();

  if (errorLectura) {
    console.error('[preciosService] Error leyendo precio actual:', errorLectura);
    throw new Error('No se pudo leer el precio actual. Intenta nuevamente.');
  }

  const { error } = await supabase
    .from('precios_por_par')
    .update({ precio: nuevoPrecio, updated_by: user.id, updated_at: new Date().toISOString() })
    .eq('rol', rol);

  if (error) {
    console.error('[preciosService] Error actualizando precio:', error);
    throw new Error('No se pudo actualizar el precio. Intenta nuevamente.');
  }

  try {
    await registrarAuditValidador(
      'precio_actualizado',
      ROLE_LABELS[rol] || rol,
      null,
      null,
      { precio_anterior: actual?.precio ?? null, precio_nuevo: nuevoPrecio },
      null
    );
  } catch (err) {
    // El precio ya quedó guardado; si la auditoría falla no revertimos
    // el cambio (mismo criterio que movementsService.js con audit_validador).
    console.error('[preciosService] Error registrando auditoría de precio:', err);
  }
}
