import { getState } from '../state/appState.js';
import {
  fetchPedidosPorDespachar,
  fetchFacetasADespachar,
  fetchSaldoPorDespachar,
  fetchEstadoPedidos,
  crearDespacho
} from '../services/despachosService.js';
import { rolEfectivo, esValidador } from '../services/validatorService.js';
import { calcularOpciones, reconstruirSelect } from '../lib/facetas.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { cargarRegistrosDespachos, EVENTO_DESPACHO_ELIMINADO } from './registrosDespachosPage.js';
import { sincronizarEtiquetaFiltro } from './customSelect.js';
import { mostrarToast } from './toast.js';

/**
 * Módulo Despachos (operado por Empaque; el Validador también lo ve).
 * Una sola pestaña "Despachos" dentro de Órdenes, con "A Despachar" y
 * "Despachado" como acordeones independientes — sin sub-pestañas, ambos
 * se cargan siempre que se entra a la pestaña.
 *
 * "Despachado" lo pinta registrosDespachosPage.js (antes era la pestaña
 * RegistrosD, que se fusionó aquí para no mostrar lo mismo dos veces).
 *
 * La asignación pedido->bulto se decide DENTRO de "Crear Salida" (no en
 * un paso posterior): todo se envía junto y atómico al RPC crear_despacho
 * (ver 031_despachos_crear_atomico.sql) — si algo no cuadra (falta un
 * pedido sin bulto, sobra un bulto sin usar), no se crea nada y el
 * usuario corrige en el mismo modal. Por eso la tarjeta de "Despachado"
 * solo abre el detalle de solo lectura (ver despachoDetalleModal.js),
 * nunca un formulario de asignación.
 *
 * Patrones copiados/adaptados de otras páginas (no hay helpers
 * compartidos en esta app):
 *   - Selector múltiple con Set + checkbox "seleccionar todos" (igual
 *     que historyPage.js/Registros).
 *   - Tarjeta de pedido = .orden-fila reutilizada tal cual (dashboard.js).
 *   - Modal .modal/.modal-content/.modal-header/.modal-close.
 */

const MAX_BULTOS_POR_ORDEN = 5;

// ---- "A Despachar" ----
let seleccionDespacho = new Set(); // order_numbers seleccionados
// Saldo por talla de los pedidos abiertos en "Crear Salida" (Map order -> tallas[])
let saldoPorPedido = new Map();
let paginaADespachar = 0;
let hayPaginaSiguienteADespachar = false;
let filtrosADespachar = { orden: '', cliente: '', nombreSuela: '', material: '', color: '' };
let debounceADespachar = null;

// Filtros en cascada de "A Despachar": una fila por pedido con saldo,
// descargada al entrar a la pestaña (ver src/lib/facetas.js).
let filasFacetas = [];

const CAMPOS_FACETAS = {
  orden: { columna: 'order_number', modo: 'contiene' },
  cliente: { columna: 'cliente', modo: 'exacto', lista: true },
  nombreSuela: { columna: 'nombre_referencia', modo: 'exacto', lista: true },
  material: { columna: 'material', modo: 'exacto', lista: true },
  color: { columna: 'color', modo: 'exacto', lista: true }
};

const SELECT_POR_FACETA = {
  cliente: 'despacho-filtro-cliente',
  nombreSuela: 'despacho-filtro-nombre-suela',
  material: 'despacho-filtro-material',
  color: 'despacho-filtro-color'
};

// ---------------------------------------------------------------------
// Inicialización / permisos
// ---------------------------------------------------------------------

