import {
  fetchDetalleDespacho,
  fetchAsignacionesDespacho,
  fetchBultosDespacho,
  fetchItemsDespacho,
  fetchEstadoPedidos,
  fetchInfoPedidos
} from '../services/despachosService.js';

/**
 * Modal "Detalle del Despacho", que se abre desde Despachos > Despachado.
 *
 * En pantalla se lee de arriba abajo como una remesa:
 *   (a) Cliente y totales del despacho (kilos, bultos, unidades)
 *   (b) Ficha de cada pedido: suela, material y color (+ Vira/etc Sí/No)
 *   (c) Fecha de creación
 *   (d) Bultos: número, peso y pedidos que van dentro
 *   (e) Unidades por pedido y talla
 *   (f) Resumen por pedido (incluye Desp. y Comp.)
 *
 * La descarga PDF (descargarDetalleDespachoPDF) usa una maqueta de
 * impresión distinta — no altera esta vista ni la lógica de despachos.
 * Ver DOCUMENTACION_TECNICA.md §12.7.
 */

export function inicializarModalDetalleDespacho() {
  document.getElementById('btn-cerrar-detalle-despacho')?.addEventListener('click', cerrarDetalleDespacho);
  document.getElementById('btn-cerrar-detalle-despacho-2')?.addEventListener('click', cerrarDetalleDespacho);
}

export function cerrarDetalleDespacho() {
  const modal = document.getElementById('modal-detalle-despacho');
  modal?.classList.remove('open', 'maqueta-pdf-despacho');
}

/**
 * @param {string} despachoId
 * @param {string} consecutivo Para el título; si no se pasa, se toma del detalle.
 * @returns {Promise<string|null>} el consecutivo tal como quedó en la
 *   base, o null si la carga falló. La descarga en PDF lo usa para dos
 *   cosas: no mandar a la impresora un mensaje de error, y nombrar el
 *   archivo con el ID de verdad y no con el que venía en la tarjeta.
 */
export async function abrirDetalleDespacho(despachoId, consecutivo) {
  const modal = document.getElementById('modal-detalle-despacho');
  const titulo = document.getElementById('detalle-despacho-titulo');
  const contenido = document.getElementById('detalle-despacho-contenido');

  modal.classList.remove('maqueta-pdf-despacho');
  titulo.textContent = `Detalle del Despacho — ${consecutivo || ''}`.trim();
  contenido.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  modal.classList.add('open');

  try {
    const ctx = await cargarContextoDetalle(despachoId);
    titulo.textContent = `Detalle del Despacho — ${ctx.detalle.consecutivo}`;
    contenido.innerHTML = renderContenidoPantalla(ctx);
    return String(ctx.detalle.consecutivo || consecutivo || '').trim() || null;
  } catch (err) {
    contenido.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    return null;
  }
}

/**
 * Carga todo lo que necesitan la vista en pantalla y la maqueta PDF.
 * @param {string} despachoId
 */
async function cargarContextoDetalle(despachoId) {
  const [detalle, asignaciones, bultos, tallasPorPedido] = await Promise.all([
    fetchDetalleDespacho(despachoId),
    fetchAsignacionesDespacho(despachoId),
    fetchBultosDespacho(despachoId),
    fetchItemsDespacho(despachoId)
  ]);

  const ordenes = detalle.order_numbers || [];
  const [estadoPorPedido, infoPorPedido] = ordenes.length
    ? await Promise.all([fetchEstadoPedidos(ordenes), fetchInfoPedidos(ordenes)])
    : [new Map(), new Map()];

  const bultosPorOrden = new Map();
  const ordenesPorBulto = new Map();
  asignaciones.forEach((a) => {
    if (!bultosPorOrden.has(a.order_number)) bultosPorOrden.set(a.order_number, []);
    bultosPorOrden.get(a.order_number).push(a.bulto_numero);

    if (!ordenesPorBulto.has(a.bulto_numero)) ordenesPorBulto.set(a.bulto_numero, []);
    ordenesPorBulto.get(a.bulto_numero).push(a.order_number);
  });

  const bultosDe = (orden) =>
    (bultosPorOrden.get(orden) || []).sort((a, b) => a - b).join(', ') || '—';
  const pedidosDe = (bulto) =>
    (ordenesPorBulto.get(bulto) || []).sort().join(', ') || '—';
  const unidadesDe = (orden) =>
    (tallasPorPedido.get(orden) || []).reduce((sum, t) => sum + t.unidades, 0);

  const pesoTotal = bultos.reduce((sum, b) => sum + Number(b.peso || 0), 0);
  const unidadesTotal = ordenes.reduce((sum, o) => sum + unidadesDe(o), 0);
  const clientes = [...new Set(ordenes.map((o) => infoPorPedido.get(o)?.cliente).filter(Boolean))];

  return {
    detalle,
    bultos,
    tallasPorPedido,
    ordenes,
    estadoPorPedido,
    infoPorPedido,
    bultosDe,
    pedidosDe,
    unidadesDe,
    pesoTotal,
    unidadesTotal,
    clientes
  };
}

