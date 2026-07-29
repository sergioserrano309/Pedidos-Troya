import { getState } from '../state/appState.js';
import { registrarDevolucion } from '../services/returnsService.js';
import { mostrarToast } from './toast.js';
import { refrescarDetalleActual } from './orderDetail.js';
import { cargarOrdenes } from './dashboard.js';

let itemActual = null;

export function inicializarModalDevolucion() {
  document.getElementById('btn-cerrar-devolucion').addEventListener('click', cerrarModalDevolucion);
  document.getElementById('btn-cancelar-devolucion').addEventListener('click', cerrarModalDevolucion);
  document.getElementById('btn-guardar-devolucion').addEventListener('click', guardarDevolucion);

  document.querySelectorAll('input[name="dev-accion"]').forEach((radio) => {
    radio.addEventListener('change', actualizarAccion);
  });
}

export function abrirModalDevolucion(item) {
  itemActual = item;

  document.getElementById('dev-pedido').value = item.order_number ?? '';
  document.getElementById('dev-talla').value = item.talla ?? '';
  document.getElementById('dev-cantidad').value = '';
  document.getElementById('dev-causal').value = '';
  document.getElementById('dev-proceso').value = '';
  document.getElementById('dev-obs').value = '';
  document.querySelectorAll('input[name="dev-accion"]').forEach((r) => {
    r.checked = false;
  });
  document.getElementById('dev-reproceso-destino-group').style.display = 'none';
  document.getElementById('dev-reproceso-destino').value = '';

  document.getElementById('modal-devolucion').classList.add('open');
}

function cerrarModalDevolucion() {
  document.getElementById('modal-devolucion').classList.remove('open');
  itemActual = null;
}

function actualizarAccion() {
  const accion = document.querySelector('input[name="dev-accion"]:checked')?.value;
  document.getElementById('dev-reproceso-destino-group').style.display = accion === 'REPROCESO' ? 'block' : 'none';
}

async function guardarDevolucion() {
  const { user } = getState();
  if (!itemActual) return;

  const cantidad = Number(document.getElementById('dev-cantidad').value);
  const causal = document.getElementById('dev-causal').value;
  const procesoFalla = document.getElementById('dev-proceso').value;
  const accion = document.querySelector('input[name="dev-accion"]:checked')?.value;
  const destinoReproceso = document.getElementById('dev-reproceso-destino').value;
  const observacion = document.getElementById('dev-obs').value.trim();

  const btn = document.getElementById('btn-guardar-devolucion');
  btn.disabled = true;

  try {
    await registrarDevolucion({
      item: itemActual,
      cantidad,
      causal,
      procesoFalla,
      accion,
      destinoReproceso: accion === 'REPROCESO' ? destinoReproceso : null,
      observacion,
      user
    });
    mostrarToast('Devolución registrada correctamente.', 'ok');
    cerrarModalDevolucion();
    await refrescarDetalleActual();
    await cargarOrdenes();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}
