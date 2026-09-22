import { getState } from '../state/appState.js';
import { fetchCompensacionLineas, fetchProduccionDiaria } from '../services/compensacionService.js';
import { fetchPreciosPorPar, actualizarPrecioPorPar } from '../services/preciosService.js';
import { fetchReglasPrecios, crearReglaPrecio, eliminarReglaPrecio } from '../services/reglasPreciosService.js';
import { fetchOpcionesNombreSuela, fetchOpcionesMaterial, fetchOpcionesColor } from '../services/ordersService.js';
import { esValidador, rolEfectivo, fetchAuditValidador, obtenerRolActivo, establecerRolActivo } from '../services/validatorService.js';
import { ROLE_LABELS, ICONO_PROCESO, esRolDeProceso } from '../lib/roles.js';
import { formatearCOP } from '../lib/money.js';
import { mostrarToast } from './toast.js';
import { sincronizarEtiquetaFiltro } from './customSelect.js';
import { configurarUIDespachos } from './despachosPage.js';

/**
 * Módulo Compensación (ver plan: reglas de negocio confirmadas en 3
 * rondas con el usuario). Cada línea de vw_compensacion_lineas ya trae
 * su valor congelado (precio vigente cuando se hizo el registro) y solo
 * existe si su pedido+rol ya llegó al 100% — no antes.
 *
 * "Rol Activo" (topbar) decide qué ve este módulo, igual que Órdenes:
 * un operario normal ve solo sus propias líneas; Validador actuando
 * como un rol específico ve la nómina completa de ese rol; Validador en
 * "Validador" (vista maestra) no tiene contenido propio aquí.
 */

const MESES = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
];

let periodoSeleccionado = claveMes(new Date());
let lineasActuales = [];
// Unidades por dia (todo lo procesado, liquidado o no) para "Promedio Dia".
let produccionDiaria = [];
let historicoExpandido = false;
let opcionesReglasCargadas = false;
let idReglaPrecioAEliminar = null;

// ---------------------------------------------------------------------
// Inicialización / permisos
// ---------------------------------------------------------------------

export function inicializarPaginaCompensacion() {
  document.querySelectorAll('#comp-tabs-primarios .tab-btn[data-comp-tab]').forEach((btn) => {
    btn.addEventListener('click', () => cambiarTabCompensacion(btn.dataset.compTab, btn));
  });
}

function cambiarTabCompensacion(tab, btnEl) {
  document.querySelectorAll('#comp-tabs-primarios .tab-btn[data-comp-tab]').forEach((b) => b.classList.remove('active'));
  btnEl.classList.add('active');

  const esResumen = tab === 'resumen';
  const esPrecios = tab === 'precios';
  const esReglas = tab === 'reglas-precios';

  document.getElementById('comp-resumen-seccion').style.display = esResumen ? 'block' : 'none';
  document.getElementById('comp-precios-seccion').style.display = esPrecios ? 'block' : 'none';
  document.getElementById('comp-reglas-precios-seccion').style.display = esReglas ? 'block' : 'none';
  document.getElementById('comp-rol-selector-container').style.display = (esResumen && esValidador()) ? 'flex' : 'none';

  if (esPrecios) cargarPreciosPage();
  else if (esReglas) cargarReglasPreciosPage();
}

/**
 * Análoga a configurarUIValidador() en dashboard.js: se llama una vez
 * por login. Compensación no aplica a Comercial (no procesa pares) —
 * el nav-item queda oculto para ese rol. "Precios por Par" y "Reglas de
 * Precios" son exclusivas de Validador, mismo patrón que
 * tab-btn-reglas/tab-btn-validador/tab-btn-audit.
 */
