import {
  fetchCambiosPanel, fetchEstadoDetector, fetchCamposAplicables, revertirCambioErp
} from '../services/cambiosErpService.js';
import {
  ETIQUETA_TIPO, ETIQUETA_ESTADO, descripcionCambio, contadoresPanel, estadoDetector, formatearValor,
  formatearDia, puedeDeshacer, textoCamposEncendidos
} from '../lib/cambiosErp.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { esValidador } from '../services/validatorService.js';
import { mostrarToast } from './toast.js';

/**
 * Pestaña "Cambios ERP" (solo Validador): lista las diferencias que el
 * detector encontró entre Access y el programa. Fase 1: solo se muestran.
 * Fase 2: los campos de TEXTO cuyo interruptor esté encendido (Supabase,
 * erp_cambios_estado.aplicar_campos) se aplican solos y aquí se pueden
 * DESHACER; los demás tipos siguen sin aplicarse.
 */

const ESTILO_INPUT = 'padding:8px 12px;border:1.5px solid var(--border2);border-radius:var(--r);font-size:13px;';
const PAGE_SIZE = 50;

let todos = [];
let filtros = { estado: 'pendiente', tipo: '', orden: '' };
let pagina = 0;
let estado = null;
let camposAplicables = null; // campos encendidos; [] = todo apagado; null = no se pudo leer
let cargaActual = 0;

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

function fechaHora(valor) {
  if (!valor) return '—';
  const d = new Date(valor);
  return Number.isNaN(d.getTime()) ? '—' : d.toLocaleString('es', { dateStyle: 'short', timeStyle: 'short' });
}

export async function cargarCambiosErpPage() {
  const contenedor = document.getElementById('page-cambios-erp');
  if (!contenedor || !esValidador()) return;

  const opcionesTipo = Object.entries(ETIQUETA_TIPO)
    .map(([k, v]) => `<option value="${k}">${escapeHtml(v)}</option>`).join('');

  contenedor.innerHTML = `
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.75rem;">
        <h2>🔀 Cambios ERP — diferencias entre Access y el programa</h2>
        <button id="btn-refrescar-cambios-erp" class="btn btn-secondary btn-sm">🔄 Refrescar</button>
      </div>
      <div style="font-size:12px; color:var(--text2); margin-bottom:0.5rem;">
        Aquí se listan los datos que en Access cambiaron después de cargar el pedido. <strong>Los datos de texto cuyo campo
        esté encendido (ver abajo) se aplican solos cuando se ven iguales en 2 revisiones seguidas y se pueden deshacer aquí.
        Todo lo demás, por ahora, solo se muestra: no se modifica ningún pedido.</strong>
      </div>
      <div id="cambios-erp-estado" style="font-size:12px; margin-bottom:0.75rem;"></div>
      <div id="cambios-erp-contadores" style="display:flex; gap:8px; flex-wrap:wrap; margin-bottom:0.75rem;"></div>
      <div style="display:grid; grid-template-columns:90px 190px 1.2fr; gap:0.75rem; margin-bottom:1rem;">
        <input type="text" id="cambios-erp-filtro-orden" placeholder="No. Orden" maxlength="4" style="${ESTILO_INPUT}">
        <select id="cambios-erp-filtro-estado" style="${ESTILO_INPUT}">
          <option value="pendiente">Pendientes</option>
          <option value="aplicado">Aplicados</option>
          <option value="rechazado">Deshechos</option>
          <option value="resuelto">Resueltos (historial)</option>
          <option value="">Todos</option>
        </select>
        <select id="cambios-erp-filtro-tipo" style="${ESTILO_INPUT}">
          <option value="">Todos los tipos</option>${opcionesTipo}
        </select>
      </div>
      <div style="overflow-x:auto;"><div id="cambios-erp-tabla"></div></div>
      <div style="margin-top:1rem; display:flex; gap:0.5rem; justify-content:center;">
        <button id="cambios-erp-prev" class="btn btn-secondary btn-sm">← Anterior</button>
        <span id="cambios-erp-pag-info" style="display:flex; align-items:center;">Página 1</span>
        <button id="cambios-erp-next" class="btn btn-secondary btn-sm">Siguiente →</button>
      </div>
    </div>
  `;

  filtros = { estado: 'pendiente', tipo: '', orden: '' };
  pagina = 0;

  document.getElementById('btn-refrescar-cambios-erp')?.addEventListener('click', () => recargar());
  document.getElementById('cambios-erp-filtro-estado')?.addEventListener('change', (e) => {
    filtros.estado = e.target.value; pagina = 0; pintar();
  });
  document.getElementById('cambios-erp-filtro-tipo')?.addEventListener('change', (e) => {
    filtros.tipo = e.target.value; pagina = 0; pintar();
  });
  let debounce = null;
  document.getElementById('cambios-erp-filtro-orden')?.addEventListener('input', (e) => {
    clearTimeout(debounce);
    debounce = setTimeout(() => { filtros.orden = e.target.value.trim(); pagina = 0; pintar(); }, 300);
  });
  document.getElementById('cambios-erp-prev')?.addEventListener('click', () => {
    if (pagina > 0) { pagina -= 1; pintar(); }
  });
  document.getElementById('cambios-erp-next')?.addEventListener('click', () => {
    pagina += 1; pintar();
  });
  document.getElementById('cambios-erp-tabla')?.addEventListener('click', async (e) => {
    const deshacer = e.target.closest('[data-deshacer]');
    if (deshacer) {
      await deshacerCambio(deshacer);
      return;
    }
    const enlace = e.target.closest('[data-abrir-orden]');
    if (!enlace) return;
    e.preventDefault();
    abrirDetalleOrden(enlace.dataset.abrirOrden);
  });

  await recargar();
}

