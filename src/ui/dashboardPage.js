import { esValidador } from '../services/validatorService.js';
import {
  fetchLineasDashboard, fetchDespachosDashboard, fetchPedidosConCambiosPendientes
} from '../services/dashboardService.js';
import {
  MEDIDAS, LECTURAS, DIMENSIONES, FILTROS_VACIOS, prepararLineas, prepararDespachos,
  agrupar, totalesTarjetas, notasDashboard, fechaDeLectura, formatearPares, diaColombia
} from '../lib/dashboard.js';
import { calcularOpciones } from '../lib/facetas.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { mostrarToast } from './toast.js';

/**
 * Pestaña "Dashboard" (solo Validador): pares (unidades) solicitados,
 * despachados y pendientes por despachar, agrupables por una o dos
 * categorías y filtrables. Solo lectura: no escribe nada ni toca el resto
 * de la plataforma. Las reglas de fechas y de qué cuenta están en
 * src/lib/dashboard.js (y se explican en pantalla).
 *
 * Los datos se descargan una vez (dos vistas, SQL 084) y todo lo demás se
 * calcula en el navegador.
 */

const ESTILO_INPUT = 'padding:8px 12px;border:1.5px solid var(--border2);border-radius:var(--r);font-size:13px;width:100%;min-width:0;box-sizing:border-box;background:var(--surface);color:var(--text);';
const MAX_MS_DATOS = 10 * 60 * 1000;

// Estado que se conserva mientras la sesión siga abierta.
let datos = null;          // { lineas, despachos } ya preparados
let cargadoEn = null;      // Date
let cambiosPendientes = [];
let cargando = false;
let medida = 'pendiente';
let lectura = 'flujo';
let dimensiones = ['', ''];
let filtros = { ...FILTROS_VACIOS };

const CAMPOS_FACETAS = {
  cliente: { columna: 'cliente', modo: 'exacto', lista: true },
  nombreSuela: { columna: 'nombre_suela', modo: 'exacto', lista: true },
  material: { columna: 'material', modo: 'exacto', lista: true },
  color: { columna: 'color', modo: 'exacto', lista: true }
};

const SELECT_POR_FACETA = {
  cliente: 'dash-f-cliente',
  nombreSuela: 'dash-f-suela',
  material: 'dash-f-material',
  color: 'dash-f-color'
};

const TOGGLES = ['vira', 'acabado', 'esterilla', 'marquilla'];