export function configurarUICompensacionValidador() {
  const { user } = getState();
  const navItem = document.getElementById('nav-item-compensacion');
  if (navItem) navItem.style.display = user?.role === 'comercial' ? 'none' : 'flex';

  const esVal = esValidador();
  document.getElementById('tab-btn-resumen').style.display = esVal ? 'inline-block' : 'none';
  document.getElementById('tab-btn-precios').style.display = esVal ? 'inline-block' : 'none';
  document.getElementById('tab-btn-reglas-precios').style.display = esVal ? 'inline-block' : 'none';
  document.getElementById('comp-header-card')?.classList.toggle('con-tabs', esVal);

  // "Resumen" es la pestaña activa por defecto (ver class="active" en
  // index.html) cada vez que esta función corre (una vez por login), así
  // que el selector de Rol Activo debe mostrarse junto con ella.
  document.getElementById('comp-rol-selector-container').style.display = esVal ? 'flex' : 'none';

  if (!esVal) return;

  const rolActivo = obtenerRolActivo();
  let selector = document.getElementById('comp-rol-activo-selector');
  if (selector) {
    // Mismo motivo que rol-activo-selector en dashboard.js: clonar para
    // no apilar otro listener 'change' en cada login dentro de la misma
    // pestaña del navegador.
    const selectorLimpio = selector.cloneNode(true);
    selector.replaceWith(selectorLimpio);
    selector = selectorLimpio;

    selector.value = rolActivo;
    sincronizarEtiquetaFiltro('comp-rol-activo-selector');
    selector.addEventListener('change', async () => {
      establecerRolActivo(selector.value);
      mostrarToast(`Actuando como ${selector.value}`, 'ok');

      // Mismo Rol Activo, dos selectores (este y el de Órdenes) —
      // mantener el otro sincronizado para que no muestre un valor viejo
      // si el usuario cambia de página sin volver a iniciar sesión.
      const selectorOrdenes = document.getElementById('rol-activo-selector');
      if (selectorOrdenes) {
        selectorOrdenes.value = selector.value;
        sincronizarEtiquetaFiltro('rol-activo-selector');
      }

      // La pestaña "Despachos" (en Órdenes) depende de rolEfectivo() —
      // mantenerla sincronizada aunque el cambio se haga desde aquí.
      configurarUIDespachos();

      await cargarCompensacion();
    });
  }
}

// ---------------------------------------------------------------------
// Carga principal (tab "Compensación")
// ---------------------------------------------------------------------

export async function cargarCompensacion() {
  const { user, currentPage } = getState();
  if (!user || currentPage !== 'compensacion') return;

  const rol = rolEfectivo();
  if (!esRolDeProceso(rol)) {
    renderEstadoVacioSinRol();
    return;
  }

  try {
    [lineasActuales, produccionDiaria] = await Promise.all([
      fetchCompensacionLineas(user),
      fetchProduccionDiaria(user)
    ]);
  } catch (err) {
    mostrarToast(err.message, 'error');
    lineasActuales = [];
    produccionDiaria = [];
  }

  poblarSelectorPeriodo();
  configurarCustomSelect();
  await renderTodo();
}

function renderEstadoVacioSinRol() {
  const mensaje = '<div class="empty">Selecciona un rol específico (Refilado/Acabado/Mateado/Empaque) en "Rol Activo" para ver su compensación.</div>';
  document.getElementById('comp-indicadores').innerHTML = '';
  document.getElementById('comp-produccion-mes-body').innerHTML = mensaje;
  document.getElementById('comp-detalle-liquidacion-body').innerHTML = '';
  document.getElementById('comp-historico-body').innerHTML = '';
  document.getElementById('comp-evolucion-body').innerHTML = '';
  document.getElementById('comp-total-pagar-mobile').innerHTML = '';
  document.getElementById('comp-ultima-actualizacion').textContent = 'Última actualización: —';
}

function claveMes(fecha) {
  return `${fecha.getFullYear()}-${String(fecha.getMonth() + 1).padStart(2, '0')}`;
}

function nombreMes(clave) {
  const [anio, mes] = clave.split('-').map(Number);
  return `${MESES[mes - 1]} ${anio}`;
}

function poblarSelectorPeriodo() {
  const dropdown = document.getElementById('comp-periodo-dropdown');
  if (!dropdown) return; // Salir si el elemento no existe

  const claves = new Set([claveMes(new Date())]);
  lineasActuales.forEach((l) => claves.add(claveMes(new Date(l.fecha_liquidacion))));

  const ordenadas = [...claves].sort().reverse();

  if (!ordenadas.includes(periodoSeleccionado) && periodoSeleccionado !== 'historico') {
    periodoSeleccionado = ordenadas[0];
  }

  const opciones = [
    ...ordenadas.map((clave) => ({ value: clave, label: nombreMes(clave) })),
    { value: 'historico', label: 'Histórico' }
  ];

  dropdown.innerHTML = opciones
    .map((opt) => `
      <div class="comp-periodo-option ${opt.value === periodoSeleccionado ? 'active' : ''}" data-value="${opt.value}">
        ${opt.label}
      </div>
    `)
    .join('');

  // Actualizar etiqueta
  const label = document.getElementById('comp-periodo-label');
  const opcionActiva = opciones.find((opt) => opt.value === periodoSeleccionado);
  if (opcionActiva) {
    label.textContent = opcionActiva.label;
  }

}

