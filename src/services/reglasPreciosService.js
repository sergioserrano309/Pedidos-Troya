import { supabase } from '../config/supabaseClient.js';

/**
 * Reglas de precios automáticos (ver supabase/sql/023_compensacion_precios.sql):
 * mirror de reglasEnrutamientoService.js, pero con tipo_usuario (rol) y
 * destino como criterios adicionales, y precio en vez de destino-target.
 * El matching por especificidad lo hace fn_precio_aplicable en SQL, al
 * momento en que se crea cada movimiento — este servicio solo
 * administra el CRUD de las reglas, no necesita replicar el matching
 * en el cliente.
 */

export async function fetchReglasPrecios() {
  const { data, error } = await supabase
    .from('reglas_precios')
    .select('id, tipo_usuario, nombre_referencia, material, color, destino, precio, created_by, created_at, profiles(name)')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('[reglasPreciosService] Error obteniendo reglas de precios:', error);
    return [];
  }

  return data || [];
}

/**
 * @param {{ tipoUsuario: string, nombreReferencia: string|null, material: string|null, color: string|null, destino: string|null, precio: number }} regla
 * @param {{ id: string }} user
 */
export async function crearReglaPrecio(regla, user) {
  const { error } = await supabase
    .from('reglas_precios')
    .insert({
      tipo_usuario: regla.tipoUsuario,
      nombre_referencia: regla.nombreReferencia || null,
      material: regla.material || null,
      color: regla.color || null,
      destino: regla.destino || null,
      precio: regla.precio,
      created_by: user.id
    });

  if (error) {
    console.error('[reglasPreciosService] Error creando regla de precio:', error);
    throw new Error('No se pudo guardar la regla de precio. Intenta nuevamente.');
  }
}

export async function eliminarReglaPrecio(id) {
  const { error } = await supabase.from('reglas_precios').delete().eq('id', id);

  if (error) {
    console.error('[reglasPreciosService] Error eliminando regla de precio:', error);
    throw new Error('No se pudo eliminar la regla de precio.');
  }
}
