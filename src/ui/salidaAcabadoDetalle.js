import {
  fetchDetalleSalida,
  fetchAsignacionesSalida,
  fetchBultosSalida,
  fetchItemsSalida,
  editarComentarioSalida
} from '../services/salidasAcabadoService.js';
import { fetchInfoPedidos } from '../services/despachosService.js';
import { esValidador } from '../services/validatorService.js';
import { mostrarToast } from './toast.js';
import { elegirEnApp } from './confirmModal.js';

/**
 * Detalle y PDF de una salida de Acabado (Salidas(A) > Salida).
 *
 * Reutiliza la MISMA ventana (#modal-detalle-despacho) y los mismos estilos de
 * impresión que el detalle de Despachos — solo cambia el contenido y los
 * textos —, así el PDF queda idéntico en formato. Las funciones de pintado son
 * copias adaptadas de despachoDetalleModal.js (que no se toca): sin
 * estado de despacho por pedido, sin factura ni "Comp.".
 *
 * El PDF es el mismo mecanismo: window.print → "Guardar como PDF".
 */

/** Se dispara al guardar el comentario: la lista de "Salida" se vuelve a leer. */
export const EVENTO_SALIDA_ACTUALIZADA = 'salida-a-actualizada';

/**
 * Entrada del botón ↓ de la lista. Si la salida tiene comentario, se pregunta si se
 * incluye en el PDF (ventana dentro del programa); si no, se imprime directo.
 */
export async function solicitarDescargaSalidaPDF(salidaId, consecutivo, opciones = {}) {
  if (!opciones.tieneComentario) {
    descargarSalidaPDF(salidaId, consecutivo, { incluirComentario: true });
    return;
  }

  const eleccion = await elegirEnApp({
    titulo: 'Descargar PDF',
    detalle: 'Esta salida tiene un comentario. Elige si quieres incluirlo en el PDF.',
    opciones: [
      { valor: 'sin', texto: 'Sin comentario', estilo: 'secondary' },
      { valor: 'con', texto: 'Con comentario', estilo: 'primary' }
    ]
  });
  if (!eleccion) return;
  descargarSalidaPDF(salidaId, consecutivo, { incluirComentario: eleccion === 'con' });
}

/** Detalle en pantalla (solo lectura; el Validador puede editar el comentario). */
export async function abrirDetalleSalida(salidaId, consecutivo) {
  const modal = document.getElementById('modal-detalle-despacho');
  const titulo = document.getElementById('detalle-despacho-titulo');
  const contenido = document.getElementById('detalle-despacho-contenido');

  modal.classList.remove('maqueta-pdf-despacho');
  titulo.textContent = `Detalle de la Salida — ${consecutivo || ''}`.trim();
  contenido.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  modal.classList.add('open');

  try {
    const ctx = await cargarContextoDetalle(salidaId);
    titulo.textContent = `Detalle de la Salida — ${ctx.detalle.consecutivo}`;
    contenido.innerHTML = renderContenidoPantalla(ctx);
    enlazarEdicionComentario(salidaId, ctx.detalle.comentario);
  } catch (err) {
    contenido.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
  }
}

