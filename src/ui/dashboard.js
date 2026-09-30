import { fetchOrders, fetchFacetasOrdenes } from '../services/ordersService.js';
import { calcularOpciones, reconstruirSelect } from '../lib/facetas.js';
import { getState, setState } from '../state/appState.js';
import { estadoPorPorcentaje } from '../lib/calculations.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { mostrarToast } from './toast.js';
import { cargarHistorial } from './historyPage.js';
import { cargarReglas } from './reglasPage.js';
import { generarExcel } from '../services/excelService.js';
import { esValidador, esVistaMaestra, obtenerRolActivo, establecerRolActivo, usuarioEfectivo, rolEfectivo } from '../services/validatorService.js';
import { cargarValidadorPage } from './validatorPage.js';
import { cargarAuditPage } from './auditPage.js';
import { cargarDespachosTab, configurarUIDespachos } from './despachosPage.js';
import { cargarEliminaciones } from './eliminacionesPage.js';
import { cargarCompensacion } from './compensacionPage.js';
import { alternarCierreForzado } from './cierreForzado.js';
import { inicializarFiltrosCustomSelect, sincronizarEtiquetaFiltro } from './customSelect.js';

const PAGE_SIZE = 30;

let paginaActual = 0;
let hayPaginaSiguiente = false;
let filtros = { orden: '', cliente: '', nombreSuela: '', material: '', color: '', fecha: '' };
let debounceTimer = null;
// Una fila por pedido visible en la pestaña (Activas o Completadas), para
// calcular las opciones de los filtros en cascada. Se descarga al entrar
// a la pestaña, no en cada cambio de filtro.
let filasFacetas = [];
let tabFacetas = null;

const CAMPOS_FACETAS = {
  orden: { columna: 'order_number', modo: 'contiene' },
  cliente: { columna: 'cliente', modo: 'exacto', lista: true },
  nombreSuela: { columna: 'nombre_referencia', modo: 'exacto', lista: true },
  material: { columna: 'material', modo: 'exacto', lista: true },
  color: { columna: 'color', modo: 'exacto', lista: true },
  fecha: { columna: 'fecha_pedido', modo: 'exacto' }
};

const SELECT_POR_FACETA = {
  cliente: 'filtro-cliente',
  nombreSuela: 'filtro-nombre-suela',
  material: 'filtro-material',
  color: 'filtro-color'
};

/**
 * Se llama DESPUÉS del login (main.js -> iniciarApp), no en el bootstrap
 * inicial, porque necesita getState().user ya cargado — a diferencia de
 * inicializarPaginaOrdenes() (que solo registra listeners y sí corre
 * antes del login).
 */
