import { supabase } from '../config/supabaseClient.js';

/**
 * Comentarios por orden de Control Central (093): historial tipo chat.
 * No se editan; "eliminar" marca el comentario como eliminado y lo deja en el historial.
 */

const LOTE = 150; // números de pedido por consulta (evita URLs enormes)

/**
 * Comentarios activos (no eliminados) de cada orden, del más antiguo al más nuevo.
 * @returns {Promise<Map<string, Array<{texto:string, autor_nombre:string, created_at:string}>>|null>} null si la consulta falló
 */
export async function fetchComentariosActivosPorPedidos(numerosOrden) {
  const ordenes = [...new Set((numerosOrden || []).map(String))];
  const porOrden = new Map();
  if (ordenes.length === 0) return porOrden;

  for (let i = 0; i < ordenes.length; i += LOTE) {
    const lote = ordenes.slice(i, i + LOTE);
    const { data, error } = await supabase
      .from('pedido_comentarios')
      .select('order_number, texto, autor_nombre, created_at, accionable, cerrado, fecha_vencimiento')
      .eq('eliminado', false)
      .in('order_number', lote)
      .order('created_at', { ascending: true })
      .range(0, 4999);
    if (error) {
      console.error('[comentariosPedidoService] Error leyendo comentarios:', error);
      return null;
    }
    (data || []).forEach((f) => {
      if (!porOrden.has(f.order_number)) porOrden.set(f.order_number, []);
      porOrden.get(f.order_number).push(f);
    });
  }
  return porOrden;
}

/** Historial completo de una orden (incluye los eliminados), del más antiguo al más nuevo. */
export async function fetchHistorialComentarios(orderNumber) {
  const { data, error } = await supabase
    .from('pedido_comentarios')
    .select('id, texto, created_by, autor_nombre, autor_rol, created_at, accionable, fecha_vencimiento, cerrado, cerrado_nombre, cerrado_at, eliminado, eliminado_nombre, eliminado_at')
    .eq('order_number', String(orderNumber))
    .order('created_at', { ascending: true });
  if (error) {
    console.error('[comentariosPedidoService] Error leyendo el historial:', error);
    throw new Error(error.message || 'No se pudo cargar el historial de comentarios.');
  }
  return data || [];
}

export async function agregarComentarioPedido(orderNumber, texto, accionable = false, fechaVencimiento = null, rolesEtiquetados = []) {
  const { error } = await supabase.rpc('agregar_comentario_pedido', {
    p_order_number: String(orderNumber),
    p_texto: String(texto ?? '').trim(),
    p_accionable: Boolean(accionable),
    p_fecha_vencimiento: accionable ? (fechaVencimiento || null) : null,
    p_roles_etiquetados: rolesEtiquetados
  });
  if (error) {
    console.error('[comentariosPedidoService] Error agregando el comentario:', error);
    throw new Error(error.message || 'No se pudo guardar el comentario.');
  }
}

export async function eliminarComentarioPedido(comentarioId) {
  const { error } = await supabase.rpc('eliminar_comentario_pedido', {
    p_comentario_id: comentarioId
  });
  if (error) {
    console.error('[comentariosPedidoService] Error eliminando el comentario:', error);
    throw new Error(error.message || 'No se pudo eliminar el comentario.');
  }
}

/** Cierra un comentario accionable (queda quién lo cerró y cuándo). */
export async function cerrarComentarioPedido(comentarioId) {
  const { error } = await supabase.rpc('cerrar_comentario_pedido', {
    p_comentario_id: comentarioId
  });
  if (error) {
    console.error('[comentariosPedidoService] Error cerrando el accionable:', error);
    throw new Error(error.message || 'No se pudo cerrar el accionable.');
  }
}

/**
 * Resumen de TODAS las órdenes con comentarios activos, para el filtro de Control Central.
 * Map(orden -> { abiertos, accionables, roles, minVence }): abiertos = accionables sin cerrar; accionables = todos los que ha tenido; roles = Set de roles etiquetados; minVence = fecha del pendiente que vence antes. null si la consulta falló.
 */
export async function fetchResumenComentarios() {
  const resumen = new Map();
  const TAM = 1000;
  for (let desde = 0; ; desde += TAM) {
    const { data, error } = await supabase
      .from('pedido_comentarios')
      .select('order_number, accionable, cerrado, fecha_vencimiento, roles_etiquetados')
      .eq('eliminado', false)
      .order('created_at', { ascending: true })
      .range(desde, desde + TAM - 1);
    if (error) {
      console.error('[comentariosPedidoService] Error leyendo el resumen de comentarios:', error);
      return null;
    }
    (data || []).forEach((f) => {
      const r = resumen.get(f.order_number) || { abiertos: 0, accionables: 0, roles: new Set(), minVence: null };
      if (f.accionable) r.accionables += 1;
      if (f.accionable && !f.cerrado) {
        r.abiertos += 1;
        // Vencimiento más próximo entre los accionables pendientes (AAAA-MM-DD ordena como texto).
        if (f.fecha_vencimiento && (!r.minVence || f.fecha_vencimiento < r.minVence)) r.minVence = f.fecha_vencimiento;
      }
      (f.roles_etiquetados || []).forEach((rol) => r.roles.add(rol));
      resumen.set(f.order_number, r);
    });
    if ((data || []).length < TAM) break;
  }
  return resumen;
}