export function inicializarPaginaDespachos() {
  const inputOrden = document.getElementById('despacho-filtro-orden');
  inputOrden?.addEventListener('input', () => {
    clearTimeout(debounceADespachar);
    debounceADespachar = setTimeout(() => {
      filtrosADespachar.orden = inputOrden.value.trim();
      paginaADespachar = 0;
      actualizarOpcionesADespachar();
      cargarPedidosPorDespachar();
    }, 350);
  });

  const FILTRO_ID_A_CLAVE = {
    'despacho-filtro-cliente': 'cliente',
    'despacho-filtro-nombre-suela': 'nombreSuela',
    'despacho-filtro-material': 'material',
    'despacho-filtro-color': 'color'
  };
  Object.keys(FILTRO_ID_A_CLAVE).forEach((id) => {
    const el = document.getElementById(id);
    el?.addEventListener('change', () => {
      filtrosADespachar[FILTRO_ID_A_CLAVE[id]] = el.value;
      paginaADespachar = 0;
      actualizarOpcionesADespachar();
      cargarPedidosPorDespachar();
    });
  });

  // "Seleccionar todos visibles": nodo persistente (no se recrea en cada
  // render), así que el listener se engancha UNA sola vez aquí — a
  // diferencia de historyPage.js, que lo re-engancha en cada render.
  document.getElementById('despacho-seleccionar-todos-visibles')?.addEventListener('change', (e) => {
    const marcado = e.target.checked;
    document.querySelectorAll('#despacho-pedidos-lista .checkbox-registro').forEach((cb) => {
      cb.checked = marcado;
      if (marcado) seleccionDespacho.add(cb.dataset.order);
      else seleccionDespacho.delete(cb.dataset.order);
    });
    actualizarBotonCrearSalida();
  });

  document.getElementById('btn-crear-salida')?.addEventListener('click', abrirModalCrearSalida);
  document.getElementById('btn-cerrar-crear-despacho')?.addEventListener('click', cerrarModalCrearSalida);
  document.getElementById('btn-cancelar-crear-despacho')?.addEventListener('click', cerrarModalCrearSalida);
  document.getElementById('btn-confirmar-crear-despacho')?.addEventListener('click', confirmarCrearSalida);
  document.getElementById('crear-despacho-num-bultos')?.addEventListener('input', (e) => {
    const n = Number(e.target.value) || 0;
    regenerarInputsPesoBultos(n);
    regenerarOpcionesBultoEnTodasLasFilas(n);
  });

  // Los pesos y las filas de bulto se regeneran constantemente. En vez de
  // re-enganchar listeners en cada render (lo que los iría acumulando),
  // se delega una sola vez en los contenedores, que sí son permanentes.
  document.getElementById('crear-despacho-pesos')?.addEventListener('input', (e) => {
    if (!e.target.classList.contains('peso-bulto-input')) return;
    // Los kilos se manejan en enteros: se descarta cualquier carácter que
    // no sea dígito (coma, punto, signos) en el momento de teclearlo, para
    // que lo digitado y lo mostrado en "Total de kilos" siempre coincidan.
    const limpio = e.target.value.replace(/\D/g, '');
    if (e.target.value !== limpio) e.target.value = limpio;
    actualizarTotalKilos();
  });

  const contenedorFilas = document.getElementById('crear-despacho-pedidos-filas');

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

  // Eliminar un despacho (en "Despachado") devuelve sus pedidos a
  // "A Despachar": se refresca aquí mismo, sin cambiar de pestaña.
  document.addEventListener(EVENTO_DESPACHO_ELIMINADO, () => {
    cargarPedidosPorDespachar();
    cargarFacetasADespachar();
  });
}

/**
 * Análoga a configurarUIValidador()/configurarUICompensacionValidador():
 * se llama una vez por login, y también cada vez que cambia "Rol Activo"
 * (Despachos es visible según rolEfectivo(), no según el rol real — un
 * Validador emulando Empaque debe ver esta pestaña igual que un Empaque
 * real).
 */
export function configurarUIDespachos() {
  const tabBtn = document.getElementById('tab-btn-despachos');
  // El Validador la ve siempre (también en vista maestra); los demás solo
  // si su rol efectivo es Empaque.
  const mostrar = esValidador() || rolEfectivo() === 'empaque';
  if (tabBtn) tabBtn.style.display = mostrar ? 'inline-block' : 'none';
}

