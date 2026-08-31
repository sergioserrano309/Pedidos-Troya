import { getState } from '../state/appState.js';
import {
  fetchPedidosPorDespachar,
  fetchPreviewCreacionDespacho,
  crearDespacho,
  fetchDespachos,
  fetchDetalleDespacho,
  fetchAsignacionesDespacho,
  fetchBultosDespacho
} from '../services/despachosService.js';
import { fetchOpcionesCliente, fetchOpcionesNombreSuela, fetchOpcionesMaterial, fetchOpcionesColor } from '../services/ordersService.js';
import { rolEfectivo } from '../services/validatorService.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { mostrarToast } from './toast.js';

/**
 * Módulo Despachos (Fase 1 — ver plan: operado únicamente por el rol
 * Empaque, incluyendo Validador emulando Empaque vía rolEfectivo()).
 * Una sola pestaña "Despachos" dentro de Órdenes, con "A Despachar" y
 * "Despachado" como acordeones independientes (mismo lenguaje visual
 * que Compensación > Evolución 12 Meses/Histórico de Producción) — sin
 * sub-pestañas, ambos se cargan siempre que se entra a la pestaña.
 *
 * La asignación pedido->bulto se decide DENTRO de "Crear Salida" (no en
 * un paso posterior): todo se envía junto y atómico al RPC crear_despacho
 * (ver 031_despachos_crear_atomico.sql) — si algo no cuadra (falta un
 * pedido sin bulto, sobra un bulto sin usar), no se crea nada y el
 * usuario corrige en el mismo modal. Por eso la tarjeta de "Despachado"
 * solo abre un resumen de solo lectura, nunca un formulario de asignación.
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
let paginaADespachar = 0;
let hayPaginaSiguienteADespachar = false;
let filtrosADespachar = { orden: '', cliente: '', nombreSuela: '', material: '', color: '' };
let debounceADespachar = null;

// ---- "Despachado" ----
let paginaDespachado = 0;
let hayPaginaSiguienteDespachado = false;
let filtrosDespachado = { fecha: '', consecutivo: '', orden: '' };
let debounceDespachado = null;

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
      cargarPedidosPorDespachar();
    });
  });

  const inputFecha = document.getElementById('despachado-filtro-fecha');
  inputFecha?.addEventListener('input', () => {
    filtrosDespachado.fecha = inputFecha.value;
    paginaDespachado = 0;
    cargarDespachados();
  });

  const inputConsecutivo = document.getElementById('despachado-filtro-consecutivo');
  inputConsecutivo?.addEventListener('input', () => {
    clearTimeout(debounceDespachado);
    debounceDespachado = setTimeout(() => {
      filtrosDespachado.consecutivo = inputConsecutivo.value.trim();
      paginaDespachado = 0;
      cargarDespachados();
    }, 350);
  });

  const inputOrdenDespachado = document.getElementById('despachado-filtro-orden');
  inputOrdenDespachado?.addEventListener('input', () => {
    clearTimeout(debounceDespachado);
    debounceDespachado = setTimeout(() => {
      filtrosDespachado.orden = inputOrdenDespachado.value.trim();
      paginaDespachado = 0;
      cargarDespachados();
    }, 350);
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

  document.getElementById('btn-cerrar-resumen-despacho')?.addEventListener('click', cerrarResumenDespacho);
  document.getElementById('btn-cerrar-resumen-despacho-2')?.addEventListener('click', cerrarResumenDespacho);

  poblarFiltrosDropdownDespachos();
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
  if (tabBtn) tabBtn.style.display = rolEfectivo() === 'empaque' ? 'inline-block' : 'none';
}

/** "A Despachar" y "Despachado" son acordeones independientes (<details> nativos) — ambos se cargan siempre, sin importar cuál esté abierto. */
export function cargarDespachosTab() {
  if (!getState().user) return;
  cargarPedidosPorDespachar();
  cargarDespachados();
}

