import { supabase } from '../config/supabaseClient.js';

/**
 * Reglas de enrutamiento automático (ver supabase/sql/012_reglas_enrutamiento.sql):
 * pedidos que cumplen cierta combinación de Nombre Suela/Material/Color se
 * enrutan directo a Mateado o Empaque sin que Refilado tenga que confirmar
 * el destino manualmente. Cada campo nulo en la regla = comodín ("cualquiera").
 */

export async function fetchReglasEnrutamiento() {
  const { data, error } = await supabase
    .from('reglas_enrutamiento')
    .select('id, nombre_referencia, material, color, destino, created_by, created_at, profiles(name)')
    .order('created_at', { ascending: false });

  if (error) {
    console.error('[reglasEnrutamientoService] Error obteniendo reglas:', error);
    return [];
  }

  return data || [];
}

/**
 * @param {{ nombreReferencia: string|null, material: string|null, color: string|null, destino: string }} regla
 * @param {{ id: string }} user
 */
export async function crearReglaEnrutamiento(regla, user) {
  const { error } = await supabase
    .from('reglas_enrutamiento')
    .insert({
      nombre_referencia: regla.nombreReferencia || null,
      material: regla.material || null,
      color: regla.color || null,
      destino: regla.destino,
      created_by: user.id
    });

  if (error) {
    console.error('[reglasEnrutamientoService] Error creando regla:', error);
    throw new Error('No se pudo guardar la regla. Intenta nuevamente.');
  }
}

export async function eliminarReglaEnrutamiento(id) {
  const { error } = await supabase.from('reglas_enrutamiento').delete().eq('id', id);

  if (error) {
    console.error('[reglasEnrutamientoService] Error eliminando regla:', error);
    throw new Error('No se pudo eliminar la regla.');
  }
}

/**
 * Busca la regla más específica que coincida con un ítem (representa el
 * pedido completo: se asume Nombre/Material/Color uniformes en todas las
 * tallas de un mismo pedido). Un campo nulo en la regla es comodín.
 * Si varias reglas coinciden, gana la que tenga más criterios definidos.
 * @param {{ nombre_referencia?: string, material?: string, color?: string }} item
 * @param {Array} reglas
 */
export function encontrarReglaCoincidente(item, reglas) {
  const candidatas = reglas.filter((r) =>
    (!r.nombre_referencia || r.nombre_referencia === item.nombre_referencia) &&
    (!r.material || r.material === item.material) &&
    (!r.color || r.color === item.color)
  );

  if (candidatas.length === 0) return null;

  const especificidad = (r) => [r.nombre_referencia, r.material, r.color].filter(Boolean).length;
  candidatas.sort((a, b) => especificidad(b) - especificidad(a));

  return candidatas[0];
}