const ESTILO_PAGINA = `
  .dash-sub { font-size:12px; color:var(--text2); margin:-0.25rem 0 1rem; }
  .dash-tarjetas { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:0.75rem; margin-bottom:1rem; }
  .dash-tarjeta { text-align:left; background:var(--surface); border:1.5px solid var(--border); border-radius:var(--r);
    padding:14px 16px; cursor:pointer; font:inherit; color:inherit; transition:border-color .15s, background .15s, box-shadow .15s; }
  .dash-tarjeta:hover { border-color:var(--blue); }
  .dash-tarjeta.activa { border-color:var(--blue); background:var(--blue-bg); box-shadow:0 0 0 3px var(--blue-bg); }
  .dash-tarjeta-lbl { font-size:12px; font-weight:600; color:var(--text2); text-transform:uppercase; letter-spacing:.04em; }
  .dash-tarjeta-valor { font-size:28px; font-weight:700; color:var(--text); line-height:1.2; margin:4px 0 2px; font-variant-numeric:tabular-nums; }
  .dash-tarjeta-unidad { font-size:12px; font-weight:500; color:var(--text2); margin-left:4px; }
  .dash-tarjeta-fecha { font-size:11px; color:var(--text3); }
  .dash-lectura { display:flex; flex-wrap:wrap; align-items:center; gap:0.75rem; margin-bottom:0.75rem; }
  .dash-lectura-lbl { font-size:12px; color:var(--text2); font-weight:600; }
  .dash-segmentado { display:inline-flex; border:1.5px solid var(--border2); border-radius:var(--r); overflow:hidden; }
  .dash-segmentado button { border:0; background:var(--surface); color:var(--text2); font:inherit; font-size:13px; padding:7px 14px; cursor:pointer; }
  .dash-segmentado button + button { border-left:1.5px solid var(--border2); }
  .dash-segmentado button.activo { background:var(--blue); color:#fff; }
  .dash-lectura-ayuda { font-size:12px; color:var(--text2); }
  .dash-bloque { display:grid; gap:0.75rem; margin-bottom:0.75rem; }
  .dash-fila-agrupar { grid-template-columns:150px minmax(0,1.2fr) 150px minmax(0,1.2fr); align-items:center; }
  .dash-fila-filtros { grid-template-columns:repeat(4,minmax(0,1fr)); }
  .dash-fila-filtros2 { grid-template-columns:repeat(4,minmax(0,1fr)); align-items:end; }
  .dash-etiqueta { font-size:12px; color:var(--text2); white-space:nowrap; }
  .dash-campo { display:flex; flex-direction:column; gap:4px; min-width:0; }
  .dash-fechas { font-size:12px; color:var(--text2); background:var(--bg); border:1px solid var(--border2); border-radius:var(--r);
    padding:8px 12px; margin:0.25rem 0 1rem; }
  .dash-fechas strong { color:var(--text); }
  .dash-tabla-wrap { overflow-x:auto; }
  .dash-tabla { width:100%; border-collapse:collapse; font-size:13px; }
  .dash-tabla th { background:var(--bg); border-bottom:2px solid var(--border); padding:8px; text-align:left; font-size:12px; color:var(--text2); text-transform:uppercase; letter-spacing:.04em; }
  .dash-tabla td { padding:8px; border-bottom:1px solid var(--border); }
  .dash-tabla .num { text-align:right; font-variant-numeric:tabular-nums; white-space:nowrap; }
  .dash-tabla tfoot td { font-weight:700; border-top:2px solid var(--border); border-bottom:0; background:var(--bg); }
  .dash-barra-celda { width:34%; min-width:120px; }
  .dash-barra { height:8px; border-radius:999px; background:var(--blue-bg); overflow:hidden; }
  .dash-barra > span { display:block; height:100%; background:var(--blue); border-radius:999px; }
  .dash-notas { display:grid; gap:0.5rem; margin-top:1rem; }
  .dash-nota { font-size:12px; border-radius:var(--r); padding:8px 12px; background:var(--amber-bg); color:var(--amber-text); }
  .dash-nota.info { background:var(--bg); color:var(--text2); border:1px solid var(--border2); }
  .dash-nota button { background:none; border:0; padding:0; font:inherit; font-weight:700; color:inherit; text-decoration:underline; cursor:pointer; }
  @media (max-width: 768px) {
    .dash-tarjetas, .dash-fila-agrupar, .dash-fila-filtros, .dash-fila-filtros2 { grid-template-columns:1fr; }
    .dash-tarjeta-valor { font-size:24px; }
  }
`;

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

function hoyColombia() {
  return diaColombia(new Date());
}

// ---------------------------------------------------------------------
// Carga
// ---------------------------------------------------------------------

async function cargarDatos(forzar = false) {
  if (cargando) return;
  const vigente = datos && cargadoEn && Date.now() - cargadoEn.getTime() < MAX_MS_DATOS;
  if (vigente && !forzar) return;

  cargando = true;
  pintarCargando(true);
  try {
    const [lineas, despachos, pendientes] = await Promise.all([
      fetchLineasDashboard(),
      fetchDespachosDashboard(),
      fetchPedidosConCambiosPendientes()
    ]);
    datos = {
      lineas: prepararLineas(lineas, hoyColombia()),
      despachos: prepararDespachos(despachos)
    };
    cambiosPendientes = pendientes;
    cargadoEn = new Date();
  } catch (err) {
    mostrarToast(err.message, 'error');
    const cont = document.getElementById('dash-resultado');
    if (cont) cont.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    datos = null;
  } finally {
    cargando = false;
    pintarCargando(false);
  }
  if (datos) pintar();
}

