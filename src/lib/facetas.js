/**
 * Filtros en cascada ("facetas").
 *
 * Cada lista desplegable muestra solo los valores que existen en los
 * pedidos que cumplen los DEMÁS filtros activos — nunca su propio filtro.
 * Así, al elegir un cliente, Suela/Material/Color se reducen a lo de ese
 * cliente, pero la lista de clientes sigue completa para poder cambiar
 * de cliente sin limpiar primero.
 *
 * Todo se calcula en el navegador sobre un conjunto de filas que la
 * pantalla descarga UNA vez al entrar a la pestaña: filtrar no genera
 * consultas extra.
 */

/**
 * @typedef {{ columna: string, modo: 'exacto'|'contiene', lista?: boolean }} CampoFaceta
 *   columna: nombre de la columna en las filas.
 *   modo: 'exacto' para listas y fechas, 'contiene' para No. Orden.
 *   lista: true si ese filtro es una lista desplegable a recalcular.
 */

function activo(valor) {
  return valor != null && String(valor).trim() !== '';
}

function cumple(fila, clave, valor, campo) {
  const dato = fila[campo.columna];
  if (campo.modo === 'contiene') {
    return String(dato ?? '').includes(String(valor).trim());
  }
  return String(dato ?? '') === String(valor);
}

/**
 * @param {Array<object>} filas
 * @param {Record<string, string>} filtros valores actuales por clave
 * @param {Record<string, CampoFaceta>} campos
 * @returns {Record<string, string[]>} opciones por cada clave con lista:true
 */
export function calcularOpciones(filas, filtros, campos) {
  const resultado = {};

  Object.entries(campos).forEach(([claveLista, campoLista]) => {
    if (!campoLista.lista) return;

    const valores = new Set();
    filas.forEach((fila) => {
      const pasa = Object.entries(campos).every(([clave, campo]) => {
        if (clave === claveLista) return true; // la lista ignora su propio filtro
        const valor = filtros[clave];
        return !activo(valor) || cumple(fila, clave, valor, campo);
      });
      const dato = fila[campoLista.columna];
      if (pasa && activo(dato)) valores.add(String(dato));
    });

    resultado[claveLista] = [...valores].sort((a, b) => a.localeCompare(b, 'es', { numeric: true }));
  });

  return resultado;
}

/**
 * Reemplaza las opciones de un <select> conservando la primera (el
 * placeholder, ej. "Cliente...") y el valor elegido, aunque ya no esté en
 * la lista nueva: así lo que el usuario seleccionó nunca desaparece de
 * la pantalla sin que lo haya quitado él.
 */
export function reconstruirSelect(selectId, valores) {
  const select = document.getElementById(selectId);
  if (!select) return;

  const actual = select.value;
  const placeholder = select.options[0];
  const lista = actual && !valores.includes(actual) ? [actual, ...valores] : valores;

  select.innerHTML = '';
  if (placeholder) select.appendChild(placeholder);
  lista.forEach((valor) => {
    const option = document.createElement('option');
    option.value = valor;
    option.textContent = valor;
    select.appendChild(option);
  });
  select.value = actual;
}
