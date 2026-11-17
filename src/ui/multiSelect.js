/**
 * Desplegable de selección MÚLTIPLE con el mismo aspecto que los filtros
 * desplegables de la plataforma (.filtro-custom-*): botón azul y panel
 * blanco, pero cada opción lleva una casilla y el panel NO se cierra al
 * marcar, para poder elegir varias.
 *
 * Reusa las clases de customSelect.js; el cierre al hacer clic afuera lo
 * resuelve el oyente global de inicializarFiltrosCustomSelect (el envoltorio
 * lleva la clase .filtro-custom-select).
 */

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

/**
 * @param {HTMLElement} contenedor Celda donde se dibuja.
 * @param {{ placeholder: string, opciones: Array<{valor: string, etiqueta: string}>, alCambiar: (valores: string[]) => void }} config
 * @returns {{ obtener: () => string[], limpiar: () => void }}
 */
export function montarMultiSelect(contenedor, { placeholder, opciones, alCambiar }) {
  contenedor.innerHTML = `
    <div class="filtro-custom-select filtro-multi">
      <button type="button" class="filtro-custom-btn" aria-haspopup="true" aria-expanded="false">
        <span class="filtro-custom-label">${escapeHtml(placeholder)}</span>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><polyline points="6 9 12 15 18 9"/></svg>
      </button>
      <div class="filtro-custom-dropdown">
        ${opciones.map((o) => `
        <label class="filtro-multi-opcion">
          <input type="checkbox" value="${escapeHtml(o.valor)}">
          <span>${escapeHtml(o.etiqueta)}</span>
        </label>`).join('')}
      </div>
    </div>`;

  const boton = contenedor.querySelector('.filtro-custom-btn');
  const etiqueta = contenedor.querySelector('.filtro-custom-label');
  const panel = contenedor.querySelector('.filtro-custom-dropdown');
  const casillas = [...contenedor.querySelectorAll('input[type="checkbox"]')];

  const obtener = () => casillas.filter((c) => c.checked).map((c) => c.value);

  const pintarEtiqueta = () => {
    const elegidos = casillas.filter((c) => c.checked);
    if (elegidos.length === 0) etiqueta.textContent = placeholder;
    else if (elegidos.length === 1) etiqueta.textContent = opciones.find((o) => o.valor === elegidos[0].value)?.etiqueta ?? placeholder;
    else etiqueta.textContent = `${elegidos.length} estados`;
    boton.classList.toggle('filtro-multi-activo', elegidos.length > 0);
  };

  boton.addEventListener('click', (e) => {
    e.stopPropagation();
    const abriendo = !panel.classList.contains('open');
    document.querySelectorAll('.filtro-custom-dropdown.open').forEach((d) => d.classList.remove('open'));
    panel.classList.toggle('open', abriendo);
    boton.setAttribute('aria-expanded', String(abriendo));
  });

  casillas.forEach((c) => {
    c.addEventListener('change', () => {
      pintarEtiqueta();
      alCambiar(obtener());
    });
  });

  return {
    obtener,
    limpiar() {
      casillas.forEach((c) => { c.checked = false; });
      pintarEtiqueta();
    }
  };
}
