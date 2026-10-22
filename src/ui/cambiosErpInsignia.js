import { fetchPedidosConCambiosPendientes } from '../services/cambiosErpService.js';
import { textoInsignia } from '../lib/cambiosErp.js';
import { esValidador } from '../services/validatorService.js';

/**
 * Insignia roja (círculo con el número en blanco) de la pestaña «Cambios ERP»:
 * cuántos PEDIDOS tienen cambios de Access pendientes de revisar. Solo la ve el
 * Validador (la pestaña es suya). Es informativa: si no se puede calcular, la
 * insignia simplemente se queda como estaba.
 *
 * Se actualiza: al iniciar sesión, cada 2 minutos (el detector corre cada 5),
 * al abrir el panel y tras cada acción del panel (ver cambiosErpPage.js).
 */

const MS_REFRESCO = 2 * 60 * 1000;
let temporizador = null;

/** Pinta (o esconde) la insignia con un número ya calculado de pedidos. */
export function pintarInsigniaCambiosErp(pedidos) {
  const el = document.getElementById('badge-cambios-erp');
  if (!el) return;
  const texto = textoInsignia(pedidos);
  if (!texto) {
    el.style.display = 'none';
    el.textContent = '';
    el.removeAttribute('title');
    el.removeAttribute('aria-label');
    return;
  }
  const n = Math.floor(Number(pedidos));
  const frase = `${n} pedido${n === 1 ? '' : 's'} con cambios de Access por revisar`;
  el.textContent = texto;
  el.title = frase;
  el.setAttribute('aria-label', frase);
  el.style.display = 'inline-flex';
}

/** Consulta cuántos pedidos están pendientes y pinta la insignia. */
export async function refrescarInsigniaCambiosErp() {
  if (!esValidador()) {
    pintarInsigniaCambiosErp(0);
    return;
  }
  const n = await fetchPedidosConCambiosPendientes();
  if (n !== null) pintarInsigniaCambiosErp(n);
}

/** Arranca la insignia (una sola vez) y la mantiene al día. Solo Validador. */
export function iniciarInsigniaCambiosErp() {
  refrescarInsigniaCambiosErp();
  if (temporizador) return;
  temporizador = setInterval(refrescarInsigniaCambiosErp, MS_REFRESCO);
}

/** Apaga la insignia y su temporizador (usuario que no es Validador). */
export function detenerInsigniaCambiosErp() {
  if (temporizador) {
    clearInterval(temporizador);
    temporizador = null;
  }
  pintarInsigniaCambiosErp(0);
}
