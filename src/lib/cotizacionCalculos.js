/**
 * Cálculos puros del cotizador de precios de suelas (módulo Propuesta).
 * Sin dependencias de Supabase ni del DOM.
 */

export const RECARGO_FUERA_BOGOTA = 400;

/**
 * Items opcionales del "canasto". vira/acabado/aplique tienen columna
 * homónima en precios_suelas: si la fila elegida ya la trae en true,
 * el item queda incluido de forma forzosa (no se puede agregar de
 * nuevo ni quitar). silbatrín suelto/inyectado y marquilla no tienen
 * columna asociada, así que siempre quedan libres de agregar/quitar.
 */
export const ITEMS_CANASTO = [
  { key: 'silbatrinSuelto', label: 'Silbatrín suelto', precio: 600 },
  { key: 'silbatrinInyectado', label: 'Silbatrín inyectado', precio: 1000 },
  { key: 'marquilla', label: 'Marquilla', precio: 200 },
  { key: 'vira', label: 'Vira', precio: 1000, columnaFila: 'vira' },
  { key: 'acabado', label: 'Acabado', precio: 1600, columnaFila: 'acabado' },
  { key: 'aplique', label: 'Aplique', precio: 400, columnaFila: 'aplique' }
];

/** Marca, para la fila elegida, qué items del canasto ya vienen incluidos. */
export function itemsCanastoParaFila(fila) {
  return ITEMS_CANASTO.map((item) => ({
    ...item,
    incluido: item.columnaFila ? !!fila[item.columnaFila] : false
  }));
}

/**
 * @param {object} params
 * @param {number} params.precioBase           Precio con IVA de la fila elegida (distribuidor o fabricante)
 * @param {boolean} params.esFabricante
 * @param {boolean} params.fueraDeBogota
 * @param {Set<string>|string[]} params.itemsSeleccionados  Keys de ITEMS_CANASTO marcados por el usuario
 * @param {object} params.fila                  Fila de precios_suelas elegida
 */
export function calcularCotizacion({ precioBase, esFabricante, fueraDeBogota, itemsSeleccionados, fila }) {
  const seleccionados = itemsSeleccionados instanceof Set ? itemsSeleccionados : new Set(itemsSeleccionados);
  const recargoUbicacion = esFabricante && fueraDeBogota ? RECARGO_FUERA_BOGOTA : 0;

  const lineas = itemsCanastoParaFila(fila)
    .filter((item) => item.incluido || seleccionados.has(item.key))
    .map((item) => ({
      key: item.key,
      label: item.label,
      // Un item ya incluido en la fila hace parte del precio base — no
      // se suma de nuevo, solo se muestra como informativo.
      precio: item.incluido ? 0 : item.precio,
      incluido: item.incluido
    }));

  const totalExtras = lineas.reduce((sum, l) => sum + l.precio, 0);
  const total = precioBase + recargoUbicacion + totalExtras;

  return { precioBase, recargoUbicacion, lineas, total };
}

/**
 * Política de descuento por pronto pago. Depende únicamente de dónde se
 * despacha el cliente (Bogotá o fuera de Bogotá) — independiente de si la
 * cotización es a distribuidor o fabricante.
 */
export const DESCUENTOS_BOGOTA = [
  { rango: 'Hasta 15 días', pct: 0.12 },
  { rango: '16 - 30 días', pct: 0.10 },
  { rango: '31 - 60 días', pct: 0.07 },
  { rango: '61 - 90 días', pct: 0.04 }
];

export const DESCUENTOS_FUERA_BOGOTA = [
  { rango: 'Hasta 30 días', pct: 0.06 },
  { rango: '31 - 60 días', pct: 0.04 },
  { rango: '61 - 90 días', pct: 0.02 }
];

const FACTOR_IVA = 1.19;

/**
 * Precio con descuento por banda de días de pago. El total que recibe ya
 * tiene el IVA incluido (igual que el resto del cotizador); para aplicar
 * el % de descuento sobre el valor real del producto (sin IVA) se
 * "desarma" el IVA, se descuenta, y se vuelve a "armar" — el usuario no ve
 * ninguno de estos pasos intermedios, solo el precio final por banda.
 *
 * @param {number} totalConIva       Total ya calculado por calcularCotizacion()
 * @param {boolean} fueraDeBogota
 */
export function calcularTablaDescuentos(totalConIva, fueraDeBogota) {
  const bandas = fueraDeBogota ? DESCUENTOS_FUERA_BOGOTA : DESCUENTOS_BOGOTA;
  const subtotal = totalConIva / FACTOR_IVA;

  return bandas.map((banda) => {
    const subtotalDescontado = subtotal * (1 - banda.pct);
    return { ...banda, totalConDescuento: subtotalDescontado * FACTOR_IVA };
  });
}
