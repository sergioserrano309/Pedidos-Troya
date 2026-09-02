import { getState, setState } from '../state/appState.js';
import { fetchPreciosSuelas } from '../services/preciosSuelasService.js';
import { calcularCotizacion, itemsCanastoParaFila, calcularTablaDescuentos } from '../lib/cotizacionCalculos.js';
import { formatearCOP } from '../lib/money.js';
import { mostrarToast } from './toast.js';

/**
 * Página "Cotizador" (módulo Propuesta) — exclusiva del rol 'propuesta'.
 * Independiente de la arquitectura de producción: no importa ni es
 * importada por dashboard.js, orderDetail.js, historyPage.js, etc.
 *
 * Con solo 438 filas, se cargan todas una vez (fetchPreciosSuelas) y el
 * filtrado se hace 100% en memoria. Las OPCIONES de cada filtro se
 * recalculan en vivo en cascada (filasCoincidenExcepto/opcionesDisponibles)
 * conforme se van llenando los demás filtros, pero los RESULTADOS solo se
 * recalculan al hacer clic en "Buscar" (ver resultadosBuscados).
 */

const FILTROS_SELECT = [
  { key: 'referencia', label: 'Referencia', campo: 'referencia' },
  { key: 'material', label: 'Material', campo: 'material' },
  { key: 'cliente', label: 'Cliente', campo: 'cliente' },
  { key: 'colorCategoria', label: 'Color', campo: 'colorCategoria' },
  { key: 'tallaRango', label: 'Talla', campo: 'tallaRango' }
];

const FILTROS_SELECT_DROPDOWN = FILTROS_SELECT.filter((f) => f.key !== 'referencia');

const FILTROS_OBLIGATORIOS = ['referencia', 'cliente'];

const FILTROS_BOOLEANOS = [
  { key: 'bicolor', label: 'Bicolor' },
  { key: 'vira', label: 'Vira' },
  { key: 'esterilla', label: 'Esterilla' },
  { key: 'acabado', label: 'Acabado' },
  { key: 'aplique', label: 'Aplique' }
];

let filas = [];
let filtros = {};
let filaSeleccionadaId = null;
let itemsSeleccionados = new Set();
let cargando = false;
let resultadosBuscados = false;

function filtrosVacios() {
  const base = {};
  FILTROS_SELECT.forEach((f) => { base[f.key] = ''; });
  FILTROS_BOOLEANOS.forEach((f) => { base[f.key] = ''; });
  return base;
}

filtros = filtrosVacios();

