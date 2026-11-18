import { fetchTallasParaCierre, TIPOS_TROYA } from '../services/cierreForzadoService.js';

/**
 * Parte de la ventana de cierre (y del cambio de tipo) que solo aparece con los
 * tipos "Cerrado y despachado en Troya" (SQL 089):
 *   - día opcional en que salió en Troya;
 *   - total: solo un resumen (lo que falte se cuenta como despachado en Troya);
 *   - parcial: tabla por talla con lo que falta, repartido en
 *       (i)   despachado en Troya        (se escribe)
 *       (ii)  sigue pendiente            (se calcula: lo que sobra)
 *       (iii) ya no se despachará        (se escribe)
 */

function esc(v) {
  return String(v ?? '').replace(/[&<>"']/g, (c) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  }[c]));
}

export function esTipoTroya(tipo) {
  return TIPOS_TROYA.includes(tipo);
}

/**
 * Pinta el detalle según el tipo elegido (o lo vacía si no es de Troya).
 * @param {HTMLElement} contenedor
 * @param {string} orderNumber
 * @param {string|null} tipo
 * @param {{ fechaTroya?: string|null }} [inicial] fecha ya guardada (al cambiar tipo)
 */
export async function montarReparto(contenedor, orderNumber, tipo, inicial = {}) {
  if (!contenedor) return;
  if (!esTipoTroya(tipo)) {
    contenedor.innerHTML = '';
    contenedor.dataset.tipo = '';
    return;
  }

  contenedor.dataset.tipo = tipo;
  contenedor.innerHTML = '<div style="font-size:12px;color:var(--text3);">Cargando tallas...</div>';

  let tallas;
  try {
    tallas = await fetchTallasParaCierre(orderNumber);
  } catch (err) {
    // Si cambió la selección mientras cargaba, no se pisa.
    if (contenedor.dataset.tipo !== tipo) return;
    contenedor.innerHTML = `<div class="troya-aviso">${esc(err.message)}</div>`;
    return;
  }
  if (contenedor.dataset.tipo !== tipo) return;

  const conFalta = tallas.filter((t) => t.falta > 0);
  const totalFalta = conFalta.reduce((s, t) => s + t.falta, 0);

  if (tallas.length === 0) {
    contenedor.innerHTML = '<div class="troya-aviso">Este pedido no aparece en el Dashboard de unidades (solo pedidos desde el 3095), así que estos tipos no aplican.</div>';
    return;
  }
  if (totalFalta === 0) {
    contenedor.innerHTML = '<div class="troya-aviso">Este pedido no tiene pares pendientes por despachar; no hay nada que repartir. Usa otro tipo de cierre.</div>';
    return;
  }

  const hoy = new Date().toLocaleDateString('en-CA', { timeZone: 'America/Bogota' });
  const fecha = `
    <label class="troya-fecha">
      <span>¿Qué día salió en Troya? (opcional)</span>
      <input type="date" class="troya-fecha-input" max="${hoy}" value="${esc(inicial.fechaTroya || '')}">
      <small>Con fecha, esos pares también cuentan en el despachado "por fecha de despacho". Sin fecha, solo "por fecha del pedido".</small>
    </label>`;

  if (tipo === 'despachado_troya_total') {
    contenedor.innerHTML = `
      ${fecha}
      <div class="troya-resumen">Se contarán <strong>${totalFalta.toLocaleString('es-CO')} pares</strong> como despachados en Troya (todo lo que falta por despachar). Los ya despachados en la plataforma no se tocan. Pendiente quedará en 0.</div>`;
    return;
  }

  const filas = conFalta.map((t) => `
    <tr data-item="${esc(t.item_id)}" data-falta="${t.falta}">
      <td>${esc(t.talla)}</td>
      <td class="num">${t.falta}</td>
      <td class="num"><input type="number" min="0" max="${t.falta}" step="1" value="${t.despachado_troya}" class="troya-i" aria-label="Despachados en Troya, talla ${esc(t.talla)}"></td>
      <td class="num troya-ii">${t.falta - t.despachado_troya - t.no_se_despacha}</td>
      <td class="num"><input type="number" min="0" max="${t.falta}" step="1" value="${t.no_se_despacha}" class="troya-iii" aria-label="Ya no se despachará, talla ${esc(t.talla)}"></td>
    </tr>`).join('');

  contenedor.innerHTML = `
    ${fecha}
    <div class="troya-resumen">Reparte lo que falta de cada talla. Lo que no escribas <strong>sigue pendiente</strong>.</div>
    <div style="overflow-x:auto;">
      <table class="troya-tabla">
        <thead><tr>
          <th>Talla</th><th class="num">Falta</th>
          <th class="num">(i) Despachados en Troya</th>
          <th class="num">(ii) Siguen pendientes</th>
          <th class="num">(iii) Ya no se despacharán</th>
        </tr></thead>
        <tbody>${filas}</tbody>
        <tfoot><tr><td>Total</td><td class="num troya-t-falta">${totalFalta}</td><td class="num troya-t-i">0</td><td class="num troya-t-ii">${totalFalta}</td><td class="num troya-t-iii">0</td></tr></tfoot>
      </table>
    </div>
    <div class="troya-aviso" style="display:none;"></div>`;

  const recalcular = () => {
    let ti = 0; let tii = 0; let tiii = 0; let hayError = false;
    contenedor.querySelectorAll('tbody tr').forEach((tr) => {
      const falta = Number(tr.dataset.falta);
      const i = Math.max(parseInt(tr.querySelector('.troya-i').value, 10) || 0, 0);
      const iii = Math.max(parseInt(tr.querySelector('.troya-iii').value, 10) || 0, 0);
      const ii = falta - i - iii;
      const celda = tr.querySelector('.troya-ii');
      celda.textContent = ii;
      celda.classList.toggle('troya-mal', ii < 0);
      if (ii < 0) hayError = true;
      ti += i; tii += Math.max(ii, 0); tiii += iii;
    });
    contenedor.querySelector('.troya-t-i').textContent = ti;
    contenedor.querySelector('.troya-t-ii').textContent = tii;
    contenedor.querySelector('.troya-t-iii').textContent = tiii;
    const aviso = contenedor.querySelector('.troya-aviso');
    aviso.style.display = hayError ? 'block' : 'none';
    aviso.textContent = hayError ? 'En alguna talla escribiste más pares de los que faltan.' : '';
  };
  contenedor.querySelectorAll('input[type="number"]').forEach((i) => i.addEventListener('input', recalcular));
  recalcular();
}

/**
 * Lee y valida lo que el usuario puso. Devuelve { fechaTroya, lineas } o lanza
 * un Error con un mensaje claro.
 */
export function leerReparto(contenedor, tipo) {
  const fechaTroya = contenedor?.querySelector('.troya-fecha-input')?.value || null;
  if (!esTipoTroya(tipo)) return { fechaTroya: null, lineas: null };
  if (!contenedor || contenedor.dataset.tipo !== tipo || !contenedor.querySelector('.troya-resumen')) {
    throw new Error('Este pedido no tiene pares pendientes que repartir, o las tallas aún no cargan. Elige otro tipo o espera un momento.');
  }
  if (tipo === 'despachado_troya_total') return { fechaTroya, lineas: null };

  const lineas = [];
  let hayAlgo = false;
  contenedor.querySelectorAll('tbody tr').forEach((tr) => {
    const falta = Number(tr.dataset.falta);
    const i = parseInt(tr.querySelector('.troya-i').value, 10) || 0;
    const iii = parseInt(tr.querySelector('.troya-iii').value, 10) || 0;
    if (i < 0 || iii < 0) throw new Error('Los pares no pueden ser negativos.');
    if (i + iii > falta) {
      throw new Error(`En la talla ${tr.firstElementChild.textContent} escribiste más pares de los que faltan (${falta}).`);
    }
    if (i + iii > 0) hayAlgo = true;
    lineas.push({ item_id: tr.dataset.item, despachado_troya: i, no_se_despacha: iii });
  });
  if (!hayAlgo) {
    throw new Error('Escribe al menos un par despachado en Troya o que ya no se vaya a despachar. Si todo sigue pendiente, usa "No se terminó de despachar".');
  }
  return { fechaTroya, lineas };
}
