import { getState } from '../state/appState.js';
import {
  fetchRegistrosDespachos,
  fetchClientesDespachados,
  eliminarDespachoConMotivo,
  marcarDespachoRevisado
} from '../services/despachosService.js';
import { reconstruirSelect } from '../lib/facetas.js';
import { sincronizarEtiquetaFiltro } from './customSelect.js';
import { esValidador, esPropuesta } from '../services/validatorService.js';
import { abrirDetalleDespacho, solicitarDescargaDetalleDespachoPDF } from './despachoDetalleModal.js';
import { mostrarToast } from './toast.js';

/**
 * Acordeón "Despachado" de la pestaña Despachos (antes era la pestaña
 * independiente "RegistrosD"; se fusionó para no duplicar información).
 *
 * Una fila por despacho: al hacer clic se abre el detalle de solo
 * lectura (órdenes, bultos, tallas); el botón × elimina el despacho
 * COMPLETO con motivo obligatorio. No hay edición ni borrado parcial —
 * la asignación pedido->bulto se decide al crear la salida y es
 * inmutable (ver despachosPage.js).
 *
 * A diferencia de historyPage.js, los listeners de filtros se registran
 * UNA sola vez en inicializarPaginaRegistrosDespachos(); el render solo
 * engancha los de las filas que acaba de crear.
 */

let pagina = 0;
let hayPaginaSiguiente = false;
let filtros = { fecha: '', consecutivo: '', orden: '', cliente: '' };
// Firma de la última lista de clientes pintada. Si un refresco trae la
// misma, no se reconstruye el <select>: eso borraría lo que se está escribiendo.
let firmaClientes = null;
let despachoAEliminar = null;
// Cada llamada a cargarRegistrosDespachos incrementa esto. Si una
// petición anterior termina después, su resultado se descarta: si no,
// un filtro a medias (344) pinta "no hay despachos" encima de 3449.
let cargaSeq = 0;

const HTML_CARGANDO = '<div class="loading"><div class="spinner"></div> Cargando despachos...</div>';
const HTML_OVERLAY_CARGA = '<div class="regd-lista-overlay" aria-live="polite"><div class="spinner"></div> Cargando despachos...</div>';

/**
 * Se dispara en document al eliminar un despacho: sus pedidos vuelven a
 * "A Despachar", y despachosPage.js lo escucha para refrescar esa lista.
 * Un evento en vez de un import cruzado evita la dependencia circular
 * entre los dos módulos.
 */
export const EVENTO_DESPACHO_ELIMINADO = 'despacho-eliminado';

export function inicializarPaginaRegistrosDespachos() {
  const inputFecha = document.getElementById('regd-filtro-fecha');
  inputFecha?.addEventListener('input', () => {
    filtros.fecha = inputFecha.value;
    pagina = 0;
    cargarRegistrosDespachos();
  });

  const conDebounce = (id, clave) => {
    const el = document.getElementById(id);
    let temporizador = null;
    el?.addEventListener('input', () => {
      clearTimeout(temporizador);
      temporizador = setTimeout(() => {
        filtros[clave] = el.value.trim();
        pagina = 0;
        cargarRegistrosDespachos();
      }, 350);
    });
  };
  conDebounce('regd-filtro-consecutivo', 'consecutivo');
  conDebounce('regd-filtro-orden', 'orden');

  // El texto del desplegable solo acorta la lista; el filtro se aplica
  // al elegir (el <select> dispara change). "Todos" manda valor vacío.
  document.getElementById('regd-filtro-cliente')?.addEventListener('change', (event) => {
    filtros.cliente = event.target.value;
    pagina = 0;
    cargarRegistrosDespachos();
  });

  document.getElementById('btn-cerrar-eliminar-despacho')?.addEventListener('click', cerrarModalEliminar);
  document.getElementById('btn-cancelar-eliminar-despacho')?.addEventListener('click', cerrarModalEliminar);
  document.getElementById('btn-confirmar-eliminar-despacho')?.addEventListener('click', confirmarEliminar);
}

