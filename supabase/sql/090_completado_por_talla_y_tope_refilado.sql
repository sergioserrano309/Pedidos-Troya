-- =====================================================================
-- 090_completado_por_talla_y_tope_refilado.sql
--
-- Refilado puede procesar MAS de lo que pide la talla (porque se inyecta de
-- mas), hasta un tope proporcional. Para que eso no rompa nada, un pedido
-- pasa a considerarse completo POR TALLA, no por la suma de pares.
--
-- REGLAS (decididas con el usuario, 2026-11-24)
--   1. Tope de Refilado por talla = pedido + 25% (redondeado hacia arriba,
--      minimo 2 pares). Ej.: 5 -> 7, 10 -> 13, 100 -> 125. Lo aplica un
--      candado en la base (trigger) ademas de la pantalla.
--   2. Un proceso (y el pedido) esta completo solo si CADA talla alcanzo lo
--      que pidio. El exceso de una talla NO compensa el faltante de otra:
--      T34 15/10 y T35 10/15 = incompleto.
--   3. Los % de las vistas siguen topados en 100 (las listas Activas/
--      Completadas filtran con "= 100"). El % REAL se calcula en pantalla
--      (Control Central y Excel) desde los pares.
--   4. Un % nunca se redondea a 100 si todavia falta algo (99,67 -> 99).
--   5. Pago: sin cambio. Cada movimiento se paga por cantidad x precio
--      congelado (024); los pares extra se pagan. Solo cambia CUANDO se
--      liquida el pedido (vw_pedido_rol_gate, por talla).
--
-- QUE HACE ESTE ARCHIVO
--   a. fn_extra_refilado(solicitado): la regla del 25%, en un solo lugar.
--   b. vw_pedido_progreso: pendientes, % por proceso, estado, etapa "Fin" y
--      total_pendiente se calculan POR TALLA. Mismas columnas, mismo orden y
--      mismos tipos que 057; se agregan 5 al final (tallas_total y
--      tallas_ok_refilado/acabado/mateado/empaque) para el texto "7/7 Tallas".
--   c. vw_pedido_progreso_atributos: se recrea (copia las columnas de la
--      anterior al crearse; solo la lee la aplicacion).
--   d. vw_pedido_rol_gate: la liquidacion exige TODAS las tallas cubiertas
--      (misma firma que 046).
--   e. Trigger trg_validar_tope_refilado en production_movements.
--
-- NO TOCA: movimientos existentes, despachos, Troya, Dashboard de unidades,
-- Cambios ERP, enrutamiento automatico, vw_pedidos_por_despachar.
--
-- ANTES DE EJECUTAR: correr 090_antes.sql (foto de las vistas actuales).
-- DESPUES: correr 090_despues.sql (compara contra la foto).
-- Reversa: 090_revertir_completado_por_talla_y_tope_refilado.sql
-- REQUIERE: 046, 057 y 082 ya ejecutados.
--
-- Todo va en UNA transaccion: si algo falla (p. ej. un tipo de columna que
-- no coincide), nada se aplica.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- a. Regla del tope en un solo lugar
-- ---------------------------------------------------------------------
create or replace function public.fn_extra_refilado(p_solicitado integer)
returns integer
language sql
immutable
as $$
  select case
    when coalesce(p_solicitado, 0) <= 0 then 0
    else greatest(2, ceil(p_solicitado * 0.25)::integer)
  end;
$$;

comment on function public.fn_extra_refilado(integer) is
  'Pares extra que Refilado puede procesar sobre lo pedido de una talla: 25% redondeado hacia arriba, minimo 2 (090). Debe coincidir con extraPermitidoRefilado() de src/lib/stageQuantities.js.';

