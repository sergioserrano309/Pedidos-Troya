import { getState } from '../state/appState.js';
import { fetchEliminaciones } from '../services/eliminacionesService.js';
import { mostrarToast } from './toast.js';

/**
 * Pestaña "Eliminaciones" (solo Validador).
 *
 * Muestra log_eliminaciones — el registro de TODO lo que se ha borrado en
 * la plataforma, por cualquier usuario, desde 014. Cubre dos tipos:
 *   - production_movements: un registro de producción (RegistrosO)
 *   - despachos: un despacho completo con sus órdenes/bultos (Despachos > Despachado)
 *
 * Es distinto de la pestaña Auditoría, que muestra audit_validador — solo
 * intervenciones del Validador, y que nunca ha registrado eliminaciones.
 *
 * Todo el contenido se escapa antes de inyectarse: el motivo lo escribe
 * el usuario y el snapshot contiene datos de la base.
 */

const TIPOS = {
  production_movements: 'Registro',
  despachos: 'Despacho'
};

let pagina = 0;
let total = 0;
let pageSize = 50;
let filtros = { tipo: '', referencia: '', desde: '', hasta: '' };
let debounceTimer = null;
let snapshotsPorId = new Map();

export function inicializarPaginaEliminaciones() {
  const inmediato = (id, clave) => {
    const el = document.getElementById(id);
    el?.addEventListener('input', () => {
      filtros[clave] = el.value;
      pagina = 0;
      cargarEliminaciones();
    });
  };
  inmediato('elim-filtro-desde', 'desde');
  inmediato('elim-filtro-hasta', 'hasta');

  const selectTipo = document.getElementById('elim-filtro-tipo');
  selectTipo?.addEventListener('change', () => {
    filtros.tipo = selectTipo.value;
    pagina = 0;
    cargarEliminaciones();
  });

  const inputRef = document.getElementById('elim-filtro-referencia');
  inputRef?.addEventListener('input', () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(() => {
      filtros.referencia = inputRef.value.trim();
      pagina = 0;
      cargarEliminaciones();
    }, 350);
  });

  document.getElementById('btn-cerrar-detalle-eliminacion')?.addEventListener('click', cerrarModalDetalle);
  document.getElementById('btn-cerrar-detalle-eliminacion-2')?.addEventListener('click', cerrarModalDetalle);
}

export async function cargarEliminaciones() {
  if (!getState().user) return;

  const tbody = document.getElementById('elim-tabla');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="8" class="empty">Cargando...</td></tr>';

  try {
    const res = await fetchEliminaciones({ page: pagina, filters: filtros });
    total = res.count;
    pageSize = res.pageSize;
    render(res.eliminaciones);
    renderPaginacion();
  } catch (err) {
    tbody.innerHTML = `<tr><td colspan="8" class="empty">${escapeHtml(err.message)}</td></tr>`;
    mostrarToast(err.message, 'error');
  }
}

/** Resumen legible de lo borrado, distinto según el tipo. */
function descripcion(row) {
  if (row.tabla_origen === 'production_movements') {
    const partes = [];
    if (row.talla) partes.push(`Talla ${row.talla}`);
    if (row.cantidad != null) partes.push(`${row.cantidad} und`);
    if (row.proceso) partes.push(row.proceso);
    return partes.join(' · ') || '—';
  }
  if (row.tabla_origen === 'despachos') {
    const o = row.num_ordenes ?? 0;
    const b = row.num_bultos ?? 0;
    return `${o} orden${o === 1 ? '' : 'es'} · ${b} bulto${b === 1 ? '' : 's'}`;
  }
  return '—';
}

function badgeTipo(tablaOrigen) {
  const esDespacho = tablaOrigen === 'despachos';
  const bg = esDespacho ? 'var(--amber-bg)' : 'var(--purple-bg)';
  const color = esDespacho ? 'var(--amber-text)' : 'var(--purple-text)';
  const texto = TIPOS[tablaOrigen] || tablaOrigen;
  return `<span style="background:${bg}; color:${color}; padding:3px 10px; border-radius:5px; font-size:12px; font-weight:600; display:inline-block;">${escapeHtml(texto)}</span>`;
}

