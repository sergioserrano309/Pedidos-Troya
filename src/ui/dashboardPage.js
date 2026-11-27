import { getState } from '../state/appState.js';
import { esValidador } from '../services/validatorService.js';
import {
  fetchLineasDashboard, fetchDespachosDashboard, fetchPedidosConCambiosPendientes, fetchInfoDespachosDashboard,
  fetchBultosPorOrdenDespacho, fetchLineasTroyaDashboard
} from '../services/dashboardService.js';
import {
  MEDIDAS, LECTURAS, DIMENSIONES, FILTROS_VACIOS, prepararLineas, prepararDespachos,
  agrupar, totalesTarjetas, notasDashboard, fechaDeLectura, formatearPares, diaColombia, bultosPorCliente
} from '../lib/dashboard.js';
import { calcularOpciones } from '../lib/facetas.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { mostrarToast } from './toast.js';

/**
 * Pestaña "Dashboard" (Validador completo; Empaque solo Despachado): pares (unidades) solicitados,
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

// Controles de la versión reducida (Empaque): todos con la misma altura, el botón incluido.
const ESTILO_RED = ESTILO_INPUT + 'height:36px;';

/** Empaque ve solo lo despachado (sin solicitado ni pendiente); el Validador lo ve todo. */
function soloDespachado() {
  return !esValidador();
}

/** ¿"Bultos (por despacho)" tiene sentido con lo elegido? Solo en Despachado por fecha de despacho. */
function despachoPermitido() {
  return medida === 'despachado' && lectura === 'flujo';
}

// Estado que se conserva mientras la sesión siga abierta.
let datos = null;          // { lineas, despachos, infoDespachos, asignaciones } ya preparados (los dos últimos pueden ser null hasta que se pidan)
let datosReducidos = false; // true = datos de la versión liviana (Empaque)
let pidiendoExtras = false;
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
  color: { columna: 'color', modo: 'exacto', lista: true },
  talla: { columna: 'talla', modo: 'exacto', lista: true }
};