function configurarCustomSelect() {
  const btn = document.querySelector('.comp-periodo-btn');
  const dropdown = document.getElementById('comp-periodo-dropdown');

  if (!btn || !dropdown) return;

  // Remover evento anterior si existe (clone y reemplaza)
  const newBtn = btn.cloneNode(true);
  btn.parentNode.replaceChild(newBtn, btn);
  const newBtnRef = document.querySelector('.comp-periodo-btn');

  // Agregar nuevo evento al botón
  newBtnRef.addEventListener('click', (e) => {
    e.stopPropagation();
    dropdown.classList.toggle('open');

    // En mobile, calcular la posición correcta del dropdown
    if (window.innerWidth <= 768) {
      const rect = newBtnRef.getBoundingClientRect();
      dropdown.style.top = (rect.bottom + 8) + 'px';
    }
  });

  // Agregar event listeners a las opciones
  dropdown.querySelectorAll('.comp-periodo-option').forEach((opt) => {
    opt.addEventListener('click', () => {
      periodoSeleccionado = opt.dataset.value;
      dropdown.classList.remove('open');
      poblarSelectorPeriodo();
      cargarCompensacion();
    });
  });

  // Cerrar dropdown al hacer click afuera (se ejecuta una sola vez globalmente)
  if (!window.compSelectClickOutsideConfigured) {
    document.addEventListener('click', (e) => {
      const customSelect = document.querySelector('.comp-periodo-custom-select');
      if (customSelect && !e.target.closest('.comp-periodo-custom-select')) {
        const dropdown = document.getElementById('comp-periodo-dropdown');
        if (dropdown) {
          dropdown.classList.remove('open');
        }
      }
    });
    window.compSelectClickOutsideConfigured = true;
  }
}

async function renderTodo() {
  const esHistorico = periodoSeleccionado === 'historico';
  const lineasDelPeriodo = esHistorico
    ? lineasActuales
    : lineasActuales.filter((l) => claveMes(new Date(l.fecha_liquidacion)) === periodoSeleccionado);

  await renderIndicadores(lineasDelPeriodo, esHistorico);
  renderHistoricoUnificado(lineasDelPeriodo, esHistorico);
  renderEvolucion12Meses();
  renderUltimaActualizacion();
}

// ---------------------------------------------------------------------
// Indicadores
// ---------------------------------------------------------------------

async function renderIndicadores(lineasDelPeriodo, esHistorico) {
  const rol = rolEfectivo();
  const totalHistorico = lineasActuales.reduce((s, l) => s + l.quantity, 0);
  const totalPeriodo = lineasDelPeriodo.reduce((s, l) => s + l.quantity, 0);
  const devengadoPeriodo = lineasDelPeriodo.reduce((s, l) => s + Number(l.valor_cop || 0), 0);

  let tarifa = null;
  if (esValidador()) {
    const precios = await fetchPreciosPorPar();
    tarifa = precios.find((p) => p.rol === rol)?.precio ?? null;
  } else if (lineasActuales.length > 0) {
    // Operario normal no tiene acceso a precios_por_par (RLS): se
    // deriva de su propia línea más reciente, ya visible para él mismo.
    const masReciente = [...lineasActuales].sort((a, b) => new Date(b.fecha_registro) - new Date(a.fecha_registro))[0];
    tarifa = masReciente?.precio_cop ?? null;
  }

  const labelPeriodo = esHistorico ? 'Producción Histórica' : 'Mes Seleccionado';

  // Promedio de suelas por día: se divide entre los días que TIENEN
  // registro, no entre los días del calendario — un día sin trabajo no
  // debe castigar el promedio. Sigue el selector de periodo, igual que
  // las tarjetas vecinas.
  const diasDelPeriodo = esHistorico
    ? produccionDiaria
    : produccionDiaria.filter((d) => claveMes(new Date(`${d.dia}T00:00:00`)) === periodoSeleccionado);

  // El mismo día puede venir en varias filas si el Validador está
  // emulando un rol con varios operarios: hay que agrupar antes de contar.
  const unidadesPorDia = new Map();
  diasDelPeriodo.forEach((d) => {
    unidadesPorDia.set(d.dia, (unidadesPorDia.get(d.dia) || 0) + Number(d.unidades || 0));
  });

  const totalDias = unidadesPorDia.size;
  const unidadesTotales = [...unidadesPorDia.values()].reduce((s, u) => s + u, 0);
  const promedioDia = totalDias > 0 ? Math.round(unidadesTotales / totalDias) : null;

  const items = [
    {
      icono: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>',
      color: '#6366f1',
      bgColor: '#e0e7ff',
      label: 'Total Histórico',
      valor: totalHistorico.toLocaleString('es-CO'),
      unidad: 'suelas'
    },
    {
      icono: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>',
      color: '#3b82f6',
      bgColor: '#dbeafe',
      label: labelPeriodo,
      valor: totalPeriodo.toLocaleString('es-CO'),
      unidad: 'suelas'
    },
    {
      icono: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M3 6a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V6z"/><line x1="3" y1="10" x2="21" y2="10"/></svg>',
      color: '#10b981',
      bgColor: '#d1fae5',
      label: esHistorico ? 'Devengado Histórico' : 'Devengado Mes',
      valor: formatearCOP(devengadoPeriodo),
      unidad: 'COP'
    },
    {
      icono: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M6 3h12a2 2 0 0 1 2 2v6l-8 8H6a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z"/><circle cx="14" cy="9" r="1.5"/></svg>',
      color: '#b45309',
      bgColor: '#fef3c7',
      label: 'Tarifa por Suela',
      valor: tarifa != null ? formatearCOP(tarifa) : '—',
      unidad: tarifa != null ? 'COP' : ''
    },
    {
      icono: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="9"/><polyline points="12 7 12 12 15.5 14"/></svg>',
      color: '#7c3aed',
      bgColor: '#ede9fe',
      label: 'Promedio Día',
      valor: promedioDia != null ? promedioDia.toLocaleString('es-CO') : '—',
      unidad: promedioDia != null ? `suelas/día · ${totalDias} día${totalDias === 1 ? '' : 's'}` : ''
    }
  ];

  document.getElementById('comp-indicadores').innerHTML = `
    <div class="comp-indicadores-card">
      ${items.map((i, idx) => `
        <div class="comp-indicador-fila">
          <div class="comp-indicador-icono" style="background-color: ${i.bgColor}; color: ${i.color};">
            ${i.icono}
          </div>
          <div class="comp-indicador-contenido">
            <span class="comp-indicador-label">${i.label}</span>
            <div class="comp-indicador-valor-grupo">
              <span class="comp-indicador-valor">${i.valor}</span>
              ${i.unidad ? `<span class="comp-indicador-unidad">${i.unidad}</span>` : ''}
            </div>
          </div>
        </div>
        ${idx < items.length - 1 ? '<div class="comp-indicador-divisor"></div>' : ''}
      `).join('')}
    </div>
  `;
}

