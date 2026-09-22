import { supabase } from '../config/supabaseClient.js';

/**
 * Servicio de órdenes de producción.
 *
 * Todo el cálculo de progreso vive en las vistas SQL
 * (vw_pedido_progreso / vw_item_progreso, ver supabase/sql/005_views_dashboard.sql)
 * para cumplir la regla de negocio: "el progreso nunca se almacena,
 * siempre se calcula". Este servicio solo consulta esas vistas y aplica
 * la visibilidad por rol.
 *
 * Visibilidad y cifras por rol:
 *   - comercial: ve TODAS las órdenes con las cifras globales del pedido
 *     completo (total_solicitado/procesado/pendiente/porcentaje).
 *   - refilado: ve TODAS las órdenes (es el punto de entrada).
 *   - acabado/mateado/empaque: ven solo las órdenes donde algo le ha
 *     sido enviado a SU proceso (entrada_<proceso> > 0) — un pedido
 *     completo va SIEMPRE a Acabado O a Mateado, nunca a ambos, así que
 *     esto no oculta nada que realmente les compete.
 *   Las cifras mostradas (Total Suelas/Procesadas/Pendientes/%) para
 *   cualquier rol de proceso se calculan contra el TOTAL del pedido
 *   completo (no contra "lo que me han enviado hasta ahora"), porque
 *   eventualmente el 100% del pedido pasa por su proceso (Acabado O
 *   Mateado, y siempre Empaque) — así el % sí puede llegar a 100% de
 *   forma consistente y la pestaña "Completadas" es alcanzable.
 */

const ROLE_TO_PROCESS = {
  refilado: 'Refilado',
  acabado: 'Acabado',
  mateado: 'Mateado',
  empaque: 'Empaque'
};

// Columnas especificas por proceso en vw_pedido_progreso (ver
// supabase/sql/005_views_dashboard.sql). "entrada" solo existe para
// Acabado/Mateado/Empaque y se usa UNICAMENTE para decidir visibilidad
// (algo me fue enviado realmente); las cifras mostradas (total/procesado/
// pendiente/porcentaje) se calculan contra el pedido completo.
const PROCESO_COLUMNAS = {
  Refilado: { total: 'total_refilado', procesado: 'procesado_refilado', pendiente: 'pendiente_refilado', porcentaje: 'porcentaje_refilado' },
  Acabado: { entrada: 'entrada_acabado', total: 'total_acabado', procesado: 'procesado_acabado', pendiente: 'pendiente_acabado', porcentaje: 'porcentaje_acabado' },
  Mateado: { entrada: 'entrada_mateado', total: 'total_mateado', procesado: 'procesado_mateado', pendiente: 'pendiente_mateado', porcentaje: 'porcentaje_mateado' },
  Empaque: { entrada: 'entrada_empaque', total: 'total_empaque', procesado: 'procesado_empaque', pendiente: 'pendiente_empaque', porcentaje: 'porcentaje_empaque' }
};

const PAGE_SIZE = 30;

/**
 * Qué pedidos ve un rol en una pestaña. La usan el listado Y las
 * opciones de los filtros (fetchFacetasOrdenes): si cada uno tuviera su
 * propia copia, tarde o temprano las listas ofrecerían valores que el
 * listado no muestra.
 */
function aplicarVisibilidad(query, user, tab) {
  const proceso = ROLE_TO_PROCESS[user.role];
  const columnas = proceso ? PROCESO_COLUMNAS[proceso] : null;

  if (columnas?.entrada) {
    // Visibilidad basada en si algo fue REALMENTE enviado a mi proceso
    // (>0), no en el "ultimo movimiento" del item (que cambia de proceso
    // cada vez que la orden avanza y hacia que la orden "desapareciera"
    // para roles previos con trabajo aun pendiente en su propio proceso).
    // Refilado no tiene columna "entrada": ve todas las ordenes siempre,
    // EXCEPTO las auto-enrutadas por regla (ver mas abajo).
    query = query.gt(columnas.entrada, 0);
  }

  if (user.role === 'refilado') {
    // Los pedidos que una regla de enrutamiento envio automaticamente
    // (ver supabase/sql/013_auto_enrutamiento_trigger.sql) nunca le
    // llegan a Refilado: no debe verlos ni procesarlos.
    query = query.or('destino_es_automatico.is.null,destino_es_automatico.eq.false');
  }

  if (user.role === 'validador') {
    // Validador ve el estado real de la orden (etapa_actual = 'Fin' solo
    // cuando ya pasó por Empaque, ver 018_fix_etapa_fin.sql), no el %
    // global (que puede llegar a 100% sin haber pasado por Empaque).
    if (tab === 'completadas') {
      query = query.eq('etapa_actual', 'Fin');
    } else {
      query = query.neq('etapa_actual', 'Fin');
    }
  } else {
    const columnaPorcentaje = columnas ? columnas.porcentaje : 'porcentaje_completado';
    if (tab === 'completadas') {
      query = query.eq(columnaPorcentaje, 100);
    } else {
      query = query.lt(columnaPorcentaje, 100);
    }
  }

  return query;
}

