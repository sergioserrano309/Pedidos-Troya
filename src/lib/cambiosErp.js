import { estadoSincronizacion } from './inyeccion.js';

/**
 * Cambios de Access (Fase 1): diferencias que el detector (Detectar_Cambios.py)
 * encontró entre Access y el programa y registró en erp_cambios. En esta fase
 * SOLO se muestran: ninguna modifica el pedido.
 *
 * Cada fila de erp_cambios: { id, pedido, talla, tipo, campo, clave_linea,
 * valor_access, valor_programa, ambiguo, estado, detectado_at,
 * ultima_revision_at, revisiones_consecutivas, resuelto_at, contexto }.
 */

export const ETIQUETA_CAMPO = {
  Cliente: 'Cliente',
  Vira: 'Vira',
  DetalleVira: 'Detalle de vira',
  Acabado: 'Acabado',
  DetalleAcab: 'Detalle de acabado',
  Esterilla: 'Esterilla',
  DetalleEsterilla: 'Detalle de esterilla',
  Marquilla: 'Marquilla',
  NombreR: 'Nombre de la suela',
  Referencia: 'Referencia',
  MaterialP: 'Material',
  ColorP: 'Color',
  CantidadP: 'Cantidad',
  Cancelado: 'Cancelado'
};

export const ETIQUETA_TIPO = {
  texto: 'Dato del pedido',
  identidad: 'Referencia / material / color',
  cantidad: 'Cantidad',
  cancelado: 'Pedido cancelado',
  cancelado_parcial: 'Talla cancelada',
  linea_nueva: 'Talla o línea nueva',
  linea_sobrante: 'Talla o línea que ya no está'
};

export const ETIQUETA_ESTADO = {
  pendiente: 'Pendiente',
  aplicado: 'Aplicado',
  rechazado: 'Deshecho',
  resuelto: 'Resuelto'
};