function renderContenidoPantalla(ctx) {
  const {
    detalle,
    bultos,
    tallasPorPedido,
    ordenes,
    estadoPorPedido,
    infoPorPedido,
    bultosDe,
    pedidosDe,
    unidadesDe,
    pesoTotal,
    unidadesTotal,
    clientes
  } = ctx;

  return `
    <div class="detalle-despacho-cliente">${clientes.length ? escapeHtml(clientes.join(' · ')) : 'Cliente sin registrar'}</div>

    <div class="detalle-despacho-totales">
      <span class="detalle-despacho-badge">${formatearKilos(pesoTotal)} Kg</span>
      <span class="detalle-despacho-badge">${bultos.length} ${bultos.length === 1 ? 'Bulto' : 'Bultos'}</span>
      <span class="detalle-despacho-badge">${unidadesTotal} ${unidadesTotal === 1 ? 'Unidad' : 'Unidades'}</span>
    </div>

    <div class="form-group">
      <label>Pedidos del despacho</label>
      ${ordenes.map((o) => renderFichaPedido(o, infoPorPedido.get(o))).join('') || '<div class="empty">Sin pedidos.</div>'}
    </div>

    <div class="form-group">
      <label>Fecha de creación</label>
      <div>${formatearFecha(detalle.created_at)}</div>
    </div>

    <div class="form-group">
      <label>Bultos</label>
      <table class="regd-detalle-tabla">
        <thead><tr><th>Bulto</th><th>Peso (kg)</th><th>Pedidos</th></tr></thead>
        <tbody>
          ${bultos
            .map(
              (b) => `<tr>
            <td>${b.bulto_numero}</td>
            <td>${formatearKilos(b.peso)}</td>
            <td>${escapeHtml(pedidosDe(b.bulto_numero))}</td>
          </tr>`
            )
            .join('')}
        </tbody>
      </table>
    </div>

    <div class="form-group">
      <label>Unidades por pedido y talla</label>
      ${renderMatrizTallas(ordenes, tallasPorPedido)}
    </div>

    <div class="form-group">
      <label>Resumen por pedido</label>
      ${renderMatrizPedidos(ordenes, { bultosDe, unidadesDe, estadoPorPedido })}
    </div>
  `;
}

/** [No. Orden]: [Suela] [Material] [Color] + procesos Sí/No (solo pantalla). */
function renderFichaPedido(orden, info) {
  const siNo = (etiqueta, valor) => (valor === undefined ? null : `${etiqueta}: ${valor ? 'Sí' : 'No'}`);
  const atributos = [
    info?.nombreSuela,
    info?.material,
    info?.color,
    siNo('VIRA', info?.vira),
    siNo('ACABADO', info?.acabado),
    siNo('ESTERILLA', info?.esterilla),
    siNo('MARQUILLA', info?.marquilla)
  ].filter(Boolean);
  return `
    <div class="detalle-despacho-ficha">
      <span class="detalle-despacho-ficha-orden">${escapeHtml(orden)}</span>
      <span class="detalle-despacho-ficha-attrs">${atributos.length ? escapeHtml(atributos.join(' · ')) : 'Sin referencia'}</span>
    </div>
  `;
}

/**
 * Ficha para PDF: procesos solo si aplican, y solo el nombre (ej. ACABADO),
 * sin ": Sí" / ": No".
 */
