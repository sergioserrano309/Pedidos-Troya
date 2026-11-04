/**
 * Dashboard de unidades (pares) del Validador: lógica pura, sin pantalla ni
 * base de datos, para poder probarla con datos simulados.
 *
 * Los datos llegan de dos vistas (SQL 084) y aquí se agrupan en el navegador:
 *   - líneas  (vw_dashboard_lineas): una por pedido x talla viva, con
 *     solicitado y despachado hasta hoy.
 *   - despachos (vw_dashboard_despachos): una por despacho x talla, con la
 *     fecha real del despacho.
 *
 * FECHAS — cada medida usa su fecha natural:
 *   Solicitado / Pendiente  -> fecha del PEDIDO (el pendiente no tiene fecha
 *                              de despacho: todavía no salió).
 *   Despachado, "flujo"     -> fecha del DESPACHO (la del PDF), en hora de
 *                              Colombia.
 *   Despachado, "cohorte"   -> fecha del PEDIDO (qué pasó con los pedidos de
 *                              un período).
 * fecha_pedido es una fecha de calendario guardada a medianoche UTC: se lee
 * en UTC (ver fechas.js). La del despacho es un instante real: se lee en
 * America/Bogota.
 */

export const ZONA_DESPACHO = 'America/Bogota';

export const MEDIDAS = {
  solicitado: { etiqueta: 'Solicitado', ayuda: 'Pares pedidos (sin pedidos cancelados en Access).' },
  despachado: { etiqueta: 'Despachado', ayuda: 'Pares que ya salieron en un despacho.' },
  pendiente: { etiqueta: 'Pendiente por despachar', ayuda: 'Solicitado menos despachado, sin pedidos cancelados en Access.' }
};

export const LECTURAS = {
  flujo: { etiqueta: 'Por fecha de despacho', corta: 'Flujo', ayuda: 'Pares que salieron en el período, sin importar de qué pedido son.' },
  cohorte: { etiqueta: 'Por fecha del pedido', corta: 'Por pedido', ayuda: 'Qué pasó con los pares de los pedidos hechos en el período.' }
};

export const DIMENSIONES = {
  cliente: { etiqueta: 'Cliente', tipo: 'texto', campo: 'cliente' },
  nombreSuela: { etiqueta: 'Nombre suela', tipo: 'texto', campo: 'nombre_suela' },
  material: { etiqueta: 'Material', tipo: 'texto', campo: 'material' },
  color: { etiqueta: 'Color', tipo: 'texto', campo: 'color' },
  vira: { etiqueta: 'Vira', tipo: 'si_no', campo: 'vira' },
  acabado: { etiqueta: 'Acabado', tipo: 'si_no', campo: 'acabado' },
  esterilla: { etiqueta: 'Esterilla', tipo: 'si_no', campo: 'esterilla' },
  marquilla: { etiqueta: 'Marquilla', tipo: 'si_no', campo: 'marquilla' },
  mes: { etiqueta: 'Mes', tipo: 'tiempo' },
  dia: { etiqueta: 'Día', tipo: 'tiempo' },
  antiguedad: { etiqueta: 'Antigüedad del pedido', tipo: 'tiempo', soloPendiente: true }
};

const MESES = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const SIN_DATO = '(sin dato)';

// ---------------------------------------------------------------------
// Fechas
// ---------------------------------------------------------------------

/** 'YYYY-MM-DD' de una fecha de calendario guardada a medianoche UTC (fecha_pedido). */
export function diaCalendario(fecha) {
  if (!fecha) return null;
  const d = new Date(fecha);
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().slice(0, 10);
}

const formateadorBogota = new Intl.DateTimeFormat('en-CA', {
  timeZone: ZONA_DESPACHO, year: 'numeric', month: '2-digit', day: '2-digit'
});

/** 'YYYY-MM-DD' del día en Colombia de un instante real (fecha del despacho). */
export function diaColombia(instante) {
  if (!instante) return null;
  const d = new Date(instante);
  if (Number.isNaN(d.getTime())) return null;
  return formateadorBogota.format(d);
}

