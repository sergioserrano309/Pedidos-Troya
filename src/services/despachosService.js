import { supabase } from '../config/supabaseClient.js';
import { esValidador, registrarAuditValidador } from './validatorService.js';
import { fetchPedidosCerradosForzado } from './cierreForzadoService.js';

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

  // Los pedidos cerrados a la fuerza por el Validador (057) ya no se despachan.
  const cerrados = await fetchPedidosCerradosForzado();
  if (cerrados.length) query = query.not('order_number', 'in', `(${cerrados.join(',')})`);

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
 * Filas para los filtros en cascada de "A Despachar" (ver
 * src/lib/facetas.js): una por pedido con saldo, solo las columnas que
 * filtran. Paginado de a 1000 (tope por consulta de Supabase).
 */
export async function fetchFacetasADespachar() {
  const LOTE = 1000;
  const filas = [];
  const cerrados = await fetchPedidosCerradosForzado();

  for (let desde = 0; ; desde += LOTE) {
    let q = supabase
      .from('vw_pedidos_por_despachar')
      .select('order_number, cliente, nombre_referencia, material, color');
    if (cerrados.length) q = q.not('order_number', 'in', `(${cerrados.join(',')})`);
    const { data, error } = await q
      .order('order_number', { ascending: false })
      .range(desde, desde + LOTE - 1);

    if (error) {
      console.error('[despachosService] Error obteniendo opciones de filtros:', error);
      return filas;
    }

    filas.push(...(data || []));
    if (!data || data.length < LOTE) break;
  }

  return filas;
}

/**
 * Saldo despachable por talla, para el modal "Crear Salida".
 *
 * Desde 044 la fuente es vw_item_despacho_saldo, no p_pedidosh: lo que
 * importa no es cuánto se pidió sino cuánto queda por despachar
 * (empacada − despachada). Un pedido que ya salió a medias vuelve a
 * aparecer con su saldo.
 *
 * @param {string[]} orderNumbers
 * @returns {Promise<Map<string, Array<{ itemId: string, talla: string, disponible: number, solicitada: number, despachada: number }>>>}
 */
export async function fetchSaldoPorDespachar(orderNumbers) {
  const { data, error } = await supabase
    .from('vw_item_despacho_saldo')
    .select('item_id, order_number, talla, cantidad_solicitada, cantidad_empacada, cantidad_despachada, cantidad_disponible, numero_despachos')
    .in('order_number', orderNumbers)
    .gt('cantidad_disponible', 0);

  if (error) {
    console.error('[despachosService] Error obteniendo saldo por despachar:', error);
    throw new Error('No se pudo calcular el saldo de los pedidos seleccionados.');
  }

  const porPedido = new Map();
  (data || []).forEach((f) => {
    const pedido = String(f.order_number);
    if (!porPedido.has(pedido)) porPedido.set(pedido, []);
    porPedido.get(pedido).push({
      itemId: f.item_id,
      talla: String(f.talla ?? '—'),
      // Las cuatro cifras que ve el usuario, con Despachos como receptor:
      //   recibida = lo que Empaque mandó   (empacada)
      //   despachada = lo ya despachado     ("Procesado" en esta pantalla)
      //   disponible = recibida − despachada ("Pendiente por despachar")
      // Siempre se cumple recibida = despachada + disponible.
      solicitada: f.cantidad_solicitada ?? 0,
      recibida: f.cantidad_empacada ?? 0,
      despachada: f.cantidad_despachada ?? 0,
      disponible: f.cantidad_disponible ?? 0,
      // En cuántos despachos distintos ha salido ya esta talla (052).
      numeroDespachos: f.numero_despachos ?? 0
    });
  });

  porPedido.forEach((tallas) =>
    tallas.sort((a, b) => a.talla.localeCompare(b.talla, undefined, { numeric: true }))
  );

  return porPedido;
}

/**
 * Estado de despacho de varios pedidos: completitud, porcentaje y en
 * cuántos despachos está cada uno. Alimenta los badges Sí/No del detalle
 * y el contador por pedido de "Crear Salida".
 * @param {string[]} orderNumbers
 * @returns {Promise<Map<string, { completo: boolean, porcentaje: number, despachadas: number, solicitadas: number }>>}
 */
