/**
 * Cálculos de progreso de producción.
 *
 * Regla crítica del negocio: el progreso NUNCA se guarda en base de datos,
 * siempre se calcula en el momento a partir de:
 *   Requerido   = Pedidos Prueba.CantidadP
 *   Procesado   = SUM(production_movements.quantity)
 *   Devuelto    = SUM(returns.quantity)
 *   Pendiente   = Requerido - Procesado + Reprocesado
 *   Completado% = Procesado / Requerido * 100
 */

/**
 * @param {number} requerido  Cantidad solicitada (CantidadP)
 * @param {number} procesado  Suma de production_movements.quantity para el ítem
 * @param {number} devuelto   Suma de returns.quantity para el ítem
 * @returns {{ requerido: number, procesado: number, devuelto: number, pendiente: number, porcentaje: number }}
 */
export function calcularProgresoItem(requerido = 0, procesado = 0, devuelto = 0) {
  const req = Number(requerido) || 0;
  const proc = Number(procesado) || 0;
  const dev = Number(devuelto) || 0;

  const pendiente = Math.max(req - proc + dev, 0);
  const porcentaje = req > 0 ? Math.min(Math.round((proc / req) * 100), 100) : 0;

  return {
    requerido: req,
    procesado: proc,
    devuelto: dev,
    pendiente,
    porcentaje
  };
}

/**
 * % REAL de lo hecho sobre lo pedido, SIN tope de 100 (110 de 100 = 110%).
 * Se usa donde importa el dato real (Control Central y el Excel); las barras de
 * Activas/Completadas siguen topadas en 100 (vienen de las vistas).
 * Si todavía falta algo nunca se redondea hacia 100: 99,67% se muestra 99%.
 * @param {number} parte  pares hechos (procesados, inyectados, despachados)
 * @param {number} total  pares pedidos
 */
export function porcentajeReal(parte, total) {
  const t = Number(total) || 0;
  if (t <= 0) return 0;
  const p = Number(parte) || 0;
  const r = Math.round((p / t) * 100);
  return p < t ? Math.min(r, 99) : r;
}

/**
 * Agrega los progresos de varios ítems de un mismo pedido (PedidoNo) para
 * obtener las cifras totales que se muestran en la card del dashboard.
 * @param {Array<{requerido:number, procesado:number, devuelto:number}>} items
 */
export function calcularProgresoPedido(items) {
  const totales = items.reduce(
    (acc, item) => {
      acc.requerido += Number(item.requerido) || 0;
      acc.procesado += Number(item.procesado) || 0;
      acc.devuelto += Number(item.devuelto) || 0;
      return acc;
    },
    { requerido: 0, procesado: 0, devuelto: 0 }
  );

  return calcularProgresoItem(totales.requerido, totales.procesado, totales.devuelto);
}

/**
 * Determina el estado visual de un pedido/ítem según su porcentaje de avance.
 * @param {number} porcentaje
 * @returns {'por-procesar'|'en-proceso'|'completado'}
 */
export function estadoPorPorcentaje(porcentaje) {
  if (porcentaje >= 100) return 'completado';
  if (porcentaje > 0) return 'en-proceso';
  return 'por-procesar';
}
