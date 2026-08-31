-- =====================================================================
-- 025_compensacion_vistas.sql
-- Vistas del modulo Compensacion. Ambas SI llevan security_invoker=true
-- (a diferencia de lo que haria falta si el precio se calculara en vivo
-- aqui): como precio_cop/valor_cop ya quedaron CONGELADOS en cada fila
-- de production_movements por el trigger de 024, estas vistas no
-- necesitan leer precios_por_par/reglas_precios en absoluto — solo
-- agregan production_movements + vw_item_progreso, ambas ya legibles
-- por el usuario normal. Se mantiene asi el mismo patron que el resto
-- de vistas del proyecto (vw_pedido_progreso, vw_item_progreso, etc.).
--
-- Regla de negocio (gating POR PEDIDO COMPLETO + POR ROL, no por talla,
-- no por pipeline completo hasta Empaque): un pedido "cuenta" para
-- Compensacion de un rol especifico solo cuando el acumulado de TODAS
-- sus tallas procesado por ESE rol alcanza el total solicitado del
-- pedido completo. Cada rol es independiente — Refilado no espera a
-- Acabado/Mateado/Empaque. La fecha de liquidacion (a que mes pertenece
-- el pago) es la fecha del registro que hizo cruzar ese umbral; TODOS
-- los registros de ese pedido+rol comparten esa misma fecha de
-- liquidacion, aunque cada uno mantiene su propio valor_cop ya
-- congelado (no se suman en una sola linea, cada registro sigue siendo
-- su propia fila).
--
-- Movimientos automaticos (es_automatico=true) se excluyen del
-- acumulado: no son trabajo de ningun operario.
-- =====================================================================

-- ---------------------------------------------------------------------
-- vw_pedido_rol_gate: una fila por (order_number, rol) con la fecha en
-- que ese rol completo TODO el pedido (todas sus tallas), o null si
-- todavia no ha llegado al 100%.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedido_rol_gate
with (security_invoker = true) as
with totales as (
  select order_number::text as order_number, sum(cantidad_solicitada) as total_solicitado
  from public.vw_item_progreso
  group by order_number::text
),
movs as (
  select
    m.order_number,
    lower(m.from_process) as rol,
    m.id,
    m.created_at,
    sum(m.quantity) over (
      partition by m.order_number, m.from_process
      order by m.created_at, m.id
      rows between unbounded preceding and current row
    ) as acumulado
  from public.production_movements m
  where not m.es_automatico
)
select
  mv.order_number,
  mv.rol,
  t.total_solicitado,
  min(mv.created_at) filter (where mv.acumulado >= t.total_solicitado) as fecha_liquidacion
from movs mv
join totales t on t.order_number = mv.order_number
where t.total_solicitado > 0
group by mv.order_number, mv.rol, t.total_solicitado;

grant select on public.vw_pedido_rol_gate to authenticated;

-- ---------------------------------------------------------------------
-- vw_compensacion_lineas: una fila por movimiento (registro), SOLO para
-- los que pertenecen a un (order_number, rol) ya liquidable. Es lo que
-- consume compensacionService.js para indicadores/tablas/historico.
-- Cada fila conserva su propio valor_cop y su propia fecha_registro
-- (informativa), mas fecha_liquidacion (compartida por pedido+rol, para
-- decidir a que mes pertenece).
-- ---------------------------------------------------------------------
create or replace view public.vw_compensacion_lineas
with (security_invoker = true) as
select
  m.id as movimiento_id,
  m.item_id,
  m.order_number,
  m.reference,
  m.size,
  m.quantity,
  lower(m.from_process) as rol,
  m.user_id,
  m.created_at as fecha_registro,
  g.fecha_liquidacion,
  m.precio_cop,
  m.valor_cop
from public.production_movements m
join public.vw_pedido_rol_gate g
  on g.order_number = m.order_number and g.rol = lower(m.from_process)
where not m.es_automatico
  and m.precio_cop is not null
  and g.fecha_liquidacion is not null;

grant select on public.vw_compensacion_lineas to authenticated;

-- Soporte para la ventana (order_number, from_process, created_at) de
-- vw_pedido_rol_gate — sin esto, cada consulta fuerza un sort completo
-- de production_movements.
create index if not exists idx_movements_order_from_created
  on public.production_movements(order_number, from_process, created_at);

comment on view public.vw_pedido_rol_gate is
  'Fecha en la que cada (pedido, rol) completo el 100% de lo solicitado del pedido entero (todas sus tallas). Null = todavia no liquidable (fix 025).';
comment on view public.vw_compensacion_lineas is
  'Una fila por registro de produccion ya liquidable (su pedido+rol completo el 100%). valor_cop ya viene congelado desde production_movements (ver 024). Consumida por src/services/compensacionService.js.';
