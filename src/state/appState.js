/**
 * Estado en memoria de la sesión / UI actual.
 * Simple y explícito a propósito (no se usa ningún framework de estado):
 * un objeto mutable + un pequeño mecanismo de suscripción para que la UI
 * pueda reaccionar a cambios (por ejemplo, tras login o tras un realtime
 * update).
 */

const state = {
  user: null,          // { id, authId, name, email, role }
  currentPage: 'ordenes',
  currentTab: 'activas',
  orders: [],           // resultado de vw_pedido_progreso, ya filtrado por rol
  selectedOrderNumber: null,
  selectedOrderItems: [],  // resultado de vw_item_progreso para la orden seleccionada
  selectedItem: null,      // item actualmente abierto en el modal de proceso/devolución
  destinoConfirmadoOrden: null, // { destino, confirmed_by, confirmed_at } de order_destino para la orden abierta, o null si aún no se confirma
  cierreForzadoOrden: null, // { motivo, cerradoAt, cerradoPor } si la orden abierta fue cerrada a la fuerza (057), o null
  history: []
};

const listeners = new Set();

export function getState() {
  return state;
}

export function setState(patch) {
  Object.assign(state, patch);
  listeners.forEach((fn) => fn(state));
}

export function subscribe(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function resetState() {
  setState({
    user: null,
    currentPage: 'ordenes',
    currentTab: 'activas',
    orders: [],
    selectedOrderNumber: null,
    selectedOrderItems: [],
    selectedItem: null,
    destinoConfirmadoOrden: null,
    cierreForzadoOrden: null,
    history: []
  });
}