function pintarCargando(si) {
  const btn = document.getElementById('dash-refrescar');
  if (btn) {
    btn.disabled = si;
    btn.textContent = si ? '⏳ Cargando...' : '🔄 Actualizar';
  }
  if (si && !datos) {
    const cont = document.getElementById('dash-resultado');
    if (cont) cont.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando datos...</div>';
  }
}

// ---------------------------------------------------------------------
// Pantalla
// ---------------------------------------------------------------------

export async function cargarDashboardPage() {
  const contenedor = document.getElementById('page-dashboard');
  if (!contenedor || !esValidador()) return;

  const opcionesDim = (n) => `<option value="">${n === 0 ? 'Sin agrupar (solo el total)' : 'Nada más'}</option>` +
    Object.entries(DIMENSIONES).map(([k, d]) => `<option value="${k}" data-dim="${k}">${escapeHtml(d.etiqueta)}</option>`).join('');

  contenedor.innerHTML = `
    <style>${ESTILO_PAGINA}</style>
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; gap:0.75rem; margin-bottom:1rem; flex-wrap:wrap;">
        <h2>📊 Dashboard de unidades</h2>
        <div style="display:flex; align-items:center; gap:0.75rem;">
          <span id="dash-actualizado" style="font-size:12px; color:var(--text3);"></span>
          <button id="dash-refrescar" class="btn btn-secondary btn-sm">🔄 Actualizar</button>
        </div>
      </div>
      <div class="dash-sub">Pares (unidades) de los pedidos desde el 3095. Toque una tarjeta para elegir qué mirar.</div>

      <div class="dash-tarjetas" id="dash-tarjetas"></div>

      <div class="dash-lectura" id="dash-lectura" style="display:none;">
        <span class="dash-lectura-lbl">Cómo leer lo despachado:</span>
        <div class="dash-segmentado" id="dash-segmentado">
          ${Object.entries(LECTURAS).map(([k, l]) => `<button type="button" data-lectura="${k}">${escapeHtml(l.etiqueta)}</button>`).join('')}
        </div>
        <span class="dash-lectura-ayuda" id="dash-lectura-ayuda"></span>
      </div>

      <div class="dash-bloque dash-fila-agrupar">
        <label class="dash-etiqueta" for="dash-dim1">Agrupar por</label>
        <select id="dash-dim1" style="${ESTILO_INPUT}">${opcionesDim(0)}</select>
        <label class="dash-etiqueta" for="dash-dim2">y luego por</label>
        <select id="dash-dim2" style="${ESTILO_INPUT}">${opcionesDim(1)}</select>
      </div>

      <div class="dash-bloque dash-fila-filtros">
        <select id="dash-f-cliente" style="${ESTILO_INPUT}"><option value="">Cliente...</option></select>
        <select id="dash-f-suela" style="${ESTILO_INPUT}"><option value="">Nombre Suela...</option></select>
        <select id="dash-f-material" style="${ESTILO_INPUT}"><option value="">Material...</option></select>
        <select id="dash-f-color" style="${ESTILO_INPUT}"><option value="">Color...</option></select>
      </div>

      <div class="dash-bloque dash-fila-filtros2">
        <label class="dash-campo"><span class="dash-etiqueta" id="dash-lbl-desde">Desde</span>
          <input type="date" id="dash-desde" style="${ESTILO_INPUT}"></label>
        <label class="dash-campo"><span class="dash-etiqueta" id="dash-lbl-hasta">Hasta</span>
          <input type="date" id="dash-hasta" style="${ESTILO_INPUT}"></label>
        <label class="dash-campo"><span class="dash-etiqueta">Estado del pedido</span>
          <select id="dash-estado" style="${ESTILO_INPUT}">
            <option value="">Todos</option>
            <option value="abierto">Abiertos</option>
            <option value="cerrado">Cerrados a la fuerza</option>
          </select></label>
        <button type="button" id="dash-limpiar" class="btn btn-secondary btn-sm" style="justify-self:start;">Limpiar filtros</button>
      </div>

      <div class="dash-bloque dash-fila-filtros">
        ${TOGGLES.map((t) => `
        <label class="filtro-toggle" data-filtro-toggle="dash-t-${t}" title="Solo pares de pedidos con ${t}">
          <span class="filtro-toggle-lbl">${t.charAt(0).toUpperCase() + t.slice(1)}</span>
          <span class="propuesta-switch">
            <input type="checkbox" id="dash-t-${t}">
            <span class="propuesta-switch-slider"></span>
          </span>
        </label>`).join('')}
      </div>

      <div class="dash-fechas" id="dash-fechas"></div>
      <div id="dash-resultado"></div>
      <div class="dash-notas" id="dash-notas"></div>
    </div>
  `;

  enlazarControles();
  sincronizarControles();
  if (datos) pintar();
  await cargarDatos(false);
}

