/** Formatea un valor COP como "$ 40.000" (sin decimales, separador de miles es-CO). Usado en Registros y Compensación. */
export function formatearCOP(valor) {
  if (valor === null || valor === undefined) return '—';
  const numero = Number(valor);
  if (Number.isNaN(numero)) return '—';
  return `$ ${Math.round(numero).toLocaleString('es-CO')}`;
}
