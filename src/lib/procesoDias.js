/**
 * Cálculo compartido de "cuántos días se demoró cada proceso" (usado por
 * el Excel y por Control Central del Validador) — ver excelService.js
 * para el contexto original de esta lógica.
 */

function obtenerDateObject(fecha) {
  if (!fecha) return null;
  try {
    return new Date(fecha);
  } catch {
    return null;
  }
}

/** Fecha con la hora en cero (solo día) — evita que la hora del
 * movimiento cause un día de diferencia falso al restar fechas. */
export function soloFecha(fecha) {
  const d = obtenerDateObject(fecha);
  if (!d) return null;
  return new Date(d.getFullYear(), d.getMonth(), d.getDate());
}

/** Diferencia en días completos entre dos fechas (solo día, sin hora). */
export function diferenciaDias(fechaInicio, fechaFin) {
  const d1 = soloFecha(fechaInicio);
  const d2 = soloFecha(fechaFin);
  if (!d1 || !d2) return null;
  return Math.round((d2 - d1) / 86400000);
}

/**
 * Última fecha en que cada proceso hizo su ÚLTIMO movimiento de salida,
 * agrupado por orden. Acepta filas de production_movements (sin campo
 * `tipo`) o de vw_historial (con `tipo`, se filtran las devoluciones).
 *
 * Los movimientos automáticos de Refilado (enrutamiento por regla) se
 * excluyen: no son trabajo que Refilado hizo, así que no deben marcar
 * "cuándo Refilado terminó".
 */
export function construirMapaUltimaFechaPorProceso(movimientos) {
  const mapa = {};
  movimientos.forEach((h) => {
    if (h.tipo && h.tipo !== 'movimiento') return;
    if (h.from_process === 'Refilado' && h.observation?.includes('Enrutamiento automático')) return;

    const key = `${h.order_number}|${h.from_process}`;
    const actual = mapa[key];
    if (!actual || new Date(h.created_at) > new Date(actual)) {
      mapa[key] = h.created_at;
    }
  });
  return mapa;
}

/**
 * "No" mientras el proceso no haya despachado el 100% del pedido
 * completo; una vez llega a 100%, la fecha del último movimiento.
 * Devuelve un objeto Date real o 'No'.
 */
export function fechaFinProceso(orden, proceso, porcentajeCampo, mapaUltimaFecha) {
  if ((orden[porcentajeCampo] ?? 0) < 100) return 'No';
  const fecha = mapaUltimaFecha[`${orden.order_number}|${proceso}`];
  return fecha ? soloFecha(fecha) : 'No';
}

/**
 * D_Refilado/Acabado/Mateado/Empaque: días que se demoró CADA proceso,
 * encadenados según el flujo real Refilado -> (Acabado O Mateado) ->
 * Empaque, de forma que sumados dan exactamente "Días O." de la orden:
 *   D_Refilado = fecha entrega Refilado - fecha creación del pedido
 *   D_(Acabado o Mateado, el que aplique) = su fecha entrega - fecha entrega Refilado
 *   D_Empaque = fecha entrega Empaque - fecha entrega del proceso anterior
 *     (Acabado/Mateado, o Refilado si el pedido saltó directo a Empaque)
 * El proceso que la orden NUNCA usó (Acabado si fue a Mateado, o
 * viceversa) queda en 'NA'. Si el proceso aplica pero aún no termina,
 * queda en 'No' (igual que fechaFinProceso).
 */
export function calcularDiasPorProceso(orden, mapaUltimaFecha) {
  const key = (proceso) => `${orden.order_number}|${proceso}`;
  const fRefilado = mapaUltimaFecha[key('Refilado')];
  const fAcabado = mapaUltimaFecha[key('Acabado')];
  const fMateado = mapaUltimaFecha[key('Mateado')];
  const fEmpaque = mapaUltimaFecha[key('Empaque')];

  const refiladoListo = (orden.porcentaje_refilado ?? 0) >= 100 && fRefilado;
  const acabadoListo = (orden.porcentaje_acabado ?? 0) >= 100 && fAcabado;
  const mateadoListo = (orden.porcentaje_mateado ?? 0) >= 100 && fMateado;
  const empaqueListo = (orden.porcentaje_empaque ?? 0) >= 100 && fEmpaque;

  const usoAcabado = (orden.entrada_acabado ?? 0) > 0;
  const usoMateado = (orden.entrada_mateado ?? 0) > 0;

  const dRefilado = refiladoListo ? diferenciaDias(orden.fecha_pedido, fRefilado) : 'No';

  let dAcabado = 'NA';
  if (usoAcabado) {
    dAcabado = (acabadoListo && refiladoListo) ? diferenciaDias(fRefilado, fAcabado) : 'No';
  }

  let dMateado = 'NA';
  if (usoMateado) {
    dMateado = (mateadoListo && refiladoListo) ? diferenciaDias(fRefilado, fMateado) : 'No';
  }

  let dEmpaque = 'No';
  if (empaqueListo) {
    const fechaBase = usoAcabado ? fAcabado : (usoMateado ? fMateado : fRefilado);
    const baseLista = usoAcabado ? acabadoListo : (usoMateado ? mateadoListo : refiladoListo);
    if (baseLista) {
      dEmpaque = diferenciaDias(fechaBase, fEmpaque);
    }
  }

  return { dRefilado, dAcabado, dMateado, dEmpaque };
}
