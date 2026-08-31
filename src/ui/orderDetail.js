import { fetchOrderDetail, fetchMovimientosOrden } from '../services/ordersService.js';
import { fetchDestinoOrden, confirmarDestinoOrden, cambiarDestinoOrden } from '../services/destinoService.js';
import { getState, setState } from '../state/appState.js';
import { estadoPorPorcentaje } from '../lib/calculations.js';
import { nombreProcesoDeRol, esRolDeProceso, ICONO_PROCESO } from '../lib/roles.js';
import { calcularPendientePorProceso, calcularProcesadoPorProceso } from '../lib/stageQuantities.js';
import { abrirModalProcesar } from './processModal.js';
import { abrirModalDevolucion } from './returnModal.js';
import { mostrarToast } from './toast.js';
import { usuarioEfectivo } from '../services/validatorService.js';

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
    }

    renderDestinoHeader(orderNumber, destino, movimientos);
    renderProcesarLoteHeader();
    renderDetalleItems(items, movimientos);
  } catch (err) {
    contenedor.innerHTML = `<div class="empty">${err.message}</div>`;
  }
}

/**
 * El destino es inmutable en cuanto la orden tiene al menos un
 * movimiento registrado, o si fue asignado automáticamente por una
 * regla de enrutamiento (ese caso NUNCA se vuelve editable a mano,
 * tenga o no movimientos — es una decisión de negocio, no una
 * limitación técnica).
 *
 * Si el destino es manual y la orden todavía no tiene ningún
 * movimiento (ej.: Refilado se equivocó de destino y borró todos los
 * registros), vuelve a mostrarse el mismo selector de "elegir destino"
 * para REEMPLAZARLO — ver cambiarDestinoOrden en destinoService.js. La
 * autoridad real de "solo si no hay movimientos" vive en la política
 * RLS de DELETE (supabase/sql/022_permitir_cambio_destino_sin_movimientos.sql),
 * este chequeo aquí es solo para decidir qué UI mostrar.
 */
function renderDestinoHeader(orderNumber, destino, movimientos) {
  const effectiveUser = usuarioEfectivo();
  const el = document.getElementById('detalle-destino');
  if (!el) return;

  const sinMovimientos = movimientos.length === 0;
  const esCambio = !!destino;
  const esEditable = destino && !destino.es_automatico && sinMovimientos && effectiveUser.role === 'refilado';

  if (destino && !esEditable) {
    el.innerHTML = `
      <div class="destino-row">
        <span class="destino-label">Destino confirmado</span>
        <span class="destino-valor">${escapeHtml(destino.destino)} ${ICONO_PROCESO[destino.destino] || ''}</span>
      </div>
      <div class="orden-divider"></div>`;
    return;
  }

  if (!destino && effectiveUser.role !== 'refilado') {
    el.innerHTML = '';
    return;
  }

  const titulo = esCambio ? 'Cambiar destino del pedido' : 'Confirmar destino del pedido';
  // Al cambiar un destino ya confirmado, se precarga el valor actual en
  // el select — así el usuario ve de entrada qué queda seleccionado, en
  // vez de un "Selecciona..." vacío que sugiere que no eligió nada.
  const valorActual = esCambio ? destino.destino : '';

  el.innerHTML = `
    <div style="padding-bottom:4px;">
      <div style="font-size:13px; color:var(--text2); font-weight:600; margin-bottom:12px;">${titulo}</div>
      <select class="destino-select" id="destino-header-select">
        <option value="" ${valorActual === '' ? 'selected' : ''}>Selecciona...</option>
        <option value="Acabado" ${valorActual === 'Acabado' ? 'selected' : ''}>Acabado ${ICONO_PROCESO.Acabado}</option>
        <option value="Mateado" ${valorActual === 'Mateado' ? 'selected' : ''}>Mateado ${ICONO_PROCESO.Mateado}</option>
        <option value="Empaque" ${valorActual === 'Empaque' ? 'selected' : ''}>Empaque ${ICONO_PROCESO.Empaque}</option>
      </select>
      <button class="btn-confirmar-destino" id="btn-confirmar-destino">Confirmar</button>
    </div>
    <div class="orden-divider"></div>`;

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
      if (esCambio) {
        await cambiarDestinoOrden(orderNumber, valor, effectiveUser);
        mostrarToast('Destino actualizado.', 'ok');
      } else {
        await confirmarDestinoOrden(orderNumber, valor, effectiveUser);
        mostrarToast('Destino confirmado para todo el pedido.', 'ok');
      }
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
  const { destinoConfirmadoOrden } = getState();
  const effectiveUser = usuarioEfectivo();
  const el = document.getElementById('detalle-procesar-lote');
  if (!el) return;

  if (!esRolDeProceso(effectiveUser.role) || (effectiveUser.role === 'refilado' && !destinoConfirmadoOrden)) {
    el.innerHTML = '';
    return;
  }

  el.innerHTML = `
    <div class="procesamiento-titulo">Procesamiento</div>
    <button class="btn-procesar-todo" id="btn-procesar-todo">
      <svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <circle cx="12" cy="12" r="9" stroke="white" stroke-width="1.6"/>
        <path d="M8 12.3l2.6 2.6L16 9.3" stroke="white" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
      </svg>
      Procesar toda la orden
    </button>
    <button class="btn-procesar-parcial" id="btn-procesar-lote">Procesar Parcial</button>
    <div class="orden-divider"></div>`;

  document.getElementById('btn-procesar-lote').addEventListener('click', abrirResumenLote);
  document.getElementById('btn-procesar-todo').addEventListener('click', () => {
    const contenedor = document.getElementById('detalle-contenido');
    contenedor.querySelectorAll('.input-cantidad-procesar').forEach((input) => {
      input.value = input.dataset.pendiente;
    });
    abrirResumenLote();
  });
}

