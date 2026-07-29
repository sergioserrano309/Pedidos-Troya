-- =====================================================================
-- 008_realtime.sql
-- Habilita Supabase Realtime (postgres_changes) sobre las tablas que el
-- frontend escucha para refrescar el dashboard/detalle/historial
-- automáticamente (ver src/realtime.js).
-- =====================================================================

alter publication supabase_realtime add table public.production_movements;
alter publication supabase_realtime add table public.returns;