/** 'oct 2026' a partir de '2026-10'. */
export function etiquetaMes(mes) {
  const [anio, m] = String(mes).split('-');
  return `${MESES[Number(m) - 1] ?? m} ${anio}`;
}

/** '23/10/2026' a partir de '2026-10-23'. */
export function etiquetaDia(dia) {
  const [anio, m, d] = String(dia).split('-');
  return `${d}/${m}/${anio}`;
}

/** Días entre dos 'YYYY-MM-DD' (hoy - pedido), como días de calendario. */
export function diasEntre(desde, hasta) {
  const a = Date.UTC(...desde.split('-').map((v, i) => (i === 1 ? Number(v) - 1 : Number(v))));
  const b = Date.UTC(...hasta.split('-').map((v, i) => (i === 1 ? Number(v) - 1 : Number(v))));
  return Math.round((b - a) / 86400000);
}

/** Rango de antigüedad del pedido (solo para el pendiente). */
export function rangoAntiguedad(dias) {
  if (dias == null || Number.isNaN(dias)) return SIN_DATO;
  if (dias <= 15) return '0-15 días';
  if (dias <= 30) return '16-30 días';
  if (dias <= 60) return '31-60 días';
  return 'Más de 60 días';
}

const ORDEN_ANTIGUEDAD = ['0-15 días', '16-30 días', '31-60 días', 'Más de 60 días', SIN_DATO];

/**
 * Qué fecha lee cada medida, y por qué (para explicárselo al usuario).
 * @returns {{ base: 'pedido'|'despacho', nombre: string, porque: string }}
 */
export function fechaDeLectura(medida, lectura) {
  if (medida === 'despachado' && lectura === 'flujo') {
    return {
      base: 'despacho',
      nombre: 'fecha del despacho',
      porque: 'Estás viendo lo que salió en el período: cuenta el día en que se hizo cada despacho (hora de Colombia), sin importar de qué pedido sea.'
    };
  }
  if (medida === 'despachado') {
    return {
      base: 'pedido',
      nombre: 'fecha del pedido',
      porque: 'Estás viendo qué pasó con los pedidos hechos en el período: cuenta todo lo despachado de esos pedidos, sin importar cuándo salió.'
    };
  }
  if (medida === 'pendiente') {
    return {
      base: 'pedido',
      nombre: 'fecha del pedido',
      porque: 'Lo pendiente todavía no salió, así que no tiene fecha de despacho: se mira por la fecha en que se pidió.'
    };
  }
  return {
    base: 'pedido',
    nombre: 'fecha del pedido',
    porque: 'Lo solicitado se mira por la fecha en que se pidió.'
  };
}

// ---------------------------------------------------------------------
// Preparación de los datos
// ---------------------------------------------------------------------

/**
 * Agrega a cada línea el día del pedido, el pendiente y lo despachado de más.
 * Pendiente = solicitado - despachado, nunca negativo (lo de más se reporta
 * aparte). Un pedido cancelado en Access no cuenta como pendiente.
 * @param {Array<object>} lineas
 * @param {string} hoy 'YYYY-MM-DD' (día en Colombia)
 */
export function prepararLineas(lineas, hoy) {
  return (lineas || []).map((l) => {
    const solicitado = Number(l.solicitado) || 0;
    const despachado = Number(l.despachado) || 0;
    const dia = diaCalendario(l.fecha_pedido);
    return {
      ...l,
      solicitado,
      despachado,
      dia,
      mes: dia ? dia.slice(0, 7) : null,
      antiguedad: dia && hoy ? rangoAntiguedad(diasEntre(dia, hoy)) : SIN_DATO,
      pendiente: l.cancelado_access ? 0 : Math.max(solicitado - despachado, 0),
      deMas: l.cancelado_access ? 0 : Math.max(despachado - solicitado, 0)
    };
  });
}

/** Agrega a cada fila de despacho su día (hora de Colombia) y mes. */
export function prepararDespachos(despachos) {
  return (despachos || []).map((d) => {
    const dia = diaColombia(d.fecha_despacho);
    return {
      ...d,
      cantidad: Number(d.cantidad) || 0,
      dia,
      mes: dia ? dia.slice(0, 7) : null
    };
  });
}

