import { obtenerSesionActual } from './services/authService.js';
import { getState, setState } from './state/appState.js';
import { ROLE_LABELS } from './lib/roles.js';

import { initLoginPage, mostrarLogin, ocultarLogin } from './ui/login.js';
import { inicializarNavegacion } from './ui/navigation.js';
import { inicializarPaginaOrdenes, cargarOrdenes } from './ui/dashboard.js';
import { inicializarModalDetalle, refrescarDetalleActual } from './ui/orderDetail.js';
import { inicializarModalProcesar } from './ui/processModal.js';
import { inicializarModalDevolucion } from './ui/returnModal.js';
import { inicializarPaginaHistorial, cargarHistorial } from './ui/historyPage.js';
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

  initLoginPage(iniciarApp);
}

async function iniciarApp(user) {
  setState({ user, currentPage: 'ordenes', currentTab: 'activas' });
  ocultarLogin();

  document.getElementById('topbar-nombre').textContent = user.name;
  document.getElementById('topbar-rol').textContent = ROLE_LABELS[user.role] || user.role;

  await cargarOrdenes();

  iniciarRealtime(async () => {
    const { currentPage } = getState();
    if (currentPage === 'ordenes') await cargarOrdenes();
    if (currentPage === 'historial') await cargarHistorial();
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