// ========================================================================
// Histórico Unificado: Mes Actual + Histórico de Producción en UNA vista
// ========================================================================

function renderHistoricoUnificado(lineasDelPeriodo, esHistoricoSelector) {
  const titulo = document.getElementById('comp-historico-titulo');
  titulo.innerHTML = `
    Histórico de Producción
    <svg class="comp-chevron" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><polyline points="6 9 12 15 18 9"/></svg>`;

  const body = document.getElementById('comp-historico-body');

  // Solo mostrar Histórico por Mes (sin tabs)
  renderVistaHistorico();

  // Setup del modal
  configurarModalHistoricoDetalle();
}

function renderVistaHistorico() {
  const container = document.getElementById('comp-historico-body');
  if (!container) return;

  const porMes = new Map();
  lineasActuales.forEach((l) => {
    const clave = claveMes(new Date(l.fecha_liquidacion));
    const acc = porMes.get(clave) || { suelas: 0, devengado: 0, clave };
    acc.suelas += l.quantity;
    acc.devengado += Number(l.valor_cop || 0);
    porMes.set(clave, acc);
  });

  const meses = [...porMes.values()].sort((a, b) => b.clave.localeCompare(a.clave));

  if (meses.length === 0) {
    container.innerHTML = '<div class="empty">Sin histórico todavía.</div>';
    return;
  }

  const LIMITE = 5;
  const visibles = historicoExpandido ? meses : meses.slice(0, LIMITE);
  const hayMas = meses.length > LIMITE;

  container.innerHTML = `
    <table>
      <thead>
        <tr><th>Mes</th><th>Suelas Procesadas</th><th>Devengado (COP)</th><th></th></tr>
      </thead>
      <tbody>
        ${visibles.map((m) => `
          <tr>
            <td>${nombreMes(m.clave)}</td>
            <td>${m.suelas.toLocaleString('es-CO')}</td>
            <td>${formatearCOP(m.devengado)}</td>
            <td><button class="btn btn-primary btn-sm btn-ver-historico" data-mes="${m.clave}">Ver</button></td>
          </tr>`).join('')}
      </tbody>
    </table>
    ${hayMas ? `<button class="btn btn-secondary btn-sm" id="comp-ver-historico-completo" style="margin-top:0.5rem;">${historicoExpandido ? '← Ver menos' : 'Ver histórico completo →'}</button>` : ''}`;

  // Listeners para botones "Ver"
  container.querySelectorAll('.btn-ver-historico').forEach((btn) => {
    btn.addEventListener('click', () => {
      abrirModalHistoricoDetalle(btn.dataset.mes);
    });
  });

  document.getElementById('comp-ver-historico-completo')?.addEventListener('click', () => {
    historicoExpandido = !historicoExpandido;
    renderVistaHistorico();
  });
}