export function inicializarPaginaPropuesta() {
  document.getElementById('propuesta-tipo-distribuidor')?.addEventListener('change', onCambioTipoPrecio);
  document.getElementById('propuesta-tipo-fabricante')?.addEventListener('change', onCambioTipoPrecio);
  document.getElementById('propuesta-ubicacion-bogota')?.addEventListener('change', renderizarTodo);
  document.getElementById('propuesta-ubicacion-fuera')?.addEventListener('change', renderizarTodo);

  document.getElementById('propuesta-btn-limpiar-filtros')?.addEventListener('click', () => {
    filtros = filtrosVacios();
    renderizarFiltros();
    onFiltroCambiado();
  });

  document.getElementById('propuesta-btn-toggle-filtros')?.addEventListener('click', () => {
    const grid = document.getElementById('propuesta-filtros-grid');
    const btn = document.getElementById('propuesta-btn-toggle-filtros');
    const abierto = grid?.classList.toggle('abierto');
    btn?.classList.toggle('activo', !!abierto);
  });

  document.getElementById('propuesta-btn-toggle-resultados')?.addEventListener('click', () => {
    const lista = document.getElementById('propuesta-resultados-lista');
    const chevron = document.querySelector('#propuesta-btn-toggle-resultados .propuesta-chevron');
    const colapsado = lista?.classList.toggle('colapsado');
    chevron?.classList.toggle('abierto', !colapsado);
  });

  document.getElementById('propuesta-btn-buscar')?.addEventListener('click', () => {
    if (!todosObligatoriosLlenos()) {
      mostrarToast('Completa Referencia y Cliente antes de buscar.', 'error');
      return;
    }
    resultadosBuscados = true;
    renderizarResultados();
  });

  // Todo lo del filtro de Referencia (autocompletar) se delega sobre el
  // contenedor #propuesta-filtros-grid, que nunca se destruye (solo su
  // innerHTML se reconstruye en cada renderizarFiltros) — así los
  // listeners siguen funcionando sin tener que re-engancharlos.
  const grid = document.getElementById('propuesta-filtros-grid');

  grid?.addEventListener('input', (e) => {
    if (e.target.id === 'propuesta-filtro-referencia-input') renderizarSugerenciasReferencia();
  });

  grid?.addEventListener('focusin', (e) => {
    if (e.target.id === 'propuesta-filtro-referencia-input') renderizarSugerenciasReferencia();
  });

  grid?.addEventListener('focusout', (e) => {
    if (e.target.id !== 'propuesta-filtro-referencia-input') return;
    // Pequeño delay para que un clic sobre una sugerencia alcance a
    // registrarse antes de cerrar la lista y revertir el texto escrito.
    setTimeout(() => {
      cerrarSugerenciasReferencia();
      const input = document.getElementById('propuesta-filtro-referencia-input');
      if (input) input.value = filtros.referencia;
    }, 150);
  });

  grid?.addEventListener('click', (e) => {
    const item = e.target.closest('.propuesta-autocomplete-item');
    if (!item) return;
    filtros.referencia = item.dataset.valor;
    renderizarFiltros();
    onFiltroCambiado();
  });

  grid?.addEventListener('change', (e) => {
    const el = e.target.closest('[data-filtro]');
    if (!el) return;
    filtros[el.dataset.filtro] = el.value;
    renderizarFiltros();
    onFiltroCambiado();
  });

  document.getElementById('propuesta-resultados-lista')?.addEventListener('click', (e) => {
    const el = e.target.closest('[data-fila-id]');
    if (!el) return;
    seleccionarFila(el.dataset.filaId);
  });

  document.getElementById('propuesta-canasto')?.addEventListener('change', (e) => {
    const chk = e.target.closest('input[type="checkbox"][data-item]');
    if (!chk || chk.disabled) return;
    if (chk.checked) itemsSeleccionados.add(chk.dataset.item);
    else itemsSeleccionados.delete(chk.dataset.item);
    renderizarDesglose();
  });

  document.getElementById('propuesta-toggle-volumen')?.addEventListener('change', renderizarDesglose);

  document.getElementById('propuesta-btn-descargar-pdf')?.addEventListener('click', abrirModalPdf);
  document.getElementById('btn-cerrar-propuesta-pdf')?.addEventListener('click', cerrarModalPdf);
  document.getElementById('btn-cancelar-propuesta-pdf')?.addEventListener('click', cerrarModalPdf);
  document.getElementById('btn-confirmar-propuesta-pdf')?.addEventListener('click', confirmarDescargaPDF);
}

function actualizarContadorFiltros() {
  const activos = Object.values(filtros).filter((v) => v && v.trim() !== '').length;
  const contador = document.getElementById('propuesta-filtros-contador');
  if (contador) contador.textContent = `(${activos})`;

  const btnLimpiar = document.getElementById('propuesta-btn-limpiar-filtros');
  btnLimpiar?.classList.toggle('activo', activos > 0);
}

function todosObligatoriosLlenos() {
  return FILTROS_OBLIGATORIOS.every((key) => !!filtros[key]);
}

function actualizarEstadoBotonBuscar() {
  const btn = document.getElementById('propuesta-btn-buscar');
  const ayuda = document.getElementById('propuesta-filtros-ayuda');
  const listo = todosObligatoriosLlenos();
  if (btn) btn.disabled = !listo;
  if (ayuda) ayuda.style.display = listo ? 'none' : 'inline';
}

/** Cualquier cambio de filtro invalida los resultados ya buscados — hay
 * que volver a darle a "Buscar" para verlos (ver renderizarResultados). */
function onFiltroCambiado() {
  resultadosBuscados = false;
  renderizarResultados();
}

/**
 * Antes de imprimir, pide el nombre del lead/cliente y un comentario
 * opcional — se muestran en el PDF (ver confirmarDescargaPDF) para que
 * quede claro para quién es la cotización.
 */
function abrirModalPdf() {
  if (!filaSeleccionada()) return;
  const leadInput = document.getElementById('propuesta-pdf-lead');
  const comentariosInput = document.getElementById('propuesta-pdf-comentarios');
  if (leadInput) leadInput.value = '';
  if (comentariosInput) comentariosInput.value = '';
  document.getElementById('modal-propuesta-pdf')?.classList.add('open');
  leadInput?.focus();
}

