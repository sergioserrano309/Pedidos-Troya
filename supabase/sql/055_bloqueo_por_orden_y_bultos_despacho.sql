-- =====================================================================
-- 055_bloqueo_por_orden_y_bultos_despacho.sql
--
--   1. vw_despacho_orden_detalle -> total_bultos del despacho (Excel)
--   2. Bloqueo de borrado: si OTRO proceso ya registro sobre la misma
--      orden, se bloquea la orden entera, no solo esa talla.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. La hoja Despachos necesitaba distinguir dos cosas que se llamaban
--    parecido: en cuantos bultos va ESA ORDEN, y cuantos bultos tiene el
--    DESPACHO. La columna nueva va al final (create or replace view solo
--    deja agregar).
-- ---------------------------------------------------------------------
create or replace view public.vw_despacho_orden_detalle
with (security_invoker = true) as
with atributos as (
  select
    "PedidoNo"::text                                as order_number,
    max("Cliente")                                  as cliente,
    max("NombreR")                                  as nombre_referencia,
    max("MaterialP")                                as material,
    max("ColorP")                                   as color,
    bool_or(public.fn_es_si("Vira"::text))          as vira,
    bool_or(public.fn_es_si("Acabado"::text))       as acabado,
    bool_or(public.fn_es_si("Esterilla"::text))     as esterilla,
    bool_or(public.fn_es_si("Marquilla"::text))     as marquilla
  from public.p_pedidosh
  group by "PedidoNo"::text
),
items as (
  select despacho_id, order_number, sum(cantidad) as unidades
    from public.despacho_orden_items
   group by despacho_id, order_number
),
asignaciones as (
  select despacho_id,
         order_number,
         string_agg(bulto_numero::text, ', ' order by bulto_numero) as bultos_asignados,
         count(*)                                                   as numero_bultos
    from public.despacho_orden_bultos
   group by despacho_id, order_number
),
kilos as (
  select despacho_id, sum(peso) as peso_total
    from public.despacho_bultos
   group by despacho_id
),
unidades_despacho as (
  select despacho_id, sum(cantidad) as unidades
    from public.despacho_orden_items
   group by despacho_id
)
select
  d.id                                          as despacho_id,
  d.consecutivo,
  coalesce(d.confirmed_at, d.created_at)        as fecha_despacho,
  d.revisado,
  do2.order_number,
  a.cliente,
  a.nombre_referencia,
  a.material,
  a.color,
  coalesce(a.vira, false)                       as vira,
  coalesce(a.acabado, false)                    as acabado,
  coalesce(a.esterilla, false)                  as esterilla,
  coalesce(a.marquilla, false)                  as marquilla,
  coalesce(i.unidades, 0)                       as unidades_orden_despacho,
  coalesce(asg.bultos_asignados, '')            as bultos_asignados,
  coalesce(asg.numero_bultos, 0)                as numero_bultos,
  coalesce(k.peso_total, 0)                     as kilos_despacho,
  coalesce(ud.unidades, 0)                      as unidades_despacho,
  coalesce(e.porcentaje_despachado, 0)          as porcentaje_despachado,
  coalesce(e.pedido_completo, false)            as pedido_completo,
  -- Columna nueva: bultos del DESPACHO (se repite por fila, como kilos
  -- y unidades del despacho).
  d.total_bultos                                as bultos_despacho
from public.despacho_ordenes do2
join public.despachos d on d.id = do2.despacho_id
left join atributos a           on a.order_number   = do2.order_number
left join items i               on i.despacho_id    = do2.despacho_id
                               and i.order_number   = do2.order_number
left join asignaciones asg      on asg.despacho_id  = do2.despacho_id
                               and asg.order_number = do2.order_number
left join kilos k               on k.despacho_id    = d.id
left join unidades_despacho ud  on ud.despacho_id   = d.id
left join public.vw_pedido_despacho_estado e on e.order_number = do2.order_number;

grant select on public.vw_despacho_orden_detalle to authenticated;

