import { supabase } from '../config/supabaseClient.js';
import { esValidador, registrarAuditValidador } from './validatorService.js';
import { fetchPedidosCerradosForzado } from './cierreForzadoService.js';

/**
 * Servicio de Salidas(A) (SQL 092): registro INFORMATIVO de lo que Acabado
 * saca de su proceso. Es un módulo paralelo a Despachos: lee lo que Acabado
 * procesó (production_movements) pero nunca escribe en ello, así que no puede
 * alterar el flujo Acabado -> Empaque. Mismas ideas que despachosService.js,
 * con tablas y funciones propias.
 */

const PAGE_SIZE = 30;

// Las tarjetas de "Por Salir" reutilizan la plantilla .orden-fila: se remapean las
// columnas de Acabado a los nombres genéricos que espera (igual que Despachos con Empaque).
function remapearAGenerico(row) {
  return {
    ...row,
    total_solicitado: row.total_solicitado,
    total_procesado: row.procesado_acabado,
    total_pendiente: row.pendiente_acabado,
    porcentaje_completado: row.porcentaje_acabado,
    estatus_general: row.porcentaje_acabado === 100 ? 'Completado' : 'En Proceso'
  };
}

/**
 * @param {{ page?: number, filters?: { orden?: string, cliente?: string, nombreSuela?: string, material?: string, color?: string } }} options
 */
export async function fetchPedidosPorSalir(options = {}) {
  const { page = 0, filters = {} } = options;
  const { orden = '', cliente = '', nombreSuela = '', material = '', color = '' } = filters;

  let query = supabase.from('vw_pedidos_por_salir_a').select('*');

  // Los pedidos cerrados a la fuerza no admiten salidas nuevas (igual que Despachos).
  const cerrados = await fetchPedidosCerradosForzado();
  if (cerrados.length) query = query.not('order_number', 'in', `(${cerrados.join(',')})`);

  if (orden.trim()) query = query.ilike('order_number', `%${orden.trim()}%`);
  if (cliente.trim()) query = query.eq('cliente', cliente.trim());
  if (nombreSuela.trim()) query = query.eq('nombre_referencia', nombreSuela.trim());
  if (material.trim()) query = query.eq('material', material.trim());
  if (color.trim()) query = query.eq('color', color.trim());

  query = query
    .order('order_number', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE); // PAGE_SIZE + 1 filas

  const { data, error } = await query;
  if (error) {
    console.error('[salidasAcabadoService] Error obteniendo pedidos por salir:', error);
    throw new Error('No se pudieron cargar los pedidos por salir.');
  }

  const hayMas = (data || []).length > PAGE_SIZE;
  const pedidos = (data || []).slice(0, PAGE_SIZE).map(remapearAGenerico);
  return { pedidos, hayMas };
}

/** Filas para los filtros en cascada de "Por Salir": una por pedido con saldo. */
export async function fetchFacetasPorSalir() {
  const LOTE = 1000;
  const filas = [];
  const cerrados = await fetchPedidosCerradosForzado();

  for (let desde = 0; ; desde += LOTE) {
    let q = supabase
      .from('vw_pedidos_por_salir_a')
      .select('order_number, cliente, nombre_referencia, material, color');
    if (cerrados.length) q = q.not('order_number', 'in', `(${cerrados.join(',')})`);
    const { data, error } = await q
      .order('order_number', { ascending: false })
      .range(desde, desde + LOTE - 1);

    if (error) {
      console.error('[salidasAcabadoService] Error obteniendo opciones de filtros:', error);
      return filas;
    }
    filas.push(...(data || []));
    if (!data || data.length < LOTE) break;
  }
  return filas;
}

/**
 * Saldo por talla para "Crear Salida Acabados".
 * recibida = procesado por Acabado · salida = ya sacado · disponible = recibida - salida.
 * @param {string[]} orderNumbers
 * @returns {Promise<Map<string, Array<{ itemId: string, talla: string, solicitada: number, recibida: number, salida: number, disponible: number, numeroSalidas: number }>>>}
 */
