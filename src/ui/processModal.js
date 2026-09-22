import { getState } from '../state/appState.js';
import { registrarMovimientosLote } from '../services/movementsService.js';
import { destinosPermitidos, ICONO_PROCESO } from '../lib/roles.js';
import { mostrarToast } from './toast.js';
import { cerrarDetalle } from './orderDetail.js';
import { cargarOrdenes } from './dashboard.js';
import { usuarioEfectivo } from '../services/validatorService.js';

// [{ item, cantidad, pendiente }] — un item por talla incluida en el lote.
let seleccionActual = [];

export function inicializarModalProcesar() {
  document.getElementById('btn-cerrar-procesar').addEventListener('click', cerrarModalProcesar);
  document.getElementById('btn-cancelar-procesar').addEventListener('click', cerrarModalProcesar);
  document.getElementById('btn-guardar-procesar').addEventListener('click', guardarProceso);
}

/**
 * @param {Array<{ item: object, cantidad: number, pendiente: number }>} seleccion
 *   Una fila por cada talla con cantidad > 0 que el usuario cargó antes de
 *   presionar el botón único "Procesar" del encabezado de la orden.
 * @param {boolean} esOrdenCompleta
 *   true si viene de "Procesar toda la orden". El modal se pinta en verde
 *   (el mismo del botón que lo abrió) en vez de azul, para que el usuario
 *   distinga de un vistazo si está cerrando la orden entera o solo una
 *   parte — son dos acciones con consecuencias muy distintas.
 */
export function abrirModalProcesar(seleccion, esOrdenCompleta = false) {
  seleccionActual = seleccion;
  const { destinoConfirmadoOrden } = getState();
  const user = usuarioEfectivo();

  const acento = esOrdenCompleta ? 'var(--green)' : 'var(--blue)';

  const totalUnidades = seleccion.reduce((sum, s) => sum + s.cantidad, 0);
  const detalleHtml = `<span style="color: ${acento};">${totalUnidades.toLocaleString('es-CO')} und(es).</span> en <span style="color: ${acento};">${seleccion.length}</span> talla(s)`;
  document.getElementById('procesar-titulo').innerHTML =
    user.role === 'empaque'
      ? `¿Está seguro que va a marcar como completadas ${detalleHtml}?`
      : `¿Está seguro que va a procesar ${detalleHtml}?`;

  document.getElementById('procesar-resumen').innerHTML = seleccion
    .map(({ item, cantidad }) => `
      <div style="display:flex; justify-content:space-between; padding:7px 0; border-bottom:1px solid var(--border); font-size:13px;">
        <span>Talla ${escapeHtml(String(item.talla))}</span>
        <span style="font-weight:600; color:${acento};">${cantidad.toLocaleString('es-CO')} und(es).</span>
      </div>`)
    .join('');

  // El botón de confirmar acompaña el mismo código de color.
  const btnGuardar = document.getElementById('btn-guardar-procesar');
  btnGuardar.classList.toggle('btn-success', esOrdenCompleta);
  btnGuardar.classList.toggle('btn-primary', !esOrdenCompleta);

  document.getElementById('procesar-obs').value = '';

  // Refilado ya confirmó el destino de TODO el pedido en el encabezado
  // (ver orderDetail.js), asi que aqui no se le vuelve a preguntar: se
  // comporta igual que Acabado/Mateado (destino unico, ver mas abajo).
  const opciones = (user.role === 'refilado' && destinoConfirmadoOrden)
    ? [destinoConfirmadoOrden.destino]
    : destinosPermitidos(user.role);
  const select = document.getElementById('procesar-destino');
  const placeholder = opciones.length > 1 ? '<option value="">Selecciona proceso destino</option>' : '';
  select.innerHTML =
    placeholder +
    opciones
      .map((op) => `<option value="${op}">${op === 'Completado' ? 'Marcar como Completado' : `Enviar a ${op} ${ICONO_PROCESO[op] || ''}`}</option>`)
      .join('');

  const grupoDestino = document.getElementById('procesar-destino-group');
  const infoDestino = document.getElementById('procesar-destino-info');
  const infoTexto = document.getElementById('procesar-destino-info-texto');

  // Cuando el rol solo tiene un destino posible (Acabado/Mateado -> Empaque),
  // ocultamos el selector y en su lugar mostramos un texto informativo con
  // el destino automático. Empaque no necesita este texto: su título ya
  // deja claro que se está marcando como completado.
  if (opciones.length > 1) {
    grupoDestino.style.display = 'block';
    infoDestino.style.display = 'none';
  } else {
    grupoDestino.style.display = 'none';
    const unicoDestino = opciones[0];
    if (unicoDestino && unicoDestino !== 'Completado') {
      infoTexto.textContent = `${unicoDestino} ${ICONO_PROCESO[unicoDestino] || ''}`;
      infoDestino.style.display = 'block';
    } else {
      infoDestino.style.display = 'none';
    }
  }

  document.getElementById('btn-guardar-procesar').textContent =
    user.role === 'empaque' ? 'Marcar como Completado' : 'Guardar Procesamiento';

  document.getElementById('modal-procesar').classList.add('open');
}

function cerrarModalProcesar() {
  document.getElementById('modal-procesar').classList.remove('open');
  seleccionActual = [];

  // Salir sin confirmar debe dejar el detalle como estaba. Antes, si el
  // usuario pulsaba "Procesar toda la orden" y cancelaba, las cantidades
  // quedaban pre-llenadas al pendiente: la orden se veía "armada" sin
  // que nadie lo hubiera decidido, y el siguiente clic la procesaba entera.
  document
    .querySelectorAll('#detalle-contenido .input-cantidad-procesar')
    .forEach((input) => { input.value = ''; });
}

async function guardarProceso() {
  // Rol efectivo: si Validador está actuando como Acabado/Mateado/etc.,
  // el movimiento se registra como si lo hubiera hecho ese rol
  // (from_process correcto), conservando el id real para auditoría.
  const user = usuarioEfectivo();
  if (!seleccionActual.length) return;

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
    // Un solo viaje a la base de datos para TODAS las tallas del lote
    // (antes eran N llamadas seguidas, una por talla). Cada talla sigue
    // quedando como un registro independiente en Registros.
    await registrarMovimientosLote(seleccionActual, { destino, observacion, user });
    mostrarToast('Procesamiento registrado correctamente.', 'ok');
    cerrarModalProcesar();
    // Ya se procesó: cerramos la cartilla y volvemos al listado, en vez
    // de recargar el detalle (evita una consulta pesada innecesaria).
    cerrarDetalle();
    await cargarOrdenes();
  } catch (err) {
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
