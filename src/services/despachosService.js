import { supabase } from '../config/supabaseClient.js';
import { esValidador, registrarAuditValidador } from './validatorService.js';

/**
 * Servicio del módulo Despachos (Fase 1 — operado únicamente por el rol
 * Empaque, ver plan). Todo el cálculo de elegibilidad ("100% completo en
 * Empaque y aún no despachado") vive en vw_pedidos_por_despachar (ver
 * supabase/sql/028_despachos_vistas.sql) — este servicio solo consulta
 * esa vista y las tablas de despachos, igual que ordersService.js hace
 * con vw_pedido_progreso.
 */

const PAGE_SIZE = 30;

// Mismas columnas por proceso que ordersService.js (PROCESO_COLUMNAS.Empaque)
// — se remapean a los nombres genéricos que ya espera la tarjeta .orden-fila
// reutilizada (total_solicitado/procesado/pendiente/porcentaje_completado).
function remapearAGenerico(row) {
  return {
    ...row,
    total_solicitado: row.total_empaque,
    total_procesado: row.procesado_empaque,
    total_pendiente: row.pendiente_empaque,
    porcentaje_completado: row.porcentaje_empaque,
    estatus_general: row.porcentaje_empaque === 100 ? 'Completado' : 'En Proceso'
  };
}

/**
 * @param {{ page?: number, filters?: { orden?: string, cliente?: string, nombreSuela?: string, material?: string, color?: string } }} options
 */
export async function fetchPedidosPorDespachar(options = {}) {
  const { page = 0, filters = {} } = options;
  const { orden = '', cliente = '', nombreSuela = '', material = '', color = '' } = filters;

  let query = supabase.from('vw_pedidos_por_despachar').select('*');

  if (orden.trim()) query = query.ilike('order_number', `%${orden.trim()}%`);
  if (cliente.trim()) query = query.eq('cliente', cliente.trim());
  if (nombreSuela.trim()) query = query.eq('nombre_referencia', nombreSuela.trim());
  if (material.trim()) query = query.eq('material', material.trim());
  if (color.trim()) query = query.eq('color', color.trim());

  query = query
    .order('order_number', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE); // PAGE_SIZE + 1 filas, ver ordersService.js

  const { data, error } = await query;

  if (error) {
    console.error('[despachosService] Error obteniendo pedidos por despachar:', error);
    throw new Error('No se pudieron cargar los pedidos por despachar.');
  }

  const hayMas = (data || []).length > PAGE_SIZE;
  const pedidos = (data || []).slice(0, PAGE_SIZE).map(remapearAGenerico);

  return { pedidos, hayMas };
}

/**
 * Resumen (total de unidades + desglose por talla) para el modal "Crear
 * Salida", calculado directamente sobre p_pedidosh (única fuente de la
 * verdad para tallas/cantidades — solo lectura, RLS abierta a
 * authenticated, ver 006_rls_policies.sql).
 * @param {string[]} orderNumbers
 */
export async function fetchPreviewCreacionDespacho(orderNumbers) {
  const { data, error } = await supabase
    .from('p_pedidosh')
    .select('"PedidoNo", "Talla", "CantidadP"')
    .in('PedidoNo', orderNumbers)
    .or('Cancelado.is.null,Cancelado.eq.false');

  if (error) {
    console.error('[despachosService] Error obteniendo resumen de pedidos:', error);
    throw new Error('No se pudo calcular el resumen de los pedidos seleccionados.');
  }

  const filas = data || [];
  const totalUnidades = filas.reduce((sum, f) => sum + (f.CantidadP || 0), 0);

  const porTallaMapa = new Map();
  filas.forEach((f) => {
    const talla = String(f.Talla ?? '—');
    porTallaMapa.set(talla, (porTallaMapa.get(talla) || 0) + (f.CantidadP || 0));
  });
  const porTalla = [...porTallaMapa.entries()]
    .map(([talla, unidades]) => ({ talla, unidades }))
    .sort((a, b) => a.talla.localeCompare(b.talla, undefined, { numeric: true }));

  return { totalUnidades, porTalla };
}

