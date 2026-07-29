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
