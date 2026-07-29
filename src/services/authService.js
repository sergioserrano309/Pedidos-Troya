import { supabase } from '../config/supabaseClient.js';

/**
 * Servicio de autenticación (Supabase Auth) + resolución del perfil de
 * negocio (rol) asociado al usuario autenticado.
 *
 * Nota UX: el campo "Usuario" del login (produccion_app.html) se usa
 * como el correo electrónico de Supabase Auth (signInWithPassword
 * requiere email + password).
 */

/**
 * @param {string} email
 * @param {string} password
 * @returns {Promise<{ id: string, authId: string, name: string, email: string, role: string }>}
 */
export async function login(email, password) {
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    throw new Error(traducirErrorAuth(error));
  }

  const profile = await obtenerPerfilPorAuthId(data.user.id);

  if (!profile) {
    await supabase.auth.signOut();
    throw new Error(
      'Tu usuario no tiene un perfil de negocio asignado. Contacta a un administrador para que te asigne un rol.'
    );
  }

  return profile;
}

export async function logout() {
  await supabase.auth.signOut();
}

/**
 * Recupera la sesión activa (si existe) y su perfil, útil al recargar
 * la página para no perder la sesión.
 * @returns {Promise<{ id: string, authId: string, name: string, email: string, role: string } | null>}
 */
export async function obtenerSesionActual() {
  const { data, error } = await supabase.auth.getSession();

  if (error || !data.session) {
    return null;
  }

  return obtenerPerfilPorAuthId(data.session.user.id);
}

async function obtenerPerfilPorAuthId(authId) {
  const { data, error } = await supabase
    .from('profiles')
    .select('id, auth_id, name, email, role')
    .eq('auth_id', authId)
    .maybeSingle();

  if (error) {
    console.error('[authService] Error obteniendo perfil:', error);
    return null;
  }

  if (!data) return null;

  return {
    id: data.id,
    authId: data.auth_id,
    name: data.name,
    email: data.email,
    role: data.role
  };
}

function traducirErrorAuth(error) {
  const msg = String(error?.message || '').toLowerCase();
  if (msg.includes('invalid login credentials')) {
    return 'Usuario o contraseña incorrectos.';
  }
  if (msg.includes('email not confirmed')) {
    return 'Debes confirmar tu correo antes de iniciar sesión.';
  }
  return 'No se pudo iniciar sesión. Intenta nuevamente.';
}