/** dd/mm/aaaa en hora local; «—» si no hay fecha válida. */
export function formatearDia(valor) {
  if (!valor) return '—';
  const d = new Date(valor);
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleDateString('es', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

/** Campos de texto que el programa puede aplicar solo (lista cerrada, igual que SQL 071). */
export const CAMPOS_APLICABLES = [
  'Cliente', 'Vira', 'DetalleVira', 'Acabado', 'DetalleAcab',
  'Esterilla', 'DetalleEsterilla', 'Marquilla', 'NombreR'
];

/** Solo un cambio de texto ya aplicado se puede deshacer (SQL 071). */
export function puedeDeshacer(cambio) {
  return cambio?.estado === 'aplicado' && cambio?.tipo === 'texto'
    && CAMPOS_APLICABLES.includes(cambio?.campo);
}

/** Texto de los campos encendidos para el panel: «Cliente, Vira» o «ninguno». */
export function textoCamposEncendidos(campos) {
  if (!Array.isArray(campos)) return null;
  const nombres = campos.filter((c) => CAMPOS_APLICABLES.includes(c)).map((c) => ETIQUETA_CAMPO[c] || c);
  return nombres.length ? nombres.join(', ') : 'ninguno';
}

/**
 * Frase del historial de un cambio ya aplicado o deshecho (nota gris del
 * pedido). null si el estado no es de historial.
 */
export function descripcionHistorial(c) {
  const etiqueta = ETIQUETA_CAMPO[c.campo] || c.campo || 'Dato';
  const antes = formatearValor(c.campo, c.valor_programa);
  const ahora = formatearValor(c.campo, c.valor_access);
  const talla = c.talla ? `Talla ${c.talla}: ` : '';
  if (c.estado === 'aplicado') {
    return `${talla}${etiqueta} cambiado el ${formatearDia(c.aplicado_at)} desde Access: ${antes} → ${ahora}`;
  }
  if (c.estado === 'rechazado') {
    return `${talla}Access tiene ${etiqueta} ${ahora}, pero el Validador mantuvo ${antes}`;
  }
  return null;
}

const CAMPOS_SI_NO = new Set(['Vira', 'Acabado', 'Esterilla', 'Marquilla', 'Cancelado']);

/** 'TRUE'/'FALSE' → Sí/No en los campos de casilla; vacío → «—». */
export function formatearValor(campo, valor) {
  if (valor === null || valor === undefined || String(valor).trim() === '') return '—';
  if (CAMPOS_SI_NO.has(campo)) {
    const v = String(valor).trim().toUpperCase();
    if (v === 'TRUE') return 'Sí';
    if (v === 'FALSE') return 'No';
  }
  return String(valor).trim();
}

/** ¿Es un cambio de tallas/unidades? (los que llevan el aviso de unidades procesadas) */
export function esCambioDeUnidades(cambio) {
  return ['cantidad', 'linea_nueva', 'linea_sobrante', 'cancelado_parcial'].includes(cambio?.tipo);
}

/** Frase legible de una diferencia, para la nota, el panel y el Excel. */
export function descripcionCambio(c) {
  const talla = c.talla ? `Talla ${c.talla}` : '';
  const etiqueta = ETIQUETA_CAMPO[c.campo] || c.campo || '';
  const antes = () => formatearValor(c.campo, c.valor_programa);
  const ahora = () => formatearValor(c.campo, c.valor_access);

  switch (c.tipo) {
    case 'cancelado':
      return 'El pedido fue cancelado en Access';
    case 'cancelado_parcial':
      return `${talla || 'Una línea'} fue cancelada en Access`;
    case 'linea_nueva':
      return `Línea nueva en Access: ${talla || 'sin talla'} × ${formatearValor('', c.valor_access)}`;
    case 'linea_sobrante':
      return `La línea ya no está en Access: ${talla || 'sin talla'} × ${formatearValor('', c.valor_programa)}`;
    case 'cantidad':
      return `${talla}: cantidad ${antes()} → ${ahora()}`;
    default:
      return `${talla ? `${talla}: ` : ''}${etiqueta} ${antes()} → ${ahora()}`;
  }
}

/** Solo lo que sigue sin resolver (lo que importa para la nota). */
export function cambiosPendientes(cambios) {
  return (cambios || []).filter((c) => c.estado === 'pendiente');
}

/**
 * Mensaje de unidades para la nota del pedido. null si no hay cambios de
 * tallas/unidades pendientes. "Unidades procesadas" = movimientos hechos por
 * personas en todo el pedido (el detector no cuenta los automáticos).
 */
export function mensajeUnidades(cambios) {
  const deUnidades = cambiosPendientes(cambios).filter(esCambioDeUnidades);
  if (deUnidades.length === 0) return null;
  const conProcesadas = deUnidades.some((c) => Number(c.contexto?.movimientos || 0) > 0);
  return conProcesadas
    ? 'Cambio de tallas/unidades después de unidades procesadas'
    : 'Cambio de tallas/unidades sin unidades procesadas';
}

/**
 * Lo que muestra la nota del detalle de la orden: las diferencias pendientes
 * (ámbar), con tope de líneas visibles, y el mensaje de unidades.
 * @returns {{ lineas: string[], extra: number, mensaje: string|null, hayAmbiguos: boolean }|null}
 *   null = no hay nada pendiente: no se muestra nota.
 */
export function resumenNota(cambios, maxLineas = 6) {
  const pendientes = cambiosPendientes(cambios);
  // Historial permanente (nota gris): lo ya aplicado y lo que el Validador deshizo.
  const historial = (cambios || [])
    .filter((c) => c.estado === 'aplicado' || c.estado === 'rechazado')
    .sort((a, b) => new Date(b.aplicado_at || b.ultima_revision_at || 0) - new Date(a.aplicado_at || a.ultima_revision_at || 0))
    .map(descripcionHistorial)
    .filter(Boolean);
  if (pendientes.length === 0 && historial.length === 0) return null;
  const orden = { cancelado: 0, cancelado_parcial: 1, cantidad: 2, linea_nueva: 3, linea_sobrante: 4, identidad: 5, texto: 6 };
  const ordenadas = [...pendientes].sort((a, b) =>
    (orden[a.tipo] ?? 9) - (orden[b.tipo] ?? 9)
    || String(a.talla ?? '').localeCompare(String(b.talla ?? ''), undefined, { numeric: true }));
  return {
    lineas: ordenadas.slice(0, maxLineas).map(descripcionCambio),
    extra: Math.max(0, ordenadas.length - maxLineas),
    mensaje: mensajeUnidades(pendientes),
    hayAmbiguos: ordenadas.some((c) => c.ambiguo),
    historial: historial.slice(0, maxLineas),
    historialExtra: Math.max(0, historial.length - maxLineas)
  };
}

/** Cuántas diferencias pendientes tiene cada pedido: Map<pedido, number>. */
export function contarPendientesPorPedido(cambios) {
  const mapa = new Map();
  cambiosPendientes(cambios).forEach((c) => {
    const p = String(c.pedido);
    mapa.set(p, (mapa.get(p) || 0) + 1);
  });
  return mapa;
}

/** Contadores del panel: pendientes, resueltas y por tipo (solo pendientes). */
export function contadoresPanel(cambios) {
  const r = { pendientes: 0, resueltos: 0, aplicados: 0, pedidos: 0, porTipo: {} };
  const pedidos = new Set();
  (cambios || []).forEach((c) => {
    if (c.estado === 'pendiente') {
      r.pendientes += 1;
      pedidos.add(String(c.pedido));
      r.porTipo[c.tipo] = (r.porTipo[c.tipo] || 0) + 1;
    } else if (c.estado === 'resuelto') {
      r.resueltos += 1;
    } else if (c.estado === 'aplicado') {
      r.aplicados += 1;
    }
  });
  r.pedidos = pedidos.size;
  return r;
}

/** Estado del detector (misma forma que erp_sync_estado, mismo criterio de frescura). */
export function estadoDetector(estado, ahora = new Date()) {
  return estadoSincronizacion(estado, ahora);
}

function aFechaExcel(valor) {
  if (!valor) return '—';
  const d = new Date(valor);
  return Number.isNaN(d.getTime()) ? '—' : d;
}

/**
 * Filas de la hoja "Cambios ERP" del Excel: todas las diferencias (también
 * las resueltas, como historial), de la más reciente a la más antigua.
 */
export function filasCambiosERP(cambios) {
  return [...(cambios || [])]
    .sort((a, b) => new Date(b.detectado_at || 0) - new Date(a.detectado_at || 0)
      || Number(b.pedido) - Number(a.pedido))
    .map((c) => {
      const movimientos = Number(c.contexto?.movimientos || 0);
      return {
        'Orden': Number.isFinite(Number(c.pedido)) ? Number(c.pedido) : c.pedido,
        'Talla': c.talla || '—',
        'Tipo': ETIQUETA_TIPO[c.tipo] || c.tipo,
        'Campo': ETIQUETA_CAMPO[c.campo] || c.campo || '—',
        'En Access': c.tipo === 'cancelado' || c.tipo === 'cancelado_parcial' ? 'Cancelado' : formatearValor(c.campo, c.valor_access),
        'En el programa': c.tipo === 'cancelado' || c.tipo === 'cancelado_parcial' ? 'Activo' : formatearValor(c.campo, c.valor_programa),
        'Descripción': descripcionCambio(c),
        'Estado': ETIQUETA_ESTADO[c.estado] || c.estado,
        'Detectado': aFechaExcel(c.detectado_at),
        'Última revisión': aFechaExcel(c.ultima_revision_at),
        'Revisiones iguales seguidas': c.revisiones_consecutivas ?? 0,
        'Resuelto': aFechaExcel(c.resuelto_at),
        'Aplicado': aFechaExcel(c.aplicado_at),
        'Aplicado por': c.aplicado_por || '—',
        'Movimientos de personas': movimientos,
        'Despachos': Number(c.contexto?.despachos || 0),
        'Pedido completo': c.contexto?.completo ? 'Sí' : 'No',
        'Cerrado a la fuerza': c.contexto?.cerrado ? 'Sí' : 'No',
        'Ambiguo': c.ambiguo ? 'Sí' : 'No'
      };
    });
}
