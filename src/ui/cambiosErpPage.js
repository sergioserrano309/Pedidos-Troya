import {
  fetchCambiosPanel, fetchEstadoDetector, fetchCamposAplicables, revertirCambioErp,
  aplicarCambioErp, descartarCambioErp, fetchImpactoCambios
} from '../services/cambiosErpService.js';
import {
  ETIQUETA_TIPO, etiquetaEstado, descripcionCambio, contadoresPanel, estadoDetector, formatearValor,
  formatearDia, estadoBotones, textoImpacto, pierdeLiquidacion, textoCamposEncendidos, necesitaImpacto, infoLineaSobrante, columnasLineaSobrante
} from '../lib/cambiosErp.js';
import { abrirDetalleOrden } from './orderDetail.js';
import { esValidador } from '../services/validatorService.js';
import { mostrarToast } from './toast.js';
import { pintarInsigniaCambiosErp } from './cambiosErpInsignia.js';

/**
 * Pestaña "Cambios ERP" (solo Validador): lista las diferencias que el
 * detector encontró entre Access y el programa. Fase 1: solo se muestran.
 * Fase 2: los campos de TEXTO cuyo interruptor esté encendido (Supabase,
 * erp_cambios_estado.aplicar_campos) se aplican solos y aquí se pueden
 * DESHACER; los demás tipos siguen sin aplicarse.
 */

const ESTILO_INPUT = 'padding:8px 12px;border:1.5px solid var(--border2);border-radius:var(--r);font-size:13px;';
const PAGE_SIZE = 50;

// Íconos de trazo (mismo estilo que el resto de la plataforma: 24x24, trazo
// redondeado, color = currentColor).
const SVG = (contenido) => `<svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${contenido}</svg>`;
const ICONO_APLICAR = SVG('<polyline points="20 6 9 17 4 12"/>');
const ICONO_DESCARTAR = SVG('<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>');
const ICONO_DESHACER = SVG('<polyline points="1 4 1 10 7 10"/><path d="M3.51 15a9 9 0 1 0 2.13-9.36L1 10"/>');

// Botones: ✓ verde = Aplicar · ✕ rojo = Descartar (no aplicar) · ↺ azul = Deshacer.
// El botón de la acción tomada se ve "presionado" (relleno); los que no se
// pueden usar ahora se ven apagados.
const ESTILO_BOTONES = `
  .erp-acciones{display:inline-flex;gap:6px;align-items:center;justify-content:center;}
  .erp-btn{width:30px;height:30px;padding:0;border-radius:8px;border:1.5px solid;background:var(--surface,#fff);
    display:inline-flex;align-items:center;justify-content:center;cursor:pointer;
    transition:background .12s,color .12s,box-shadow .12s;}
  .erp-btn.verde{color:var(--green);border-color:var(--green);}
  .erp-btn.rojo{color:var(--red);border-color:var(--red);}
  .erp-btn.azul{color:var(--blue);border-color:var(--blue);}
  .erp-btn.verde:hover:not(.inactivo){background:var(--green-bg);}
  .erp-btn.rojo:hover:not(.inactivo){background:var(--red-bg);}
  .erp-btn.azul:hover:not(.inactivo){background:var(--blue-bg);}
  .erp-btn.verde.activo{background:var(--green);color:#fff;box-shadow:0 0 0 3px var(--green-bg);}
  .erp-btn.rojo.activo{background:var(--red);color:#fff;box-shadow:0 0 0 3px var(--red-bg);}
  .erp-btn.azul.activo{background:var(--blue);color:#fff;box-shadow:0 0 0 3px var(--blue-bg);}
  .erp-btn.inactivo:not(.activo){opacity:.35;cursor:not-allowed;}
  .erp-btn.activo{cursor:default;}
  .erp-chip{font-size:11px;font-weight:600;margin-top:3px;text-align:center;white-space:nowrap;}
  .erp-chip.verde{color:var(--green-text);}
  .erp-chip.rojo{color:var(--red-text);}
  .erp-chip.azul{color:var(--blue);}
  .erp-chip.gris{color:var(--text3);}
`;

