import { supabase } from '../config/supabaseClient.js';
import { formatearFechaPedido } from '../lib/fechas.js';
import { mostrarToast } from './toast.js';
import { fetchOpcionesCliente, fetchOpcionesNombreSuela, fetchOpcionesMaterial, fetchOpcionesColor } from '../services/ordersService.js';
import { construirMapaUltimaFechaPorProceso, calcularDiasPorProceso } from '../lib/procesoDias.js';
import { esValidador } from '../services/validatorService.js';
import { getState } from '../state/appState.js';
import { fetchInyectadoPorPedidos, fetchEstadoSincronizacion } from '../services/inyeccionService.js';
import { aplicaInyeccion, porcentajeInyectado, estadoSincronizacion } from '../lib/inyeccion.js';

// Estado de la sincronización del Total Inyectado (solo Validador). Se refresca
// con cada carga de la tabla y, mientras la pantalla esté abierta, cada minuto.
let estadoInyeccion = null;
let temporizadorInyeccion = null;
const MS_REFRESCO_ESTADO = 60 * 1000;

let paginaActual = 0;
const PAGE_SIZE = 50;
let hayPaginaSiguiente = false;
let filtros = { orden: '', cliente: '', nombreSuela: '', material: '', color: '', fecha: '' };

/** Rol real Empaque (no el emulado por el Validador, que ya tiene todo). */
function esEmpaque() {
  return getState().user?.role === 'empaque';
}

const ESTILO_INPUT = 'padding:8px 12px;border:1.5px solid var(--border2);border-radius:var(--r);font-size:13px;';

export async function cargarValidadorPage() {
  const contenedor = document.getElementById('page-validador');
  if (!contenedor) return;

  contenedor.innerHTML = `
    <div class="card">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1rem;">
        <h2>🔍 Control Central — Estado Completo de Órdenes</h2>
        <button id="btn-refrescar-validador" class="btn btn-secondary btn-sm">🔄 Refrescar</button>
      </div>

      <div id="validador-filtros" style="display:grid;grid-template-columns:80px 1.2fr 1.2fr 1fr 1fr 150px;gap:0.75rem;margin-bottom:1rem;">
        <input type="text" id="validador-filtro-orden" placeholder="No. Orden" maxlength="4" style="${ESTILO_INPUT}">
        <select id="validador-filtro-cliente" style="${ESTILO_INPUT}">
          <option value="">Cliente...</option>
        </select>
        <select id="validador-filtro-nombre-suela" style="${ESTILO_INPUT}">
          <option value="">Nombre Suela...</option>
        </select>
        <select id="validador-filtro-material" style="${ESTILO_INPUT}">
          <option value="">Material...</option>
        </select>
        <select id="validador-filtro-color" style="${ESTILO_INPUT}">
          <option value="">Color...</option>
        </select>
        <input type="date" id="validador-filtro-fecha" style="${ESTILO_INPUT}">
      </div>

      ${esValidador()
        ? '<div id="validador-nota-inyeccion" style="font-size:11px; color:var(--text3); margin:-0.25rem 0 0.5rem;">I% = Inyección (ERP): pares inyectados | % de lo solicitado. Verificando actualización…</div>'
        : esEmpaque()
          ? '<div style="font-size:11px; color:var(--text3); margin:-0.25rem 0 0.5rem;">I% = Inyección (ERP): pares inyectados | % de lo solicitado.</div>'
          : ''}

      <div style="overflow-x: auto;">
        <div id="validador-tabla"></div>
      </div>

      <div style="margin-top: 1rem; display: flex; gap: 0.5rem; justify-content: center;">
        <button id="validador-pag-prev" class="btn btn-secondary btn-sm">← Anterior</button>
        <span id="validador-pag-info" style="display: flex; align-items: center;">Página 1</span>
        <button id="validador-pag-next" class="btn btn-secondary btn-sm">Siguiente →</button>
      </div>
    </div>
  `;

  document.getElementById('btn-refrescar-validador')?.addEventListener('click', () => cargarValidador());

  const FILTRO_ID_A_CLAVE = {
    'validador-filtro-orden': 'orden',
    'validador-filtro-cliente': 'cliente',
    'validador-filtro-nombre-suela': 'nombreSuela',
    'validador-filtro-material': 'material',
    'validador-filtro-color': 'color',
    'validador-filtro-fecha': 'fecha'
  };

  let debounceTimer = null;
  Object.keys(FILTRO_ID_A_CLAVE).forEach((id) => {
    const el = document.getElementById(id);
    if (!el) return;

    if (el.tagName === 'SELECT') {
      el.addEventListener('change', () => {
        filtros[FILTRO_ID_A_CLAVE[id]] = el.value;
        paginaActual = 0;
        cargarValidador();
      });
    } else {
      el.addEventListener('input', () => {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          filtros[FILTRO_ID_A_CLAVE[id]] = el.value.trim();
          paginaActual = 0;
          cargarValidador();
        }, 350);
      });
    }
  });

  document.getElementById('validador-pag-prev')?.addEventListener('click', () => {
    if (paginaActual > 0) {
      paginaActual--;
      cargarValidador();
    }
  });
  document.getElementById('validador-pag-next')?.addEventListener('click', () => {
    if (hayPaginaSiguiente) {
      paginaActual++;
      cargarValidador();
    }
  });

  poblarFiltrosDropdown();
  iniciarTemporizadorInyeccion();
  await cargarValidador();
}

