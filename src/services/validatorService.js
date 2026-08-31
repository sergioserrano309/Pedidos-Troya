import { supabase } from '../config/supabaseClient.js';
import { getState } from '../state/appState.js';

/**
 * Validador es un rol INDEPENDIENTE (profiles.role = 'validador'), igual
 * que refilado/acabado/mateado/empaque — no es un rol adicional que se
 * agrega a otro usuario. Por eso la verificación es directa contra
 * getState().user.role, ya cargado desde profiles al hacer login.
 */
export function esValidador() {
  const { user } = getState();
  return user?.role === 'validador';
}

/**
 * Obtiene el rol de proceso actualmente activo del validador (para actuar
 * como Refilado/Acabado/Empaque). Se guarda en localStorage para persistencia.
 */
export function obtenerRolActivo() {
  return localStorage.getItem('rolActivo') || 'Refilado';
}

export function establecerRolActivo(rol) {
  localStorage.setItem('rolActivo', rol);
}

/**
 * Rol "efectivo" a usar en TODA lógica de negocio (visibilidad de
 * órdenes, filtros de registros, y qué puede procesar/a dónde puede
 * enviar). Para cualquier usuario normal, es simplemente su propio rol.
 * Para Validador, es el "Rol Activo" que eligió emular — así el sistema
 * se comporta exactamente como si ese rol estuviera conectado, sin
 * duplicar la lógica de ordersService/movementsService/orderDetail.
 * Si Validador tiene seleccionado "Validador" (vista maestra, sin
 * emular a nadie), el rol efectivo sigue siendo 'validador'.
 */
export function rolEfectivo() {
  const { user } = getState();
  if (!user) return null;
  if (user.role !== 'validador') return user.role;

  const activo = obtenerRolActivo();
  return activo === 'Validador' ? 'validador' : activo.toLowerCase();
}

/**
 * Igual que getState().user, pero con el rol reemplazado por
 * rolEfectivo() — conserva el id/nombre real (para auditoría), solo
 * cambia el campo que decide qué puede ver/hacer.
 */
export function usuarioEfectivo() {
  const { user } = getState();
  if (!user) return null;
  return { ...user, role: rolEfectivo() };
}

/**
 * Registra una acción del validador en audit_validador
 */
export async function registrarAuditValidador(
  accion,
  rolActuante,
  ordenId,
  itemId,
  detalle,
  razon
) {
  const { error } = await supabase.rpc('registrar_audit_validador', {
    p_accion: accion,
    p_rol_actuante: rolActuante,
    p_orden_id: ordenId,
    p_item_id: itemId,
    p_detalle: detalle,
    p_razon: razon
  });

  if (error) {
    console.error('[validatorService] Error registrando audit:', error);
    throw error;
  }
}

/**
 * Obtiene el historial de auditoría del validador
 */
export async function fetchAuditValidador(filtros = {}) {
  let query = supabase
    .from('audit_validador')
    .select('*')
    .order('creado_en', { ascending: false });

  if (filtros.accion) {
    query = query.eq('accion', filtros.accion);
  }

  if (filtros.rolActuante) {
    query = query.eq('rol_actuante', filtros.rolActuante);
  }

  if (filtros.ordenId) {
    query = query.eq('orden_id', filtros.ordenId);
  }

  if (filtros.fechaDesde) {
    query = query.gte('creado_en', filtros.fechaDesde);
  }

  if (filtros.fechaHasta) {
    query = query.lte('creado_en', filtros.fechaHasta);
  }

  const { data, error } = await query;

  if (error) {
    console.error('[validatorService] Error obteniendo audit:', error);
    return [];
  }

  return data || [];
}
