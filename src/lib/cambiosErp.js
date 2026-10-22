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

/**
 * Texto de la columna Estado. «Rechazado» en la base significa dos cosas
 * distintas para el usuario: el Validador lo DESCARTÓ (✕, "revisado, no se
 * aplica") o lo DESHIZO (↺, tras aplicarlo). Se distingue por el último evento.
 */
export function etiquetaEstado(c) {
  if (c?.estado === 'rechazado') {
    const eventos = Array.isArray(c.historial) ? c.historial : [];
    for (let i = eventos.length - 1; i >= 0; i -= 1) {
      if (eventos[i]?.accion === 'revertido') return 'Deshecho';
      if (eventos[i]?.accion === 'descartado') return 'Descartado';
    }
    return 'Descartado';
  }
  return ETIQUETA_ESTADO[c?.estado] || c?.estado;
}

/** dd/mm/aaaa en hora local; «—» si no hay fecha válida. */
export function formatearDia(valor) {
  if (!valor) return '—';
  const d = new Date(valor);
  return Number.isNaN(d.getTime())
    ? '—'
    : d.toLocaleDateString('es', { day: '2-digit', month: '2-digit', year: 'numeric' });
}

/** Campos de identidad que se cambian por pedido (SQL 077). */
export const CAMPOS_IDENTIDAD = ['MaterialP', 'ColorP', 'Referencia'];

/** Rango de tallas sin el conteo: «34 a 40» (contiguas), «34, 36, 40» o «34». */
export function rangoTallas(tallas) {
  const lista = [...new Set((tallas || []).map((t) => String(t).trim()).filter(Boolean))];
  if (lista.length === 0) return '';
  const numericas = lista.every((t) => Number.isFinite(Number(t)));
  const orden = numericas ? [...lista].sort((a, b) => Number(a) - Number(b)) : [...lista].sort();
  if (orden.length === 1) return orden[0];
  const contiguas = numericas && orden.every((t, i) => i === 0 || Number(t) === Number(orden[i - 1]) + 1);
  return contiguas ? `${orden[0]} a ${orden[orden.length - 1]}` : orden.join(', ');
}

/** «34 a 40 (7 tallas)»; una sola talla: «34». */
export function tallasTexto(tallas) {
  const rango = rangoTallas(tallas);
  const n = new Set((tallas || []).map((t) => String(t).trim()).filter(Boolean)).size;
  return n > 1 ? `${rango} (${n} tallas)` : rango;
}

/**
 * Junta en UNA fila las diferencias de identidad (material, color, referencia)
 * de un mismo pedido, campo, valor nuevo y estado: se aplican, descartan y
 * deshacen juntas (por pedido, no por talla). La fila agrupada es la primera
 * del grupo con: talla = «34 a 40 (7 tallas)», _grupo, _ids, _tallas.
 * Conserva el orden; las demás filas pasan tal cual.
 */
export function agruparIdentidad(cambios) {
  const salida = [];
  const grupos = new Map();
  (cambios || []).forEach((c) => {
    const esIdentidad = c?.tipo === 'identidad' && CAMPOS_IDENTIDAD.includes(c.campo) && c.talla && !c.clave_linea;
    if (!esIdentidad) {
      salida.push(c);
      return;
    }
    const clave = [c.pedido, c.campo, c.valor_access ?? '', c.estado, c.aplicado_at ?? ''].join('|');
    let g = grupos.get(clave);
    if (!g) {
      g = { ...c, _grupo: true, _ids: [], _tallas: [], _actuales: [] };
      grupos.set(clave, g);
      salida.push(g);
    }
    g._ids.push(c.id);
    g._tallas.push(c.talla);
    const actual = c.valor_programa ?? '';
    if (!g._actuales.includes(actual)) g._actuales.push(actual);
  });
  grupos.forEach((g) => {
    g.talla = tallasTexto(g._tallas);
    g.valor_programa = g._actuales.length > 1 ? 'varios valores' : g._actuales[0];
  });
  return salida;
}

/** Campos de texto que el programa puede aplicar solo (lista cerrada, igual que SQL 071). */
export const CAMPOS_APLICABLES = [
  'Cliente', 'Vira', 'DetalleVira', 'Acabado', 'DetalleAcab',
  'Esterilla', 'DetalleEsterilla', 'Marquilla', 'NombreR'
];