-- ---------------------------------------------------------------------
-- b. vw_pedido_progreso por talla
--    Todo lo que no se menciona es identico a 057.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedido_progreso
with (security_invoker = true)
as
with orden_progreso as (
  select
    order_number::text as order_number,
    max(cliente)        as cliente,
    max(fecha_pedido)   as fecha_pedido,
    max(nombre_referencia) as nombre_referencia,
    max(material)       as material,
    max(color)          as color,
    count(*)            as total_items,
    sum(cantidad_solicitada) as total_solicitado,
    sum(cantidad_devuelta)   as total_devuelto,
    case
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 4 then 'E'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 3 then 'A'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 2 then 'M'
      when max(case when etapa_actual = 'Empaque' then 4 when etapa_actual = 'Acabado' then 3 when etapa_actual = 'Mateado' then 2 when etapa_actual = 'Refilado' then 1 else 0 end) = 1 then 'R'
      else 'Sin Procesar'
    end as etapa_actual
  from public.vw_item_progreso
  group by order_number::text
),
movimientos_orden_calc as (
  select
    order_number::text as order_number,
    sum(quantity) filter (where to_process = 'Refilado')   as in_refilado,
    sum(quantity) filter (where to_process = 'Acabado')    as in_acabado,
    sum(quantity) filter (where to_process = 'Mateado')    as in_mateado,
    sum(quantity) filter (where to_process = 'Empaque')    as in_empaque,
    sum(quantity) filter (where from_process = 'Refilado' and not es_automatico) as out_refilado,
    sum(quantity) filter (where from_process = 'Acabado')  as out_acabado,
    sum(quantity) filter (where from_process = 'Mateado')  as out_mateado,
    sum(quantity) filter (where from_process = 'Empaque')  as out_empaque,
    max(created_at) filter (where to_process = 'Empaque')  as fecha_fin
  from public.production_movements
  group by order_number::text
),
destino_calc as (
  select order_number, es_automatico
  from public.order_destino
),
-- NUEVO (090): una fila por TALLA. Las lineas que comparten item_id comparten
-- movimientos, asi que se suman sus pedidos y se cuentan una sola vez.
tallas as (
  -- Misma fuente y mismo filtro (sin canceladas) que vw_item_progreso, pero sin
  -- recorrer sus agregados otra vez (esta vista es la central de la app).
  select
    p."PedidoNo"::text as order_number,
    p.item_id,
    sum(coalesce(p."CantidadP", 0)) as sol
  from public.p_pedidosh p
  where coalesce(p."Cancelado", false) = false
  group by p."PedidoNo"::text, p.item_id
),
mov_talla as (
  select
    m.item_id,
    sum(m.quantity) filter (where m.to_process = 'Refilado')   as in_r,
    sum(m.quantity) filter (where m.from_process = 'Refilado' and not m.es_automatico) as out_r,
    sum(m.quantity) filter (where m.from_process = 'Acabado')  as out_a,
    sum(m.quantity) filter (where m.from_process = 'Mateado')  as out_m,
    sum(m.quantity) filter (where m.from_process = 'Empaque')  as out_e
  from public.production_movements m
  group by m.item_id
),
cobertura as (
  select
    t.order_number,
    count(*) as n_tallas,
    -- Refilado: lo que debe cubrir cada talla es lo pedido + lo que le regresaron
    sum(t.sol + coalesce(x.in_r, 0))                                 as base_r,
    sum(least(coalesce(x.out_r, 0), t.sol + coalesce(x.in_r, 0)))    as cub_r,
    sum(greatest(t.sol + coalesce(x.in_r, 0) - coalesce(x.out_r, 0), 0)) as pend_r,
    count(*) filter (where coalesce(x.out_r, 0) >= t.sol + coalesce(x.in_r, 0)) as ok_r,
    -- Acabado / Mateado / Empaque: lo pedido por talla
    sum(least(coalesce(x.out_a, 0), t.sol))                          as cub_a,
    sum(greatest(t.sol - coalesce(x.out_a, 0), 0))                   as pend_a,
    count(*) filter (where coalesce(x.out_a, 0) >= t.sol)            as ok_a,
    sum(least(coalesce(x.out_m, 0), t.sol))                          as cub_m,
    sum(greatest(t.sol - coalesce(x.out_m, 0), 0))                   as pend_m,
    count(*) filter (where coalesce(x.out_m, 0) >= t.sol)            as ok_m,
    sum(least(coalesce(x.out_e, 0), t.sol))                          as cub_e,
    sum(greatest(t.sol - coalesce(x.out_e, 0), 0))                   as pend_e,
    count(*) filter (where coalesce(x.out_e, 0) >= t.sol)            as ok_e
  from tallas t
  left join mov_talla x on x.item_id = t.item_id
  group by t.order_number
)
select
  op.order_number,
  op.cliente,
  op.fecha_pedido,
  op.nombre_referencia,
  op.material,
  op.color,
  op.total_solicitado,
  coalesce(mo.out_empaque, 0)::numeric as total_procesado,
  op.total_devuelto,
  -- Lo que falta, TALLA POR TALLA (un exceso en una talla no tapa otra).
  coalesce(cb.pend_e, 0)::numeric as total_pendiente,
  case when op.total_solicitado > 0
    then (case when coalesce(cb.cub_e, 0) >= op.total_solicitado then 100
               else least(round(coalesce(cb.cub_e, 0)::numeric / op.total_solicitado::numeric * 100), 99) end)
    else 0
  end as porcentaje_completado,
  case
    when op.total_solicitado > 0 and coalesce(cb.ok_e, 0) = coalesce(cb.n_tallas, -1) then 'Completado'
    else 'En Proceso'
  end as estatus_general,
  case
    when op.total_solicitado > 0 and coalesce(cb.ok_e, 0) = coalesce(cb.n_tallas, -1) then 'Fin'
    else coalesce(op.etapa_actual, 'R')
  end as etapa_actual,
  extract(day from (case when op.total_solicitado > 0 and coalesce(cb.ok_e, 0) = coalesce(cb.n_tallas, -1) and mo.fecha_fin is not null then mo.fecha_fin else now() end) - op.fecha_pedido)::int as dias_orden,
  (op.total_solicitado + coalesce(mo.in_refilado, 0)) as total_refilado,
  coalesce(mo.out_refilado, 0) as procesado_refilado,
  coalesce(cb.pend_r, 0)::numeric as pendiente_refilado,
  case when coalesce(cb.base_r, 0) > 0
    then (case when coalesce(cb.cub_r, 0) >= cb.base_r then 100
               else least(round(coalesce(cb.cub_r, 0)::numeric / cb.base_r::numeric * 100), 99) end)
    else 0
  end as porcentaje_refilado,
  coalesce(mo.in_acabado, 0) as entrada_acabado,
  op.total_solicitado as total_acabado,
  coalesce(mo.out_acabado, 0) as procesado_acabado,
  coalesce(cb.pend_a, 0)::numeric as pendiente_acabado,
  case when op.total_solicitado > 0
    then (case when coalesce(cb.cub_a, 0) >= op.total_solicitado then 100
               else least(round(coalesce(cb.cub_a, 0)::numeric / op.total_solicitado::numeric * 100), 99) end)
    else 0
  end as porcentaje_acabado,
  coalesce(mo.in_mateado, 0) as entrada_mateado,
  op.total_solicitado as total_mateado,
  coalesce(mo.out_mateado, 0) as procesado_mateado,
  coalesce(cb.pend_m, 0)::numeric as pendiente_mateado,
  case when op.total_solicitado > 0
    then (case when coalesce(cb.cub_m, 0) >= op.total_solicitado then 100
               else least(round(coalesce(cb.cub_m, 0)::numeric / op.total_solicitado::numeric * 100), 99) end)
    else 0
  end as porcentaje_mateado,
  coalesce(mo.in_empaque, 0) as entrada_empaque,
  op.total_solicitado as total_empaque,
  coalesce(mo.out_empaque, 0) as procesado_empaque,
  coalesce(cb.pend_e, 0)::numeric as pendiente_empaque,
  case when op.total_solicitado > 0
    then (case when coalesce(cb.cub_e, 0) >= op.total_solicitado then 100
               else least(round(coalesce(cb.cub_e, 0)::numeric / op.total_solicitado::numeric * 100), 99) end)
    else 0
  end as porcentaje_empaque,
  dc.es_automatico as destino_es_automatico,
  -- 057, siempre al final:
  (pcf.order_number is not null) as cierre_forzado,
  pcf.motivo                     as cierre_forzado_motivo,
  pcf.cerrado_at                 as cierre_forzado_at,
  cpr.name                       as cierre_forzado_por,
  -- NUEVAS (090): tallas con el proceso cubierto / tallas del pedido.
  coalesce(cb.n_tallas, 0)::bigint as tallas_total,
  coalesce(cb.ok_r, 0)::bigint     as tallas_ok_refilado,
  coalesce(cb.ok_a, 0)::bigint     as tallas_ok_acabado,
  coalesce(cb.ok_m, 0)::bigint     as tallas_ok_mateado,
  coalesce(cb.ok_e, 0)::bigint     as tallas_ok_empaque
