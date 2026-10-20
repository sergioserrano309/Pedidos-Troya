import { serialExcelDeDia, diaPedidoLocal } from './fechas.js';

/**
 * Inyección (ERP): dato INFORMATIVO que viene directo de Access (columna
 * Total01Iny de p_pedidosh, acumulado por pedido y talla). No es un proceso
 * de la cadena (Refilado → Acabado/Mateado → Empaque → Despacho): no entra
 * en porcentajes, completado, comisiones ni límites de proceso. Solo se
 * muestra al Validador.
 */

/** Primer pedido que interesa: del 1 de agosto en adelante. */
export const PRIMER_PEDIDO_INYECCION = 3095;

/**
 * Desde el paso 4 el Total Inyectado se actualiza solo cada ~5 minutos
 * (tarea de la oficina). Si pasan más de estos minutos sin una corrida, se
 * avisa: la oficina puede estar apagada o la tarea haberse caído.
 */
export const UMBRAL_ALERTA_MINUTOS = 15;

/** "menos de 1 min", "7 min", "1 h 5 min", "3 h", "2 días". */
export function textoDuracion(minutos) {
  const m = Math.max(0, Math.floor(Number(minutos) || 0));
  if (m < 1) return 'menos de 1 min';
  if (m < 60) return `${m} min`;
  if (m < 1440) {
    const h = Math.floor(m / 60);
    const resto = m % 60;
    return resto ? `${h} h ${resto} min` : `${h} h`;
  }
  const d = Math.floor(m / 1440);
  return `${d} ${d === 1 ? 'día' : 'días'}`;
}

/**
 * Qué decirle al Validador sobre la frescura del dato, a partir de la fila
 * única de erp_sync_estado.
 *
 * @param {{ activo?: boolean, ultima_ejecucion?: string, ultimo_resultado?: string }|null} estado
 *   null = no se pudo leer.
 * @param {Date} [ahora]
 * @returns {{ nivel: 'ok'|'alerta'|'desconocido', texto: string, corto: string, ultima: Date|null }}
 *   texto: frase para la pantalla; corto: para el Excel; ultima: hora de la última corrida.
 */
export function estadoSincronizacion(estado, ahora = new Date()) {
  const armar = (nivel, texto, ultima = null) => ({
    nivel,
    texto,
    corto: nivel === 'ok' ? 'Al día' : `ATENCIÓN: ${texto}`,
    ultima
  });

  if (!estado) {
    return armar('desconocido', 'No se pudo verificar la actualización; el dato puede no estar al día');
  }

  const ultimaBruta = estado.ultima_ejecucion ? new Date(estado.ultima_ejecucion) : null;
  const ultima = ultimaBruta && !Number.isNaN(ultimaBruta.getTime()) ? ultimaBruta : null;
  // Un reloj adelantado no debe dar minutos negativos.
  const minutos = ultima ? Math.max(0, Math.floor((ahora.getTime() - ultima.getTime()) / 60000)) : null;

  if (estado.activo === false) {
    return armar('alerta', 'Actualización PAUSADA: el dato quedó congelado', ultima);
  }
  if (!ultima) {
    return armar('alerta', 'Todavía no hay ninguna actualización registrada');
  }
  if (minutos > UMBRAL_ALERTA_MINUTOS) {
    return armar('alerta', `Sin actualizar hace ${textoDuracion(minutos)}: el dato puede estar atrasado`, ultima);
  }

  const resultado = String(estado.ultimo_resultado || '').toLowerCase();
  if (resultado.startsWith('detenido') || resultado === 'pausado') {
    return armar('alerta', `La última actualización se detuvo (${estado.ultimo_resultado}); requiere revisión`, ultima);
  }

  return armar('ok', `Actualizado hace ${textoDuracion(minutos)}`, ultima);
}

/** ¿Este pedido entra en el alcance de Inyección (3095 en adelante)? */
export function aplicaInyeccion(pedido) {
  const texto = String(pedido ?? '').trim();
  if (texto === '') return false;
  const n = Number(texto);
  return Number.isFinite(n) && n >= PRIMER_PEDIDO_INYECCION;
}

/** % inyectado sobre lo solicitado, entero y con tope en 100 (igual que los demás %). */
export function porcentajeInyectado(inyectado, solicitado) {
  const s = Number(solicitado || 0);
  if (s <= 0) return 0;
  return Math.min(100, Math.round((Number(inyectado || 0) / s) * 100));
}

/**
 * Filas de la hoja "Inyección ERP" del Excel: una por línea (pedido x talla
 * x detalle de vira), de más reciente a más antigua. El Detalle Vira se
 * incluye porque un mismo pedido y talla puede venir partido en dos líneas.
 * @param {Array<object>} lineas Líneas de p_pedidosh (ya sin canceladas).
 * @param {object|null} [estado] Fila de erp_sync_estado (null = no se pudo leer).
 */
export function filasInyeccionERP(lineas, estado = null) {
  const info = estadoSincronizacion(estado);
  return [...lineas]
    .sort((a, b) =>
      Number(b.PedidoNo) - Number(a.PedidoNo)
      || String(a.Talla ?? '').localeCompare(String(b.Talla ?? ''), undefined, { numeric: true })
      || String(a.DetalleVira ?? '').localeCompare(String(b.DetalleVira ?? '')))
    .map((l) => ({
      'Orden': l.PedidoNo,
      'Fecha Pedido': l.FechaP ? serialExcelDeDia(diaPedidoLocal(l.FechaP)) : '—',
      'Cliente': l.Cliente || '—',
      'Nombre Suela': l.NombreR || '—',
      'Material': l.MaterialP || '—',
      'Color': l.ColorP || '—',
      'Talla': l.Talla ?? '—',
      'Detalle Vira': l.DetalleVira || '—',
      'Solicitado': l.CantidadP ?? 0,
      'Inyectado': l.Total01Iny ?? 0,
      '% Inyectado': porcentajeInyectado(l.Total01Iny, l.CantidadP),
      'Fuente': 'ERP (Access)',
      // Hora de la última corrida del sincronizador (cuándo se confirmó que
      // este dato coincidía con Access) y si está al día o hay que mirarlo.
      'Actualizado': info.ultima || '—',
      'Estado del dato': info.corto
    }));
}
