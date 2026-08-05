import { fetchOrders, fetchOpcionesCliente, fetchOpcionesNombreSuela, fetchOpcionesMaterial, fetchOpcionesColor } from '../services/ordersService.js';
import { getState, setState } from '../state/appState.js';
import { estadoPorPorcentaje } from '../lib/calculations.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { mostrarToast } from './toast.js';
import { cargarHistorial } from './historyPage.js';
import { cargarReglas } from './reglasPage.js';
import { generarExcel } from '../services/excelService.js';

const PAGE_SIZE = 30;

let paginaActual = 0;
let hayPaginaSiguiente = false;
let filtros = { orden: '', cliente: '', nombreSuela: '', material: '', color: '', fecha: '' };
let debounceTimer = null;

export function inicializarPaginaOrdenes() {
  document.querySelectorAll('#page-ordenes .tab-btn[data-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#page-ordenes .tab-btn[data-tab]').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      const tab = btn.dataset.tab;
      setState({ currentTab: tab });

      const esRegistros = tab === 'registros';
      const esReglas = tab === 'reglas';
      const esOrdenes = !esRegistros && !esReglas;

      document.getElementById('ordenes-filtros').style.display = esOrdenes ? 'grid' : 'none';
      document.getElementById('ordenes-seccion').style.display = esOrdenes ? 'block' : 'none';
      document.getElementById('registros-seccion').style.display = esRegistros ? 'block' : 'none';
      document.getElementById('reglas-seccion').style.display = esReglas ? 'block' : 'none';

      if (esRegistros) {
        cargarHistorial();
      } else if (esReglas) {
        cargarReglas();
      } else {
        paginaActual = 0;
        cargarOrdenes();
      }
    });
  });

  const FILTRO_ID_A_CLAVE = {
    'filtro-orden': 'orden',
    'filtro-cliente': 'cliente',
    'filtro-nombre-suela': 'nombreSuela',
    'filtro-material': 'material',
    'filtro-color': 'color',
    'filtro-fecha': 'fecha'
  };

  Object.keys(FILTRO_ID_A_CLAVE).forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;

    if (el.tagName === 'SELECT') {
      // Dropdown: aplica de inmediato, sin debounce (es una selección
      // puntual, no texto que se sigue escribiendo).
      el.addEventListener('change', () => {
        filtros[FILTRO_ID_A_CLAVE[id]] = el.value;
        paginaActual = 0;
        cargarOrdenes();
      });
    } else {
      el.addEventListener('input', () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          filtros[FILTRO_ID_A_CLAVE[id]] = el.value.trim();
          paginaActual = 0;
          cargarOrdenes();
        }, 350);
      });
    }
  });

  poblarFiltrosDropdown();

  const btnExcel = document.getElementById('btn-descargar-excel');
  if (btnExcel) {
    btnExcel.addEventListener('click', async () => {
      btnExcel.disabled = true;
      const textoOriginal = btnExcel.textContent;
      btnExcel.textContent = '⏳ Generando...';

      try {
        await generarExcel();
        mostrarToast('Excel descargado correctamente', 'ok');
      } catch (err) {
        console.error('[dashboard] Error generando Excel:', err);
        mostrarToast(err.message || 'Error al generar Excel', 'error');
      } finally {
        btnExcel.disabled = false;
        btnExcel.textContent = textoOriginal;
      }
    });
  }
}

/**
 * Carga las opciones de los dropdowns (Nombre Suela/Material/Color) desde
 * la base de datos (ver vw_nombres_suela/vw_materiales/vw_colores en
 * supabase/sql/011_filtros_opciones.sql). Se lee en vivo, así que un
 * valor nuevo que llegue en un pedido futuro aparece automáticamente la
 * próxima vez que se cargue la app, sin tocar código.
 */
async function poblarFiltrosDropdown() {
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
    rellenar('filtro-cliente', clientes);
    rellenar('filtro-nombre-suela', nombresSuela);
    rellenar('filtro-material', materiales);
    rellenar('filtro-color', colores);
  } catch (err) {
    console.error('[dashboard] Error cargando opciones de filtros:', err);
  }
}

