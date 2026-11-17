/**
 * Filtro por "Estado" del pedido (solo Validador): En proceso, Completado y
 * Cerrado. Se pueden elegir varios a la vez.
 *
 *   En proceso -> estatus_general = 'En Proceso' y NO cerrado a la fuerza
 *   Completado -> estatus_general = 'Completado' y NO cerrado a la fuerza
 *   Cerrado    -> cerrado a la fuerza (057), aunque su estatus real sea "En Proceso"
 *
 * Un pedido cerrado a la fuerza se muestra como "Cerrada" en toda la
 * plataforma, por eso "Cerrado" manda sobre el estatus real.
 */

export const ESTADOS_PEDIDO = [
  { valor: 'en_proceso', etiqueta: 'En proceso' },
  { valor: 'completado', etiqueta: 'Completado' },
  { valor: 'cerrado', etiqueta: 'Cerrado' }
];

const CONDICION = {
  en_proceso: 'and(estatus_general.eq."En Proceso",cierre_forzado.eq.false)',
  completado: 'and(estatus_general.eq."Completado",cierre_forzado.eq.false)',
  cerrado: 'cierre_forzado.eq.true'
};

/**
 * Condición para `.or()` de PostgREST que une (O) los estados elegidos.
 * Devuelve null si no hay que filtrar: ninguno elegido, o los tres (que
 * equivale a no filtrar).
 * @param {string[]} valores
 * @returns {string|null}
 */
export function condicionEstados(valores) {
  const elegidos = [...new Set((valores || []).filter((v) => CONDICION[v]))];
  if (elegidos.length === 0 || elegidos.length === ESTADOS_PEDIDO.length) return null;
  return elegidos.map((v) => CONDICION[v]).join(',');
}