function render(filas) {
  const tbody = document.getElementById('elim-tabla');

  if (filas.length === 0) {
    tbody.innerHTML = '<tr><td colspan="8" class="empty">No hay eliminaciones registradas.</td></tr>';
    return;
  }

  // El snapshot no se mete en el DOM (puede ser grande y llevar comillas):
  // se guarda aparte y el botón solo referencia el id.
  snapshotsPorId = new Map(filas.map((f) => [f.id, f]));

  const celda = 'padding:0.5rem; border-bottom:1px solid var(--border2); font-size:13px;';

  tbody.innerHTML = filas
    .map((row) => `
      <tr>
        <td style="${celda}">${formatearFechaHora(row.eliminado_en)}</td>
        <td style="${celda}">${escapeHtml(row.usuario_nombre || '—')}</td>
        <td style="${celda}">${escapeHtml(row.usuario_rol || '—')}</td>
        <td style="${celda}">${badgeTipo(row.tabla_origen)}</td>
        <td style="${celda}"><strong>${escapeHtml(row.referencia || '—')}</strong></td>
        <td style="${celda}">${escapeHtml(descripcion(row))}</td>
        <td style="${celda}">${escapeHtml(row.motivo || '—')}</td>
        <td style="${celda}"><button class="btn btn-secondary btn-sm" data-ver="${escapeHtml(row.id)}">Ver</button></td>
      </tr>
    `)
    .join('');

  tbody.querySelectorAll('[data-ver]').forEach((btn) => {
    btn.addEventListener('click', () => abrirModalDetalle(btn.dataset.ver));
  });
}

function renderPaginacion() {
  const el = document.getElementById('elim-paginacion');
  const totalPaginas = Math.max(Math.ceil(total / pageSize), 1);

  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="elim-pag-prev" ${pagina === 0 ? 'disabled' : ''}>← Anterior</button>
    <span>Página ${pagina + 1} de ${totalPaginas} · ${total} eliminación${total === 1 ? '' : 'es'}</span>
    <button class="btn btn-secondary btn-sm" id="elim-pag-next" ${pagina + 1 >= totalPaginas ? 'disabled' : ''}>Siguiente →</button>
  `;

  document.getElementById('elim-pag-prev')?.addEventListener('click', () => {
    pagina = Math.max(pagina - 1, 0);
    cargarEliminaciones();
  });
  document.getElementById('elim-pag-next')?.addEventListener('click', () => {
    pagina += 1;
    cargarEliminaciones();
  });
}

// ---------------------------------------------------------------------
// Modal: copia completa de lo eliminado
// ---------------------------------------------------------------------

function abrirModalDetalle(id) {
  const row = snapshotsPorId.get(id);
  if (!row) return;

  document.getElementById('detalle-eliminacion-titulo').textContent =
    `${TIPOS[row.tabla_origen] || row.tabla_origen} eliminado — ${row.referencia || ''}`;

  const json = JSON.stringify(row.snapshot, null, 2);

  document.getElementById('detalle-eliminacion-contenido').innerHTML = `
    <div class="form-group">
      <label>Eliminado por</label>
      <div>${escapeHtml(row.usuario_nombre || '—')} (${escapeHtml(row.usuario_rol || '—')}) · ${formatearFechaHora(row.eliminado_en)}</div>
    </div>
    <div class="form-group">
      <label>Motivo</label>
      <div>${escapeHtml(row.motivo || '—')}</div>
    </div>
    <div class="form-group">
      <label>Copia exacta de lo eliminado</label>
      <pre style="background:var(--bg); border:1px solid var(--border); border-radius:var(--r); padding:12px; font-size:12px; max-height:340px; overflow:auto; white-space:pre-wrap; word-break:break-word;">${escapeHtml(json)}</pre>
    </div>
  `;

  document.getElementById('modal-detalle-eliminacion').classList.add('open');
}

function cerrarModalDetalle() {
  document.getElementById('modal-detalle-eliminacion').classList.remove('open');
}

// ---------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------

function formatearFechaHora(valor) {
  if (!valor) return '—';
  try {
    const d = new Date(valor);
    return `${d.toLocaleDateString('es-CO')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
  } catch {
    return String(valor);
  }
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