function cerrarModalPdf() {
  document.getElementById('modal-propuesta-pdf')?.classList.remove('open');
}

/**
 * "Descarga" la tarjeta de cotización como PDF usando la impresión del
 * navegador (Ctrl+P → Guardar como PDF): sin librerías nuevas, la
 * hoja de estilos @media print (index.html) deja visible solo la
 * tarjeta, igual a como se ve en pantalla. document.title se usa como
 * sugerencia de nombre de archivo en la mayoría de navegadores.
 */
function confirmarDescargaPDF() {
  const fila = filaSeleccionada();
  if (!fila) return;

  const lead = document.getElementById('propuesta-pdf-lead')?.value.trim() || '';
  const comentarios = document.getElementById('propuesta-pdf-comentarios')?.value.trim() || '';

  if (!lead) {
    mostrarToast('Ingresa el nombre del lead/cliente antes de descargar.', 'error');
    return;
  }

  const fechaEl = document.getElementById('propuesta-print-fecha');
  if (fechaEl) {
    fechaEl.textContent = new Date().toLocaleDateString('es-CO', { day: '2-digit', month: 'long', year: 'numeric' });
  }

  const leadEl = document.getElementById('propuesta-print-lead');
  if (leadEl) {
    leadEl.innerHTML = `<strong>Cliente:</strong> ${escapeHtml(lead)}`;
    leadEl.classList.add('con-contenido');
  }

  const comentariosEl = document.getElementById('propuesta-print-comentarios');
  if (comentariosEl) {
    if (comentarios) {
      comentariosEl.innerHTML = `<strong>Comentarios:</strong> ${escapeHtml(comentarios)}`;
      comentariosEl.classList.add('con-contenido');
    } else {
      comentariosEl.classList.remove('con-contenido');
    }
  }

  cerrarModalPdf();

  const tituloOriginal = document.title;
  document.title = `Cotizacion ${fila.referencia} ${fila.cliente} ${fila.tallaRango}`.replace(/\s+/g, ' ').trim();

  const restaurarTitulo = () => {
    document.title = tituloOriginal;
    window.removeEventListener('afterprint', restaurarTitulo);
  };
  window.addEventListener('afterprint', restaurarTitulo);

  window.print();
}

/** Se llama una vez por login (igual que configurarUIDespachos/Compensacion). */
export function configurarUIPropuesta() {
  const { user } = getState();
  const esPropuesta = user?.role === 'propuesta';

  const navPropuesta = document.getElementById('nav-item-propuesta');
  if (navPropuesta) navPropuesta.style.display = esPropuesta ? 'flex' : 'none';

  if (!esPropuesta) return;

  // El rol 'propuesta' no tiene nada que hacer en Órdenes/Compensación:
  // se ocultan y "Cotizador" queda como única página activa.
  document.getElementById('nav-item-compensacion')?.style.setProperty('display', 'none');
  const navOrdenes = document.querySelector('.nav-item[data-page="ordenes"]');
  navOrdenes?.style.setProperty('display', 'none');

  document.querySelectorAll('.nav-item[data-page]').forEach((b) => b.classList.remove('active'));
  navPropuesta.classList.add('active');
  document.querySelectorAll('.page').forEach((p) => p.classList.remove('active'));
  document.getElementById('page-propuesta')?.classList.add('active');
  setState({ currentPage: 'propuesta' });
}

/** Loader de la página (LOADERS_POR_PAGINA.propuesta en navigation.js). */
export async function cargarPropuesta() {
  if (cargando) return;
  cargando = true;

  try {
    filas = await fetchPreciosSuelas();
    renderizarFiltros();
    renderizarResultados();
  } catch (err) {
    console.error('[propuestaPage] Error cargando precios:', err);
    const lista = document.getElementById('propuesta-resultados-lista');
    if (lista) lista.innerHTML = `<div class="propuesta-vacio">${escapeHtml(err.message)}</div>`;
  } finally {
    cargando = false;
  }
}

function onCambioTipoPrecio() {
  const esFabricante = document.getElementById('propuesta-tipo-fabricante')?.checked;
  // "Ubicación de despacho" siempre se pide (Distribuidor y Fabricante) —
  // solo determina la política de descuento en el caso Distribuidor. El
  // recargo de +$400 solo aplica a Fabricante, así que el texto de la
  // opción únicamente lo menciona en ese caso.
  const labelFuera = document.getElementById('propuesta-label-fuera-bogota');
  if (labelFuera) labelFuera.textContent = esFabricante ? 'Fuera de Bogotá (+$400)' : 'Fuera de Bogotá';
  renderizarTodo();
}