function renderFichaPedidoImpresion(orden, info) {
  const atributos = [
    info?.nombreSuela,
    info?.material,
    info?.color,
    info?.vira ? 'VIRA' : null,
    info?.acabado ? 'ACABADO' : null,
    info?.esterilla ? 'ESTERILLA' : null,
    info?.marquilla ? 'MARQUILLA' : null
  ].filter(Boolean);
  return `
    <div class="detalle-despacho-ficha">
      <span class="detalle-despacho-ficha-orden">${escapeHtml(orden)}</span>
      <span class="detalle-despacho-ficha-attrs">${atributos.length ? escapeHtml(atributos.join(' · ')) : 'Sin referencia'}</span>
    </div>
  `;
}

/**
 * Una sola matriz para todo el despacho: un pedido por fila, una talla
 * por columna. Las columnas son la unión de las tallas de TODOS los
 * pedidos. Las casillas vacías llevan guion, no cero.
 */
function renderMatrizTallas(ordenes, tallasPorPedido) {
  const tallas = [
    ...new Set(ordenes.flatMap((o) => (tallasPorPedido.get(o) || []).map((t) => t.talla)))
  ].sort(compararTallas);

  if (tallas.length === 0) return '<div class="empty">Sin tallas registradas.</div>';

  const filas = ordenes
    .map((orden) => {
      const porTalla = new Map((tallasPorPedido.get(orden) || []).map((t) => [t.talla, t.unidades]));
      const celdas = tallas
        .map((t) => `<td class="col-num">${porTalla.has(t) ? porTalla.get(t) : '<span class="celda-vacia">—</span>'}</td>`)
        .join('');
      return `<tr><td class="celda-pedido">${escapeHtml(orden)}</td>${celdas}</tr>`;
    })
    .join('');

  return `
    <div class="detalle-despacho-matriz">
      <table class="regd-detalle-tabla">
        <thead>
          <tr>
            <th>Pedido / Talla</th>
            ${tallas.map((t) => `<th class="col-num">${escapeHtml(t)}</th>`).join('')}
          </tr>
        </thead>
        <tbody>${filas}</tbody>
      </table>
    </div>
  `;
}

/**
 * Matriz unificada solo para PDF: Pedido | tallas | Und | Bultos.
 * Sin columna Desp. (esa queda en el resumen de pantalla).
 */
function renderMatrizImpresion(ordenes, tallasPorPedido, { bultosDe, unidadesDe }) {
  if (ordenes.length === 0) return '<div class="empty">Sin pedidos.</div>';

  const tallas = [
    ...new Set(ordenes.flatMap((o) => (tallasPorPedido.get(o) || []).map((t) => t.talla)))
  ].sort(compararTallas);

  if (tallas.length === 0) {
    return '<div class="empty">Sin tallas registradas.</div>';
  }

  const filas = ordenes
    .map((orden) => {
      const porTalla = new Map((tallasPorPedido.get(orden) || []).map((t) => [t.talla, t.unidades]));
      const celdas = tallas
        .map((t) => `<td class="col-num">${porTalla.has(t) ? porTalla.get(t) : '<span class="celda-vacia">—</span>'}</td>`)
        .join('');
      return `<tr>
        <td class="celda-pedido">${escapeHtml(orden)}</td>
        ${celdas}
        <td class="col-num">${unidadesDe(orden)}</td>
        <td class="col-num">${escapeHtml(bultosDe(orden))}</td>
      </tr>`;
    })
    .join('');

  return `
    <div class="detalle-despacho-matriz detalle-despacho-matriz-print">
      <table class="regd-detalle-tabla">
        <thead>
          <tr>
            <th>Pedido</th>
            ${tallas.map((t) => `<th class="col-num">${escapeHtml(t)}</th>`).join('')}
            <th class="col-num">Und</th>
            <th class="col-num">Bultos</th>
          </tr>
        </thead>
        <tbody>${filas}</tbody>
      </table>
    </div>
  `;
}

/**
 * Bultos en PDF: 4 columnas fijas BULTO | PESO (KG), relleno fila a fila
 * de izquierda a derecha (1,2,3,4 / 5,6,7,8…). Celdas vacías si sobran.
 */
