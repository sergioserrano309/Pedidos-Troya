import { fetchHistory } from '../services/historyService.js';
import { getState } from '../state/appState.js';
import { mostrarToast } from './toast.js';

const PAGE_SIZE = 50;

let paginaActual = 0;
let totalRegistros = 0;
let terminoBusqueda = '';
let debounceTimer = null;

export function inicializarPaginaHistorial() {
  const buscador = document.getElementById('historial-buscar');
  buscador.addEventListener('input', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      terminoBusqueda = buscador.value.trim();
      paginaActual = 0;
      cargarHistorial();
    }, 350);
  });
}

export async function cargarHistorial() {
  const { user } = getState();
  if (!user) return;

  const tbody = document.getElementById('historial-tabla');
  tbody.innerHTML = '<tr><td colspan="7" class="empty">Cargando...</td></tr>';

  try {
    const { history, count } = await fetchHistory(user, { page: paginaActual, search: terminoBusqueda });
    totalRegistros = count;
    renderHistorial(history);
    renderPaginacion();
  } catch (err) {
    tbody.innerHTML = `<tr><td colspan="7" class="empty">${err.message}</td></tr>`;
    mostrarToast(err.message, 'error');
  }
}

function renderHistorial(rows) {
  const tbody = document.getElementById('historial-tabla');

  if (rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" class="empty">Sin actividad registrada.</td></tr>';
    return;
  }

  tbody.innerHTML = rows
    .map((row) => {
      const fecha = new Date(row.created_at);
      const accion =
        row.tipo === 'devolucion'
          ? `Devolución (${row.action}) — ${row.from_process} → ${row.to_process}`
          : `Procesado — ${row.from_process} → ${row.to_process}`;

      return `
        <tr>
          <td>${escapeHtml(row.order_number)}</td>
          <td>${escapeHtml(row.user_name || '—')}</td>
          <td>${escapeHtml(accion)}</td>
          <td>${row.quantity}</td>
          <td>${fecha.toLocaleDateString('es-CO')}</td>
          <td>${fecha.toLocaleTimeString('es-CO')}</td>
          <td>${escapeHtml(row.observation || '—')}</td>
        </tr>
      `;
    })
    .join('');
}

function renderPaginacion() {
  const el = document.getElementById('historial-paginacion');
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