/** "A Despachar" y "Despachado" son acordeones independientes (<details> nativos) — ambos se cargan siempre, sin importar cuál esté abierto. */
export function cargarDespachosTab() {
  if (!getState().user) return;
  cargarPedidosPorDespachar();
  cargarFacetasADespachar();
  cargarRegistrosDespachos();
}

/** Descarga los pedidos con saldo para las listas en cascada. */
async function cargarFacetasADespachar() {
  filasFacetas = await fetchFacetasADespachar();
  actualizarOpcionesADespachar();
}

/** Recalcula las cuatro listas con los filtros actuales (sin consultar). */
function actualizarOpcionesADespachar() {
  const opciones = calcularOpciones(filasFacetas, filtrosADespachar, CAMPOS_FACETAS);
  Object.entries(SELECT_POR_FACETA).forEach(([clave, selectId]) => {
    reconstruirSelect(selectId, opciones[clave] || []);
    sincronizarEtiquetaFiltro(selectId);
  });
}

// ---------------------------------------------------------------------
// "A Despachar"
// ---------------------------------------------------------------------

async function cargarPedidosPorDespachar() {
  const contenedor = document.getElementById('despacho-pedidos-lista');
  contenedor.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando pedidos...</div>';

  try {
    const { pedidos, hayMas } = await fetchPedidosPorDespachar({ page: paginaADespachar, filters: filtrosADespachar });
    hayPaginaSiguienteADespachar = hayMas;
    renderPedidosPorDespachar(pedidos);
    renderPaginacionADespachar();
  } catch (err) {
    contenedor.innerHTML = `<div class="card"><div class="empty">${err.message}</div></div>`;
    mostrarToast(err.message, 'error');
  }
}

/**
 * Misma plantilla que .orden-fila en dashboard.js::renderOrdenes() —
 * duplicada aquí porque no está exportada como componente reutilizable.
 * Sin el modo "badges por proceso" de Validador maestro: Despachos es
 * exclusivo de Empaque, siempre se ve el badge/barra normal.
 */
function renderTarjetaOrden(orden) {
  const progreso = orden.porcentaje_completado || 0;
  const diasOrden = orden.dias_orden ?? 0;
  // La etapa ya no va aqui: en movil tiene su propia celda bajo el numero de orden.
  const atributosMobile = [orden.nombre_referencia, orden.material, orden.color]
    .filter(Boolean)
    .map((v) => escapeHtml(v))
    .join(' · ');

  return `
    <div class="orden-fila" data-order="${escapeHtml(orden.order_number)}">
      <div class="col-numero" title="Número de orden">${escapeHtml(orden.order_number)}</div>
      <div class="col-cliente" title="Nombre del cliente">${escapeHtml(orden.cliente || '—')}</div>
      <div class="col-fecha" title="Fecha de creación del pedido">${formatearFecha(orden.fecha_pedido)}</div>
      <div class="col-nombre-suela" title="Nombre de la suela">${escapeHtml(orden.nombre_referencia || '—')}</div>
      <div class="col-material" title="Material">${escapeHtml(orden.material || '—')}</div>
      <div class="col-color" title="Color">${escapeHtml(orden.color || '—')}</div>
      <div class="col-etapa" title="Etapa actual del pedido">${escapeHtml(orden.etapa_actual || '—')}</div>
      <div class="col-mobile-attrs" title="${atributosMobile}">${atributosMobile || '—'}</div>

      <div class="col-metrica col-metrica-total" title="Cantidad total solicitada">
        <div class="metrica-label"><span class="lbl-full">Total Suelas</span><span class="lbl-short">Total</span></div>
        <div class="metrica-valor">${orden.total_solicitado ?? 0}</div>
      </div>
      <div class="col-metrica col-metrica-procesado" title="Suelas ya procesadas">
        <div class="metrica-label"><span class="lbl-full">Procesadas</span><span class="lbl-short">Proc.</span></div>
        <div class="metrica-valor">${orden.total_procesado ?? 0}</div>
      </div>
      <div class="col-metrica col-metrica-pendiente" title="Suelas empacadas y aún sin despachar — el máximo que puede salir en esta remesa">
        <div class="metrica-label"><span class="lbl-full">Disponibles</span><span class="lbl-short">Disp.</span></div>
        <div class="metrica-valor">${orden.unidades_disponibles ?? 0}</div>
      </div>
      <div class="col-metrica col-metrica-dias" title="Días desde creación del pedido">
        <div class="metrica-label"><span class="lbl-full">Días O.</span><span class="lbl-short">Días</span></div>
        <div class="metrica-valor">${diasOrden}d</div>
      </div>

      <div class="orden-chevron" title="Ver detalle del pedido">›</div>

      <div class="col-estado" title="Completado: procesado 100% | En Proceso: aún hay pendientes">
        <span class="estado-badge estado-${orden.estatus_general === 'Completado' ? 'completado' : 'en-proceso'}">${orden.estatus_general}</span>
        <div class="progreso-contenedor">
          <div class="progreso-barra"><div class="progreso-lleno" style="width:${progreso}%"></div></div>
          <span class="progreso-pct">${progreso}%</span>
        </div>
      </div>
    </div>
  `;
}

