import { getState } from '../state/appState.js';
import { destinosDashboardProceso, esRolDashboardProceso, ICONO_PROCESO } from '../lib/roles.js';
import {
  formatearCantidadEscrita, formatearHaceCuanto, formatearLlegadaArea,
  formatearPares, formatearUnidades, leerCantidad, tallasDePedido,
  detalleOrigen, etiquetaOrigen, textosPlanta
} from '../lib/dashboardProceso.js';
import {
  fetchPedidosDashboardProceso, enviarTallaDashboardProceso, procesoDeUsuario
} from '../services/dashboardProcesoService.js';
import { mostrarToast } from './toast.js';

/**
 * Dashboard operativo de Refilado / Acabado / Mateado.
 * Distinto del dashboard técnico del Validador (dashboardPage.js / 084).
 * Textos y layout pensados para planta: qué llegó, de dónde, cuánto falta,
 * y qué hay que escribir para enviar.
 */

const ESTILO = `
  .dash-proc-root { background:transparent; border:0; box-shadow:none; padding:0; }
  .dash-proc-top { display:flex; justify-content:space-between; align-items:center; gap:0.75rem; flex-wrap:wrap; margin-bottom:0.7rem; }
  .dash-proc-top h2 { font-size:22px; font-weight:800; letter-spacing:-0.02em; }
  .dash-proc-pasos { display:flex; flex-wrap:wrap; gap:0.4rem; margin-bottom:0.85rem; }
  .dash-proc-paso { display:flex; align-items:center; gap:0.45rem; background:var(--blue-bg); border:1px solid #bfdbfe; color:var(--text); font-size:13px; font-weight:600; padding:7px 12px; border-radius:999px; }
  .dash-proc-paso b { display:inline-flex; align-items:center; justify-content:center; width:1.35rem; height:1.35rem; border-radius:999px; background:var(--blue); color:#fff; font-size:12px; }
  .dash-proc-lista { display:grid; gap:1rem; }
  .dash-proc-card { background:var(--surface); border:1.5px solid var(--border); border-radius:14px; padding:0; box-shadow:var(--shadow); overflow:hidden; }
  .dash-proc-card.es-primero { border-color:#fbbf24; box-shadow:0 0 0 3px var(--amber-bg); }
  .dash-proc-badge { display:inline-block; font-size:12px; font-weight:700; color:var(--amber-text); background:var(--amber-bg); padding:4px 10px; border-radius:999px; margin-bottom:0.55rem; }
  .dash-proc-ruta { display:grid; grid-template-columns:1fr 1fr; gap:0.75rem 1rem; background:#f8fafc; border-bottom:1px solid var(--border); padding:12px 16px; }
  .dash-proc-ruta dt { font-size:11px; font-weight:700; color:var(--text2); text-transform:uppercase; letter-spacing:.04em; margin:0 0 2px; }
  .dash-proc-ruta dd { margin:0; font-size:16px; font-weight:800; color:var(--text); line-height:1.25; }
  .dash-proc-ruta .cuando { color:var(--amber-text); }
  .dash-proc-ruta small { display:block; font-size:12px; font-weight:600; color:var(--text2); margin-top:2px; }
  .dash-proc-cuerpo { padding:14px 16px 16px; }
  .dash-proc-suela { font-size:24px; font-weight:800; color:var(--text); line-height:1.15; }
  .dash-proc-chips { display:flex; flex-wrap:wrap; gap:0.4rem; margin-top:0.5rem; }
  .dash-proc-chip { font-size:14px; font-weight:700; background:var(--bg); border:1px solid var(--border); color:var(--text); padding:5px 11px; border-radius:999px; }
  .dash-proc-chip span { color:var(--text2); font-weight:600; margin-right:4px; }
  .dash-proc-nums { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:0.55rem; margin:0.9rem 0 1rem; }
  .dash-proc-num { background:var(--bg); border-radius:12px; padding:10px 12px; }
  .dash-proc-num span { display:block; font-size:13px; font-weight:700; color:var(--text2); }
  .dash-proc-num strong { display:block; font-size:28px; font-weight:800; color:var(--text); font-variant-numeric:tabular-nums; line-height:1.1; margin-top:2px; }
  .dash-proc-num em { display:block; font-style:normal; font-size:12px; font-weight:600; color:var(--text2); }
  .dash-proc-num.llegaron { background:var(--blue-bg); }
  .dash-proc-num.llegaron span { color:var(--blue); }
  .dash-proc-num.enviaste { background:var(--green-bg); }
  .dash-proc-num.enviaste span { color:var(--green-text); }
  .dash-proc-num.faltan { background:var(--amber-bg); outline:2px solid #fbbf24; }
  .dash-proc-num.faltan span, .dash-proc-num.faltan strong, .dash-proc-num.faltan em { color:var(--amber-text); }
  .dash-proc-hacer { font-size:13px; font-weight:800; color:var(--text2); text-transform:uppercase; letter-spacing:.04em; margin:0 0 0.55rem; }
  .dash-proc-tallas { display:grid; gap:0.7rem; }
  .dash-proc-talla { display:grid; grid-template-columns: minmax(8rem,auto) minmax(0,1fr) auto; align-items:end; gap:0.7rem 0.85rem; padding:14px; background:#fff; border:1.5px solid var(--border); border-radius:12px; }
  .dash-proc-talla-lbl { font-weight:800; font-size:22px; line-height:1.1; }
  .dash-proc-talla-pend { font-size:14px; color:var(--text2); margin-top:4px; }
  .dash-proc-talla-pend strong { color:var(--amber-text); font-size:16px; }
  .dash-proc-campo { display:flex; flex-direction:column; gap:4px; min-width:0; }
  .dash-proc-campo label { font-size:13px; font-weight:700; color:var(--text); }
  .dash-proc-qty-row { display:flex; gap:0.4rem; align-items:center; }
  .dash-proc-qty { width:100%; max-width:7.5rem; height:52px; padding:0 12px; border:2px solid var(--border2); border-radius:10px; font-size:22px; font-weight:800; font-family:inherit; text-align:center; }
  .dash-proc-qty::placeholder { color:#94a3b8; font-weight:700; }
  .dash-proc-qty:focus { border-color:var(--blue); outline:none; box-shadow:0 0 0 3px var(--blue-bg); }
  .dash-proc-todas { height:52px; padding:0 12px; font-size:14px; font-weight:700; border-radius:10px; white-space:nowrap; }
  .dash-proc-enviar { height:52px; padding:0 18px; font-size:16px; font-weight:800; white-space:nowrap; border-radius:10px; }
  .dash-proc-aviso { font-size:14px; color:var(--amber-text); background:var(--amber-bg); padding:10px 12px; border-radius:10px; margin-top:0.65rem; }
  .dash-proc-vacio { text-align:center; padding:2rem 1rem; color:var(--text2); font-size:16px; background:var(--surface); border-radius:12px; border:1.5px dashed var(--border2); }
  .dash-proc-modal { max-width: 420px; padding: 1.25rem 1.35rem; }
  .dash-proc-ticket { background:var(--bg); border-radius:12px; padding:14px 16px; margin-bottom:0.75rem; }
  .dash-proc-ticket-suela { font-size:20px; font-weight:800; line-height:1.2; }
  .dash-proc-ticket-meta { color:var(--text2); font-weight:600; font-size:14px; margin:4px 0 10px; }
  .dash-proc-ticket-qty { font-size:22px; font-weight:800; font-variant-numeric:tabular-nums; }
  .dash-proc-destinos { display:grid; gap:0.55rem; margin:0.35rem 0 0.25rem; }
  .dash-proc-destino { display:flex; align-items:center; gap:0.7rem; padding:16px 14px; border:2px solid var(--border2); border-radius:12px; cursor:pointer; font-size:18px; font-weight:800; }
  .dash-proc-destino:has(input:checked) { border-color:var(--blue); background:var(--blue-bg); }
  .dash-proc-destino input { width:22px; height:22px; }
  .dash-proc-fijo { background:var(--blue-bg); color:var(--text); padding:14px; border-radius:12px; font-size:17px; font-weight:700; }
  .dash-proc-nota { font-size:14px; color:var(--text2); margin:0.75rem 0 1rem; }
  @media (max-width: 700px) {
    .dash-proc-ruta { grid-template-columns:1fr; }
    .dash-proc-nums { grid-template-columns:1fr; }
    .dash-proc-talla { grid-template-columns:1fr; }
    .dash-proc-qty { max-width:none; }
    .dash-proc-enviar { width:100%; }
    .dash-proc-todas { flex:0 0 auto; }
  }
`;

