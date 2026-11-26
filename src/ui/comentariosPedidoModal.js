import { supabase } from '../config/supabaseClient.js';
import { getState } from '../state/appState.js';
import { mostrarToast } from './toast.js';
import { confirmarEnApp } from './confirmModal.js';
import {
  fetchHistorialComentarios,
  agregarComentarioPedido,
  eliminarComentarioPedido,
  cerrarComentarioPedido
} from '../services/comentariosPedidoService.js';
import {
  ROLES_ETIQUETABLES,
  rolesDeTexto,
  resaltarEtiquetasHtml,
  hoyISO,
  diasParaVencer,
  formatearVencimiento
} from '../lib/etiquetasRol.js';

/**
 * Ventana de comentarios de una orden (Control Central): historial tipo chat.
 * Solo se puede agregar y eliminar; lo eliminado queda marcado en el historial.
 */

const MAX = 255;
const ROL_ETIQUETA = { propuesta: 'Propuesta', empaque: 'Despachos', validador: 'Validador' };

function escapeHtml(value) {
  return String(value ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

function formatearMarca(iso) {
  return new Date(iso).toLocaleString('es-CO', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit', hour12: true
  });
}

/**
 * @param {string} orderNumber
 * @param {{ alCambiar?: () => void }} [opciones] alCambiar: se llama al agregar/eliminar (refresca el botón de la tabla)
 */
export async function abrirComentariosPedido(orderNumber, { alCambiar } = {}) {
  const usuario = getState().user;
  const esVal = usuario?.role === 'validador';

  const modal = document.createElement('div');
  modal.className = 'modal open';
  modal.style.zIndex = '1050';
  modal.innerHTML = `
    <div class="modal-content" role="dialog" aria-modal="true" style="max-width:560px;">
      <div class="modal-header">
        <div class="modal-title">Comentarios — Orden ${escapeHtml(orderNumber)}</div>
        <button class="modal-close" type="button" data-accion="cerrar" aria-label="Cerrar">×</button>
      </div>
      <div id="cpm-historial" style="max-height:50vh; overflow-y:auto; display:flex; flex-direction:column; gap:10px; padding:4px 2px; margin-bottom:1rem;">
        <div style="color:var(--text3); font-size:13px; text-align:center;">Cargando...</div>
      </div>
      <div style="display:flex; align-items:flex-end; gap:10px;">
        <label class="acc-switch" title="Rojo = No, verde = Sí. Marca Sí si este comentario implica algo que la operación debe hacer; luego se marca como Hecho."
          style="display:flex; flex-direction:column; align-items:center; gap:4px; font-size:11px; color:var(--text2); cursor:pointer; width:64px; flex-shrink:0; padding-bottom:4px;">
          <span>Accionable</span>
          <span class="propuesta-switch">
            <input type="checkbox" id="cpm-accionable">
            <span class="propuesta-switch-slider"></span>
          </span>
        </label>
        <div style="position:relative; flex:1; min-width:0;">
          <div id="cpm-menu" role="listbox" style="display:none; position:absolute; left:0; bottom:100%; margin-bottom:4px; z-index:5; min-width:180px; background:var(--surface); border:1px solid var(--border2); border-radius:var(--r); box-shadow:var(--shadow-md); padding:4px; font-size:13px;"></div>
          <textarea id="cpm-texto" maxlength="${MAX}" rows="2" placeholder="Escribe un comentario... (@ para etiquetar un rol)"
            style="width:100%; box-sizing:border-box; padding:8px 12px; border:1.5px solid var(--border2); border-radius:var(--r); font-size:13px; font-family:inherit; resize:none; display:block;"></textarea>
        </div>
        <button class="btn btn-primary" type="button" id="cpm-enviar" disabled style="flex-shrink:0;">Enviar</button>
      </div>
      <div style="margin-top:6px; display:flex; justify-content:space-between; align-items:center; gap:8px;">
        <label style="display:flex; align-items:center; gap:6px; font-size:12px; color:var(--text2);">
          Vence
          <input type="date" id="cpm-vence" min="${hoyISO()}" disabled
            style="padding:3px 6px; border:1.5px solid var(--border2); border-radius:var(--r); font-size:12px; font-family:inherit;">
        </label>
        <span id="cpm-contador" style="font-size:12px; color:var(--text3);">0 / ${MAX}</span>
      </div>
    </div>`;

  const historial = modal.querySelector('#cpm-historial');
  const campo = modal.querySelector('#cpm-texto');
  const contador = modal.querySelector('#cpm-contador');
  const botonEnviar = modal.querySelector('#cpm-enviar');
  const interruptorAcc = modal.querySelector('#cpm-accionable');
  const campoVence = modal.querySelector('#cpm-vence');
  const menu = modal.querySelector('#cpm-menu');
  let opcionesMenu = [];
  let indiceMenu = 0;

  // En vivo: si otro usuario comenta o elimina mientras está abierta, se actualiza sola.
  const canal = supabase
    .channel(`comentarios-pedido-${orderNumber}-${Date.now()}`)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'pedido_comentarios' }, () => cargar())
    .subscribe();

  const cerrar = () => {
    document.removeEventListener('keydown', alTeclear, true);
    supabase.removeChannel(canal);
    modal.remove();
  };
  const alTeclear = (e) => {
    if (e.key === 'Escape') {
      e.stopPropagation();
      // Con la lista de @ abierta, Esc solo la cierra.
      if (menu.style.display !== 'none') ocultarMenu();
      else cerrar();
    }
  };

  /** " · vence dd/mm/aaaa" (en rojo si ya venció). */
  function textoVencimiento(c) {
    if (!c.fecha_vencimiento) return '';
    const dias = diasParaVencer(c.fecha_vencimiento);
    const color = dias !== null && dias < 0 ? 'var(--red-text)' : 'var(--text2)';
    return ` <span style="color:${color};">· vence ${formatearVencimiento(c.fecha_vencimiento)}</span>`;
  }

  function burbuja(c) {
    const rol = ROL_ETIQUETA[String(c.autor_rol).toLowerCase()] || c.autor_rol;
    const propio = c.created_by === usuario?.id;
    const puedeEliminar = !c.eliminado && (esVal || propio);
    // Estilo chat: lo mío a la derecha (azul suave), lo de los demás a la izquierda (gris).
    const lado = propio ? 'align-self:flex-end;' : 'align-self:flex-start;';
    const fondo = propio ? 'background:var(--blue-bg); border-color:transparent;' : 'background:var(--bg); border-color:var(--border);';
    const base = `${lado} max-width:88%; min-width:55%; box-sizing:border-box; border:1px solid; border-radius:12px; padding:8px 12px;`;
    const cabecera = `
      <div style="font-size:11px; color:var(--text2); margin-bottom:4px;">
        <strong style="color:var(--text);">${escapeHtml(c.autor_nombre)}</strong> (${escapeHtml(rol)}) · ${formatearMarca(c.created_at)}
      </div>`;
    if (c.eliminado) {
      return `
        <div style="${base} background:transparent; border-style:dashed; border-color:var(--border2);">
          ${cabecera}
          <div style="font-size:13px; color:var(--text3); text-decoration:line-through; white-space:pre-wrap; word-break:break-word;">${resaltarEtiquetasHtml(escapeHtml(c.texto))}</div>
          ${c.accionable ? '<div style="font-size:11px; color:var(--text3); margin-top:4px;">Era un accionable</div>' : ''}
          <div style="font-size:11px; color:var(--red-text); margin-top:4px;">Eliminado por ${escapeHtml(c.eliminado_nombre || '—')} · ${formatearMarca(c.eliminado_at)}</div>
        </div>`;
    }
    let pie = '';
    if (c.accionable) {
      pie = c.cerrado
        ? `<div style="margin-top:8px; font-size:11px;"><span style="background:var(--green-bg); color:var(--green-text); padding:2px 8px; border-radius:10px; font-weight:600;">Hecho</span> <span style="color:var(--text2);">por ${escapeHtml(c.cerrado_nombre || '—')} · ${formatearMarca(c.cerrado_at)}</span></div>`
        : `<div style="margin-top:8px; font-size:11px; display:flex; align-items:center; justify-content:space-between; gap:8px;">
             <span><span style="background:var(--amber-bg); color:var(--amber-text); padding:2px 8px; border-radius:10px; font-weight:600;">Pendiente</span>${textoVencimiento(c)}</span>
             <button type="button" class="btn btn-sm btn-secondary" data-cerrar-acc="${escapeHtml(c.id)}">Hecho</button>
           </div>`;
    }
    return `
      <div style="${base} ${fondo}">
        ${cabecera}
        <div style="display:flex; justify-content:space-between; align-items:flex-start; gap:8px;">
          <div style="font-size:13px; white-space:pre-wrap; word-break:break-word;">${resaltarEtiquetasHtml(escapeHtml(c.texto))}</div>
          ${puedeEliminar ? `<button type="button" class="btn-eliminar-registro" data-eliminar="${escapeHtml(c.id)}" title="Eliminar comentario" aria-label="Eliminar comentario" style="width:22px; height:22px; padding:0; font-size:14px; flex-shrink:0;">×</button>` : ''}
        </div>
        ${pie}
      </div>`;
  }

  async function cargar() {
    try {
      const filas = await fetchHistorialComentarios(orderNumber);
      const alFinal = historial.scrollTop + historial.clientHeight >= historial.scrollHeight - 40;
      historial.innerHTML = filas.length
        ? filas.map(burbuja).join('')
        : '<div style="color:var(--text3); font-size:13px; text-align:center;">Aún no hay comentarios en esta orden.</div>';
      if (alFinal) historial.scrollTop = historial.scrollHeight;
    } catch (err) {
      historial.innerHTML = `<div style="color:var(--red-text); font-size:13px; text-align:center;">${escapeHtml(err.message)}</div>`;
    }
  }

  function actualizarEntrada() {
    const largo = campo.value.length;
    contador.textContent = `${largo} / ${MAX}`;
    campoVence.disabled = !interruptorAcc.checked;
    if (!interruptorAcc.checked) campoVence.value = '';
    const faltaFecha = interruptorAcc.checked && !campoVence.value;
    botonEnviar.disabled = campo.value.trim() === '' || largo > MAX || faltaFecha;
    botonEnviar.title = faltaFecha ? 'Elige la fecha de vencimiento del accionable' : '';
  }

  // ---- Etiquetas con "@" ----
  function ocultarMenu() {
    menu.style.display = 'none';
    opcionesMenu = [];
  }

  function pintarMenu() {
    menu.innerHTML = opcionesMenu.map((r, i) => `
      <div role="option" data-etiqueta="${r.etiqueta}" style="padding:5px 10px; border-radius:4px; cursor:pointer; ${i === indiceMenu ? 'background:var(--blue-bg); color:var(--blue);' : ''}">@${r.etiqueta}</div>`).join('');
    menu.style.display = '';
  }

  /** Muestra la lista si justo antes del cursor hay "@" + letras. */
  function actualizarMenu() {
    const antes = campo.value.slice(0, campo.selectionStart);
    const m = antes.match(/(^|\s)@([\p{L}]*)$/u);
    if (!m) return ocultarMenu();
    const frag = m[2].toLowerCase();
    opcionesMenu = ROLES_ETIQUETABLES.filter((r) => r.etiqueta.toLowerCase().startsWith(frag));
    if (opcionesMenu.length === 0) return ocultarMenu();
    indiceMenu = Math.min(indiceMenu, opcionesMenu.length - 1);
    pintarMenu();
  }

  function insertarEtiqueta(etiqueta) {
    const pos = campo.selectionStart;
    const antes = campo.value.slice(0, pos).replace(/@[\p{L}]*$/u, `@${etiqueta} `);
    campo.value = antes + campo.value.slice(pos);
    campo.setSelectionRange(antes.length, antes.length);
    ocultarMenu();
    actualizarEntrada();
    campo.focus();
  }

  async function enviar() {
    const texto = campo.value.trim();
    if (!texto) return;
    botonEnviar.disabled = true;
    try {
      await agregarComentarioPedido(orderNumber, texto, interruptorAcc.checked, campoVence.value || null, rolesDeTexto(texto));
      campo.value = '';
      interruptorAcc.checked = false;
      campoVence.value = '';
      actualizarEntrada();
      await cargar();
      historial.scrollTop = historial.scrollHeight;
      alCambiar?.();
    } catch (err) {
      mostrarToast(err.message, 'error');
      actualizarEntrada();
    }
  }

  async function eliminar(id) {
    const ok = await confirmarEnApp({
      titulo: 'Eliminar comentario',
      detalle: 'El comentario no se borra: queda en el historial marcado como eliminado, con tu nombre y la fecha.',
      textoConfirmar: 'Eliminar',
      estiloConfirmar: 'danger'
    });
    if (!ok) return;
    try {
      await eliminarComentarioPedido(id);
      await cargar();
      alCambiar?.();
    } catch (err) {
      mostrarToast(err.message, 'error');
    }
  }

  async function cerrarAccionable(id) {
    const ok = await confirmarEnApp({
      titulo: 'Marcar como hecho',
      detalle: 'Confirma que la acción de este comentario ya se hizo. Quedará registrado quién lo cerró y cuándo; no se puede reabrir.',
      textoConfirmar: 'Hecho'
    });
    if (!ok) return;
    try {
      await cerrarComentarioPedido(id);
      await cargar();
      alCambiar?.();
    } catch (err) {
      mostrarToast(err.message, 'error');
      await cargar();
    }
  }

  modal.addEventListener('click', (e) => {
    if (e.target === modal) return cerrar();
    const boton = e.target.closest?.('button');
    if (!boton) return;
    if (boton.dataset.accion === 'cerrar') cerrar();
    else if (boton.id === 'cpm-enviar') enviar();
    else if (boton.dataset.cerrarAcc) cerrarAccionable(boton.dataset.cerrarAcc);
    else if (boton.dataset.eliminar) eliminar(boton.dataset.eliminar);
  });
  campo.addEventListener('input', () => {
    actualizarEntrada();
    indiceMenu = 0;
    actualizarMenu();
  });
  campo.addEventListener('click', actualizarMenu);
  campo.addEventListener('blur', () => setTimeout(ocultarMenu, 150));
  interruptorAcc.addEventListener('change', actualizarEntrada);
  campoVence.addEventListener('input', actualizarEntrada);
  campoVence.addEventListener('change', actualizarEntrada);
  menu.addEventListener('mousedown', (e) => {
    e.preventDefault(); // no quitar el foco del texto
    const op = e.target.closest?.('[data-etiqueta]');
    if (op) insertarEtiqueta(op.dataset.etiqueta);
  });
  campo.addEventListener('keydown', (e) => {
    if (menu.style.display !== 'none' && opcionesMenu.length) {
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        indiceMenu = (indiceMenu + (e.key === 'ArrowDown' ? 1 : -1) + opcionesMenu.length) % opcionesMenu.length;
        pintarMenu();
        return;
      }
      if (e.key === 'Enter' || e.key === 'Tab') {
        e.preventDefault();
        insertarEtiqueta(opcionesMenu[indiceMenu].etiqueta);
        return;
      }
    }
    if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)) {
      e.preventDefault();
      enviar();
    }
  });
  document.addEventListener('keydown', alTeclear, true);

  document.body.appendChild(modal);
  campo.focus();
  await cargar();
  historial.scrollTop = historial.scrollHeight;
}
