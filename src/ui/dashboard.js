import { fetchOrders } from '../services/ordersService.js';
import { getState, setState } from '../state/appState.js';
import { estadoPorPorcentaje } from '../lib/calculations.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { mostrarToast } from './toast.js';

const PAGE_SIZE = 20;

let paginaActual = 0;
let totalRegistros = 0;
let terminoBusqueda = '';
let debounceTimer = null;

export function inicializarPaginaOrdenes() {
  document.querySelectorAll('#page-ordenes .tab-btn[data-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#page-ordenes .tab-btn[data-tab]').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      setState({ currentTab: btn.dataset.tab });
      paginaActual = 0;
      cargarOrdenes();
    });
  });

  const buscador = document.getElementById('ordenes-buscar');
  buscador.addEventListener('input', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      terminoBusqueda = buscador.value.trim();
      paginaActual = 0;
      cargarOrdenes();
    }, 350);
  });
}

export async function cargarOrdenes() {
  const { user, currentTab } = getState();
  if (!user) return;

  const contenedor = document.getElementById('ordenes-lista');
  contenedor.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando órdenes...</div>';

  try {
    const { orders, count } = await fetchOrders(user, currentTab, {
      page: paginaActual,
      search: terminoBusqueda
    });
    totalRegistros = count;
    setState({ orders });
    renderOrdenes(orders);
    renderPaginacion();
  } catch (err) {
    contenedor.innerHTML = `<div class="card"><div class="empty">${err.message}</div></div>`;
    mostrarToast(err.message, 'error');
  }
}

function renderOrdenes(orders) {
  const contenedor = document.getElementById('ordenes-lista');

  if (orders.length === 0) {
    contenedor.innerHTML = '<div class="card"><div class="empty">No hay órdenes para mostrar.</div></div>';
    return;
  }

  contenedor.innerHTML = orders
    .map((orden) => {
      const progreso = orden.porcentaje_completado || 0;
      const estado = estadoPorPorcentaje(progreso);

      return `
        <div class="card-orden" data-order="${escapeHtml(orden.order_number)}">
          <div class="orden-header">
            <div>
              <div class="orden-num">Orden ${escapeHtml(orden.order_number)}</div>
              <div class="orden-cliente">${escapeHtml(orden.cliente || '—')}</div>
            </div>
            <div style="text-align:right;">
              <div class="orden-fecha">${formatearFecha(orden.fecha_pedido)}</div>
              <span class="estado-badge estado-${estado}">${estado.replace('-', ' ')}</span>
            </div>
          </div>
          <div class="orden-divider"></div>
          <div class="orden-stats">
            <div class="stat-item">
              <div class="stat-label">Total Suelas</div>
              <div class="stat-value">${orden.total_solicitado ?? 0}</div>
            </div>
            <div class="stat-item">
              <div class="stat-label">Procesadas</div>
              <div class="stat-value">${orden.total_procesado ?? 0}</div>
            </div>
            <div class="stat-item">
              <div class="stat-label">Pendientes</div>
              <div class="stat-value">${orden.total_pendiente ?? 0}</div>
            </div>
            <div class="stat-item">
              <div class="stat-label">Ítems</div>
              <div class="stat-value">${orden.total_items ?? 0}</div>
            </div>
          </div>
          <div class="progress-bar"><div class="progress-fill" style="width:${progreso}%"></div></div>
          <div class="progress-text">${progreso}% completado</div>
        </div>
      `;
    })
    .join('');

  contenedor.querySelectorAll('.card-orden').forEach((card) => {
    card.addEventListener('click', () => abrirDetalleOrden(card.dataset.order));
  });
}

function renderPaginacion() {
  const el = document.getElementById('ordenes-paginacion');
  const totalPaginas = Math.max(Math.ceil(totalRegistros / PAGE_SIZE), 1);

  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="orden-pag-prev" ${paginaActual === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${paginaActual + 1} de ${totalPaginas}</span>
    <button class="btn btn-secondary btn-sm" id="orden-pag-next" ${paginaActual + 1 >= totalPaginas ? 'disabled' : ''}>Siguiente →</button>
  `;

  document.getElementById('orden-pag-prev')?.addEventListener('click', () => {
    paginaActual = Math.max(paginaActual - 1, 0);
    cargarOrdenes();
  });
  document.getElementById('orden-pag-next')?.addEventListener('click', () => {
    paginaActual += 1;
    cargarOrdenes();
  });
}

function formatearFecha(fecha) {
  if (!fecha) return '—';
  try {
    return new Date(fecha).toLocaleDateString('es-CO');
  } catch {
    return String(fecha);
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
