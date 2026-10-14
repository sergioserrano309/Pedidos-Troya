import { fetchHistory } from '../services/historyService.js';
import { eliminarMovimientoConMotivo, eliminarMovimientosConMotivo } from '../services/movementsService.js';
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
let filtroDespacho = '';
let debounceTimer = null;
let debounceDespacho = null;
let idRegistroAEliminar = null;
let registrosSeleccionados = new Set(); // IDs de registros seleccionados para eliminar múltiples

export function inicializarPaginaHistorial() {
  const inputOrden = document.getElementById('registros-filtro-orden');
  inputOrden.addEventListener('input', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      filtroOrden = inputOrden.value.trim();
      paginaActual = 0;
      limpiarSeleccion();
      cargarHistorial();
    }, 350);
  });

  const inputFecha = document.getElementById('registros-filtro-fecha');
  inputFecha.addEventListener('input', () => {
    filtroFecha = inputFecha.value;
    paginaActual = 0;
    limpiarSeleccion();
    cargarHistorial();
  });

  const inputDespacho = document.getElementById('registros-filtro-despacho');
  inputDespacho?.addEventListener('input', () => {
    clearTimeout(debounceDespacho);
    debounceDespacho = setTimeout(() => {
      filtroDespacho = inputDespacho.value.trim();
      paginaActual = 0;
      limpiarSeleccion();
      cargarHistorial();
    }, 350);
  });

  const selectProceso = document.getElementById('registros-filtro-proceso');
  selectProceso?.addEventListener('change', () => {
    filtroProceso = selectProceso.value;
    paginaActual = 0;
    limpiarSeleccion();
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

  // Delegación de eventos de ambas tablas, registrada UNA sola vez. El
  // clic-en-fila para seleccionar solo aplica a la tabla simple: en la
  // del Validador la fila está partida en dos tablas y el gesto sería
  // ambiguo.
  wirearDelegacionTabla(document.getElementById('registros-simple'), true);
  wirearDelegacionTabla(document.getElementById('registros-wrapper'), false);

  // Sincronizar scroll vertical entre las dos tablas (solo Validador)
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

  // Filtro por ID de despacho: solo Empaque, que es quien despacha y el
  // único que ve la columna ID Despacho.
  const campoDespacho = document.getElementById('registros-campo-despacho');
  if (campoDespacho) campoDespacho.style.display = user?.role === 'empaque' ? '' : 'none';

  // Desde la Fase 8 hay DOS tablas distintas, no una que se recorta:
  //   - Validador: la tabla doble con paneles congelados y todas las
  //     columnas (precio, comisión, hora, detalles, badges por proceso).
  //   - Los demás roles: una tabla simple, operativa, sin congelación.
  // Separarlas elimina el acoplamiento entre <th> ocultos por CSS y <td>
  // omitidos por JS, que es de donde salían las desalineaciones.
  const esVal = user?.role === 'validador';
  const wrapper = document.getElementById('registros-wrapper');
  const simple = document.getElementById('registros-simple');
  if (wrapper) wrapper.style.display = esVal ? 'flex' : 'none';
  if (simple) simple.style.display = esVal ? 'none' : 'block';

  // En la tabla del Validador todas las columnas van visibles siempre.
  document.querySelectorAll('#registros-wrapper .col-validador-only, #registros-wrapper .col-despacho-only')
    .forEach((th) => { th.style.display = esVal ? '' : 'none'; });
}

export async function cargarHistorial() {
  const { user } = getState();
  if (!user) return;

  mensajeEnTablas('Cargando...');

  // Para Validador, el proceso a filtrar viene de "Rol Activo" (no del
  // dropdown, que queda oculto para él). "Validador" (vista maestra) no
  // filtra por proceso: ve todo, de cualquier proceso.
  let procesoEfectivo = filtroProceso;
  if (esValidador()) {
    const rolActivo = obtenerRolActivo();
    procesoEfectivo = rolActivo === 'Validador' ? '' : rolActivo;
  }

  try {
    const { history, count } = await fetchHistory(user, { page: paginaActual, orden: filtroOrden, fecha: filtroFecha, proceso: procesoEfectivo, despacho: filtroDespacho });
    totalRegistros = count;
    renderHistorial(history);
    renderPaginacion();
  } catch (err) {
    mensajeEnTablas(err.message);
    mostrarToast(err.message, 'error');
  }
}

/** Mensaje de estado en la tabla que esté visible (simple o Validador). */
function mensajeEnTablas(texto) {
  const seguro = escapeHtml(texto);
  const fixed = document.getElementById('registros-tabla-fixed');
  const scroll = document.getElementById('registros-tabla-scroll');
  const simple = document.getElementById('registros-simple-body');
  if (fixed) fixed.innerHTML = `<tr><td colspan="6" class="empty">${seguro}</td></tr>`;
  if (scroll) scroll.innerHTML = `<tr><td colspan="13" class="empty">${seguro}</td></tr>`;
  if (simple) simple.innerHTML = `<tr><td colspan="9" class="empty">${seguro}</td></tr>`;
}

/**
 * La selección no debe sobrevivir a un cambio de página o de filtro: el
 * Set guardaba ids de filas que ya no están a la vista, y el borrado
 * múltiple SÍ los borraba aunque el modal no llegara a listarlos.
 */
function limpiarSeleccion() {
  registrosSeleccionados.clear();
  actualizarBotonEliminarMultiples();
  sincronizarSeleccionarTodos();
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

/**
 * Checkbox y botón de eliminar de una fila. Lo comparten las dos tablas
 * (la simple y la del Validador) para que las reglas de bloqueo sean
 * idénticas en ambas.
 *
 * Los tres motivos por los que el servidor rechaza un borrado se
 * reflejan aquí ANTES de que el usuario escriba un motivo en vano:
 *   - no es suyo            -> ni checkbox ni botón
 *   - (060) el registro es de Empaque y quitarlo dejaría menos unidades
 *     empacadas que despachadas en esa talla (reemplaza al bloqueo 046 por
 *     "talla con algún despacho") -> botón gris, sin checkbox
 *   - (059) hay un registro posterior del MISMO proceso en esa talla, o el
 *     proceso que recibió esas unidades ya las usó -> ídem (la columna
 *     tiene_movimiento_posterior de vw_historial ya trae esa regla)
 */
function metaFila(row) {
  const { user } = getState();
  const fecha = new Date(row.created_at);

  const puedeEliminar = row.tipo === 'movimiento' && row.user_id === user?.id;
  // 060: bloquea solo si quitar este registro de Empaque dejaría menos unidades
  // empacadas que despachadas (antes: cualquier talla con algún despacho).
  const bloqueadoPorDespacho = puedeEliminar && !!row.bloqueado_por_despacho;
  const bloqueadoPorPosterior = puedeEliminar && !bloqueadoPorDespacho && !!row.tiene_movimiento_posterior;
  const bloqueado = bloqueadoPorDespacho || bloqueadoPorPosterior;

  // Sin checkbox si está bloqueado: el borrado múltiple es un bucle sin
  // transacción, así que incluir uno bloqueado abortaría el lote a medias.
  const checkbox =
    puedeEliminar && !bloqueado
      ? `<input type="checkbox" class="checkbox-registro" data-id="${escapeHtml(row.id)}" data-orden="${escapeHtml(row.order_number)}" data-talla="${escapeHtml(row.size ?? '')}" data-cantidad="${row.quantity ?? 0}" data-fecha="${formatearFechaCorta(fecha)}" ${registrosSeleccionados.has(row.id) ? 'checked' : ''}>`
      : '';

  let boton = '';
  if (bloqueadoPorDespacho) {
    boton = `<button class="btn-eliminar-registro" disabled title="Este registro cubre unidades de la talla ${escapeHtml(row.size ?? '')} del pedido ${escapeHtml(row.order_number)} que ya fueron despachadas. Elimina primero ese despacho en Despachos > Despachado." aria-label="Eliminar registro (bloqueado: unidades ya despachadas)">×</button>`;
  } else if (bloqueadoPorPosterior) {
    boton = `<button class="btn-eliminar-registro" disabled title="No se puede eliminar todavía: hay un registro posterior de tu proceso en esta talla, o el proceso siguiente ya usó estas unidades. Elimina primero ese registro." aria-label="Eliminar registro (bloqueado: hay un registro posterior que depende de este)">×</button>`;
  } else if (puedeEliminar) {
    boton = `<button class="btn-eliminar-registro" data-id="${escapeHtml(row.id)}" title="Eliminar registro" aria-label="Eliminar registro">×</button>`;
  }

  return { checkbox, boton };
}

/**
 * Columnas de la tabla simple (todos los roles menos Validador).
 *
 * Header y celda salen del MISMO descriptor a propósito: mientras las
 * dos se generen de aquí, es imposible que la tabla quede corrida.
 */
function columnasSimples(verDespacho) {
  const cols = [
    { th: 'Orden', td: (r) => escapeHtml(r.order_number) },
    // En Empaque "Envío" siempre dice E (Completado): en celular no aporta
    // y se oculta. En los demás roles indica el destino y se deja.
    { th: 'Envío', td: (r) => letraProceso(r.to_process), ocultaMovil: verDespacho },
    { th: 'Q', td: (r) => r.quantity, centro: true },
    { th: 'Fecha', td: (r) => formatearFechaCorta(new Date(r.created_at)) },
    // Solo el número de talla, sin la palabra "Talla" delante.
    { th: 'Talla', td: (r) => escapeHtml(r.size ?? '—'), centro: true }
  ];

  if (verDespacho) {
    // Fecha e ID de la remesa en que salieron las unidades de ESTE
    // registro (049). Si un registro salió repartido, muestra la fecha de
    // la última remesa y ambos IDs.
    cols.push({
      th: 'Despacho',
      corto: 'F.Desp',
      td: (r) => (r.despacho_fecha_registro ? formatearFechaCorta(new Date(r.despacho_fecha_registro)) : '—')
    });
    cols.push({
      th: 'ID Despacho',
      corto: 'Desp',
      td: (r) => (r.despacho_consecutivo
        ? `<span style="font-weight:600; color:var(--blue); white-space:nowrap;">${escapeHtml(r.despacho_consecutivo)}</span>`
        : '—')
    });
    cols.push({
      th: 'Confirmado',
      corto: 'Conf',
      td: (r) => (r.fecha_despacho ? badgeSiNo(r.despacho_confirmado) : '—'),
      centro: true
    });
  }

  return cols;
}

/** Nombre completo en PC; el corto (si lo hay) en celular. */
function encabezado(col) {
  if (!col.corto) return col.th;
  return `<span class="cart-lbl-full">${col.th}</span><span class="cart-lbl-short">${col.corto}</span>`;
}

/** Tabla simple: encabezado y filas generados juntos. */
function renderHistorialSimple(rows, verDespacho) {
  const thead = document.getElementById('registros-simple-head');
  const tbody = document.getElementById('registros-simple-body');
  if (!thead || !tbody) return;

  const cols = columnasSimples(verDespacho);
  const total = cols.length + 2; // checkbox + acción

  thead.innerHTML = `
    <tr>
      <th style="width:36px; padding:0.5rem; text-align:center; font-size:13px; font-weight:600;">
        <input type="checkbox" id="checkbox-seleccionar-todos-simple" class="checkbox-registro">
      </th>
      ${cols.map((c) => `<th class="${c.ocultaMovil ? 'col-oculta-movil' : ''}" style="padding:0.5rem; text-align:${c.centro ? 'center' : 'left'}; font-size:13px; font-weight:600;">${encabezado(c)}</th>`).join('')}
      <th style="width:44px; padding:0.5rem;"></th>
    </tr>
  `;

  if (rows.length === 0) {
    tbody.innerHTML = `<tr><td colspan="${total}" class="empty">Sin actividad registrada.</td></tr>`;
    return;
  }

  const celda = 'padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;';

  tbody.innerHTML = rows
    .map((row) => {
      const meta = metaFila(row);
      return `
        <tr data-id="${escapeHtml(row.id)}">
          <td style="${celda} text-align:center;">${meta.checkbox}</td>
          ${cols.map((c) => `<td class="${c.ocultaMovil ? 'col-oculta-movil' : ''}" style="${celda}${c.centro ? ' text-align:center;' : ''}">${c.td(row)}</td>`).join('')}
          <td style="${celda} text-align:center;">${meta.boton}</td>
        </tr>
      `;
    })
    .join('');
}

function renderHistorial(rows) {
  const { user } = getState();
  const esVal = user?.role === 'validador';
  const verDespacho = user?.role === 'empaque' || esVal;

  // Todos los roles menos Validador usan la tabla simple.
  if (!esVal) {
    renderHistorialSimple(rows, verDespacho);
    sincronizarSeleccionarTodos();
    return;
  }

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

    // Fecha de despacho + estado de confirmación del pedido. La comisión
    // de Empaque solo suma en Compensación si ambas están en verde (040);
    // aquí se muestran para que el operario entienda por qué su registro
    // todavía no aparece liquidado.
    const celdasDespacho = verDespacho
      ? `
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${row.fecha_despacho ? formatearFechaCorta(new Date(row.fecha_despacho)) : '—'}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${row.fecha_despacho ? badgeSiNo(row.despacho_confirmado) : '—'}</td>
      `
      : '';

    const { checkbox, boton: botonEliminar } = metaFila(row);

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
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${escapeHtml(row.size ?? '—')}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${row.precio_cop != null ? formatearCOP(row.precio_cop) : '—'}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${row.valor_cop != null ? formatearCOP(row.valor_cop) : '—'}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${formatearFechaCorta(fecha)}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;">${formatearHora24(fecha)}</td>
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px; max-width:80px; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; ${row.observation ? 'cursor:pointer; color:var(--blue);' : ''}" ${row.observation ? `class="celda-detalle-registro" data-detalle="${escapeHtml(row.observation)}"` : ''}>${row.observation ? escapeHtml(row.observation) : '—'}</td>
        ${celdasProcesos}
        ${celdasDespacho}
        <td style="padding:0.5rem; border-bottom:1px solid var(--border2); text-align:center; font-size:13px;">${botonEliminar}</td>
      </tr>
    `;

    return { filaFixed, filaScroll };
  });

  tbodyFixed.innerHTML = rowsHtml.map(r => r.filaFixed).join('');
  tbodyScroll.innerHTML = rowsHtml.map(r => r.filaScroll).join('');

  // Sincronizar alturas de filas entre tabla fija y scrollable
  sincronizarAlturasFilas();

  sincronizarSeleccionarTodos();
}

/**
 * Listeners de las tablas, por DELEGACIÓN sobre el contenedor (que es
 * permanente) en vez de sobre las filas (que se regeneran en cada
 * render). Antes se re-enganchaban en cada render y se iban acumulando:
 * tras N paginaciones, un solo clic disparaba N veces.
 *
 * Se registra una sola vez, desde inicializarPaginaHistorial().
 */
function wirearDelegacionTabla(contenedor, permitirClicEnFila) {
  if (!contenedor) return;

  contenedor.addEventListener('click', (e) => {
    const btn = e.target.closest('.btn-eliminar-registro');
    if (btn) {
      if (!btn.disabled) abrirModalEliminarRegistro(btn.dataset.id);
      return;
    }

    const celdaDetalle = e.target.closest('.celda-detalle-registro');
    if (celdaDetalle) {
      abrirModalDetalleRegistro(celdaDetalle.dataset.detalle);
      return;
    }

    // Clic en cualquier punto de la fila alterna su selección. El propio
    // checkbox se excluye: ya se alterna solo, y volver a tocarlo aquí
    // lo dejaría como estaba.
    if (!permitirClicEnFila) return;
    if (e.target.closest('.checkbox-registro')) return;

    const fila = e.target.closest('tr');
    const checkbox = fila?.querySelector('.checkbox-registro');
    if (!checkbox) return;
    checkbox.checked = !checkbox.checked;
    checkbox.dispatchEvent(new Event('change', { bubbles: true }));
  });

  contenedor.addEventListener('change', (e) => {
    const el = e.target;

    if (el.id === 'checkbox-seleccionar-todos' || el.id === 'checkbox-seleccionar-todos-simple') {
      contenedor.querySelectorAll('tbody .checkbox-registro').forEach((cb) => {
        cb.checked = el.checked;
        if (el.checked) registrosSeleccionados.add(cb.dataset.id);
        else registrosSeleccionados.delete(cb.dataset.id);
      });
      actualizarBotonEliminarMultiples();
      return;
    }

    if (el.classList.contains('checkbox-registro')) {
      if (el.checked) registrosSeleccionados.add(el.dataset.id);
      else registrosSeleccionados.delete(el.dataset.id);
      actualizarBotonEliminarMultiples();
      sincronizarSeleccionarTodos();
    }
  });
}

/** Deja el checkbox maestro coherente con lo que hay marcado abajo. */
function sincronizarSeleccionarTodos() {
  ['checkbox-seleccionar-todos', 'checkbox-seleccionar-todos-simple'].forEach((id) => {
    const maestro = document.getElementById(id);
    if (!maestro) return;
    const tabla = maestro.closest('table');
    const checkboxes = [...(tabla?.querySelectorAll('tbody .checkbox-registro') || [])];
    if (checkboxes.length === 0) {
      maestro.checked = false;
      maestro.indeterminate = false;
      return;
    }
    const todos = checkboxes.every((cb) => cb.checked);
    const alguno = checkboxes.some((cb) => cb.checked);
    maestro.checked = todos;
    maestro.indeterminate = alguno && !todos;
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

/**
 * Datos de los registros seleccionados, leídos de los data-* del
 * checkbox. Como limpiarSeleccion() se llama al cambiar de página o de
 * filtro, el Set solo contiene filas que están a la vista.
 */
function seleccionDetallada() {
  const items = [];
  document.querySelectorAll('#registros-seccion .checkbox-registro[data-id]').forEach((cb) => {
    if (!registrosSeleccionados.has(cb.dataset.id)) return;
    items.push({
      id: cb.dataset.id,
      orden: cb.dataset.orden || '—',
      talla: cb.dataset.talla || '—',
      cantidad: Number(cb.dataset.cantidad) || 0,
      fecha: cb.dataset.fecha || '—'
    });
  });
  return items;
}

function actualizarBotonEliminarMultiples() {
  const btn = document.getElementById('btn-eliminar-multiples-registros');
  const aviso = document.getElementById('eliminar-multiples-aviso');
  if (!btn) return;

  const items = seleccionDetallada();

  if (items.length === 0) {
    btn.style.display = 'none';
    if (aviso) aviso.style.display = 'none';
    return;
  }

  btn.style.display = 'inline-block';
  btn.textContent = `Eliminar ${items.length} registro${items.length > 1 ? 's' : ''}`;

  // Solo se permite borrar en lote dentro de UN pedido. Sin esta regla,
  // un filtro mal puesto + "seleccionar todos" puede arrasar con
  // registros de pedidos que el usuario ni miró.
  const ordenes = [...new Set(items.map((i) => i.orden))];
  const variasOrdenes = ordenes.length > 1;

  btn.disabled = variasOrdenes;
  if (aviso) {
    aviso.style.display = variasOrdenes ? 'block' : 'none';
    aviso.textContent = variasOrdenes
      ? `Solo puedes eliminar varios registros si son del MISMO pedido. Tienes seleccionados ${ordenes.length} pedidos: ${ordenes.join(', ')}. Deselecciona los que sobren.`
      : '';
  }
}

function abrirModalEliminarMultiples() {
  if (registrosSeleccionados.size === 0) {
    mostrarToast('Selecciona al menos un registro para eliminar.', 'error');
    return;
  }

  const detalles = seleccionDetallada();
  const ordenes = [...new Set(detalles.map((d) => d.orden))];

  if (ordenes.length > 1) {
    mostrarToast('Solo puedes eliminar varios registros si son del mismo pedido.', 'error');
    return;
  }

  // Resumen de una línea para verificar de un vistazo antes de borrar.
  const totalSuelas = detalles.reduce((sum, d) => sum + d.cantidad, 0);
  const tallas = [...new Set(detalles.map((d) => d.talla))]
    .sort((a, b) => String(a).localeCompare(String(b), undefined, { numeric: true }));

  document.getElementById('eliminar-multiples-resumen').innerHTML = `
    <div style="font-weight:700; color:var(--blue); font-size:15px; margin-bottom:4px;">Pedido ${escapeHtml(ordenes[0])}</div>
    <div style="color:var(--text);">
      <strong>${detalles.length}</strong> registro${detalles.length > 1 ? 's' : ''} ·
      <strong>${totalSuelas}</strong> suela${totalSuelas === 1 ? '' : 's'} ·
      talla${tallas.length > 1 ? 's' : ''} <strong>${escapeHtml(tallas.join(', '))}</strong>
    </div>
  `;

  const lista = detalles
    .map((d) => `<tr><td>${escapeHtml(d.talla)}</td><td>${d.cantidad}</td><td>${escapeHtml(d.fecha)}</td></tr>`)
    .join('');

  document.getElementById('eliminar-multiples-lista').innerHTML = `
    <table style="width:100%; font-size:13px;">
      <thead>
        <tr><th>Talla</th><th>Cantidad</th><th>Fecha</th></tr>
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
    // Todos o ninguno (060): una sola operación en la base. Si cualquier
    // registro incumple una regla, no se elimina ninguno y el mensaje
    // dice cuál y por qué (el modal queda abierto para corregir).
    const cantidad = registrosSeleccionados.size;
    await eliminarMovimientosConMotivo([...registrosSeleccionados], motivo);

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
    limpiarSeleccion();
    cargarHistorial();
  });
  document.getElementById('hist-pag-next')?.addEventListener('click', () => {
    paginaActual += 1;
    limpiarSeleccion();
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
