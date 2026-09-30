import { supabase } from './config/supabaseClient.js';

/**
 * Suscripción realtime a production_movements y returns (sección 7 y 20
 * del documento: "Realtime refresh" / "real-time subscriptions").
 * Requiere que ambas tablas estén agregadas a la publicación
 * `supabase_realtime` (ver supabase/sql/008_realtime.sql).
 */
let canal = null;
let debounceTimer = null;

export function iniciarRealtime(onChange) {
  if (canal) return;

  const dispararCambio = () => {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(onChange, 300);
  };

  canal = supabase
    .channel('produccion-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'production_movements' }, dispararCambio)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'returns' }, dispararCambio)
    .on('postgres_changes', { event: '*', schema: 'public', table: 'pedido_cierre_forzado' }, dispararCambio)
    .subscribe();
}

export function detenerRealtime() {
  if (canal) {
    supabase.removeChannel(canal);
    canal = null;
  }
}