function abrirModalHistoricoDetalle(mesClave) {
  const modal = document.getElementById('modal-historico-detalle');
  const titulo = document.getElementById('modal-historico-titulo');
  const tabla = document.getElementById('modal-historico-tabla');

  titulo.textContent = `Registros de ${nombreMes(mesClave)}`;

  // Filtrar líneas del mes seleccionado
  const lineasDelMes = lineasActuales.filter((l) => claveMes(new Date(l.fecha_liquidacion)) === mesClave);

  if (lineasDelMes.length === 0) {
    tabla.innerHTML = '<div class="empty">Sin registros en este mes.</div>';
    modal.classList.add('visible');
    return;
  }

  // Agrupar por número de orden
  const ordenesMap = {};
  lineasDelMes.forEach((l) => {
    if (!ordenesMap[l.order_number]) {
      ordenesMap[l.order_number] = {
        order_number: l.order_number,
        fecha_liquidacion: l.fecha_liquidacion,
        totalPares: 0,
        totalDevengado: 0,
        reference: l.reference,
        registros: []
      };
    }
    ordenesMap[l.order_number].totalPares += l.quantity;
    ordenesMap[l.order_number].totalDevengado += (l.valor_cop || 0);
    ordenesMap[l.order_number].registros.push(l);
  });

  const ordenesPorgrupo = Object.values(ordenesMap).sort((a, b) => {
    return a.order_number.localeCompare(b.order_number);
  });

  // Calcular totales generales
  const totalPares = lineasDelMes.reduce((sum, l) => sum + l.quantity, 0);
  const totalDevengado = lineasDelMes.reduce((sum, l) => sum + (l.valor_cop || 0), 0);

  tabla.innerHTML = `
    <table>
      <thead>
        <tr>
          <th>FechaFin</th>
          <th>Número de Orden</th>
          <th>Referencia</th>
          <th>Pares</th>
          <th>Total</th>
        </tr>
      </thead>
      <tbody>
        ${ordenesPorgrupo.map((orden) => `
          <tr>
            <td>${formatearFechaCorta(orden.fecha_liquidacion)}</td>
            <td><a class="comp-orden-link" data-orden="${escapeHtml(orden.order_number)}" style="color:var(--blue); cursor:pointer; text-decoration:none; font-weight:600;">${escapeHtml(orden.order_number)}</a></td>
            <td>${escapeHtml(orden.reference || '—')}</td>
            <td>${orden.totalPares}</td>
            <td>${formatearCOP(orden.totalDevengado)}</td>
          </tr>`).join('')}
        <tr style="border-top: 2px solid var(--border2); font-weight:600; background:var(--surface); color:var(--text1);">
          <td colspan="3" style="padding:0.75rem; text-align:right;">TOTAL</td>
          <td style="padding:0.75rem;">${totalPares}</td>
          <td style="padding:0.75rem;">${formatearCOP(totalDevengado)}</td>
        </tr>
      </tbody>
    </table>`;

  // Agregar event listeners a los números de orden
  tabla.querySelectorAll('.comp-orden-link').forEach((link) => {
    link.addEventListener('click', () => {
      const ordenNumber = link.dataset.orden;
      modal.classList.remove('visible');
      irACartillaOrden(ordenNumber);
    });
  });

  modal.classList.add('visible');
}

function irACartillaOrden(orderNumber) {
  // Navegar a Órdenes
  const navBtn = document.querySelector('button[data-page="ordenes"]');
  if (navBtn) {
    navBtn.click();
  }

  // Después de navegar, clickear la pestaña "Completadas" y luego buscar la orden
  setTimeout(() => {
    // Click en pestaña "Completadas"
    const btnCompletadas = document.querySelector('button[data-tab="completadas"]');
    if (btnCompletadas) {
      btnCompletadas.click();
    }

    // Buscar y clickear la orden
    setTimeout(() => {
      const ordenFila = document.querySelector(`.orden-fila[data-order="${orderNumber}"]`);
      if (ordenFila) {
        ordenFila.click();
      }
    }, 300);
  }, 300);
}

function configurarModalHistoricoDetalle() {
  const modal = document.getElementById('modal-historico-detalle');
  const btnCerrar = document.getElementById('btn-cerrar-historico-detalle');

  if (!btnCerrar) return;

  btnCerrar.addEventListener('click', () => {
    modal.classList.remove('visible');
  });

  // Cerrar al hacer clic fuera del modal
  modal.addEventListener('click', (e) => {
    if (e.target === modal) {
      modal.classList.remove('visible');
    }
  });
}

// ---------------------------------------------------------------------
// Evolución 12 Meses — SVG a mano (sin librerías, el proyecto no trae
// ninguna), una sola serie "Suelas Procesadas".
// ---------------------------------------------------------------------

