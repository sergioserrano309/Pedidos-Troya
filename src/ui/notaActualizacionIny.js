import { getState } from '../state/appState.js';
import { esVistaInyeccion } from '../services/validatorService.js';
import { fetchFrescuraSincronizacion } from '../services/inyeccionService.js';
import { estadoSincronizacion } from '../lib/inyeccion.js';

/**
 * Rótulo "Actualizado hace X min" a la derecha del selector de vista, solo
 * cuando se está en la vista Inyección: Validador con Rol Activo = Inyección,
 * o Empaque con "Ver como: Inyección". Dice qué tan fresco es el dato que la
 * oficina sube desde Access (el mismo de la columna I%). Si está pausado o
 * lleva más de 15 min sin actualizar, avisa en ámbar/rojo.
 */

const MS_REFRESCO = 60 * 1000;
let temporizador = null;

function enVistaInyeccion() {
  return !!getState().user && esVistaInyeccion();
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

/** Muestra u oculta el rótulo según la vista actual y, si toca, lo actualiza. */
export async function refrescarNotaActualizacionIny() {
  const nota = document.getElementById('nota-actualizacion-iny');
  if (!nota) return;

  if (!enVistaInyeccion()) {
    nota.style.display = 'none';
    nota.textContent = '';
    return;
  }

  nota.style.display = '';
  const info = estadoSincronizacion(await fetchFrescuraSincronizacion());
  // La vista pudo cambiar mientras se esperaba la respuesta.
  if (!enVistaInyeccion()) return;

  nota.className = `nota-actualizacion-iny nota-actualizacion-${info.nivel}`;
  nota.innerHTML = info.nivel === 'ok'
    ? escapeHtml(info.texto)
    : `⚠ ${escapeHtml(info.texto)}`;
  nota.title = 'Qué tan al día está el dato de Inyección que sube la oficina desde Access';
}

/** Mantiene el "hace X min" vivo mientras la pantalla esté abierta. */
export function iniciarNotaActualizacionIny() {
  if (temporizador) clearInterval(temporizador);
  temporizador = setInterval(() => {
    const nota = document.getElementById('nota-actualizacion-iny');
    if (!nota || nota.offsetParent === null) return; // oculta: no se consulta
    refrescarNotaActualizacionIny();
  }, MS_REFRESCO);
  refrescarNotaActualizacionIny();
}
