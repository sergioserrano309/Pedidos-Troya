import { obtenerSesionActual } from './services/authService.js';
import { getState, setState } from './state/appState.js';
import { ROLE_LABELS } from './lib/roles.js';

import { initLoginPage, mostrarLogin, ocultarLogin } from './ui/login.js';
import { initAccessCodeModal, mostrarAccessCodeModal, ocultarAccessCodeModal } from './ui/accessCodeModal.js';
import { inicializarNavegacion } from './ui/navigation.js';
import { inicializarPaginaOrdenes, cargarOrdenes, configurarUIValidador } from './ui/dashboard.js';
import { inicializarModalDetalle, refrescarDetalleActual } from './ui/orderDetail.js';
import { inicializarModalProcesar } from './ui/processModal.js';
import { inicializarModalDevolucion } from './ui/returnModal.js';
import { inicializarPaginaHistorial, cargarHistorial, configurarFiltroProcesoHistorial } from './ui/historyPage.js';
import { inicializarPaginaReglas } from './ui/reglasPage.js';
import { refrescarValidadorSiVisible } from './ui/validatorPage.js';
import { inicializarPaginaCompensacion, configurarUICompensacionValidador, cargarCompensacion } from './ui/compensacionPage.js';
import { inicializarPaginaDespachos, configurarUIDespachos, cargarDespachosTab } from './ui/despachosPage.js';
import { iniciarRealtime } from './realtime.js';

/**
 * Punto de entrada de la app. No usa ningún framework: conecta la UI
 * (ya definida en index.html, adaptada de produccion_app.html) con
 * Supabase mediante los módulos de src/services y src/ui.
 */

function inicializarUI() {
  inicializarNavegacion();
  inicializarPaginaOrdenes();
  inicializarPaginaHistorial();
  inicializarModalDetalle();
  inicializarModalProcesar();
  inicializarModalDevolucion();
  inicializarPaginaReglas();
  inicializarPaginaCompensacion();
  inicializarPaginaDespachos();

  initLoginPage(mostrarModalCodigoAcceso);
}

function mostrarModalCodigoAcceso(user) {
  ocultarLogin();
  mostrarAccessCodeModal();
  initAccessCodeModal(user, () => iniciarApp(user));
}

async function iniciarApp(user) {
  setState({ user, currentPage: 'ordenes', currentTab: 'activas' });
  ocultarAccessCodeModal();

  document.getElementById('topbar-nombre').textContent = user.name;
  document.getElementById('topbar-rol').textContent = ROLE_LABELS[user.role] || user.role;

  // La pestaña "Reglas de Enrutamiento" es exclusiva de Validador —
  // configurarUIValidador() la muestra/oculta según corresponda.
  configurarUIValidador();
  configurarUICompensacionValidador();
  configurarUIDespachos();
  configurarFiltroProcesoHistorial(user);

  await cargarOrdenes();

  iniciarRealtime(async () => {
    const { currentTab, currentPage } = getState();
    if (currentPage === 'compensacion') {
      await cargarCompensacion();
      return;
    }
    if (currentTab === 'registros') await cargarHistorial();
    else if (currentTab === 'validador') await refrescarValidadorSiVisible();
    else if (currentTab === 'despachos') await cargarDespachosTab();
    else if (!['audit', 'reglas'].includes(currentTab)) await cargarOrdenes();
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