// Evita que una respuesta VIEJA (ej. de un llamado disparado por realtime
// justo antes de cambiar de pestaña/filtro) sobreescriba el listado con
// datos desactualizados si llega DESPUÉS de una petición más reciente.
let solicitudActual = 0;

export async function cargarOrdenes() {
  const { user, currentTab } = getState();
  if (!user) return;

  const miSolicitud = ++solicitudActual;

  const contenedor = document.getElementById('ordenes-lista');
  contenedor.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando órdenes...</div>';

  try {
    const { orders, hayMas } = await fetchOrders(user, currentTab, {
      page: paginaActual,
      filters: filtros
    });

    // Si mientras esperábamos esta respuesta se disparó OTRA carga más
    // reciente, esta ya quedó obsoleta: no pisar lo que se esté mostrando.
    if (miSolicitud !== solicitudActual) return;

    hayPaginaSiguiente = hayMas;
    setState({ orders });
    renderOrdenes(orders);
    renderPaginacion();
  } catch (err) {
    if (miSolicitud !== solicitudActual) return;
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
      const diasOrden = orden.dias_orden ?? 0;

      return `
        <div class="orden-fila" data-order="${escapeHtml(orden.order_number)}">
          <div class="col-numero" title="Número de orden">${escapeHtml(orden.order_number)}</div>
          <div class="col-cliente" title="Nombre del cliente">${escapeHtml(orden.cliente || '—')}</div>
          <div class="col-fecha" title="Fecha de creación del pedido">${formatearFecha(orden.fecha_pedido)}</div>
          <div class="col-nombre-suela" title="Nombre de la suela">${escapeHtml(orden.nombre_referencia || '—')}</div>
          <div class="col-material" title="Material">${escapeHtml(orden.material || '—')}</div>
          <div class="col-color" title="Color">${escapeHtml(orden.color || '—')}</div>

          <div class="col-metrica" title="Cantidad total solicitada">
            <div class="metrica-label">Total Suelas</div>
            <div class="metrica-valor">${orden.total_solicitado ?? 0}</div>
          </div>
          <div class="col-metrica" title="Suelas ya procesadas">
            <div class="metrica-label">Procesadas</div>
            <div class="metrica-valor">${orden.total_procesado ?? 0}</div>
          </div>
          <div class="col-metrica" title="Suelas aún por procesar">
            <div class="metrica-label">Pendientes</div>
            <div class="metrica-valor">${orden.total_pendiente ?? 0}</div>
          </div>

          <div class="col-metrica" title="Días desde creación del pedido">
            <div class="metrica-label">Días O.</div>
            <div class="metrica-valor">${diasOrden}d</div>
          </div>

          <div class="col-estado" title="Completado: procesado 100% | En Proceso: aún hay pendientes">
            <span class="estado-badge estado-${orden.estatus_general === 'Completado' ? 'completado' : 'en-proceso'}">${orden.estatus_general}</span>
            <div class="progreso-contenedor">
              <div class="progreso-barra"><div class="progreso-lleno" style="width:${progreso}%"></div></div>
              <span class="progreso-pct">${progreso}%</span>
            </div>
          </div>
        </div>
      `;
    })
    .join('');

  contenedor.querySelectorAll('.orden-fila').forEach((fila) => {
    fila.addEventListener('click', () => abrirDetalleOrden(fila.dataset.order));
  });
}

function renderPaginacion() {
  const el = document.getElementById('ordenes-paginacion');

  // Sin conteo exacto (ver ordersService.js): no sabemos el total de
  // páginas de antemano, solo si la página actual trajo una fila extra
  // que indica que hay una siguiente.
  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="orden-pag-prev" ${paginaActual === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${paginaActual + 1}</span>
    <button class="btn btn-secondary btn-sm" id="orden-pag-next" ${hayPaginaSiguiente ? '' : 'disabled'}>Siguiente →</button>
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
