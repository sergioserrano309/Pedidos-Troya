import { fetchOrderDetail } from '../services/ordersService.js';
import { getState, setState } from '../state/appState.js';
import { estadoPorPorcentaje } from '../lib/calculations.js';
import { nombreProcesoDeRol, esRolDeProceso } from '../lib/roles.js';
import { abrirModalProcesar } from './processModal.js';
import { abrirModalDevolucion } from './returnModal.js';

export function inicializarModalDetalle() {
  document.getElementById('btn-cerrar-detalle').addEventListener('click', cerrarDetalle);
  document.getElementById('btn-cerrar-detalle-2').addEventListener('click', cerrarDetalle);
  document.getElementById('btn-devolucion').addEventListener('click', () => {
    const { selectedItem } = getState();
    if (selectedItem) abrirModalDevolucion(selectedItem);
  });
}

export async function abrirDetalleOrden(orderNumber) {
  const modal = document.getElementById('modal-detalle');
  const contenedor = document.getElementById('detalle-contenido');

  document.getElementById('detalle-pedido').textContent = orderNumber;
  document.getElementById('detalle-cliente').textContent = '';
  document.getElementById('detalle-fecha').textContent = '';
  document.getElementById('detalle-especificaciones').innerHTML = '';
  document.getElementById('detalle-comentarios').innerHTML = '';
  contenedor.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  modal.classList.add('open');

  setState({ selectedOrderNumber: orderNumber, selectedItem: null });
  actualizarBotonDevolucion();

  try {
    const items = await fetchOrderDetail(orderNumber);
    setState({ selectedOrderItems: items });

    if (items.length > 0) {
      const firstItem = items[0];
      document.getElementById('detalle-cliente').textContent = firstItem.cliente || '—';
      document.getElementById('detalle-fecha').textContent = formatearFecha(firstItem.fecha_pedido);

      renderEspecificaciones(firstItem);
      renderComentarios(firstItem);
    }

    renderDetalleItems(items);
  } catch (err) {
    contenedor.innerHTML = `<div class="empty">${err.message}</div>`;
  }
}

/** Vuelve a cargar el detalle de la orden actualmente abierta (si hay alguna). Usado tras registrar un movimiento/devolución o por realtime. */
export async function refrescarDetalleActual() {
  const { selectedOrderNumber } = getState();
  const modal = document.getElementById('modal-detalle');
  if (selectedOrderNumber && modal.classList.contains('open')) {
    await abrirDetalleOrden(selectedOrderNumber);
  }
}

function renderEspecificaciones(item) {
  const specs = [];

  if (item.referencia) specs.push(`Referencia: ${escapeHtml(item.referencia)}`);
  if (item.color) specs.push(`Color: ${escapeHtml(item.color)}`);
  if (item.material) specs.push(`Material: ${escapeHtml(item.material)}`);

  const flags = [];
  if (item.vira) flags.push('Vira ✓');
  if (item.acabado_spec) flags.push('Acabado ✓');
  if (item.esterilla) flags.push('Esterilla ✓');
  if (item.marquilla) flags.push('Marquilla ✓');

  if (flags.length > 0) specs.push(flags.join(' • '));

  document.getElementById('detalle-especificaciones').innerHTML = specs.join(' • ');
}

function renderComentarios(item) {
  const comentarios = [];

  if (item.detalle_vira?.trim()) {
    comentarios.push(`<div style="margin-bottom: 8px;"><strong>Detalles Vira:</strong> ${escapeHtml(item.detalle_vira)}</div>`);
  }
  if (item.detalle_acabado?.trim()) {
    comentarios.push(`<div style="margin-bottom: 8px;"><strong>Detalles Acabado:</strong> ${escapeHtml(item.detalle_acabado)}</div>`);
  }
  if (item.detalle_esterilla?.trim()) {
    comentarios.push(`<div style="margin-bottom: 8px;"><strong>Detalles Esterilla:</strong> ${escapeHtml(item.detalle_esterilla)}</div>`);
  }

  if (comentarios.length > 0) {
    document.getElementById('detalle-comentarios').innerHTML =
      `<div style="background: var(--bg); padding: 10px 12px; border-radius: 6px; border-left: 3px solid var(--blue);">
        ${comentarios.join('')}
      </div>`;
  }
}

function renderDetalleItems(items) {
  const { user } = getState();
  const contenedor = document.getElementById('detalle-contenido');

  if (items.length === 0) {
    contenedor.innerHTML = '<div class="empty">Esta orden no tiene ítems.</div>';
    return;
  }

  const procesoDelRol = nombreProcesoDeRol(user.role);

  contenedor.innerHTML = items
    .map((item, idx) => {
      const progreso = item.porcentaje_completado || 0;
      const estado = estadoPorPorcentaje(progreso);
      const puedeProcesar = esRolDeProceso(user.role) && item.etapa_actual === procesoDelRol;
      const puedeDevolver = user.role === 'comercial';

      return `
        <div class="card-orden" data-idx="${idx}">
          <div class="orden-header">
            <div>
              <div class="orden-num">Talla ${escapeHtml(item.talla)}</div>
            </div>
            <span class="estado-badge estado-${estado}">${estado.replace('-', ' ')}</span>
          </div>
          <div class="orden-stats">
            <div class="stat-item"><div class="stat-label">Solicitado</div><div class="stat-value">${item.cantidad_solicitada}</div></div>
            <div class="stat-item"><div class="stat-label">Procesado</div><div class="stat-value">${item.cantidad_procesada}</div></div>
            <div class="stat-item"><div class="stat-label">Pendiente</div><div class="stat-value">${item.cantidad_pendiente}</div></div>
            <div class="stat-item"><div class="stat-label">Etapa actual</div><div class="stat-value">${escapeHtml(item.etapa_actual)}</div></div>
          </div>
          <div style="display:flex; gap:0.5rem; margin-top:0.75rem;">
            ${puedeProcesar ? `<button class="btn btn-primary btn-sm btn-item-procesar" data-idx="${idx}">${user.role === 'empaque' ? 'Marcar Completado' : 'Procesar'}</button>` : ''}
            ${puedeDevolver ? `<button class="btn btn-danger btn-sm btn-item-devolver" data-idx="${idx}">🔄 Devolver</button>` : ''}
          </div>
        </div>
      `;
    })
    .join('');

  contenedor.querySelectorAll('.btn-item-procesar').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const idx = Number(btn.dataset.idx);
      abrirModalProcesar(getState().selectedOrderItems[idx]);
    });
  });

  contenedor.querySelectorAll('.btn-item-devolver').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const idx = Number(btn.dataset.idx);
      const item = getState().selectedOrderItems[idx];
      setState({ selectedItem: item });
      actualizarBotonDevolucion();
      abrirModalDevolucion(item);
    });
  });

  contenedor.querySelectorAll('.card-orden').forEach((card) => {
    card.addEventListener('click', () => {
      const idx = Number(card.dataset.idx);
      setState({ selectedItem: getState().selectedOrderItems[idx] });
      actualizarBotonDevolucion();
    });
  });
}

function actualizarBotonDevolucion() {
  const { user, selectedItem } = getState();
  const btn = document.getElementById('btn-devolucion');
  if (user?.role === 'comercial') {
    btn.style.display = 'inline-block';
    btn.disabled = !selectedItem;
    btn.title = selectedItem ? '' : 'Selecciona un ítem de la lista primero';
  } else {
    btn.style.display = 'none';
  }
}

function cerrarDetalle() {
  document.getElementById('modal-detalle').classList.remove('open');
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