export async function fetchSaldoPorSalir(orderNumbers) {
  const { data, error } = await supabase
    .from('vw_item_salida_a_saldo')
    .select('item_id, order_number, talla, cantidad_solicitada, cantidad_procesada, cantidad_salida, cantidad_disponible, numero_salidas')
    .in('order_number', orderNumbers)
    .gt('cantidad_disponible', 0);

  if (error) {
    console.error('[salidasAcabadoService] Error obteniendo saldo por salir:', error);
    throw new Error('No se pudo calcular el saldo de los pedidos seleccionados.');
  }

  const porPedido = new Map();
  (data || []).forEach((f) => {
    const pedido = String(f.order_number);
    if (!porPedido.has(pedido)) porPedido.set(pedido, []);
    porPedido.get(pedido).push({
      itemId: f.item_id,
      talla: String(f.talla ?? '—'),
      solicitada: f.cantidad_solicitada ?? 0,
      recibida: f.cantidad_procesada ?? 0,
      salida: f.cantidad_salida ?? 0,
      disponible: f.cantidad_disponible ?? 0,
      numeroSalidas: f.numero_salidas ?? 0
    });
  });

  porPedido.forEach((tallas) =>
    tallas.sort((a, b) => a.talla.localeCompare(b.talla, undefined, { numeric: true }))
  );
  return porPedido;
}

/** En cuántas salidas está cada pedido (contador de "Crear Salida"). */
export async function fetchSalidasPorPedido(orderNumbers) {
  const mapa = new Map();
  if (!orderNumbers?.length) return mapa;

  const { data, error } = await supabase
    .from('vw_pedido_salida_a_estado')
    .select('order_number, numero_salidas, unidades_salidas')
    .in('order_number', orderNumbers);

  if (error) {
    // Informativo: si falla, el contador queda en 0 y la salida se puede crear igual.
    console.error('[salidasAcabadoService] Error obteniendo el estado de salidas por pedido:', error);
    return mapa;
  }
  (data || []).forEach((f) => mapa.set(String(f.order_number), { salidas: f.numero_salidas ?? 0, unidades: f.unidades_salidas ?? 0 }));
  return mapa;
}

/**
 * Crea la salida COMPLETA en una sola transacción (RPC crear_salida_a).
 * Los errores de validación llegan en español tal cual los lanzó la base.
 * @param {{ orderNumbers: string[], totalBultos: number, pesos: number[], asignaciones: Array<{ order_number: string, bulto_numero: number }>, items: Array<{ item_id: string, cantidad: number }>, comentario?: string }} datos
 */
export async function crearSalidaAcabado({ orderNumbers, totalBultos, pesos, asignaciones, items, comentario = '' }) {
  const params = {
    p_order_numbers: orderNumbers,
    p_total_bultos: totalBultos,
    p_pesos: pesos,
    p_asignaciones: asignaciones,
    p_items: items
  };
  const texto = String(comentario ?? '').trim();
  if (texto) params.p_comentario = texto;

  const { data, error } = await supabase.rpc('crear_salida_a', params);
  if (error) {
    console.error('[salidasAcabadoService] Error creando la salida:', error);
    throw new Error(error.message || 'No se pudo crear la salida.');
  }

  const salida = data?.[0];
  try {
    if (esValidador() && salida) {
      await registrarAuditValidador(
        'crear_salida_a', 'Acabado', salida.consecutivo, null,
        { pedidos: orderNumbers, total_bultos: totalBultos, pesos, asignaciones, items }, null
      );
    }
  } catch (auditError) {
    console.error('[salidasAcabadoService] Error registrando audit:', auditError);
  }
  return salida;
}

/**
 * Listado de la sección "Salida": una fila por salida con sus agregados.
 * @param {{ page?: number, filters?: { fecha?: string, consecutivo?: string, orden?: string, cliente?: string } }} options
 */
export async function fetchRegistrosSalidas(options = {}) {
  const { page = 0, filters = {} } = options;
  const { fecha = '', consecutivo = '', orden = '', cliente = '' } = filters;

  let query = supabase.from('vw_salidas_a_registro').select('*');

  if (fecha.trim()) {
    // Día de calendario en hora de Colombia (UTC-5).
    query = query.gte('created_at', `${fecha}T00:00:00-05:00`).lt('created_at', `${fecha}T23:59:59.999-05:00`);
  }
  const digitos = consecutivo.replace(/\D/g, '');
  if (digitos) query = query.ilike('consecutivo', `%${digitos}%`);
  if (orden.trim()) query = query.contains('order_numbers', [orden.trim()]);
  if (cliente.trim()) query = query.contains('clientes', [cliente.trim()]);

  query = query
    .order('created_at', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE);

  const { data, error } = await query;
  if (error) {
    console.error('[salidasAcabadoService] Error obteniendo las salidas:', error);
    throw new Error('No se pudieron cargar las salidas.');
  }

  const hayMas = (data || []).length > PAGE_SIZE;
  return { salidas: (data || []).slice(0, PAGE_SIZE), hayMas };
}