/** Interruptores que se pueden encender: los textos y, desde 072, el cierre por cancelación. */
export const INTERRUPTORES = [...CAMPOS_APLICABLES, 'Cancelado'];

/**
 * Se puede deshacer: un cambio de texto ya aplicado (SQL 071) o un cierre por
 * cancelación hecho por el sistema (072) o por el Validador con "Aplicar"
 * (073); reabre el pedido. Un cancelado que "ya estaba cerrado" a mano no se toca.
 */
export function puedeDeshacer(cambio) {
  if (cambio?.estado !== 'aplicado') return false;
  if (cambio?.tipo === 'texto') return CAMPOS_APLICABLES.includes(cambio?.campo);
  if (cambio?.tipo === 'cancelado') return ['automatico', 'validador'].includes(cambio?.aplicado_por);
  if (cambio?.tipo === 'cantidad') return cambio?.aplicado_por === 'validador';
  if (cambio?.tipo === 'linea_sobrante') return cambio?.aplicado_por === 'validador';
  if (cambio?.tipo === 'identidad') return CAMPOS_IDENTIDAD.includes(cambio?.campo) && cambio?.aplicado_por === 'validador';
  return false;
}

/**
 * Botón "Aplicar" (SQL 073/074): un cambio pendiente o descartado que se puede
 * aplicar a mano. Hoy el CANCELADO de un pedido y la CANTIDAD de una talla
 * (una sola línea); la fase 5 agrega los demás con el mismo botón.
 */
export function puedeAplicar(cambio) {
  if (!['pendiente', 'rechazado'].includes(cambio?.estado)) return false;
  if (cambio?.tipo === 'cancelado') return !cambio?.talla;
  if (cambio?.tipo === 'cantidad') return !!cambio?.talla && !cambio?.clave_linea;
  if (cambio?.tipo === 'linea_sobrante') return !!cambio?.talla && !!cambio?.clave_linea;
  if (cambio?.tipo === 'identidad') return CAMPOS_IDENTIDAD.includes(cambio?.campo) && !!cambio?.talla && !cambio?.clave_linea;
  return false;
}

/** Botón "Descartar" (SQL 073): cualquier diferencia pendiente de cualquier tipo. */
export function puedeDescartar(cambio) {
  return cambio?.estado === 'pendiente';
}

/** Último evento del historial con alguna de esas acciones (o null). */
function ultimoEvento(cambio, acciones) {
  const eventos = Array.isArray(cambio?.historial) ? cambio.historial : [];
  for (let i = eventos.length - 1; i >= 0; i -= 1) {
    if (acciones.includes(eventos[i]?.accion)) return eventos[i];
  }
  return null;
}

/** Tipos de cambio que muestran bloqueo e impacto antes de aplicarse (074 y 075). */
export function necesitaImpacto(cambio) {
  return ['cantidad', 'linea_sobrante', 'identidad'].includes(cambio?.tipo);
}

const NOMBRE_ROL = { refilado: 'Refilado', acabado: 'Acabado', mateado: 'Mateado', empaque: 'Empaque' };

/**
 * Cómo se ve la fila: estado de los TRES botones (Aplicar ✓ verde, Descartar ✕
 * rojo, Deshacer ↺ azul) y la etiqueta de quién hizo la acción.
 *   habilitado  se puede pulsar ahora.
 *   activo      es la acción que se tomó (el botón se ve "presionado").
 *   motivo      por qué no se puede pulsar (tooltip).
 *
 * @param {object} c Fila de erp_cambios.
 * @param {object|null|undefined} impacto Resultado de erp_impacto_cambios para
 *   esta fila (solo cantidades): undefined = aún calculando; null = no se pudo.
 */