function renderPedidosPorDespachar(pedidos) {
  const contenedor = document.getElementById('despacho-pedidos-lista');

  if (pedidos.length === 0) {
    contenedor.innerHTML = '<div class="card"><div class="empty">No hay pedidos por despachar.</div></div>';
    sincronizarCheckboxSeleccionarTodos();
    actualizarBotonCrearSalida();
    return;
  }

  contenedor.innerHTML = pedidos
    .map((orden) => {
      const seleccionado = seleccionDespacho.has(orden.order_number);
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
      if (cb.checked) seleccionDespacho.add(cb.dataset.order);
      else seleccionDespacho.delete(cb.dataset.order);
      actualizarBotonCrearSalida();
      sincronizarCheckboxSeleccionarTodos();
    });
  });

  // Tocar cualquier parte de la tarjeta marca o desmarca el pedido. La
  // única excepción es la flecha ›, que abre el detalle. El checkbox se
  // excluye porque ya se alterna solo con su propio clic.
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
  const maestro = document.getElementById('despacho-seleccionar-todos-visibles');
  if (!maestro) return;

  const checkboxes = document.querySelectorAll('#despacho-pedidos-lista .checkbox-registro');
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
  const btn = document.getElementById('btn-crear-salida');
  if (!btn) return;

  if (seleccionDespacho.size > 0) {
    btn.style.display = 'inline-block';
    btn.textContent = `Crear Salida (${seleccionDespacho.size})`;
  } else {
    btn.style.display = 'none';
  }
}