/**
 * Crea el despacho COMPLETO (RPC atómico crear_despacho, ver
 * supabase/sql/031_despachos_crear_atomico.sql): valida que cada pedido
 * esté 100% completo en Empaque y sin despacho previo, que cada pedido
 * tenga ≥1 bulto asignado y que la unión de bultos usados sea EXACTAMENTE
 * {1..totalBultos} — todo en una sola transacción. Si algo falla, no se
 * crea absolutamente nada (el usuario corrige en el mismo modal y
 * reintenta). Cualquier error de validación llega en error.message tal
 * cual lo lanzó el RPC (ej. "Los siguientes pedidos no tienen ningún
 * bulto asignado: 3201").
 * @param {{ orderNumbers: string[], totalBultos: number, pesos: number[], asignaciones: Array<{ order_number: string, bulto_numero: number }> }} datos
 */
export async function crearDespacho({ orderNumbers, totalBultos, pesos, asignaciones }) {
  const { data, error } = await supabase.rpc('crear_despacho', {
    p_order_numbers: orderNumbers,
    p_total_bultos: totalBultos,
    p_pesos: pesos,
    p_asignaciones: asignaciones
  });

  if (error) {
    console.error('[despachosService] Error creando despacho:', error);
    throw new Error(error.message || 'No se pudo crear el despacho.');
  }

  const despacho = data?.[0];

  try {
    if (esValidador() && despacho) {
      await registrarAuditValidador(
        'crear_despacho',
        'Empaque',
        despacho.consecutivo,
        null,
        { pedidos: orderNumbers, total_bultos: totalBultos, pesos, asignaciones },
        null
      );
    }
  } catch (auditError) {
    console.error('[despachosService] Error registrando audit:', auditError);
    // No lanzar error — el despacho ya quedó creado.
  }

  return despacho;
}

/**
 * @param {{ page?: number, filters?: { fecha?: string, consecutivo?: string, orden?: string } }} options
 */
export async function fetchDespachos(options = {}) {
  const { page = 0, filters = {} } = options;
  const { fecha = '', consecutivo = '', orden = '' } = filters;

  let query = supabase.from('vw_despachos_resumen').select('*');

  if (fecha.trim()) {
    // Rango del día completo — created_at es timestamptz.
    query = query.gte('created_at', `${fecha}T00:00:00`).lt('created_at', `${fecha}T23:59:59.999`);
  }
  if (consecutivo.trim()) query = query.ilike('consecutivo', `%${consecutivo.trim()}%`);
  if (orden.trim()) query = query.contains('order_numbers', [orden.trim()]);

  query = query
    .order('created_at', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE);

  const { data, error } = await query;

  if (error) {
    console.error('[despachosService] Error obteniendo despachos:', error);
    throw new Error('No se pudieron cargar los despachos.');
  }

  const hayMas = (data || []).length > PAGE_SIZE;
  const despachos = (data || []).slice(0, PAGE_SIZE);

  return { despachos, hayMas };
}

export async function fetchDetalleDespacho(despachoId) {
  const { data, error } = await supabase
    .from('vw_despachos_resumen')
    .select('*')
    .eq('id', despachoId)
    .single();

  if (error) {
    console.error('[despachosService] Error obteniendo detalle de despacho:', error);
    throw new Error('No se pudo cargar el detalle del despacho.');
  }

  return data;
}

/**
 * Asignaciones pedido→bulto ya confirmadas (el despacho siempre queda
 * creado con asignacion_confirmada=true desde 031 — no existe un estado
 * "borrador" en la base de datos). Alimenta el resumen de solo lectura
 * que se abre al hacer clic en la tarjeta de un despacho.
 */
export async function fetchAsignacionesDespacho(despachoId) {
  const { data, error } = await supabase
    .from('despacho_orden_bultos')
    .select('order_number, bulto_numero')
    .eq('despacho_id', despachoId);

  if (error) {
    console.error('[despachosService] Error obteniendo asignaciones de bultos:', error);
    throw new Error('No se pudieron cargar las asignaciones de bultos.');
  }

  return data || [];
}

/** Bultos (número + peso) de un despacho, para el resumen de solo lectura. */
export async function fetchBultosDespacho(despachoId) {
  const { data, error } = await supabase
    .from('despacho_bultos')
    .select('bulto_numero, peso')
    .eq('despacho_id', despachoId)
    .order('bulto_numero', { ascending: true });

  if (error) {
    console.error('[despachosService] Error obteniendo bultos del despacho:', error);
    throw new Error('No se pudieron cargar los bultos del despacho.');
  }

  return data || [];
}
