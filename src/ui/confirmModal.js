/**
 * Ventana de confirmación DENTRO del programa (mismo aspecto que la de "Guardar
 * Procesamiento": .modal / .modal-content, título, nota y botones), en vez del
 * cuadro del navegador ("localhost dice…").
 *
 * Se crea al pedirla y se quita al cerrarse. Devuelve una promesa: true si el
 * usuario confirma; false si cancela, pulsa la X, la tecla Esc o hace clic fuera.
 */

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

/**
 * @param {{
 *   titulo: string,                 // HTML ya escapado por quien llama (puede llevar <span> de color)
 *   detalle?: string,               // texto gris bajo el título
 *   infoEtiqueta?: string,          // caja azul: "Se enviará a:"
 *   infoValor?: string,             //   y su valor resaltado, p. ej. "Empaque 📦"
 *   nota?: string,                  // nota roja pequeña
 *   textoConfirmar?: string,
 *   estiloConfirmar?: 'primary'|'purple'|'danger',
 *   textoCancelar?: string
 * }} opciones
 * @returns {Promise<boolean>}
 */
export function confirmarEnApp({
  titulo,
  detalle = '',
  infoEtiqueta = '',
  infoValor = '',
  nota = '',
  textoConfirmar = 'Confirmar',
  estiloConfirmar = 'primary',
  textoCancelar = 'Cancelar'
}) {
  return new Promise((resolve) => {
    const estilos = {
      primary: { clase: 'btn btn-primary', style: '' },
      purple: { clase: 'btn', style: 'background:var(--purple); color:#fff; border:none;' },
      danger: { clase: 'btn btn-danger', style: '' }
    };
    const est = estilos[estiloConfirmar] || estilos.primary;

    const modal = document.createElement('div');
    modal.className = 'modal open';
    modal.style.zIndex = '1100'; // por encima del detalle del pedido
    modal.innerHTML = `
      <div class="modal-content" role="dialog" aria-modal="true" style="max-width:520px;">
        <div class="modal-header">
          <div class="modal-title">${titulo}</div>
          <button class="modal-close" type="button" data-accion="cancelar" aria-label="Cerrar">×</button>
        </div>
        ${detalle ? `<div style="font-size:13px; color:var(--text2); margin-bottom:1rem;">${escapeHtml(detalle)}</div>` : ''}
        ${infoValor ? `
        <div style="font-size:13px; color:var(--text2); background:var(--blue-bg); padding:10px 12px; border-radius:var(--r); margin-bottom:1rem;">
          ${escapeHtml(infoEtiqueta)} <strong style="color:var(--blue);">${escapeHtml(infoValor)}</strong>
        </div>` : ''}
        ${nota ? `<div style="font-size:12px; color:var(--red-text); margin-bottom:1rem;">${escapeHtml(nota)}</div>` : ''}
        <div style="margin-top:1.5rem; display:flex; gap:0.75rem;">
          <button class="btn btn-secondary" type="button" data-accion="cancelar">${escapeHtml(textoCancelar)}</button>
          <button class="${est.clase}" type="button" data-accion="confirmar" style="${est.style}">${escapeHtml(textoConfirmar)}</button>
        </div>
      </div>`;

    const cerrar = (resultado) => {
      document.removeEventListener('keydown', alTeclear, true);
      modal.remove();
      resolve(resultado);
    };
    const alTeclear = (e) => {
      if (e.key === 'Escape') {
        e.stopPropagation();
        cerrar(false);
      }
    };

    modal.addEventListener('click', (e) => {
      if (e.target === modal) return cerrar(false); // clic en el fondo oscuro
      const accion = e.target.closest?.('[data-accion]')?.dataset.accion;
      if (accion === 'confirmar') cerrar(true);
      else if (accion === 'cancelar') cerrar(false);
    });
    document.addEventListener('keydown', alTeclear, true);

    document.body.appendChild(modal);
    modal.querySelector('[data-accion="confirmar"]').focus();
  });
}
