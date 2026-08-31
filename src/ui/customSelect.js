/**
 * Componente genérico: envuelve un <select> oculto con un botón + panel
 * desplegable visual (mismo lenguaje que .comp-periodo-*, ver
 * index.html), sin tocar la lógica de quien lo use — el <select> sigue
 * siendo la fuente de verdad, el panel solo le asigna .value y dispara
 * 'change' sobre él.
 *
 * Estructura HTML esperada (ver #ordenes-filtros / #comp-rol-selector-
 * container en index.html):
 *   <div class="filtro-custom-select" data-filtro-select="mi-select-id">
 *     <select id="mi-select-id" style="display:none;">...</select>
 *     <button type="button" class="filtro-custom-btn">
 *       <span class="filtro-custom-label"></span>
 *       <svg ...chevron.../>
 *     </button>
 *     <div class="filtro-custom-dropdown"></div>
 *   </div>
 */

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  }[c]));
}

/**
 * Refleja en el botón custom de un select el texto de la opción
 * actualmente seleccionada (o el placeholder si no hay ninguna). Se
 * llama después de elegir una opción y tras cualquier código que toque
 * select.value directamente (ej. "Limpiar" filtros, o el login que fija
 * el Rol Activo guardado).
 */
export function sincronizarEtiquetaFiltro(selectId) {
  const wrapper = document.querySelector(`.filtro-custom-select[data-filtro-select="${selectId}"]`);
  const select = document.getElementById(selectId);
  if (!wrapper || !select) return;

  const label = wrapper.querySelector('.filtro-custom-label');
  const placeholder = select.options[0]?.textContent || '';
  const opcionActiva = [...select.options].find((o) => o.value === select.value);
  label.textContent = opcionActiva ? opcionActiva.textContent : placeholder;
}

/**
 * Envuelve cada `.filtro-custom-select` presente en el documento (puede
 * llamarse desde varias páginas — Órdenes y Compensación comparten este
 * componente) con su interacción de abrir/cerrar/elegir opción. Idempotente:
 * cada wrapper se marca una vez inicializado, así que llamarlo de nuevo
 * (ej. al entrar a otra página) no apila listeners duplicados sobre los
 * que ya existían.
 *
 * El <select> se busca por getElementById DENTRO de cada handler (no se
 * cachea en un closure externo) porque algunos selects (ej.
 * rol-activo-selector) se reemplazan por un clon en cada login para
 * evitar apilar listeners de 'change' — cachearlo dejaría el botón
 * custom apuntando a un nodo ya desconectado del DOM tras el primer
 * cambio de sesión.
 */
export function inicializarFiltrosCustomSelect() {
  document.querySelectorAll('.filtro-custom-select').forEach((wrapper) => {
    if (wrapper.dataset.filtroCustomInit === '1') return;

    const selectId = wrapper.dataset.filtroSelect;
    const btn = wrapper.querySelector('.filtro-custom-btn');
    const dropdown = wrapper.querySelector('.filtro-custom-dropdown');
    if (!document.getElementById(selectId) || !btn || !dropdown) return;

    wrapper.dataset.filtroCustomInit = '1';

    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const select = document.getElementById(selectId);
      if (!select) return;

      const abriendo = !dropdown.classList.contains('open');
      document.querySelectorAll('.filtro-custom-dropdown.open').forEach((d) => d.classList.remove('open'));
      if (!abriendo) return;

      dropdown.innerHTML = [...select.options]
        .map((o) => `<div class="filtro-custom-option ${o.value === select.value ? 'active' : ''}" data-value="${escapeHtml(o.value)}">${escapeHtml(o.textContent)}</div>`)
        .join('');

      dropdown.querySelectorAll('.filtro-custom-option').forEach((opt) => {
        opt.addEventListener('click', () => {
          const selectActual = document.getElementById(selectId);
          if (!selectActual) return;
          selectActual.value = opt.dataset.value;
          selectActual.dispatchEvent(new Event('change', { bubbles: true }));
          sincronizarEtiquetaFiltro(selectId);
          dropdown.classList.remove('open');
        });
      });

      dropdown.classList.add('open');

      // Mismo tratamiento que .comp-periodo-dropdown en mobile: position:
      // fixed calculado a mano para escapar del overflow-x:auto de .card
      // (ver index.html), que si no recortaría el panel desplegado.
      if (window.innerWidth <= 767) {
        const rect = btn.getBoundingClientRect();
        dropdown.style.position = 'fixed';
        dropdown.style.top = `${rect.bottom + 6}px`;
        dropdown.style.left = `${rect.left}px`;
        dropdown.style.width = `${rect.width}px`;
      } else {
        dropdown.style.position = '';
        dropdown.style.top = '';
        dropdown.style.left = '';
        dropdown.style.width = '';
      }
    });

    sincronizarEtiquetaFiltro(selectId);
  });

  if (!window.filtroCustomSelectClickOutsideConfigured) {
    document.addEventListener('click', (e) => {
      if (!e.target.closest('.filtro-custom-select')) {
        document.querySelectorAll('.filtro-custom-dropdown.open').forEach((d) => d.classList.remove('open'));
      }
    });
    window.filtroCustomSelectClickOutsideConfigured = true;
  }
}