from orden_progreso op
left join movimientos_orden_calc mo on mo.order_number = op.order_number
left join destino_calc dc on dc.order_number = op.order_number
left join cobertura cb on cb.order_number = op.order_number
left join public.pedido_cierre_forzado pcf on pcf.order_number = op.order_number
left join public.profiles cpr on cpr.id = pcf.cerrado_por;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo. Desde 090 los pendientes, % por proceso, estado y etapa Fin se calculan POR TALLA (cada talla cuenta hasta lo que pidio; el exceso de una no tapa el faltante de otra) y el % no se redondea a 100 si falta algo. procesado_* sigue siendo el real (puede superar lo pedido). tallas_* = tallas con el proceso cubierto.';

-- ---------------------------------------------------------------------
-- c. La vista con atributos copia las columnas de vw_pedido_progreso al
--    crearse (vp.*): hay que recrearla para que incluya las nuevas. Solo la
--    lee la aplicacion (ninguna otra vista depende de ella).
-- ---------------------------------------------------------------------
drop view if exists public.vw_pedido_progreso_atributos;

create view public.vw_pedido_progreso_atributos
with (security_invoker = true)
as
select
  vp.*,
  coalesce(a.vira, false)       as vira,
  coalesce(a.acabado, false)    as acabado,
  coalesce(a.esterilla, false)  as esterilla,
  coalesce(a.marquilla, false)  as marquilla
