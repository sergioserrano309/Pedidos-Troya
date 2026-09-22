-- =====================================================================
-- 042_vista_log_eliminaciones.sql
-- Vista para la pestaña "Eliminaciones" (Validador).
--
-- La tabla log_eliminaciones existe desde 014 y ya captura TODAS las
-- eliminaciones de TODOS los usuarios — no solo del Validador. Hasta
-- ahora su único consumidor era la hoja "Eliminaciones" del Excel
-- (excelService.js), donde el usuario sale como UUID crudo y el snapshot
-- hay que interpretarlo a mano.
--
-- Esta vista hace dos cosas:
--   1. Resuelve eliminado_por -> nombre y rol (join a profiles).
--   2. Desempaqueta del snapshot los campos que cambian según el tipo,
--      para que la UI no tenga que saber la forma interna de cada uno:
--        - tabla_origen='production_movements': snapshot es la fila
--          completa del movimiento (to_jsonb de la fila, ver 014:75).
--        - tabla_origen='despachos': snapshot es un objeto con las
--          llaves despacho/ordenes/bultos/asignaciones (ver 039).
--
-- Nota: esto es distinto de audit_validador (017/020), que solo registra
-- intervenciones DEL Validador y nunca ha registrado eliminaciones.
-- =====================================================================

drop view if exists public.vw_log_eliminaciones;

create view public.vw_log_eliminaciones
with (security_invoker = true) as
select
  le.id,
  le.eliminado_en,
  le.tabla_origen,
  le.registro_id,
  le.motivo,
  le.eliminado_por,
  pr.name as usuario_nombre,
  pr.role as usuario_rol,

  -- Identificador legible: número de orden para movimientos,
  -- consecutivo (D1000) para despachos.
  case le.tabla_origen
    when 'production_movements' then le.snapshot->>'order_number'
    when 'despachos'            then le.snapshot->'despacho'->>'consecutivo'
  end as referencia,

  -- Campos propios de un movimiento de producción borrado.
  case when le.tabla_origen = 'production_movements'
       then le.snapshot->>'size' end                       as talla,
  case when le.tabla_origen = 'production_movements'
       then (le.snapshot->>'quantity')::integer end        as cantidad,
  case when le.tabla_origen = 'production_movements'
       then le.snapshot->>'from_process' end               as proceso,

  -- Campos propios de un despacho borrado. coalesce evita que
  -- jsonb_array_length falle si el snapshot viniera incompleto.
  case when le.tabla_origen = 'despachos'
       then jsonb_array_length(coalesce(le.snapshot->'ordenes', '[]'::jsonb)) end as num_ordenes,
  case when le.tabla_origen = 'despachos'
       then jsonb_array_length(coalesce(le.snapshot->'bultos', '[]'::jsonb)) end  as num_bultos,

  le.snapshot
from public.log_eliminaciones le
left join public.profiles pr on pr.id = le.eliminado_por;

grant select on public.vw_log_eliminaciones to authenticated;

comment on view public.vw_log_eliminaciones is
  'log_eliminaciones con el usuario resuelto a nombre/rol y los campos del snapshot desempaquetados segun tabla_origen. Alimenta la pestana Eliminaciones del Validador.';
