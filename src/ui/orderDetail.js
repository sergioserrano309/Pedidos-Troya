import { fetchOrderDetail, fetchMovimientosOrden } from '../services/ordersService.js';
import { fetchDestinoOrden, confirmarDestinoOrden } from '../services/destinoService.js';
import { getState, setState } from '../state/appState.js';
import { estadoPorPorcentaje } from '../lib/calculations.js';
import { nombreProcesoDeRol, esRolDeProceso, ICONO_PROCESO } from '../lib/roles.js';
import { calcularPendientePorProceso, calcularProcesadoPorProceso } from '../lib/stageQuantities.js';
import { abrirModalProcesar } from './processModal.js';
import { abrirModalDevolucion } from './returnModal.js';
import { mostrarToast } from './toast.js';

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
  document.getElementById('detalle-destino').innerHTML = '';
  document.getElementById('detalle-comentarios').innerHTML = '';
  contenedor.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  modal.classList.add('open');

  setState({ selectedOrderNumber: orderNumber, selectedItem: null, destinoConfirmadoOrden: null });
  actualizarBotonDevolucion();

  try {
    // El enrutamiento automático (pedidos que cumplen una regla) ya lo
    // resuelve el sistema ANTES de que esto se ejecute (ver trigger en
    // supabase/sql/013_auto_enrutamiento_trigger.sql): Refilado nunca
    // llega a abrir estos pedidos porque ordersService.js ya los oculta
    // de su listado. Aquí solo queda leer lo que ya exista.
    const [items, movimientos, destino] = await Promise.all([
      fetchOrderDetail(orderNumber),
      fetchMovimientosOrden(orderNumber),
      fetchDestinoOrden(orderNumber)
    ]);

    setState({ selectedOrderItems: items, selectedOrderMovimientos: movimientos, destinoConfirmadoOrden: destino });

    if (items.length > 0) {
      const firstItem = items[0];
      document.getElementById('detalle-cliente').textContent = firstItem.cliente || '—';
      document.getElementById('detalle-fecha').textContent = formatearFecha(firstItem.fecha_pedido);

      renderEspecificaciones(firstItem);
      renderComentarios(firstItem);
    }

    renderDestinoHeader(orderNumber, destino);
    renderProcesarLoteHeader();
    renderDetalleItems(items, movimientos);
  } catch (err) {
    contenedor.innerHTML = `<div class="empty">${err.message}</div>`;
  }
}

function renderDestinoHeader(orderNumber, destino) {
  const { user } = getState();
  const el = document.getElementById('detalle-destino');
  if (!el) return;

  if (destino) {
    el.innerHTML = `
      <div style="margin-top: 12px; display:flex; align-items:center; gap:8px; font-size: 13px;">
        <span style="color: var(--text2);">Destino confirmado:</span>
        <span style="background:var(--blue-bg); color:var(--blue); padding:4px 10px; border-radius:6px; font-weight:600;">
          ${escapeHtml(destino.destino)} ${ICONO_PROCESO[destino.destino] || ''}
        </span>
        ${destino.es_automatico ? '<span style="font-size:11px; color:var(--text3);">(regla automática)</span>' : ''}
      </div>`;
    return;
  }

  if (user.role !== 'refilado') {
    el.innerHTML = '';
    return;
  }

  el.innerHTML = `
    <div style="margin-top: 12px; padding: 10px 12px; background: var(--amber-bg); border-radius: var(--r); display:flex; align-items:center; gap:10px; flex-wrap:wrap;">
      <span style="font-size:12px; font-weight:600; color:var(--amber-text); text-transform:uppercase;">Confirmar destino del pedido</span>
      <select id="destino-header-select" style="padding:6px 10px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;">
        <option value="">Selecciona...</option>
        <option value="Acabado">Enviar a Acabado ${ICONO_PROCESO.Acabado}</option>
        <option value="Mateado">Enviar a Mateado ${ICONO_PROCESO.Mateado}</option>
        <option value="Empaque">Enviar directo a Empaque ${ICONO_PROCESO.Empaque}</option>
      </select>
      <button class="btn btn-primary btn-sm" id="btn-confirmar-destino">Confirmar</button>
    </div>`;

  document.getElementById('btn-confirmar-destino').addEventListener('click', async () => {
    const select = document.getElementById('destino-header-select');
    const valor = select.value;

    if (!valor) {
      mostrarToast('Selecciona un destino antes de confirmar.', 'error');
      return;
    }

    const btn = document.getElementById('btn-confirmar-destino');
    btn.disabled = true;

    try {
      await confirmarDestinoOrden(orderNumber, valor, user);
      mostrarToast('Destino confirmado para todo el pedido.', 'ok');
      await abrirDetalleOrden(orderNumber);
    } catch (err) {
      mostrarToast(err.message, 'error');
      btn.disabled = false;
    }
  });
}