function enlazarControles() {
  document.getElementById('dash-refrescar')?.addEventListener('click', () => cargarDatos(true));

  document.getElementById('dash-tarjetas')?.addEventListener('click', (e) => {
    const tarjeta = e.target.closest('[data-medida]');
    if (!tarjeta) return;
    medida = tarjeta.dataset.medida;
    // La antigüedad solo existe para el pendiente.
    dimensiones = dimensiones.map((d) => (d === 'antiguedad' && medida !== 'pendiente' ? '' : d));
    sincronizarControles();
    pintar();
  });

  document.getElementById('dash-segmentado')?.addEventListener('click', (e) => {
    const btn = e.target.closest('[data-lectura]');
    if (!btn) return;
    lectura = btn.dataset.lectura;
    sincronizarControles();
    pintar();
  });

  ['dash-dim1', 'dash-dim2'].forEach((id, i) => {
    document.getElementById(id)?.addEventListener('change', (e) => {
      dimensiones[i] = e.target.value;
      // No tiene sentido repetir la misma categoría dos veces.
      if (dimensiones[0] && dimensiones[0] === dimensiones[1]) dimensiones[1] = '';
      sincronizarControles();
      pintar();
    });
  });

  Object.entries(SELECT_POR_FACETA).forEach(([clave, id]) => {
    document.getElementById(id)?.addEventListener('change', (e) => {
      filtros[clave] = e.target.value;
      pintar();
    });
  });

  [['dash-desde', 'desde'], ['dash-hasta', 'hasta']].forEach(([id, clave]) => {
    document.getElementById(id)?.addEventListener('change', (e) => {
      filtros[clave] = e.target.value;
      pintar();
    });
  });

  document.getElementById('dash-estado')?.addEventListener('change', (e) => {
    filtros.estado = e.target.value;
    pintar();
  });

  TOGGLES.forEach((t) => {
    document.getElementById(`dash-t-${t}`)?.addEventListener('change', (e) => {
      filtros[t] = e.target.checked ? 'Si' : '';
      pintar();
    });
  });

  document.getElementById('dash-limpiar')?.addEventListener('click', () => {
    filtros = { ...FILTROS_VACIOS };
    sincronizarControles();
    pintar();
  });

  document.getElementById('dash-resultado')?.addEventListener('click', manejarClicPedido);
  document.getElementById('dash-notas')?.addEventListener('click', manejarClicPedido);
}

function manejarClicPedido(e) {
  const btn = e.target.closest('[data-pedido]');
  if (btn) abrirDetalleOrden(btn.dataset.pedido);
}