/**
 * @param {{ role: string }} user
 * @param {'activas'|'completadas'} tab
 * @param {{ page?: number, filters?: { orden?: string, cliente?: string, nombreSuela?: string, material?: string, color?: string, fecha?: string } }} options
 */
export async function fetchOrders(user, tab = 'activas', options = {}) {
  const { page = 0, filters = {} } = options;
  const { orden = '', cliente = '', nombreSuela = '', material = '', color = '', fecha = '' } = filters;

  const proceso = ROLE_TO_PROCESS[user.role];
  const columnas = proceso ? PROCESO_COLUMNAS[proceso] : null;

  // OJO: sin count:'exact' a propósito. Contar el total exacto de filas
  // obliga a Postgres a calcular la vista COMPLETA (todos los pedidos que
  // cumplan el filtro) antes de poder aplicar el LIMIT, aunque solo se
  // vayan a mostrar 30 — eso duplicaba el trabajo real en cada consulta.
  // En su lugar pedimos PAGE_SIZE+1 filas: si llegan más de PAGE_SIZE,
  // sabemos que hay una página siguiente, sin necesidad de contar todo.
  let query = aplicarVisibilidad(supabase.from('vw_pedido_progreso').select('*'), user, tab);

  if (orden.trim()) {
    query = query.ilike('order_number', `%${orden.trim()}%`);
  }
  // cliente/nombreSuela/material/color son dropdowns con valores EXACTOS tomados
  // de la base de datos (ver fetchOpcionesCliente/NombreSuela/Material/Color),
  // así que se filtran con igualdad exacta y del lado del servidor (antes de
  // paginar, para no perder resultados que caían en otra página).
  if (cliente.trim()) {
    query = query.eq('cliente', cliente.trim());
  }
  if (nombreSuela.trim()) {
    query = query.eq('nombre_referencia', nombreSuela.trim());
  }
  if (material.trim()) {
    query = query.eq('material', material.trim());
  }
  if (color.trim()) {
    query = query.eq('color', color.trim());
  }
  if (fecha.trim()) {
    query = query.eq('fecha_pedido', fecha.trim());
  }

  // Las pestañas Activas y Completadas se ordenan por FECHA DEL PEDIDO,
  // de la más vieja a la más nueva: lo que lleva más tiempo esperando es
  // lo más urgente, y así queda arriba. El número de orden queda solo
  // como desempate — y es imprescindible que esté: sin un criterio
  // único, dos pedidos del mismo día pueden intercambiarse entre una
  // página y la siguiente, duplicando uno y escondiendo otro.
  // Despachos y Registros no se tocan: tienen su propio servicio.
  query = query
    .order('fecha_pedido', { ascending: true, nullsFirst: false })
    .order('order_number', { ascending: true })
    .range(page * PAGE_SIZE, page * PAGE_SIZE + PAGE_SIZE); // PAGE_SIZE + 1 filas

  const { data, error } = await query;

  if (error) {
    console.error('[ordersService] Error obteniendo órdenes:', error);
    throw new Error('No se pudieron cargar las órdenes.');
  }

  const hayMas = (data || []).length > PAGE_SIZE;
  let filteredData = (data || []).slice(0, PAGE_SIZE);

  // Remapea las cifras especificas del proceso del rol a los nombres
  // genericos que usa el resto del frontend (total_solicitado,
  // total_procesado, total_pendiente, porcentaje_completado), para que
  // dashboard.js / orderDetail.js no necesiten saber de esta distincion.
  if (columnas) {
    filteredData = filteredData.map((row) => ({
      ...row,
      total_solicitado: row[columnas.total],
      total_procesado: row[columnas.procesado],
      total_pendiente: row[columnas.pendiente],
      porcentaje_completado: row[columnas.porcentaje],
      estatus_general: row[columnas.porcentaje] === 100 ? 'Completado' : 'En Proceso'
    }));
  }

  return { orders: filteredData, hayMas };
}