function renderEvolucion12Meses() {
  const finKey = periodoSeleccionado === 'historico' ? claveMes(new Date()) : periodoSeleccionado;
  const [finAnio, finMes] = finKey.split('-').map(Number);

  const claves = [];
  for (let i = 11; i >= 0; i--) {
    const d = new Date(finAnio, finMes - 1 - i, 1);
    claves.push(claveMes(d));
  }

  const porMes = new Map();
  lineasActuales.forEach((l) => {
    const clave = claveMes(new Date(l.fecha_liquidacion));
    porMes.set(clave, (porMes.get(clave) || 0) + l.quantity);
  });

  const valores = claves.map((c) => porMes.get(c) || 0);
  const maximo = Math.max(...valores, 1);

  const W = 600, H = 200, PAD_L = 36, PAD_B = 24, PAD_T = 12, PAD_R = 12;
  const anchoUtil = W - PAD_L - PAD_R;
  const altoUtil = H - PAD_T - PAD_B;
  const paso = anchoUtil / (claves.length - 1);

  const puntos = valores.map((v, i) => {
    const x = PAD_L + i * paso;
    const y = PAD_T + altoUtil - (v / maximo) * altoUtil;
    return { x, y, v };
  });

  const polyline = puntos.map((p) => `${p.x.toFixed(1)},${p.y.toFixed(1)}`).join(' ');
  const circulos = puntos.map((p) => `<circle cx="${p.x.toFixed(1)}" cy="${p.y.toFixed(1)}" r="3" fill="var(--blue)"></circle>`).join('');
  const etiquetasX = claves.map((c, i) => {
    const [, mes] = c.split('-').map(Number);
    const x = PAD_L + i * paso;
    return `<text x="${x.toFixed(1)}" y="${H - 4}" font-size="9" fill="var(--text3)" text-anchor="middle">${MESES[mes - 1].slice(0, 3)}</text>`;
  }).join('');

  document.getElementById('comp-evolucion-body').innerHTML = `
    <div style="display:flex; align-items:center; gap:6px; margin-bottom:0.5rem; font-size:12px; color:var(--text2);">
      <span style="width:10px; height:10px; border-radius:2px; background:var(--blue); display:inline-block;"></span>
      Suelas Procesadas
    </div>
    <svg viewBox="0 0 ${W} ${H}" style="width:100%; height:auto;">
      <line x1="${PAD_L}" y1="${PAD_T}" x2="${PAD_L}" y2="${H - PAD_B}" stroke="var(--border)" stroke-width="1"></line>
      <line x1="${PAD_L}" y1="${H - PAD_B}" x2="${W - PAD_R}" y2="${H - PAD_B}" stroke="var(--border)" stroke-width="1"></line>
      <polyline points="${polyline}" fill="none" stroke="var(--blue)" stroke-width="2"></polyline>
      ${circulos}
      ${etiquetasX}
    </svg>`;
}

// ---------------------------------------------------------------------
// Última actualización (dd/mm/yyyy, sin hora)
// ---------------------------------------------------------------------

function renderUltimaActualizacion() {
  const el = document.getElementById('comp-ultima-actualizacion');
  if (lineasActuales.length === 0) {
    el.textContent = 'Última actualización: —';
    return;
  }
  const masReciente = lineasActuales.reduce((max, l) => {
    const f = new Date(l.fecha_registro);
    return f > max ? f : max;
  }, new Date(0));
  el.textContent = `Última actualización: ${formatearFechaCorta(masReciente)}`;
}

function formatearFechaCorta(fecha) {
  const d = fecha instanceof Date ? fecha : new Date(fecha);
  const dia = String(d.getDate()).padStart(2, '0');
  const mes = String(d.getMonth() + 1).padStart(2, '0');
  return `${dia}/${mes}/${d.getFullYear()}`;
}

function formatearFechaHora(fecha) {
  const d = fecha instanceof Date ? fecha : new Date(fecha);
  const hora = String(d.getHours()).padStart(2, '0');
  const min = String(d.getMinutes()).padStart(2, '0');
  return `${formatearFechaCorta(d)} ${hora}:${min}`;
}

// ---------------------------------------------------------------------
// Tab "Precios por Par" (exclusiva de Validador)
// ---------------------------------------------------------------------