/** Refleja el estado (medida, lectura, dimensiones, filtros) en los controles. */
function sincronizarControles() {
  const lecturaDate = fechaDeLectura(medida, lectura);

  const lectBloque = document.getElementById('dash-lectura');
  if (lectBloque) lectBloque.style.display = medida === 'despachado' ? 'flex' : 'none';
  document.querySelectorAll('#dash-segmentado [data-lectura]').forEach((b) => {
    b.classList.toggle('activo', b.dataset.lectura === lectura);
  });
  const ayuda = document.getElementById('dash-lectura-ayuda');
  if (ayuda) ayuda.textContent = LECTURAS[lectura].ayuda;

  [['dash-dim1', 0], ['dash-dim2', 1]].forEach(([id, i]) => {
    const sel = document.getElementById(id);
    if (!sel) return;
    sel.value = dimensiones[i] || '';
    [...sel.options].forEach((o) => {
      if (!o.dataset.dim) return;
      const def = DIMENSIONES[o.dataset.dim];
      o.disabled = !!(def.soloPendiente && medida !== 'pendiente');
      if (o.dataset.dim === 'mes' || o.dataset.dim === 'dia') {
        o.textContent = `${def.etiqueta} (${lecturaDate.base === 'despacho' ? 'del despacho' : 'del pedido'})`;
      }
    });
  });

  const nombreFecha = lecturaDate.base === 'despacho' ? 'despacho' : 'pedido';
  const desde = document.getElementById('dash-lbl-desde');
  const hasta = document.getElementById('dash-lbl-hasta');
  if (desde) desde.textContent = `Desde (fecha del ${nombreFecha})`;
  if (hasta) hasta.textContent = `Hasta (fecha del ${nombreFecha})`;

  document.getElementById('dash-desde') && (document.getElementById('dash-desde').value = filtros.desde || '');
  document.getElementById('dash-hasta') && (document.getElementById('dash-hasta').value = filtros.hasta || '');
  document.getElementById('dash-estado') && (document.getElementById('dash-estado').value = filtros.estado || '');
  TOGGLES.forEach((t) => {
    const el = document.getElementById(`dash-t-${t}`);
    if (el) el.checked = filtros[t] === 'Si';
  });
}

function pintar() {
  if (!datos) return;
  const dims = dimensiones.filter(Boolean);
  const lecturaDate = fechaDeLectura(medida, lectura);

  // --- Tarjetas (cada una con su fecha natural) ---
  const totales = totalesTarjetas(datos, lectura, filtros);
  const fechaTarjeta = {
    solicitado: 'por fecha del pedido',
    despachado: lectura === 'flujo' ? 'por fecha del despacho' : 'por fecha del pedido',
    pendiente: 'por fecha del pedido'
  };
  const tarjetas = document.getElementById('dash-tarjetas');
  if (tarjetas) {
    tarjetas.innerHTML = Object.entries(MEDIDAS).map(([k, m]) => `
      <button type="button" class="dash-tarjeta${medida === k ? ' activa' : ''}" data-medida="${k}" title="${escapeHtml(m.ayuda)}">
        <div class="dash-tarjeta-lbl">${escapeHtml(m.etiqueta)}</div>
        <div class="dash-tarjeta-valor">${formatearPares(totales[k])}<span class="dash-tarjeta-unidad">pares</span></div>
        <div class="dash-tarjeta-fecha">${fechaTarjeta[k]}</div>
      </button>`).join('');
  }

  // --- Opciones en cascada de los 4 desplegables ---
  const filasFacetas = [...datos.lineas, ...datos.despachos];
  const opciones = calcularOpciones(filasFacetas, filtros, CAMPOS_FACETAS);
  Object.entries(SELECT_POR_FACETA).forEach(([clave, id]) => {
    reconstruirOpciones(id, opciones[clave] || [], filtros[clave] || '');
  });

  // --- Explicación de fechas ---
  const cajaFechas = document.getElementById('dash-fechas');
  if (cajaFechas) {
    cajaFechas.innerHTML = `📅 <strong>Fechas:</strong> Mes, Día y el rango Desde/Hasta se leen por la
      <strong>${lecturaDate.nombre}</strong>. ${escapeHtml(lecturaDate.porque)}`;
  }

  // --- Tabla ---
  const resultado = agrupar(datos, { medida, lectura, dimensiones: dims, filtros });
  const cont = document.getElementById('dash-resultado');
  if (cont) cont.innerHTML = htmlTabla(resultado, dims);

  // --- Notas ---
  const notas = notasDashboard(datos, filtros);
  const partes = [];
  if (notas.deMas.length > 0) {
    partes.push(`<div class="dash-nota">⚠ <strong>Despachado de más:</strong> en estos pedidos salió más de lo solicitado
      (su pendiente cuenta 0): ${listaPedidos(notas.deMas)}</div>`);
  }
  if (cambiosPendientes.length > 0) {
    partes.push(`<div class="dash-nota">⚠ Hay <strong>${cambiosPendientes.length}</strong> pedido${cambiosPendientes.length === 1 ? '' : 's'}
      con cambios de Access por revisar (pestaña Cambios ERP). Estos números usan lo que hay hoy en la plataforma.</div>`);
  }
  if (notas.cancelados.length > 0) {
    const pares = notas.cancelados.reduce((s, n) => s + n.pares, 0);
    partes.push(`<div class="dash-nota info">ℹ ${notas.cancelados.length} pedido${notas.cancelados.length === 1 ? '' : 's'} cancelado${notas.cancelados.length === 1 ? '' : 's'}
      en Access (${formatearPares(pares)} pares) no cuenta${notas.cancelados.length === 1 ? '' : 'n'} en solicitado ni pendiente. Lo que ya se
      despachó de ellos sí aparece en el despachado por fecha de despacho. ${listaPedidos(notas.cancelados)}</div>`);
  }
  const notasEl = document.getElementById('dash-notas');
  if (notasEl) notasEl.innerHTML = partes.join('');

  const act = document.getElementById('dash-actualizado');
  if (act && cargadoEn) {
    act.textContent = `Datos de las ${cargadoEn.toLocaleTimeString('es-CO', { hour: '2-digit', minute: '2-digit', hour12: false })}`;
  }
}

