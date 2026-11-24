-- =====================================================================
-- 090_antes.sql — CORRER ANTES de 090_completado_por_talla_y_tope_refilado.sql
--
-- Saca una "foto" de lo que las vistas devuelven HOY, para compararla con lo
-- que devuelvan despues del 090 (ver 090_despues.sql). Solo crea dos tablas
-- temporales de apoyo (tmp_090_*) con candado RLS (nadie las lee desde la
-- aplicacion) y las borra 090_despues.sql al terminar.
--
-- No modifica ninguna vista ni dato de produccion.
-- =====================================================================

drop table if exists public.tmp_090_pedidos;
drop table if exists public.tmp_090_gate;

create table public.tmp_090_pedidos as
select
  order_number, estatus_general, etapa_actual, total_solicitado, total_procesado,
  total_pendiente, porcentaje_completado,
  pendiente_refilado, porcentaje_refilado,
  pendiente_acabado, porcentaje_acabado,
  pendiente_mateado, porcentaje_mateado,
  pendiente_empaque, porcentaje_empaque
from public.vw_pedido_progreso;

create table public.tmp_090_gate as
select order_number, rol, total_solicitado, fecha_liquidacion
from public.vw_pedido_rol_gate;

-- Sin politicas = nadie (salvo el dueño de la base) puede leerlas por la API.
alter table public.tmp_090_pedidos enable row level security;
alter table public.tmp_090_gate enable row level security;

-- Comprobacion: cuantas filas quedaron en la foto.
select
  (select count(*) from public.tmp_090_pedidos) as pedidos_en_la_foto,
  (select count(*) from public.tmp_090_gate)    as filas_gate_en_la_foto;