/**
 * Llena el desplegable con clientes que ya tienen despacho. Se llama al
 * entrar a la pestaña (y en cada refresco): si la lista no cambió, no
 * toca el campo.
 */
export async function cargarClientesDespachados() {
  const select = document.getElementById('regd-filtro-cliente');
  if (!select) return;

  const clientes = await fetchClientesDespachados();
  const firma = clientes.join('\n');
  if (firma === firmaClientes) return;
  firmaClientes = firma;

  reconstruirSelect('regd-filtro-cliente', clientes);
  sincronizarEtiquetaFiltro('regd-filtro-cliente');
}

export async function cargarRegistrosDespachos() {
  if (!getState().user) return;

  const contenedor = document.getElementById('regd-lista');
  if (!contenedor) return;

  const seq = ++cargaSeq;
  pintarEstadoCarga(contenedor);

  try {
    const { despachos, hayMas } = await fetchRegistrosDespachos({ page: pagina, filters: filtros });
    if (seq !== cargaSeq) return;
    hayPaginaSiguiente = hayMas;
    renderDespachos(despachos);
    renderPaginacion();
  } catch (err) {
    if (seq !== cargaSeq) return;
    contenedor.classList.remove('regd-lista-cargando');
    contenedor.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    mostrarToast(err.message, 'error');
  }
}

/**
 * Si ya hay filas, no las borra: overlay encima. Vacío / primer load:
 * spinner a pantalla completa. "No hay despachos" solo lo pinta
 * renderDespachos cuando ESTA petición (seq vigente) volvió en cero.
 */
function pintarEstadoCarga(contenedor) {
  const tieneFilas = !!contenedor.querySelector('.regd-fila');
  if (tieneFilas) {
    contenedor.classList.add('regd-lista-cargando');
    if (!contenedor.querySelector('.regd-lista-overlay')) {
      contenedor.insertAdjacentHTML('beforeend', HTML_OVERLAY_CARGA);
    }
    return;
  }
  contenedor.classList.remove('regd-lista-cargando');
  contenedor.innerHTML = HTML_CARGANDO;
}

/**
 * Con despachos parciales, un despacho puede llevar pedidos completos y
 * otros a medias. El badge es POR PEDIDO, así que en la fila se muestra
 * el contador y el detalle desglosa cuál es cuál.
 */
/**
 * Flecha hacia abajo sobre una bandeja: "descargar", en la misma familia
 * de trazos (24x24, fill none, stroke 2) que el resto de iconos.
 */
const ICONO_DESCARGA = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>`;

/** Bocadillo de comentario (064): misma familia de trazos que la descarga. */
const ICONO_COMENTARIO = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`;

/** Popover de solo lectura anclado al icono de comentario de la fila. */
let popoverComentario = null;
let botonComentarioActivo = null;

function contadorCompletos(completos, total) {
  const todos = total > 0 && completos === total;
  const bg = todos ? 'var(--green-bg)' : 'var(--amber-bg)';
  const color = todos ? 'var(--green-text)' : 'var(--amber-text)';
  return `<span style="background:${bg}; color:${color}; padding:3px 10px; border-radius:5px; font-size:12px; font-weight:600; display:inline-block; white-space:nowrap;">${completos} de ${total}</span>`;
}

