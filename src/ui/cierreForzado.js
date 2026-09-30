import { cerrarPedidoForzado, reabrirPedidoForzado } from '../services/cierreForzadoService.js';
import { mostrarToast } from './toast.js';

/**
 * Cierre forzado de un pedido por el Validador (supabase/sql/057_cierre_forzado.sql).
 * Mismo formato que el visto bueno de un despacho: check circular con ✓
 * (.checkbox-revisado) que se prende y se apaga. Prender pide un motivo;
 * apagar reabre el pedido.
 */

let pedidoACerrar = null;
let alTerminar = null;
let checkboxPendiente = null;

export function inicializarModalCierreForzado() {
  document.getElementById('btn-cerrar-cierre-forzado')?.addEventListener('click', cerrarModal);
  document.getElementById('btn-cancelar-cierre-forzado')?.addEventListener('click', cerrarModal);
  document.getElementById('btn-confirmar-cierre-forzado')?.addEventListener('click', confirmarCierre);
}

/**
 * Cambio de estado del check de una tarjeta.
 * @param {HTMLInputElement} checkbox
 * @param {() => Promise<void>} refrescar recarga el listado al terminar
 */
export async function alternarCierreForzado(checkbox, refrescar) {
  const orderNumber = checkbox.dataset.cierreForzado;

  if (checkbox.checked) {
    // Prender: hace falta el motivo. La casilla queda marcada solo si se confirma.
    checkbox.checked = false;
    pedidoACerrar = orderNumber;
    alTerminar = refrescar;
    checkboxPendiente = checkbox;
    document.getElementById('cierre-forzado-motivo').value = '';
    document.getElementById('cierre-forzado-resumen').innerHTML = `Pedido <strong>${escapeHtml(orderNumber)}</strong>`;
    document.getElementById('modal-cierre-forzado').classList.add('open');
    return;
  }

  // Apagar: reabrir.
  checkbox.disabled = true;
  try {
    await reabrirPedidoForzado(orderNumber);
    mostrarToast(`Pedido ${orderNumber} reabierto.`, 'ok');
    await refrescar();
  } catch (err) {
    checkbox.checked = true;
    checkbox.disabled = false;
    mostrarToast(err.message, 'error');
  }
}

function cerrarModal() {
  document.getElementById('modal-cierre-forzado').classList.remove('open');
  pedidoACerrar = null;
  alTerminar = null;
  checkboxPendiente = null;
}

async function confirmarCierre() {
  const motivo = document.getElementById('cierre-forzado-motivo').value.trim();
  if (!motivo) {
    mostrarToast('Debes indicar el motivo del cierre.', 'error');
    return;
  }

  const btn = document.getElementById('btn-confirmar-cierre-forzado');
  btn.disabled = true;
  const refrescar = alTerminar;
  const orderNumber = pedidoACerrar;

  try {
    await cerrarPedidoForzado(orderNumber, motivo);
    mostrarToast(`Pedido ${orderNumber} cerrado a la fuerza.`, 'ok');
    cerrarModal();
    if (refrescar) await refrescar();
  } catch (err) {
    if (checkboxPendiente) checkboxPendiente.checked = false;
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
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
