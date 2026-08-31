-- =====================================================================
-- 028_despachos_vistas.sql
-- Vistas de lectura del modulo Despachos.
-- =====================================================================

-- ---------------------------------------------------------------------
-- vw_pedidos_por_despachar: pedidos 100% completos en Empaque
-- (porcentaje_empaque=100, el MISMO criterio, ya corregido dos veces —
-- 018/021 — que hoy determina la pestaña "Completadas" de Empaque) que
-- todavia no pertenecen a ningun despacho.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedidos_por_despachar
with (security_invoker = true) as
select vp.*
from public.vw_pedido_progreso vp
where vp.porcentaje_empaque = 100
  and not exists (
    select 1 from public.despacho_ordenes do2
    where do2.order_number = vp.order_number
  );

grant select on public.vw_pedidos_por_despachar to authenticated;

-- ---------------------------------------------------------------------
-- vw_despachos_resumen: una fila por despacho, con el conteo/lista de
-- pedidos ya agregados — alimenta tanto la tarjeta de "Despachado" como
-- el filtro "buscar por No. de Orden" (via el arreglo order_numbers).
-- ---------------------------------------------------------------------
create or replace view public.vw_despachos_resumen
with (security_invoker = true) as
select
  d.id,
  d.numero_despacho,
  d.consecutivo,
  d.created_at,
  d.created_by,
  d.total_bultos,
  d.asignacion_confirmada,
  d.confirmed_at,
  count(do2.order_number) as numero_ordenes,
  array_agg(do2.order_number order by do2.order_number) as order_numbers
from public.despachos d
left join public.despacho_ordenes do2 on do2.despacho_id = d.id
group by d.id;

grant select on public.vw_despachos_resumen to authenticated;

comment on view public.vw_pedidos_por_despachar is 'Pedidos 100% completos en Empaque y aun sin despacho asignado (Fase 1: un pedido pertenece a lo sumo a un despacho).';
comment on view public.vw_despachos_resumen is 'Un despacho por fila, con conteo y lista de pedidos agregados. Consumida por src/services/despachosService.js.';