/**
 * Botón único de "Procesar"/"Marcar Completado" en el encabezado de la
 * orden: recoge la cantidad cargada en CADA talla y los envía todos
 * juntos como un solo lote (cada talla sigue generando su propio
 * registro/movimiento independiente, ver processModal.js).
 */
function renderProcesarLoteHeader() {
  const { user, destinoConfirmadoOrden } = getState();
  const el = document.getElementById('detalle-procesar-lote');
  if (!el) return;

  if (!esRolDeProceso(user.role) || (user.role === 'refilado' && !destinoConfirmadoOrden)) {
    el.innerHTML = '';
    return;
  }

  const texto = user.role === 'empaque' ? 'Marcar Completado' : 'Procesar';
  el.innerHTML = `
    <div style="margin-top: 12px; padding: 10px 14px; background: var(--bg); border-radius: var(--r); display:flex; align-items:center; justify-content:space-between; gap:14px; flex-wrap:wrap;">
      <span style="color:var(--text2); font-weight:600; font-size:12px; text-transform:uppercase; letter-spacing:.05em;">Envío de Proceso</span>
      <div style="display:flex; gap:0.5rem;">
        <button class="btn btn-success btn-sm" id="btn-procesar-todo" title="Llena la cantidad máxima pendiente en cada talla">Procesar Toda la Orden</button>
        <button class="btn btn-primary btn-sm" id="btn-procesar-lote">${texto}</button>
      </div>
    </div>`;

  document.getElementById('btn-procesar-lote').addEventListener('click', abrirResumenLote);
  document.getElementById('btn-procesar-todo').addEventListener('click', () => {
    const contenedor = document.getElementById('detalle-contenido');
    contenedor.querySelectorAll('.input-cantidad-procesar').forEach((input) => {
      input.value = input.dataset.pendiente;
    });
    abrirResumenLote();
  });
}

function abrirResumenLote() {
  const { selectedOrderItems } = getState();
  const contenedor = document.getElementById('detalle-contenido');
  const inputs = contenedor.querySelectorAll('.input-cantidad-procesar');

  const seleccion = [];
  for (const input of inputs) {
    const cantidad = Number(input.value || 0);
    if (cantidad <= 0) continue;

    const idx = Number(input.dataset.idx);
    const pendiente = Number(input.dataset.pendiente);
    const item = selectedOrderItems[idx];

    if (cantidad > pendiente) {
      mostrarToast(`Talla ${item.talla}: no puedes procesar ${cantidad}, solo quedan ${pendiente} pendientes en este proceso.`, 'error');
      return;
    }

    seleccion.push({ item, cantidad, pendiente });
  }

  if (seleccion.length === 0) {
    mostrarToast('Ingresa al menos una cantidad a procesar.', 'error');
    return;
  }

  abrirModalProcesar(seleccion);
}

/** Vuelve a cargar el detalle de la orden actualmente abierta (si hay alguna). Usado tras registrar un movimiento/devolución o por realtime. */
export async function refrescarDetalleActual() {
  const { selectedOrderNumber } = getState();
  const modal = document.getElementById('modal-detalle');
  if (selectedOrderNumber && modal.classList.contains('open')) {
    await abrirDetalleOrden(selectedOrderNumber);
  }
}

function filaEspec(label, valueHtml) {
  return `<div style="display:flex; align-items:center; gap:14px; margin-bottom:14px;">
    <div style="width:110px; flex-shrink:0; color:var(--text2);">${label}</div>
    <div>${valueHtml}</div>
  </div>`;
}

function badgeSiNo(valor) {
  const bg = valor ? 'var(--green-bg)' : 'var(--red-bg)';
  const color = valor ? 'var(--green-text)' : 'var(--red-text)';
  return `<span style="background:${bg}; color:${color}; padding:4px 12px; border-radius:5px; font-size:13px; font-weight:600; display:inline-block;">${valor ? 'Sí' : 'No'}</span>`;
}

function renderEspecificaciones(item) {
  let html = '';

  if (item.referencia) html += filaEspec('Referencia', `<strong>${escapeHtml(item.referencia)}</strong>`);
  if (item.color) html += filaEspec('Color', `<strong>${escapeHtml(item.color)}</strong>`);
  if (item.material) html += filaEspec('Material', `<strong>${escapeHtml(item.material)}</strong>`);
  if (item.vira !== undefined) html += filaEspec('Vira', badgeSiNo(item.vira));
  if (item.acabado_spec !== undefined) html += filaEspec('Acabado', badgeSiNo(item.acabado_spec));
  if (item.esterilla !== undefined) html += filaEspec('Esterilla', badgeSiNo(item.esterilla));
  if (item.marquilla !== undefined) html += filaEspec('Marquilla', badgeSiNo(item.marquilla));

  document.getElementById('detalle-especificaciones').innerHTML = html;
}

