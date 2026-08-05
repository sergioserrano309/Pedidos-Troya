/**
 * Reglas de negocio de roles (sección 6 del documento).
 *
 * Mapea cada rol de `profiles.role` (minúsculas, como está en la BD) al
 * nombre de proceso "bonito" usado en production_movements.from_process /
 * to_process (que coincide con los valores usados en el HTML original:
 * 'Refilado', 'Acabado', 'Mateado', 'Empaque').
 */

export const ROLE_TO_PROCESS_NAME = {
  refilado: 'Refilado',
  acabado: 'Acabado',
  mateado: 'Mateado',
  empaque: 'Empaque',
  comercial: null // Comercial no procesa, solo registra devoluciones/ve historial
};

/**
 * A qué procesos puede enviar un item cada rol al presionar "Procesar".
 * Empaque no "envía" a otro proceso: marca la producción como completada
 * (se modela como un movimiento especial hacia 'Completado').
 */
export const DESTINOS_PERMITIDOS_POR_ROL = {
  refilado: ['Acabado', 'Mateado', 'Empaque'],
  acabado: ['Empaque'],
  mateado: ['Empaque'],
  empaque: ['Completado']
};

export function nombreProcesoDeRol(role) {
  return ROLE_TO_PROCESS_NAME[role] || null;
}

export function destinosPermitidos(role) {
  return DESTINOS_PERMITIDOS_POR_ROL[role] || [];
}

export function esRolDeProceso(role) {
  return role === 'refilado' || role === 'acabado' || role === 'mateado' || role === 'empaque';
}

export const ROLE_LABELS = {
  refilado: 'Refilado',
  acabado: 'Acabado',
  mateado: 'Mateado',
  empaque: 'Empaque',
  comercial: 'Comercial'
};

export const ICONO_PROCESO = {
  Refilado: '✂️',
  Acabado: '🖌️',
  Mateado: '🎨',
  Empaque: '📦'
};
