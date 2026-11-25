import { getState } from '../state/appState.js';
import { formatearFechaPedido } from '../lib/fechas.js';
import {
  fetchPedidosPorSalir,
  fetchFacetasPorSalir,
  fetchSaldoPorSalir,
  fetchSalidasPorPedido,
  crearSalidaAcabado,
  fetchRegistrosSalidas,
  fetchClientesConSalida,
  eliminarSalidaConMotivo,
  marcarSalidaRevisada
} from '../services/salidasAcabadoService.js';
import { esValidador } from '../services/validatorService.js';
import { calcularOpciones, reconstruirSelect } from '../lib/facetas.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { sincronizarEtiquetaFiltro } from './customSelect.js';
import { mostrarToast } from './toast.js';
import {
  abrirDetalleSalida,
  solicitarDescargaSalidaPDF,
  EVENTO_SALIDA_ACTUALIZADA
} from './salidaAcabadoDetalle.js';

/**
 * Pestaña "Salidas(A)" (SQL 092) — la ven Acabado y el Validador.
 *
 * Dos acordeones, igual que Despachos:
 *   - "Por Salir": pedidos con unidades que Acabado ya procesó y aún no han
 *     salido. Selección múltiple y "Crear Salida" (ventana "Crear Salida Acabados").
 *   - "Salida": las salidas ya creadas, con comentario, descarga en PDF,
 *     visto bueno del Validador y eliminación (×).
 *
 * ES SOLO INFORMATIVA: no escribe en production_movements ni toca Despachos ni
 * el flujo Acabado -> Empaque. Es un módulo paralelo a despachosPage.js /
 * registrosDespachosPage.js, con ids propios (prefijo sa-) para no cruzarse con
 * ellos. Las consultas del modal están acotadas a SU ventana por la misma razón.
 */

const MAX_BULTOS_POR_ORDEN = 5;

// ---- "Por Salir" ----
let seleccionSalida = new Set(); // order_numbers seleccionados
let saldoPorPedido = new Map();
let paginaPorSalir = 0;
let hayPaginaSiguientePorSalir = false;
let filtrosPorSalir = { orden: '', cliente: '', nombreSuela: '', material: '', color: '' };
let debouncePorSalir = null;
let filasFacetas = [];

const CAMPOS_FACETAS = {
  orden: { columna: 'order_number', modo: 'contiene' },
  cliente: { columna: 'cliente', modo: 'exacto', lista: true },
  nombreSuela: { columna: 'nombre_referencia', modo: 'exacto', lista: true },
  material: { columna: 'material', modo: 'exacto', lista: true },
  color: { columna: 'color', modo: 'exacto', lista: true }
};

const SELECT_POR_FACETA = {
  cliente: 'sa-filtro-cliente',
  nombreSuela: 'sa-filtro-nombre-suela',
  material: 'sa-filtro-material',
  color: 'sa-filtro-color'
};

// ---- "Salida" ----
let paginaSalidas = 0;
let hayPaginaSiguienteSalidas = false;
let filtrosSalidas = { fecha: '', consecutivo: '', orden: '', cliente: '' };
let firmaClientes = null;
let salidaAEliminar = null;
let cargaSeq = 0;

const HTML_CARGANDO = '<div class="loading"><div class="spinner"></div> Cargando salidas...</div>';
const HTML_OVERLAY_CARGA = '<div class="regd-lista-overlay" aria-live="polite"><div class="spinner"></div> Cargando salidas...</div>';

const ICONO_DESCARGA = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/></svg>';
const ICONO_COMENTARIO = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>';

let popoverComentario = null;
let botonComentarioActivo = null;

// ---------------------------------------------------------------------
// Inicialización / permisos
// ---------------------------------------------------------------------