export function estadoBotones(c, impacto) {
  const boton = (habilitado, motivo = '', activo = false) => ({ habilitado, activo, motivo });
  const nada = 'Solo se puede deshacer un cambio que ya se aplicó.';
  const estado = c?.estado;

  // Aplicar: ¿se puede ahora?
  const aplicarPosible = () => {
    if (!puedeAplicar(c)) return boton(false, 'Este tipo de cambio todavía no se puede aplicar a mano.');
    if (necesitaImpacto(c)) {
      if (impacto === undefined) return boton(false, 'Calculando el impacto…');
      if (impacto === null || !impacto.soportado) return boton(false, 'No se pudo calcular el impacto; no se puede aplicar.');
      if (impacto.bloqueado) return boton(false, impacto.motivo || 'Este cambio está bloqueado.');
    }
    return boton(true, 'Aplicar el cambio');
  };

  if (estado === 'pendiente') {
    return {
      aplicar: aplicarPosible(),
      descartar: boton(true, 'No aplicar (descartar)'),
      deshacer: boton(false, nada),
      chip: null
    };
  }

  if (estado === 'aplicado') {
    const quien = c.aplicado_por === 'automatico' ? 'Automático'
      : c.aplicado_por === 'validador' ? 'Validador' : null;
    return {
      aplicar: boton(false, 'Ya está aplicado', true),
      descartar: boton(false, 'Ya está aplicado: use Deshacer'),
      deshacer: puedeDeshacer(c) ? boton(true, 'Deshacer') : boton(false, 'Este cambio no se puede deshacer desde aquí.'),
      chip: quien
        ? { texto: `Aplicado · ${quien}`, tono: 'verde' }
        : { texto: 'Ya estaba cerrado', tono: 'gris' }
    };
  }

  if (estado === 'rechazado') {
    const hecho = ultimoEvento(c, ['descartado', 'revertido']);
    const deshecho = hecho?.accion === 'revertido';
    return {
      aplicar: aplicarPosible(),
      descartar: boton(false, deshecho ? 'Ya fue deshecho' : 'Ya está descartado', !deshecho),
      deshacer: boton(false, nada, deshecho),
      chip: deshecho
        ? { texto: 'Deshecho · Validador', tono: 'azul' }
        : { texto: 'Descartado · Validador', tono: 'rojo' }
    };
  }

  return {
    aplicar: boton(false, 'Ya no está pendiente'),
    descartar: boton(false, 'Ya no está pendiente'),
    deshacer: boton(false, nada),
    chip: { texto: 'Resuelto', tono: 'gris' }
  };
}

/**
 * Líneas de texto del IMPACTO de aplicar un cambio de cantidad, para el
 * mensaje de confirmación. null si no hay impacto calculado.
 */
