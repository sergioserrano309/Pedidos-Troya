import { getState } from '../state/appState.js';
import { registrarMovimiento } from '../services/movementsService.js';
import { destinosPermitidos } from '../lib/roles.js';
import { mostrarToast } from './toast.js';
import { refrescarDetalleActual } from './orderDetail.js';
import { cargarOrdenes } from './dashboard.js';

let itemActual = null;

export function inicializarModalProcesar() {
  document.getElementById('btn-cerrar-procesar').addEventListener('click', cerrarModalProcesar);
  document.getElementById('btn-cancelar-procesar').addEventListener('click', cerrarModalProcesar);
  document.getElementById('btn-guardar-procesar').addEventListener('click', guardarProceso);
}

export function abrirModalProcesar(item) {
  itemActual = item;
  const { user } = getState();

  document.getElementById('procesar-talla').value = item.talla ?? '';
  document.getElementById('procesar-nombre').value = item.nombre_referencia || item.referencia || '';
  document.getElementById('procesar-solicitada').value = item.cantidad_solicitada ?? 0;
  document.getElementById('procesar-yaprocesada').value = item.cantidad_procesada ?? 0;
  document.getElementById('procesar-cantidad').value = '';
  document.getElementById('procesar-obs').value = '';

  const opciones = destinosPermitidos(user.role);
  const select = document.getElementById('procesar-destino');
  const placeholder = opciones.length > 1 ? '<option value="">Selecciona proceso destino</option>' : '';
  select.innerHTML =
    placeholder +
    opciones
      .map((op) => `<option value="${op}">${op === 'Completado' ? 'Marcar como Completado' : `Enviar a ${op}`}</option>`)
      .join('');

  const grupoDestino = document.getElementById('procesar-destino-group');
  // Empaque solo tiene un destino posible (Completado): ocultamos el
  // selector y usamos ese único valor directamente.
  grupoDestino.style.display = opciones.length > 1 ? 'block' : 'none';

  document.getElementById('btn-guardar-procesar').textContent =
    user.role === 'empaque' ? 'Marcar como Completado' : 'Guardar Procesamiento';

  document.getElementById('modal-procesar').classList.add('open');
}

function cerrarModalProcesar() {
  document.getElementById('modal-procesar').classList.remove('open');
  itemActual = null;
}

async function guardarProceso() {
  const { user } = getState();
  if (!itemActual) return;

  const cantidad = Number(document.getElementById('procesar-cantidad').value);
  const select = document.getElementById('procesar-destino');
  const destino = select.value || select.options[0]?.value;
  const observacion = document.getElementById('procesar-obs').value.trim();

  if (!destino) {
    mostrarToast('Selecciona un proceso destino.', 'error');
    return;
  }

  const btn = document.getElementById('btn-guardar-procesar');
  btn.disabled = true;

  try {
    await registrarMovimiento({ item: itemActual, cantidad, destino, observacion, user });
    mostrarToast('Procesamiento registrado correctamente.', 'ok');
    cerrarModalProcesar();
    await refrescarDetalleActual();
    await cargarOrdenes();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}