/**
 * Pinta el rótulo de Inyección según el estado de la sincronización: al día
 * ("Actualizado hace 3 min"), en falla (pausada, detenida o sin actualizar
 * hace más de 15 min) o "no se pudo verificar". No hace nada si la nota no
 * está en pantalla (cualquier usuario que no sea Validador).
 */
function pintarNotaInyeccion() {
  const nota = document.getElementById('validador-nota-inyeccion');
  if (!nota) return false;

  const info = estadoSincronizacion(estadoInyeccion);
  const base = 'I% = Inyección (ERP): pares inyectados | % de lo solicitado.';

  if (info.nivel === 'ok') {
    nota.style.cssText = 'font-size:11px; color:var(--text3); margin:-0.25rem 0 0.5rem;';
    nota.innerHTML = `${base} <strong style="color:var(--green-text);">${escapeHtml(info.texto)}</strong>`;
  } else {
    const alerta = info.nivel === 'alerta';
    nota.style.cssText = [
      'font-size:12px', 'margin:0 0 0.75rem', 'padding:6px 10px', 'border-radius:var(--r)',
      `background:var(--${alerta ? 'red' : 'amber'}-bg)`,
      `color:var(--${alerta ? 'red' : 'amber'}-text)`
    ].join('; ') + ';';
    nota.innerHTML = `${alerta ? '⚠ ' : ''}${base} <strong>${escapeHtml(info.texto)}</strong>`;
  }
  return true;
}

async function actualizarEstadoInyeccion() {
  if (!esValidador()) return;
  estadoInyeccion = await fetchEstadoSincronizacion();
  pintarNotaInyeccion();
}

/**
 * Mantiene el "hace X min" al día mientras la pantalla siga abierta (sin
 * esto diría "hace 3 min" para siempre). Consulta una sola fila, solo si la
 * pestaña se está viendo, y se apaga sola cuando la nota deja de existir.
 */
function iniciarTemporizadorInyeccion() {
  if (temporizadorInyeccion) {
    clearInterval(temporizadorInyeccion);
    temporizadorInyeccion = null;
  }
  if (!esValidador()) return;

  temporizadorInyeccion = setInterval(async () => {
    const nota = document.getElementById('validador-nota-inyeccion');
    if (!nota) {
      clearInterval(temporizadorInyeccion);
      temporizadorInyeccion = null;
      return;
    }
    if (nota.offsetParent === null) return; // pestaña oculta: no se consulta
    await actualizarEstadoInyeccion();
  }, MS_REFRESCO_ESTADO);
}

/**
 * Mismos dropdowns (valores DISTINCT en vivo desde la BD) que usa el
 * listado normal de Órdenes — ver poblarFiltrosDropdown() en dashboard.js.
 */