const SELECT_POR_FACETA = {
  cliente: 'dash-f-cliente',
  nombreSuela: 'dash-f-suela',
  material: 'dash-f-material',
  color: 'dash-f-color',
  talla: 'dash-f-talla'
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
  .dash-fila-filtros { grid-template-columns:repeat(5,minmax(0,1fr)); }
  .dash-fila-filtros2 { grid-template-columns:repeat(4,minmax(0,1fr)); align-items:end; }
  .dash-fila-red1 { grid-template-columns:minmax(0,1.5fr) minmax(0,1fr); align-items:center; }
  .dash-fila-red2 { grid-template-columns:repeat(4,minmax(0,1fr)) 90px; align-items:end; }
  .dash-agrupar-red { display:flex; align-items:center; gap:0.75rem; min-width:0; }
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
  .dash-barra { display:flex; }
  .dash-barra > span { display:block; height:100%; background:var(--blue); }
  .dash-barra > span.troya { background:#7c3aed; }
  .dash-leyenda { display:flex; flex-wrap:wrap; gap:14px; font-size:12px; color:var(--text2); margin:0 0 0.5rem; }
  .dash-leyenda i { display:inline-block; width:10px; height:10px; border-radius:2px; margin-right:5px; vertical-align:-1px; background:var(--blue); }
  .dash-leyenda i.troya { background:#7c3aed; }
  .dash-tarjeta-troya { font-size:11px; color:#7c3aed; margin-top:2px; }
  .dash-notas { display:grid; gap:0.5rem; margin-top:1rem; }
  .dash-nota { font-size:12px; border-radius:var(--r); padding:8px 12px; background:var(--amber-bg); color:var(--amber-text); }
  .dash-nota.info { background:var(--bg); color:var(--text2); border:1px solid var(--border2); }
  .dash-nota button { background:none; border:0; padding:0; font:inherit; font-weight:700; color:inherit; text-decoration:underline; cursor:pointer; }
  @media (max-width: 768px) {
    .dash-tarjetas, .dash-fila-agrupar, .dash-fila-filtros, .dash-fila-filtros2, .dash-fila-red1, .dash-fila-red2 { grid-template-columns:1fr; }
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

let recargarPendiente = false;
let usuarioFechaInicial = null;

/** Despachos y consecutivos ya cargados, para pedir los bultos solo de esos (null = todos). */
function despachosCargados() {
  if (!datos?.dia) return { ids: null, consecutivos: null };
  return {
    ids: [...new Set(datos.despachos.map((d) => d.despacho_id))],
    consecutivos: [...new Set(datos.despachos.map((d) => d.consecutivo).filter(Boolean))]
  };
}

async function cargarDatos(forzar = false) {
  if (cargando) {
    // Cambió la fecha mientras se cargaba otra: se vuelve a cargar al terminar.
    if (forzar) recargarPendiente = true;
    return;
  }
  const reducido = soloDespachado();
  // Empaque trabaja de a un día: los datos son de UN día (los que dice la fecha del despacho).
  const dia = reducido ? (filtros.desde || '') : '';
  // Los datos de Empaque (versión liviana) no sirven para el Validador y al revés.
  const vigente = datos && cargadoEn && datosReducidos === reducido && (datos.dia || '') === dia
    && Date.now() - cargadoEn.getTime() < MAX_MS_DATOS;
  if (vigente && !forzar) return;

  cargando = true;
  if (reducido && datos && (datos.dia || '') !== dia) datos = null; // otro día: se muestra "Cargando..."
  pintarCargando(true);
  try {
    // Empaque: solo los despachos de ese día (filtrados en la base), solo las líneas de Troya y sin la
    // nota de cambios de Access. Los bultos (por despacho / por cliente) solo si esa agrupación está
    // elegida y solo de esos despachos; si se elige después, se piden en ese momento.
    const despachosP = fetchDespachosDashboard({ dia });
    const lineasP = reducido ? fetchLineasTroyaDashboard({ dia }) : fetchLineasDashboard();
    const pendientesP = reducido ? Promise.resolve([]) : fetchPedidosConCambiosPendientes();
    const extrasP = (async () => {
      const quiereInfo = dimensiones.includes('despacho');
      const quiereBultos = dimensiones.includes('bultosCliente');
      if (!quiereInfo && !quiereBultos) return [null, null];
      const filas = dia ? await despachosP : null; // con día, los bultos se piden solo de esos despachos
      const ids = filas ? [...new Set(filas.map((d) => d.despacho_id))] : null;
      const consecutivos = filas ? [...new Set(filas.map((d) => d.consecutivo).filter(Boolean))] : null;
      return Promise.all([
        quiereInfo ? fetchInfoDespachosDashboard({ consecutivos }) : null,
        quiereBultos ? fetchBultosPorOrdenDespacho({ despachoIds: ids }) : null
      ]);
    })();
    const [lineas, despachos, pendientes, [infoDespachos, asignaciones]] =
      await Promise.all([lineasP, despachosP, pendientesP, extrasP]);
    datos = {
      lineas: prepararLineas(lineas, hoyColombia()),
      despachos: prepararDespachos(despachos),
      infoDespachos,
      asignaciones,
      dia
    };
    datosReducidos = reducido;
    cambiosPendientes = pendientes;
    cargadoEn = new Date();
  } catch (err) {
    mostrarToast(err.message, 'error');
    const cont = document.getElementById('dash-resultado');
    if (cont) cont.innerHTML = `<div class="empty">${escapeHtml(err.message)}</div>`;
    datos = null;
    recargarPendiente = false;
  } finally {
    cargando = false;
    pintarCargando(false);
  }
  if (recargarPendiente) {
    recargarPendiente = false;
    await cargarDatos(true);
    return;
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
  if (!contenedor) return;
  // Validador (todo) y Empaque (solo Despachado). Cualquier otro rol no llega aquí.
  if (soloDespachado()) {
    if (getState().user?.role !== 'empaque') return;
    medida = 'despachado';
    // La antigüedad es solo del pendiente: si venía elegida de otra sesión, se quita.
    dimensiones = dimensiones.map((d) => (d === 'antiguedad' ? '' : d));
    // Versión reducida: siempre por fecha de despacho, una sola agrupación, un solo día,
    // sin Estado del pedido ni Vira/Acabado/Esterilla/Marquilla.
    lectura = 'flujo';
    dimensiones = [dimensiones[0] || 'bultosCliente', ''];
    filtros.talla = '';
    filtros.estado = '';
    TOGGLES.forEach((t) => { filtros[t] = ''; });
    // Primera vez en la sesión: la fecha del despacho arranca en HOY (se puede cambiar).
    const idUsuario = getState().user?.id ?? null;
    if (idUsuario !== usuarioFechaInicial) {
      usuarioFechaInicial = idUsuario;
      filtros.desde = hoyColombia();
    }
    filtros.hasta = filtros.desde;
  }
  const reducido = soloDespachado();

  const opcionesDim = (n) => `<option value="">${n === 0 ? 'Sin agrupar (solo el total)' : 'Nada más'}</option>` +
    Object.entries(DIMENSIONES).map(([k, d]) => `<option value="${k}" data-dim="${k}">${escapeHtml(d.etiqueta)}</option>`).join('');

  contenedor.innerHTML = `
    <style>${ESTILO_PAGINA}</style>
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; gap:0.75rem; margin-bottom:1rem; flex-wrap:wrap;">
        <h2 style="display:flex; align-items:center; gap:8px;"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><line x1="18" y1="20" x2="18" y2="10"/><line x1="12" y1="20" x2="12" y2="4"/><line x1="6" y1="20" x2="6" y2="14"/></svg>Dashboard de unidades</h2>
        <div style="display:flex; align-items:center; gap:0.75rem;">
          <span id="dash-actualizado" style="font-size:12px; color:var(--text3);"></span>
          <button id="dash-refrescar" class="btn btn-secondary btn-sm">🔄 Actualizar</button>
        </div>
      </div>
      ${soloDespachado() ? '' : '<div class="dash-sub">Pares (unidades) de los pedidos desde el 3095. Toque una tarjeta para elegir qué mirar.</div>'}

      <div class="dash-tarjetas" id="dash-tarjetas"></div>

      ${reducido ? '' : `      <div class="dash-lectura" id="dash-lectura" style="display:none;">
        <span class="dash-lectura-lbl">Cómo leer lo despachado:</span>
        <div class="dash-segmentado" id="dash-segmentado">
          ${Object.entries(LECTURAS).map(([k, l]) => `<button type="button" data-lectura="${k}">${escapeHtml(l.etiqueta)}</button>`).join('')}
        </div>
        <span class="dash-lectura-ayuda" id="dash-lectura-ayuda"></span>
      </div>`}

      ${reducido ? `
      <div class="dash-bloque dash-fila-red1">
        <div class="dash-agrupar-red">
          <label class="dash-etiqueta" for="dash-dim1">Agrupar por</label>
          <select id="dash-dim1" style="${ESTILO_RED}">${opcionesDim(0)}</select>
        </div>
        <select id="dash-f-cliente" style="${ESTILO_RED}"><option value="">Cliente...</option></select>
      </div>

      <div class="dash-bloque dash-fila-red2">
        <label class="dash-campo"><span class="dash-etiqueta">Fecha del despacho</span>
          <input type="date" id="dash-fecha" style="${ESTILO_RED}"></label>
        <select id="dash-f-suela" style="${ESTILO_RED}"><option value="">Nombre Suela...</option></select>
        <select id="dash-f-material" style="${ESTILO_RED}"><option value="">Material...</option></select>
        <select id="dash-f-color" style="${ESTILO_RED}"><option value="">Color...</option></select>
        <button type="button" id="dash-limpiar" class="btn btn-secondary" style="${ESTILO_RED}cursor:pointer;">Limpiar</button>
      </div>
      ` : `
      <div class="dash-bloque dash-fila-agrupar"${reducido ? ' style="grid-template-columns:150px minmax(0,1.2fr);"' : ''}>
        <label class="dash-etiqueta" for="dash-dim1">Agrupar por</label>
        <select id="dash-dim1" style="${ESTILO_INPUT}">${opcionesDim(0)}</select>
        ${reducido ? '' : `<label class="dash-etiqueta" for="dash-dim2">y luego por</label>
        <select id="dash-dim2" style="${ESTILO_INPUT}">${opcionesDim(1)}</select>`}
      </div>

      <div class="dash-bloque dash-fila-filtros">
        <select id="dash-f-cliente" style="${ESTILO_INPUT}"><option value="">Cliente...</option></select>
        <select id="dash-f-suela" style="${ESTILO_INPUT}"><option value="">Nombre Suela...</option></select>
        <select id="dash-f-material" style="${ESTILO_INPUT}"><option value="">Material...</option></select>
        <select id="dash-f-color" style="${ESTILO_INPUT}"><option value="">Color...</option></select>
        <select id="dash-f-talla" style="${ESTILO_INPUT}"><option value="">Talla...</option></select>
      </div>

      <div class="dash-bloque dash-fila-filtros2">
        ${reducido ? `
        <label class="dash-campo"><span class="dash-etiqueta">Fecha del despacho</span>
          <input type="date" id="dash-fecha" style="${ESTILO_INPUT}"></label>` : `
        <label class="dash-campo"><span class="dash-etiqueta" id="dash-lbl-desde">Desde</span>
          <input type="date" id="dash-desde" style="${ESTILO_INPUT}"></label>
        <label class="dash-campo"><span class="dash-etiqueta" id="dash-lbl-hasta">Hasta</span>
          <input type="date" id="dash-hasta" style="${ESTILO_INPUT}"></label>
        <label class="dash-campo"><span class="dash-etiqueta">Estado del pedido</span>
          <select id="dash-estado" style="${ESTILO_INPUT}">
            <option value="">Todos</option>
            <option value="abierto">Abiertos</option>
            <option value="cerrado">Cerrados a la fuerza</option>
          </select></label>`}
        <button type="button" id="dash-limpiar" class="btn btn-secondary btn-sm" style="justify-self:start;">Limpiar filtros</button>
      </div>
      `}

      ${reducido ? '' : `      <div class="dash-bloque dash-fila-filtros">
        ${TOGGLES.map((t) => `
        <label class="filtro-toggle" data-filtro-toggle="dash-t-${t}" title="Solo pares de pedidos con ${t}">
          <span class="filtro-toggle-lbl">${t.charAt(0).toUpperCase() + t.slice(1)}</span>
          <span class="propuesta-switch">
            <input type="checkbox" id="dash-t-${t}">
            <span class="propuesta-switch-slider"></span>
          </span>
        </label>`).join('')}
      </div>`}

      ${reducido ? '' : '<div class="dash-fechas" id="dash-fechas"></div>'}
      <div id="dash-resultado"></div>
      <div class="dash-notas" id="dash-notas"></div>
    </div>
  `;

  enlazarControles();
  sincronizarControles();
  if (datos && datosReducidos === reducido) pintar();
  await cargarDatos(false);
}

function enlazarControles() {
  document.getElementById('dash-refrescar')?.addEventListener('click', () => cargarDatos(true));

  document.getElementById('dash-tarjetas')?.addEventListener('click', (e) => {
    const tarjeta = e.target.closest('[data-medida]');
    if (!tarjeta || soloDespachado()) return;
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

  // Empaque: un solo día (los despachos de esa fecha) = Desde y Hasta iguales.
  document.getElementById('dash-fecha')?.addEventListener('change', (e) => {
    filtros.desde = e.target.value;
    filtros.hasta = e.target.value;
    cargarDatos(true); // datos de ese día (vacío = todos los días: tarda más)
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
    if (soloDespachado()) {
      // Empaque: "Limpiar" vuelve a la fecha de hoy, no a todos los días.
      filtros.desde = hoyColombia();
      filtros.hasta = filtros.desde;
      sincronizarControles();
      cargarDatos(true);
      return;
    }
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
  // "Bultos (por despacho)" solo existe en Despachado por fecha de despacho: si lo elegido cambia, se quita.
  if (!despachoPermitido()) dimensiones = dimensiones.map((d) => (DIMENSIONES[d]?.soloDespachadoFlujo ? '' : d));
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
      o.disabled = !!((def.soloPendiente && medida !== 'pendiente') || (def.soloDespachadoFlujo && !despachoPermitido()));
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

  document.getElementById('dash-fecha') && (document.getElementById('dash-fecha').value = filtros.desde || '');
  document.getElementById('dash-desde') && (document.getElementById('dash-desde').value = filtros.desde || '');
  document.getElementById('dash-hasta') && (document.getElementById('dash-hasta').value = filtros.hasta || '');
  document.getElementById('dash-estado') && (document.getElementById('dash-estado').value = filtros.estado || '');
  TOGGLES.forEach((t) => {
    const el = document.getElementById(`dash-t-${t}`);
    if (el) el.checked = filtros[t] === 'Si';
  });
}

/** Pide los bultos (por despacho / por cliente) la primera vez que se elige esa agrupación. */
function asegurarExtras(dims) {
  if (!datos || pidiendoExtras) return;
  const pedir = [];
  if (dims.includes('despacho') && datos.infoDespachos === null) {
    pedir.push(fetchInfoDespachosDashboard({ consecutivos: despachosCargados().consecutivos }).then((m) => { datos.infoDespachos = m; }));
  }
  if (dims.includes('bultosCliente') && datos.asignaciones === null) {
    pedir.push(fetchBultosPorOrdenDespacho({ despachoIds: despachosCargados().ids }).then((m) => { datos.asignaciones = m; }));
  }
  if (pedir.length === 0) return;
  pidiendoExtras = true;
  Promise.all(pedir).finally(() => {
    pidiendoExtras = false;
    pintar();
  });
}

function pintar() {
  if (!datos) return;
  const dims = dimensiones.filter(Boolean);
  asegurarExtras(dims);
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
    tarjetas.innerHTML = Object.entries(MEDIDAS).filter(([k]) => !soloDespachado() || k === 'despachado').map(([k, m]) => `
      <button type="button" class="dash-tarjeta${medida === k ? ' activa' : ''}" data-medida="${k}" title="${escapeHtml(m.ayuda)}"${soloDespachado() ? ' style="cursor:default;"' : ''}>
        <div class="dash-tarjeta-lbl">${escapeHtml(m.etiqueta)}</div>
        <div class="dash-tarjeta-valor">${formatearPares(totales[k])}<span class="dash-tarjeta-unidad">pares</span></div>
        <div class="dash-tarjeta-fecha">${fechaTarjeta[k]}</div>
        ${k === 'despachado' && totales.despachadoTroya > 0
          ? `<div class="dash-tarjeta-troya">incluye ${formatearPares(totales.despachadoTroya)} pares despachados en Troya</div>` : ''}
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
    cajaFechas.innerHTML = soloDespachado()
      ? '📅 <strong>Fechas:</strong> Mes, Día y la fecha elegida se leen por la <strong>fecha del despacho</strong>: cuenta lo que salió ese día (hora de Colombia), sin importar de qué pedido sea.'
      : `📅 <strong>Fechas:</strong> Mes, Día y el rango Desde/Hasta se leen por la
      <strong>${lecturaDate.nombre}</strong>. ${escapeHtml(lecturaDate.porque)}`;
  }

  // --- Tabla ---
  const resultado = agrupar(datos, { medida, lectura, dimensiones: dims, filtros });
  // "Bultos (por cliente)": de más a menos bultos (a igual cantidad, más pares primero).
  let bultosCli = null;
  if (dims.length === 1 && dims[0] === 'bultosCliente') {
    bultosCli = bultosPorCliente(datos, filtros);
    resultado.filas.sort((a, b) =>
      (bultosCli.porCliente.get(b.claves[0]) || 0) - (bultosCli.porCliente.get(a.claves[0]) || 0) || b.valor - a.valor);
  }
  const cont = document.getElementById('dash-resultado');
  if (cont) cont.innerHTML = htmlTabla(resultado, dims, medida === 'despachado', datos.infoDespachos, bultosCli);

  // --- Notas ---
  const notas = notasDashboard(datos, filtros);
  const partes = [];
  const completo = !soloDespachado();
  if (completo && notas.deMas.length > 0) {
    partes.push(`<div class="dash-nota">⚠ <strong>Despachado de más:</strong> en estos pedidos salió más de lo solicitado
      (su pendiente cuenta 0): ${listaPedidos(notas.deMas)}</div>`);
  }
  if (completo && cambiosPendientes.length > 0) {
    partes.push(`<div class="dash-nota">⚠ Hay <strong>${cambiosPendientes.length}</strong> pedido${cambiosPendientes.length === 1 ? '' : 's'}
      con cambios de Access por revisar (pestaña Cambios ERP). Estos números usan lo que hay hoy en la plataforma.</div>`);
  }
  if (completo && notas.cancelados.length > 0) {
    const pares = notas.cancelados.reduce((s, n) => s + n.pares, 0);
    partes.push(`<div class="dash-nota info">ℹ ${notas.cancelados.length} pedido${notas.cancelados.length === 1 ? '' : 's'} cancelado${notas.cancelados.length === 1 ? '' : 's'}
      en Access, o cerrado${notas.cancelados.length === 1 ? '' : 's'} a la fuerza como "Cancelado" (${formatearPares(pares)} pares), no cuenta${notas.cancelados.length === 1 ? '' : 'n'} en solicitado ni pendiente. Lo que ya se
      despachó de ellos sí aparece en el despachado por fecha de despacho. ${listaPedidos(notas.cancelados)}</div>`);
  }
  if (notas.troya.length > 0) {
    const pares = notas.troya.reduce((s, n) => s + n.pares, 0);
    const n = notas.troya.length;
    partes.push(`<div class="dash-nota info">ℹ <strong>Despachado en Troya:</strong> ${n} pedido${n === 1 ? '' : 's'} cerrado${n === 1 ? '' : 's'} a la fuerza
      como "Cerrado y despachado en Troya" (${formatearPares(pares)} pares) cuenta${n === 1 ? '' : 'n'} como despachado y no como pendiente. Aparece${n === 1 ? '' : 'n'} en
      "por fecha del pedido"; en "por fecha de despacho" solo si al cerrar se indicó el día en que salió en Troya. ${listaPedidos(notas.troya)}</div>`);
  }
  if (completo && notas.noSeDespacha.length > 0) {
    const pares = notas.noSeDespacha.reduce((s, n) => s + n.pares, 0);
    const n = notas.noSeDespacha.length;
    partes.push(`<div class="dash-nota info">ℹ <strong>Ya no se despacharán:</strong> ${formatearPares(pares)} pares de ${n} pedido${n === 1 ? '' : 's'}
      (cierres "No se terminó de despachar" o parcial en Troya) siguen en "solicitado" pero no cuentan como pendiente ni como despachado. ${listaPedidos(notas.noSeDespacha)}</div>`);
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

/** Barra de una fila: azul = real, violeta = despachado en Troya (si lo hay). */
function barra(f, maximo) {
  const real = Math.max(f.valor - (f.troya || 0), 0);
  const ancho = (v) => (v / maximo) * 100;
  return `<span style="width:${ancho(real)}%"></span>` +
    (f.troya > 0 ? `<span class="troya" style="width:${ancho(f.troya)}%"></span>` : '');
}

function htmlTabla({ filas, total, totalTroya }, dims, mostrarLeyenda, infoDespachos, bultosCli) {
  if (filas.length === 0) {
    return '<div class="empty">No hay pares para mostrar con estos filtros.</div>';
  }
  const maximo = Math.max(...filas.map((f) => f.valor), 1);
  const encabezados = dims.length
    ? dims.map((d) => `<th>${escapeHtml(DIMENSIONES[d].encabezado || DIMENSIONES[d].etiqueta)}</th>`).join('')
    : '<th>Total</th>';
  // Agrupado SOLO por despacho: dos columnas más, con los bultos y los kilos de cada despacho.
  const porDespacho = dims.length === 1 && dims[0] === 'despacho';
  const formatoKilos = (v) => Number(v).toLocaleString('es-CO', { maximumFractionDigits: 2 });
  let totalBultos = 0;
  let totalKilos = 0;
  // Agrupado SOLO por "Bultos (por cliente)": una columna de bultos por cliente (sin kilos).
  const porBultosCliente = Boolean(bultosCli);
  let sumaBultosCli = 0;

  const cuerpo = filas.map((f) => {
    const pct = total > 0 ? (f.valor / total) * 100 : 0;
    const celdas = dims.length
      ? f.etiquetas.map((e) => `<td>${escapeHtml(e)}</td>`).join('')
      : '<td>Todos los pares</td>';
    let extra = '';
    if (porBultosCliente) {
      const n = bultosCli.porCliente.get(f.claves[0]);
      sumaBultosCli += n || 0;
      extra = `<td class="num">${n ? formatearPares(n) : '—'}</td>`;
    }
    if (porDespacho) {
      const info = infoDespachos?.get(f.claves[0]);
      if (info) {
        totalBultos += info.bultos;
        totalKilos += info.kilos;
      }
      extra = `<td class="num">${info ? formatearPares(info.bultos) : '—'}</td><td class="num">${info ? formatoKilos(info.kilos) : '—'}</td>`;
    }
    return `<tr>${celdas}
      <td class="num">${formatearPares(f.valor)}</td>${extra}
      <td class="num">${pct.toFixed(1).replace('.', ',')}%</td>
      <td class="dash-barra-celda"><div class="dash-barra">${barra(f, maximo)}</div></td>
    </tr>`;
  }).join('');

  const leyenda = mostrarLeyenda && totalTroya > 0
    ? '<div class="dash-leyenda"><span><i></i>Despachado en la plataforma</span><span><i class="troya"></i>Despachado en Troya</span></div>'
    : '';

  const notaMixtos = porBultosCliente && sumaBultosCli > bultosCli.total
    ? '<div class="dash-sub" style="margin:0.5rem 0 0;">Un bulto con órdenes de varios clientes cuenta para cada uno; por eso la suma por cliente supera el total de bultos.</div>'
    : '';

  return `
    ${leyenda}
    <div class="dash-tabla-wrap">
      <table class="dash-tabla">
        <thead><tr>${encabezados}<th class="num">Pares</th>${porDespacho ? '<th class="num">Bultos</th><th class="num">Kilos</th>' : ''}${porBultosCliente ? '<th class="num">Bultos</th>' : ''}<th class="num">% del total</th><th></th></tr></thead>
        <tbody>${cuerpo}</tbody>
        <tfoot><tr><td colspan="${Math.max(dims.length, 1)}">Total</td><td class="num">${formatearPares(total)}</td>${porDespacho ? `<td class="num">${formatearPares(totalBultos)}</td><td class="num">${formatoKilos(totalKilos)}</td>` : ''}${porBultosCliente ? `<td class="num">${formatearPares(bultosCli.total)}</td>` : ''}<td class="num">100%</td><td></td></tr></tfoot>
      </table>
    </div>${notaMixtos}`;
}