export function textoImpacto(c, impacto) {
  if (!impacto?.soportado || impacto.bloqueado) return null;
  if (impacto.tipo === 'identidad') {
    const etiqueta = ETIQUETA_CAMPO[impacto.campo] || impacto.campo;
    const antes = formatearValor(impacto.campo, impacto.actual);
    const n = Number(impacto.n_tallas || 0);
    const precio = (v) => (v === null || v === undefined ? 's/d' : `$${Number(v).toLocaleString('es-CO', { maximumFractionDigits: 2 })}`);
    const lineas = [
      `Pedido ${c.pedido}: ${etiqueta} ${antes === '—' ? '(vacío)' : antes} → ${impacto.nuevo} en ${n} ${n === 1 ? 'talla' : 'tallas'} (${rangoTallas(impacto.tallas)}).`,
      `Registros de producción del pedido: ${impacto.registros} · unidades despachadas: ${impacto.despachadas}.`,
      'Su historial se conserva: el código interno de cada línea no cambia.'
    ];
    const precios = Array.isArray(impacto.precios) ? impacto.precios : [];
    const cambian = precios.filter((p) => String(p.hoy) !== String(p.despues));
    if (cambian.length === 0) {
      lineas.push('Precio por par de los registros nuevos: no cambia en ningún rol.');
    } else {
      lineas.push('Precio por par de los registros NUEVOS (los ya hechos no cambian):');
      cambian.forEach((p) => lineas.push(`  ⚠ ${NOMBRE_ROL[p.rol] || p.rol}: ${precio(p.hoy)} → ${precio(p.despues)}`));
    }
    if (Number(impacto.despachadas) > 0) {
      lineas.push(`⚠ Las fichas y PDF de los despachos de este pedido mostrarán el ${etiqueta.toLowerCase()} nuevo.`);
    }
    if (impacto.cerrado) lineas.push('El pedido está cerrado a la fuerza y seguirá cerrado.');
    return lineas;
  }
  const lineas = [];
  if (impacto.tipo === 'linea_sobrante') {
    lineas.push(`Se oculta la línea de la talla ${c.talla} de ${impacto.cantidad} pares (Access ya no la tiene).`);
    if (impacto.comparte_item) {
      lineas.push(`La talla queda con ${impacto.otras_cantidad} pares (su otra línea, igual que Access) y conserva sus registros de producción.`);
    }
  } else {
    const dif = Number(impacto.nueva) - Number(impacto.actual);
    lineas.push(`Talla ${c.talla}: cantidad ${impacto.actual} → ${impacto.nueva} (${dif >= 0 ? '+' : ''}${dif})`);
  }
  lineas.push(`Total del pedido: ${impacto.total_actual} → ${impacto.total_nuevo}`);
  const si = (v) => (v ? 'Sí' : 'No');
  if (impacto.completo_hoy !== impacto.completo_despues) {
    lineas.push(`Pedido completo: ${si(impacto.completo_hoy)} → ${si(impacto.completo_despues)}`);
  }
  const roles = Array.isArray(impacto.roles) ? impacto.roles : [];
  if (roles.length > 0) {
    lineas.push('Comisiones (trabajo liquidable por rol):');
    roles.forEach((r) => {
      // ⚠ = pierde lo ya liquidable · ↑ = pasa a ser liquidable · • = sin cambio
      const marca = r.liquidable_hoy && !r.liquidable_despues ? '⚠'
        : !r.liquidable_hoy && r.liquidable_despues ? '↑' : '•';
      lineas.push(`  ${marca} ${NOMBRE_ROL[r.rol] || r.rol}: ${si(r.liquidable_hoy)} → ${si(r.liquidable_despues)}`);
    });
  }
  if (impacto.cerrado) lineas.push('El pedido está cerrado a la fuerza y seguirá cerrado.');
  return lineas;
}

/**
 * Aclaración bajo «Qué cambió» para una línea que sobra: qué se quita y qué se
 * queda. null si no aplica o aún no hay datos.
 */
export function infoLineaSobrante(c, impacto) {
  if (c?.tipo !== 'linea_sobrante' || !impacto?.soportado || !impacto.comparte_item) return null;
  return `Esta talla tiene 2 líneas en el programa; Access solo tiene la de ${impacto.otras_cantidad} pares. Sobra esta de ${impacto.cantidad}.`;
}

/**
 * Columnas «En Access» y «En el programa» de una línea que sobra, en unidades
 * por TALLA (como lo piensa quien revisa): si la talla tiene otra línea que sí
 * está en Access, Access tiene esas unidades y el programa esas más las que
 * sobran. Sin dato (o si es la única línea de la talla): «No la tiene» / la cantidad.
 */
export function columnasLineaSobrante(c, impacto) {
  const sobran = Number(c?.valor_programa || 0);
  if (impacto?.soportado && impacto.comparte_item) {
    const otras = Number(impacto.otras_cantidad || 0);
    return { enAccess: `${otras} (toda la talla)`, enPrograma: `${otras + sobran} (${otras} + ${sobran} que sobran)` };
  }
  return { enAccess: 'No la tiene', enPrograma: String(sobran) };
}

/** ¿Aplicar este cambio hará que algún rol pierda lo ya liquidable? */
export function pierdeLiquidacion(impacto) {
  return (impacto?.roles || []).some((r) => r.liquidable_hoy && !r.liquidable_despues);
}

/** Texto de los campos encendidos para el panel: «Cliente, Vira» o «ninguno». */
export function textoCamposEncendidos(campos) {
  if (!Array.isArray(campos)) return null;
  const nombres = campos.filter((c) => INTERRUPTORES.includes(c))
    .map((c) => (c === 'Cancelado' ? 'Cancelados (cierre)' : ETIQUETA_CAMPO[c] || c));
  return nombres.length ? nombres.join(', ') : 'ninguno';
}

/**
 * Frase del historial de un cambio ya aplicado o deshecho (nota gris del
 * pedido). null si el estado no es de historial.
 */