export function configurarUIValidador() {
  const esVal = esValidador();

  // Descarga de Excel: solo Validador (Refilado/Acabado/Mateado/Empaque
  // solo necesitan procesar, no descargar el reporte completo).
  const btnExcel = document.getElementById('btn-descargar-excel');
  if (btnExcel) btnExcel.style.display = esVal ? '' : 'none';

  // Completadas y Registros (sin id propio): Propuesta no los ve; el resto
  // sí. Se fija siempre para no arrastrar el estado de una sesión anterior
  // en la misma pestaña del navegador.
  const esPropuesta = getState().user?.role === 'propuesta';
  ['completadas', 'registros'].forEach((t) => {
    const b = document.querySelector(`#tabs-primarios .tab-btn[data-tab="${t}"]`);
    if (b) b.style.display = esPropuesta ? 'none' : '';
  });

  if (!esVal) {
    // Sin esto, un usuario NO-validador que inicia sesión en la misma
    // pestaña donde antes hubo una sesión de Validador (el logout no
    // recarga la página, ver navigation.js) sigue viendo estos 4
    // elementos: nada los ocultaba de nuevo al cambiar de sesión.
    // "Reglas de Enrutamiento" es exclusiva de Validador — Refilado ya
    // no la ve (antes era una excepción explícita, se retiró).
    document.getElementById('tab-btn-reglas').style.display = 'none';
    // Control Central (solo lectura, sin Excel): además del Validador, lo
    // ven Propuesta y Empaque.
    const verControlCentral = esPropuesta || getState().user?.role === 'empaque';
    document.getElementById('tab-btn-validador').style.display = verControlCentral ? 'inline-block' : 'none';
    document.getElementById('tab-btn-audit').style.display = 'none';
    document.getElementById('tab-btn-eliminaciones').style.display = 'none';
    // Sin "Rol Activo": es exclusivo del Validador.
    document.getElementById('rol-selector-container').style.display = 'none';
    return;
  }

  document.getElementById('tab-btn-reglas').style.display = 'inline-block';
  document.getElementById('tab-btn-validador').style.display = 'inline-block';
  document.getElementById('tab-btn-audit').style.display = 'inline-block';
  document.getElementById('tab-btn-eliminaciones').style.display = 'inline-block';
  document.getElementById('rol-selector-container').style.display = 'grid';

  const rolActivo = obtenerRolActivo();
  let selector = document.getElementById('rol-activo-selector');
  if (selector) {
    // Esta función corre una vez por login: sin clonar el nodo, cada
    // sesión de Validador en la misma pestaña (sin recargar) apilaría
    // otro listener 'change' sobre el anterior.
    const selectorLimpio = selector.cloneNode(true);
    selector.replaceWith(selectorLimpio);
    selector = selectorLimpio;

    selector.value = rolActivo;
    sincronizarEtiquetaFiltro('rol-activo-selector');
    selector.addEventListener('change', async () => {
      const nuevoRol = selector.value;
      establecerRolActivo(nuevoRol);
      mostrarToast(`Actuando como ${nuevoRol}`, 'ok');

      // Mismo Rol Activo, dos selectores (este y el de Compensación) —
      // mantener el otro sincronizado para que no muestre un valor viejo
      // si el usuario cambia de página sin volver a iniciar sesión.
      const selectorComp = document.getElementById('comp-rol-activo-selector');
      if (selectorComp) {
        selectorComp.value = nuevoRol;
        sincronizarEtiquetaFiltro('comp-rol-activo-selector');
      }

      // La pestaña "Despachos" depende de rolEfectivo(), no del rol real
      // — un Validador que deja de emular Empaque debe dejar de verla.
      configurarUIDespachos();

      // Refresca la vista actual con el nuevo rol efectivo — antes el
      // selector solo guardaba el valor y no pasaba nada visible.
      // "Rol Activo" es global (topbar), así que también debe refrescar
      // Compensación si esa es la página activa, no solo Órdenes.
      const { currentTab, currentPage } = getState();
      if (currentPage === 'compensacion') {
        await cargarCompensacion();
        return;
      }

      // Si estaba en Despachos y el nuevo rol ya no es Empaque, la
      // pestaña acaba de ocultarse: regresar a "Activas" en vez de dejar
      // la sección de Despachos visible sin su botón de pestaña.
      if (currentTab === 'despachos' && !esValidador() && rolEfectivo() !== 'empaque') {
        document.querySelector('#tabs-primarios .tab-btn[data-tab="activas"]')?.click();
        return;
      }

      paginaActual = 0;
      // Otro rol ve otros pedidos: las opciones de los filtros cambian.
      tabFacetas = null;
      if (currentTab === 'registros') {
        await cargarHistorial();
      } else if (currentTab === 'despachos') {
        await cargarDespachosTab();
      } else if (!['validador', 'audit', 'reglas', 'eliminaciones'].includes(currentTab)) {
        await cargarOrdenes();
        await cargarFacetasOrdenes();
      }
    });
  }
}