/** Valor de texto plano (Color/Material): '—' si no hay dato, nunca se omite la columna. */
function valorTexto(valor) {
  return valor ? escapeHtml(valor) : '<span style="color:var(--text3);">—</span>';
}

/** Valor Sí/No (Vira/Acabado/Esterilla/Marquilla): badge, o '—' si el campo no aplica a este ítem. */
function valorBooleano(valor) {
  if (valor === undefined || valor === null) return '<span style="color:var(--text3);">—</span>';
  return `<span class="attr-badge ${valor ? 'si' : 'no'}">${valor ? 'Sí' : 'No'}</span>`;
}

function celdaAtributo(label, valueHtml) {
  return `<div class="attr-cell"><div class="attr-label">${label}</div><div class="attr-value">${valueHtml}</div></div>`;
}

/**
 * SIEMPRE renderiza las 6 celdas (Color/Material/Vira/Acabado/Esterilla/
 * Marquilla) aunque algún campo no exista en el ítem — así las columnas
 * de ambas filas quedan garantizadas a coincidir (un único CSS grid
 * compartido, ver .attrs-grid en index.html). Omitir celdas condicionalmente
 * fue lo que causaba el desalineamiento entre filas.
 */
function renderEspecificaciones(item) {
  let html = '';

  if (item.referencia) {
    html += `<div class="detalle-referencia">
      <div class="attr-label">Referencia</div>
      <div class="attr-value">${escapeHtml(item.referencia)}</div>
    </div>`;
  }

  html += `<div class="attrs-grid">
    ${celdaAtributo('Color', valorTexto(item.color))}
    ${celdaAtributo('Material', valorTexto(item.material))}
    ${celdaAtributo('Vira', valorBooleano(item.vira))}
    ${celdaAtributo('Acabado', valorBooleano(item.acabado_spec))}
    ${celdaAtributo('Esterilla', valorBooleano(item.esterilla))}
    ${celdaAtributo('Marquilla', valorBooleano(item.marquilla))}
  </div>`;

  if (item.detalle_vira?.trim()) {
    html += `<div class="detalle-nota">
      <div class="attr-label">Detalle Vira</div>
      <div class="attr-value">${escapeHtml(item.detalle_vira)}</div>
    </div>`;
  }

  if (item.detalle_acabado?.trim()) {
    html += `<div class="detalle-nota">
      <div class="attr-label">Detalle Acabado</div>
      <div class="attr-value">${escapeHtml(item.detalle_acabado)}</div>
    </div>`;
  }

  if (item.detalle_esterilla?.trim()) {
    html += `<div class="detalle-nota">
      <div class="attr-label">Detalle Esterilla</div>
      <div class="attr-value">${escapeHtml(item.detalle_esterilla)}</div>
    </div>`;
  }

  html += '<div class="orden-divider"></div>';

  document.getElementById('detalle-especificaciones').innerHTML = html;
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


function renderDetalleItems(items, movimientos) {
  const { user, destinoConfirmadoOrden } = getState();
  const effectiveUser = usuarioEfectivo();
  const contenedor = document.getElementById('detalle-contenido');

  if (items.length === 0) {
    contenedor.innerHTML = '<div class="empty">Esta orden no tiene ítems.</div>';
    return;
  }

  const procesoDelRol = nombreProcesoDeRol(effectiveUser.role);
  const esProceso = esRolDeProceso(effectiveUser.role);

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
      const puedeProcesar = esProceso && pendienteEnMiProceso > 0 && (effectiveUser.role !== 'refilado' || !!destinoConfirmadoOrden);
      // Devoluciones quedan atadas al rol REAL (no al rol emulado): es
      // una función exclusiva de Comercial, fuera del alcance de "actuar
      // como" que tiene Validador.
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
          <div class="item-stats-row">
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
