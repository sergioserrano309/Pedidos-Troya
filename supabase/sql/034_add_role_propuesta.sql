-- =====================================================================
-- 034_add_role_propuesta.sql
-- Agrega el rol 'propuesta' (cotizador de precios de suelas) al check
-- constraint de profiles.role. Este rol es independiente de los roles
-- de producción (refilado, acabado, mateado, empaque), del rol
-- 'comercial' existente (devoluciones/historial) y de 'validador'.
--
-- NOTA: el constraint versionado en 001_profiles.sql nunca incluyó
-- 'validador' (ver src/services/validatorService.js:5), aunque el rol
-- sí está vivo en producción — quedó ajustado directo en Supabase sin
-- dejar migración en el repo (mismo patrón que access_codes). Este
-- archivo reconstruye el constraint con la lista real y agrega
-- 'propuesta'.
-- =====================================================================

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('refilado', 'acabado', 'mateado', 'empaque', 'comercial', 'validador', 'propuesta'));
