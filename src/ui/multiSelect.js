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
 * @param {{
 *   placeholder: string,
 *   opciones: Array<{valor: string, etiqueta: string}>,
 *   alCambiar: (valores: string[]) => void,
 *   etiquetaPlural?: string,  // "3 clientes" (por defecto "estados")
 *   buscable?: boolean        // agrega un campo para buscar dentro de la lista
 * }} config
 * @returns {{ obtener: () => string[], limpiar: () => void, actualizarOpciones: (opciones: Array<{valor: string, etiqueta: string}>) => void }}
 */
export function montarMultiSelect(contenedor, { placeholder, opciones, alCambiar, etiquetaPlural = 'estados', buscable = false }) {
  contenedor.innerHTML = `
    <div class="filtro-custom-select filtro-multi">
      <button type="button" class="filtro-custom-btn" aria-haspopup="true" aria-expanded="false">
        <span class="filtro-custom-label">${escapeHtml(placeholder)}</span>
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><polyline points="6 9 12 15 18 9"/></svg>
      </button>
      <div class="filtro-custom-dropdown">
        ${buscable ? '<input type="text" class="filtro-multi-buscar" placeholder="Buscar..." autocomplete="off" style="width:100%;box-sizing:border-box;padding:8px 12px;border:none;border-bottom:1px solid var(--border2);font-size:13px;outline:none;position:sticky;top:0;background:#fff;">' : ''}
        <div class="filtro-multi-lista"></div>
      </div>
    </div>`;

  const boton = contenedor.querySelector('.filtro-custom-btn');
  const etiqueta = contenedor.querySelector('.filtro-custom-label');
  const panel = contenedor.querySelector('.filtro-custom-dropdown');
  const lista = contenedor.querySelector('.filtro-multi-lista');
  const buscador = contenedor.querySelector('.filtro-multi-buscar');

  let opcionesActuales = [];
  // Lo elegido vive aquí (no en las casillas): así sobrevive a que la lista
  // se reconstruya y a que una opción elegida deje de estar en la lista.
  const elegidos = new Set();

  const obtener = () => [...elegidos];

  const pintarEtiqueta = () => {
    if (elegidos.size === 0) etiqueta.textContent = placeholder;
    else if (elegidos.size === 1) {
      const unico = [...elegidos][0];
      etiqueta.textContent = opcionesActuales.find((o) => o.valor === unico)?.etiqueta ?? unico;
    } else etiqueta.textContent = `${elegidos.size} ${etiquetaPlural}`;
    boton.classList.toggle('filtro-multi-activo', elegidos.size > 0);
  };

  const aplicarBusqueda = () => {
    const texto = (buscador?.value || '').trim().toLowerCase();
    lista.querySelectorAll('.filtro-multi-opcion').forEach((el) => {
      el.style.display = !texto || el.textContent.toLowerCase().includes(texto) ? '' : 'none';
    });
  };

  const dibujar = () => {
    // Lo elegido que ya no está en la lista nueva se sigue mostrando (arriba),
    // para que nunca desaparezca sin que el usuario lo haya quitado.
    const enLista = new Set(opcionesActuales.map((o) => o.valor));
    const sobrantes = [...elegidos].filter((v) => !enLista.has(v)).map((v) => ({ valor: v, etiqueta: v }));
    const todas = [...sobrantes, ...opcionesActuales];
    lista.innerHTML = todas.map((o) => `
      <label class="filtro-multi-opcion">
        <input type="checkbox" value="${escapeHtml(o.valor)}"${elegidos.has(o.valor) ? ' checked' : ''}>
        <span>${escapeHtml(o.etiqueta)}</span>
      </label>`).join('');
    aplicarBusqueda();
    pintarEtiqueta();
  };

  boton.addEventListener('click', (e) => {
    e.stopPropagation();
    const abriendo = !panel.classList.contains('open');
    document.querySelectorAll('.filtro-custom-dropdown.open').forEach((d) => d.classList.remove('open'));
    panel.classList.toggle('open', abriendo);
    boton.setAttribute('aria-expanded', String(abriendo));
    if (abriendo && buscador) buscador.focus();
  });

  buscador?.addEventListener('input', aplicarBusqueda);

  // Un solo oyente para toda la lista (las casillas se reconstruyen).
  lista.addEventListener('change', (e) => {
    const casilla = e.target;
    if (!(casilla instanceof HTMLInputElement)) return;
    if (casilla.checked) elegidos.add(casilla.value);
    else elegidos.delete(casilla.value);
    pintarEtiqueta();
    alCambiar(obtener());
  });

  opcionesActuales = opciones;
  dibujar();

  return {
    obtener,
    limpiar() {
      elegidos.clear();
      dibujar();
    },
    /** Cambia las opciones disponibles conservando lo elegido. */
    actualizarOpciones(nuevas) {
      const igual = nuevas.length === opcionesActuales.length
        && nuevas.every((o, i) => o.valor === opcionesActuales[i].valor);
      opcionesActuales = nuevas;
      if (!igual) dibujar();
    }
  };
}
