-- =====================================================================
-- 044_despachos_parciales.sql
-- Un pedido deja de salir "todo o nada": ahora puede repartirse en
-- varios despachos, con un desglose POR TALLA en cada uno.
--
-- El esquema ya estaba preparado para esto — 027:148 dice explicitamente
-- "Sin unique(order_number) a proposito — ver Fase 2: despachos
-- parciales". Lo que faltaba era la granularidad de cantidad.
--
-- Modelo:
--   despacho_ordenes       -> "esta orden participa en este despacho"  (sin cambios)
--   despacho_orden_items   -> "de esta orden salieron N unidades de la talla X"  (NUEVO)
--   despacho_orden_bultos  -> asignacion a bultos, sigue siendo por orden (sin cambios)
--
-- La regla de negocio se reduce a tres numeros por talla:
--   empacada - despachada = disponible
-- Se despacha lo que tenga disponible > 0; el pedido esta completo
-- cuando ninguna de sus tallas debe nada.
--
-- Nota de tipos: todos los joins van por item_id (text en ambos lados).
-- Se evita a proposito unir por "PedidoNo"/"Talla", que en la base real
-- tienen tipos distintos a los que declara 009 (drift documentado en
-- 039:58-60).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tabla de desglose por talla
-- ---------------------------------------------------------------------
create table if not exists public.despacho_orden_items (
  id uuid primary key default gen_random_uuid(),
  despacho_id uuid not null references public.despachos(id) on delete cascade,
  order_number text not null,
  item_id text not null,
  talla text not null,
  cantidad integer not null check (cantidad > 0),
  created_at timestamptz not null default now(),
  -- Una sola fila por (despacho, talla): si se despacha dos veces la
  -- misma talla en la misma salida, va en una sola linea sumada.
  unique (despacho_id, item_id),
  -- La orden debe estar declarada en el despacho; si se borra la orden
  -- del despacho, su desglose cae con ella.
  foreign key (despacho_id, order_number)
    references public.despacho_ordenes(despacho_id, order_number) on delete cascade
);

create index if not exists idx_despacho_orden_items_item on public.despacho_orden_items(item_id);
create index if not exists idx_despacho_orden_items_orden on public.despacho_orden_items(order_number);
create index if not exists idx_despacho_orden_items_despacho on public.despacho_orden_items(despacho_id);

alter table public.despacho_orden_items enable row level security;

drop policy if exists "despacho_orden_items_select_empaque" on public.despacho_orden_items;
create policy "despacho_orden_items_select_empaque"
on public.despacho_orden_items
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) in ('empaque', 'validador')
  )
);

-- Mismo criterio que sus hermanas (029:138): el cliente solo lee; toda
-- escritura pasa por crear_despacho (security definer).
grant select on public.despacho_orden_items to authenticated;
revoke insert, update, delete on public.despacho_orden_items from authenticated, anon;

comment on table public.despacho_orden_items is
  'Desglose por talla de lo que salio en cada despacho. Permite despachos parciales: un pedido puede repartirse en varias salidas.';

-- ---------------------------------------------------------------------
-- 2. vw_item_despacho_saldo — el corazon del modulo
--
-- cantidad_empacada NO excluye es_automatico, a proposito: replica
-- exactamente el criterio de out_empaque/porcentaje_empaque de
-- vw_pedido_progreso (005:171), que es el que regia "A Despachar" antes
-- de este cambio. Cambiarlo aqui alteraria en silencio que pedidos son
-- despachables.
-- ---------------------------------------------------------------------
create or replace view public.vw_item_despacho_saldo
with (security_invoker = true) as
select
  ip.item_id,
  ip.order_number::text                        as order_number,
  ip.talla::text                               as talla,
  ip.referencia,
  ip.material,
  ip.color,
  ip.cantidad_solicitada,
  coalesce(emp.cantidad_empacada, 0)           as cantidad_empacada,
  coalesce(des.cantidad_despachada, 0)         as cantidad_despachada,
  greatest(
    coalesce(emp.cantidad_empacada, 0) - coalesce(des.cantidad_despachada, 0),
    0
  )                                            as cantidad_disponible
