-- =====================================================================
-- 081_estado_sincronizacion_empaque.sql
-- Deja que Empaque vea el rotulo "Actualizado hace X min" (frescura del
-- dato que sube la oficina desde Access) en la vista Refilado.
--
-- POR QUE
--   erp_sync_estado solo la puede leer el Validador (066). Esta funcion
--   de SOLO LECTURA devuelve unicamente 4 campos de esa fila unica
--   (activo, ultima_ejecucion, ultima_actualizacion, ultimo_resultado)
--   y solo a Empaque y Validador (se valida el rol adentro). No abre la
--   tabla ni muestra conteos ni detalles internos.
--
-- NO CAMBIA: la tabla, sus permisos ni ningun dato.
-- Reversa: 081_revertir_estado_sincronizacion_empaque.sql
-- =====================================================================

create or replace function public.erp_estado_sincronizacion_vista()
returns table (
  activo boolean,
  ultima_ejecucion timestamptz,
  ultima_actualizacion timestamptz,
  ultimo_resultado text
)
language sql
stable
security definer
set search_path = public
as $$
  select e.activo, e.ultima_ejecucion, e.ultima_actualizacion, e.ultimo_resultado
    from public.erp_sync_estado e
   where e.id = 1
     and exists (
       select 1 from public.profiles pr
        where pr.auth_id = auth.uid()
          and lower(pr.role) in ('empaque', 'validador')
     );
$$;

revoke all on function public.erp_estado_sincronizacion_vista() from public, anon;
grant execute on function public.erp_estado_sincronizacion_vista() to authenticated;

comment on function public.erp_estado_sincronizacion_vista() is
  'Frescura de la sincronizacion Access->Supabase (4 campos de erp_sync_estado) para el rotulo "Actualizado hace X min". Solo Empaque y Validador. Solo lectura (081).';

-- Prueba segura: desde el editor de Supabase no hay sesion de usuario, asi
-- que devuelve 0 filas (eso confirma que bloquea a quien no es Empaque/Validador):
--   select * from public.erp_estado_sincronizacion_vista();
