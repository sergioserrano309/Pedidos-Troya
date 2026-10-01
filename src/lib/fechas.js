/**
 * Manejo de fechas de calendario (sin hora).
 *
 * "fecha_pedido" (p_pedidosh."FechaP") es una fecha de Access guardada
 * como timestamptz a medianoche UTC (3/08/2026 -> 2026-08-03T00:00:00Z).
 * Convertida a la hora local de Colombia (UTC-5) cae en la noche del día
 * ANTERIOR (2/08, 19:00), por eso mostrarla con la zona local la corría
 * un día. Es una fecha de calendario, no un instante: se lee en UTC.
 *
 * Las fechas de REGISTRO (created_at de movimientos, despachos,
 * eliminaciones) sí son instantes reales y se siguen mostrando en hora
 * local.
 */

/** "3/8/2026" para una fecha de calendario guardada a medianoche UTC. */
export function formatearFechaPedido(fecha) {
  if (!fecha) return '—';
  try {
    return new Date(fecha).toLocaleDateString('es-CO', { timeZone: 'UTC' });
  } catch {
    return String(fecha);
  }
}

/**
 * Date local (medianoche) con el día de calendario de fecha_pedido, para
 * poder restarla contra fechas locales de movimientos sin correr un día.
 */
export function diaPedidoLocal(fecha) {
  if (!fecha) return null;
  const d = new Date(fecha);
  if (Number.isNaN(d.getTime())) return null;
  return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}

/**
 * Número de serie de Excel (entero) de un Date local de solo-día.
 *
 * Por qué no se le pasa el Date a la librería xlsx: para fechas en hora
 * local de Colombia calcula el serial con el desfase histórico de la zona
 * de 1899 (LMT, -4:56:16) redondeado al minuto, y una medianoche local
 * queda unos segundos ANTES de la medianoche (46294.9998), que Excel
 * muestra como el día anterior. Con un entero no hay desfase posible.
 * @returns {number|null}
 */
export function serialExcelDeDia(dia) {
  if (!(dia instanceof Date) || Number.isNaN(dia.getTime())) return null;
  return Date.UTC(dia.getFullYear(), dia.getMonth(), dia.getDate()) / 86400000 + 25569;
}
