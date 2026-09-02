import { logout as logoutService } from '../services/authService.js';
import { resetState, setState } from '../state/appState.js';
import { mostrarLogin } from './login.js';
import { cargarOrdenes } from './dashboard.js';
import { cargarCompensacion } from './compensacionPage.js';
import { cargarPropuesta } from './propuestaPage.js';

// Un loader por cada página de alto nivel del sidebar (ver
// index.html: <button class="nav-item" data-page="...">). Agregar una
// página nueva es agregar una entrada aquí, sin tocar cambiarPagina().
const LOADERS_POR_PAGINA = {
  ordenes: cargarOrdenes,
  compensacion: cargarCompensacion,
  propuesta: cargarPropuesta
};

const MOBILE_BREAKPOINT = 768;
const SIDEBAR_COLLAPSED_KEY = 'sidebarColapsado';

export function inicializarNavegacion() {
  document.querySelectorAll('.nav-item[data-page]').forEach((btn) => {
    btn.addEventListener('click', () => {
      cambiarPagina(btn.dataset.page, btn);
      cerrarSidebarMobile();
    });
  });

  document.getElementById('btn-logout').addEventListener('click', async () => {
    await logoutService();
    resetState();
    mostrarLogin();
  });

  inicializarSidebarToggle();
}

function cambiarPagina(pagina, btnEl) {
  document.querySelectorAll('.nav-item[data-page]').forEach((b) => b.classList.remove('active'));
  btnEl.classList.add('active');

  document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
  document.getElementById(`page-${pagina}`).classList.add('active');

  setState({ currentPage: pagina });

  const loader = LOADERS_POR_PAGINA[pagina];
  if (loader) loader();
}

/**
 * Un solo botón en el header del sidebar (#btn-sidebar-toggle) sirve
 * para dos cosas distintas según el dispositivo — la iconografía
 * correcta para cada caso ya la resuelve el CSS (ver index.html:
 * .icon-chevrons-left/right/x):
 *   - Desktop/Tablet: colapsa/expande a una barra de solo íconos
 *     (persistido en localStorage para que sobreviva un refresh).
 *   - Mobile: el sidebar es un drawer fuera de pantalla; este mismo
 *     botón (ahora con ícono X) lo cierra, igual que el overlay.
 */
function inicializarSidebarToggle() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebar-overlay');
  const btnAbrir = document.getElementById('btn-abrir-sidebar');
  const btnToggle = document.getElementById('btn-sidebar-toggle');

  if (localStorage.getItem(SIDEBAR_COLLAPSED_KEY) === '1') {
    sidebar.classList.add('collapsed');
  }

  btnAbrir?.addEventListener('click', () => {
    sidebar.classList.add('mobile-open');
    overlay.classList.add('visible');
  });

  overlay?.addEventListener('click', cerrarSidebarMobile);

  btnToggle?.addEventListener('click', () => {
    if (window.innerWidth <= MOBILE_BREAKPOINT) {
      cerrarSidebarMobile();
      return;
    }

    const colapsado = sidebar.classList.toggle('collapsed');
    localStorage.setItem(SIDEBAR_COLLAPSED_KEY, colapsado ? '1' : '0');
  });
}

function cerrarSidebarMobile() {
  document.getElementById('sidebar')?.classList.remove('mobile-open');
  document.getElementById('sidebar-overlay')?.classList.remove('visible');
}