async function recargar() {
  const miCarga = ++cargaActual;
  const tabla = document.getElementById('cambios-erp-tabla');
  if (tabla) tabla.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando...</div>';
  const [filas, est, campos] = await Promise.all([
    fetchCambiosPanel(), fetchEstadoDetector(), fetchCamposAplicables()
  ]);
  if (miCarga !== cargaActual) return; // llegó una respuesta vieja
  todos = filas || [];
  estado = est;
  camposAplicables = campos;
  pintar(filas === null);
}

/** Botón "Deshacer": pide confirmación y restaura el cliente anterior. */
async function deshacerCambio(boton) {
  const id = Number(boton.dataset.deshacer);
  const pedido = boton.dataset.pedido;
  if (!Number.isFinite(id)) return;
  const ok = window.confirm(
    `¿Deshacer este cambio del pedido ${pedido}?\n\n`
    + 'Se restaura el valor anterior y el programa no lo volverá a cambiar '
    + 'mientras Access no lo modifique otra vez.'
  );
  if (!ok) return;
  boton.disabled = true;
  try {
    await revertirCambioErp(id);
    mostrarToast(`Cambio del pedido ${pedido} deshecho.`, 'ok');
    await recargar();
  } catch (err) {
    boton.disabled = false;
    mostrarToast(err.message || 'No se pudo deshacer el cambio.', 'error');
  }
}

function pintarEstado() {
  const el = document.getElementById('cambios-erp-estado');
  if (!el) return;
  const info = estadoDetector(estado);
  const base = 'Detector de cambios: ';
  const encendidos = textoCamposEncendidos(camposAplicables);
  const interruptor = encendidos === null
    ? ''
    : ` · Aplicación automática de: <strong>${encendidos === 'ninguno' ? 'APAGADA (ningún campo)' : escapeHtml(encendidos)}</strong>`;
  if (info.nivel === 'ok') {
    el.style.cssText = 'font-size:12px; margin-bottom:0.75rem; color:var(--text3);';
    el.innerHTML = `${base}<strong style="color:var(--green-text);">${escapeHtml(info.texto)}</strong>${interruptor}`;
  } else {
    const alerta = info.nivel === 'alerta';
    el.style.cssText = `font-size:12px; margin-bottom:0.75rem; padding:6px 10px; border-radius:var(--r); background:var(--${alerta ? 'red' : 'amber'}-bg); color:var(--${alerta ? 'red' : 'amber'}-text);`;
    el.innerHTML = `${alerta ? '⚠ ' : ''}${base}<strong>${escapeHtml(info.texto)}</strong>${interruptor}`;
  }
}

function pintarContadores() {
  const el = document.getElementById('cambios-erp-contadores');
  if (!el) return;
  const c = contadoresPanel(todos);
  const chip = (texto, fuerte) => `<span style="background:var(--bg); border:1px solid var(--border2); padding:3px 10px; border-radius:5px; font-size:12px;">${fuerte ? `<strong>${texto}</strong>` : texto}</span>`;
  const partes = [
    chip(`${c.pendientes} pendiente${c.pendientes === 1 ? '' : 's'} en ${c.pedidos} pedido${c.pedidos === 1 ? '' : 's'}`, true),
    ...Object.entries(c.porTipo).map(([t, n]) => chip(`${escapeHtml(ETIQUETA_TIPO[t] || t)}: ${n}`)),
    chip(`${c.aplicados} aplicado${c.aplicados === 1 ? '' : 's'}`),
    chip(`${c.resueltos} resuelto${c.resueltos === 1 ? '' : 's'}`)
  ];
  el.innerHTML = partes.join('');
}

function filtrar() {
  return todos.filter((c) =>
    (!filtros.estado || c.estado === filtros.estado)
    && (!filtros.tipo || c.tipo === filtros.tipo)
    && (!filtros.orden || String(c.pedido).includes(filtros.orden)));
}