async function cargarContextoDetalle(salidaId) {
  const [detalle, asignaciones, bultos, tallasPorPedido] = await Promise.all([
    fetchDetalleSalida(salidaId),
    fetchAsignacionesSalida(salidaId),
    fetchBultosSalida(salidaId),
    fetchItemsSalida(salidaId)
  ]);

  const ordenes = detalle.order_numbers || [];
  const infoPorPedido = ordenes.length ? await fetchInfoPedidos(ordenes) : new Map();

  const bultosPorOrden = new Map();
  const ordenesPorBulto = new Map();
  asignaciones.forEach((a) => {
    if (!bultosPorOrden.has(a.order_number)) bultosPorOrden.set(a.order_number, []);
    bultosPorOrden.get(a.order_number).push(a.bulto_numero);
    if (!ordenesPorBulto.has(a.bulto_numero)) ordenesPorBulto.set(a.bulto_numero, []);
    ordenesPorBulto.get(a.bulto_numero).push(a.order_number);
  });

  const bultosDe = (orden) => (bultosPorOrden.get(orden) || []).sort((a, b) => a - b).join(', ') || '—';
  const pedidosDe = (bulto) => (ordenesPorBulto.get(bulto) || []).sort().join(', ') || '—';
  const unidadesDe = (orden) => (tallasPorPedido.get(orden) || []).reduce((sum, t) => sum + t.unidades, 0);

  const pesoTotal = bultos.reduce((sum, b) => sum + Number(b.peso || 0), 0);
  const unidadesTotal = ordenes.reduce((sum, o) => sum + unidadesDe(o), 0);
  const clientes = [...new Set(ordenes.map((o) => infoPorPedido.get(o)?.cliente).filter(Boolean))];

  return {
    detalle, bultos, tallasPorPedido, ordenes, infoPorPedido,
    bultosDe, pedidosDe, unidadesDe, pesoTotal, unidadesTotal, clientes
  };
}

function renderContenidoPantalla(ctx) {
  const { detalle, bultos, tallasPorPedido, ordenes, infoPorPedido, bultosDe, pedidosDe, unidadesDe, pesoTotal, unidadesTotal, clientes } = ctx;

  return `
    <div class="detalle-despacho-cliente">${clientes.length ? escapeHtml(clientes.join(' · ')) : 'Cliente sin registrar'}</div>

    <div class="detalle-despacho-totales">
      <span class="detalle-despacho-badge">${formatearKilos(pesoTotal)} Kg</span>
      <span class="detalle-despacho-badge">${bultos.length} ${bultos.length === 1 ? 'Bulto' : 'Bultos'}</span>
      <span class="detalle-despacho-badge">${unidadesTotal} ${unidadesTotal === 1 ? 'Unidad' : 'Unidades'}</span>
    </div>

    <div class="form-group">
      <label>Pedidos de la salida</label>
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
          ${bultos.map((b) => `<tr>
            <td>${b.bulto_numero}</td>
            <td>${formatearKilos(b.peso)}</td>
            <td>${escapeHtml(pedidosDe(b.bulto_numero))}</td>
          </tr>`).join('')}
        </tbody>
      </table>
    </div>

    <div class="form-group">
      <label>Unidades por pedido y talla</label>
      ${renderMatrizTallas(ordenes, tallasPorPedido)}
    </div>

    <div class="form-group">
      <label>Resumen por pedido</label>
      ${renderMatrizPedidos(ordenes, { bultosDe, unidadesDe })}
    </div>
    ${esValidador() ? renderComentarioEditable(detalle.comentario) : renderComentario(detalle.comentario, 'form-group')}
  `;
}

function renderComentario(comentario, clasesGrupo) {
  const texto = String(comentario ?? '').trim();
  if (!texto) return '';
  return `
    <div class="${clasesGrupo}">
      <label>Comentarios</label>
      <div class="detalle-despacho-comentario">${escapeHtml(texto)}</div>
    </div>`;
}

function renderComentarioEditable(comentario) {
  const texto = String(comentario ?? '');
  return `
    <div class="form-group">
      <label for="detalle-salida-a-comentario-input">Comentarios</label>
      <textarea id="detalle-salida-a-comentario-input" maxlength="255" rows="3"
        placeholder="Sin comentario. Escribe aquí lo que quieras dejar anotado sobre esta salida.">${escapeHtml(texto)}</textarea>
      <div class="detalle-despacho-comentario-pie">
        <span id="detalle-salida-a-comentario-contador" class="crear-despacho-contador">${texto.length} / 255</span>
        <button type="button" class="btn btn-primary btn-sm" id="detalle-salida-a-comentario-guardar" disabled>Guardar comentario</button>
      </div>
    </div>`;
}