function renderDespachos(despachos) {
  const contenedor = document.getElementById('regd-lista');
  contenedor.classList.remove('regd-lista-cargando');
  cerrarPopoverComentario();

  if (despachos.length === 0) {
    contenedor.innerHTML = '<div class="empty">No hay despachos para mostrar.</div>';
    return;
  }

  // El visto bueno es del Validador; los demás lo ven, pero no lo mueven.
  const puedeRevisar = esValidador();
  // Propuesta solo mira: sin × y sin descarga del PDF. Las columnas se
  // conservan (vacías) para que la grilla de la fila no cambie de forma.
  // El icono de comentario (064) sí lo ven todos, incluido Propuesta.
  const puedeEliminar = !esPropuesta();
  const puedeDescargar = !esPropuesta();

  contenedor.innerHTML = despachos
    .map((d) => {
      const listaOrdenes = (d.order_numbers || []).join(', ');
      const comentario = String(d.comentario ?? '').trim();
      // El × se apaga con el visto bueno puesto, salvo para el propio
      // Validador — que de todos modos puede quitarlo. Es el mismo
      // criterio de Registros: no ofrecer lo que el servidor rechazaría.
      const bloqueado = d.revisado && !puedeRevisar;
      return `
        <div class="regd-fila" data-despacho="${escapeHtml(d.id)}" data-consecutivo="${escapeHtml(d.consecutivo)}" data-ordenes="${escapeHtml(listaOrdenes)}" data-bultos="${d.total_bultos}"${comentario ? ' data-tiene-comentario="1"' : ''}>
          <div class="regd-col-consecutivo">${escapeHtml(d.consecutivo)}</div>
          <div class="regd-col-fecha">${formatearFecha(d.created_at)}</div>
          <div class="regd-col-hora" title="Hora del despacho">${formatearHora(d.created_at)}</div>
          <div class="regd-col-ordenes" data-lbl="Pedidos" title="${escapeHtml(listaOrdenes)}">${escapeHtml(listaOrdenes) || '—'}</div>
          <div class="regd-col-num" data-lbl="Bultos">${d.total_bultos}</div>
          <div class="regd-col-num" data-lbl="Kilos">${formatearKilos(d.peso_total)}</div>
          <div class="regd-col-num" data-lbl="Unidades">${d.total_unidades ?? 0}</div>
          <div class="regd-col-num" data-lbl="Completos">${contadorCompletos(d.pedidos_completos ?? 0, d.numero_ordenes ?? 0)}</div>
          <div class="regd-col-revisado">
            <input type="checkbox" class="checkbox-revisado" data-revisar="${escapeHtml(d.id)}"
              ${d.revisado ? 'checked' : ''} ${puedeRevisar ? '' : 'disabled'}
              title="${tituloRevisado(d, puedeRevisar)}" aria-label="Revisado por el Validador">
          </div>
          <div class="regd-col-comentario">
            ${comentario
              ? `<button type="button" class="btn-comentario-registro con-comentario" data-comentario="${escapeHtml(comentario)}" title="Ver comentario" aria-label="Ver comentario" aria-expanded="false">${ICONO_COMENTARIO}</button>`
              : `<button type="button" class="btn-comentario-registro sin-comentario" aria-disabled="true" aria-label="Sin comentario">${ICONO_COMENTARIO}</button>`}
          </div>
          <div class="regd-col-descarga">
            ${puedeDescargar ? `<button class="btn-descargar-registro" data-descargar="${escapeHtml(d.id)}" title="Descargar el despacho en PDF" aria-label="Descargar el despacho en PDF">${ICONO_DESCARGA}</button>` : ''}
          </div>
          <div class="regd-col-accion">
            ${puedeEliminar ? `<button class="btn-eliminar-registro" data-eliminar="${escapeHtml(d.id)}" ${bloqueado ? 'disabled' : ''}
              title="${bloqueado ? 'El Validador ya revisó este despacho. Pídele que quite el visto bueno para poder eliminarlo.' : 'Eliminar despacho completo'}"
              aria-label="Eliminar despacho completo">×</button>` : ''}
          </div>
        </div>
      `;
    })
    .join('');

  contenedor.querySelectorAll('.regd-fila').forEach((fila) => {
    fila.addEventListener('click', () => {
      cerrarPopoverComentario();
      abrirDetalleDespacho(fila.dataset.despacho, fila.dataset.consecutivo);
    });
  });

  contenedor.querySelectorAll('[data-revisar]').forEach((cb) => {
    // El clic en la fila abre el detalle: la casilla no debe dispararlo.
    cb.addEventListener('click', (event) => event.stopPropagation());
    cb.addEventListener('change', () => cambiarRevisado(cb));
  });

  contenedor.querySelectorAll('.btn-comentario-registro').forEach((btn) => {
    btn.addEventListener('click', (event) => {
      // La fila entera abre el detalle; el popover es solo lectura aquí.
      // Sin comentario: el botón se ve apagado y no debe abrir nada ni
      // disparar el detalle (aria-disabled, no disabled nativo: ese a
      // veces deja pasar el clic a la fila).
      event.stopPropagation();
      if (btn.classList.contains('sin-comentario') || btn.getAttribute('aria-disabled') === 'true') return;
      alternarPopoverComentario(btn);
    });
  });

  contenedor.querySelectorAll('[data-descargar]').forEach((btn) => {
    btn.addEventListener('click', (event) => {
      // La fila entera abre el detalle; este botón abre lo mismo y además
      // manda a imprimir, así que no debe dispararla también.
      event.stopPropagation();
      cerrarPopoverComentario();
      const fila = btn.closest('.regd-fila');
      solicitarDescargaDetalleDespachoPDF(btn.dataset.descargar, fila.dataset.consecutivo, {
        tieneComentario: fila.dataset.tieneComentario === '1'
      });
    });
  });

  contenedor.querySelectorAll('[data-eliminar]').forEach((btn) => {
    btn.addEventListener('click', (event) => {
      // La fila entera abre el detalle; el × no debe dispararlo.
      event.stopPropagation();
      cerrarPopoverComentario();
      const fila = btn.closest('.regd-fila');
      abrirModalEliminar(btn.dataset.eliminar, fila.dataset);
    });
  });
}