export async function fetchEstadoPedidos(orderNumbers) {
  const { data, error } = await supabase
    .from('vw_pedido_despacho_estado')
    .select('order_number, pedido_completo, porcentaje_despachado, unidades_despachadas, unidades_solicitadas, numero_despachos')
    .in('order_number', orderNumbers);

  if (error) {
    console.error('[despachosService] Error obteniendo estado de pedidos:', error);
    throw new Error('No se pudo cargar el estado de despacho de los pedidos.');
  }

  const mapa = new Map();
  (data || []).forEach((f) => {
    mapa.set(String(f.order_number), {
      completo: !!f.pedido_completo,
      porcentaje: f.porcentaje_despachado ?? 0,
      despachadas: f.unidades_despachadas ?? 0,
      solicitadas: f.unidades_solicitadas ?? 0,
      // En cuántos despachos distintos está el pedido (044). Distinto del
      // contador por talla: dos tallas del mismo pedido pueden llevar
      // historias diferentes.
      despachos: f.numero_despachos ?? 0
    });
  });
  return mapa;
}

/**
 * Prende o apaga el visto bueno del Validador sobre un despacho (053).
 *
 * El RPC valida el rol en la base; aquí no se comprueba nada, porque una
 * comprobación en el navegador no es un permiso, es una cortesía. La
 * pantalla esconde el control a quien no es validador solo para no
 * ofrecer algo que va a fallar.
 *
 * @param {string} despachoId
 * @param {boolean} revisado
 */
export async function marcarDespachoRevisado(despachoId, revisado) {
  const { error } = await supabase.rpc('marcar_despacho_revisado', {
    p_despacho_id: despachoId,
    p_revisado: revisado
  });

  if (error) {
    console.error('[despachosService] Error marcando el despacho como revisado:', error);
    throw new Error(error.message || 'No se pudo cambiar el visto bueno del despacho.');
  }
}

/**
 * Ficha de los pedidos de un despacho: cliente, suela, material y color.
 *
 * Sale de vw_pedido_progreso — la misma vista que alimenta las tarjetas
 * del dashboard — y NO de vw_pedidos_por_despachar, que solo lista
 * pedidos con saldo: un pedido ya despachado del todo desaparece de
 * ahí, y el detalle de un despacho viejo se quedaría sin cliente.
 *
 * Si la consulta falla NO tumba el detalle: el modal sigue mostrando
 * bultos, tallas y saldos, que es su información esencial, y la ficha
 * queda en blanco.
 *
 * @param {string[]} orderNumbers
 * @returns {Promise<Map<string, { cliente: string, nombreSuela: string, material: string, color: string }>>}
 */
export async function fetchInfoPedidos(orderNumbers) {
  const mapa = new Map();
  if (!orderNumbers || orderNumbers.length === 0) return mapa;

  const { data, error } = await supabase
    .from('vw_pedido_progreso')
    .select('order_number, cliente, nombre_referencia, material, color')
    .in('order_number', orderNumbers);

  if (error) {
    console.error('[despachosService] Error obteniendo la ficha de los pedidos:', error);
    return mapa;
  }

  (data || []).forEach((f) => {
    mapa.set(String(f.order_number), {
      cliente: f.cliente || '',
      nombreSuela: f.nombre_referencia || '',
      material: f.material || '',
      color: f.color || ''
    });
  });

  // Vira/Acabado/Esterilla/Marquilla: los mismos booleanos que usa el Excel
  // (vw_despacho_orden_detalle, salen de p_pedidosh). Consulta aparte y
  // tolerante a fallos: si falla, la ficha se muestra sin esos cuatro datos.
  const { data: attrs, error: errAttrs } = await supabase
    .from('vw_despacho_orden_detalle')
    .select('order_number, vira, acabado, esterilla, marquilla')
    .in('order_number', orderNumbers);

  if (errAttrs) {
    console.error('[despachosService] Error obteniendo Vira/Acabado/Esterilla/Marquilla:', errAttrs);
    return mapa;
  }

  (attrs || []).forEach((a) => {
    const ficha = mapa.get(String(a.order_number));
    if (ficha && ficha.vira === undefined) {
      ficha.vira = !!a.vira;
      ficha.acabado = !!a.acabado;
      ficha.esterilla = !!a.esterilla;
      ficha.marquilla = !!a.marquilla;
    }
  });

  return mapa;
}

