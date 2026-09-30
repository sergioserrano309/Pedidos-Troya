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
 * Antes había dos modales distintos ("Resumen del Despacho" y "Detalle
 * del Despacho") con casi la misma información ordenada de otra forma.
 * Se unificaron en este, que se lee de arriba abajo como una remesa:
 *   (a) Cliente y totales del despacho (kilos, bultos, unidades)
 *   (b) Ficha de cada pedido: suela, material y color
 *   (c) Fecha de creación
 *   (d) Bultos: número, peso y pedidos que van dentro
 *   (e) Unidades por pedido y talla — UNA matriz para todo el despacho
 *   (f) Resumen por pedido — otra matriz
 *
 * Las dos matrices sustituyen al bloque que se repetía por pedido
 * (tabla de tallas + tres renglones de texto): con cuatro pedidos, esa
 * forma ocupaba una hoja entera para decir lo mismo.
 *
 * El mismo contenido se imprime en PDF (descargarDetalleDespachoPDF),
 * así que no hay una segunda maqueta que mantener en paralelo.
 */

export function inicializarModalDetalleDespacho() {
  document.getElementById('btn-cerrar-detalle-despacho')?.addEventListener('click', cerrarDetalleDespacho);
  document.getElementById('btn-cerrar-detalle-despacho-2')?.addEventListener('click', cerrarDetalleDespacho);
}

export function cerrarDetalleDespacho() {
  document.getElementById('modal-detalle-despacho').classList.remove('open');
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
  const titulo = document.getElementById('detalle-despacho-titulo');
  const contenido = document.getElementById('detalle-despacho-contenido');

  titulo.textContent = `Detalle del Despacho — ${consecutivo || ''}`.trim();
  contenido.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  document.getElementById('modal-detalle-despacho').classList.add('open');

  try {
    const [detalle, asignaciones, bultos, tallasPorPedido] = await Promise.all([
      fetchDetalleDespacho(despachoId),
      fetchAsignacionesDespacho(despachoId),
      fetchBultosDespacho(despachoId),
      fetchItemsDespacho(despachoId)
    ]);

    titulo.textContent = `Detalle del Despacho — ${detalle.consecutivo}`;

    const ordenes = detalle.order_numbers || [];
    // Completitud del PEDIDO sumando todas sus remesas, no solo esta, y
    // la ficha (cliente/suela/material/color) de cada uno.
    const [estadoPorPedido, infoPorPedido] = ordenes.length
      ? await Promise.all([fetchEstadoPedidos(ordenes), fetchInfoPedidos(ordenes)])
      : [new Map(), new Map()];

    // La asignación es de muchos a muchos: un bulto puede llevar varios
    // pedidos y un pedido puede ir repartido en varios bultos. Por eso se
    // arman los dos índices: uno por pedido (para el resumen) y otro por
    // bulto (para la tabla de bultos).
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

    // En teoría un despacho lleva un solo cliente. Si no, no se bloquea
    // nada: se listan todos los nombres distintos que aparezcan.
    const clientes = [...new Set(ordenes.map((o) => infoPorPedido.get(o)?.cliente).filter(Boolean))];

    contenido.innerHTML = `
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
    return String(detalle.consecutivo || consecutivo || '').trim() || null;
  } catch (err) {
    contenido.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    return null;
  }
}

/** [No. Orden]: [Suela] [Material] [Color] */
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
 * Una sola matriz para todo el despacho: un pedido por fila, una talla
 * por columna. Las columnas son la unión de las tallas de TODOS los
 * pedidos, así que la suma de la matriz es el total de pares de la
 * remesa. Las casillas vacías llevan guion, no cero: no es que se
 * hayan despachado cero pares de esa talla, es que esa talla no entra
 * en ese pedido.
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
 * El resumen que antes iba en tres renglones de texto por pedido, ahora
 * en una fila por pedido. "Desp." es el acumulado del PEDIDO sumando
 * todas sus remesas, no lo de esta salida: por eso puede decir 20 de 20
 * aunque en esta salida hayan ido 2.
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
 * Descarga el despacho en PDF. Mismo mecanismo que el Cotizador
 * (propuestaPage.js): se abre el detalle, se manda a imprimir
 * (Ctrl+P → "Guardar como PDF") y la hoja @media print de index.html
 * esconde todo menos esta tarjeta. Sin librerías nuevas y sin una
 * segunda maqueta que se pueda desincronizar de la pantalla.
 *
 * document.title es el nombre de archivo que sugieren casi todos los
 * navegadores: se deja en el consecutivo pelado (D1032) para que el PDF
 * quede nombrado con el ID del despacho, y se restaura al terminar.
 *
 * Los dos esperas de abajo no son adorno, son lo que hace que el nombre
 * sugerido salga bien; están explicadas en su sitio.
 */
export async function descargarDetalleDespachoPDF(despachoId, consecutivo) {
  const consecutivoReal = await abrirDetalleDespacho(despachoId, consecutivo);
  if (!consecutivoReal) return;

  const fechaEl = document.getElementById('detalle-despacho-print-fecha');
  if (fechaEl) {
    fechaEl.textContent = `Impreso el ${new Date().toLocaleDateString('es-CO', {
      day: '2-digit',
      month: 'long',
      year: 'numeric'
    })}`;
  }

  const tituloOriginal = document.title;
  document.title = consecutivoReal;

  // Sin esta clase la hoja sale con páginas en blanco detrás: el resto
  // de la aplicación se esconde con visibility:hidden, que lo vuelve
  // invisible pero NO le quita el espacio que ocupa, así que el
  // documento seguía midiendo lo que mide el listado completo. La clase
  // hace que esos elementos dejen de ocupar lugar mientras se imprime
  // (ver @media print en index.html).
  document.body.classList.add('imprimiendo-despacho');

  const restaurarTitulo = () => {
    window.removeEventListener('afterprint', restaurarTitulo);
    document.body.classList.remove('imprimiendo-despacho');
    // afterprint se dispara cuando se cierra la vista previa, que en
    // Windows es ANTES de que se abra el cuadro "Guardar como" del
    // sistema — y ese cuadro toma de ahí el nombre sugerido. Restaurar
    // de una alcanzaba a borrárselo.
    setTimeout(() => {
      document.title = tituloOriginal;
    }, 2000);
  };
  window.addEventListener('afterprint', restaurarTitulo);

  // El navegador lee el título al generar la vista previa, y el cambio
  // necesita una vuelta del ciclo de eventos para quedar aplicado.
  // Llamar a print() en la misma vuelta dejaba el nombre anterior
  // ("Suelas — Producción").
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