function asegurarListenersPopoverComentario() {
  if (asegurarListenersPopoverComentario.listo) return;
  asegurarListenersPopoverComentario.listo = true;

  document.addEventListener('click', (event) => {
    if (!popoverComentario) return;
    if (popoverComentario.contains(event.target)) return;
    if (botonComentarioActivo?.contains(event.target)) return;
    cerrarPopoverComentario();
  });

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') cerrarPopoverComentario();
  });

  window.addEventListener('resize', cerrarPopoverComentario);
  document.getElementById('regd-lista')?.addEventListener('scroll', cerrarPopoverComentario, true);
}

function alternarPopoverComentario(boton) {
  asegurarListenersPopoverComentario();

  if (botonComentarioActivo === boton && popoverComentario) {
    cerrarPopoverComentario();
    return;
  }

  cerrarPopoverComentario();

  const texto = boton.dataset.comentario || '';
  const pop = document.createElement('div');
  pop.className = 'regd-comentario-popover';
  pop.setAttribute('role', 'dialog');
  pop.setAttribute('aria-label', 'Comentario del despacho');
  pop.innerHTML = `
    <div class="regd-comentario-popover-titulo">Comentario</div>
    <div class="regd-comentario-popover-texto">${escapeHtml(texto)}</div>
  `;
  document.body.appendChild(pop);

  const rect = boton.getBoundingClientRect();
  const margen = 8;
  const ancho = pop.offsetWidth;
  const alto = pop.offsetHeight;
  let left = rect.left + rect.width / 2 - ancho / 2;
  left = Math.max(margen, Math.min(left, window.innerWidth - ancho - margen));
  let top = rect.bottom + 6;
  if (top + alto + margen > window.innerHeight && rect.top - alto - 6 > margen) {
    top = rect.top - alto - 6;
  }

  pop.style.left = `${Math.round(left)}px`;
  pop.style.top = `${Math.round(top)}px`;

  popoverComentario = pop;
  botonComentarioActivo = boton;
  boton.setAttribute('aria-expanded', 'true');
}

function cerrarPopoverComentario() {
  if (popoverComentario) {
    popoverComentario.remove();
    popoverComentario = null;
  }
  if (botonComentarioActivo) {
    botonComentarioActivo.setAttribute('aria-expanded', 'false');
    botonComentarioActivo = null;
  }
}

/** Texto del tooltip de la casilla, según quién esté mirando. */
function tituloRevisado(despacho, puedeRevisar) {
  if (!despacho.revisado) {
    return puedeRevisar
      ? 'Marcar como revisado: bloquea su eliminación'
      : 'Pendiente de revisión del Validador';
  }
  const quien = despacho.revisado_por_nombre ? ` por ${despacho.revisado_por_nombre}` : '';
  return puedeRevisar
    ? `Revisado${quien}. Quitar el visto bueno permite eliminarlo de nuevo.`
    : `Revisado${quien}. No se puede eliminar mientras tenga el visto bueno.`;
}