let paginaActual = 0;
let hayPaginaSiguiente = false;
let pedidos = [];
let envioPendiente = null;
let modalListo = false;
let usuarioCargado = null;

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

function usuarioProceso() {
  const user = getState().user;
  if (!esRolDashboardProceso(user?.role)) return null;
  return user;
}

export async function cargarDashboardProcesoPage() {
  const user = usuarioProceso();
  const contenedor = document.getElementById('page-dashboard');
  if (!contenedor || !user) return;

  asegurarEstilos();
  if (usuarioCargado !== user.id || !contenedor.querySelector('.dash-proc-pasos')) {
    if (usuarioCargado !== user.id) paginaActual = 0;
    usuarioCargado = user.id;
    pedidos = [];
    contenedor.querySelector('.dash-proc-root')?.remove();
  }
  if (!contenedor.querySelector('.dash-proc-root')) {
    pintarEsqueleto(contenedor, user);
    enlazarControles();
  }

  await recargar();
}

function asegurarEstilos() {
  let estilo = document.getElementById('dash-proc-estilo');
  if (!estilo) {
    estilo = document.createElement('style');
    estilo.id = 'dash-proc-estilo';
    document.head.appendChild(estilo);
  }
  estilo.textContent = ESTILO;
}

function pintarEsqueleto(contenedor, user) {
  const proceso = procesoDeUsuario(user);
  const t = textosPlanta(proceso);
  contenedor.innerHTML = `
    <div class="dash-proc-root">
      <div class="dash-proc-top">
        <h2>${escapeHtml(t.titulo)}</h2>
        <button type="button" id="dash-proc-refrescar" class="btn btn-secondary btn-sm">Ver lo último</button>
      </div>
      <div class="dash-proc-pasos">
        ${t.pasos.map((p, i) => `<div class="dash-proc-paso"><b>${i + 1}</b>${escapeHtml(p)}</div>`).join('')}
      </div>
      <div id="dash-proc-lista" class="dash-proc-lista"></div>
      <div id="dash-proc-paginacion" class="pagination"></div>
    </div>
  `;
}