export function descripcionHistorial(c) {
  if (c.tipo === 'cancelado') {
    if (c.estado === 'aplicado') {
      if (c.aplicado_por === 'automatico') {
        return `Cancelado en Access: el pedido se cerró a la fuerza el ${formatearDia(c.aplicado_at)} (Cancelado en Troya)`;
      }
      if (c.aplicado_por === 'validador') {
        return `Cancelado en Access: el Validador cerró el pedido a la fuerza el ${formatearDia(c.aplicado_at)} (Cancelado en Troya)`;
      }
      return 'Cancelado en Access: el pedido ya estaba cerrado a la fuerza';
    }
    if (c.estado === 'rechazado') {
      return 'Access lo tiene cancelado, pero el Validador decidió no aplicarlo';
    }
    return null;
  }
  if (c.tipo === 'linea_sobrante') {
    const pares = formatearValor('', c.valor_programa);
    if (c.estado === 'aplicado') {
      return `Talla ${c.talla}: la línea de ${pares} pares que Access ya no tenía se ocultó el ${formatearDia(c.aplicado_at)}`;
    }
    if (c.estado === 'rechazado') {
      return `Talla ${c.talla}: Access ya no tiene la línea de ${pares} pares, pero el Validador decidió mantenerla`;
    }
    return null;
  }
  const etiqueta = ETIQUETA_CAMPO[c.campo] || c.campo || 'Dato';
  const antes = formatearValor(c.campo, c.valor_programa);
  const ahora = formatearValor(c.campo, c.valor_access);
  const talla = c._grupo ? '' : (c.talla ? `Talla ${c.talla}: ` : '');
  const tallas = c._grupo ? ` (tallas ${c.talla})` : '';
  if (c.estado === 'aplicado') {
    return `${talla}${etiqueta} cambiado el ${formatearDia(c.aplicado_at)} desde Access: ${antes} → ${ahora}${tallas}`;
  }
  if (c.estado === 'rechazado') {
    return `${talla}Access tiene ${etiqueta} ${ahora}, pero el Validador mantuvo ${antes}${tallas}`;
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
      return c.contexto?.completo
        ? 'El pedido fue cancelado en Access, pero ya está completo: no se cierra solo, se revisa a mano'
        : 'El pedido fue cancelado en Access';
    case 'cancelado_parcial':
      return `${talla || 'Una línea'} fue cancelada en Access`;
    case 'linea_nueva':
      return `Línea nueva en Access: ${talla || 'sin talla'} × ${formatearValor('', c.valor_access)}`;
    case 'linea_sobrante':
      return `Sobra una línea en el programa: ${talla || 'sin talla'} × ${formatearValor('', c.valor_programa)} pares (Access no la tiene)`;
    case 'cantidad':
      return `${talla}: cantidad ${antes()} → ${ahora()}`;
    default:
      if (c._grupo) return `${etiqueta} ${antes()} → ${ahora()} · Tallas ${c.talla}`;
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
export function resumenNota(cambiosCrudos, maxLineas = 6) {
  const cambios = agruparIdentidad(cambiosCrudos);
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

/**
 * Texto de la insignia roja de la pestaña «Cambios ERP»: el número de PEDIDOS
 * con cambios pendientes de revisar. '' = no se muestra (0 o dato inválido);
 * más de 99 se muestra «99+».
 */
export function textoInsignia(pedidos) {
  const n = Math.floor(Number(pedidos));
  if (!Number.isFinite(n) || n <= 0) return '';
  return n > 99 ? '99+' : String(n);
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
        'En Access': c.tipo === 'cancelado' || c.tipo === 'cancelado_parcial' ? 'Cancelado'
          : c.tipo === 'linea_sobrante' ? 'No la tiene'
            : formatearValor(c.campo, c.valor_access),
        'En el programa': c.tipo === 'cancelado' || c.tipo === 'cancelado_parcial' ? 'Activo'
          : c.tipo === 'linea_nueva' ? 'No la tiene'
            : formatearValor(c.campo, c.valor_programa),
        'Descripción': descripcionCambio(c),
        'Estado': etiquetaEstado(c),
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