/**
 * La casilla se pinta optimista (el navegador ya la marcó al hacer clic)
 * y se revierte si el servidor dice que no. Se recarga la lista para que
 * el × y el tooltip queden acordes sin tener que tocarlos a mano.
 */
async function cambiarRevisado(checkbox) {
  const deseado = checkbox.checked;
  checkbox.disabled = true;

  try {
    await marcarDespachoRevisado(checkbox.dataset.revisar, deseado);
    mostrarToast(deseado ? 'Despacho marcado como revisado.' : 'Visto bueno retirado.', 'ok');
    await cargarRegistrosDespachos();
  } catch (err) {
    checkbox.checked = !deseado;
    checkbox.disabled = false;
    mostrarToast(err.message, 'error');
  }
}

function renderPaginacion() {
  const el = document.getElementById('regd-paginacion');
  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="regd-pag-prev" ${pagina === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${pagina + 1}</span>
    <button class="btn btn-secondary btn-sm" id="regd-pag-next" ${hayPaginaSiguiente ? '' : 'disabled'}>Siguiente →</button>
  `;

  document.getElementById('regd-pag-prev')?.addEventListener('click', () => {
    pagina = Math.max(pagina - 1, 0);
    cargarRegistrosDespachos();
  });
  document.getElementById('regd-pag-next')?.addEventListener('click', () => {
    pagina += 1;
    cargarRegistrosDespachos();
  });
}

// ---------------------------------------------------------------------
// Modal de eliminación (despacho completo, motivo obligatorio)
// ---------------------------------------------------------------------

function abrirModalEliminar(despachoId, datos) {
  despachoAEliminar = despachoId;
  document.getElementById('eliminar-despacho-motivo').value = '';
  document.getElementById('eliminar-despacho-resumen').innerHTML = `
    Despacho <strong>${escapeHtml(datos.consecutivo)}</strong> ·
    ${escapeHtml(datos.bultos)} bulto${datos.bultos === '1' ? '' : 's'} ·
    Órdenes: <strong>${escapeHtml(datos.ordenes) || '—'}</strong>
  `;
  document.getElementById('modal-eliminar-despacho').classList.add('open');
}

function cerrarModalEliminar() {
  document.getElementById('modal-eliminar-despacho').classList.remove('open');
  despachoAEliminar = null;
}

async function confirmarEliminar() {
  const motivo = document.getElementById('eliminar-despacho-motivo').value.trim();
  if (!motivo) {
    mostrarToast('Debes indicar un motivo para eliminar este despacho.', 'error');
    return;
  }

  const btn = document.getElementById('btn-confirmar-eliminar-despacho');
  btn.disabled = true;

  try {
    await eliminarDespachoConMotivo(despachoAEliminar, motivo);
    mostrarToast('Despacho eliminado. Sus órdenes vuelven a "A Despachar".', 'ok');
    cerrarModalEliminar();
    await cargarClientesDespachados();
    await cargarRegistrosDespachos();
    document.dispatchEvent(new CustomEvent(EVENTO_DESPACHO_ELIMINADO));
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}

// ---------------------------------------------------------------------
// Utilidades (mismo formato que despachosPage.js)
// ---------------------------------------------------------------------

function formatearFecha(fecha) {
  if (!fecha) return '—';
  try {
    return new Date(fecha).toLocaleDateString('es-CO');
  } catch {
    return String(fecha);
  }
}

/** Hora local en 24 h, sin segundos. Solo el listado: el detalle y el PDF siguen en fecha. */
function formatearHora(fecha) {
  if (!fecha) return '—';
  const d = new Date(fecha);
  if (Number.isNaN(d.getTime())) return '—';
  const horas = String(d.getHours()).padStart(2, '0');
  const minutos = String(d.getMinutes()).padStart(2, '0');
  return `${horas}:${minutos}`;
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
