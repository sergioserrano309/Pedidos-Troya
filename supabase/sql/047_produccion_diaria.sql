-- =====================================================================
-- 047_produccion_diaria.sql
-- Unidades procesadas por dia, por usuario y rol. Alimenta la tarjeta
-- "Promedio Dia" de Compensacion.
--
-- Por que NO se calcula desde vw_compensacion_lineas, que ya esta en
-- memoria del cliente: esa vista solo contiene trabajo LIQUIDABLE
-- (025:94). Para Empaque, una linea aparece ahi solo cuando el pedido se
-- despacha completo (046), asi que el promedio ignoraria todo lo
-- empacado y aun no despachado, y pegaria saltos cada vez que sale un
-- camion. Lo que el operario quiere ver es cuanto produce por dia,
-- liquidado o no.
--
-- La fecha se convierte a hora de Bogota antes de truncar a dia: con
-- timestamptz crudo, lo registrado despues de las 19:00 caeria en el dia
-- siguiente y el promedio saldria repartido en dos dias.
--
-- Se excluye es_automatico: los movimientos de enrutamiento automatico
-- (013) no son trabajo de nadie. Mismo criterio que vw_pedido_rol_gate.
-- =====================================================================

create or replace view public.vw_produccion_diaria
with (security_invoker = true) as
select
  m.user_id,
  lower(m.from_process)                                    as rol,
  (m.created_at at time zone 'America/Bogota')::date       as dia,
  sum(m.quantity)                                          as unidades
from public.production_movements m
where not m.es_automatico
group by m.user_id, lower(m.from_process), (m.created_at at time zone 'America/Bogota')::date;

grant select on public.vw_produccion_diaria to authenticated;

comment on view public.vw_produccion_diaria is
  'Unidades procesadas por (usuario, rol, dia) sobre TODO lo registrado, liquidado o no. Alimenta la tarjeta Promedio Dia de Compensacion.';
