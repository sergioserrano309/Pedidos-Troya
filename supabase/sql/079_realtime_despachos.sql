-- =====================================================================
-- 079_realtime_despachos.sql
-- Despachos "en vivo": agrega la tabla despachos a la publicacion
-- supabase_realtime (la misma que ya usan production_movements, returns
-- y pedido_cierre_forzado, ver 008 y 057). Asi, crear, eliminar, dar
-- visto bueno o cambiar comentario/factura de un despacho refresca la
-- pestana Despachos de los demas usuarios sin F5.
--
-- NO cambia datos, columnas, politicas ni funciones. Solo hace que
-- Supabase avise a la app cuando cambia una fila de despachos. Cada
-- usuario recibe unicamente lo que sus permisos (RLS) le dejan leer.
-- Es idempotente: si ya estaba agregada, no hace nada.
--
-- Reversa: 079_revertir_realtime_despachos.sql
-- =====================================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'despachos'
  ) then
    alter publication supabase_realtime add table public.despachos;
  end if;
end
$$;

-- Comprobacion (debe devolver 1 fila):
--   select tablename from pg_publication_tables
--    where pubname = 'supabase_realtime' and tablename = 'despachos';