function enlazarControles() {
  document.getElementById('dash-proc-refrescar')?.addEventListener('click', () => recargar());
  if (!modalListo) {
    document.getElementById('btn-cerrar-dash-proc')?.addEventListener('click', cerrarModalEnvio);
    document.getElementById('btn-cancelar-dash-proc')?.addEventListener('click', cerrarModalEnvio);
    document.getElementById('btn-confirmar-dash-proc')?.addEventListener('click', confirmarEnvio);
    modalListo = true;
  }

  const lista = document.getElementById('dash-proc-lista');
  lista?.addEventListener('input', (e) => {
    if (!e.target.classList.contains('dash-proc-qty')) return;
    e.target.value = formatearCantidadEscrita(e.target.value);
  });
  lista?.addEventListener('click', (e) => {
    const todas = e.target.closest('[data-usar-todas]');
    if (todas) {
      const input = document.getElementById(todas.dataset.for);
      if (input && !input.disabled) {
        input.value = formatearCantidadEscrita(todas.dataset.qty);
        input.focus();
      }
      return;
    }
    const btn = e.target.closest('[data-enviar-talla]');
    if (!btn) return;
    abrirModalEnvio(btn.dataset.order, btn.dataset.item);
  });
}

async function recargar() {
  const user = usuarioProceso();
  const lista = document.getElementById('dash-proc-lista');
  if (!user || !lista) return;

  lista.innerHTML = '<div class="loading"><div class="spinner"></div> Cargando tu trabajo...</div>';
  try {
    const proceso = procesoDeUsuario(user);
    const res = await fetchPedidosDashboardProceso(proceso, paginaActual);
    pedidos = res.pedidos;
    hayPaginaSiguiente = res.hayMas;
    if (!pedidos.length && paginaActual > 0) {
      paginaActual -= 1;
      await recargar();
      return;
    }
    pintarLista();
    pintarPaginacion();
  } catch (err) {
    mostrarToast(err.message, 'error');
    lista.innerHTML = `<div class="dash-proc-vacio">${escapeHtml(err.message)}</div>`;
  }
}