function renderBultosImpresion(bultos) {
  const COLS = 4;
  const columnas = Array.from({ length: COLS }, () => []);
  bultos.forEach((b, i) => {
    columnas[i % COLS].push(b);
  });
  const filasMax = Math.max(1, ...columnas.map((c) => c.length));

  const colsHtml = columnas
    .map((col) => {
      const filas = [];
      for (let r = 0; r < filasMax; r++) {
        const b = col[r];
        if (b) {
          filas.push(`<tr><td>${b.bulto_numero}</td><td class="col-num">${formatearKilos(b.peso)}</td></tr>`);
        } else {
          filas.push('<tr><td>&nbsp;</td><td class="col-num">&nbsp;</td></tr>');
        }
      }
      return `
        <div class="despacho-print-bultos-col">
          <table class="regd-detalle-tabla">
            <thead><tr><th>Bulto</th><th class="col-num">Peso (kg)</th></tr></thead>
            <tbody>${filas.join('')}</tbody>
          </table>
        </div>`;
    })
    .join('');

  return `<div class="despacho-print-bultos-grid">${colsHtml}</div>`;
}

/**
 * Una copia completa del PDF (sin duplicar aún).
 */
function renderCuerpoImpresion(ctx, fechaImpreso, consecutivo) {
  const {
    detalle,
    bultos,
    tallasPorPedido,
    ordenes,
    infoPorPedido,
    bultosDe,
    unidadesDe,
    pesoTotal,
    unidadesTotal,
    clientes
  } = ctx;

  const clienteTxt = clientes.length ? escapeHtml(clientes.join(' · ')) : 'Cliente sin registrar';
  const labelBultos = `${bultos.length} ${bultos.length === 1 ? 'Bulto' : 'Bultos'}`;
  const labelUnd = `${unidadesTotal} ${unidadesTotal === 1 ? 'Unidad' : 'Unidades'}`;

  return `
    <div class="despacho-print-header despacho-print-header-en-copia">
      <div class="despacho-print-brand">Suelas<span>.</span></div>
      <div class="despacho-print-fecha">${escapeHtml(fechaImpreso)}</div>
    </div>
    <div class="despacho-print-titulo">Detalle del Despacho — ${escapeHtml(consecutivo)}</div>

    <div class="detalle-despacho-print-linea-cliente">
      <span class="detalle-despacho-print-cliente">${clienteTxt}</span>
      <span class="detalle-despacho-print-totales">
        <span>${formatearKilos(pesoTotal)} Kg</span>
        <span>${labelBultos}</span>
        <span>${labelUnd}</span>
      </span>
    </div>

    <div class="form-group form-group-print">
      <label>Pedidos del despacho</label>
      ${ordenes.map((o) => renderFichaPedidoImpresion(o, infoPorPedido.get(o))).join('') || '<div class="empty">Sin pedidos.</div>'}
    </div>

    <div class="form-group form-group-print">
      <label>Fecha de creación</label>
      <div>${formatearFecha(detalle.created_at)}</div>
    </div>

    <div class="form-group form-group-print">
      <label>Bultos</label>
      ${bultos.length ? renderBultosImpresion(bultos) : '<div class="empty">Sin bultos.</div>'}
    </div>

    <div class="form-group form-group-print">
      <label>Unidades por pedido y talla</label>
      ${renderMatrizImpresion(ordenes, tallasPorPedido, { bultosDe, unidadesDe })}
    </div>
  `;
}

/**
 * El resumen que antes iba en tres renglones de texto por pedido, ahora
 * en una fila por pedido. "Desp." es el acumulado del PEDIDO sumando
 * todas sus remesas. Solo se muestra en pantalla (no en el PDF).
 */
