import {
  fetchDetalleDespacho,
  fetchAsignacionesDespacho,
  fetchBultosDespacho,
  fetchItemsDespacho,
  fetchEstadoPedidos,
  fetchInfoPedidos,
  editarComentarioDespacho,
  editarFacturaDespacho
} from '../services/despachosService.js';
import { esPropuesta, esValidador } from '../services/validatorService.js';
import { mostrarToast } from './toast.js';

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
 * La descarga PDF (descargarDetalleDespachoPDF) usa una maqueta distinta.
 * Preview A4; en print cada mitad = 50% del papel elegido, corte al centro;
 * si no caben, una copia por página sin corte. Ver §12.7.
 */

/**
 * Se dispara en document al guardar comentario o factura de un despacho:
 * la lista de Despachado lo escucha y se vuelve a leer, así lo nuevo se ve
 * sin F5. Evento en vez de import cruzado (la lista ya importa este módulo).
 */
export const EVENTO_DESPACHO_ACTUALIZADO = 'despacho-actualizado';

/** Pendiente del modal “¿incluir comentario en el PDF?”. */
let pdfPendiente = null;

export function inicializarModalDetalleDespacho() {
  document.getElementById('btn-cerrar-detalle-despacho')?.addEventListener('click', cerrarDetalleDespacho);
  document.getElementById('btn-cerrar-detalle-despacho-2')?.addEventListener('click', cerrarDetalleDespacho);

  document.getElementById('btn-cerrar-pdf-comentario')?.addEventListener('click', cerrarModalPdfComentario);
  document.getElementById('btn-cancelar-pdf-comentario')?.addEventListener('click', cerrarModalPdfComentario);
  document.getElementById('btn-confirmar-pdf-comentario')?.addEventListener('click', confirmarPdfComentario);
}

/**
 * Entrada del botón ↓ en Despachado. Si la salida no tiene comentario,
 * imprime directo. Si tiene, abre un modal con toggle (default: incluir)
 * antes de generar el PDF. No cambia el layout de impresión: solo decide
 * si se pinta el bloque de comentario.
 *
 * @param {string} despachoId
 * @param {string} consecutivo
 * @param {{ tieneComentario?: boolean }} [opciones]
 */
export function solicitarDescargaDetalleDespachoPDF(despachoId, consecutivo, opciones = {}) {
  if (esPropuesta()) return;

  const tieneComentario = Boolean(opciones.tieneComentario);
  if (!tieneComentario) {
    descargarDetalleDespachoPDF(despachoId, consecutivo, { incluirComentario: true });
    return;
  }

  pdfPendiente = { despachoId, consecutivo };
  const toggle = document.getElementById('pdf-despacho-incluir-comentario');
  if (toggle) toggle.checked = true;
  document.getElementById('modal-pdf-comentario-despacho')?.classList.add('open');
}

function cerrarModalPdfComentario() {
  document.getElementById('modal-pdf-comentario-despacho')?.classList.remove('open');
  pdfPendiente = null;
}

function confirmarPdfComentario() {
  if (!pdfPendiente) return;
  const { despachoId, consecutivo } = pdfPendiente;
  const incluir = Boolean(document.getElementById('pdf-despacho-incluir-comentario')?.checked);
  cerrarModalPdfComentario();
  descargarDetalleDespachoPDF(despachoId, consecutivo, { incluirComentario: incluir });
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
    enlazarEdicionComentario(despachoId, ctx.detalle.comentario);
    enlazarEdicionFactura(despachoId, ctx.detalle.numero_factura);
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

  return armarContexto(detalle, asignaciones, bultos, tallasPorPedido);
}

/**
 * Detalle de un despacho ELIMINADO (solo lectura): se arma con la copia
 * guardada al eliminarlo (snapshot), porque sus filas ya no existen. Arriba
 * lleva quién lo eliminó, cuándo y el motivo.
 *
 * @param {object} fila Fila de listar_despachos_eliminados (trae `snapshot`).
 */
