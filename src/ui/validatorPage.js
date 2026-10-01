import { supabase } from '../config/supabaseClient.js';
import { formatearFechaPedido } from '../lib/fechas.js';
import { mostrarToast } from './toast.js';
import { fetchOpcionesCliente, fetchOpcionesNombreSuela, fetchOpcionesMaterial, fetchOpcionesColor } from '../services/ordersService.js';
import { construirMapaUltimaFechaPorProceso, calcularDiasPorProceso } from '../lib/procesoDias.js';

let paginaActual = 0;
const PAGE_SIZE = 50;
let hayPaginaSiguiente = false;
let filtros = { orden: '', cliente: '', nombreSuela: '', material: '', color: '', fecha: '' };

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
  await cargarValidador();
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

  renderTablaValidador(ordenes, mapaUltimaFecha);
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

function renderTablaValidador(ordenes, mapaUltimaFecha) {
  const tabla = document.getElementById('validador-tabla');

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
          <th style="padding: 8px; text-align: center;" title="Refilado %">R%</th>
          <th style="padding: 8px; text-align: center;" title="Acabado %">A%</th>
          <th style="padding: 8px; text-align: center;" title="Mateado %">M%</th>
          <th style="padding: 8px; text-align: center;" title="Empaque %">E%</th>
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
            <td style="padding: 8px; text-align: center;">
              <span style="background: var(--blue-bg); color: var(--blue); padding: 2px 6px; border-radius: 3px;">
                ${o.porcentaje_refilado || 0}%
              </span>
            </td>
            <td style="padding: 8px; text-align: center;">
              <span style="background: var(--green-bg); color: var(--green-text); padding: 2px 6px; border-radius: 3px;">
                ${o.porcentaje_acabado || 0}%
              </span>
            </td>
            <td style="padding: 8px; text-align: center;">
              <span style="background: var(--purple-bg); color: var(--purple-text); padding: 2px 6px; border-radius: 3px;">
                ${o.porcentaje_mateado || 0}%
              </span>
            </td>
            <td style="padding: 8px; text-align: center;">
              <span style="background: var(--amber-bg); color: var(--amber-text); padding: 2px 6px; border-radius: 3px;">
                ${o.porcentaje_empaque || 0}%
              </span>
            </td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dRefilado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dAcabado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dMateado)}</td>
            <td style="padding: 8px; text-align: center;">${celdaDias(dias.dEmpaque)}</td>
            <td style="padding: 8px; text-align: center;"><strong>${o.dias_orden ?? 0}</strong></td>
            <td style="padding: 8px; text-align: center;">${badgeEtapa(o.etapa_actual)}</td>
            <td style="padding: 8px; text-align: center;">
              <span class="estado-badge estado-${o.estatus_general === 'Completado' ? 'completado' : 'en-proceso'}">
                ${o.estatus_general}
              </span>
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