/** Clientes que ya tienen al menos una salida (para el filtro de "Salida"). */
export async function fetchClientesConSalida() {
  const LOTE = 1000;
  const clientes = new Set();

  for (let desde = 0; ; desde += LOTE) {
    const { data, error } = await supabase
      .from('vw_salidas_a_registro')
      .select('clientes')
      .range(desde, desde + LOTE - 1);

    if (error) {
      console.warn('[salidasAcabadoService] No se pudieron leer los clientes de las salidas:', error);
      return [];
    }
    (data || []).forEach((f) => (f.clientes || []).forEach((c) => c && clientes.add(c)));
    if (!data || data.length < LOTE) break;
  }
  return [...clientes].sort((a, b) => a.localeCompare(b, 'es'));
}

/** Cabecera de una salida (para el detalle). */
export async function fetchDetalleSalida(salidaId) {
  const { data, error } = await supabase
    .from('vw_salidas_a_registro')
    .select('*')
    .eq('id', salidaId)
    .single();

  if (error) {
    console.error('[salidasAcabadoService] Error obteniendo el detalle de la salida:', error);
    throw new Error('No se pudo cargar el detalle de la salida.');
  }
  return { ...data, comentario: data.comentario || '' };
}

export async function fetchAsignacionesSalida(salidaId) {
  const { data, error } = await supabase
    .from('salida_a_orden_bultos')
    .select('order_number, bulto_numero')
    .eq('salida_id', salidaId);

  if (error) {
    console.error('[salidasAcabadoService] Error obteniendo asignaciones de bultos:', error);
    throw new Error('No se pudieron cargar las asignaciones de bultos.');
  }
  return data || [];
}

export async function fetchBultosSalida(salidaId) {
  const { data, error } = await supabase
    .from('salida_a_bultos')
    .select('bulto_numero, peso')
    .eq('salida_id', salidaId)
    .order('bulto_numero', { ascending: true });

  if (error) {
    console.error('[salidasAcabadoService] Error obteniendo bultos de la salida:', error);
    throw new Error('No se pudieron cargar los bultos de la salida.');
  }
  return data || [];
}

/** Lo que salió en UNA salida, agrupado por pedido. */
export async function fetchItemsSalida(salidaId) {
  const { data, error } = await supabase
    .from('salida_a_orden_items')
    .select('order_number, talla, cantidad')
    .eq('salida_id', salidaId);

  if (error) {
    console.error('[salidasAcabadoService] Error obteniendo items de la salida:', error);
    throw new Error('No se pudieron cargar las tallas de la salida.');
  }

  const porPedido = new Map();
  (data || []).forEach((f) => {
    const pedido = String(f.order_number);
    if (!porPedido.has(pedido)) porPedido.set(pedido, []);
    porPedido.get(pedido).push({ talla: String(f.talla ?? '—'), unidades: f.cantidad ?? 0 });
  });
  porPedido.forEach((tallas) =>
    tallas.sort((a, b) => a.talla.localeCompare(b.talla, undefined, { numeric: true }))
  );
  return porPedido;
}

/** Elimina una salida COMPLETA con motivo obligatorio (la base explica por qué si no se puede). */
export async function eliminarSalidaConMotivo(salidaId, motivo) {
  const { error } = await supabase.rpc('eliminar_salida_a_con_motivo', {
    p_salida_id: salidaId,
    p_motivo: motivo
  });
  if (error) {
    console.error('[salidasAcabadoService] Error eliminando la salida:', error);
    throw new Error(error.message || 'No se pudo eliminar la salida.');
  }
}

/** Visto bueno del Validador: bloquea (o libera) la eliminación de la salida. */
export async function marcarSalidaRevisada(salidaId, revisado) {
  const { error } = await supabase.rpc('marcar_salida_a_revisada', {
    p_salida_id: salidaId,
    p_revisado: revisado
  });
  if (error) {
    console.error('[salidasAcabadoService] Error marcando la salida como revisada:', error);
    throw new Error(error.message || 'No se pudo cambiar el visto bueno de la salida.');
  }
}

/** Comentario editable solo por el Validador (texto vacío = quitar). */
export async function editarComentarioSalida(salidaId, comentario) {
  const { error } = await supabase.rpc('editar_comentario_salida_a', {
    p_salida_id: salidaId,
    p_comentario: String(comentario ?? '').trim()
  });
  if (error) {
    console.error('[salidasAcabadoService] Error editando el comentario de la salida:', error);
    throw new Error(error.message || 'No se pudo guardar el comentario de la salida.');
  }
}