export async function abrirDetalleDespachoEliminado(fila) {
  const modal = document.getElementById('modal-detalle-despacho');
  const titulo = document.getElementById('detalle-despacho-titulo');
  const contenido = document.getElementById('detalle-despacho-contenido');

  modal.classList.remove('maqueta-pdf-despacho');
  titulo.textContent = `Detalle del Despacho — ${fila.consecutivo} (eliminado)`;
  contenido.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  modal.classList.add('open');

  try {
    const snap = fila.snapshot || {};
    const despacho = snap.despacho || {};
    const ordenes = (snap.ordenes || []).map((o) => String(o.order_number));

    const tallasPorPedido = new Map();
    (snap.items || []).forEach((i) => {
      const pedido = String(i.order_number);
      if (!tallasPorPedido.has(pedido)) tallasPorPedido.set(pedido, []);
      tallasPorPedido.get(pedido).push({ talla: String(i.talla ?? '—'), unidades: i.cantidad ?? 0 });
    });
    tallasPorPedido.forEach((tallas) =>
      tallas.sort((a, b) => a.talla.localeCompare(b.talla, undefined, { numeric: true }))
    );

    const bultos = [...(snap.bultos || [])].sort((a, b) => a.bulto_numero - b.bulto_numero);

    const ctx = await armarContexto(
      {
        consecutivo: fila.consecutivo,
        created_at: despacho.created_at,
        comentario: despacho.comentario,
        numero_factura: despacho.numero_factura,
        order_numbers: ordenes
      },
      snap.asignaciones || [],
      bultos,
      tallasPorPedido
    );

    contenido.innerHTML = `
      <div class="detalle-despacho-eliminado">
        <strong>Despacho eliminado</strong>
        <div>Por ${escapeHtml(fila.eliminado_por_nombre || '—')} · ${escapeHtml(formatearFecha(fila.eliminado_en))}</div>
        <div class="detalle-despacho-eliminado-motivo"><span>Motivo:</span> ${escapeHtml(fila.motivo || '—')}</div>
      </div>
      ${renderContenidoPantalla({ ...ctx, soloLectura: true })}
    `;
  } catch (err) {
    contenido.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
  }
}