function renderMatrizPedidos(ordenes, { bultosDe, unidadesDe, estadoPorPedido }) {
  if (ordenes.length === 0) return '<div class="empty">Sin pedidos.</div>';

  const filas = ordenes
    .map((orden) => {
      const estado = estadoPorPedido.get(orden);
      const despachado = estado
        ? `${estado.despachadas} de ${estado.solicitadas} (${estado.porcentaje}%)`
        : '—';
      return `
        <tr>
          <td class="celda-pedido">${escapeHtml(orden)}</td>
          <td class="col-num">${unidadesDe(orden)}</td>
          <td class="col-num">${escapeHtml(bultosDe(orden))}</td>
          <td class="col-num">${despachado}</td>
          <td class="col-num col-solo-pantalla">${badgeSiNo(estado?.completo ?? false)}</td>
        </tr>
      `;
    })
    .join('');

  return `
    <div class="detalle-despacho-matriz">
      <table class="regd-detalle-tabla">
        <thead>
          <tr>
            <th>Pedido</th>
            <th class="col-num">Unidades</th>
            <th class="col-num">Bultos</th>
            <th class="col-num">Desp.</th>
            <th class="col-num col-solo-pantalla">Comp.</th>
          </tr>
        </thead>
        <tbody>${filas}</tbody>
      </table>
    </div>
  `;
}

/** 35 antes que 36 y que 7A: numérico cuando se puede, texto si no. */
function compararTallas(a, b) {
  return String(a).localeCompare(String(b), undefined, { numeric: true });
}

/**
 * Descarga el despacho en PDF. Mecanismo: window.print → "Guardar como PDF".
 * La maqueta de impresión es independiente del modal en pantalla (cliente
 * + totales en una línea, etapas solo si aplican, bultos en 4 columnas,
 * matriz unificada sin Desp., dos copias con línea de corte).
 *
 * document.title = consecutivo (nombre sugerido del archivo).
 */
export async function descargarDetalleDespachoPDF(despachoId, consecutivo) {
  const modal = document.getElementById('modal-detalle-despacho');
  const titulo = document.getElementById('detalle-despacho-titulo');
  const contenido = document.getElementById('detalle-despacho-contenido');

  titulo.textContent = `Detalle del Despacho — ${consecutivo || ''}`.trim();
  contenido.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  modal.classList.add('open', 'maqueta-pdf-despacho');

  let consecutivoReal;
  try {
    const ctx = await cargarContextoDetalle(despachoId);
    consecutivoReal = String(ctx.detalle.consecutivo || consecutivo || '').trim() || null;
    if (!consecutivoReal) {
      contenido.innerHTML = '<div class="empty">No se pudo identificar el despacho.</div>';
      return;
    }

    titulo.textContent = `Detalle del Despacho — ${consecutivoReal}`;

    const fechaImpreso = `Impreso el ${new Date().toLocaleDateString('es-CO', {
      day: '2-digit',
      month: 'long',
      year: 'numeric'
    })}`;

    const fechaEl = document.getElementById('detalle-despacho-print-fecha');
    if (fechaEl) fechaEl.textContent = fechaImpreso;

    const cuerpo = renderCuerpoImpresion(ctx, fechaImpreso, consecutivoReal);
    contenido.innerHTML = `
      <div class="despacho-print-hoja">
        <div class="despacho-print-copia">${cuerpo}</div>
        <div class="despacho-print-corte" aria-hidden="true"></div>
        <div class="despacho-print-copia">${cuerpo}</div>
      </div>
    `;
  } catch (err) {
    contenido.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    return;
  }

  const tituloOriginal = document.title;
  document.title = consecutivoReal;

  document.body.classList.add('imprimiendo-despacho');

  const restaurarTitulo = () => {
    window.removeEventListener('afterprint', restaurarTitulo);
    document.body.classList.remove('imprimiendo-despacho');
    setTimeout(() => {
      document.title = tituloOriginal;
    }, 2000);
  };
  window.addEventListener('afterprint', restaurarTitulo);

  setTimeout(() => window.print(), 200);
}

function badgeSiNo(valor) {
  const bg = valor ? 'var(--green-bg)' : 'var(--red-bg)';
  const color = valor ? 'var(--green-text)' : 'var(--red-text)';
  return `<span style="background:${bg}; color:${color}; padding:3px 10px; border-radius:5px; font-size:12px; font-weight:600; display:inline-block;">${valor ? 'Sí' : 'No'}</span>`;
}

function formatearFecha(fecha) {
  if (!fecha) return '—';
  try {
    return new Date(fecha).toLocaleDateString('es-CO');
  } catch {
    return String(fecha);
  }
}

/** Kilos sin decimales, igual que en "Crear Salida". */
function formatearKilos(valor) {
  return Math.round(Number(valor || 0)).toLocaleString('es-CO');
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  }[c]));
}
