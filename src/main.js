import { obtenerSesionActual } from './services/authService.js';
import { getState, setState } from './state/appState.js';
import { ROLE_LABELS } from './lib/roles.js';

import { initLoginPage, mostrarLogin, ocultarLogin } from './ui/login.js';
import { initAccessCodeModal, mostrarAccessCodeModal, ocultarAccessCodeModal } from './ui/accessCodeModal.js';
import { inicializarNavegacion } from './ui/navigation.js';
import { inicializarPaginaOrdenes, cargarOrdenes, cargarFacetasOrdenes, configurarUIValidador } from './ui/dashboard.js';
import { inicializarModalDetalle, refrescarDetalleActual } from './ui/orderDetail.js';
import { inicializarModalProcesar } from './ui/processModal.js';
import { inicializarModalDevolucion } from './ui/returnModal.js';
import { inicializarPaginaHistorial, cargarHistorial, configurarFiltroProcesoHistorial } from './ui/historyPage.js';
import { inicializarPaginaReglas } from './ui/reglasPage.js';
import { refrescarValidadorSiVisible } from './ui/validatorPage.js';
import { inicializarPaginaCompensacion, configurarUICompensacionValidador, cargarCompensacion } from './ui/compensacionPage.js';
import { inicializarPaginaDespachos, configurarUIDespachos, cargarDespachosTab } from './ui/despachosPage.js';
import { inicializarPaginaRegistrosDespachos } from './ui/registrosDespachosPage.js';
import { inicializarModalDetalleDespacho } from './ui/despachoDetalleModal.js';
import { inicializarPaginaEliminaciones } from './ui/eliminacionesPage.js';
import { inicializarPaginaPropuesta, configurarUIPropuesta, cargarPropuesta } from './ui/propuestaPage.js';
import { iniciarRealtime } from './realtime.js';

/**
 * Punto de entrada de la app. No usa ningún framework: conecta la UI
 * (ya definida en index.html, adaptada de produccion_app.html) con
 * Supabase mediante los módulos de src/services y src/ui.
 */

/**
 * Campos marcados con data-solo-digitos (No. Orden, No. Despacho...):
 * descarta todo lo que no sea número. Va en fase de captura para que el
 * valor ya llegue limpio a los listeners de cada filtro. El teclado
 * numérico en celular lo pone inputmode="numeric" en el propio campo.
 */
function inicializarCamposNumericos() {
  document.addEventListener('input', (e) => {
    const el = e.target;
    if (!el.matches?.('[data-solo-digitos]')) return;
    const limpio = el.value.replace(/\D/g, '');
    if (limpio !== el.value) el.value = limpio;
  }, true);
}

function inicializarUI() {
  inicializarCamposNumericos();
  inicializarNavegacion();
  inicializarPaginaOrdenes();
  inicializarPaginaHistorial();
  inicializarModalDetalle();
  inicializarModalProcesar();
  inicializarModalDevolucion();
  inicializarPaginaReglas();
  inicializarPaginaCompensacion();
  inicializarPaginaDespachos();
  inicializarPaginaRegistrosDespachos();
  inicializarModalDetalleDespacho();
  inicializarPaginaEliminaciones();
  inicializarPaginaPropuesta();

  initLoginPage(mostrarModalCodigoAcceso);
}

function mostrarModalCodigoAcceso(user) {
  ocultarLogin();
  mostrarAccessCodeModal();
  initAccessCodeModal(user, () => iniciarApp(user));
}

async function iniciarApp(user) {
  setState({ user, currentPage: 'ordenes', currentTab: 'activas' });
  // Las dos puertas de entrada terminan aquí: el login normal (que pasa
  // por el código de acceso) y la restauración de sesión al recargar la
  // página. Por eso se esconde el login ACÁ y no solo en el camino del
  // código: al recargar, la sesión se restauraba bien y la app quedaba
  // funcionando por debajo, pero la pantalla de login seguía encima y
  // parecía que la sesión se había caído.
  ocultarLogin();
  ocultarAccessCodeModal();

  document.getElementById('topbar-nombre').textContent = user.name;
  document.getElementById('topbar-rol').textContent = ROLE_LABELS[user.role] || user.role;

  // El rol 'propuesta' (cotizador de precios) es un módulo independiente
  // de la arquitectura de producción: no toca órdenes, compensación,
  // despachos ni historial — ver src/ui/propuestaPage.js.
  configurarUIPropuesta();
  if (user.role === 'propuesta') {
    await cargarPropuesta();
    return;
  }

  // La pestaña "Reglas de Enrutamiento" es exclusiva de Validador —
  // configurarUIValidador() la muestra/oculta según corresponda.
  configurarUIValidador();
  configurarUICompensacionValidador();
  configurarUIDespachos();
  configurarFiltroProcesoHistorial(user);

  await cargarOrdenes();
  cargarFacetasOrdenes({ forzar: true });

  iniciarRealtime(async () => {
    const { currentTab, currentPage } = getState();
    if (currentPage === 'compensacion') {
      await cargarCompensacion();
      return;
    }
    if (currentTab === 'registros') await cargarHistorial();
    else if (currentTab === 'validador') await refrescarValidadorSiVisible();
    else if (currentTab === 'despachos') await cargarDespachosTab();
    else if (!['audit', 'reglas', 'eliminaciones'].includes(currentTab)) {
      await cargarOrdenes();
      // Pedidos nuevos o que cambiaron de pestaña: las listas se actualizan.
      cargarFacetasOrdenes({ forzar: true });
    }
    await refrescarDetalleActual();
  });
}

async function bootstrap() {
  inicializarUI();

  const user = await obtenerSesionActual();
  if (user) {
    await iniciarApp(user);
  } else {
    mostrarLogin();
  }
}

bootstrap();