export function inicializarPaginaOrdenes() {
  document.querySelectorAll('#page-ordenes .tab-btn[data-tab]').forEach((btn) => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('#page-ordenes .tab-btn[data-tab]').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      const tab = btn.dataset.tab;
      setState({ currentTab: tab });

      const esRegistros = tab === 'registros';
      const esReglas = tab === 'reglas';
      const esPestanaValidador = tab === 'validador';
      const esAudit = tab === 'audit';
      const esDespachos = tab === 'despachos';
      const esEliminaciones = tab === 'eliminaciones';
      const esOrdenes = !esRegistros && !esReglas && !esPestanaValidador && !esAudit && !esDespachos && !esEliminaciones;

      // La barra "Filtros (n) / Limpiar" de celular solo sirve en Activas
      // y Completadas. Al salir se cierra también el panel: su regla de
      // "abierto" lleva !important y le ganaría al display:none de abajo.
      const barraMovil = document.getElementById('filtros-barra-mobile');
      const divisorMovil = document.getElementById('ordenes-header-divider');
      if (barraMovil) barraMovil.style.display = esOrdenes ? '' : 'none';
      if (divisorMovil) divisorMovil.style.display = esOrdenes ? '' : 'none';
      if (!esOrdenes) {
        document.getElementById('ordenes-filtros')?.classList.remove('filtros-abiertos');
        document.getElementById('btn-toggle-filtros')?.classList.remove('filtros-activo');
      }

      document.getElementById('ordenes-filtros').style.display = esOrdenes ? 'grid' : 'none';
      document.getElementById('ordenes-seccion').style.display = esOrdenes ? 'block' : 'none';
      document.getElementById('registros-seccion').style.display = esRegistros ? 'block' : 'none';
      document.getElementById('reglas-seccion').style.display = esReglas ? 'block' : 'none';
      document.getElementById('page-validador').style.display = esPestanaValidador ? 'block' : 'none';
      document.getElementById('page-audit').style.display = esAudit ? 'block' : 'none';
      document.getElementById('despachos-seccion').style.display = esDespachos ? 'block' : 'none';
      document.getElementById('eliminaciones-seccion').style.display = esEliminaciones ? 'block' : 'none';

      if (esRegistros) {
        cargarHistorial();
      } else if (esReglas) {
        cargarReglas();
      } else if (esPestanaValidador) {
        cargarValidadorPage();
      } else if (esAudit) {
        cargarAuditPage();
      } else if (esDespachos) {
        cargarDespachosTab();
      } else if (esEliminaciones) {
        cargarEliminaciones();
      } else {
        paginaActual = 0;
        cargarOrdenes();
        cargarFacetasOrdenes();
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
        actualizarContadorFiltros();
        actualizarOpcionesFiltros();
        cargarOrdenes();
      });
    } else {
      el.addEventListener('input', () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          filtros[FILTRO_ID_A_CLAVE[id]] = el.value.trim();
          paginaActual = 0;
          actualizarContadorFiltros();
          actualizarOpcionesFiltros();
          cargarOrdenes();
        }, 350);
      });
    }
  });

  inicializarFiltrosCustomSelect();
  inicializarControlesMobile();
  actualizarContadorFiltros();

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
/**
 * Descarga (una vez por pestaña) los pedidos visibles para calcular las
 * opciones de los filtros en cascada. Se llama al entrar a Activas o
 * Completadas, tras el login, al cambiar de Rol Activo y en los refrescos
 * en tiempo real.
 * @param {{ forzar?: boolean }} opciones forzar=true ignora la caché de pestaña
 */
export async function cargarFacetasOrdenes({ forzar = false } = {}) {
  const { user, currentTab } = getState();
  if (!user || !['activas', 'completadas'].includes(currentTab)) return;
  if (!forzar && tabFacetas === currentTab) {
    actualizarOpcionesFiltros();
    return;
  }

  const tabPedida = currentTab;
  const filas = await fetchFacetasOrdenes(usuarioEfectivo(), tabPedida);

  // Si mientras tanto el usuario cambió de pestaña, esta respuesta ya no aplica.
  if (getState().currentTab !== tabPedida) return;

  filasFacetas = filas;
  tabFacetas = tabPedida;
  actualizarOpcionesFiltros();
}

/** Recalcula las cuatro listas con los filtros actuales (sin consultar). */
function actualizarOpcionesFiltros() {
  const opciones = calcularOpciones(filasFacetas, filtros, CAMPOS_FACETAS);
  Object.entries(SELECT_POR_FACETA).forEach(([clave, selectId]) => {
    reconstruirSelect(selectId, opciones[clave] || []);
    sincronizarEtiquetaFiltro(selectId);
  });
}

/**
 * Controles exclusivos de móvil (barra "Filtros (N)"/"Limpiar"). En
 * desktop/tablet quedan ocultos por CSS y estos listeners simplemente
 * no se disparan porque los elementos no son visibles/clickeables ahí.
 */