async function armarContexto(detalle, asignaciones, bultos, tallasPorPedido) {
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
    clientes,
    soloLectura
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
${soloLectura
    ? renderComentario(detalle.comentario, 'form-group') + renderFacturaSoloLectura(detalle.numero_factura)
    : (esValidador() ? renderComentarioEditable(detalle.comentario) : renderComentario(detalle.comentario, 'form-group')) + renderFacturaEditable(detalle.numero_factura)}
  `;
}

/**
 * Comentario de la salida (062). Solo se pinta si lo hay: los despachos
 * sin comentario (todos los anteriores a 062) se ven exactamente igual.
 * Va escapado y con saltos de línea respetados (white-space: pre-wrap).
 */
function renderComentario(comentario, clasesGrupo) {
  const texto = String(comentario ?? '').trim();
  if (!texto) return '';
  return `
    <div class="${clasesGrupo}">
      <label>Comentarios</label>
      <div class="detalle-despacho-comentario">${escapeHtml(texto)}</div>
    </div>`;
}

/**
 * Comentario editable (063), solo para el Validador y solo en pantalla: el
 * PDF usa siempre renderComentario (texto fijo). El botón nace apagado y
 * se prende al cambiar el texto.
 */
function renderComentarioEditable(comentario) {
  const texto = String(comentario ?? '');
  return `
    <div class="form-group">
      <label for="detalle-despacho-comentario-input">Comentarios</label>
      <textarea id="detalle-despacho-comentario-input" maxlength="255" rows="3"
        placeholder="Sin comentario. Escribe aquí lo que quieras dejar anotado sobre este despacho.">${escapeHtml(texto)}</textarea>
      <div class="detalle-despacho-comentario-pie">
        <span id="detalle-despacho-comentario-contador" class="crear-despacho-contador">${texto.length} / 255</span>
        <button type="button" class="btn btn-primary btn-sm" id="detalle-despacho-comentario-guardar" disabled>Guardar comentario</button>
      </div>
    </div>`;
}

/**
 * Engancha el campo editable recién pintado. No-op si no hay campo
 * (cualquier usuario que no sea Validador). Los listeners viven en nodos
 * que se recrean en cada apertura del modal, así que no se acumulan.
 */
function enlazarEdicionComentario(despachoId, comentarioInicial) {
  const campo = document.getElementById('detalle-despacho-comentario-input');
  const boton = document.getElementById('detalle-despacho-comentario-guardar');
  const contador = document.getElementById('detalle-despacho-comentario-contador');
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
      await editarComentarioDespacho(despachoId, nuevo);
      guardado = nuevo;
      campo.value = nuevo;
      mostrarToast(nuevo ? 'Comentario guardado.' : 'Comentario eliminado.', 'ok');
      document.dispatchEvent(new CustomEvent(EVENTO_DESPACHO_ACTUALIZADO));
    } catch (err) {
      mostrarToast(err.message, 'error');
    } finally {
      campo.disabled = false;
      sincronizar();
    }
  });
}

/**
 * Factura editable (068) para quien abre Despachado. Solo dígitos, máx. 5.
 * Vacío al guardar = quitar. No se incluye en el PDF.
 */
function renderFacturaEditable(numeroFactura) {
  const texto = String(numeroFactura ?? '').replace(/\D/g, '').slice(0, 5);
  return `
    <div class="form-group">
      <label for="detalle-despacho-factura-input">Facturas</label>
      <input type="text" id="detalle-despacho-factura-input" maxlength="5"
        inputmode="numeric" pattern="[0-9]*" autocomplete="off" data-solo-digitos
        placeholder="Número de factura"
        value="${escapeHtml(texto)}">
      <div class="detalle-despacho-comentario-pie">
        <span id="detalle-despacho-factura-ayuda" class="crear-despacho-contador">${texto.length} / 5</span>
        <button type="button" class="btn btn-primary btn-sm" id="detalle-despacho-factura-guardar" disabled>Guardar factura</button>
      </div>
    </div>`;
}

/** Factura de un despacho eliminado: solo se muestra, si la tenía. */
function renderFacturaSoloLectura(numeroFactura) {
  const texto = String(numeroFactura ?? '').trim();
  if (!texto) return '';
  return `
    <div class="form-group">
      <label>Facturas</label>
      <div>${escapeHtml(texto)}</div>
    </div>`;
}

function enlazarEdicionFactura(despachoId, facturaInicial) {
  const campo = document.getElementById('detalle-despacho-factura-input');
  const boton = document.getElementById('detalle-despacho-factura-guardar');
  const ayuda = document.getElementById('detalle-despacho-factura-ayuda');
  if (!campo || !boton) return;

  let guardado = String(facturaInicial ?? '').replace(/\D/g, '').slice(0, 5);

  const soloDigitos = () => {
    const limpio = campo.value.replace(/\D/g, '').slice(0, 5);
    if (campo.value !== limpio) campo.value = limpio;
    return limpio;
  };

  const sincronizar = () => {
    const actual = soloDigitos();
    if (ayuda) ayuda.textContent = `${actual.length} / 5`;
    boton.disabled = actual === guardado;
  };
  campo.addEventListener('input', sincronizar);

  boton.addEventListener('click', async () => {
    const nuevo = soloDigitos();
    if (nuevo === guardado) return;

    boton.disabled = true;
    campo.disabled = true;
    try {
      await editarFacturaDespacho(despachoId, nuevo);
      guardado = nuevo;
      campo.value = nuevo;
      mostrarToast(nuevo ? 'Factura guardada.' : 'Factura eliminada.', 'ok');
      document.dispatchEvent(new CustomEvent(EVENTO_DESPACHO_ACTUALIZADO));
    } catch (err) {
      mostrarToast(err.message, 'error');
    } finally {
      campo.disabled = false;
      sincronizar();
    }
  });
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
 * Una copia completa del PDF (sin duplicar aún). El duplicado y el
 * layout de hoja (mitad física o dos páginas) lo arma
 * descargarDetalleDespachoPDF + aplicarLayoutHojaImpresion.
 */
/**
 * @param {object} ctx
 * @param {string} fechaImpreso
 * @param {string} consecutivo
 * @param {{ incluirComentario?: boolean }} [opciones]
 */
function renderCuerpoImpresion(ctx, fechaImpreso, consecutivo, opciones = {}) {
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

  const incluirComentario = opciones.incluirComentario !== false;
  const clienteTxt = clientes.length ? escapeHtml(clientes.join(' · ')) : 'Cliente sin registrar';
  const labelBultos = `${bultos.length} ${bultos.length === 1 ? 'Bulto' : 'Bultos'}`;
  const labelUnd = `${unidadesTotal} ${unidadesTotal === 1 ? 'Unidad' : 'Unidades'}`;

  return `
    <div class="despacho-print-header despacho-print-header-en-copia">
      <div class="despacho-print-brand">Suelas<span>.</span></div>
      <div class="despacho-print-fecha">${escapeHtml(fechaImpreso)}</div>
    </div>
    <div class="despacho-print-titulo-fila">
      <div class="despacho-print-titulo">Detalle del Despacho — ${escapeHtml(consecutivo)}</div>
      <div class="despacho-print-fecha-creacion">
        <label>Fecha de creación</label>
        <div>${formatearFecha(detalle.created_at)}</div>
      </div>
    </div>

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
 * Elige layout de hoja tras pintar la maqueta (medición sobre preview A4):
 *   - mitad: caben → 50% / corte / 50% (en print = página elegida)
 *   - dos-paginas: no caben → una copia por página, sin corte
 *
 * No se remide en beforeprint: con height aún no estable el motor
 * marcaba desborde falso y cada mitad iba a su hoja. Ver §12.7.
 */
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

/**
 * Descarga el despacho en PDF. Mecanismo: window.print → "Guardar como PDF".
 * Preview = A4. Print modo --mitad = dos franjas al 50% del papel elegido
 * (@page size: auto) con corte en el centro; si no caben, --dos-paginas.
 *
 * document.title = consecutivo (nombre sugerido del archivo).
 *
 * @param {string} despachoId
 * @param {string} consecutivo
 * @param {{ incluirComentario?: boolean }} [opciones] default: incluir
 */
export async function descargarDetalleDespachoPDF(despachoId, consecutivo, opciones = {}) {
  // Propuesta solo consulta: no descarga despachos (el botón ya no se
  // le pinta; esto cubre cualquier otra vía que llegue hasta aquí).
  if (esPropuesta()) return;

  const incluirComentario = opciones.incluirComentario !== false;

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