async function poblarFiltrosDropdownDespachos() {
  const rellenar = (id, valores) => {
    const select = document.getElementById(id);
    if (!select) return;
    const actual = select.value;
    valores.forEach((valor) => {
      const option = document.createElement('option');
      option.value = valor;
      option.textContent = valor;
      select.appendChild(option);
    });
    select.value = actual;
  };

  try {
    const [clientes, nombresSuela, materiales, colores] = await Promise.all([
      fetchOpcionesCliente(),
      fetchOpcionesNombreSuela(),
      fetchOpcionesMaterial(),
      fetchOpcionesColor()
    ]);
    rellenar('despacho-filtro-cliente', clientes);
    rellenar('despacho-filtro-nombre-suela', nombresSuela);
    rellenar('despacho-filtro-material', materiales);
    rellenar('despacho-filtro-color', colores);
  } catch (err) {
    console.error('[despachosPage] Error cargando opciones de filtros:', err);
  }
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
  const atributosMobile = [orden.nombre_referencia, orden.material, orden.color, orden.etapa_actual]
    .filter(Boolean)
    .map((v) => escapeHtml(v))
    .join(' · ');
  const claseAnillo = orden.estatus_general === 'Completado' ? 'anillo-completado' : (progreso > 0 ? 'anillo-progreso' : '');

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
      <div class="col-metrica col-metrica-pendiente" title="Suelas aún por procesar">
        <div class="metrica-label"><span class="lbl-full">Pendientes</span><span class="lbl-short">Pend.</span></div>
        <div class="metrica-valor">${orden.total_pendiente ?? 0}</div>
      </div>
      <div class="col-metrica col-metrica-dias" title="Días desde creación del pedido">
        <div class="metrica-label"><span class="lbl-full">Días O.</span><span class="lbl-short">Días</span></div>
        <div class="metrica-valor">${diasOrden}d</div>
      </div>

      <div class="progreso-anillo ${claseAnillo}" style="--pct:${progreso}" title="${progreso}% completado"></div>
      <div class="orden-chevron">›</div>

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

  contenedor.querySelectorAll('.orden-fila').forEach((fila) => {
    fila.addEventListener('click', () => abrirDetalleOrden(fila.dataset.order));
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
  document.getElementById('crear-despacho-pedidos-label').textContent = `Pedidos seleccionados — ${ordenes.length}`;
  document.getElementById('crear-despacho-pedidos-numeros').textContent = ordenes.join(', ');
  document.getElementById('crear-despacho-pedidos-filas').innerHTML = ordenes.map((o) => renderFilaPedidoBulto(o)).join('');
  document.getElementById('crear-despacho-tallas').innerHTML = '';

  wirearFilasPedidoBulto();
  document.getElementById('modal-crear-despacho').classList.add('open');

  try {
    const { totalUnidades, porTalla } = await fetchPreviewCreacionDespacho(ordenes);
    document.getElementById('crear-despacho-total-unidades').textContent = totalUnidades;
    document.getElementById('crear-despacho-tallas').innerHTML = porTalla
      .map((t) => `<tr><td>${escapeHtml(t.talla)}</td><td>${t.unidades}</td></tr>`)
      .join('');
  } catch (err) {
    mostrarToast(err.message, 'error');
  }
}

function cerrarModalCrearSalida() {
  document.getElementById('modal-crear-despacho').classList.remove('open');
}

/** Genera N inputs de peso, conservando los valores ya escritos si el usuario ajusta el número de bultos hacia arriba/abajo. */
function regenerarInputsPesoBultos(n) {
  const cont = document.getElementById('crear-despacho-pesos');
  if (!n || n <= 0) {
    cont.innerHTML = '';
    return;
  }

  const valoresActuales = [...cont.querySelectorAll('.peso-bulto-input')].map((i) => i.value);
  cont.innerHTML = Array.from({ length: n }, (_, i) => `
    <div class="form-group">
      <label>Peso bulto ${i + 1} (kg)</label>
      <input type="number" class="peso-bulto-input" data-bulto="${i + 1}" min="0.01" step="0.01" value="${valoresActuales[i] ?? ''}">
    </div>
  `).join('');
}

/** Una fila por pedido seleccionado: número de pedido + dropdown(s) de bulto + "+". Nada se persiste hasta "Crear Despacho". */
function renderFilaPedidoBulto(orderNumber) {
  return `
    <div class="crear-despacho-pedido-fila" data-order="${escapeHtml(orderNumber)}">
      <div class="crear-despacho-pedido-numero">${escapeHtml(orderNumber)}</div>
      <div class="crear-despacho-pedido-bultos">
        <select class="bulto-select" data-order="${escapeHtml(orderNumber)}"><option value="">Bulto...</option></select>
        <button type="button" class="btn-agregar-bulto-input" data-order="${escapeHtml(orderNumber)}">+</button>
      </div>
    </div>
  `;
}

function wirearFilasPedidoBulto() {
  document.querySelectorAll('#crear-despacho-pedidos-filas .btn-agregar-bulto-input').forEach((btn) => {
    btn.addEventListener('click', () => agregarSelectBulto(btn.dataset.order));
  });
  document.querySelectorAll('#crear-despacho-pedidos-filas .bulto-select').forEach((select) => {
    select.addEventListener('change', () => regenerarOpcionesBultoEnTodasLasFilas(numeroBultosActual()));
  });
}

function numeroBultosActual() {
  return Number(document.getElementById('crear-despacho-num-bultos').value) || 0;
}

function agregarSelectBulto(orderNumber) {
  const fila = document.querySelector(`.crear-despacho-pedido-fila[data-order="${orderNumber}"]`);
  if (!fila) return;

  const cont = fila.querySelector('.crear-despacho-pedido-bultos');
  if (cont.querySelectorAll('.bulto-select').length >= MAX_BULTOS_POR_ORDEN) return;

  const select = document.createElement('select');
  select.className = 'bulto-select';
  select.dataset.order = orderNumber;
  select.addEventListener('change', () => regenerarOpcionesBultoEnTodasLasFilas(numeroBultosActual()));

  const btnQuitar = document.createElement('button');
  btnQuitar.type = 'button';
  btnQuitar.className = 'btn-quitar-bulto-input';
  btnQuitar.title = 'Quitar';
  btnQuitar.textContent = '×';
  btnQuitar.addEventListener('click', () => {
    select.remove();
    btnQuitar.remove();
    actualizarVisibilidadBotonesAgregar();
    regenerarOpcionesBultoEnTodasLasFilas(numeroBultosActual());
  });

  const btnAgregar = cont.querySelector('.btn-agregar-bulto-input');
  cont.insertBefore(select, btnAgregar);
  cont.insertBefore(btnQuitar, btnAgregar);

  regenerarOpcionesBultoEnTodasLasFilas(numeroBultosActual());
  actualizarVisibilidadBotonesAgregar();
}

function actualizarVisibilidadBotonesAgregar() {
  document.querySelectorAll('#crear-despacho-pedidos-filas .crear-despacho-pedido-bultos').forEach((cont) => {
    const btnAgregar = cont.querySelector('.btn-agregar-bulto-input');
    if (!btnAgregar) return;
    btnAgregar.style.display = cont.querySelectorAll('.bulto-select').length >= MAX_BULTOS_POR_ORDEN ? 'none' : '';
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
  if (pesos.some((p) => !Number.isFinite(p) || p <= 0)) {
    mostrarToast('Todos los pesos deben ser mayores a 0.', 'error');
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
      asignaciones
    });
    mostrarToast(`Despacho ${despacho.consecutivo} creado correctamente.`, 'ok');
    cerrarModalCrearSalida();
    seleccionDespacho.clear();
    await cargarPedidosPorDespachar();
    await cargarDespachados();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}

// ---------------------------------------------------------------------
// "Despachado"
// ---------------------------------------------------------------------

async function cargarDespachados() {
  const contenedor = document.getElementById('despachos-lista');
  contenedor.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando despachos...</div>';

  try {
    const { despachos, hayMas } = await fetchDespachos({ page: paginaDespachado, filters: filtrosDespachado });
    hayPaginaSiguienteDespachado = hayMas;
    renderDespachos(despachos);
    renderPaginacionDespachado();
  } catch (err) {
    contenedor.innerHTML = `<div class="card"><div class="empty">${err.message}</div></div>`;
    mostrarToast(err.message, 'error');
  }
}

function badgeAsignacion(valor) {
  const bg = valor ? 'var(--green-bg)' : 'var(--red-bg)';
  const color = valor ? 'var(--green-text)' : 'var(--red-text)';
  return `<span class="despacho-col-badge" style="background:${bg}; color:${color}; padding:3px 10px; border-radius:5px; font-size:12px; font-weight:600; display:inline-block;">${valor ? 'Sí' : 'No'}</span>`;
}

function renderDespachos(despachos) {
  const contenedor = document.getElementById('despachos-lista');

  if (despachos.length === 0) {
    contenedor.innerHTML = '<div class="card"><div class="empty">No hay despachos para mostrar.</div></div>';
    return;
  }

  contenedor.innerHTML = despachos
    .map((d) => {
      const listaOrdenes = (d.order_numbers || []).join(', ');
      return `
        <div class="despacho-fila" data-despacho="${d.id}">
          <div class="despacho-col-consecutivo">${escapeHtml(d.consecutivo)}</div>
          <div class="despacho-col-fecha">${formatearFecha(d.created_at)}</div>
          <div class="despacho-col-lista-ordenes" title="${escapeHtml(listaOrdenes)}">${escapeHtml(listaOrdenes)}</div>
          <div class="despacho-col-num-bultos">${d.total_bultos} bulto${d.total_bultos === 1 ? '' : 's'}</div>
          ${badgeAsignacion(d.asignacion_confirmada)}
        </div>
      `;
    })
    .join('');

  contenedor.querySelectorAll('.despacho-fila').forEach((fila) => {
    fila.addEventListener('click', () => abrirResumenDespacho(fila.dataset.despacho));
  });
}

function renderPaginacionDespachado() {
  const el = document.getElementById('despacho-despachado-paginacion');
  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="despachado-pag-prev" ${paginaDespachado === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${paginaDespachado + 1}</span>
    <button class="btn btn-secondary btn-sm" id="despachado-pag-next" ${hayPaginaSiguienteDespachado ? '' : 'disabled'}>Siguiente →</button>
  `;

  document.getElementById('despachado-pag-prev')?.addEventListener('click', () => {
    paginaDespachado = Math.max(paginaDespachado - 1, 0);
    cargarDespachados();
  });
  document.getElementById('despachado-pag-next')?.addEventListener('click', () => {
    paginaDespachado += 1;
    cargarDespachados();
  });
}

// ---------------------------------------------------------------------
// Modal "Resumen del Despacho" — solo lectura. La asignación de bultos
// ya quedó definida al crear la salida (crear_despacho es atómico), así
// que aquí no hay nada que editar.
// ---------------------------------------------------------------------

async function abrirResumenDespacho(despachoId) {
  document.getElementById('resumen-despacho-contenido').innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  document.getElementById('modal-resumen-despacho').classList.add('open');

  try {
    const [detalle, asignaciones, bultos] = await Promise.all([
      fetchDetalleDespacho(despachoId),
      fetchAsignacionesDespacho(despachoId),
      fetchBultosDespacho(despachoId)
    ]);

    document.getElementById('resumen-despacho-titulo').textContent = `Resumen del Despacho — ${detalle.consecutivo}`;

    const bultosPorOrden = new Map();
    asignaciones.forEach((a) => {
      if (!bultosPorOrden.has(a.order_number)) bultosPorOrden.set(a.order_number, []);
      bultosPorOrden.get(a.order_number).push(a.bulto_numero);
    });

    document.getElementById('resumen-despacho-contenido').innerHTML = `
      <div class="form-group">
        <label>Fecha de creación</label>
        <div>${formatearFecha(detalle.created_at)}</div>
      </div>
      <div class="form-group">
        <label>Pedidos y bultos asignados</label>
        <table style="width:100%; font-size:13px;">
          <thead><tr><th>Pedido</th><th>Bultos</th></tr></thead>
          <tbody>
            ${(detalle.order_numbers || []).map((o) => `
              <tr><td>${escapeHtml(o)}</td><td>${(bultosPorOrden.get(o) || []).sort((a, b) => a - b).join(', ') || '—'}</td></tr>
            `).join('')}
          </tbody>
        </table>
      </div>
      <div class="form-group">
        <label>Bultos y peso</label>
        <table style="width:100%; font-size:13px;">
          <thead><tr><th>Bulto</th><th>Peso (kg)</th></tr></thead>
          <tbody>
            ${bultos.map((b) => `<tr><td>${b.bulto_numero}</td><td>${b.peso}</td></tr>`).join('')}
          </tbody>
        </table>
      </div>
    `;
  } catch (err) {
    document.getElementById('resumen-despacho-contenido').innerHTML = `<div class="empty">${err.message}</div>`;
  }
}

function cerrarResumenDespacho() {
  document.getElementById('modal-resumen-despacho').classList.remove('open');
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