async function poblarFiltrosDropdown() {
  const rellenar = (id, valores) => {
    const select = document.getElementById(id);
    if (!select) return;
    valores.forEach((valor) => {
      const option = document.createElement('option');
      option.value = valor;
      option.textContent = valor;
      select.appendChild(option);
    });
  };

  try {
    const [clientes, nombresSuela, materiales, colores] = await Promise.all([
      fetchOpcionesCliente(),
      fetchOpcionesNombreSuela(),
      fetchOpcionesMaterial(),
      fetchOpcionesColor()
    ]);
    rellenar('validador-filtro-cliente', clientes);
    rellenar('validador-filtro-nombre-suela', nombresSuela);
    rellenar('validador-filtro-material', materiales);
    rellenar('validador-filtro-color', colores);
  } catch (err) {
    console.error('[validadorPage] Error cargando opciones de filtros:', err);
  }
}

/**
 * Refresco liviano (solo los datos, sin reconstruir los inputs de
 * filtro) — usado por realtime cuando la pestaña Control Central ya
 * está inicializada. cargarValidadorPage() reconstruye todo el HTML,
 * lo que borraría lo que el usuario esté escribiendo en los filtros.
 */
export async function refrescarValidadorSiVisible() {
  if (!document.getElementById('validador-tabla')) return;
  await cargarValidador();
}

async function cargarValidador() {
  let query = supabase
    .from('vw_pedido_progreso')
    .select('*')
    .order('order_number', { ascending: false });

  if (filtros.orden.trim()) {
    query = query.ilike('order_number', `%${filtros.orden.trim()}%`);
  }
  if (filtros.cliente) {
    query = query.eq('cliente', filtros.cliente);
  }
  if (filtros.nombreSuela) {
    query = query.eq('nombre_referencia', filtros.nombreSuela);
  }
  if (filtros.material) {
    query = query.eq('material', filtros.material);
  }
  if (filtros.color) {
    query = query.eq('color', filtros.color);
  }
  if (filtros.fecha) {
    query = query.eq('fecha_pedido', filtros.fecha);
  }

  const { data, error } = await query.range(
    paginaActual * PAGE_SIZE,
    paginaActual * PAGE_SIZE + PAGE_SIZE
  );

  if (error) {
    console.error('[validadorPage] Error:', error);
    mostrarToast('Error cargando órdenes', 'error');
    return;
  }

  hayPaginaSiguiente = data?.length > PAGE_SIZE;
  const ordenes = (data || []).slice(0, PAGE_SIZE);

  // Movimientos SOLO de las órdenes visibles en esta página, necesarios
  // para calcular D_Refilado/Acabado/Mateado/Empaque (misma lógica que
  // el Excel, ver src/lib/procesoDias.js).
  const numerosOrden = ordenes.map((o) => o.order_number);
  let mapaUltimaFecha = {};
  if (numerosOrden.length > 0) {
    const { data: movimientos, error: errorMov } = await supabase
      .from('production_movements')
      .select('order_number, from_process, created_at, observation')
      .in('order_number', numerosOrden);

    if (errorMov) {
      console.error('[validadorPage] Error obteniendo movimientos para días:', errorMov);
    } else {
      mapaUltimaFecha = construirMapaUltimaFechaPorProceso(movimientos || []);
    }
  }

  // Inyección (ERP): dato informativo de Access, solo para el Validador.
  // undefined = la columna no se muestra; null = la consulta falló ("—").
  // Empaque ve la misma columna; el estado de la sincronización (rótulo
  // "Actualizado hace X min") sigue siendo solo del Validador (RLS).
  let inyeccion;
  if (esValidador()) {
    [inyeccion] = await Promise.all([fetchInyectadoPorPedidos(numerosOrden), actualizarEstadoInyeccion()]);
  } else if (esEmpaque()) {
    inyeccion = await fetchInyectadoPorPedidos(numerosOrden);
  }

  renderTablaValidador(ordenes, mapaUltimaFecha, inyeccion);
  renderPaginacionValidador();
}

/**
 * Mismo código de color que usa cada proceso en el resto de la app
 * (Refilado=azul, Acabado=verde, Mateado=morado, Empaque=ámbar), para
 * que la etapa se lea de un vistazo sin tener que leer la letra.
 */
