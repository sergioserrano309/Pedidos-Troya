import { fetchHistory } from '../services/historyService.js';
import { eliminarMovimientoConMotivo } from '../services/movementsService.js';
import { getState } from '../state/appState.js';
import { mostrarToast } from './toast.js';
import { ICONO_PROCESO } from '../lib/roles.js';

const PAGE_SIZE = 50;
const COLSPAN = 13;

let paginaActual = 0;
let totalRegistros = 0;
let filtroOrden = '';
let filtroFecha = '';
let debounceTimer = null;

export function inicializarPaginaHistorial() {
  const inputOrden = document.getElementById('registros-filtro-orden');
  inputOrden.addEventListener('input', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      filtroOrden = inputOrden.value.trim();
      paginaActual = 0;
      cargarHistorial();
    }, 350);
  });

  const inputFecha = document.getElementById('registros-filtro-fecha');
  inputFecha.addEventListener('input', () => {
    filtroFecha = inputFecha.value;
    paginaActual = 0;
    cargarHistorial();
  });
}

export async function cargarHistorial() {
  const { user } = getState();
  if (!user) return;

  const tbody = document.getElementById('registros-tabla');
  tbody.innerHTML = `<tr><td colspan="${COLSPAN}" class="empty">Cargando...</td></tr>`;

  try {
    const { history, count } = await fetchHistory(user, { page: paginaActual, orden: filtroOrden, fecha: filtroFecha });
    totalRegistros = count;
    renderHistorial(history);
    renderPaginacion();
  } catch (err) {
    tbody.innerHTML = `<tr><td colspan="${COLSPAN}" class="empty">${err.message}</td></tr>`;
    mostrarToast(err.message, 'error');
  }
}

function badgeSiNo(valor) {
  const bg = valor ? 'var(--green-bg)' : 'var(--red-bg)';
  const color = valor ? 'var(--green-text)' : 'var(--red-text)';
  return `<span style="background:${bg}; color:${color}; padding:3px 10px; border-radius:5px; font-size:12px; font-weight:600; display:inline-block;">${valor ? 'Sí' : 'No'}</span>`;
}

function formatearHora24(fecha) {
  const horas = String(fecha.getHours()).padStart(2, '0');
  const minutos = String(fecha.getMinutes()).padStart(2, '0');
  return `${horas}:${minutos}`;
}

function conIcono(proceso) {
  const icono = ICONO_PROCESO[proceso];
  return icono ? `${escapeHtml(proceso)} ${icono}` : escapeHtml(proceso || '—');
}

function renderHistorial(rows) {
  const { user } = getState();
  const tbody = document.getElementById('registros-tabla');

  if (rows.length === 0) {
    tbody.innerHTML = `<tr><td colspan="${COLSPAN}" class="empty">Sin actividad registrada.</td></tr>`;
    return;
  }

  tbody.innerHTML = rows
    .map((row) => {
      const fecha = new Date(row.created_at);
      const rol = row.tipo === 'devolucion' ? `Devolución (${row.action})` : row.from_process;
      // Solo se puede eliminar un movimiento propio (no devoluciones,
      // que tienen sus propias reglas). El backend valida además que sea
      // el mas reciente de esa talla, ver eliminar_movimiento_con_motivo.
      const puedeEliminar = row.tipo === 'movimiento' && row.user_id === user?.id;

      return `
        <tr>
          <td>${escapeHtml(row.order_number)}</td>
          <td>${escapeHtml(row.user_name || '—')}</td>
          <td>${escapeHtml(rol)}</td>
          <td>${conIcono(row.to_process)}</td>
          <td>${row.quantity}</td>
          <td>${fecha.toLocaleDateString('es-CO')}</td>
          <td>${formatearHora24(fecha)}</td>
          <td>${escapeHtml(row.observation || '—')}</td>
          <td>${badgeSiNo(row.paso_refilado)}</td>
          <td>${badgeSiNo(row.paso_mateado)}</td>
          <td>${badgeSiNo(row.paso_acabado)}</td>
          <td>${badgeSiNo(row.paso_empaque)}</td>
          <td>${puedeEliminar ? `<button class="btn btn-danger btn-sm btn-eliminar-registro" data-id="${row.id}">Eliminar</button>` : ''}</td>
        </tr>
      `;
    })
    .join('');

  tbody.querySelectorAll('.btn-eliminar-registro').forEach((btn) => {
    btn.addEventListener('click', () => eliminarRegistro(btn.dataset.id));
  });
}

async function eliminarRegistro(id) {
  const motivo = prompt('Indica el motivo por el que eliminas este registro (obligatorio):');
  if (motivo === null) return;
  if (!motivo.trim()) {
    mostrarToast('Debes indicar un motivo para eliminar el registro.', 'error');
    return;
  }

  try {
    await eliminarMovimientoConMotivo(id, motivo.trim());
    mostrarToast('Registro eliminado correctamente.', 'ok');
    cargarHistorial();
  } catch (err) {
    mostrarToast(err.message, 'error');
  }
}

function renderPaginacion() {
  const el = document.getElementById('registros-paginacion');
  const totalPaginas = Math.max(Math.ceil(totalRegistros / PAGE_SIZE), 1);

  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="hist-pag-prev" ${paginaActual === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${paginaActual + 1} de ${totalPaginas}</span>
    <button class="btn btn-secondary btn-sm" id="hist-pag-next" ${paginaActual + 1 >= totalPaginas ? 'disabled' : ''}>Siguiente →</button>
  `;

  document.getElementById('hist-pag-prev')?.addEventListener('click', () => {
    paginaActual = Math.max(paginaActual - 1, 0);
    cargarHistorial();
  });
  document.getElementById('hist-pag-next')?.addEventListener('click', () => {
    paginaActual += 1;
    cargarHistorial();
  });
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