async function cargarPreciosPage() {
  const cont = document.getElementById('comp-precios-seccion');
  cont.innerHTML = '<div class="card"><div class="loading"><div class="spinner"></div> Cargando...</div></div>';

  const [precios, logCambios] = await Promise.all([
    fetchPreciosPorPar(),
    fetchAuditValidador({ accion: 'precio_actualizado' })
  ]);

  cont.innerHTML = `
    <div class="card">
      <div class="card-title">Precios por Par</div>
      <table>
        <thead><tr><th>Rol</th><th>Precio (COP)</th><th></th></tr></thead>
        <tbody>
          ${precios.map((p) => `
            <tr>
              <td>${ROLE_LABELS[p.rol] || p.rol} ${ICONO_PROCESO[ROLE_LABELS[p.rol]] || ''}</td>
              <td><input type="number" min="0" step="1" class="input-precio-rol" data-rol="${p.rol}" value="${p.precio}" style="width:120px; padding:6px 10px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;"></td>
              <td><button class="btn btn-primary btn-sm btn-guardar-precio" data-rol="${p.rol}">Guardar</button></td>
            </tr>`).join('')}
        </tbody>
      </table>
    </div>

    <div class="card">
      <div class="card-title">Log de Cambios de Precio</div>
      ${logCambios.length === 0 ? '<div class="empty">Sin cambios registrados.</div>' : `
      <table>
        <thead><tr><th>Fecha/Hora</th><th>Rol</th><th>Precio Anterior</th><th>Precio Nuevo</th></tr></thead>
        <tbody>
          ${logCambios.map((r) => `
            <tr>
              <td>${formatearFechaHora(r.creado_en)}</td>
              <td>${r.rol_actuante}</td>
              <td>${r.detalle?.precio_anterior != null ? formatearCOP(r.detalle.precio_anterior) : '—'}</td>
              <td>${r.detalle?.precio_nuevo != null ? formatearCOP(r.detalle.precio_nuevo) : '—'}</td>
            </tr>`).join('')}
        </tbody>
      </table>`}
    </div>`;

  cont.querySelectorAll('.btn-guardar-precio').forEach((btn) => {
    btn.addEventListener('click', async () => {
      const { user } = getState();
      const rol = btn.dataset.rol;
      const input = cont.querySelector(`.input-precio-rol[data-rol="${rol}"]`);
      const nuevoPrecio = Number(input.value);

      if (!(nuevoPrecio >= 0)) {
        mostrarToast('Ingresa un precio válido.', 'error');
        return;
      }

      btn.disabled = true;
      try {
        await actualizarPrecioPorPar(rol, nuevoPrecio, user);
        mostrarToast('Precio actualizado.', 'ok');
      } catch (err) {
        mostrarToast(err.message, 'error');
      } finally {
        btn.disabled = false;
      }
    });
  });
}

// ---------------------------------------------------------------------
// Tab "Reglas de Precios" (exclusiva de Validador) — mirror de
// reglasPage.js, con tipo_usuario + destino añadidos.
// ---------------------------------------------------------------------

async function cargarReglasPreciosPage() {
  const cont = document.getElementById('comp-reglas-precios-seccion');

  if (!cont.dataset.montado) {
    cont.dataset.montado = '1';
    cont.innerHTML = `
      <div class="card">
        <div class="card-title">Nueva Regla de Precio</div>
        <div style="display:grid; grid-template-columns:1fr 1fr 1fr 1fr 1fr auto; gap:0.75rem; align-items:end;">
          <div>
            <label style="display:block; font-size:11px; font-weight:600; color:var(--text2); margin-bottom:6px; text-transform:uppercase;">Tipo de Usuario</label>
            <select id="regla-precio-tipo-usuario" style="width:100%; padding:8px 10px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;">
              <option value="">Selecciona...</option>
              <option value="refilado">Refilado</option>
              <option value="acabado">Acabado</option>
              <option value="mateado">Mateado</option>
              <option value="empaque">Empaque</option>
            </select>
          </div>
          <div>
            <label style="display:block; font-size:11px; font-weight:600; color:var(--text2); margin-bottom:6px; text-transform:uppercase;">Nombre Suela</label>
            <select id="regla-precio-nombre-suela" style="width:100%; padding:8px 10px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;"><option value="">Cualquiera</option></select>
          </div>
          <div>
            <label style="display:block; font-size:11px; font-weight:600; color:var(--text2); margin-bottom:6px; text-transform:uppercase;">Material</label>
            <select id="regla-precio-material" style="width:100%; padding:8px 10px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;"><option value="">Cualquiera</option></select>
          </div>
          <div>
            <label style="display:block; font-size:11px; font-weight:600; color:var(--text2); margin-bottom:6px; text-transform:uppercase;">Color</label>
            <select id="regla-precio-color" style="width:100%; padding:8px 10px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;"><option value="">Cualquiera</option></select>
          </div>
          <div>
            <label style="display:block; font-size:11px; font-weight:600; color:var(--text2); margin-bottom:6px; text-transform:uppercase;">Destino</label>
            <select id="regla-precio-destino" style="width:100%; padding:8px 10px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;">
              <option value="">Cualquiera</option>
              <option value="Acabado">Acabado</option>
              <option value="Mateado">Mateado</option>
              <option value="Empaque">Empaque</option>
            </select>
          </div>
          <div>
            <label style="display:block; font-size:11px; font-weight:600; color:var(--text2); margin-bottom:6px; text-transform:uppercase;">Precio (COP)</label>
            <input type="number" id="regla-precio-valor" min="0" step="1" style="width:100%; padding:8px 10px; border:1.5px solid var(--border2); border-radius:6px; font-size:13px;">
          </div>
        </div>
        <button class="btn btn-primary btn-sm" id="btn-guardar-regla-precio" style="margin-top:1rem;">Guardar Regla</button>
      </div>

      <div class="card">
        <table>
          <thead>
            <tr>
              <th>Tipo Usuario</th><th>Nombre Suela</th><th>Material</th><th>Color</th><th>Destino</th><th>Precio</th><th>Creada por</th><th></th>
            </tr>
          </thead>
          <tbody id="reglas-precios-tabla"><tr><td colspan="8" class="empty">Cargando...</td></tr></tbody>
        </table>
      </div>`;

    document.getElementById('btn-guardar-regla-precio').addEventListener('click', guardarReglaPrecio);
  }

  if (!opcionesReglasCargadas) {
    await poblarSelectsReglaPrecio();
    opcionesReglasCargadas = true;
  }

  await renderTablaReglasPrecios();
}