function enlazarEdicionComentario(salidaId, comentarioInicial) {
  const campo = document.getElementById('detalle-salida-a-comentario-input');
  const boton = document.getElementById('detalle-salida-a-comentario-guardar');
  const contador = document.getElementById('detalle-salida-a-comentario-contador');
  if (!campo || !boton) return;

  let guardado = String(comentarioInicial ?? '').trim();

  const sincronizar = () => {
    if (contador) contador.textContent = `${campo.value.length} / ${campo.maxLength}`;
    boton.disabled = campo.value.trim() === guardado;
  };
  campo.addEventListener('input', sincronizar);

  boton.addEventListener('click', async () => {
    const nuevo = campo.value.trim();
    if (nuevo === guardado) return;

    boton.disabled = true;
    campo.disabled = true;
    try {
      await editarComentarioSalida(salidaId, nuevo);
      guardado = nuevo;
      campo.value = nuevo;
      mostrarToast(nuevo ? 'Comentario guardado.' : 'Comentario eliminado.', 'ok');
      document.dispatchEvent(new CustomEvent(EVENTO_SALIDA_ACTUALIZADA));
    } catch (err) {
      mostrarToast(err.message, 'error');
    } finally {
      campo.disabled = false;
      sincronizar();
    }
  });
}

function renderFichaPedido(orden, info) {
  const siNo = (etiqueta, valor) => (valor === undefined ? null : `${etiqueta}: ${valor ? 'Sí' : 'No'}`);
  const atributos = [
    info?.nombreSuela, info?.material, info?.color,
    siNo('VIRA', info?.vira), siNo('ACABADO', info?.acabado),
    siNo('ESTERILLA', info?.esterilla), siNo('MARQUILLA', info?.marquilla)
  ].filter(Boolean);
  return `
    <div class="detalle-despacho-ficha">
      <span class="detalle-despacho-ficha-orden">${escapeHtml(orden)}</span>
      <span class="detalle-despacho-ficha-attrs">${atributos.length ? escapeHtml(atributos.join(' · ')) : 'Sin referencia'}</span>
    </div>`;
}

function renderFichaPedidoImpresion(orden, info) {
  const atributos = [
    info?.nombreSuela, info?.material, info?.color,
    info?.vira ? 'VIRA' : null, info?.acabado ? 'ACABADO' : null,
    info?.esterilla ? 'ESTERILLA' : null, info?.marquilla ? 'MARQUILLA' : null
  ].filter(Boolean);
  return `
    <div class="detalle-despacho-ficha">
      <span class="detalle-despacho-ficha-orden">${escapeHtml(orden)}</span>
      <span class="detalle-despacho-ficha-attrs">${atributos.length ? escapeHtml(atributos.join(' · ')) : 'Sin referencia'}</span>
    </div>`;
}

function unirTallas(ordenes, tallasPorPedido) {
  return [...new Set(ordenes.flatMap((o) => (tallasPorPedido.get(o) || []).map((t) => t.talla)))]
    .sort((a, b) => String(a).localeCompare(String(b), undefined, { numeric: true }));
}

function renderMatrizTallas(ordenes, tallasPorPedido) {
  const tallas = unirTallas(ordenes, tallasPorPedido);
  if (tallas.length === 0) return '<div class="empty">Sin tallas registradas.</div>';

  const filas = ordenes.map((orden) => {
    const porTalla = new Map((tallasPorPedido.get(orden) || []).map((t) => [t.talla, t.unidades]));
    const celdas = tallas
      .map((t) => `<td class="col-num">${porTalla.has(t) ? porTalla.get(t) : '<span class="celda-vacia">—</span>'}</td>`)
      .join('');
    return `<tr><td class="celda-pedido">${escapeHtml(orden)}</td>${celdas}</tr>`;
  }).join('');

  return `
    <div class="detalle-despacho-matriz">
      <table class="regd-detalle-tabla">
        <thead><tr><th>Pedido / Talla</th>${tallas.map((t) => `<th class="col-num">${escapeHtml(t)}</th>`).join('')}</tr></thead>
        <tbody>${filas}</tbody>
      </table>
    </div>`;
}

