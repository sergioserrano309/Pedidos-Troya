import { fetchHistory } from '../services/historyService.js';
import { eliminarMovimientoConMotivo } from '../services/movementsService.js';
import { getState } from '../state/appState.js';
import { mostrarToast } from './toast.js';
import { esValidador, obtenerRolActivo } from '../services/validatorService.js';
import { formatearCOP } from '../lib/money.js';

const PAGE_SIZE = 50;
const COLSPAN_VALIDADOR = 16; // +1 por checkbox
const COLSPAN_NORMAL = 10; // +1 por checkbox

let paginaActual = 0;
let totalRegistros = 0;
let filtroOrden = '';
let filtroFecha = '';
let filtroProceso = '';
let debounceTimer = null;
let idRegistroAEliminar = null;
let registrosSeleccionados = new Set(); // IDs de registros seleccionados para eliminar múltiples

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

  const selectProceso = document.getElementById('registros-filtro-proceso');
  selectProceso?.addEventListener('change', () => {
    filtroProceso = selectProceso.value;
    paginaActual = 0;
    cargarHistorial();
  });

  document.getElementById('btn-cerrar-eliminar-registro').addEventListener('click', cerrarModalEliminarRegistro);
  document.getElementById('btn-cancelar-eliminar-registro').addEventListener('click', cerrarModalEliminarRegistro);
  document.getElementById('btn-confirmar-eliminar-registro').addEventListener('click', confirmarEliminarRegistro);

  document.getElementById('btn-cerrar-detalle-registro').addEventListener('click', cerrarModalDetalleRegistro);

  // Multi-selector
  document.getElementById('btn-eliminar-multiples-registros').addEventListener('click', abrirModalEliminarMultiples);
  document.getElementById('btn-cerrar-eliminar-multiples').addEventListener('click', cerrarModalEliminarMultiples);
  document.getElementById('btn-cancelar-eliminar-multiples').addEventListener('click', cerrarModalEliminarMultiples);
  document.getElementById('btn-confirmar-eliminar-multiples').addEventListener('click', confirmarEliminarMultiples);

  // Sincronizar scroll vertical entre las dos tablas
  const scrollSection = document.getElementById('registros-scroll-section');
  const fixedSection = document.getElementById('registros-fixed-section');
  if (scrollSection && fixedSection) {
    scrollSection.addEventListener('scroll', () => {
      fixedSection.scrollTop = scrollSection.scrollTop;
    });
  }
}

/**
 * Se llama DESPUÉS del login (main.js -> iniciarApp), cuando ya se
 * conoce el rol del usuario — inicializarPaginaHistorial() corre antes
 * del login (bootstrap) y en ese momento getState().user es null.
 */
export function configurarFiltroProcesoHistorial(user) {
  const selectProceso = document.getElementById('registros-filtro-proceso');
  if (selectProceso) {
    // Este dropdown manual solo es para Comercial. Validador ya tiene su
    // propio control ("Rol Activo" en la topbar) que cumple el mismo
    // propósito — mostrar ambos era información duplicada/contradictoria.
    selectProceso.style.display = user?.role === 'comercial' ? '' : 'none';
  }

  // Columnas Usuario/Rol/Refilado/Mateado/Acabado/Empaque: solo tienen
  // sentido para Validador (ve registros de TODOS los usuarios/procesos
  // a la vez). Para cualquier otro rol son ruido — cada quien ya sabe
  // que es su propio registro y su propio proceso.
  const esVal = user?.role === 'validador';
  document.querySelectorAll('#registros-seccion .col-validador-only').forEach((th) => {
    th.style.display = esVal ? '' : 'none';
  });
}