function pintarLista() {
  const lista = document.getElementById('dash-proc-lista');
  const user = usuarioProceso();
  if (!lista || !user) return;
  const t = textosPlanta(procesoDeUsuario(user));

  if (!pedidos.length) {
    lista.innerHTML = `<div class="dash-proc-vacio">${escapeHtml(t.vacio)}</div>`;
    return;
  }

  lista.innerHTML = pedidos.map((p, i) => pintarCard(p, t, i === 0 && paginaActual === 0)).join('');
}

function pintarCard(pedido, t, esPrimero) {
  const tallas = tallasDePedido(pedido);
  const destinoFijo = pedido.destino && destinosDashboardProceso(getState().user.role).includes(pedido.destino)
    ? pedido.destino
    : null;
  const destinoAjeno = pedido.destino && !destinoFijo;

  const filasTalla = tallas.map((tal) => {
    const itemId = escapeHtml(tal.item_id);
    const order = escapeHtml(pedido.order_number);
    const tallaTxt = escapeHtml(tal.talla);
    const qtyId = `qty-${order}-${itemId}`;
    const pendTxt = formatearPares(tal.pendiente);
    return `
      <div class="dash-proc-talla">
        <div>
          <div class="dash-proc-talla-lbl">Talla ${tallaTxt}</div>
          <div class="dash-proc-talla-pend">${escapeHtml(t.teFaltan)} <strong>${pendTxt}</strong></div>
        </div>
        <div class="dash-proc-campo">
          <label for="${qtyId}">${escapeHtml(t.cuantas)}</label>
          <div class="dash-proc-qty-row">
            <input type="text" inputmode="numeric" pattern="[0-9]*" autocomplete="off" maxlength="6"
                   id="${qtyId}" class="dash-proc-qty" data-order="${order}" data-item="${itemId}"
                   ${destinoAjeno ? 'disabled' : ''} value="${escapeHtml(formatearUnidades(tal.pendiente))}"
                   aria-label="${escapeHtml(t.cuantas)} talla ${tallaTxt}">
            <button type="button" class="btn btn-secondary dash-proc-todas" data-usar-todas
                    data-for="${qtyId}" data-qty="${escapeHtml(formatearUnidades(tal.pendiente))}"
                    ${destinoAjeno ? 'disabled' : ''}>${escapeHtml(t.usarTodas)}</button>
          </div>
        </div>
        <button type="button" class="btn btn-primary dash-proc-enviar" data-enviar-talla
                data-order="${order}" data-item="${itemId}" ${destinoAjeno ? 'disabled' : ''}>
          Enviar talla ${tallaTxt}
        </button>
      </div>`;
  }).join('');

  const aviso = destinoAjeno
    ? `<div class="dash-proc-aviso">Este trabajo ya está marcado para ${escapeHtml(pedido.destino)}. Regístralo en Órdenes.</div>`
    : '';

  return `
    <article class="dash-proc-card${esPrimero ? ' es-primero' : ''}" data-order="${escapeHtml(pedido.order_number)}">
      <dl class="dash-proc-ruta">
        <div>
          <dt>${escapeHtml(t.deDonde)}</dt>
          <dd>${escapeHtml(etiquetaOrigen(pedido.origen))}
            <small>${escapeHtml(detalleOrigen(pedido.origen))}</small>
          </dd>
        </div>
        <div>
          <dt>${escapeHtml(t.cuandoLlego)}</dt>
          <dd class="cuando">${escapeHtml(formatearHaceCuanto(pedido.llegada_al_area))}
            <small>${escapeHtml(formatearLlegadaArea(pedido.llegada_al_area))}</small>
          </dd>
        </div>
      </dl>
      <div class="dash-proc-cuerpo">
        ${esPrimero ? `<div class="dash-proc-badge">${escapeHtml(t.empiezaAqui)}</div>` : ''}
        <div class="dash-proc-suela">${escapeHtml(pedido.nombre_suela || '—')}</div>
        <div class="dash-proc-chips">
          <span class="dash-proc-chip"><span>Material</span>${escapeHtml(pedido.material || '—')}</span>
          <span class="dash-proc-chip"><span>Color</span>${escapeHtml(pedido.color || '—')}</span>
        </div>
        <div class="dash-proc-nums">
          <div class="dash-proc-num llegaron"><span>${escapeHtml(t.teLlegaron)}</span><strong>${formatearUnidades(pedido.entrada)}</strong><em>pares</em></div>
          <div class="dash-proc-num enviaste"><span>${escapeHtml(t.yaEnviaste)}</span><strong>${formatearUnidades(pedido.salida)}</strong><em>pares</em></div>
          <div class="dash-proc-num faltan"><span>${escapeHtml(t.teFaltan)}</span><strong>${formatearUnidades(pedido.pendiente)}</strong><em>pares</em></div>
        </div>
        <div class="dash-proc-hacer">${escapeHtml(t.queHacer)}</div>
        <div class="dash-proc-tallas">${filasTalla}</div>
        ${aviso}
      </div>
    </article>`;
}

