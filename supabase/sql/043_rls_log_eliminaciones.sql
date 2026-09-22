-- =====================================================================
-- 043_rls_log_eliminaciones.sql
-- Restringe la lectura de log_eliminaciones a Validador.
--
-- Problema: la política creada en 014:27-32 es "using (true)", así que
-- CUALQUIER usuario autenticado podía leer TODAS las eliminaciones de
-- TODOS los usuarios, con el snapshot completo de lo borrado, llamando a
-- la API directamente. La pestaña Eliminaciones está restringida a
-- Validador en la interfaz, pero eso es una restricción de pantalla, no
-- de datos.
--
-- Se verificó que solo hay dos lectores en toda la app, ambos exclusivos
-- de Validador:
--   - src/services/eliminacionesService.js (pestaña Eliminaciones, 042)
--   - src/services/excelService.js:58 (hoja "Eliminaciones" del Excel;
--     el botón de descarga solo se muestra a Validador, dashboard.js:34-35)
-- Así que restringir no rompe ningún flujo existente.
--
-- Las ESCRITURAS no se ven afectadas: las hacen funciones security
-- definer (eliminar_movimiento_con_motivo en 014/041 y
-- eliminar_despacho_con_motivo en 039), que no pasan por RLS. La tabla
-- sigue sin políticas de insert/update/delete, como desde 014.
--
-- vw_log_eliminaciones (042) es security_invoker = true, así que hereda
-- esta política automáticamente — no hay que tocarla.
-- =====================================================================

drop policy if exists "log_eliminaciones_select_authenticated" on public.log_eliminaciones;
drop policy if exists "log_eliminaciones_select_validador" on public.log_eliminaciones;

create policy "log_eliminaciones_select_validador"
on public.log_eliminaciones
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'validador'
  )
);

comment on table public.log_eliminaciones is
  'Registro inmutable de todo lo eliminado (movimientos de produccion y despachos), con snapshot y motivo. Escrito solo por funciones security definer. Lectura restringida a Validador desde 043.';