// Impacto/bloqueo de las cantidades, por id de cambio. undefined = sin pedir;
// null = se pidió y no se pudo calcular.
const impactos = new Map();
const impactosEnVuelo = new Set();

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
    <style>${ESTILO_BOTONES}</style>
    <div class="card">
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:0.75rem;">
        <h2>🔀 Cambios ERP — diferencias entre Access y el programa</h2>
        <button id="btn-refrescar-cambios-erp" class="btn btn-secondary btn-sm">🔄 Refrescar</button>
      </div>
      <div style="font-size:12px; color:var(--text2); margin-bottom:0.5rem;">
        Aquí se listan los datos que en Access cambiaron después de cargar el pedido. <strong>Los datos de texto y los pedidos
        cancelados (se cierran a la fuerza) cuyo interruptor esté encendido (ver abajo) se aplican solos cuando se ven iguales
        en 2 revisiones seguidas. Lo demás lo decide usted con los botones:
        <span style="color:var(--green-text);">✓ Aplicar</span> ·
        <span style="color:var(--red-text);">✕ No aplicar (descartar)</span> ·
        <span style="color:var(--blue);">↺ Deshacer</span> (solo si se aplicó).
        Las <u>cantidades</u> nunca se aplican solas: siempre con ✓, viendo antes el impacto en comisiones.</strong>
      </div>
      <div id="cambios-erp-estado" style="font-size:12px; margin-bottom:0.75rem;"></div>
      <div id="cambios-erp-contadores" style="display:flex; gap:8px; flex-wrap:wrap; margin-bottom:0.75rem;"></div>
      <div style="display:grid; grid-template-columns:90px 190px 1.2fr; gap:0.75rem; margin-bottom:1rem;">
        <input type="text" id="cambios-erp-filtro-orden" placeholder="No. Orden" maxlength="4" style="${ESTILO_INPUT}">
        <select id="cambios-erp-filtro-estado" style="${ESTILO_INPUT}">
          <option value="pendiente">Pendientes</option>
          <option value="aplicado">Aplicados</option>
          <option value="rechazado">Descartados / deshechos</option>
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
    const boton = e.target.closest('[data-accion]');
    if (boton) {
      await ejecutarAccion(boton);
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
  // El impacto depende del estado actual del pedido: se vuelve a calcular.
  impactos.clear();
  impactosEnVuelo.clear();
  // La insignia de la pestaña usa el mismo número que "N pendientes en M pedidos".
  if (filas !== null) pintarInsigniaCambiosErp(contadoresPanel(todos).pedidos);
  pintar(filas === null);
}

/** Pide el bloqueo/impacto de las cantidades visibles que aún no se han calculado y repinta. */
async function cargarImpactos(visibles) {
  const ids = visibles
    .filter((c) => necesitaImpacto(c) && ['pendiente', 'rechazado'].includes(c.estado))
    .map((c) => Number(c.id))
    .filter((id) => !impactos.has(id) && !impactosEnVuelo.has(id));
  if (ids.length === 0) return;
  ids.forEach((id) => impactosEnVuelo.add(id));
  const miCarga = cargaActual;
  const res = await fetchImpactoCambios(ids);
  if (miCarga !== cargaActual) return; // se recargó el panel mientras tanto
  ids.forEach((id) => {
    impactosEnVuelo.delete(id);
    impactos.set(id, res === null ? null : (res[String(id)] ?? null));
  });
  pintar();
}

/**
 * Acciones de la fila (los mismos tres botones para cualquier tipo de cambio):
 *   ✓ Aplicar    aplica el cambio ahora, a mano.
 *   ✕ Descartar  no aplicarlo (no toca ningún pedido).
 *   ↺ Deshacer   revierte un cambio ya aplicado.
 * Cada una pide confirmación; las cantidades muestran antes el impacto.
 */
