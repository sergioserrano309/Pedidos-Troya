import { validarCodigoAcceso } from '../services/accessCodeService.js';

/**
 * Modal de código de acceso. Se muestra después del login.
 * Diseño coherente con el login existente.
 * @param {object} user - Usuario autenticado
 * @param {(user: object) => void} onAccessGranted - Callback cuando el código es válido
 */
export function initAccessCodeModal(user, onAccessGranted) {
  const modal = document.getElementById('access-code-modal');
  const form = document.getElementById('access-code-form');
  const inputCode = document.getElementById('access-code-input');
  const errorBox = document.getElementById('access-code-error');
  const btn = document.getElementById('btn-access-code');

  form.addEventListener('submit', async (event) => {
    event.preventDefault();
    errorBox.style.display = 'none';

    const code = inputCode.value.trim();
    if (!code) return;

    btn.disabled = true;
    btn.textContent = 'Verificando...';

    try {
      const isValid = await validarCodigoAcceso(user.id, code);

      if (!isValid) {
        errorBox.textContent = 'Código de acceso incorrecto.';
        errorBox.style.display = 'block';
        return;
      }

      // Código válido - cerrar modal y continuar
      form.reset();
      ocultarAccessCodeModal();
      onAccessGranted();
    } catch (err) {
      errorBox.textContent = 'Error al validar código. Intenta nuevamente.';
      errorBox.style.display = 'block';
    } finally {
      btn.disabled = false;
      btn.textContent = 'Verificar Acceso';
    }
  });
}

export function mostrarAccessCodeModal() {
  const modal = document.getElementById('access-code-modal');
  modal.style.display = 'flex';
  document.getElementById('access-code-input').focus();
}

export function ocultarAccessCodeModal() {
  const modal = document.getElementById('access-code-modal');
  modal.style.display = 'none';
}