function esTipoFabricante() {
  return !!document.getElementById('propuesta-tipo-fabricante')?.checked;
}

function esFueraDeBogota() {
  return !!document.getElementById('propuesta-ubicacion-fuera')?.checked;
}

function precioConIvaDeFila(fila) {
  return esTipoFabricante() ? fila.precioFabricanteConIva : fila.precioDistribuidorConIva;
}

function renderizarTodo() {
  renderizarResultados();
  renderizarCotizacionSeleccionada();
}

/** Filas que cumplen todos los filtros activos EXCEPTO el indicado por
 * claveExcluida — es la base para calcular qué opciones sigue teniendo
 * sentido ofrecer en cada filtro dado lo que ya se llenó en los demás
 * (filtrado en cascada, bidireccional: no importa por cuál se empiece). */
function filasCoincidenExcepto(claveExcluida) {
  return filas.filter((fila) => {
    for (const f of FILTROS_SELECT) {
      if (f.key === claveExcluida) continue;
      if (filtros[f.key] && fila[f.campo] !== filtros[f.key]) return false;
    }
    for (const f of FILTROS_BOOLEANOS) {
      if (filtros[f.key] === 'si' && !fila[f.key]) return false;
      if (filtros[f.key] === 'no' && fila[f.key]) return false;
    }
    return true;
  });
}

function opcionesDisponibles(campo, claveExcluida) {
  return [...new Set(filasCoincidenExcepto(claveExcluida).map((f) => f[campo]).filter(Boolean))]
    .sort((a, b) => a.localeCompare(b));
}

function renderizarFiltros() {
  const cont = document.getElementById('propuesta-filtros-grid');
  if (!cont) return;

  const referenciasDisponibles = opcionesDisponibles('referencia', 'referencia');
  if (filtros.referencia && !referenciasDisponibles.includes(filtros.referencia)) {
    filtros.referencia = '';
  }

  const refHtml = `
    <div class="form-group">
      <label>Referencia <span class="propuesta-req">*</span></label>
      <div class="propuesta-autocomplete">
        <input type="text" id="propuesta-filtro-referencia-input" class="propuesta-filtro-principal"
          placeholder="Escribe para buscar..." autocomplete="off" value="${escapeHtml(filtros.referencia)}">
        <div class="propuesta-autocomplete-lista" id="propuesta-autocomplete-referencia"></div>
      </div>
    </div>`;

  const otrosSelects = FILTROS_SELECT_DROPDOWN.map((f) => {
    const disponibles = opcionesDisponibles(f.campo, f.key);
    if (filtros[f.key] && !disponibles.includes(filtros[f.key])) {
      filtros[f.key] = '';
    }
    const obligatorio = FILTROS_OBLIGATORIOS.includes(f.key) ? ' <span class="propuesta-req">*</span>' : '';
    const opciones = disponibles
      .map((v) => `<option value="${escapeHtml(v)}" ${filtros[f.key] === v ? 'selected' : ''}>${escapeHtml(v)}</option>`)
      .join('');
    return `
      <div class="form-group">
        <label>${escapeHtml(f.label)}${obligatorio}</label>
        <select class="propuesta-filtro-principal" data-filtro="${f.key}">
          <option value="">Todos</option>
          ${opciones}
        </select>
      </div>`;
  }).join('');

  const booleanos = FILTROS_BOOLEANOS.map((f) => `
      <div class="form-group">
        <label>${escapeHtml(f.label)}</label>
        <select data-filtro="${f.key}">
          <option value="" ${filtros[f.key] === '' ? 'selected' : ''}>Cualquiera</option>
          <option value="si" ${filtros[f.key] === 'si' ? 'selected' : ''}>Sí</option>
          <option value="no" ${filtros[f.key] === 'no' ? 'selected' : ''}>No</option>
        </select>
      </div>`).join('');

  cont.innerHTML = refHtml + otrosSelects + booleanos;
  actualizarContadorFiltros();
  actualizarEstadoBotonBuscar();
}