// ---------------------------------------------------------------------
// Filtros y agrupación
// ---------------------------------------------------------------------

export const FILTROS_VACIOS = {
  cliente: '', nombreSuela: '', material: '', color: '',
  vira: '', acabado: '', esterilla: '', marquilla: '',
  estado: '', desde: '', hasta: ''
};

/** ¿La fila (línea o despacho) cumple los filtros? La fecha usada es `fila.dia`. */
export function cumpleFiltros(fila, filtros) {
  const f = { ...FILTROS_VACIOS, ...filtros };
  if (f.cliente && fila.cliente !== f.cliente) return false;
  if (f.nombreSuela && fila.nombre_suela !== f.nombreSuela) return false;
  if (f.material && fila.material !== f.material) return false;
  if (f.color && fila.color !== f.color) return false;
  if (f.vira === 'Si' && !fila.vira) return false;
  if (f.acabado === 'Si' && !fila.acabado) return false;
  if (f.esterilla === 'Si' && !fila.esterilla) return false;
  if (f.marquilla === 'Si' && !fila.marquilla) return false;
  if (f.estado === 'abierto' && fila.cierre_forzado) return false;
  if (f.estado === 'cerrado' && !fila.cierre_forzado) return false;
  if (f.desde || f.hasta) {
    if (!fila.dia) return false;
    if (f.desde && fila.dia < f.desde) return false;
    if (f.hasta && fila.dia > f.hasta) return false;
  }
  return true;
}

function claveDimension(fila, dim) {
  const def = DIMENSIONES[dim];
  if (!def) return SIN_DATO;
  if (dim === 'mes') return fila.mes ?? SIN_DATO;
  if (dim === 'dia') return fila.dia ?? SIN_DATO;
  if (dim === 'antiguedad') return fila.antiguedad ?? SIN_DATO;
  if (def.tipo === 'si_no') return fila[def.campo] ? 'Sí' : 'No';
  const valor = fila[def.campo];
  return valor == null || String(valor).trim() === '' ? SIN_DATO : String(valor);
}

function etiquetaClave(dim, clave) {
  if (clave === SIN_DATO) return clave;
  if (dim === 'mes') return etiquetaMes(clave);
  if (dim === 'dia') return etiquetaDia(clave);
  return clave;
}

/**
 * Fuente y valor de cada medida.
 *   solicitado, pendiente, despachado/cohorte -> líneas (sin cancelados en Access)
 *   despachado/flujo -> despachos (todo lo que físicamente salió)
 */
export function filasDeMedida(medida, lectura, { lineas, despachos }) {
  if (medida === 'despachado' && lectura === 'flujo') {
    return despachos.map((d) => ({ fila: d, valor: d.cantidad }));
  }
  const vivas = lineas.filter((l) => !l.cancelado_access);
  if (medida === 'solicitado') return vivas.map((l) => ({ fila: l, valor: l.solicitado }));
  if (medida === 'pendiente') return vivas.map((l) => ({ fila: l, valor: l.pendiente }));
  return vivas.map((l) => ({ fila: l, valor: l.despachado }));
}

/**
 * Suma una medida agrupada por 0, 1 o 2 dimensiones, ya filtrada.
 * @returns {{ filas: Array<{ claves: string[], etiquetas: string[], valor: number }>, total: number }}
 */