export function inicializarPaginaSalidasA() {
  // ---- Por Salir: filtros ----
  const inputOrden = document.getElementById('sa-filtro-orden');
  inputOrden?.addEventListener('input', () => {
    clearTimeout(debouncePorSalir);
    debouncePorSalir = setTimeout(() => {
      filtrosPorSalir.orden = inputOrden.value.trim();
      paginaPorSalir = 0;
      actualizarOpcionesPorSalir();
      cargarPedidosPorSalir();
    }, 350);
  });

  const FILTRO_ID_A_CLAVE = {
    'sa-filtro-cliente': 'cliente',
    'sa-filtro-nombre-suela': 'nombreSuela',
    'sa-filtro-material': 'material',
    'sa-filtro-color': 'color'
  };
  Object.keys(FILTRO_ID_A_CLAVE).forEach((id) => {
    const el = document.getElementById(id);
    el?.addEventListener('change', () => {
      filtrosPorSalir[FILTRO_ID_A_CLAVE[id]] = el.value;
      paginaPorSalir = 0;
      actualizarOpcionesPorSalir();
      cargarPedidosPorSalir();
    });
  });

  document.getElementById('sa-seleccionar-todos-visibles')?.addEventListener('change', (e) => {
    const marcado = e.target.checked;
    document.querySelectorAll('#sa-pedidos-lista .checkbox-registro').forEach((cb) => {
      cb.checked = marcado;
      if (marcado) seleccionSalida.add(cb.dataset.order);
      else seleccionSalida.delete(cb.dataset.order);
    });
    actualizarBotonCrearSalida();
  });

  // ---- Crear Salida Acabados ----
  document.getElementById('btn-sa-crear-salida')?.addEventListener('click', abrirModalCrearSalida);
  document.getElementById('btn-cerrar-crear-salida-a')?.addEventListener('click', cerrarModalCrearSalida);
  document.getElementById('btn-cancelar-crear-salida-a')?.addEventListener('click', cerrarModalCrearSalida);
  document.getElementById('btn-confirmar-crear-salida-a')?.addEventListener('click', confirmarCrearSalida);
  document.getElementById('crear-salida-a-comentario')?.addEventListener('input', actualizarContadorComentario);
  document.getElementById('crear-salida-a-num-bultos')?.addEventListener('input', (e) => {
    const n = Number(e.target.value) || 0;
    regenerarInputsPesoBultos(n);
    regenerarOpcionesBultoEnTodasLasFilas(n);
  });

  document.getElementById('crear-salida-a-pesos')?.addEventListener('input', (e) => {
    if (!e.target.classList.contains('peso-bulto-input')) return;
    const limpio = e.target.value.replace(/\D/g, '');
    if (e.target.value !== limpio) e.target.value = limpio;
    actualizarTotalKilos();
  });

  const contenedorFilas = document.getElementById('crear-salida-a-pedidos-filas');
  contenedorFilas?.addEventListener('click', (e) => {
    const btnAgregar = e.target.closest('.btn-agregar-bulto-input');
    if (btnAgregar && !btnAgregar.disabled) {
      agregarSelectBulto(btnAgregar.dataset.order);
      return;
    }
    const btnQuitar = e.target.closest('.btn-quitar-bulto-input');
    if (btnQuitar && !btnQuitar.disabled) {
      btnQuitar.closest('.crear-despacho-bulto-row')?.remove();
      actualizarVisibilidadBotonesAgregar();
      regenerarOpcionesBultoEnTodasLasFilas(numeroBultosActual());
    }
  });
  contenedorFilas?.addEventListener('change', (e) => {
    if (e.target.classList.contains('bulto-select')) {
      regenerarOpcionesBultoEnTodasLasFilas(numeroBultosActual());
    }
  });
  contenedorFilas?.addEventListener('input', (e) => {
    if (e.target.classList.contains('talla-cantidad-input')) actualizarTotalUnidades();
  });

  // ---- Salida: filtros y eliminación ----
  const inputFecha = document.getElementById('sa-regd-filtro-fecha');
  inputFecha?.addEventListener('input', () => {
    filtrosSalidas.fecha = inputFecha.value;
    paginaSalidas = 0;
    cargarSalidas();
  });

  const conDebounce = (id, clave) => {
    const el = document.getElementById(id);
    let temporizador = null;
    el?.addEventListener('input', () => {
      clearTimeout(temporizador);
      temporizador = setTimeout(() => {
        filtrosSalidas[clave] = el.value.trim();
        paginaSalidas = 0;
        cargarSalidas();
      }, 350);
    });
  };
  conDebounce('sa-regd-filtro-consecutivo', 'consecutivo');
  conDebounce('sa-regd-filtro-orden', 'orden');

  document.getElementById('sa-regd-filtro-cliente')?.addEventListener('change', (event) => {
    filtrosSalidas.cliente = event.target.value;
    paginaSalidas = 0;
    cargarSalidas();
  });

  // Comentario guardado desde el detalle: la fila se actualiza sola.
  document.addEventListener(EVENTO_SALIDA_ACTUALIZADA, () => cargarSalidas());

  document.getElementById('btn-cerrar-eliminar-salida-a')?.addEventListener('click', cerrarModalEliminar);
  document.getElementById('btn-cancelar-eliminar-salida-a')?.addEventListener('click', cerrarModalEliminar);
  document.getElementById('btn-confirmar-eliminar-salida-a')?.addEventListener('click', confirmarEliminar);
}

/**
 * Se llama una vez por login y cada vez que cambia "Rol Activo": la pestaña la
 * ven Acabado y el Validador (siempre, también en vista maestra).
 */
export function configurarUISalidasA() {
  const tabBtn = document.getElementById('tab-btn-salidas-a');
  const rol = getState().user?.role;
  const mostrar = esValidador() || rol === 'acabado';
  if (tabBtn) tabBtn.style.display = mostrar ? 'inline-block' : 'none';

  // Validador: al entrar por primera vez (por sesión, no en cada cambio de
  // Rol Activo) "Por Salir" arranca comprimido y "Salida" abierto.
  const idUsuario = getState().user?.id ?? null;
  if (esValidador() && idUsuario && idUsuario !== usuarioAperturaInicial) {
    usuarioAperturaInicial = idUsuario;
    const porSalir = document.getElementById('sa-por-salir-seccion');
    const salida = document.getElementById('sa-salida-seccion');
    if (porSalir) porSalir.open = false;
    if (salida) salida.open = true;
  }
}

let usuarioAperturaInicial = null;

/** Ambos acordeones se cargan siempre al entrar a la pestaña. */
export function cargarSalidasATab() {
  if (!getState().user) return;
  cargarPedidosPorSalir();
  cargarFacetasPorSalir();
  cargarClientesFiltro();
  cargarSalidas();
}

async function cargarFacetasPorSalir() {
  filasFacetas = await fetchFacetasPorSalir();
  actualizarOpcionesPorSalir();
}

function actualizarOpcionesPorSalir() {
  const opciones = calcularOpciones(filasFacetas, filtrosPorSalir, CAMPOS_FACETAS);
  Object.entries(SELECT_POR_FACETA).forEach(([clave, selectId]) => {
    reconstruirSelect(selectId, opciones[clave] || []);
    sincronizarEtiquetaFiltro(selectId);
  });
}

// ---------------------------------------------------------------------
// "Por Salir"
// ---------------------------------------------------------------------

async function cargarPedidosPorSalir() {
  const contenedor = document.getElementById('sa-pedidos-lista');
  if (!contenedor) return;
  contenedor.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando pedidos...</div>';

  try {
    const { pedidos, hayMas } = await fetchPedidosPorSalir({ page: paginaPorSalir, filters: filtrosPorSalir });
    hayPaginaSiguientePorSalir = hayMas;
    renderPedidosPorSalir(pedidos);
    renderPaginacionPorSalir();
  } catch (err) {
    contenedor.innerHTML = `<div class="card"><div class="empty">${escapeHtml(err.message)}</div></div>`;
    mostrarToast(err.message, 'error');
  }
}

