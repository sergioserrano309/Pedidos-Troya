import { supabase } from '../config/supabaseClient.js';

/**
 * Servicio de solo lectura para el módulo Propuesta (cotizador de
 * precios de suelas para el rol 'propuesta'). Consume precios_suelas +
 * sus 5 catálogos, protegidos por RLS en
 * supabase/sql/035_rls_precios_suelas.sql.
 *
 * Sin relación con preciosService.js (precios_por_par, compensación de
 * producción) ni con reglasPreciosService.js — dominios distintos que
 * comparten un nombre parecido.
 *
 * Con solo 438 filas se trae todo en una sola consulta y el filtrado
 * de la UI se hace 100% en memoria (ver propuestaPage.js).
 */
export async function fetchPreciosSuelas() {
  const { data, error } = await supabase
    .from('precios_suelas')
    .select(`
      id,
      bicolor,
      vira,
      esterilla,
      acabado,
      aplique,
      comentario,
      precio_distribuidor_con_iva,
      precio_fabricante_con_iva,
      referencia:referencias ( codigo ),
      material:materiales ( nombre ),
      cliente:clientes ( nombre ),
      color:colores ( nombre, categoria ),
      talla:tallas ( rango, talla_min, talla_max )
    `);

  if (error) {
    console.error('[preciosSuelasService] Error cargando precios_suelas:', error);
    throw new Error('No se pudieron cargar los precios de suelas.');
  }

  const filas = (data || [])
    .map((fila) => ({
      id: fila.id,
      referencia: fila.referencia?.codigo ?? '',
      material: fila.material?.nombre ?? '',
      cliente: fila.cliente?.nombre ?? '',
      colorNombre: fila.color?.nombre ?? '',
      colorCategoria: fila.color?.categoria ?? '',
      tallaRango: fila.talla?.rango ?? '',
      tallaMin: fila.talla?.talla_min ?? 0,
      bicolor: !!fila.bicolor,
      vira: !!fila.vira,
      esterilla: !!fila.esterilla,
      acabado: !!fila.acabado,
      aplique: !!fila.aplique,
      comentario: fila.comentario ?? '',
      precioDistribuidorConIva: Number(fila.precio_distribuidor_con_iva) || 0,
      precioFabricanteConIva: Number(fila.precio_fabricante_con_iva) || 0
    }))
    // El rol 'propuesta' solo debe ver precios generales (cliente=TODOS),
    // nunca los precios especiales exclusivos de un cliente puntual. Es un
    // filtro de la app, no un cambio en Supabase — los demás 437 registros
    // siguen intactos en precios_suelas.
    .filter((fila) => fila.cliente === 'TODOS');

  filas.sort((a, b) => a.referencia.localeCompare(b.referencia) || a.tallaMin - b.tallaMin);

  return filas;
}