export async function cargarHistorial() {
  const { user } = getState();
  if (!user) return;

  const tbodyFixed = document.getElementById('registros-tabla-fixed');
  const tbodyScroll = document.getElementById('registros-tabla-scroll');
  tbodyFixed.innerHTML = `<tr><td colspan="6" class="empty">Cargando...</td></tr>`;
  tbodyScroll.innerHTML = `<tr><td colspan="10" class="empty">Cargando...</td></tr>`;

  // Para Validador, el proceso a filtrar viene de "Rol Activo" (no del
  // dropdown, que queda oculto para él). "Validador" (vista maestra) no
  // filtra por proceso: ve todo, de cualquier proceso.
  let procesoEfectivo = filtroProceso;
  if (esValidador()) {
    const rolActivo = obtenerRolActivo();
    procesoEfectivo = rolActivo === 'Validador' ? '' : rolActivo;
  }

  try {
    const { history, count } = await fetchHistory(user, { page: paginaActual, orden: filtroOrden, fecha: filtroFecha, proceso: procesoEfectivo });
    totalRegistros = count;
    renderHistorial(history);
    renderPaginacion();
  } catch (err) {
    tbodyFixed.innerHTML = `<tr><td colspan="6" class="empty">${err.message}</td></tr>`;
    tbodyScroll.innerHTML = `<tr><td colspan="10" class="empty">${err.message}</td></tr>`;
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

/**
 * Solo la letra del proceso, con el mismo color que usa Validador en
 * Control Central/listado (R=azul, A=verde, M=morado, E=ámbar).
 */
function letraProceso(proceso) {
  const estilos = {
    Refilado: { letra: 'R', bg: 'var(--blue-bg)', color: 'var(--blue)' },
    Acabado: { letra: 'A', bg: 'var(--green-bg)', color: 'var(--green-text)' },
    Mateado: { letra: 'M', bg: 'var(--purple-bg)', color: 'var(--purple-text)' },
    Empaque: { letra: 'E', bg: 'var(--amber-bg)', color: 'var(--amber-text)' },
    // Cuando Empaque marca como terminado, to_process pasa a ser el
    // texto "Completado" (no "Empaque") — pero sigue siendo trabajo de
    // Empaque, así que se muestra igual: E ámbar, sin una 5ta letra.
    Completado: { letra: 'E', bg: 'var(--amber-bg)', color: 'var(--amber-text)' }
  };
  const s = estilos[proceso];
  if (!s) return escapeHtml(proceso || '—');
  return `<span style="background:${s.bg}; color:${s.color}; padding:2px 9px; border-radius:4px; font-weight:700; font-size:12px;">${s.letra}</span>`;
}

/** Solo día/mes (d/mm) — el Excel mantiene el formato de fecha completo. */
function formatearFechaCorta(fecha) {
  const dia = fecha.getDate();
  const mes = String(fecha.getMonth() + 1).padStart(2, '0');
  return `${dia}/${mes}`;
}

function renderHistorial(rows) {
  const { user } = getState();
  const esVal = user?.role === 'validador';

  const tbodyFixed = document.getElementById('registros-tabla-fixed');
  const tbodyScroll = document.getElementById('registros-tabla-scroll');

  if (rows.length === 0) {
    tbodyFixed.innerHTML = `<tr><td colspan="6" class="empty">Sin actividad registrada.</td></tr>`;
    tbodyScroll.innerHTML = `<tr><td colspan="10" class="empty">Sin actividad registrada.</td></tr>`;
    return;
  }

  const rowsHtml = rows.map((row) => {
    const fecha = new Date(row.created_at);
    const rol = row.tipo === 'devolucion' ? `Devolución (${row.action})` : row.from_process;
    const puedeEliminar = row.tipo === 'movimiento' && row.user_id === user?.id;

    const celdasValidadorFixed = esVal
      ? `
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${escapeHtml(row.user_name || '—')}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${escapeHtml(rol)}</td>
      `
      : '';

    const celdasProcesos = esVal
      ? `
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${badgeSiNo(row.paso_refilado)}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${badgeSiNo(row.paso_mateado)}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${badgeSiNo(row.paso_acabado)}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${badgeSiNo(row.paso_empaque)}</td>
      `
      : '';

    const esSeleccionado = registrosSeleccionados.has(row.id);
    const checkbox = puedeEliminar
      ? `<input type="checkbox" class="checkbox-registro" data-id="${row.id}" data-orden="${row.order_number}" data-fecha="${formatearFechaCorta(fecha)}" ${esSeleccionado ? 'checked' : ''}>`
      : '';

    // Fila fija (checkbox, orden, usuario/rol, envío, Q)
    const filaFixed = `
      <tr style="height:auto;">
        <td style="padding:0.5rem; text-align:center; border-bottom:1px solid var(--border2); font-size:13px;">${checkbox}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${escapeHtml(row.order_number)}</td>
        ${celdasValidadorFixed}
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${letraProceso(row.to_process)}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${row.quantity}</td>
      </tr>
    `;

    // Fila scrollable (precio, comisión, fecha, hora, detalles, badges, botón)
    const filaScroll = `
      <tr style="height:auto;">
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${row.precio_cop != null ? formatearCOP(row.precio_cop) : '—'}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${row.valor_cop != null ? formatearCOP(row.valor_cop) : '—'}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${formatearFechaCorta(fecha)}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${formatearHora24(fecha)}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px; max-width:80px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; ${row.observation ? 'cursor:pointer; color:var(--blue);' : ''}" ${row.observation ? `class="celda-detalle-registro" data-detalle="${escapeHtml(row.observation)}"` : ''}>${row.observation ? escapeHtml(row.observation) : '—'}</td>
        ${celdasProcesos}
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${puedeEliminar ? `<button class="btn-eliminar-registro" data-id="${row.id}" title="Eliminar registro" aria-label="Eliminar registro">×</button>` : ''}</td>
      </tr>
    `;

    return { filaFixed, filaScroll, id: row.id, puedeEliminar };
  });

  tbodyFixed.innerHTML = rowsHtml.map(r => r.filaFixed).join('');
  tbodyScroll.innerHTML = rowsHtml.map(r => r.filaScroll).join('');

  // Sincronizar alturas de filas entre tabla fija y scrollable
  sincronizarAlturasFilas();

  // Checkbox "Seleccionar todos"
  const checkboxSeleccionarTodos = document.getElementById('checkbox-seleccionar-todos');
  if (checkboxSeleccionarTodos) {
    checkboxSeleccionarTodos.addEventListener('change', () => {
      const checkboxes = tbodyFixed.querySelectorAll('.checkbox-registro');
      if (checkboxSeleccionarTodos.checked) {
        checkboxes.forEach((checkbox) => {
          checkbox.checked = true;
          registrosSeleccionados.add(checkbox.dataset.id);
        });
      } else {
        checkboxes.forEach((checkbox) => {
          checkbox.checked = false;
          registrosSeleccionados.delete(checkbox.dataset.id);
        });
      }
      actualizarBotonEliminarMultiples();
    });
  }

  // Checkboxes para multi-selector
  tbodyFixed.querySelectorAll('.checkbox-registro').forEach((checkbox) => {
    checkbox.addEventListener('change', () => {
      if (checkbox.checked) {
        registrosSeleccionados.add(checkbox.dataset.id);
      } else {
        registrosSeleccionados.delete(checkbox.dataset.id);
      }
      actualizarBotonEliminarMultiples();
      // Actualizar estado del checkbox "Seleccionar todos"
      const checkboxes = tbodyFixed.querySelectorAll('.checkbox-registro');
      const todosSeleccionados = Array.from(checkboxes).every(cb => cb.checked);
      const algunoSeleccionado = Array.from(checkboxes).some(cb => cb.checked);
      checkboxSeleccionarTodos.checked = todosSeleccionados;
      checkboxSeleccionarTodos.indeterminate = algunoSeleccionado && !todosSeleccionados;
    });
  });

  // Botones individuales de eliminar (en tabla scroll)
  tbodyScroll.querySelectorAll('.btn-eliminar-registro').forEach((btn) => {
    btn.addEventListener('click', () => abrirModalEliminarRegistro(btn.dataset.id));
  });

  tbodyScroll.querySelectorAll('.celda-detalle-registro').forEach((celda) => {
    celda.addEventListener('click', () => abrirModalDetalleRegistro(celda.dataset.detalle));
  });
}

function abrirModalDetalleRegistro(texto) {
  document.getElementById('detalle-registro-texto').textContent = texto;
  document.getElementById('modal-detalle-registro').classList.add('open');
}

function cerrarModalDetalleRegistro() {
  document.getElementById('modal-detalle-registro').classList.remove('open');
}

function sincronizarAlturasFilas() {
  const tbodyFixed = document.getElementById('registros-tabla-fixed');
  const tbodyScroll = document.getElementById('registros-tabla-scroll');

  const filasFixed = tbodyFixed.querySelectorAll('tr');
  const filasScroll = tbodyScroll.querySelectorAll('tr');

  // Esperar a que el DOM se renderice completamente
  requestAnimationFrame(() => {
    filasFixed.forEach((filaFixed, index) => {
      const filaScroll = filasScroll[index];
      if (!filaScroll) return;

      const alturaFixed = filaFixed.offsetHeight;
      const alturaScroll = filaScroll.offsetHeight;
      const alturaMaxima = Math.max(alturaFixed, alturaScroll);

      // Establecer ambas filas con la misma altura
      filaFixed.style.height = alturaMaxima + 'px';
      filaScroll.style.height = alturaMaxima + 'px';
    });
  });
}

function abrirModalEliminarRegistro(id) {
  idRegistroAEliminar = id;
  document.getElementById('eliminar-registro-motivo').value = '';
  document.getElementById('modal-eliminar-registro').classList.add('open');
}

function cerrarModalEliminarRegistro() {
  document.getElementById('modal-eliminar-registro').classList.remove('open');
  idRegistroAEliminar = null;
}

async function confirmarEliminarRegistro() {
  if (!idRegistroAEliminar) return;

  const motivo = document.getElementById('eliminar-registro-motivo').value.trim();
  if (!motivo) {
    mostrarToast('Debes indicar un motivo para eliminar el registro.', 'error');
    return;
  }

  const btn = document.getElementById('btn-confirmar-eliminar-registro');
  btn.disabled = true;

  try {
    await eliminarMovimientoConMotivo(idRegistroAEliminar, motivo);
    mostrarToast('Registro eliminado correctamente.', 'ok');
    cerrarModalEliminarRegistro();
    cargarHistorial();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}

// ===== MULTI-SELECTOR DE REGISTROS =====

function actualizarBotonEliminarMultiples() {
  const btnEliminar = document.getElementById('btn-eliminar-multiples-registros');
  if (!btnEliminar) return;

  if (registrosSeleccionados.size > 0) {
    btnEliminar.style.display = 'inline-block';
    btnEliminar.textContent = `Eliminar ${registrosSeleccionados.size} registro${registrosSeleccionados.size > 1 ? 's' : ''}`;
  } else {
    btnEliminar.style.display = 'none';
  }
}

function abrirModalEliminarMultiples() {
  if (registrosSeleccionados.size === 0) {
    mostrarToast('Selecciona al menos un registro para eliminar.', 'error');
    return;
  }

  const tbodyFixed = document.getElementById('registros-tabla-fixed');
  const detalles = [];

  registrosSeleccionados.forEach((id) => {
    const checkbox = tbodyFixed.querySelector(`.checkbox-registro[data-id="${id}"]`);
    if (checkbox) {
      detalles.push({
        orden: checkbox.dataset.orden,
        fecha: checkbox.dataset.fecha
      });
    }
  });

  const lista = detalles
    .map((d) => `<tr><td>${escapeHtml(d.orden)}</td><td>${escapeHtml(d.fecha)}</td></tr>`)
    .join('');

  document.getElementById('eliminar-multiples-lista').innerHTML = `
    <table style="width:100%; font-size:13px;">
      <thead>
        <tr><th>Orden</th><th>Fecha</th></tr>
      </thead>
      <tbody>${lista}</tbody>
    </table>`;

  document.getElementById('eliminar-multiples-motivo').value = '';
  document.getElementById('modal-eliminar-multiples-registros').classList.add('open');
}

function cerrarModalEliminarMultiples() {
  document.getElementById('modal-eliminar-multiples-registros').classList.remove('open');
}

async function confirmarEliminarMultiples() {
  const motivo = document.getElementById('eliminar-multiples-motivo').value.trim();
  if (!motivo) {
    mostrarToast('Debes indicar un motivo para eliminar los registros.', 'error');
    return;
  }

  const btn = document.getElementById('btn-confirmar-eliminar-multiples');
  btn.disabled = true;

  try {
    // Eliminar todos los registros seleccionados
    for (const id of registrosSeleccionados) {
      await eliminarMovimientoConMotivo(id, motivo);
    }

    const cantidad = registrosSeleccionados.size;
    mostrarToast(`${cantidad} registro${cantidad > 1 ? 's' : ''} eliminado${cantidad > 1 ? 's' : ''} correctamente.`, 'ok');
    cerrarModalEliminarMultiples();
    registrosSeleccionados.clear();
    actualizarBotonEliminarMultiples();
    cargarHistorial();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
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