function renderPaginacionADespachar() {
  const el = document.getElementById('despacho-a-despachar-paginacion');
  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="despacho-pag-prev" ${paginaADespachar === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${paginaADespachar + 1}</span>
    <button class="btn btn-secondary btn-sm" id="despacho-pag-next" ${hayPaginaSiguienteADespachar ? '' : 'disabled'}>Siguiente →</button>
  `;

  document.getElementById('despacho-pag-prev')?.addEventListener('click', () => {
    paginaADespachar = Math.max(paginaADespachar - 1, 0);
    cargarPedidosPorDespachar();
  });
  document.getElementById('despacho-pag-next')?.addEventListener('click', () => {
    paginaADespachar += 1;
    cargarPedidosPorDespachar();
  });
}

// ---------------------------------------------------------------------
// Modal "Crear Salida" — bultos+pesos, total unidades, pedidos
// seleccionados CON asignación de bulto inline, unidades por talla.
// ---------------------------------------------------------------------

async function abrirModalCrearSalida() {
  if (seleccionDespacho.size === 0) {
    mostrarToast('Selecciona al menos un pedido para crear la salida.', 'error');
    return;
  }

  const ordenes = [...seleccionDespacho];

  document.getElementById('crear-despacho-num-bultos').value = '';
  document.getElementById('crear-despacho-pesos').innerHTML = '';
  document.getElementById('crear-despacho-total-unidades').textContent = '…';
  document.getElementById('crear-despacho-total-kilos').textContent = '0';
  document.getElementById('crear-despacho-pedidos-label').textContent = `Pedidos seleccionados — ${ordenes.length}`;
  document.getElementById('crear-despacho-pedidos-filas').innerHTML =
    '<div class="loading"><div class="spinner"></div> Cargando saldos...</div>';

  document.getElementById('modal-crear-despacho').classList.add('open');

  try {
    // El saldo por talla y el estado del pedido se piden a la vez: uno
    // alimenta las filas, el otro el contador de despachos del pedido.
    const [saldo, estadoPorPedido] = await Promise.all([
      fetchSaldoPorDespachar(ordenes),
      fetchEstadoPedidos(ordenes)
    ]);
    saldoPorPedido = saldo;

    const totalDisponible = ordenes.reduce(
      (sum, o) => sum + (saldoPorPedido.get(o) || []).reduce((s, t) => s + t.disponible, 0),
      0
    );

    if (totalDisponible === 0) {
      document.getElementById('crear-despacho-pedidos-filas').innerHTML =
        '<div class="empty">Estos pedidos ya no tienen unidades disponibles para despachar.</div>';
      document.getElementById('crear-despacho-total-unidades').textContent = '0';
      return;
    }

    document.getElementById('crear-despacho-pedidos-filas').innerHTML = ordenes
      .map((o) => renderFilaPedidoBulto(o, saldoPorPedido.get(o) || [], estadoPorPedido.get(o)?.despachos ?? 0))
      .join('');

    actualizarTotalUnidades();
  } catch (err) {
    document.getElementById('crear-despacho-pedidos-filas').innerHTML =
      `<div class="empty">${escapeHtml(err.message)}</div>`;
    mostrarToast(err.message, 'error');
  }
}

function cerrarModalCrearSalida() {
  document.getElementById('modal-crear-despacho').classList.remove('open');
}

/**
 * Genera N filas de peso, conservando los valores ya escritos si el
 * usuario ajusta el número de bultos hacia arriba/abajo.
 * Etiqueta a la izquierda y campo a la derecha (.crear-despacho-peso-fila),
 * para que la jerarquía "Número de bultos -> pesos" se lea de un vistazo.
 */
function regenerarInputsPesoBultos(n) {
  const cont = document.getElementById('crear-despacho-pesos');
  if (!n || n <= 0) {
    cont.innerHTML = '';
    actualizarTotalKilos();
    return;
  }

  const valoresActuales = [...cont.querySelectorAll('.peso-bulto-input')].map((i) => i.value);
  cont.innerHTML = Array.from({ length: n }, (_, i) => `
    <div class="crear-despacho-peso-fila">
      <label for="peso-bulto-${i + 1}">Peso bulto ${i + 1} (kg)</label>
      <input type="text" inputmode="numeric" id="peso-bulto-${i + 1}" class="peso-bulto-input" data-bulto="${i + 1}" value="${valoresActuales[i] ?? ''}">
    </div>
  `).join('');

  actualizarTotalKilos();
}

/**
 * Total de unidades de la salida y de cada pedido, según lo digitado por
 * talla. Se recalcula en cada tecla (listener delegado).
 */
function actualizarTotalUnidades() {
  let total = 0;

  document.querySelectorAll('#crear-despacho-pedidos-filas .crear-despacho-pedido-fila').forEach((fila) => {
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

  const el = document.getElementById('crear-despacho-total-unidades');
  if (el) el.textContent = total;
}

/** Suma de los pesos digitados. Se recalcula en cada tecla (listener delegado). */
function actualizarTotalKilos() {
  const total = [...document.querySelectorAll('.peso-bulto-input')]
    .reduce((sum, input) => sum + (Number(input.value) || 0), 0);

  // Sin decimales: en la práctica los pesos se manejan en kilos enteros.
  const el = document.getElementById('crear-despacho-total-kilos');
  if (el) el.textContent = Math.round(total).toLocaleString('es-CO');
}

/**
 * Una fila por pedido seleccionado: el número a la izquierda y sus
 * asignaciones de bulto a la derecha.
 *
 * No se capturan cantidades por talla: la salida lleva TODO lo
 * disponible de cada pedido (ver 048). Lo parcial nace de lo que haya
 * empacado, no de digitar números. Nada se persiste hasta "Crear Despacho".
 */
/**
 * @param {number} despachosDelPedido En cuántos despachos está ya el
 *   pedido completo. Es otra pregunta que el contador por talla: el
 *   pedido puede llevar tres remesas y una talla concreta solo una.
 */
function renderFilaPedidoBulto(orderNumber, tallas, despachosDelPedido) {
  const orden = escapeHtml(orderNumber);
  const disponibles = tallas.reduce((sum, t) => sum + t.disponible, 0);

  return `
    <div class="crear-despacho-pedido-fila" data-order="${orden}">
      <div class="crear-despacho-pedido-cabecera">
        <div class="crear-despacho-pedido-id">
          <div class="crear-despacho-pedido-numero">${orden}</div>
          <div class="crear-despacho-pedido-meta">
            <span title="En cuántos despachos está ya este pedido"><span class="cart-lbl-full">Despachos:</span><span class="cart-lbl-short">Desp.:</span> ${despachosDelPedido}</span>
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
 * Una línea por talla con la misma lectura que la cartilla de órdenes,
 * pero con Despachos como receptor:
 *   Soli. = lo pedido · Proc. = lo ya despachado ·
 *   Pend. = lo que falta por despachar · Reci. = lo que Empaque mandó
 * Siempre se cumple Reci. = Proc. + Pend., así el saldo se lee de un
 * vistazo. El campo nace en el disponible y nunca puede superarlo.
 *
 * "Contador" (solo PC) dice en cuántos despachos distintos ha salido ya
 * esa talla: avisa que el pedido viene repartido en varias remesas.
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
      ${stat('stat-procesado', 'Procesado', 'Proc.', t.despachada)}
      ${stat('stat-pendiente', 'Pendiente', 'Pend.', t.disponible)}
      ${stat('stat-recibido', 'Recibido', 'Reci.', t.recibida)}
      ${stat('stat-contador', 'Contador', 'Cont.', t.numeroDespachos, 'En cuántos despachos ha salido esta talla')}
      <input type="number" class="talla-cantidad-input"
             data-item-id="${escapeHtml(t.itemId)}" data-order="${orden}"
             min="0" max="${t.disponible}" step="1" value="${t.disponible}">
    </div>
  `;
}

/**
 * Una asignación: [dropdown de bulto][+][×].
 * La × de la PRIMERA fila de cada pedido va deshabilitada en gris en vez
 * de omitirse, para que todas las filas tengan la misma forma y quede
 * claro que cada pedido necesita al menos un bulto.
 */
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
  return Number(document.getElementById('crear-despacho-num-bultos').value) || 0;
}

function agregarSelectBulto(orderNumber) {
  const fila = document.querySelector(`.crear-despacho-pedido-fila[data-order="${orderNumber}"]`);
  if (!fila) return;

  const cont = fila.querySelector('.crear-despacho-pedido-bultos');
  if (cont.querySelectorAll('.bulto-select').length >= MAX_BULTOS_POR_ORDEN) return;

  cont.insertAdjacentHTML('beforeend', renderBultoRow(orderNumber, false));

  regenerarOpcionesBultoEnTodasLasFilas(numeroBultosActual());
  actualizarVisibilidadBotonesAgregar();
}

/**
 * Al llegar al tope de bultos por pedido, los "+" se DESHABILITAN en vez
 * de ocultarse: así la fila no cambia de forma y el usuario entiende que
 * el botón existe pero ya no aplica (mismo criterio que la × de la
 * primera fila).
 */
function actualizarVisibilidadBotonesAgregar() {
  document.querySelectorAll('#crear-despacho-pedidos-filas .crear-despacho-pedido-bultos').forEach((cont) => {
    const enTope = cont.querySelectorAll('.bulto-select').length >= MAX_BULTOS_POR_ORDEN;
    cont.querySelectorAll('.btn-agregar-bulto-input').forEach((btn) => {
      btn.disabled = enTope;
      btn.title = enTope
        ? `Máximo ${MAX_BULTOS_POR_ORDEN} bultos por pedido`
        : 'Agregar otro bulto a este pedido';
    });
  });
}

/**
 * Reconstruye las opciones (1..n) de TODOS los dropdown de bulto —
 * llamada cada vez que cambia "Número de bultos" o el usuario elige un
 * valor (para excluir, dentro de un mismo pedido, los números que ya
 * escogió en sus otros dropdowns — no tiene sentido asignar el mismo
 * bulto dos veces a la misma orden). Conserva el valor actual si sigue
 * siendo válido, lo limpia si ya no cabe en el rango.
 */
function regenerarOpcionesBultoEnTodasLasFilas(n) {
  document.querySelectorAll('#crear-despacho-pedidos-filas .crear-despacho-pedido-fila').forEach((fila) => {
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

  const inputsPeso = [...document.querySelectorAll('.peso-bulto-input')];
  if (inputsPeso.length !== numBultos) {
    mostrarToast('Indica el peso de cada bulto.', 'error');
    return;
  }

  const pesos = inputsPeso.map((i) => Number(i.value));
  if (pesos.some((p) => !Number.isInteger(p) || p <= 0)) {
    mostrarToast('Todos los pesos deben ser números enteros mayores a 0.', 'error');
    return;
  }

  // Cuántas unidades salen de cada talla. El RPC vuelve a validar el
  // saldo contra la base (y hay un trigger detrás), pero se revisa aquí
  // para dar un mensaje claro sin ir al servidor.
  const items = [];
  const pedidosSinUnidades = [];
  const pedidosSobreSaldo = [];

  document.querySelectorAll('#crear-despacho-pedidos-filas .crear-despacho-pedido-fila').forEach((fila) => {
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

  // Recolectar asignaciones pedido -> bulto (todo en memoria, nada se
  // guardó todavía) y pre-validar en el cliente antes de llamar al RPC.
  const asignaciones = [];
  const pedidosSinBulto = [];

  document.querySelectorAll('#crear-despacho-pedidos-filas .crear-despacho-pedido-fila').forEach((fila) => {
    const orderNumber = fila.dataset.order;
    const valores = [...fila.querySelectorAll('.bulto-select')].map((s) => s.value).filter((v) => v !== '');
    if (valores.length === 0) {
      pedidosSinBulto.push(orderNumber);
    }
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

  const btn = document.getElementById('btn-confirmar-crear-despacho');
  btn.disabled = true;

  try {
    const despacho = await crearDespacho({
      orderNumbers: [...seleccionDespacho],
      totalBultos: numBultos,
      pesos,
      asignaciones,
      items
    });
    mostrarToast(`Despacho ${despacho.consecutivo} creado correctamente.`, 'ok');
    cerrarModalCrearSalida();
    seleccionDespacho.clear();
    await cargarPedidosPorDespachar();
    await cargarRegistrosDespachos();
    cargarFacetasADespachar();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}

// ---------------------------------------------------------------------
// Utilidades (duplicadas de dashboard.js — no exportadas desde allí)
// ---------------------------------------------------------------------

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
