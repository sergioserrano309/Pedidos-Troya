import { logout as logoutService } from '../services/authService.js';
import { resetState, setState } from '../state/appState.js';
import { mostrarLogin } from './login.js';
import { cargarOrdenes } from './dashboard.js';

export function inicializarNavegacion() {
  document.querySelectorAll('.nav-item[data-page]').forEach((btn) => {
    btn.addEventListener('click', () => cambiarPagina(btn.dataset.page, btn));
  });

  document.getElementById('btn-logout').addEventListener('click', async () => {
    await logoutService();
    resetState();
    mostrarLogin();
  });
}

function cambiarPagina(pagina, btnEl) {
  document.querySelectorAll('.nav-item[data-page]').forEach((b) => b.classList.remove('active'));
  btnEl.classList.add('active');

  document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
  document.getElementById(`page-${pagina}`).classList.add('active');

  setState({ currentPage: pagina });

  cargarOrdenes();
}