function pintarPaginacion() {
  const el = document.getElementById('dash-proc-paginacion');
  if (!el) return;
  el.innerHTML = `
    <button class="btn btn-secondary btn-sm" id="dash-proc-prev" ${paginaActual === 0 ? 'disabled' : ''}>← Anteriores</button>
    <span>Página ${paginaActual + 1}</span>
    <button class="btn btn-secondary btn-sm" id="dash-proc-next" ${hayPaginaSiguiente ? '' : 'disabled'}>Siguientes →</button>
  `;
  document.getElementById('dash-proc-prev')?.addEventListener('click', () => {
    paginaActual = Math.max(paginaActual - 1, 0);
    recargar();
  });
  document.getElementById('dash-proc-next')?.addEventListener('click', () => {
    paginaActual += 1;
    recargar();
  });
}

function abrirModalEnvio(orderNumber, itemId) {
  const user = usuarioProceso();
  const pedido = pedidos.find((p) => p.order_number === orderNumber);
  const talla = tallasDePedido(pedido).find((tal) => tal.item_id === itemId);
  if (!user || !pedido || !talla) return;

  const input = document.querySelector(`.dash-proc-qty[data-order="${CSS.escape(orderNumber)}"][data-item="${CSS.escape(itemId)}"]`);
  const cantidad = leerCantidad(input?.value);
  const pendiente = Number(talla.pendiente) || 0;

  if (cantidad <= 0) {
    mostrarToast('Escribe cuántos pares vas a enviar.', 'error');
    input?.focus();
    return;
  }
  if (cantidad > pendiente) {
    mostrarToast(`En esa talla solo te faltan ${formatearPares(pendiente)}.`, 'error');
    input?.focus();
    return;
  }

  const destinos = destinosDashboardProceso(user.role);
  const destinoFijo = pedido.destino && destinos.includes(pedido.destino) ? pedido.destino : null;
  if (pedido.destino && !destinoFijo) {
    mostrarToast(`Este trabajo ya está marcado para ${pedido.destino}.`, 'error');
    return;
  }

  envioPendiente = { pedido, talla, cantidad, destinoFijo, destinos, user };

  const titulo = document.querySelector('#modal-dashboard-proceso .modal-title');
  if (titulo) titulo.textContent = '¿Confirmas el envío?';

  document.getElementById('dash-proc-resumen').innerHTML = `
    <div class="dash-proc-ticket">
      <div class="dash-proc-ticket-suela">${escapeHtml(pedido.nombre_suela || '—')}</div>
      <div class="dash-proc-ticket-meta">${escapeHtml(pedido.material || '—')} · ${escapeHtml(pedido.color || '—')}</div>
      <div class="dash-proc-ticket-qty">Talla ${escapeHtml(talla.talla)} · ${formatearPares(cantidad)}</div>
    </div>
  `;

  const cajaDestino = document.getElementById('dash-proc-destino-box');
  if (destinoFijo || destinos.length === 1) {
    const destino = destinoFijo || destinos[0];
    cajaDestino.innerHTML = `<div class="dash-proc-fijo">Va para <strong>${escapeHtml(destino)} ${ICONO_PROCESO[destino] || ''}</strong></div>`;
  } else {
    cajaDestino.innerHTML = `
      <div style="font-size:16px;color:var(--text);font-weight:800;margin:0.65rem 0 0.4rem;">¿A dónde lo mandas?</div>
      <div class="dash-proc-destinos">
        ${destinos.map((d) => `
          <label class="dash-proc-destino">
            <input type="radio" name="dash-proc-destino" value="${escapeHtml(d)}">
            Mandar a ${escapeHtml(d)} ${ICONO_PROCESO[d] || ''}
          </label>`).join('')}
      </div>`;
  }

  const nota = document.getElementById('dash-proc-modal-nota');
  if (nota) nota.textContent = 'Revisa talla, pares y destino.';
  const btnOk = document.getElementById('btn-confirmar-dash-proc');
  if (btnOk) btnOk.textContent = 'Sí, enviar';
  const btnNo = document.getElementById('btn-cancelar-dash-proc');
  if (btnNo) btnNo.textContent = 'Volver';

  document.getElementById('modal-dashboard-proceso').classList.add('open');
}

function cerrarModalEnvio() {
  document.getElementById('modal-dashboard-proceso')?.classList.remove('open');
  envioPendiente = null;
}

async function confirmarEnvio() {
  if (!envioPendiente) return;
  const { pedido, talla, cantidad, destinoFijo, destinos, user } = envioPendiente;

  let destino = destinoFijo || (destinos.length === 1 ? destinos[0] : null);
  if (!destino) {
    destino = document.querySelector('input[name="dash-proc-destino"]:checked')?.value || null;
  }
  if (!destino) {
    mostrarToast('Elige si va a Acabado o a Mateado.', 'error');
    return;
  }

  const btn = document.getElementById('btn-confirmar-dash-proc');
  btn.disabled = true;
  try {
    await enviarTallaDashboardProceso({ pedido, talla, cantidad, destino, user });
    mostrarToast(`Listo: se enviaron ${formatearPares(cantidad)} de la talla ${talla.talla} a ${destino}.`, 'ok');
    cerrarModalEnvio();
    await recargar();
  } catch (err) {
    mostrarToast(err.message, 'error');
  } finally {
    btn.disabled = false;
  }
}