function renderMatrizImpresion(ordenes, tallasPorPedido, { bultosDe, unidadesDe }) {
  if (ordenes.length === 0) return '<div class="empty">Sin pedidos.</div>';
  const tallas = unirTallas(ordenes, tallasPorPedido);
  if (tallas.length === 0) return '<div class="empty">Sin tallas registradas.</div>';

  const filas = ordenes.map((orden) => {
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
  }).join('');

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
    </div>`;
}

function renderBultosImpresion(bultos) {
  const COLS = 4;
  const columnas = Array.from({ length: COLS }, () => []);
  bultos.forEach((b, i) => columnas[i % COLS].push(b));
  const filasMax = Math.max(1, ...columnas.map((c) => c.length));

  const colsHtml = columnas.map((col) => {
    const filas = [];
    for (let r = 0; r < filasMax; r++) {
      const b = col[r];
      filas.push(b
        ? `<tr><td>${b.bulto_numero}</td><td class="col-num">${formatearKilos(b.peso)}</td></tr>`
        : '<tr><td>&nbsp;</td><td class="col-num">&nbsp;</td></tr>');
    }
    return `
      <div class="despacho-print-bultos-col">
        <table class="regd-detalle-tabla">
          <thead><tr><th>Bulto</th><th class="col-num">Peso (kg)</th></tr></thead>
          <tbody>${filas.join('')}</tbody>
        </table>
      </div>`;
  }).join('');

  return `<div class="despacho-print-bultos-grid">${colsHtml}</div>`;
}

function renderCuerpoImpresion(ctx, fechaImpreso, consecutivo, opciones = {}) {
  const { detalle, bultos, tallasPorPedido, ordenes, infoPorPedido, bultosDe, unidadesDe, pesoTotal, unidadesTotal } = ctx;

  const incluirComentario = opciones.incluirComentario !== false;
  const labelBultos = `${bultos.length} ${bultos.length === 1 ? 'Bulto' : 'Bultos'}`;
  const labelUnd = `${unidadesTotal} ${unidadesTotal === 1 ? 'Unidad' : 'Unidades'}`;

  return `
    <div class="despacho-print-header despacho-print-header-en-copia">
      <div class="despacho-print-brand">Suelas<span>.</span></div>
      <div class="despacho-print-fecha">${escapeHtml(fechaImpreso)}</div>
    </div>
    <div class="despacho-print-titulo-fila">
      <div class="despacho-print-titulo">Salida Acabados — ${escapeHtml(consecutivo)}</div>
      <div class="despacho-print-fecha-creacion">
        <label>Fecha de creación</label>
        <div>${formatearFecha(detalle.created_at)}</div>
      </div>
    </div>

    <div class="detalle-despacho-print-linea-cliente">
      <span class="detalle-despacho-print-totales" style="margin-left:auto;">
        <span>${formatearKilos(pesoTotal)} Kg</span>
        <span>${labelBultos}</span>
        <span>${labelUnd}</span>
      </span>
    </div>

    <div class="form-group form-group-print">
      <label>Pedidos de la salida</label>
      ${ordenes.map((o) => renderFichaPedidoImpresion(o, infoPorPedido.get(o))).join('') || '<div class="empty">Sin pedidos.</div>'}
    </div>

    <div class="form-group form-group-print">
      <label>Bultos</label>
      ${bultos.length ? renderBultosImpresion(bultos) : '<div class="empty">Sin bultos.</div>'}
    </div>

    <div class="form-group form-group-print">
      <label>Unidades por pedido y talla</label>
      ${renderMatrizImpresion(ordenes, tallasPorPedido, { bultosDe, unidadesDe })}
    </div>
    ${incluirComentario ? renderComentario(detalle.comentario, 'form-group form-group-print') : ''}
  `;
}

function renderMatrizPedidos(ordenes, { bultosDe, unidadesDe }) {
  if (ordenes.length === 0) return '<div class="empty">Sin pedidos.</div>';

  const filas = ordenes.map((orden) => `
    <tr>
      <td class="celda-pedido">${escapeHtml(orden)}</td>
      <td class="col-num">${unidadesDe(orden)}</td>
      <td class="col-num">${escapeHtml(bultosDe(orden))}</td>
    </tr>`).join('');

  return `
    <div class="detalle-despacho-matriz">
      <table class="regd-detalle-tabla">
        <thead>
          <tr><th>Pedido</th><th class="col-num">Unidades</th><th class="col-num">Bultos</th></tr>
        </thead>
        <tbody>${filas}</tbody>
      </table>
    </div>`;
}

/** Mismo criterio que Despachos: mitad (50% / corte / 50%) si caben, o una copia por página. */
function aplicarLayoutHojaImpresion(hoja) {
  if (!hoja) return;
  hoja.classList.remove('despacho-print-hoja--mitad', 'despacho-print-hoja--dos-paginas');
  hoja.classList.add('despacho-print-hoja--mitad');

  void hoja.offsetHeight;

  const copias = hoja.querySelectorAll('.despacho-print-copia');
  if (copias.length === 0) return;

  const desborda = [...copias].some((c) => c.scrollHeight > c.clientHeight + 1);
  if (desborda) {
    hoja.classList.remove('despacho-print-hoja--mitad');
    hoja.classList.add('despacho-print-hoja--dos-paginas');
  }
}

/** Descarga la salida en PDF: window.print → "Guardar como PDF"; document.title = consecutivo. */
async function descargarSalidaPDF(salidaId, consecutivo, opciones = {}) {
  const incluirComentario = opciones.incluirComentario !== false;

  const modal = document.getElementById('modal-detalle-despacho');
  const titulo = document.getElementById('detalle-despacho-titulo');
  const contenido = document.getElementById('detalle-despacho-contenido');

  titulo.textContent = `Detalle de la Salida — ${consecutivo || ''}`.trim();
  contenido.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  modal.classList.add('open', 'maqueta-pdf-despacho');

  let consecutivoReal;
  try {
    const ctx = await cargarContextoDetalle(salidaId);
    consecutivoReal = String(ctx.detalle.consecutivo || consecutivo || '').trim() || null;
    if (!consecutivoReal) {
      contenido.innerHTML = '<div class="empty">No se pudo identificar la salida.</div>';
      return;
    }

    titulo.textContent = `Detalle de la Salida — ${consecutivoReal}`;

    const fechaImpreso = `Impreso el ${new Date().toLocaleDateString('es-CO', {
      day: '2-digit',
      month: 'long',
      year: 'numeric'
    })}`;
    const fechaEl = document.getElementById('detalle-despacho-print-fecha');
    if (fechaEl) fechaEl.textContent = fechaImpreso;

    const cuerpo = renderCuerpoImpresion(ctx, fechaImpreso, consecutivoReal, { incluirComentario });
    contenido.innerHTML = `
      <div class="despacho-print-hoja">
        <div class="despacho-print-copia">${cuerpo}</div>
        <div class="despacho-print-corte" aria-hidden="true"></div>
        <div class="despacho-print-copia">${cuerpo}</div>
      </div>
    `;
    aplicarLayoutHojaImpresion(contenido.querySelector('.despacho-print-hoja'));
  } catch (err) {
    contenido.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    return;
  }

  const tituloOriginal = document.title;
  document.title = consecutivoReal;

  document.documentElement.classList.add('imprimiendo-despacho');
  document.body.classList.add('imprimiendo-despacho');

  const restaurarTrasImprimir = () => {
    window.removeEventListener('afterprint', restaurarTrasImprimir);
    document.documentElement.classList.remove('imprimiendo-despacho');
    document.body.classList.remove('imprimiendo-despacho');
    setTimeout(() => {
      document.title = tituloOriginal;
    }, 2000);
  };
  window.addEventListener('afterprint', restaurarTrasImprimir);

  setTimeout(() => window.print(), 200);
}

function formatearFecha(fecha) {
  if (!fecha) return '—';
  try {
    return new Date(fecha).toLocaleDateString('es-CO');
  } catch {
    return String(fecha);
  }
}

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