function pintar(errorDeCarga = false) {
  pintarEstado();
  pintarContadores();
  const tabla = document.getElementById('cambios-erp-tabla');
  if (!tabla) return;

  if (errorDeCarga) {
    tabla.innerHTML = '<div class="empty">No se pudieron cargar los cambios. Intente refrescar.</div>';
    return;
  }

  const filas = filtrar();
  const totalPaginas = Math.max(1, Math.ceil(filas.length / PAGE_SIZE));
  if (pagina >= totalPaginas) pagina = totalPaginas - 1;
  const visibles = filas.slice(pagina * PAGE_SIZE, (pagina + 1) * PAGE_SIZE);

  document.getElementById('cambios-erp-pag-info').textContent = `Página ${pagina + 1} de ${totalPaginas} · ${filas.length} registro${filas.length === 1 ? '' : 's'}`;
  document.getElementById('cambios-erp-prev').disabled = pagina === 0;
  document.getElementById('cambios-erp-next').disabled = pagina >= totalPaginas - 1;

  if (visibles.length === 0) {
    tabla.innerHTML = '<div class="empty">No hay cambios para mostrar.</div>';
    return;
  }

  tabla.innerHTML = `
    <table style="width:100%; border-collapse:collapse; font-size:12px;">
      <thead>
        <tr style="background:var(--bg); border-bottom:2px solid var(--border);">
          <th style="padding:8px; text-align:left;">Orden</th>
          <th style="padding:8px; text-align:left;">Talla</th>
          <th style="padding:8px; text-align:left;">Tipo</th>
          <th style="padding:8px; text-align:left;">Qué cambió</th>
          <th style="padding:8px; text-align:left;">En Access</th>
          <th style="padding:8px; text-align:left;">En el programa</th>
          <th style="padding:8px; text-align:center;" title="Registros de producción hechos por personas (sin los automáticos) en todo el pedido. Si es mayor que 0, el pedido ya tiene unidades procesadas.">Movim.</th>
          <th style="padding:8px; text-align:center;" title="Despachos del pedido">Desp.</th>
          <th style="padding:8px; text-align:left;">Estado</th>
          <th style="padding:8px; text-align:left;">Detectado</th>
          <th style="padding:8px; text-align:center;" title="Revisiones seguidas en que la diferencia se vio igual">Rev.</th>
          <th style="padding:8px; text-align:center;"></th>
        </tr>
      </thead>
      <tbody>
        ${visibles.map((c) => {
          const esCancel = c.tipo === 'cancelado' || c.tipo === 'cancelado_parcial';
          const enAccess = esCancel ? 'Cancelado' : formatearValor(c.campo, c.valor_access);
          const enPrograma = esCancel ? 'Activo' : formatearValor(c.campo, c.valor_programa);
          const ambiguo = c.ambiguo ? ' <span title="El detector no pudo emparejar con certeza las líneas de esta talla" style="color:var(--amber-text);">⚠ ambiguo</span>' : '';
          const resuelto = c.estado === 'resuelto';
          return `
          <tr style="border-bottom:1px solid var(--border); ${resuelto ? 'color:var(--text3);' : ''}">
            <td style="padding:8px;"><a href="#" data-abrir-orden="${escapeHtml(c.pedido)}" style="font-weight:700;">${escapeHtml(c.pedido)}</a></td>
            <td style="padding:8px;">${escapeHtml(c.talla || '—')}</td>
            <td style="padding:8px;">${escapeHtml(ETIQUETA_TIPO[c.tipo] || c.tipo)}</td>
            <td style="padding:8px;">${escapeHtml(descripcionCambio(c))}${ambiguo}</td>
            <td style="padding:8px;">${escapeHtml(enAccess)}</td>
            <td style="padding:8px;">${escapeHtml(enPrograma)}</td>
            <td style="padding:8px; text-align:center;">${Number(c.contexto?.movimientos || 0)}</td>
            <td style="padding:8px; text-align:center;">${Number(c.contexto?.despachos || 0)}</td>
            <td style="padding:8px;">${escapeHtml(ETIQUETA_ESTADO[c.estado] || c.estado)}${c.estado === 'aplicado' ? `<div style="font-size:11px; color:var(--text3);">el ${escapeHtml(formatearDia(c.aplicado_at))}</div>` : ''}</td>
            <td style="padding:8px; white-space:nowrap;">${escapeHtml(fechaHora(c.detectado_at))}</td>
            <td style="padding:8px; text-align:center;">${Number(c.revisiones_consecutivas || 0)}</td>
            <td style="padding:8px; text-align:center;">${puedeDeshacer(c) ? `<button class="btn btn-secondary btn-sm" data-deshacer="${Number(c.id)}" data-pedido="${escapeHtml(c.pedido)}" title="Restaura el valor anterior">Deshacer</button>` : ''}</td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>
  `;
}
