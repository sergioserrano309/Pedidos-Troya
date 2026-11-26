/**
 * Etiquetas de rol con "@" en los comentarios de Control Central (095) y color
 * del botón según el vencimiento del accionable más próximo.
 */

/** Rol de la base -> nombre que se escribe tras la "@" (Empaque se llama Despachos). */
export const ROLES_ETIQUETABLES = [
  { rol: 'propuesta', etiqueta: 'Propuesta' },
  { rol: 'empaque', etiqueta: 'Despachos' },
  { rol: 'validador', etiqueta: 'Validador' },
  { rol: 'refilado', etiqueta: 'Refilado' },
  { rol: 'acabado', etiqueta: 'Acabado' },
  { rol: 'mateado', etiqueta: 'Mateado' },
  { rol: 'comercial', etiqueta: 'Comercial' }
];

const REGEX_ETIQUETA = new RegExp(`@(${ROLES_ETIQUETABLES.map((r) => r.etiqueta).join('|')})(?![\p{L}\d_])`, 'gu');

/** Roles (de la base) etiquetados dentro de un texto, sin repetir. */
export function rolesDeTexto(texto) {
  const roles = new Set();
  for (const m of String(texto ?? '').matchAll(REGEX_ETIQUETA)) {
    const r = ROLES_ETIQUETABLES.find((x) => x.etiqueta === m[1]);
    if (r) roles.add(r.rol);
  }
  return [...roles];
}

/** Recibe texto YA escapado y resalta cada "@Rol" como una etiqueta. */
export function resaltarEtiquetasHtml(textoEscapado) {
  return String(textoEscapado ?? '').replace(
    REGEX_ETIQUETA,
    (m) => `<span style="background:var(--purple-bg); color:var(--purple-text); padding:0 4px; border-radius:4px; font-weight:600;">${m}</span>`
  );
}

/** Hoy como "AAAA-MM-DD" en la hora local del navegador. */
export function hoyISO() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

/** Días que faltan para una fecha "AAAA-MM-DD" (negativo = ya venció; 0 = vence hoy). */
export function diasParaVencer(fechaISO) {
  if (!fechaISO) return null;
  const [y, m, d] = String(fechaISO).slice(0, 10).split('-').map(Number);
  const [hy, hm, hd] = hoyISO().split('-').map(Number);
  return Math.round((Date.UTC(y, m - 1, d) - Date.UTC(hy, hm - 1, hd)) / 86400000);
}

/** "05/12/2026" desde "AAAA-MM-DD". */
export function formatearVencimiento(fechaISO) {
  if (!fechaISO) return '';
  const [y, m, d] = String(fechaISO).slice(0, 10).split('-');
  return `${d}/${m}/${y}`;
}

/**
 * Color del botón de comentarios según el accionable PENDIENTE que vence antes:
 * más de 10 días = verde; de 6 a 10 = amarillo (el de siempre); 5 o menos
 * (o ya vencido) = rojo. Sin accionables pendientes con fecha = amarillo.
 * @returns {'verde'|'amarillo'|'rojo'}
 */
export function colorPorVencimiento(comentarios) {
  const dias = (comentarios || [])
    .filter((c) => c.accionable && !c.cerrado && c.fecha_vencimiento)
    .map((c) => diasParaVencer(c.fecha_vencimiento));
  if (dias.length === 0) return 'amarillo';
  const min = Math.min(...dias);
  if (min > 10) return 'verde';
  if (min > 5) return 'amarillo';
  return 'rojo';
}