/** Misma plantilla .orden-fila de Despachos, con "Procesadas" = lo de Acabado y "Disponibles" = lo que aún no ha salido. */
function renderTarjetaOrden(orden) {
  const progreso = orden.porcentaje_completado || 0;
  const diasOrden = orden.dias_orden ?? 0;
  const atributosMobile = [orden.nombre_referencia, orden.material, orden.color]
    .filter(Boolean)
    .map((v) => escapeHtml(v))
    .join(' · ');

  return `
    <div class="orden-fila" data-order="${escapeHtml(orden.order_number)}">
      <div class="col-numero" title="Número de orden">${escapeHtml(orden.order_number)}</div>
      <div class="col-cliente" title="Nombre del cliente">${escapeHtml(orden.cliente || '—')}</div>
      <div class="col-fecha" title="Fecha de creación del pedido">${formatearFechaPedidoLocal(orden.fecha_pedido)}</div>
      <div class="col-nombre-suela" title="Nombre de la suela">${escapeHtml(orden.nombre_referencia || '—')}</div>
      <div class="col-material" title="Material">${escapeHtml(orden.material || '—')}</div>
      <div class="col-color" title="Color">${escapeHtml(orden.color || '—')}</div>
      <div class="col-etapa" title="Etapa actual del pedido">${escapeHtml(orden.etapa_actual || '—')}</div>
      <div class="col-mobile-attrs" title="${atributosMobile}">${atributosMobile || '—'}</div>

      <div class="col-metrica col-metrica-total" title="Cantidad total solicitada">
        <div class="metrica-label"><span class="lbl-full">Total Suelas</span><span class="lbl-short">Total</span></div>
        <div class="metrica-valor">${orden.total_solicitado ?? 0}</div>
      </div>
      <div class="col-metrica col-metrica-procesado" title="Suelas ya procesadas por Acabado">
        <div class="metrica-label"><span class="lbl-full">Procesadas</span><span class="lbl-short">Proc.</span></div>
        <div class="metrica-valor">${orden.total_procesado ?? 0}</div>
      </div>
      <div class="col-metrica col-metrica-pendiente" title="Procesadas por Acabado que aún no han salido — el máximo que puede salir en esta salida">
        <div class="metrica-label"><span class="lbl-full">Disponibles</span><span class="lbl-short">Disp.</span></div>
        <div class="metrica-valor">${orden.unidades_disponibles ?? 0}</div>
      </div>
      <div class="col-metrica col-metrica-dias" title="Días desde creación del pedido">
        <div class="metrica-label"><span class="lbl-full">Días O.</span><span class="lbl-short">Días</span></div>
        <div class="metrica-valor">${diasOrden}d</div>
      </div>

      <div class="orden-chevron" title="Ver detalle del pedido">›</div>

      <div class="col-estado" title="Avance de Acabado sobre el pedido">
        <span class="estado-badge estado-${orden.estatus_general === 'Completado' ? 'completado' : 'en-proceso'}">${escapeHtml(orden.estatus_general)}</span>
        <div class="progreso-contenedor">
          <div class="progreso-barra"><div class="progreso-lleno" style="width:${progreso}%"></div></div>
          <span class="progreso-pct">${progreso}%</span>
        </div>
      </div>
    </div>
  `;
}

function renderPedidosPorSalir(pedidos) {
  const contenedor = document.getElementById('sa-pedidos-lista');

  if (pedidos.length === 0) {
    contenedor.innerHTML = '<div class="card"><div class="empty">No hay pedidos por salir.</div></div>';
    sincronizarCheckboxSeleccionarTodos();
    actualizarBotonCrearSalida();
    return;
  }

  contenedor.innerHTML = pedidos
    .map((orden) => {
      const seleccionado = seleccionSalida.has(orden.order_number);
      return `
        <div class="despacho-pedido-row">
          <input type="checkbox" class="checkbox-registro" data-order="${escapeHtml(orden.order_number)}" ${seleccionado ? 'checked' : ''}>
          ${renderTarjetaOrden(orden)}
        </div>
      `;
    })
    .join('');

  contenedor.querySelectorAll('.checkbox-registro').forEach((cb) => {
    cb.addEventListener('change', () => {
      if (cb.checked) seleccionSalida.add(cb.dataset.order);
      else seleccionSalida.delete(cb.dataset.order);
      actualizarBotonCrearSalida();
      sincronizarCheckboxSeleccionarTodos();
    });
  });

  // Tocar la tarjeta marca o desmarca el pedido; solo la flecha › abre el detalle.
  contenedor.querySelectorAll('.despacho-pedido-row').forEach((row) => {
    row.addEventListener('click', (e) => {
      if (e.target.closest('.checkbox-registro')) return;

      const fila = row.querySelector('.orden-fila');
      if (e.target.closest('.orden-chevron')) {
        abrirDetalleOrden(fila.dataset.order);
        return;
      }

      const checkbox = row.querySelector('.checkbox-registro');
      checkbox.checked = !checkbox.checked;
      checkbox.dispatchEvent(new Event('change', { bubbles: true }));
    });
  });

  sincronizarCheckboxSeleccionarTodos();
  actualizarBotonCrearSalida();
}

function sincronizarCheckboxSeleccionarTodos() {
  const maestro = document.getElementById('sa-seleccionar-todos-visibles');
  if (!maestro) return;

  const checkboxes = document.querySelectorAll('#sa-pedidos-lista .checkbox-registro');
  if (checkboxes.length === 0) {
    maestro.checked = false;
    maestro.indeterminate = false;
    return;
  }
  const todos = Array.from(checkboxes).every((cb) => cb.checked);
  const alguno = Array.from(checkboxes).some((cb) => cb.checked);
  maestro.checked = todos;
  maestro.indeterminate = alguno && !todos;
}