export function agrupar(datos, { medida, lectura, dimensiones = [], filtros = {} }) {
  const dims = dimensiones.filter(Boolean).slice(0, 2);
  const grupos = new Map();
  let total = 0;

  filasDeMedida(medida, lectura, datos).forEach(({ fila, valor }) => {
    if (!cumpleFiltros(fila, filtros)) return;
    total += valor;
    const claves = dims.map((d) => claveDimension(fila, d));
    const llave = claves.join('\u0001');
    const g = grupos.get(llave) || { claves, valor: 0 };
    g.valor += valor;
    grupos.set(llave, g);
  });

  // Los grupos en cero (ej. un cliente sin nada pendiente) no aportan: se ocultan.
  const filas = [...grupos.values()].filter((g) => g.valor > 0).map((g) => ({
    claves: g.claves,
    etiquetas: g.claves.map((c, i) => etiquetaClave(dims[i], c)),
    valor: g.valor
  }));

  const esTiempo = (d) => d === 'mes' || d === 'dia';
  const comparar = (dim, a, b) => {
    if (dim === 'antiguedad') return ORDEN_ANTIGUEDAD.indexOf(a) - ORDEN_ANTIGUEDAD.indexOf(b);
    if (esTiempo(dim)) {
      if (a === SIN_DATO) return 1;
      if (b === SIN_DATO) return -1;
      return a < b ? -1 : a > b ? 1 : 0;
    }
    return String(a).localeCompare(String(b), 'es', { numeric: true });
  };

  filas.sort((a, b) => {
    if (dims.length === 0) return 0;
    // Con tiempo o antigüedad se ordena cronológicamente; si no, de mayor a menor.
    const primeraEsOrden = esTiempo(dims[0]) || dims[0] === 'antiguedad';
    if (primeraEsOrden) {
      const c = comparar(dims[0], a.claves[0], b.claves[0]);
      if (c !== 0) return c;
      if (dims[1]) return esTiempo(dims[1]) || dims[1] === 'antiguedad'
        ? comparar(dims[1], a.claves[1], b.claves[1])
        : b.valor - a.valor;
      return 0;
    }
    if (dims[1] && a.claves[0] === b.claves[0]) {
      return esTiempo(dims[1]) || dims[1] === 'antiguedad'
        ? comparar(dims[1], a.claves[1], b.claves[1])
        : b.valor - a.valor;
    }
    return b.valor - a.valor;
  });

  // Con dos dimensiones sin tiempo, los grupos de la primera se ordenan por su total.
  if (dims.length === 2 && !(esTiempo(dims[0]) || dims[0] === 'antiguedad')) {
    const totales = new Map();
    filas.forEach((f) => totales.set(f.claves[0], (totales.get(f.claves[0]) || 0) + f.valor));
    filas.sort((a, b) => {
      const d = totales.get(b.claves[0]) - totales.get(a.claves[0]);
      if (d !== 0) return d;
      if (a.claves[0] !== b.claves[0]) return String(a.claves[0]).localeCompare(String(b.claves[0]), 'es');
      return esTiempo(dims[1]) || dims[1] === 'antiguedad'
        ? comparar(dims[1], a.claves[1], b.claves[1])
        : b.valor - a.valor;
    });
  }

  return { filas, total };
}

/**
 * Las tres cifras de las tarjetas con los mismos filtros. Cada una lee su
 * fecha natural (ver fechaDeLectura); el despachado sigue la lectura elegida.
 */
export function totalesTarjetas(datos, lectura, filtros) {
  const sumar = (medida) => agrupar(datos, { medida, lectura, dimensiones: [], filtros }).total;
  return {
    solicitado: sumar('solicitado'),
    despachado: sumar('despachado'),
    pendiente: sumar('pendiente')
  };
}

/**
 * Notas que acompañan los números:
 *   deMas: pedidos con más despachado que solicitado (el pendiente de esas líneas cuenta 0).
 *   cancelados: pedidos cancelados en Access que NO entran en solicitado/pendiente.
 */
export function notasDashboard(datos, filtros) {
  const deMasPorPedido = new Map();
  const cancelados = new Map();

  datos.lineas.forEach((l) => {
    if (!cumpleFiltros(l, { ...filtros, desde: '', hasta: '' })) return;
    if (l.cancelado_access) {
      cancelados.set(l.order_number, (cancelados.get(l.order_number) || 0) + l.solicitado);
      return;
    }
    if (l.deMas > 0) {
      deMasPorPedido.set(l.order_number, (deMasPorPedido.get(l.order_number) || 0) + l.deMas);
    }
  });

  const ordenar = (mapa) => [...mapa.entries()]
    .map(([pedido, pares]) => ({ pedido, pares }))
    .sort((a, b) => Number(b.pedido) - Number(a.pedido));

  return { deMas: ordenar(deMasPorPedido), cancelados: ordenar(cancelados) };
}

/** Formato de unidades con punto de miles: 12.345. */
export function formatearPares(valor) {
  return Math.round(Number(valor) || 0).toLocaleString('es-CO');
}
