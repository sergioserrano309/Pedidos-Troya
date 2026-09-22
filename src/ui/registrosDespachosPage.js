import { getState } from '../state/appState.js';
import {
  fetchRegistrosDespachos,
  eliminarDespachoConMotivo,
  marcarDespachoRevisado
} from '../services/despachosService.js';
import { esValidador } from '../services/validatorService.js';
import { abrirDetalleDespacho, descargarDetalleDespachoPDF } from './despachoDetalleModal.js';
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
let filtros = { fecha: '', consecutivo: '', orden: '' };
let despachoAEliminar = null;

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

  document.getElementById('btn-cerrar-eliminar-despacho')?.addEventListener('click', cerrarModalEliminar);
  document.getElementById('btn-cancelar-eliminar-despacho')?.addEventListener('click', cerrarModalEliminar);
  document.getElementById('btn-confirmar-eliminar-despacho')?.addEventListener('click', confirmarEliminar);
}

export async function cargarRegistrosDespachos() {
  if (!getState().user) return;

  const contenedor = document.getElementById('regd-lista');
  if (!contenedor) return;
  contenedor.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando despachos...</div>';

  try {
    const { despachos, hayMas } = await fetchRegistrosDespachos({ page: pagina, filters: filtros });
    hayPaginaSiguiente = hayMas;
    renderDespachos(despachos);
    renderPaginacion();
  } catch (err) {
    contenedor.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    mostrarToast(err.message, 'error');
  }
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

function contadorCompletos(completos, total) {
  const todos = total > 0 && completos === total;
  const bg = todos ? 'var(--green-bg)' : 'var(--amber-bg)';
  const color = todos ? 'var(--green-text)' : 'var(--amber-text)';
  return `<span style="background:${bg}; color:${color}; padding:3px 10px; border-radius:5px; font-size:12px; font-weight:600; display:inline-block; white-space:nowrap;">${completos} de ${total}</span>`;
}

function renderDespachos(despachos) {
  const contenedor = document.getElementById('regd-lista');

  if (despachos.length === 0) {
    contenedor.innerHTML = '<div class="empty">No hay despachos para mostrar.</div>';
    return;
  }

  // El visto bueno es del Validador; los demás lo ven, pero no lo mueven.
  const puedeRevisar = esValidador();

  contenedor.innerHTML = despachos
    .map((d) => {
      const listaOrdenes = (d.order_numbers || []).join(', ');
      // El × se apaga con el visto bueno puesto, salvo para el propio
      // Validador — que de todos modos puede quitarlo. Es el mismo
      // criterio de Registros: no ofrecer lo que el servidor rechazaría.
      const bloqueado = d.revisado && !puedeRevisar;
      return `
        <div class="regd-fila" data-despacho="${escapeHtml(d.id)}" data-consecutivo="${escapeHtml(d.consecutivo)}" data-ordenes="${escapeHtml(listaOrdenes)}" data-bultos="${d.total_bultos}">
          <div class="regd-col-consecutivo">${escapeHtml(d.consecutivo)}</div>
          <div class="regd-col-fecha">${formatearFecha(d.created_at)}</div>
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
          <div class="regd-col-descarga">
            <button class="btn-descargar-registro" data-descargar="${escapeHtml(d.id)}" title="Descargar el despacho en PDF" aria-label="Descargar el despacho en PDF">${ICONO_DESCARGA}</button>
          </div>
          <div class="regd-col-accion">
            <button class="btn-eliminar-registro" data-eliminar="${escapeHtml(d.id)}" ${bloqueado ? 'disabled' : ''}
              title="${bloqueado ? 'El Validador ya revisó este despacho. Pídele que quite el visto bueno para poder eliminarlo.' : 'Eliminar despacho completo'}"
              aria-label="Eliminar despacho completo">×</button>
          </div>
        </div>
      `;
    })
    .join('');

  contenedor.querySelectorAll('.regd-fila').forEach((fila) => {
    fila.addEventListener('click', () => abrirDetalleDespacho(fila.dataset.despacho, fila.dataset.consecutivo));
  });

  contenedor.querySelectorAll('[data-revisar]').forEach((cb) => {
    // El clic en la fila abre el detalle: la casilla no debe dispararlo.
    cb.addEventListener('click', (event) => event.stopPropagation());
    cb.addEventListener('change', () => cambiarRevisado(cb));
  });

  contenedor.querySelectorAll('[data-descargar]').forEach((btn) => {
    btn.addEventListener('click', (event) => {
      // La fila entera abre el detalle; este botón abre lo mismo y además
      // manda a imprimir, así que no debe dispararla también.
      event.stopPropagation();
      const fila = btn.closest('.regd-fila');
      descargarDetalleDespachoPDF(btn.dataset.descargar, fila.dataset.consecutivo);
    });
  });

  contenedor.querySelectorAll('[data-eliminar]').forEach((btn) => {
    btn.addEventListener('click', (event) => {
      // La fila entera abre el detalle; el × no debe dispararlo.
      event.stopPropagation();
      const fila = btn.closest('.regd-fila');
      abrirModalEliminar(btn.dataset.eliminar, fila.dataset);
    });
  });
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