function actualizarBotonCrearSalida() {
  const btn = document.getElementById('btn-sa-crear-salida');
  if (!btn) return;
  if (seleccionSalida.size > 0) {
    btn.style.display = 'inline-block';
    btn.textContent = `Crear Salida (${seleccionSalida.size})`;
  } else {
    btn.style.display = 'none';
  }
}

function renderPaginacionPorSalir() {
  const el = document.getElementById('sa-por-salir-paginacion');
  if (!el) return;
  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="sa-pag-prev" ${paginaPorSalir === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${paginaPorSalir + 1}</span>
    <button class="btn btn-secondary btn-sm" id="sa-pag-next" ${hayPaginaSiguientePorSalir ? '' : 'disabled'}>Siguiente →</button>
  `;
  document.getElementById('sa-pag-prev')?.addEventListener('click', () => {
    paginaPorSalir = Math.max(paginaPorSalir - 1, 0);
    cargarPedidosPorSalir();
  });
  document.getElementById('sa-pag-next')?.addEventListener('click', () => {
    paginaPorSalir += 1;
    cargarPedidosPorSalir();
  });
}

// ---------------------------------------------------------------------
// Ventana "Crear Salida Acabados"
// Todas las consultas de DOM van acotadas a esta ventana: así nunca se mezclan con
// la de Despachos (que usa las mismas clases), y al cerrarla se vacía por la misma razón.
// ---------------------------------------------------------------------

const ventanaCrear = () => document.getElementById('modal-crear-salida-a');
const dentroDeVentana = (selector) => [...(ventanaCrear()?.querySelectorAll(selector) || [])];

async function abrirModalCrearSalida() {
  if (seleccionSalida.size === 0) {
    mostrarToast('Selecciona al menos un pedido para crear la salida.', 'error');
    return;
  }

  const ordenes = [...seleccionSalida];

  document.getElementById('crear-salida-a-num-bultos').value = '';
  document.getElementById('crear-salida-a-comentario').value = '';
  actualizarContadorComentario();
  document.getElementById('crear-salida-a-pesos').innerHTML = '';
  document.getElementById('crear-salida-a-total-unidades').textContent = '…';
  document.getElementById('crear-salida-a-total-kilos').textContent = '0';
  document.getElementById('crear-salida-a-pedidos-label').textContent = `Pedidos seleccionados — ${ordenes.length}`;
  document.getElementById('crear-salida-a-pedidos-filas').innerHTML =
    '<div class="loading"><div class="spinner"></div> Cargando saldos...</div>';

  ventanaCrear().classList.add('open');

  try {
    const [saldo, estadoPorPedido] = await Promise.all([
      fetchSaldoPorSalir(ordenes),
      fetchSalidasPorPedido(ordenes)
    ]);
    saldoPorPedido = saldo;

    const totalDisponible = ordenes.reduce(
      (sum, o) => sum + (saldoPorPedido.get(o) || []).reduce((s, t) => s + t.disponible, 0),
      0
    );

    if (totalDisponible === 0) {
      document.getElementById('crear-salida-a-pedidos-filas').innerHTML =
        '<div class="empty">Estos pedidos ya no tienen unidades disponibles para salir.</div>';
      document.getElementById('crear-salida-a-total-unidades').textContent = '0';
      return;
    }

    document.getElementById('crear-salida-a-pedidos-filas').innerHTML = ordenes
      .map((o) => renderFilaPedidoBulto(o, saldoPorPedido.get(o) || [], estadoPorPedido.get(o)?.salidas ?? 0))
      .join('');

    actualizarTotalUnidades();
  } catch (err) {
    document.getElementById('crear-salida-a-pedidos-filas').innerHTML =
      `<div class="empty">${escapeHtml(err.message)}</div>`;
    mostrarToast(err.message, 'error');
  }
}

function cerrarModalCrearSalida() {
  ventanaCrear()?.classList.remove('open');
  // Se vacía para no dejar filas/pesos con las mismas clases que usa Despachos.
  document.getElementById('crear-salida-a-pedidos-filas').innerHTML = '';
  document.getElementById('crear-salida-a-pesos').innerHTML = '';
}

function regenerarInputsPesoBultos(n) {
  const cont = document.getElementById('crear-salida-a-pesos');
  if (!n || n <= 0) {
    cont.innerHTML = '';
    actualizarTotalKilos();
    return;
  }

  const valoresActuales = [...cont.querySelectorAll('.peso-bulto-input')].map((i) => i.value);
  cont.innerHTML = Array.from({ length: n }, (_, i) => `
    <div class="crear-despacho-peso-fila">
      <label for="peso-bulto-a-${i + 1}">Peso bulto ${i + 1} (kg)</label>
      <input type="text" inputmode="numeric" id="peso-bulto-a-${i + 1}" class="peso-bulto-input" data-bulto="${i + 1}" value="${valoresActuales[i] ?? ''}">
    </div>
  `).join('');

  actualizarTotalKilos();
}

function actualizarTotalUnidades() {
  let total = 0;

  dentroDeVentana('#crear-salida-a-pedidos-filas .crear-despacho-pedido-fila').forEach((fila) => {
    let delPedido = 0;
    let disponibleDelPedido = 0;

    fila.querySelectorAll('.talla-cantidad-input').forEach((input) => {
      delPedido += Number(input.value) || 0;
      disponibleDelPedido += Number(input.max) || 0;
    });

    const etiqueta = fila.querySelector('[data-total-pedido]');
    if (etiqueta) etiqueta.textContent = `${delPedido} de ${disponibleDelPedido} und`;
    total += delPedido;
  });

  const el = document.getElementById('crear-salida-a-total-unidades');
  if (el) el.textContent = total;
}

function actualizarContadorComentario() {
  const campo = document.getElementById('crear-salida-a-comentario');
  const contador = document.getElementById('crear-salida-a-comentario-contador');
  if (campo && contador) contador.textContent = `${campo.value.length} / ${campo.maxLength}`;
}

function actualizarTotalKilos() {
  const total = dentroDeVentana('.peso-bulto-input')
    .reduce((sum, input) => sum + (Number(input.value) || 0), 0);
  const el = document.getElementById('crear-salida-a-total-kilos');
  if (el) el.textContent = Math.round(total).toLocaleString('es-CO');
}

function renderFilaPedidoBulto(orderNumber, tallas, salidasDelPedido) {
  const orden = escapeHtml(orderNumber);
  const disponibles = tallas.reduce((sum, t) => sum + t.disponible, 0);

  return `
    <div class="crear-despacho-pedido-fila" data-order="${orden}">
      <div class="crear-despacho-pedido-cabecera">
        <div class="crear-despacho-pedido-id">
          <div class="crear-despacho-pedido-numero">${orden}</div>
          <div class="crear-despacho-pedido-meta">
            <span title="En cuántas salidas está ya este pedido"><span class="cart-lbl-full">Salidas:</span><span class="cart-lbl-short">Sal.:</span> ${salidasDelPedido}</span>
            <span aria-hidden="true">·</span>
            <span data-total-pedido="${orden}">${disponibles} und</span>
          </div>
        </div>
        <div class="crear-despacho-pedido-bultos">
          ${renderBultoRow(orderNumber, true)}
        </div>
      </div>
      <div class="crear-despacho-pedido-tallas">
        ${tallas.map((t) => renderFilaTalla(orden, t)).join('')}
      </div>
    </div>
  `;
}

/**
 * Una línea por talla:
 *   Soli. = lo pedido · Sal. = lo que ya salió · Disp. = lo que aún puede salir ·
 *   Proc. = lo que Acabado procesó. Siempre Proc. = Sal. + Disp.
 * El campo nace en el disponible y nunca puede superarlo.
 */
function renderFilaTalla(orden, t) {
  const stat = (clase, completa, corta, valor, titulo = '') => `
    <div class="stat-item ${clase}"${titulo ? ` title="${titulo}"` : ''}>
      <div class="stat-label"><span class="cart-lbl-full">${completa}</span><span class="cart-lbl-short">${corta}</span></div>
      <div class="stat-value">${valor}</div>
    </div>`;

  return `
    <div class="crear-despacho-talla-fila">
      <div class="crear-despacho-talla-nombre">Talla ${escapeHtml(t.talla)}</div>
      ${stat('', 'Solicitado', 'Soli.', t.solicitada)}
      ${stat('stat-procesado', 'Salido', 'Sal.', t.salida, 'Lo que ya salió de esta talla')}
      ${stat('stat-pendiente', 'Disponible', 'Disp.', t.disponible, 'Lo que aún puede salir')}
      ${stat('stat-recibido', 'Procesado', 'Proc.', t.recibida, 'Lo que Acabado procesó de esta talla')}
      ${stat('stat-contador', 'Contador', 'Cont.', t.numeroSalidas, 'En cuántas salidas ha salido esta talla')}
      <input type="number" class="talla-cantidad-input"
             data-item-id="${escapeHtml(t.itemId)}" data-order="${orden}"
             min="0" max="${t.disponible}" step="1" value="${t.disponible}">
    </div>
  `;
}

function renderBultoRow(orderNumber, esPrimera) {
  const orden = escapeHtml(orderNumber);
  const atributosQuitar = esPrimera
    ? 'disabled title="Cada pedido necesita al menos un bulto"'
    : 'title="Quitar este bulto"';

  return `
    <div class="crear-despacho-bulto-row">
      <select class="bulto-select" data-order="${orden}"><option value="">Bulto...</option></select>
      <button type="button" class="btn-agregar-bulto-input" data-order="${orden}" title="Agregar otro bulto a este pedido">+</button>
      <button type="button" class="btn-quitar-bulto-input" ${atributosQuitar}>×</button>
    </div>
  `;
}

function numeroBultosActual() {
  return Number(document.getElementById('crear-salida-a-num-bultos').value) || 0;
}

function agregarSelectBulto(orderNumber) {
  const fila = dentroDeVentana('.crear-despacho-pedido-fila').find((f) => f.dataset.order === String(orderNumber));
  if (!fila) return;

  const cont = fila.querySelector('.crear-despacho-pedido-bultos');
  if (cont.querySelectorAll('.bulto-select').length >= MAX_BULTOS_POR_ORDEN) return;

  cont.insertAdjacentHTML('beforeend', renderBultoRow(orderNumber, false));

  regenerarOpcionesBultoEnTodasLasFilas(numeroBultosActual());
  actualizarVisibilidadBotonesAgregar();
}

function actualizarVisibilidadBotonesAgregar() {
  dentroDeVentana('#crear-salida-a-pedidos-filas .crear-despacho-pedido-bultos').forEach((cont) => {
    const enTope = cont.querySelectorAll('.bulto-select').length >= MAX_BULTOS_POR_ORDEN;
    cont.querySelectorAll('.btn-agregar-bulto-input').forEach((btn) => {
      btn.disabled = enTope;
      btn.title = enTope
        ? `Máximo ${MAX_BULTOS_POR_ORDEN} bultos por pedido`
        : 'Agregar otro bulto a este pedido';
    });
  });
}

function regenerarOpcionesBultoEnTodasLasFilas(n) {
  dentroDeVentana('#crear-salida-a-pedidos-filas .crear-despacho-pedido-fila').forEach((fila) => {
    const selects = [...fila.querySelectorAll('.bulto-select')];
    selects.forEach((select) => {
      const valorActual = select.value;
      const otrosValores = selects.filter((s) => s !== select).map((s) => s.value).filter(Boolean);

      const opciones = Array.from({ length: n }, (_, i) => i + 1).filter((b) => !otrosValores.includes(String(b)));
      select.innerHTML = '<option value="">Bulto...</option>' + opciones.map((b) => `<option value="${b}">${b}</option>`).join('');

      if (valorActual && opciones.includes(Number(valorActual))) {
        select.value = valorActual;
      } else {
        select.value = '';
      }
    });
  });
}

async function confirmarCrearSalida() {
  const numBultos = numeroBultosActual();
  if (!Number.isFinite(numBultos) || numBultos <= 0) {
    mostrarToast('Indica un número de bultos válido.', 'error');
    return;
  }

  const inputsPeso = dentroDeVentana('.peso-bulto-input');
  if (inputsPeso.length !== numBultos) {
    mostrarToast('Indica el peso de cada bulto.', 'error');
    return;
  }

  const pesos = inputsPeso.map((i) => Number(i.value));
  if (pesos.some((p) => !Number.isInteger(p) || p <= 0)) {
    mostrarToast('Todos los pesos deben ser números enteros mayores a 0.', 'error');
    return;
  }

  const items = [];
  const pedidosSinUnidades = [];
  const pedidosSobreSaldo = [];

  dentroDeVentana('#crear-salida-a-pedidos-filas .crear-despacho-pedido-fila').forEach((fila) => {
    const orderNumber = fila.dataset.order;
    let unidadesDelPedido = 0;

    fila.querySelectorAll('.talla-cantidad-input').forEach((input) => {
      const cantidad = Number(input.value) || 0;
      const maximo = Number(input.max) || 0;
      if (cantidad > maximo) pedidosSobreSaldo.push(orderNumber);
      if (cantidad > 0) {
        items.push({ item_id: input.dataset.itemId, cantidad });
        unidadesDelPedido += cantidad;
      }
    });

    if (unidadesDelPedido === 0) pedidosSinUnidades.push(orderNumber);
  });

  if (pedidosSobreSaldo.length > 0) {
    mostrarToast(`Hay tallas por encima del saldo disponible en: ${[...new Set(pedidosSobreSaldo)].join(', ')}`, 'error');
    return;
  }
  if (items.length === 0) {
    mostrarToast('Indica cuántas unidades salen de al menos una talla.', 'error');
    return;
  }
  if (pedidosSinUnidades.length > 0) {
    mostrarToast(`Estos pedidos quedaron en 0 unidades: ${pedidosSinUnidades.join(', ')}. Quítalos de la selección o asígnales cantidad.`, 'error');
    return;
  }

  const asignaciones = [];
  const pedidosSinBulto = [];

  dentroDeVentana('#crear-salida-a-pedidos-filas .crear-despacho-pedido-fila').forEach((fila) => {
    const orderNumber = fila.dataset.order;
    const valores = [...fila.querySelectorAll('.bulto-select')].map((s) => s.value).filter((v) => v !== '');
    if (valores.length === 0) pedidosSinBulto.push(orderNumber);
    valores.forEach((v) => asignaciones.push({ order_number: orderNumber, bulto_numero: Number(v) }));
  });

  if (pedidosSinBulto.length > 0) {
    mostrarToast(`Falta asignar bulto a: ${pedidosSinBulto.join(', ')}`, 'error');
    return;
  }

  const bultosUsados = new Set(asignaciones.map((a) => a.bulto_numero));
  const bultosSinUsar = [];
  for (let b = 1; b <= numBultos; b++) {
    if (!bultosUsados.has(b)) bultosSinUsar.push(b);
  }
  if (bultosSinUsar.length > 0) {
    mostrarToast(`Los siguientes bultos no fueron asignados a ningún pedido: ${bultosSinUsar.join(', ')}`, 'error');
    return;
  }

  const btn = document.getElementById('btn-confirmar-crear-salida-a');
  btn.disabled = true;

  try {
    const salida = await crearSalidaAcabado({
      orderNumbers: [...seleccionSalida],
      totalBultos: numBultos,
      pesos,
      asignaciones,
      items,
      comentario: document.getElementById('crear-salida-a-comentario')?.value || ''
    });
    mostrarToast(`Salida ${salida.consecutivo} creada correctamente.`, 'ok');
    cerrarModalCrearSalida();
    seleccionSalida.clear();
    await cargarPedidosPorSalir();
    await cargarClientesFiltro();
    await cargarSalidas();
    cargarFacetasPorSalir();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}

// ---------------------------------------------------------------------
// "Salida": una fila por salida
// ---------------------------------------------------------------------

async function cargarClientesFiltro() {
  const select = document.getElementById('sa-regd-filtro-cliente');
  if (!select) return;

  const clientes = await fetchClientesConSalida();
  const firma = clientes.join('\n');
  if (firma === firmaClientes) return;
  firmaClientes = firma;

  reconstruirSelect('sa-regd-filtro-cliente', clientes);
  sincronizarEtiquetaFiltro('sa-regd-filtro-cliente');
}

async function cargarSalidas() {
  if (!getState().user) return;

  const contenedor = document.getElementById('sa-regd-lista');
  if (!contenedor) return;

  const seq = ++cargaSeq;
  pintarEstadoCarga(contenedor);

  try {
    const { salidas, hayMas } = await fetchRegistrosSalidas({ page: paginaSalidas, filters: filtrosSalidas });
    if (seq !== cargaSeq) return;
    hayPaginaSiguienteSalidas = hayMas;
    renderSalidas(salidas);
    renderPaginacionSalidas();
  } catch (err) {
    if (seq !== cargaSeq) return;
    contenedor.classList.remove('regd-lista-cargando');
    contenedor.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    mostrarToast(err.message, 'error');
  }
}

function pintarEstadoCarga(contenedor) {
  const tieneFilas = !!contenedor.querySelector('.regd-fila');
  if (tieneFilas) {
    contenedor.classList.add('regd-lista-cargando');
    if (!contenedor.querySelector('.regd-lista-overlay')) {
      contenedor.insertAdjacentHTML('beforeend', HTML_OVERLAY_CARGA);
    }
    return;
  }
  contenedor.classList.remove('regd-lista-cargando');
  contenedor.innerHTML = HTML_CARGANDO;
}

function renderSalidas(salidas) {
  const contenedor = document.getElementById('sa-regd-lista');
  contenedor.classList.remove('regd-lista-cargando');
  cerrarPopoverComentario();

  if (salidas.length === 0) {
    contenedor.innerHTML = '<div class="empty">No hay salidas para mostrar.</div>';
    return;
  }

  // El visto bueno es del Validador; Acabado lo ve pero no lo mueve.
  const puedeRevisar = esValidador();

  contenedor.innerHTML = salidas
    .map((s) => {
      const listaOrdenes = (s.order_numbers || []).join(', ');
      const listaClientes = (s.clientes || []).join(', ');
      const comentario = String(s.comentario ?? '').trim();
      // El × se apaga con el visto bueno puesto, salvo para el propio Validador.
      const bloqueado = s.revisado && !puedeRevisar;
      return `
        <div class="regd-fila regd-con-cliente" data-salida="${escapeHtml(s.id)}" data-consecutivo="${escapeHtml(s.consecutivo)}" data-ordenes="${escapeHtml(listaOrdenes)}" data-bultos="${s.total_bultos}"${comentario ? ' data-tiene-comentario="1"' : ''}>
          <div class="regd-col-consecutivo">${escapeHtml(s.consecutivo)}</div>
          <div class="regd-col-fecha">${formatearFecha(s.created_at)}</div>
          <div class="regd-col-hora" title="Hora de la salida">${formatearHora(s.created_at)}</div>
          <div class="regd-col-cliente" data-lbl="Cliente" title="${escapeHtml(listaClientes)}">${escapeHtml(listaClientes) || '—'}</div>
          <div class="regd-col-ordenes" data-lbl="Pedidos" title="${escapeHtml(listaOrdenes)}">${escapeHtml(listaOrdenes) || '—'}</div>
          <div class="regd-col-num" data-lbl="Bultos">${s.total_bultos}</div>
          <div class="regd-col-num" data-lbl="Kilos">${formatearKilos(s.peso_total)}</div>
          <div class="regd-col-num" data-lbl="Unidades">${s.total_unidades ?? 0}</div>
          <div class="regd-col-num" data-lbl="Pedidos">${s.numero_ordenes ?? 0}</div>
          <div class="regd-col-revisado">
            <input type="checkbox" class="checkbox-revisado" data-revisar="${escapeHtml(s.id)}"
              ${s.revisado ? 'checked' : ''} ${puedeRevisar ? '' : 'disabled'}
              title="${tituloRevisado(s, puedeRevisar)}" aria-label="Revisado por el Validador">
          </div>
          <div class="regd-col-comentario">
            ${comentario
              ? `<button type="button" class="btn-comentario-registro con-comentario" data-comentario="${escapeHtml(comentario)}" title="Ver comentario" aria-label="Ver comentario" aria-expanded="false">${ICONO_COMENTARIO}<span class="btn-comentario-badge" aria-hidden="true">C</span></button>`
              : `<button type="button" class="btn-comentario-registro sin-comentario" aria-disabled="true" aria-label="Sin comentario">${ICONO_COMENTARIO}</button>`}
          </div>
          <div class="regd-col-descarga">
            <button class="btn-descargar-registro" data-descargar="${escapeHtml(s.id)}" title="Descargar la salida en PDF" aria-label="Descargar la salida en PDF">${ICONO_DESCARGA}</button>
          </div>
          <div class="regd-col-accion">
            <button class="btn-eliminar-registro" data-eliminar="${escapeHtml(s.id)}" ${bloqueado ? 'disabled' : ''}
              title="${bloqueado ? 'El Validador ya revisó esta salida. Pídele que quite el visto bueno para poder eliminarla.' : 'Eliminar salida completa'}"
              aria-label="Eliminar salida completa">×</button>
          </div>
        </div>
      `;
    })
    .join('');

  contenedor.querySelectorAll('.regd-fila').forEach((fila) => {
    fila.addEventListener('click', () => {
      cerrarPopoverComentario();
      abrirDetalleSalida(fila.dataset.salida, fila.dataset.consecutivo);
    });
  });

  contenedor.querySelectorAll('[data-revisar]').forEach((cb) => {
    cb.addEventListener('click', (event) => event.stopPropagation());
    cb.addEventListener('change', () => cambiarRevisado(cb));
  });

  contenedor.querySelectorAll('.btn-comentario-registro').forEach((btn) => {
    btn.addEventListener('click', (event) => {
      event.stopPropagation();
      if (btn.classList.contains('sin-comentario') || btn.getAttribute('aria-disabled') === 'true') return;
      alternarPopoverComentario(btn);
    });
  });

  contenedor.querySelectorAll('[data-descargar]').forEach((btn) => {
    btn.addEventListener('click', (event) => {
      event.stopPropagation();
      cerrarPopoverComentario();
      const fila = btn.closest('.regd-fila');
      solicitarDescargaSalidaPDF(btn.dataset.descargar, fila.dataset.consecutivo, {
        tieneComentario: fila.dataset.tieneComentario === '1'
      });
    });
  });

  contenedor.querySelectorAll('[data-eliminar]').forEach((btn) => {
    btn.addEventListener('click', (event) => {
      event.stopPropagation();
      cerrarPopoverComentario();
      const fila = btn.closest('.regd-fila');
      abrirModalEliminar(btn.dataset.eliminar, fila.dataset);
    });
  });
}

function asegurarListenersPopoverComentario() {
  if (asegurarListenersPopoverComentario.listo) return;
  asegurarListenersPopoverComentario.listo = true;

  document.addEventListener('click', (event) => {
    if (!popoverComentario) return;
    if (popoverComentario.contains(event.target)) return;
    if (botonComentarioActivo?.contains(event.target)) return;
    cerrarPopoverComentario();
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape') cerrarPopoverComentario();
  });
  window.addEventListener('resize', cerrarPopoverComentario);
  document.getElementById('sa-regd-lista')?.addEventListener('scroll', cerrarPopoverComentario, true);
}

function alternarPopoverComentario(boton) {
  asegurarListenersPopoverComentario();

  if (botonComentarioActivo === boton && popoverComentario) {
    cerrarPopoverComentario();
    return;
  }
  cerrarPopoverComentario();

  const pop = document.createElement('div');
  pop.className = 'regd-comentario-popover';
  pop.setAttribute('role', 'dialog');
  pop.setAttribute('aria-label', 'Comentario de la salida');
  pop.innerHTML = `
    <div class="regd-comentario-popover-titulo">Comentario</div>
    <div class="regd-comentario-popover-texto">${escapeHtml(boton.dataset.comentario || '')}</div>
  `;
  document.body.appendChild(pop);

  const rect = boton.getBoundingClientRect();
  const margen = 8;
  const ancho = pop.offsetWidth;
  const alto = pop.offsetHeight;
  let left = rect.left + rect.width / 2 - ancho / 2;
  left = Math.max(margen, Math.min(left, window.innerWidth - ancho - margen));
  let top = rect.bottom + 6;
  if (top + alto + margen > window.innerHeight && rect.top - alto - 6 > margen) {
    top = rect.top - alto - 6;
  }
  pop.style.left = `${Math.round(left)}px`;
  pop.style.top = `${Math.round(top)}px`;

  popoverComentario = pop;
  botonComentarioActivo = boton;
  boton.setAttribute('aria-expanded', 'true');
}

function cerrarPopoverComentario() {
  if (popoverComentario) {
    popoverComentario.remove();
    popoverComentario = null;
  }
  if (botonComentarioActivo) {
    botonComentarioActivo.setAttribute('aria-expanded', 'false');
    botonComentarioActivo = null;
  }
}

function tituloRevisado(salida, puedeRevisar) {
  if (!salida.revisado) {
    return puedeRevisar
      ? 'Marcar como revisada: bloquea su eliminación'
      : 'Pendiente de revisión del Validador';
  }
  const quien = salida.revisado_por_nombre ? ` por ${salida.revisado_por_nombre}` : '';
  return puedeRevisar
    ? `Revisada${quien}. Quitar el visto bueno permite eliminarla de nuevo.`
    : `Revisada${quien}. No se puede eliminar mientras tenga el visto bueno.`;
}

async function cambiarRevisado(checkbox) {
  const deseado = checkbox.checked;
  checkbox.disabled = true;

  try {
    await marcarSalidaRevisada(checkbox.dataset.revisar, deseado);
    mostrarToast(deseado ? 'Salida marcada como revisada.' : 'Visto bueno retirado.', 'ok');
    await cargarSalidas();
  } catch (err) {
    checkbox.checked = !deseado;
    checkbox.disabled = false;
    mostrarToast(err.message, 'error');
  }
}

function renderPaginacionSalidas() {
  const el = document.getElementById('sa-regd-paginacion');
  if (!el) return;
  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="sa-regd-pag-prev" ${paginaSalidas === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${paginaSalidas + 1}</span>
    <button class="btn btn-secondary btn-sm" id="sa-regd-pag-next" ${hayPaginaSiguienteSalidas ? '' : 'disabled'}>Siguiente →</button>
  `;
  document.getElementById('sa-regd-pag-prev')?.addEventListener('click', () => {
    paginaSalidas = Math.max(paginaSalidas - 1, 0);
    cargarSalidas();
  });
  document.getElementById('sa-regd-pag-next')?.addEventListener('click', () => {
    paginaSalidas += 1;
    cargarSalidas();
  });
}

// ---------------------------------------------------------------------
// Eliminar una salida completa (motivo obligatorio)
// ---------------------------------------------------------------------

function abrirModalEliminar(salidaId, datos) {
  salidaAEliminar = salidaId;
  document.getElementById('eliminar-salida-a-motivo').value = '';
  document.getElementById('eliminar-salida-a-resumen').innerHTML = `
    Salida <strong>${escapeHtml(datos.consecutivo)}</strong> ·
    ${escapeHtml(datos.bultos)} bulto${datos.bultos === '1' ? '' : 's'} ·
    Pedidos: <strong>${escapeHtml(datos.ordenes) || '—'}</strong>
  `;
  document.getElementById('modal-eliminar-salida-a').classList.add('open');
}

function cerrarModalEliminar() {
  document.getElementById('modal-eliminar-salida-a').classList.remove('open');
  salidaAEliminar = null;
}

async function confirmarEliminar() {
  const motivo = document.getElementById('eliminar-salida-a-motivo').value.trim();
  if (!motivo) {
    mostrarToast('Debes indicar un motivo para eliminar esta salida.', 'error');
    return;
  }

  const btn = document.getElementById('btn-confirmar-eliminar-salida-a');
  btn.disabled = true;

  try {
    await eliminarSalidaConMotivo(salidaAEliminar, motivo);
    mostrarToast('Salida eliminada. Sus unidades vuelven a "Por Salir".', 'ok');
    cerrarModalEliminar();
    await cargarClientesFiltro();
    await cargarSalidas();
    cargarPedidosPorSalir();
    cargarFacetasPorSalir();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}

// ---------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------

/** Solo se usa para fecha_pedido (fecha de calendario): ver lib/fechas.js. */
function formatearFechaPedidoLocal(fecha) {
  return formatearFechaPedido(fecha);
}

function formatearFecha(fecha) {
  if (!fecha) return '—';
  try {
    return new Date(fecha).toLocaleDateString('es-CO');
  } catch {
    return String(fecha);
  }
}

function formatearHora(fecha) {
  if (!fecha) return '—';
  const d = new Date(fecha);
  if (Number.isNaN(d.getTime())) return '—';
  return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}

function formatearKilos(valor) {
  return Math.round(Number(valor || 0)).toLocaleString('es-CO');
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