function inicializarControlesMobile() {
  const btnToggleFiltros = document.getElementById('btn-toggle-filtros');
  const panelFiltros = document.getElementById('ordenes-filtros');
  btnToggleFiltros?.addEventListener('click', () => {
    const abierto = panelFiltros.classList.toggle('filtros-abiertos');
    btnToggleFiltros.classList.toggle('filtros-activo', abierto);
  });

  document.getElementById('btn-limpiar-filtros')?.addEventListener('click', () => {
    filtros = { orden: '', cliente: '', nombreSuela: '', material: '', color: '', fecha: '' };
    ['filtro-orden', 'filtro-cliente', 'filtro-nombre-suela', 'filtro-material', 'filtro-color', 'filtro-fecha'].forEach((id) => {
      const el = document.getElementById(id);
      if (el) el.value = '';
    });
    ['filtro-cliente', 'filtro-nombre-suela', 'filtro-material', 'filtro-color'].forEach(sincronizarEtiquetaFiltro);
    paginaActual = 0;
    actualizarContadorFiltros();
    actualizarOpcionesFiltros();
    cargarOrdenes();
  });
}

function actualizarContadorFiltros() {
  const activos = Object.values(filtros).filter((v) => v && v.trim() !== '').length;

  const contador = document.getElementById('filtros-contador');
  if (contador) contador.textContent = `(${activos})`;

  // "Limpiar" siempre está visible (estabilidad de layout) pero solo se
  // activa (azul, clickeable) cuando hay al menos un filtro — deshabilitado
  // (gris, pointer-events:none vía CSS) cuando no hay ninguno.
  const btnLimpiar = document.getElementById('btn-limpiar-filtros');
  if (btnLimpiar) btnLimpiar.classList.toggle('activo', activos > 0);
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
    // Validador con un "Rol Activo" de proceso (Refilado/Acabado/...) ve
    // exactamente lo que vería ese rol real (usuarioEfectivo() reemplaza
    // solo el campo role, conserva id/nombre reales para auditoría).
    const { orders, hayMas } = await fetchOrders(usuarioEfectivo(), currentTab, {
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

/**
 * Para Validador: en vez del badge/barra global (que puede ser engañoso,
 * ver 018_fix_etapa_fin.sql), muestra el % de CADA proceso por separado —
 * cada uno se calcula independiente contra el total del pedido, así que
 * Mateado en 0% no se confunde con "el pedido ya terminó".
 */
function renderBadgesPorProceso(orden) {
  return `
    <div style="display:flex; gap:4px; flex-wrap:wrap;">
      <span style="background:var(--blue-bg); color:var(--blue); padding:2px 6px; border-radius:4px; font-size:10px; font-weight:600;" title="Refilado">R ${orden.porcentaje_refilado ?? 0}%</span>
      <span style="background:var(--green-bg); color:var(--green-text); padding:2px 6px; border-radius:4px; font-size:10px; font-weight:600;" title="Acabado">A ${orden.porcentaje_acabado ?? 0}%</span>
      <span style="background:var(--purple-bg); color:var(--purple-text); padding:2px 6px; border-radius:4px; font-size:10px; font-weight:600;" title="Mateado">M ${orden.porcentaje_mateado ?? 0}%</span>
      <span style="background:var(--amber-bg); color:var(--amber-text); padding:2px 6px; border-radius:4px; font-size:10px; font-weight:600;" title="Empaque">E ${orden.porcentaje_empaque ?? 0}%</span>
    </div>
  `;
}

function renderOrdenes(orders) {
  const contenedor = document.getElementById('ordenes-lista');

  if (orders.length === 0) {
    contenedor.innerHTML = '<div class="card"><div class="empty">No hay órdenes para mostrar.</div></div>';
    return;
  }

  // Los badges por proceso (4 en 1) solo aplican en la vista MAESTRA de
  // Validador (Rol Activo = "Validador"). Si Validador está actuando
  // como un proceso específico, ve el mismo badge/barra que vería ese
  // rol real — "exactamente como lo vería un usuario Acabado real".
  const modoMaestroValidador = esVistaMaestra();

  contenedor.innerHTML = orders
    .map((orden) => {
      const progreso = orden.porcentaje_completado || 0;
      const estado = estadoPorPorcentaje(progreso);
      const diasOrden = orden.dias_orden ?? 0;

      // Solo para la card compacta de móvil (ver @media max-width:767px
      // en index.html): línea única "Suela · Material · Color · Etapa"
      // y anillo de progreso, en vez de las columnas separadas + badge +
      // barra que usa desktop/tablet.
      // La etapa ya no va aqui: en movil tiene su propia celda bajo el numero de orden.
      const atributosMobile = [orden.nombre_referencia, orden.material, orden.color]
        .filter(Boolean)
        .map((v) => escapeHtml(v))
        .join(' · ');
      const claseAnillo = orden.estatus_general === 'Completado'
        ? 'anillo-completado'
        : (progreso > 0 ? 'anillo-progreso' : '');

      // Cierre forzado (057): el check lo ve solo el Validador en vista
      // maestra; el badge y el fondo amarillo, todos.
      const forzada = !!orden.cierre_forzado;
      const puedeCerrar = esValidador() && esVistaMaestra();
      const marcaCierre = forzada ? `
          <div class="orden-cierre">
            <span class="badge-forzada" title="Cerrada a la fuerza por ${escapeHtml(orden.cierre_forzado_por || 'el Validador')}: ${escapeHtml(orden.cierre_forzado_motivo || '')}">Cerrada</span>
          </div>` : '';

      // Check a la IZQUIERDA y FUERA de la tarjeta, igual que en
      // Despachos > A Despachar (círculo .checkbox-registro).
      const checkCierre = puedeCerrar ? `<input type="checkbox" class="checkbox-registro" data-cierre-forzado="${escapeHtml(orden.order_number)}"
              ${forzada ? 'checked' : ''}
              title="${forzada ? 'Cerrada a la fuerza. Desmarca para reabrir el pedido.' : 'Cerrar el pedido a la fuerza (pasa a Completadas)'}"
              aria-label="Cerrar pedido a la fuerza">` : '';

      const tarjeta = `
        <div class="orden-fila${forzada ? ' forzada' : ''}" data-order="${escapeHtml(orden.order_number)}">
          ${marcaCierre}
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

          <div class="col-estado" title="${modoMaestroValidador ? 'Progreso independiente por proceso' : 'Completado: procesado 100% | En Proceso: aún hay pendientes'}">
            ${modoMaestroValidador ? renderBadgesPorProceso(orden) : `
              <span class="estado-badge estado-${orden.estatus_general === 'Completado' ? 'completado' : 'en-proceso'}">${orden.estatus_general}</span>
              <div class="progreso-contenedor">
                <div class="progreso-barra"><div class="progreso-lleno" style="width:${progreso}%"></div></div>
                <span class="progreso-pct">${progreso}%</span>
              </div>
            `}
          </div>
        </div>
      `;
      return puedeCerrar ? `<div class="orden-fila-con-check">${checkCierre}${tarjeta}</div>` : tarjeta;
    })
    .join('');

  contenedor.querySelectorAll('.orden-fila').forEach((fila) => {
    fila.addEventListener('click', () => abrirDetalleOrden(fila.dataset.order));
  });

  contenedor.querySelectorAll('input[data-cierre-forzado]').forEach((check) => {
    check.addEventListener('change', () => alternarCierreForzado(check, async () => {
      await cargarOrdenes();
      cargarFacetasOrdenes({ forzar: true });
    }));
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

  renderPaginacionMobile();
}

/**
 * Paginación real para móvil (Anterior/Siguiente, reemplaza la lista —
 * no acumula). Usa exactamente el mismo estado (paginaActual,
 * hayPaginaSiguiente) y la misma cargarOrdenes() que el paginador de
 * escritorio de arriba: comparten la lógica de filtros+paginación de
 * ordersService.js, solo cambia la presentación.
 */
function renderPaginacionMobile() {
  const btnPrev = document.getElementById('mobile-pag-prev');
  const btnNext = document.getElementById('mobile-pag-next');
  const info = document.getElementById('mobile-pag-info');

  if (info) info.textContent = `Página ${paginaActual + 1}`;
  if (btnPrev) btnPrev.disabled = paginaActual === 0;
  if (btnNext) btnNext.disabled = !hayPaginaSiguiente;

  if (btnPrev && !btnPrev.dataset.wired) {
    btnPrev.dataset.wired = '1';
    btnPrev.addEventListener('click', () => {
      paginaActual = Math.max(paginaActual - 1, 0);
      cargarOrdenes();
    });
  }
  if (btnNext && !btnNext.dataset.wired) {
    btnNext.dataset.wired = '1';
    btnNext.addEventListener('click', () => {
      paginaActual += 1;
      cargarOrdenes();
    });
  }
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