function renderizarSugerenciasReferencia() {
  const input = document.getElementById('propuesta-filtro-referencia-input');
  const lista = document.getElementById('propuesta-autocomplete-referencia');
  if (!input || !lista) return;

  const texto = input.value.trim().toLowerCase();
  const disponibles = opcionesDisponibles('referencia', 'referencia');
  const filtradas = texto ? disponibles.filter((v) => v.toLowerCase().includes(texto)) : disponibles;

  lista.innerHTML = filtradas.length
    ? filtradas.map((v) => `<div class="propuesta-autocomplete-item" data-valor="${escapeHtml(v)}">${escapeHtml(v)}</div>`).join('')
    : '<div class="propuesta-autocomplete-vacio">Sin coincidencias</div>';
  lista.classList.add('abierta');
}

function cerrarSugerenciasReferencia() {
  document.getElementById('propuesta-autocomplete-referencia')?.classList.remove('abierta');
}

function filaCumpleFiltros(fila) {
  for (const f of FILTROS_SELECT) {
    if (filtros[f.key] && fila[f.campo] !== filtros[f.key]) return false;
  }
  for (const f of FILTROS_BOOLEANOS) {
    if (filtros[f.key] === 'si' && !fila[f.key]) return false;
    if (filtros[f.key] === 'no' && fila[f.key]) return false;
  }
  return true;
}

function renderizarResultados() {
  const lista = document.getElementById('propuesta-resultados-lista');
  const contador = document.getElementById('propuesta-resultados-count');
  if (!lista) return;

  if (!resultadosBuscados) {
    if (contador) contador.textContent = '';
    lista.innerHTML = '<div class="propuesta-vacio">Completa Referencia y Cliente, luego haz clic en Buscar.</div>';
    return;
  }

  const resultado = filas.filter(filaCumpleFiltros);
  if (contador) contador.textContent = `- ${resultado.length}`;

  if (resultado.length === 0) {
    lista.innerHTML = '<div class="propuesta-vacio">Ninguna suela coincide con estos filtros.</div>';
    return;
  }

  lista.innerHTML = resultado.map((fila) => {
    const extras = [];
    if (fila.bicolor) extras.push('Bicolor');
    if (fila.vira) extras.push('Vira');
    if (fila.esterilla) extras.push('Esterilla');
    if (fila.acabado) extras.push('Acabado');
    if (fila.aplique) extras.push('Aplique');

    const sub = [fila.material, fila.cliente, fila.colorNombre, fila.tallaRango, ...extras]
      .filter(Boolean).join(' · ');

    return `
      <div class="propuesta-resultado-item ${fila.id === filaSeleccionadaId ? 'seleccionado' : ''}" data-fila-id="${fila.id}">
        <div>
          <div class="propuesta-resultado-titulo">${escapeHtml(fila.referencia)}</div>
          <div class="propuesta-resultado-sub">${escapeHtml(sub)}</div>
        </div>
        <div class="propuesta-resultado-precio">${formatearCOP(precioConIvaDeFila(fila))}</div>
      </div>`;
  }).join('');
}

function seleccionarFila(id) {
  filaSeleccionadaId = String(id);
  itemsSeleccionados = new Set();
  renderizarResultados();
  renderizarCotizacionSeleccionada();
}

function filaSeleccionada() {
  return filas.find((f) => String(f.id) === filaSeleccionadaId) || null;
}

function renderizarCotizacionSeleccionada() {
  const card = document.getElementById('propuesta-cotizacion-card');
  const fila = filaSeleccionada();
  if (!card) return;

  if (!fila) {
    card.style.display = 'none';
    return;
  }
  card.style.display = 'block';

  const info = document.getElementById('propuesta-sel-info');
  if (info) {
    // Cliente no se muestra: podría generar confusión en la cotización
    // que ve el cliente final (el precio ya es el que le corresponde).
    const campos = [
      ['Referencia', fila.referencia],
      ['Material', fila.material],
      ['Talla', fila.tallaRango],
      ['Color detallado', fila.colorNombre || '—'],
      ['Detalle', fila.comentario || '—']
    ];
    info.innerHTML = campos.map(([label, valor]) => `
      <div class="propuesta-sel-campo">
        <label>${escapeHtml(label)}</label>
        <span>${escapeHtml(valor)}</span>
      </div>`).join('');
  }

  renderizarCanasto(fila);
  renderizarDesglose();
}

