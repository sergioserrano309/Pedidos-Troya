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
 * Control Central (Validador): "Cerrado" también se separa por clasificación del
 * cierre (087/089): con tipo elegido (Cancelado, No se terminó…, Troya…) o
 * "Sin clasificar" (cierres anteriores a 087 que nadie ha clasificado).
 */
export const ESTADOS_CONTROL_CENTRAL = [
  ...ESTADOS_PEDIDO,
  { valor: 'cerrado_clasificado', etiqueta: 'Cerrado · Clasificado' },
  { valor: 'cerrado_sin_clasificar', etiqueta: 'Cerrado · Sin clasificar' }
];

const SUBCERRADOS = { cerrado_clasificado: true, cerrado_sin_clasificar: false };

/**
 * Condición para `.or()` de PostgREST que une (O) los estados elegidos.
 * Devuelve null si no hay que filtrar: ninguno elegido, o En proceso +
 * Completado + Cerrado (que equivale a no filtrar).
 *
 * Los dos "Cerrado · …" necesitan `tiposCierre` (Map pedido -> tipo|null de los
 * pedidos cerrados). Sin él se tratan como "Cerrado" a secas.
 * @param {string[]} valores
 * @param {Map<string, string|null>|null} [tiposCierre]
 * @returns {string|null}
 */
export function condicionEstados(valores, tiposCierre = null) {
  const elegidos = new Set((valores || []).filter((v) => CONDICION[v] || v in SUBCERRADOS));
  if (elegidos.size === 0) return null;
  const cierraTodo = elegidos.has('cerrado')
    || (elegidos.has('cerrado_clasificado') && elegidos.has('cerrado_sin_clasificar'));
  if (elegidos.has('en_proceso') && elegidos.has('completado') && cierraTodo) return null;

  const alternativas = [];
  elegidos.forEach((v) => {
    if (CONDICION[v]) {
      alternativas.push(CONDICION[v]);
    } else if (!tiposCierre) {
      alternativas.push(CONDICION.cerrado);
    } else {
      const ordenes = [...tiposCierre]
        .filter(([, tipo]) => (tipo != null) === SUBCERRADOS[v])
        .map(([orden]) => orden);
      if (ordenes.length > 0) {
        alternativas.push(`and(cierre_forzado.eq.true,order_number.in.(${ordenes.join(',')}))`);
      }
    }
  });
  // Ningún pedido cumple (p. ej. no hay cierres sin clasificar): condición imposible.
  return alternativas.length > 0 ? alternativas.join(',') : 'order_number.eq.__ninguno__';
}

/**
 * Misma regla que condicionEstados, pero evaluada en el navegador sobre una
 * fila ya descargada (para filtrar sin volver a consultar).
 * @param {{ order_number?: string, estatus_general?: string, cierre_forzado?: boolean }} fila
 * @param {string[]} valores
 * @param {Map<string, string|null>|null} [tiposCierre]
 */
export function cumpleEstados(fila, valores, tiposCierre = null) {
  if (condicionEstados(valores, tiposCierre) === null) return true; // sin filtro
  const cerrado = fila.cierre_forzado === true;
  return (valores || []).some((v) => {
    if (v === 'cerrado') return cerrado;
    if (v in SUBCERRADOS) {
      if (!cerrado) return false;
      if (!tiposCierre) return true;
      return (tiposCierre.get(String(fila.order_number)) != null) === SUBCERRADOS[v];
    }
    if (v === 'en_proceso') return !cerrado && fila.estatus_general === 'En Proceso';
    if (v === 'completado') return !cerrado && fila.estatus_general === 'Completado';
    return false;
  });
}