async function ejecutarAccion(boton) {
  if (boton.getAttribute('aria-disabled') === 'true') return;
  const id = Number(boton.dataset.id);
  const accion = boton.dataset.accion;
  const c = todos.find((x) => Number(x.id) === id);
  if (!c || !Number.isFinite(id)) return;

  const pedido = c.pedido;
  const esCancelado = c.tipo === 'cancelado';
  const esCantidad = c.tipo === 'cantidad';
  const esLinea = c.tipo === 'linea_sobrante';
  const impacto = impactos.get(id);

  const textos = {
    aplicar: () => {
      if (esCantidad || esLinea) {
        const lineas = textoImpacto(c, impacto);
        if (!lineas) {
          mostrarToast('No se pudo calcular el impacto; no se aplica a ciegas.', 'error');
          return null;
        }
        return {
          pregunta: `¿Aplicar este cambio del pedido ${pedido}?\n\n${lineas.join('\n')}\n\n`
            + (pierdeLiquidacion(impacto)
              ? '⚠ ATENCIÓN: con este cambio, trabajo que hoy ya es liquidable deja de serlo (comisiones). '
              : '')
            + 'Se puede deshacer después.',
          exito: esLinea
            ? `Línea de la talla ${c.talla} del pedido ${pedido} ocultada.`
            : `Cantidad de la talla ${c.talla} del pedido ${pedido} actualizada.`,
          accion: () => aplicarCambioErp(id)
        };
      }
      return {
        pregunta: `¿Aplicar este cambio del pedido ${pedido}?\n\n`
          + 'Se cierra a la fuerza con el motivo "Cancelado en Troya", firmado por usted. '
          + (c.contexto?.completo ? 'OJO: el pedido ya está completo. ' : '')
          + 'Nadie podrá registrar ni eliminar movimientos hasta que lo reabra (puede hacerlo con Deshacer).',
        exito: `Pedido ${pedido} cerrado a la fuerza.`,
        accion: () => aplicarCambioErp(id)
      };
    },
    descartar: () => ({
      pregunta: `¿No aplicar este cambio del pedido ${pedido}?\n\n`
        + 'Se descarta y dejará de mostrarse como pendiente. No se modifica ningún pedido. '
        + 'Si Access lo cambia otra vez, volverá a aparecer. Después se puede aplicar con ✓.',
      exito: `Cambio del pedido ${pedido} descartado.`,
      accion: () => descartarCambioErp(id)
    }),
    deshacer: () => ({
      pregunta: esCancelado
        ? `¿Deshacer el cierre del pedido ${pedido}?\n\n`
          + 'Se quita el cierre a la fuerza y no se volverá a cerrar mientras Access no cambie.'
        : esLinea
          ? `¿Volver a mostrar la línea de la talla ${c.talla} del pedido ${pedido}?\n\n`
            + 'La línea vuelve a contar en el pedido y no se volverá a ocultar mientras Access no cambie.'
        : esCantidad
          ? `¿Deshacer el cambio de cantidad de la talla ${c.talla} del pedido ${pedido}?\n\n`
            + 'Se restaura la cantidad anterior (solo si no queda por debajo de lo ya procesado o despachado).'
          : `¿Deshacer este cambio del pedido ${pedido}?\n\n`
            + 'Se restaura el valor anterior y el programa no lo volverá a cambiar '
            + 'mientras Access no lo modifique otra vez.',
      exito: esCancelado ? `Pedido ${pedido} reabierto.`
        : esLinea ? `Línea de la talla ${c.talla} del pedido ${pedido} visible otra vez.`
        : `Cambio del pedido ${pedido} deshecho.`,
      accion: () => revertirCambioErp(id)
    })
  };

  const t = textos[accion]?.();
  if (!t || !window.confirm(t.pregunta)) return;
  boton.setAttribute('aria-disabled', 'true');
  try {
    await t.accion();
    mostrarToast(t.exito, 'ok');
    await recargar();
  } catch (err) {
    boton.setAttribute('aria-disabled', 'false');
    mostrarToast(err.message || 'No se pudo completar la acción.', 'error');
  }
}