/**
 * Reemplaza las opciones de un desplegable conservando el título y el valor
 * elegido (aunque ya no esté en la lista, para que no desaparezca solo).
 */
function reconstruirOpciones(id, valores, actual) {
  const select = document.getElementById(id);
  if (!select) return;
  const placeholder = select.options[0];
  const lista = actual && !valores.includes(actual) ? [actual, ...valores] : valores;
  select.innerHTML = '';
  if (placeholder) select.appendChild(placeholder);
  lista.forEach((valor) => {
    const option = document.createElement('option');
    option.value = valor;
    option.textContent = valor;
    select.appendChild(option);
  });
  select.value = actual;
}

function listaPedidos(lista) {
  const visibles = lista.slice(0, 12)
    .map((n) => `<button type="button" data-pedido="${escapeHtml(n.pedido)}">${escapeHtml(n.pedido)}</button> (${formatearPares(n.pares)})`)
    .join(', ');
  return visibles + (lista.length > 12 ? ` y ${lista.length - 12} más` : '');
}

function htmlTabla({ filas, total }, dims) {
  if (filas.length === 0) {
    return '<div class="empty">No hay pares para mostrar con estos filtros.</div>';
  }
  const maximo = Math.max(...filas.map((f) => f.valor), 1);
  const encabezados = dims.length
    ? dims.map((d) => `<th>${escapeHtml(DIMENSIONES[d].etiqueta)}</th>`).join('')
    : '<th>Total</th>';

  const cuerpo = filas.map((f) => {
    const pct = total > 0 ? (f.valor / total) * 100 : 0;
    const celdas = dims.length
      ? f.etiquetas.map((e) => `<td>${escapeHtml(e)}</td>`).join('')
      : '<td>Todos los pares</td>';
    return `<tr>${celdas}
      <td class="num">${formatearPares(f.valor)}</td>
      <td class="num">${pct.toFixed(1).replace('.', ',')}%</td>
      <td class="dash-barra-celda"><div class="dash-barra"><span style="width:${(f.valor / maximo) * 100}%"></span></div></td>
    </tr>`;
  }).join('');

  return `
    <div class="dash-tabla-wrap">
      <table class="dash-tabla">
        <thead><tr>${encabezados}<th class="num">Pares</th><th class="num">% del total</th><th></th></tr></thead>
        <tbody>${cuerpo}</tbody>
        <tfoot><tr><td colspan="${Math.max(dims.length, 1)}">Total</td><td class="num">${formatearPares(total)}</td><td class="num">100%</td><td></td></tr></tfoot>
      </table>
    </div>`;
}