from public.vw_pedido_progreso vp
left join (
  select
    p."PedidoNo"::text as order_number,
    bool_or(lower(coalesce(p."Vira"::text, ''))       in ('true', 't', '1', 'si', 'sí')) as vira,
    bool_or(lower(coalesce(p."Acabado"::text, ''))    in ('true', 't', '1', 'si', 'sí')) as acabado,
    bool_or(lower(coalesce(p."Esterilla"::text, ''))  in ('true', 't', '1', 'si', 'sí')) as esterilla,
    bool_or(lower(coalesce(p."Marquilla"::text, ''))  in ('true', 't', '1', 'si', 'sí')) as marquilla
  from public.p_pedidosh p
  where coalesce(p."Cancelado", false) = false
  group by p."PedidoNo"::text
) a on a.order_number = vp.order_number;

grant select on public.vw_pedido_progreso_atributos to authenticated;
revoke select on public.vw_pedido_progreso_atributos from anon;

comment on view public.vw_pedido_progreso_atributos is
  'vw_pedido_progreso + vira/acabado/esterilla/marquilla por pedido (alguna linea = Si). Solo lectura; la usan los filtros Si/No (082, recreada en 090 para incluir las columnas tallas_*).';

-- ---------------------------------------------------------------------
-- d. vw_pedido_rol_gate por talla (misma firma y misma logica de Empaque
--    que 046). Antes: el acumulado del rol sobre el pedido entero llegaba al
--    total. Ahora: CADA talla llego a lo que pidio; la fecha es la del
--    movimiento que cubrio la ultima talla.
-- ---------------------------------------------------------------------
create or replace view public.vw_pedido_rol_gate
with (security_invoker = true) as
with tallas as (
  select p."PedidoNo"::text as order_number, p.item_id, sum(coalesce(p."CantidadP", 0)) as sol
  from public.p_pedidosh p
  where coalesce(p."Cancelado", false) = false
  group by p."PedidoNo"::text, p.item_id
),
totales as (
  -- total_solicitado se calcula igual que antes (mismo tipo de columna que 046);
  -- n_tallas = tallas con algo pedido.
  select
    ti.order_number,
    ti.total_solicitado,
    nt.n_tallas
  from (
    select order_number::text as order_number, sum(cantidad_solicitada) as total_solicitado
    from public.vw_item_progreso
    group by order_number::text
  ) ti
  join (
    select order_number, count(*) filter (where sol > 0) as n_tallas
    from tallas
    group by order_number
  ) nt on nt.order_number = ti.order_number
),
movs as (
  select
    m.order_number::text as order_number,
    m.item_id,
    lower(m.from_process) as rol,
    m.created_at,
    sum(m.quantity) over (
      partition by m.item_id, m.from_process
      order by m.created_at, m.id
      rows between unbounded preceding and current row
    ) as acumulado
  from public.production_movements m
  where not m.es_automatico
),
talla_rol as (
  select
    mv.order_number,
    mv.rol,
    mv.item_id,
    min(mv.created_at) filter (where mv.acumulado >= t.sol) as fecha_talla
  from movs mv
  join tallas t on t.order_number = mv.order_number and t.item_id = mv.item_id
  where t.sol > 0
  group by mv.order_number, mv.rol, mv.item_id
),
gate as (
  select
    tr.order_number,
    tr.rol,
    t.total_solicitado,
    -- Solo hay fecha si TODAS las tallas del pedido quedaron cubiertas.
    case when count(tr.fecha_talla) = t.n_tallas then max(tr.fecha_talla) end as fecha_proceso
  from talla_rol tr
  join totales t on t.order_number = tr.order_number
  where t.total_solicitado > 0
  group by tr.order_number, tr.rol, t.total_solicitado, t.n_tallas
),
despacho_por_orden as (
  select e.order_number, e.fecha_ultimo_despacho as fecha_despacho
  from public.vw_pedido_despacho_estado e
  where e.pedido_completo
)
select
  g.order_number,
  g.rol,
  g.total_solicitado,
  case
    when g.rol = 'empaque' then
      -- Las DOS condiciones: todas las tallas procesadas Y pedido completo despachado.
      case when g.fecha_proceso is not null then dp.fecha_despacho end
    else
      g.fecha_proceso
  end as fecha_liquidacion
