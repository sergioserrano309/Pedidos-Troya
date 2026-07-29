/**
 * Notificaciones tipo "toast" (sección 17 del documento: Toast Notifications).
 */
let ocultarTimeout = null;

export function mostrarToast(mensaje, tipo = 'ok') {
  const toast = document.getElementById('toast');
  if (!toast) return;

  toast.textContent = mensaje;
  toast.className = `toast ${tipo === 'error' ? 'err' : 'ok'}`;
  toast.style.display = 'block';

  clearTimeout(ocultarTimeout);
  ocultarTimeout = setTimeout(() => {
    toast.style.display = 'none';
  }, 3500);
}