/** Los tres botones de la fila y la etiqueta de quién hizo la acción. */
function accionesDeFila(c) {
  const e = estadoBotones(c, impactos.get(Number(c.id)));
  const btn = (accion, color, icono, nombre, est) =>
    `<button type="button" class="erp-btn ${color}${est.activo ? ' activo' : ''}${est.habilitado ? '' : ' inactivo'}" `
    + `data-accion="${accion}" data-id="${Number(c.id)}" aria-label="${nombre}" `
    + `aria-disabled="${est.habilitado ? 'false' : 'true'}" title="${escapeHtml(est.motivo || nombre)}">${icono}</button>`;
  const chip = e.chip ? `<div class="erp-chip ${e.chip.tono}">${escapeHtml(e.chip.texto)}</div>` : '';
  return `<div class="erp-acciones">`
    + btn('aplicar', 'verde', ICONO_APLICAR, 'Aplicar', e.aplicar)
    + btn('descartar', 'rojo', ICONO_DESCARTAR, 'No aplicar (descartar)', e.descartar)
    + btn('deshacer', 'azul', ICONO_DESHACER, 'Deshacer', e.deshacer)
    + `</div>${chip}`;
}

/** Aclaración azul bajo "Qué cambió" para las líneas que sobran: qué se queda y qué se quita. */
function avisoInfo(c) {
  if (!['pendiente', 'rechazado'].includes(c.estado)) return '';
  const texto = infoLineaSobrante(c, impactos.get(Number(c.id)));
  return texto ? `<div style="color:var(--blue); font-size:11px; margin-top:2px;">ℹ ${escapeHtml(texto)}</div>` : '';
}

/** Aviso rojo bajo "Qué cambió" cuando una cantidad está bloqueada. */
function avisoBloqueo(c) {
  if (!necesitaImpacto(c) || !['pendiente', 'rechazado'].includes(c.estado)) return '';
  const imp = impactos.get(Number(c.id));
  if (!imp?.bloqueado) return '';
  return `<div style="color:var(--red-text); font-size:11px; margin-top:2px;">⛔ ${escapeHtml(imp.motivo || 'Bloqueado')}</div>`;
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
          const sobra = c.tipo === 'linea_sobrante' ? columnasLineaSobrante(c, impactos.get(Number(c.id))) : null;
          const enAccess = esCancel ? 'Cancelado'
            : sobra ? sobra.enAccess
              : formatearValor(c.campo, c.valor_access);
          const enPrograma = esCancel ? 'Activo'
            : sobra ? sobra.enPrograma
              : c.tipo === 'linea_nueva' ? 'No la tiene'
                : formatearValor(c.campo, c.valor_programa);
          const ambiguo = c.ambiguo ? ' <span title="El detector no pudo emparejar con certeza las líneas de esta talla" style="color:var(--amber-text);">⚠ ambiguo</span>' : '';
          const resuelto = c.estado === 'resuelto';
          return `
          <tr style="border-bottom:1px solid var(--border); ${resuelto ? 'color:var(--text3);' : ''}">
            <td style="padding:8px;"><a href="#" data-abrir-orden="${escapeHtml(c.pedido)}" style="font-weight:700;">${escapeHtml(c.pedido)}</a></td>
            <td style="padding:8px;">${escapeHtml(c.talla || '—')}</td>
            <td style="padding:8px;">${escapeHtml(ETIQUETA_TIPO[c.tipo] || c.tipo)}</td>
            <td style="padding:8px;">${escapeHtml(descripcionCambio(c))}${ambiguo}${avisoInfo(c)}${avisoBloqueo(c)}</td>
            <td style="padding:8px;">${escapeHtml(enAccess)}</td>
            <td style="padding:8px;">${escapeHtml(enPrograma)}</td>
            <td style="padding:8px; text-align:center;">${Number(c.contexto?.movimientos || 0)}</td>
            <td style="padding:8px; text-align:center;">${Number(c.contexto?.despachos || 0)}</td>
            <td style="padding:8px;">${escapeHtml(etiquetaEstado(c))}${c.estado === 'aplicado' ? `<div style="font-size:11px; color:var(--text3);">el ${escapeHtml(formatearDia(c.aplicado_at))}</div>` : ''}</td>
            <td style="padding:8px; white-space:nowrap;">${escapeHtml(fechaHora(c.detectado_at))}</td>
            <td style="padding:8px; text-align:center;">${Number(c.revisiones_consecutivas || 0)}</td>
            <td style="padding:8px; text-align:center; white-space:nowrap;">${accionesDeFila(c)}</td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>
  `;

  cargarImpactos(visibles);
}