from gate g
left join despacho_por_orden dp on dp.order_number = g.order_number;

grant select on public.vw_pedido_rol_gate to authenticated;

comment on view public.vw_pedido_rol_gate is
  'Fecha de liquidacion por (pedido, rol). Desde 090 exige que CADA talla alcance lo que pidio (el exceso de una no tapa a otra). Empaque: ademas pedido despachado COMPLETO (046); la fecha es la del despacho que lo completo.';

-- ---------------------------------------------------------------------
-- e. Candado en la base: Refilado no puede pasar de pedido + extra por talla.
--    Solo mira movimientos NUEVOS de Refilado hechos por personas; no toca los
--    existentes ni el enrutamiento automatico.
-- ---------------------------------------------------------------------
create or replace function public.fn_validar_tope_refilado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pedido integer;
  v_entra integer;
  v_sale integer;
  v_extra integer;
  v_max integer;
begin
  if new.from_process is distinct from 'Refilado' or coalesce(new.es_automatico, false) then
    return new;
  end if;

  -- Dos registros a la vez sobre la misma talla no deben colarse juntos.
  perform pg_advisory_xact_lock(hashtext('tope_refilado:' || new.item_id));

  select coalesce(sum(coalesce(p."CantidadP", 0)), 0) into v_pedido
    from public.p_pedidosh p
   where p.item_id = new.item_id
     and coalesce(p."Cancelado", false) = false;

  select coalesce(sum(m.quantity) filter (where m.to_process = 'Refilado'), 0),
         coalesce(sum(m.quantity) filter (where m.from_process = 'Refilado' and not m.es_automatico), 0)
    into v_entra, v_sale
    from public.production_movements m
   where m.item_id = new.item_id;

  v_extra := public.fn_extra_refilado(v_pedido);
  v_max := v_pedido + v_entra + v_extra;

  if v_sale + new.quantity > v_max then
    raise exception 'Pedido % talla %: Refilado ya proceso % y no puede superar % (pedido % + % de margen). Intentas registrar % mas.',
      new.order_number, new.size, v_sale, v_max, v_pedido + v_entra, v_extra, new.quantity;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_tope_refilado on public.production_movements;
create trigger trg_validar_tope_refilado
  before insert on public.production_movements
  for each row
  execute function public.fn_validar_tope_refilado();

comment on function public.fn_validar_tope_refilado() is
  'Candado de ultimo recurso (090): Refilado no puede registrar mas de lo pedido de la talla + fn_extra_refilado. La pantalla ya valida antes.';

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (despues de ejecutar; ver tambien 090_despues.sql)
--
-- A) La regla del tope:
--   select s as pedido, public.fn_extra_refilado(s) as extra
--     from unnest(array[0, 1, 5, 10, 20, 100, 200]) s;
--   -- esperado extra: 0, 2, 2, 3, 5, 25, 50
--
-- B) Las columnas nuevas existen:
--   select order_number, tallas_total, tallas_ok_empaque, estatus_general
--     from public.vw_pedido_progreso order by order_number desc limit 5;
-- =====================================================================
