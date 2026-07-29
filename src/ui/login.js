import { login as loginService } from '../services/authService.js';

/**
 * Página de Login (Supabase Auth). El campo "Correo electrónico" se usa
 * directamente como email de Supabase Auth.
 * @param {(user: object) => void} onLoginSuccess
 */
export function initLoginPage(onLoginSuccess) {
  const form = document.getElementById('login-form');
  const errorBox = document.getElementById('login-error');
  const btn = document.getElementById('btn-login');

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    errorBox.style.display = 'none';

    const email = document.getElementById('login-usuario').value.trim();
    const password = document.getElementById('login-password').value;

    if (!email || !password) return;

    btn.disabled = true;
    btn.textContent = 'Ingresando...';

    try {
      const user = await loginService(email, password);
      form.reset();
      onLoginSuccess(user);
    } catch (err) {
      errorBox.textContent = err.message;
      errorBox.style.display = 'block';
    } finally {
      btn.disabled = false;
      btn.textContent = 'Ingresar';
    }
  });
}

export function mostrarLogin() {
  document.getElementById('login-page').style.display = 'flex';
  document.getElementById('app').style.display = 'none';
}

export function ocultarLogin() {
  document.getElementById('login-page').style.display = 'none';
  document.getElementById('app').style.display = 'block';
}