async function poblarSelectsReglaPrecio() {
  const rellenar = (id, valores) => {
    const select = document.getElementById(id);
    if (!select) return;
    valores.forEach((valor) => {
      const option = document.createElement('option');
      option.value = valor;
      option.textContent = valor;
      select.appendChild(option);
    });
  };

  try {
    const [nombresSuela, materiales, colores] = await Promise.all([
      fetchOpcionesNombreSuela(),
      fetchOpcionesMaterial(),
      fetchOpcionesColor()
    ]);
    rellenar('regla-precio-nombre-suela', nombresSuela);
    rellenar('regla-precio-material', materiales);
    rellenar('regla-precio-color', colores);
  } catch (err) {
    console.error('[compensacionPage] Error cargando opciones de reglas de precio:', err);
  }
}

async function renderTablaReglasPrecios() {
  const tbody = document.getElementById('reglas-precios-tabla');
  const reglas = await fetchReglasPrecios();

  if (reglas.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="empty">No hay reglas de precio configuradas.</td></tr>';
    return;
  }

  tbody.innerHTML = reglas
    .map((r) => `
      <tr>
        <td>${ROLE_LABELS[r.tipo_usuario] || r.tipo_usuario}</td>
        <td>${escapeHtml(r.nombre_referencia || 'Cualquiera')}</td>
        <td>${escapeHtml(r.material || 'Cualquiera')}</td>
        <td>${escapeHtml(r.color || 'Cualquiera')}</td>
        <td>${escapeHtml(r.destino || 'Cualquiera')}</td>
        <td>${formatearCOP(r.precio)}</td>
        <td>${escapeHtml(r.profiles?.name || '—')}</td>
        <td><button class="btn btn-danger btn-sm btn-eliminar-regla-precio" data-id="${r.id}">Eliminar</button></td>
      </tr>`)
    .join('');

  tbody.querySelectorAll('.btn-eliminar-regla-precio').forEach((btn) => {
    btn.addEventListener('click', async () => {
      idReglaPrecioAEliminar = btn.dataset.id;
      if (!confirm('¿Eliminar esta regla de precio?')) return;
      try {
        await eliminarReglaPrecio(idReglaPrecioAEliminar);
        mostrarToast('Regla eliminada.', 'ok');
        renderTablaReglasPrecios();
      } catch (err) {
        mostrarToast(err.message, 'error');
      }
    });
  });
}

async function guardarReglaPrecio() {
  const { user } = getState();

  const tipoUsuario = document.getElementById('regla-precio-tipo-usuario').value;
  const nombreReferencia = document.getElementById('regla-precio-nombre-suela').value;
  const material = document.getElementById('regla-precio-material').value;
  const color = document.getElementById('regla-precio-color').value;
  const destino = document.getElementById('regla-precio-destino').value;
  const precio = Number(document.getElementById('regla-precio-valor').value);

  if (!tipoUsuario) {
    mostrarToast('Selecciona el tipo de usuario.', 'error');
    return;
  }
  if (!nombreReferencia && !material && !color && !destino) {
    mostrarToast('Selecciona al menos un criterio (Nombre Suela, Material, Color o Destino).', 'error');
    return;
  }
  if (!(precio >= 0)) {
    mostrarToast('Ingresa un precio válido.', 'error');
    return;
  }

  const btn = document.getElementById('btn-guardar-regla-precio');
  btn.disabled = true;

  try {
    await crearReglaPrecio({ tipoUsuario, nombreReferencia, material, color, destino, precio }, user);
    mostrarToast('Regla de precio guardada.', 'ok');
    document.getElementById('regla-precio-tipo-usuario').value = '';
    document.getElementById('regla-precio-nombre-suela').value = '';
    document.getElementById('regla-precio-material').value = '';
    document.getElementById('regla-precio-color').value = '';
    document.getElementById('regla-precio-destino').value = '';
    document.getElementById('regla-precio-valor').value = '';
    renderTablaReglasPrecios();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
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