-- ---------------------------------------------------------------------
-- 2. Bloqueo de borrado por ORDEN cuando interviene otro proceso.
--
-- Antes: solo se bloqueaba el registro de la talla que ya tenia un
-- movimiento posterior. Si Refilado mandaba 5 tallas a Acabado y Acabado
-- procesaba una, Refilado podia borrar las otras cuatro — dejando a
-- Acabado con unidades que "nadie le envio".
--
-- Ahora la regla tiene dos mitades, y basta una para bloquear:
--   (a) existe un movimiento posterior para ESA TALLA (la regla de 014,
--       que se conserva intacta: cubre el caso de un mismo proceso
--       procesando la misma talla dos veces); o
--   (b) existe un movimiento posterior de OTRO proceso en la MISMA
--       ORDEN — lo que el usuario pidio.
--
-- Se compara contra otro proceso y no contra "cualquier movimiento
-- posterior" a proposito: si no, Refilado no podria corregir su propio
-- registro de la talla 35 por el solo hecho de haber registrado despues
-- la 36, que es trabajo suyo y nadie mas lo ha tocado.
-- ---------------------------------------------------------------------
create index if not exists idx_movements_order_created
  on public.production_movements(order_number, created_at);

create or replace view public.vw_historial
with (security_invoker = true) as
select
  h.id,
  h.tipo,
  h.order_number,
  h.item_id,
  h.reference,
  h.size,
  h.quantity,
  h.from_process,
  h.to_process,
  h.causal,
  h.failed_process,
  h.action,
  h.observation,
  h.user_id,
  pr.name as user_name,
  pr.role as user_role,
  h.created_at,
  coalesce(ep.paso_refilado, false) as paso_refilado,
  coalesce(ep.paso_mateado, false) as paso_mateado,
  coalesce(ep.paso_acabado, false) as paso_acabado,
  coalesce(ep.paso_empaque, false) as paso_empaque,
  h.precio_cop,
  h.valor_cop,
  tal.fecha_despacho,
  coalesce(est.pedido_completo, false) as despacho_confirmado,
  (h.tipo = 'movimiento' and (
     exists (
       select 1 from public.production_movements m2
       where m2.item_id = h.item_id
         and m2.created_at > h.created_at
     )
     or exists (
       select 1 from public.production_movements m3
       where m3.order_number = h.order_number
         and m3.created_at > h.created_at
         and m3.from_process is distinct from h.from_process
     )
   )) as tiene_movimiento_posterior,
  -- Las dos ultimas columnas son de 049 (el despacho concreto en que
  -- salio ESTE registro de Empaque). Van despues de
  -- tiene_movimiento_posterior y no se pueden mover: create or replace
  -- view no deja reordenar ni quitar columnas, solo agregar al final.
  md.despacho_consecutivo,
  md.despacho_fecha as despacho_fecha_registro
from (
  select
    m.id,
    'movimiento'::text as tipo,
    m.order_number,
    m.item_id,
    m.reference,
    m.size,
    m.quantity,
    m.from_process,
    m.to_process,
    null::text as causal,
    null::text as failed_process,
    null::text as action,
    m.observation,
    m.user_id,
    m.created_at,
    m.precio_cop,
    m.valor_cop
  from public.production_movements m

  union all

  select
    r.id,
    'devolucion'::text as tipo,
    r.order_number,
    r.item_id,
    null::text as reference,
    r.size,
    r.quantity,
    r.failed_process as from_process,
    coalesce(r.reprocess_destination, 'N/A') as to_process,
    r.causal,
    r.failed_process,
    r.action,
    r.observation,
    r.user_id,
    r.created_at,
    null::numeric as precio_cop,
    null::numeric as valor_cop
  from public.returns r
) h
left join public.profiles pr on pr.id = h.user_id
left join public.vw_pedido_estado_procesos ep on ep.order_number = h.order_number
left join (
  -- Fecha en que ESTA talla salio (la ultima vez, si salio en varias remesas).
  select doi.item_id,
         max(coalesce(d.confirmed_at, d.created_at)) as fecha_despacho
  from public.despacho_orden_items doi
  join public.despachos d on d.id = doi.despacho_id
  group by doi.item_id
) tal on tal.item_id = h.item_id
left join public.vw_pedido_despacho_estado est on est.order_number = h.order_number
left join public.vw_movimiento_despacho md on md.movimiento_id = h.id;