/**
 * Filas para calcular las opciones de los filtros en cascada (ver
 * src/lib/facetas.js): una por pedido visible en la pestaña, con solo
 * las columnas que filtran. Se pide al entrar a la pestaña, no en cada
 * cambio de filtro. Paginado de a 1000 porque ese es el tope por
 * consulta de Supabase.
 * @param {{ role: string }} user
 * @param {'activas'|'completadas'} tab
 */
export async function fetchFacetasOrdenes(user, tab = 'activas') {
  const LOTE = 1000;
  const filas = [];

  for (let desde = 0; ; desde += LOTE) {
    const query = aplicarVisibilidad(
      supabase.from('vw_pedido_progreso').select('order_number, cliente, nombre_referencia, material, color, fecha_pedido'),
      user,
      tab
    )
      .order('order_number', { ascending: false })
      .range(desde, desde + LOTE - 1);

    const { data, error } = await query;
    if (error) {
      console.error('[ordersService] Error obteniendo opciones de filtros:', error);
      return filas;
    }

    filas.push(...(data || []));
    if (!data || data.length < LOTE) break;
  }

  return filas;
}

/**
 * Opciones para los dropdowns de filtro (Nombre Suela/Material/Color),
 * leídas en vivo de p_pedidosh vía vistas DISTINCT (ver
 * supabase/sql/011_filtros_opciones.sql). Como se consultan cada vez que
 * se abre la página de Órdenes, un valor nuevo (ej. un color que nunca se
 * había usado) aparece automáticamente sin tocar código.
 */
export async function fetchOpcionesCliente() {
  const { data, error } = await supabase.from('vw_clientes').select('cliente');
  if (error) {
    console.error('[ordersService] Error obteniendo opciones de cliente:', error);
    return [];
  }
  return data.map((r) => r.cliente).filter(Boolean);
}

export async function fetchOpcionesNombreSuela() {
  const { data, error } = await supabase.from('vw_nombres_suela').select('nombre_referencia');
  if (error) {
    console.error('[ordersService] Error obteniendo opciones de nombre de suela:', error);
    return [];
  }
  return data.map((r) => r.nombre_referencia).filter(Boolean);
}

export async function fetchOpcionesMaterial() {
  const { data, error } = await supabase.from('vw_materiales').select('material');
  if (error) {
    console.error('[ordersService] Error obteniendo opciones de material:', error);
    return [];
  }
  return data.map((r) => r.material).filter(Boolean);
}

export async function fetchOpcionesColor() {
  const { data, error } = await supabase.from('vw_colores').select('color');
  if (error) {
    console.error('[ordersService] Error obteniendo opciones de color:', error);
    return [];
  }
  return data.map((r) => r.color).filter(Boolean);
}

/**
 * Detalle completo de una orden: todos sus ítems con progreso calculado.
 * @param {string} orderNumber
 */
export async function fetchOrderDetail(orderNumber) {
  const { data, error } = await supabase
    .from('vw_item_progreso')
    .select('*')
    .eq('order_number', orderNumber)
    .order('talla', { ascending: true });

  if (error) {
    console.error('[ordersService] Error obteniendo detalle de orden:', error);
    throw new Error('No se pudo cargar el detalle de la orden.');
  }

  return data || [];
}

/**
 * Movimientos de producción de una orden (todos los ítems), usados para
 * calcular cuánto queda pendiente en cada proceso específico (ver
 * src/lib/stageQuantities.js). production_movements tiene SELECT abierto
 * a todos los autenticados (ver supabase/sql/006_rls_policies.sql).
 * @param {string} orderNumber
 */
export async function fetchMovimientosOrden(orderNumber) {
  const { data, error } = await supabase
    .from('production_movements')
    .select('item_id, from_process, to_process, quantity')
    .eq('order_number', orderNumber);

  if (error) {
    console.error('[ordersService] Error obteniendo movimientos de orden:', error);
    return [];
  }

  return data || [];
}
