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
 *
 * Con data-buscable="1" el botón se reemplaza por un campo de texto:
 * lo que se escribe acorta la lista, y el filtro se aplica solo al
 * elegir una opción (el <select> sigue siendo la única fuente de verdad).
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

/** Minúsculas y sin tildes, para que "maria" encuentre "MARÍA". */
function normalizar(texto) {
  return String(texto ?? '')
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase();
}

/**
 * Refleja en el botón (o campo) custom de un select el texto de la
 * opción actualmente seleccionada (o el placeholder si no hay ninguna).
 * Se llama después de elegir una opción y tras cualquier código que toque
 * select.value directamente (ej. "Limpiar" filtros, o el login que fija
 * el Rol Activo guardado).
 */
export function sincronizarEtiquetaFiltro(selectId) {
  const wrapper = document.querySelector(`.filtro-custom-select[data-filtro-select="${selectId}"]`);
  const select = document.getElementById(selectId);
  if (!wrapper || !select) return;

  const placeholder = select.options[0]?.textContent || '';
  const opcionActiva = [...select.options].find((o) => o.value === select.value);

  const input = wrapper.querySelector('.filtro-custom-input');
  if (input) {
    input.placeholder = placeholder;
    input.value = opcionActiva && opcionActiva.value !== '' ? opcionActiva.textContent : '';
    return;
  }

  const label = wrapper.querySelector('.filtro-custom-label');
  label.textContent = opcionActiva ? opcionActiva.textContent : placeholder;
}

function posicionarDropdown(ancla, dropdown) {
  // Mismo tratamiento que .comp-periodo-dropdown en mobile: position:
  // fixed calculado a mano para escapar del overflow-x:auto de .card
  // (ver index.html), que si no recortaría el panel desplegado.
  if (window.innerWidth <= 767) {
    const rect = ancla.getBoundingClientRect();
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
}

function elegir(selectId, valor, dropdown) {
  const select = document.getElementById(selectId);
  if (!select) return;
  select.value = valor;
  select.dispatchEvent(new Event('change', { bubbles: true }));
  sincronizarEtiquetaFiltro(selectId);
  dropdown.classList.remove('open');
}

/** Variante de botón (comportamiento original, sin cambios). */
function inicializarConBoton(wrapper, selectId, btn, dropdown) {
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
      opt.addEventListener('click', () => elegir(selectId, opt.dataset.value, dropdown));
    });

    dropdown.classList.add('open');
    posicionarDropdown(btn, dropdown);
  });
}

/** Variante con texto (data-buscable="1"). */
function inicializarConTexto(wrapper, selectId, btn, dropdown) {
  const chevron = btn.querySelector('svg');
  const input = document.createElement('input');
  input.type = 'text';
  input.className = 'filtro-custom-input';
  input.autocomplete = 'off';
  input.spellcheck = false;
  btn.replaceWith(input);

  if (chevron) {
    chevron.classList.add('filtro-custom-input-chevron');
    wrapper.insertBefore(chevron, dropdown);
  }

  const pintar = () => {
    const select = document.getElementById(selectId);
    if (!select) return;

    // Mientras el texto es el de la opción ya elegida, se muestra la
    // lista completa; en cuanto el usuario escribe algo distinto, se
    // filtra por lo escrito.
    const elegida = [...select.options].find((o) => o.value === select.value && o.value !== '');
    const termino = elegida && input.value === elegida.textContent ? '' : normalizar(input.value.trim());

    const opciones = [...select.options].filter((o) => o.value === '' || !termino || normalizar(o.textContent).includes(termino));
    const reales = opciones.filter((o) => o.value !== '');

    dropdown.innerHTML = reales.length || !termino
      ? opciones
        .map((o) => `<div class="filtro-custom-option ${o.value === select.value ? 'active' : ''}" data-value="${escapeHtml(o.value)}">${escapeHtml(o.value === '' ? 'Todos' : o.textContent)}</div>`)
        .join('')
      : '<div class="filtro-custom-vacio">Sin coincidencias</div>';

    dropdown.querySelectorAll('.filtro-custom-option').forEach((opt) => {
      // mousedown sin acción por defecto: en PC evita que el campo pierda
      // el foco antes del click. En táctil el blur puede llegar igual
      // primero; por eso el cierre en blur espera un momento (ver abajo).
      opt.addEventListener('mousedown', (e) => e.preventDefault());
      opt.addEventListener('click', (e) => {
        e.stopPropagation();
        elegir(selectId, opt.dataset.value, dropdown);
        input.blur();
      });
    });
  };

  const abrir = () => {
    document.querySelectorAll('.filtro-custom-dropdown.open').forEach((d) => {
      if (d !== dropdown) d.classList.remove('open');
    });
    pintar();
    dropdown.classList.add('open');
    posicionarDropdown(input, dropdown);
  };

  input.addEventListener('focus', () => {
    input.select();
    abrir();
  });

  input.addEventListener('click', (e) => {
    e.stopPropagation();
    if (!dropdown.classList.contains('open')) abrir();
  });

  input.addEventListener('input', () => {
    if (!dropdown.classList.contains('open')) abrir();
    else pintar();
  });

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      const primera = dropdown.querySelector('.filtro-custom-option[data-value]:not([data-value=""])');
      if (primera) {
        elegir(selectId, primera.dataset.value, dropdown);
        input.blur();
      }
    } else if (e.key === 'Escape') {
      input.blur();
    }
  });

  // Salir sin elegir deja el campo como estaba: lo escrito solo busca,
  // no filtra.
  input.addEventListener('blur', () => {
    setTimeout(() => {
      dropdown.classList.remove('open');
      sincronizarEtiquetaFiltro(selectId);
    }, 150);
  });
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

    if (wrapper.dataset.buscable === '1') {
      inicializarConTexto(wrapper, selectId, btn, dropdown);
    } else {
      inicializarConBoton(wrapper, selectId, btn, dropdown);
    }

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