comment on view public.vw_historial is
  'Linea de tiempo de production_movements + returns. fecha_despacho = talla (decide el bloqueo por despacho); despacho_consecutivo / despacho_fecha_registro = remesa concreta de ESTE registro (049); despacho_confirmado = completitud del pedido; tiene_movimiento_posterior (055) bloquea la ORDEN entera cuando otro proceso ya registro sobre ella.';

-- ---------------------------------------------------------------------
-- El candado de verdad: la misma regla dentro del RPC. La vista solo
-- sirve para poner el boton en gris; sin esto, el borrado seguiria
-- pasando por debajo.
-- ---------------------------------------------------------------------
create or replace function public.eliminar_movimiento_con_motivo(p_movimiento_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registro public.production_movements;
  v_perfil_id uuid;
  v_consecutivos text;
  v_otro_proceso text;
begin
  select id into v_perfil_id from public.profiles where auth_id = auth.uid();
  if v_perfil_id is null then
    raise exception 'Usuario no valido.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este registro.';
  end if;

  select * into v_registro from public.production_movements where id = p_movimiento_id;
  if v_registro.id is null then
    raise exception 'El registro no existe o ya fue eliminado.';
  end if;

  if v_registro.user_id is distinct from v_perfil_id then
    raise exception 'Solo puedes eliminar registros que tu mismo creaste.';
  end if;

  -- Bloqueo por talla despachada (046).
  select string_agg(distinct d.consecutivo, ', ')
    into v_consecutivos
    from public.despacho_orden_items doi
    join public.despachos d on d.id = doi.despacho_id
   where doi.item_id = v_registro.item_id;

  if v_consecutivos is not null then
    raise exception 'No puedes eliminar este registro: la talla % del pedido % ya fue despachada (%). Elimina primero ese despacho en Despachos > Despachado.',
      v_registro.size, v_registro.order_number, v_consecutivos;
  end if;

  -- (a) Movimiento posterior de la MISMA talla (014).
  if exists (
    select 1 from public.production_movements m2
    where m2.item_id = v_registro.item_id
      and m2.created_at > v_registro.created_at
  ) then
    raise exception 'No puedes eliminar este registro: ya se genero otro movimiento posterior para esta talla.';
  end if;

  -- (b) Otro proceso ya trabajo sobre la orden (055): se bloquea la
  --     orden completa, no solo la talla.
  select m3.from_process
    into v_otro_proceso
    from public.production_movements m3
   where m3.order_number = v_registro.order_number
     and m3.created_at > v_registro.created_at
     and m3.from_process is distinct from v_registro.from_process
   order by m3.created_at
   limit 1;

  if v_otro_proceso is not null then
    raise exception 'No puedes eliminar este registro: % ya proceso unidades del pedido %. Cuando otro proceso trabaja sobre la orden, queda bloqueada completa.',
      v_otro_proceso, v_registro.order_number;
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('production_movements', v_registro.id, to_jsonb(v_registro), v_perfil_id, trim(p_motivo));

  delete from public.production_movements where id = p_movimiento_id;
end;
$$;

grant execute on function public.eliminar_movimiento_con_motivo(uuid, text) to authenticated;

comment on function public.eliminar_movimiento_con_motivo(uuid, text) is
  'Elimina un movimiento con motivo obligatorio y snapshot en log_eliminaciones. Bloquea si la TALLA fue despachada (046), si hay un movimiento posterior de esa talla (014), o si OTRO proceso ya registro sobre la orden (055).';
