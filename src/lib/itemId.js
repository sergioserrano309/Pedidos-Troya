/**
 * Generador determinístico de ID lógico de 10 dígitos para un ítem de producción.
 *
 * La tabla "Pedidos Prueba" (sincronizada por el ERP externo) NO tiene primary key.
 * Esta función genera una identidad estable y determinística a partir de los
 * campos que identifican de forma única una fila (PedidoNo + Referencia + Talla
 * + Material + Color), tal como especifica la documentación del proyecto:
 *
 *   PedidoNo + Referencia + Talla + Material + Color
 *        -> SHA-256
 *        -> convertir a numérico
 *        -> conservar 10 dígitos
 *
 * El mismo conjunto de valores de entrada siempre produce el mismo ID.
 * Se usa Web Crypto (disponible de forma nativa en navegadores modernos y
 * en el entorno de Vite/Vercel) en vez de una librería externa.
 */

/**
 * @param {string|number} pedidoNo  Columna PedidoNo
 * @param {string} referencia       Columna Referencia
 * @param {string|number} talla     Columna Talla
 * @param {string} material         Columna MaterialP
 * @param {string} color            Columna ColorP
 * @returns {Promise<string>} ID numérico de exactamente 10 dígitos (string, puede tener ceros a la izquierda)
 */
export async function generarItemId(pedidoNo, referencia, talla, material, color) {
  const raw = [pedidoNo, referencia, talla, material, color]
    .map((v) => String(v ?? '').trim().toUpperCase())
    .join('');

  const hashHex = await sha256Hex(raw);

  // Convertimos el hash hexadecimal completo a un entero grande y tomamos
  // el resto módulo 10^10 para obtener 10 dígitos numéricos estables,
  // rellenando con ceros a la izquierda si hace falta.
  const hashBigInt = BigInt(`0x${hashHex}`);
  const tenDigits = (hashBigInt % 10000000000n).toString().padStart(10, '0');

  return tenDigits;
}

/**
 * Calcula el SHA-256 de un string y lo devuelve en hexadecimal.
 * @param {string} text
 * @returns {Promise<string>}
 */
async function sha256Hex(text) {
  const encoder = new TextEncoder();
  const data = encoder.encode(text);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

/**
 * Helper para generar el item_id directamente a partir de una fila de
 * "Pedidos Prueba" (con los nombres de columna reales del proyecto).
 * @param {{PedidoNo: any, Referencia: any, Talla: any, MaterialP: any, ColorP: any}} row
 * @returns {Promise<string>}
 */
export async function generarItemIdDesdeFila(row) {
  return generarItemId(row.PedidoNo, row.Referencia, row.Talla, row.MaterialP, row.ColorP);
}
