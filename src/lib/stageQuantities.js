/**
 * Cálculo de cantidad pendiente POR PROCESO para una talla, a partir de
 * sus movimientos reales (entradas/salidas), en vez de depender de
 * "etapa_actual" (que solo refleja el destino del último movimiento).
 *
 * Esto permite procesar una talla en varios lotes: mientras quede
 * cantidad pendiente en el proceso del rol actual, el botón "Procesar"
 * sigue disponible.
 *
 * No incluye devoluciones/reproceso (tabla returns) todavía.
 */
export function calcularPendientePorProceso(item, movimientos, proceso) {
  const movimientosDelItem = movimientos.filter((m) => m.item_id === item.item_id);

  const entradas = movimientosDelItem
    .filter((m) => m.to_process === proceso)
    .reduce((sum, m) => sum + Number(m.quantity || 0), 0);

  const salidas = movimientosDelItem
    .filter((m) => m.from_process === proceso)
    .reduce((sum, m) => sum + Number(m.quantity || 0), 0);

  const base = proceso === 'Refilado' ? Number(item.cantidad_solicitada || 0) : 0;

  return Math.max(base + entradas - salidas, 0);
}

/**
 * Cantidad ya procesada (enviada hacia el siguiente proceso) DENTRO del
 * proceso del rol actual. Junto con calcularPendientePorProceso(), permite
 * mostrar "Procesado"/"Pendiente" específicos del proceso en vez de las
 * cifras globales del ítem (que suman movimientos de TODOS los procesos).
 */
export function calcularProcesadoPorProceso(item, movimientos, proceso) {
  const movimientosDelItem = movimientos.filter((m) => m.item_id === item.item_id);

  return movimientosDelItem
    .filter((m) => m.from_process === proceso)
    .reduce((sum, m) => sum + Number(m.quantity || 0), 0);
}

/**
 * Unidades que han LLEGADO al proceso del rol actual: lo que ya procesó
 * más lo que tiene pendiente. Es la misma cifra que la cartilla ya usa
 * para decidir el badge "completado" — exponerla permite ver que una
 * talla "completada" puede estarlo solo sobre lo recibido hasta ahora.
 */
export function calcularRecibidoPorProceso(item, movimientos, proceso) {
  return calcularPendientePorProceso(item, movimientos, proceso)
    + calcularProcesadoPorProceso(item, movimientos, proceso);
}

/** % recibido sobre lo solicitado, entero y con tope en 100. */
export function porcentajeRecibido(recibido, solicitado) {
  const s = Number(solicitado || 0);
  if (s <= 0) return 0;
  return Math.min(100, Math.round((Number(recibido || 0) / s) * 100));
}