function renderComentarios(item) {
  const comentarios = [];

  if (item.detalle_vira?.trim()) {
    comentarios.push(`<div style="margin-bottom: 4px;"><strong>Detalles Vira:</strong> ${escapeHtml(item.detalle_vira)}</div>`);
  }
  if (item.detalle_acabado?.trim()) {
    comentarios.push(`<div style="margin-bottom: 4px;"><strong>Detalles Acabado:</strong> ${escapeHtml(item.detalle_acabado)}</div>`);
  }
  if (item.detalle_esterilla?.trim()) {
    comentarios.push(`<div style="margin-bottom: 4px;"><strong>Detalles Esterilla:</strong> ${escapeHtml(item.detalle_esterilla)}</div>`);
  }

  if (comentarios.length > 0) {
    document.getElementById('detalle-comentarios').innerHTML =
      `<div style="background: var(--bg); padding: 10px 12px; border-radius: 6px; border-left: 3px solid var(--blue); font-size: 13px; color: var(--text);">
        ${comentarios.join('')}
      </div>`;
  }
}

function renderDetalleItems(items, movimientos) {
  const { user, destinoConfirmadoOrden } = getState();
  const contenedor = document.getElementById('detalle-contenido');

  if (items.length === 0) {
    contenedor.innerHTML = '<div class="empty">Esta orden no tiene ítems.</div>';
    return;
  }

  const procesoDelRol = nombreProcesoDeRol(user.role);
  const esProceso = esRolDeProceso(user.role);

  contenedor.innerHTML = items
    .map((item, idx) => {
      let procesadoMostrado = item.cantidad_procesada;
      let pendienteMostrado = item.cantidad_pendiente;
      let pendienteEnMiProceso = 0;
      let sinEnviar = false;
      let estado;

      if (esProceso) {
        pendienteEnMiProceso = calcularPendientePorProceso(item, movimientos, procesoDelRol);
        const procesadoEnMiProceso = calcularProcesadoPorProceso(item, movimientos, procesoDelRol);
        const entradaEnMiProceso = pendienteEnMiProceso + procesadoEnMiProceso;

        procesadoMostrado = procesadoEnMiProceso;
        pendienteMostrado = pendienteEnMiProceso;
        sinEnviar = entradaEnMiProceso === 0;

        estado = sinEnviar
          ? null
          : estadoPorPorcentaje(Math.round((procesadoEnMiProceso / entradaEnMiProceso) * 100));
      } else {
        estado = estadoPorPorcentaje(item.porcentaje_completado || 0);
      }

      const completado = estado === 'completado' || sinEnviar;
      // Refilado debe confirmar primero el destino de TODO el pedido en
      // el encabezado (ver renderDestinoHeader) antes de poder procesar
      // cualquier item; los demas roles de proceso no lo necesitan.
      const puedeProcesar = esProceso && pendienteEnMiProceso > 0 && (user.role !== 'refilado' || !!destinoConfirmadoOrden);
      const puedeDevolver = user.role === 'comercial';

      const badgeHtml = sinEnviar
        ? `<span class="estado-badge estado-etapa-previa">${escapeHtml(item.etapa_actual)}</span>`
        : `<span class="estado-badge estado-${estado}">${estado.replace('-', ' ')}</span>`;

      return `
        <div class="card-orden" data-idx="${idx}" style="padding:0.85rem 1rem; margin-bottom:0.75rem; cursor:default; background:${completado ? 'var(--bg)' : 'var(--surface)'}; border:1px solid ${completado ? 'var(--border2)' : 'var(--border)'};">
          <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.65rem;">
            <div class="orden-num">Talla ${escapeHtml(item.talla)}</div>
            ${badgeHtml}
          </div>
          <div style="display:flex; align-items:center; gap:2rem; flex-wrap:wrap;">
            <div class="stat-item"><div class="stat-label">Solicitado</div><div class="stat-value">${item.cantidad_solicitada}</div></div>
            <div class="stat-item"><div class="stat-label">Procesado</div><div class="stat-value">${procesadoMostrado}</div></div>
            <div class="stat-item"><div class="stat-label">Pendiente</div><div class="stat-value">${pendienteMostrado}</div></div>
            <div class="stat-item"><div class="stat-label">Etapa actual</div><div class="stat-value">${escapeHtml(item.etapa_actual)} ${ICONO_PROCESO[item.etapa_actual] || ''}</div></div>
            ${puedeProcesar ? `
            <div class="stat-item">
              <div class="stat-label">Cantidad a Procesar</div>
              <input type="number" class="input-cantidad-procesar" data-idx="${idx}" data-pendiente="${pendienteEnMiProceso}" min="1" max="${pendienteEnMiProceso}" placeholder="0" style="width:80px; padding:5px 8px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;">
            </div>` : ''}
            <div style="margin-left:auto; display:flex; gap:0.5rem;">
              ${puedeDevolver ? `<button class="btn btn-danger btn-sm btn-item-devolver" data-idx="${idx}">🔄 Devolver</button>` : ''}
            </div>
          </div>
        </div>
      `;
    })
    .join('');

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

export function cerrarDetalle() {
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