/**
 * Crea el despacho COMPLETO en una sola transacción atómica (RPC
 * crear_despacho, ver supabase/sql/045_crear_despacho_parcial.sql).
 *
 * Desde 051 el usuario indica cuántas unidades salen de cada talla
 * (`items`). El RPC vuelve a validar el saldo contra la base y además
 * hay un trigger de último recurso, así que despachar de más es
 * imposible aunque el cliente mande cualquier cosa.
 *
 * Los errores de validación llegan en español tal cual los lanzó el RPC
 * (ej. "No hay saldo suficiente para despachar: pedido 3121 talla 35...").
 *
 * @param {{ orderNumbers: string[], totalBultos: number, pesos: number[], asignaciones: Array<{ order_number: string, bulto_numero: number }>, items: Array<{ item_id: string, cantidad: number }> }} datos
 */
export async function crearDespacho({ orderNumbers, totalBultos, pesos, asignaciones, items }) {
  const { data, error } = await supabase.rpc('crear_despacho', {
    p_order_numbers: orderNumbers,
    p_total_bultos: totalBultos,
    p_pesos: pesos,
    p_asignaciones: asignaciones,
    p_items: items
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
        { pedidos: orderNumbers, total_bultos: totalBultos, pesos, asignaciones, items },
        null
      );
    }
  } catch (auditError) {
    console.error('[despachosService] Error registrando audit:', auditError);
    // No lanzar error — el despacho ya quedó creado.
  }

  return despacho;
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

/**
 * Acordeón Despachos > Despachado: una fila por despacho con sus agregados (bultos,
 * kilos, unidades, órdenes). Ver vw_despachos_registro en
 * supabase/sql/039_registros_despachos.sql.
 * @param {{ page?: number, filters?: { fecha?: string, consecutivo?: string, orden?: string } }} options
 */
export async function fetchRegistrosDespachos(options = {}) {
  const { page = 0, filters = {} } = options;
  const { fecha = '', consecutivo = '', orden = '' } = filters;

  let query = supabase.from('vw_despachos_registro').select('*');

  if (fecha.trim()) {
    query = query.gte('created_at', `${fecha}T00:00:00`).lt('created_at', `${fecha}T23:59:59.999`);
  }
  if (consecutivo.trim()) query = query.ilike('consecutivo', `%${consecutivo.trim()}%`);
  if (orden.trim()) query = query.contains('order_numbers', [orden.trim()]);

  query = query
    .order('created_at', { ascending: false })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE);

  const { data, error } = await query;

  if (error) {
    console.error('[despachosService] Error obteniendo registros de despachos:', error);
    throw new Error('No se pudieron cargar los registros de despachos.');
  }

  const hayMas = (data || []).length > PAGE_SIZE;
  return { despachos: (data || []).slice(0, PAGE_SIZE), hayMas };
}

/**
 * Lo que realmente salió en UN despacho, agrupado por pedido.
 *
 * Desde 044 la fuente es despacho_orden_items, no p_pedidosh: con
 * despachos parciales, mostrar el total del pedido sería engañoso — hay
 * que mostrar lo que se despachó en esta salida concreta.
 *
 * @param {string} despachoId
 * @returns {Promise<Map<string, Array<{ talla: string, unidades: number }>>>}
 */
export async function fetchItemsDespacho(despachoId) {
  const { data, error } = await supabase
    .from('despacho_orden_items')
    .select('order_number, talla, cantidad')
    .eq('despacho_id', despachoId);

  if (error) {
    console.error('[despachosService] Error obteniendo items del despacho:', error);
    throw new Error('No se pudieron cargar las tallas del despacho.');
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

/**
 * Elimina un despacho COMPLETO con motivo obligatorio. No existe borrado
 * parcial: el RPC borra el despacho y sus órdenes/bultos/asignaciones en
 * cascada, dejando snapshot en log_eliminaciones.
 * El mensaje de error del RPC llega en español y se muestra tal cual.
 * @param {string} despachoId
 * @param {string} motivo
 */
export async function eliminarDespachoConMotivo(despachoId, motivo) {
  const { error } = await supabase.rpc('eliminar_despacho_con_motivo', {
    p_despacho_id: despachoId,
    p_motivo: motivo
  });

  if (error) {
    console.error('[despachosService] Error eliminando despacho:', error);
    throw new Error(error.message || 'No se pudo eliminar el despacho.');
  }
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