from public.vw_item_progreso ip
left join (
  select item_id, sum(quantity) as cantidad_empacada
  from public.production_movements
  where from_process = 'Empaque'
  group by item_id
) emp on emp.item_id = ip.item_id
left join (
  select item_id, sum(cantidad) as cantidad_despachada
  from public.despacho_orden_items
  group by item_id
) des on des.item_id = ip.item_id;

grant select on public.vw_item_despacho_saldo to authenticated;

comment on view public.vw_item_despacho_saldo is
  'Saldo despachable por talla: empacada - despachada = disponible. Fuente unica de verdad para que se puede despachar y cuanto falta.';

-- ---------------------------------------------------------------------
-- 3. vw_pedido_despacho_estado — completitud POR PEDIDO
--
-- Es lo que alimenta el badge que ve el usuario. Ojo: NO es lo mismo que
-- despachos.asignacion_confirmada, que sigue significando "la asignacion
-- a bultos de esta salida quedo confirmada" y sigue naciendo en true.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedido_despacho_estado
with (security_invoker = true) as
with saldos as (
  select
    order_number,
    sum(cantidad_solicitada) as unidades_solicitadas,
    sum(cantidad_despachada) as unidades_despachadas,
    bool_and(cantidad_despachada >= cantidad_solicitada) as todas_cubiertas
  from public.vw_item_despacho_saldo
  group by order_number
),
fechas as (
  select
    doi.order_number,
    min(coalesce(d.confirmed_at, d.created_at)) as fecha_primer_despacho,
    max(coalesce(d.confirmed_at, d.created_at)) as fecha_ultimo_despacho,
    count(distinct doi.despacho_id)             as numero_despachos
  from public.despacho_orden_items doi
  join public.despachos d on d.id = doi.despacho_id
  group by doi.order_number
)
select
  s.order_number,
  s.unidades_solicitadas,
  s.unidades_despachadas,
  -- Se exige ademas que haya salido algo: un pedido sin despachos tiene
  -- todas_cubiertas=false salvo en casos degenerados (solicitado 0).
  (s.todas_cubiertas and s.unidades_despachadas > 0) as pedido_completo,
  case
    when s.unidades_solicitadas > 0
      then least(round(s.unidades_despachadas::numeric / s.unidades_solicitadas::numeric * 100), 100)
    else 0
  end as porcentaje_despachado,
  f.fecha_primer_despacho,
  f.fecha_ultimo_despacho,
  coalesce(f.numero_despachos, 0) as numero_despachos
from saldos s
left join fechas f on f.order_number = s.order_number;

grant select on public.vw_pedido_despacho_estado to authenticated;

comment on view public.vw_pedido_despacho_estado is
  'Completitud de despacho por pedido, sumando todas sus salidas. pedido_completo alimenta el badge Confirmado de RegistrosO/RegistrosD y el gate de comision de Empaque.';

-- ---------------------------------------------------------------------
-- 4. vw_pedidos_por_despachar — ahora por saldo, no por "todo o nada"
--
-- Cambia el conjunto de columnas (se agrega unidades_disponibles), asi
-- que requiere drop + create: create or replace view no permite eso.
-- Unico consumidor: despachosService.js:36.
-- ---------------------------------------------------------------------
drop view if exists public.vw_pedidos_por_despachar;

create view public.vw_pedidos_por_despachar
with (security_invoker = true) as
select
  vp.*,
  disp.unidades_disponibles
from public.vw_pedido_progreso vp
join (
  select order_number, sum(cantidad_disponible) as unidades_disponibles
  from public.vw_item_despacho_saldo
  group by order_number
  having sum(cantidad_disponible) > 0
) disp on disp.order_number = vp.order_number::text;

grant select on public.vw_pedidos_por_despachar to authenticated;

comment on view public.vw_pedidos_por_despachar is
  'Pedidos con al menos una talla disponible para despachar (empacada y aun no despachada). Desde 044 ya NO exige el 100% de empaque ni excluye pedidos con despachos previos: se despacha lo que haya, las veces que haga falta.';