function renderizarCanasto(fila) {
  const cont = document.getElementById('propuesta-canasto');
  if (!cont) return;

  cont.innerHTML = itemsCanastoParaFila(fila).map((item) => `
    <div class="propuesta-canasto-item ${item.incluido ? 'incluido' : ''}">
      <label class="propuesta-canasto-item-label">
        <input type="checkbox" data-item="${item.key}"
          ${item.incluido || itemsSeleccionados.has(item.key) ? 'checked' : ''}
          ${item.incluido ? 'disabled' : ''}>
        ${escapeHtml(item.label)}
        ${item.incluido ? '<span class="propuesta-badge-incluido">Ya incluido</span>' : ''}
      </label>
      <span class="propuesta-canasto-item-precio">${item.incluido ? 'Incluido' : `+ ${formatearCOP(item.precio)}`}</span>
    </div>`).join('');
}

function renderizarDesglose() {
  const cont = document.getElementById('propuesta-desglose');
  const fila = filaSeleccionada();
  if (!cont || !fila) return;

  const { precioBase, recargoUbicacion, lineas, total } = calcularCotizacion({
    precioBase: precioConIvaDeFila(fila),
    esFabricante: esTipoFabricante(),
    fueraDeBogota: esFueraDeBogota(),
    itemsSeleccionados,
    fila
  });

  const lineasHtml = lineas.map((l) => `
    <div class="propuesta-desglose-linea">
      <span>${escapeHtml(l.label)}${l.incluido ? ' (ya incluido en el precio)' : ''}</span>
      <span>${l.incluido ? formatearCOP(0) : `+ ${formatearCOP(l.precio)}`}</span>
    </div>`).join('');

  cont.innerHTML = `
    <div class="propuesta-desglose-linea">
      <span>Precio ${escapeHtml(capitalizar(fila.referencia))}, ${esTipoFabricante() ? 'Fabricante' : 'Distribuidor'}</span>
      <span>${formatearCOP(precioBase)}</span>
    </div>
    ${recargoUbicacion > 0 ? `
    <div class="propuesta-desglose-linea">
      <span>Recargo fuera de Bogotá</span>
      <span>+ ${formatearCOP(recargoUbicacion)}</span>
    </div>` : ''}
    ${lineasHtml}
    <div class="propuesta-desglose-linea propuesta-desglose-total">
      <span>Total</span>
      <span>${formatearCOP(total)}</span>
    </div>`;

  renderizarDescuentos(total);
}

function renderizarDescuentos(total) {
  const tabla = document.getElementById('propuesta-descuentos-tabla');
  if (!tabla) return;

  const fueraDeBogota = esFueraDeBogota();
  const volumenWrap = document.getElementById('propuesta-descuentos-volumen');
  const toggleVolumen = document.getElementById('propuesta-toggle-volumen');

  if (volumenWrap) volumenWrap.style.display = fueraDeBogota ? 'flex' : 'none';
  if (!fueraDeBogota && toggleVolumen) toggleVolumen.checked = false;

  const descuentoVolumenActivo = fueraDeBogota && !!toggleVolumen?.checked;
  const bandas = calcularTablaDescuentos(total, fueraDeBogota, descuentoVolumenActivo);

  const encabezado = bandas.map((b) => `<th>${escapeHtml(b.rango)}</th>`).join('');
  const filaDescuento = bandas.map((b) => `<td>${Math.round(b.pct * 100)}%</td>`).join('');
  const filaTotal = bandas.map((b) => `<td>${formatearCOP(b.totalConDescuento)}</td>`).join('');

  tabla.innerHTML = `
    <thead>
      <tr><th></th>${encabezado}</tr>
    </thead>
    <tbody>
      <tr><td class="propuesta-descuentos-label">Descuento</td>${filaDescuento}</tr>
      <tr class="propuesta-descuentos-fila-total"><td class="propuesta-descuentos-label">Total</td>${filaTotal}</tr>
    </tbody>`;

  const nota = document.getElementById('propuesta-descuentos-nota');
  if (nota) {
    nota.textContent = fueraDeBogota
      ? 'Para que aplique el descuento por volumen se debe solicitar un volumen mínimo de 300 pares.'
      : 'Para que aplique el descuento se debe pedir 240 pares o más.';
  }
}

function capitalizar(value) {
  const texto = String(value ?? '');
  return texto.charAt(0).toUpperCase() + texto.slice(1).toLowerCase();
}

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;'
  }[c]));
}