function badgeEtapa(etapa) {
  const estilos = {
    R: { bg: 'var(--blue-bg)', color: 'var(--blue)' },
    A: { bg: 'var(--green-bg)', color: 'var(--green-text)' },
    M: { bg: 'var(--purple-bg)', color: 'var(--purple-text)' },
    E: { bg: 'var(--amber-bg)', color: 'var(--amber-text)' },
    Fin: { bg: 'var(--green-bg)', color: 'var(--green-text)' }
  };
  const s = estilos[etapa] || { bg: 'var(--bg)', color: 'var(--text2)' };
  return `<span style="background:${s.bg}; color:${s.color}; padding:3px 10px; border-radius:4px; font-weight:600;">${etapa || '—'}</span>`;
}

/**
 * Badge de Estado. Un pedido cerrado a la fuerza por el Validador (057)
 * conserva su estatus_general real (p. ej. "En Proceso", porque no se
 * completó), así que se muestra "Cerrada" para que no parezca abierto.
 */
function badgeEstado(o) {
  if (o.cierre_forzado) {
    const quien = o.cierre_forzado_por || 'el Validador';
    const motivo = o.cierre_forzado_motivo ? `: ${o.cierre_forzado_motivo}` : '';
    return `<span class="estado-badge estado-cerrada" title="${escapeHtml(`Cerrada a la fuerza por ${quien}${motivo}`)}">Cerrada</span>`;
  }
  return `<span class="estado-badge estado-${o.estatus_general === 'Completado' ? 'completado' : 'en-proceso'}">${o.estatus_general}</span>`;
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

/**
 * Badge de avance de un proceso: "pares | %". Los pares son los que ya
 * salieron de ese proceso (procesado_*, el mismo numerador del %). El % de
 * la vista llega topado en 100 pero los pares no, así que si un proceso
 * registró de más se ve el número real (ej. "105 | 100%").
 */
function badgeAvance(pares, porcentaje, bg, color, estiloExtra = '') {
  return `<span style="background: ${bg}; color: ${color}; padding: 2px 6px; border-radius: 3px; white-space: nowrap; ${estiloExtra}">${pares || 0} | ${porcentaje || 0}%</span>`;
}

/**
 * Celda de Inyección (ERP). Neutra y con borde punteado para que no se
 * confunda con un proceso de la cadena. "—" si el pedido es anterior al
 * 3095 o si la consulta falló.
 */
function celdaInyeccion(orden, inyeccion) {
  if (inyeccion === null || !aplicaInyeccion(orden.order_number)) {
    return '<span style="color: var(--text3);">—</span>';
  }
  const pares = inyeccion.get(String(orden.order_number)) ?? 0;
  return badgeAvance(pares, porcentajeInyectado(pares, orden.total_solicitado), 'var(--bg)', 'var(--text2)', 'border: 1px dashed var(--border2);');
}

/** Solo se usa para fecha_pedido (fecha de calendario a medianoche UTC): ver lib/fechas.js. */
function formatearFecha(fecha) {
  return formatearFechaPedido(fecha);
}

/** Celda de días: números tal cual, 'No'/'NA' en gris tenue. */
function celdaDias(valor) {
  if (valor === 'No' || valor === 'NA') {
    return `<span style="color: var(--text3);">${valor}</span>`;
  }
  return `<strong>${valor}</strong>`;
}

function renderTablaValidador(ordenes, mapaUltimaFecha, inyeccion) {
  const tabla = document.getElementById('validador-tabla');
  const verInyeccion = inyeccion !== undefined;

  if (ordenes.length === 0) {
    tabla.innerHTML = '<div class="empty">No hay órdenes para mostrar.</div>';
    return;
  }

  const html = `
    <table style="width: 100%; border-collapse: collapse; font-size: 12px;">
      <thead>
        <tr style="background: var(--bg); border-bottom: 2px solid var(--border);">
          <th style="padding: 8px; text-align: left;">Orden</th>
          <th style="padding: 8px; text-align: left;">Cliente</th>
          <th style="padding: 8px; text-align: left;">Nombre Suela</th>
          <th style="padding: 8px; text-align: left;">Material</th>
          <th style="padding: 8px; text-align: left;">Color</th>
          <th style="padding: 8px; text-align: left;">Fecha Pedido</th>
          <th style="padding: 8px; text-align: center;" title="Unidades (pares) totales del pedido">UNDS.</th>
          ${verInyeccion ? `<th style="padding: 8px; text-align: center;" title="Inyección (ERP): pares inyectados | % de lo solicitado.${esValidador() ? ` ${escapeHtml(estadoSincronizacion(estadoInyeccion).texto)}.` : ''}">I%</th>` : ''}
          <th style="padding: 8px; text-align: center;" title="Refilado: pares procesados | % de avance">R%</th>
          <th style="padding: 8px; text-align: center;" title="Acabado: pares procesados | % de avance">A%</th>
          <th style="padding: 8px; text-align: center;" title="Mateado: pares procesados | % de avance">M%</th>
          <th style="padding: 8px; text-align: center;" title="Empaque: pares procesados | % de avance">E%</th>
          <th style="padding: 8px; text-align: center;" title="Días Refilado">D.R</th>
          <th style="padding: 8px; text-align: center;" title="Días Acabado">D.A</th>
          <th style="padding: 8px; text-align: center;" title="Días Mateado">D.M</th>
          <th style="padding: 8px; text-align: center;" title="Días Empaque">D.E</th>
          <th style="padding: 8px; text-align: center;" title="Días Orden (total)">D.O</th>
          <th style="padding: 8px; text-align: center;">Etapa</th>
          <th style="padding: 8px; text-align: center;">Estado</th>
        </tr>
      </thead>
      <tbody>
        ${ordenes.map((o) => {
          const dias = calcularDiasPorProceso(o, mapaUltimaFecha);
          return `
          <tr style="border-bottom: 1px solid var(--border);">
            <td style="padding: 8px;"><strong>${o.order_number}</strong></td>
            <td style="padding: 8px;">${o.cliente || '—'}</td>
            <td style="padding: 8px;">${o.nombre_referencia || '—'}</td>
            <td style="padding: 8px;">${o.material || '—'}</td>
            <td style="padding: 8px;">${o.color || '—'}</td>
            <td style="padding: 8px;">${formatearFecha(o.fecha_pedido)}</td>
            <td style="padding: 8px; text-align: center;"><strong>${o.total_solicitado ?? 0}</strong></td>
            ${verInyeccion ? `<td style="padding: 8px; text-align: center;">${celdaInyeccion(o, inyeccion)}</td>` : ''}
            <td style="padding: 8px; text-align: center;">${badgeAvance(o.procesado_refilado, o.porcentaje_refilado, 'var(--blue-bg)', 'var(--blue)')}</td>
            <td style="padding: 8px; text-align: center;">${badgeAvance(o.procesado_acabado, o.porcentaje_acabado, 'var(--green-bg)', 'var(--green-text)')}</td>
            <td style="padding: 8px; text-align: center;">${badgeAvance(o.procesado_mateado, o.porcentaje_mateado, 'var(--purple-bg)', 'var(--purple-text)')}</td>
            <td style="padding: 8px; text-align: center;">${badgeAvance(o.procesado_empaque, o.porcentaje_empaque, 'var(--amber-bg)', 'var(--amber-text)')}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dRefilado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dAcabado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dMateado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dEmpaque)}</td>
            <td style="padding: 8px; text-align: center;"><strong>${o.dias_orden ?? 0}</strong></td>
            <td style="padding: 8px; text-align: center;">${badgeEtapa(o.etapa_actual)}</td>
            <td style="padding: 8px; text-align: center;">
              ${badgeEstado(o)}
            </td>
          </tr>
        `;
        }).join('')}
      </tbody>
    </table>
  `;

  tabla.innerHTML = html;
}

function renderPaginacionValidador() {
  const el = document.getElementById('validador-pag-info');
  el.textContent = `Página ${paginaActual + 1}`;
  document.getElementById('validador-pag-prev').disabled = paginaActual === 0;
  document.getElementById('validador-pag-next').disabled = !hayPaginaSiguiente;
}
