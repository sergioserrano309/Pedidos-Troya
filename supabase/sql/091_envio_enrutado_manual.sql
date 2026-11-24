-- =====================================================================
-- 091_envio_enrutado_manual.sql
--
-- El enrutamiento deja de ser automatico por reglas y pasa a ser una accion de
-- REFILADO: en la tarjeta del pedido, un toggle "Pasa por Refilado" (encendido
-- por defecto). Apagado, no se procesa nada por talla y aparece el boton
-- "Envio Enrutado": manda el pedido COMPLETO al proceso elegido (Acabado,
-- Mateado o Empaque) sin que cuente como trabajo de Refilado ni para su
-- compensacion. Es lo mismo que hacia una regla, pero lo dispara una persona.
--
-- REGLAS (decididas con el usuario, 2026-11-24)
--   1. Solo se enruta si el pedido NO tiene ningun registro y su destino ya
--      esta confirmado. Se enruta completo o no se hace.
--   2. Los movimientos creados son los mismos que creaba una regla:
--      es_automatico = true, sin usuario, Refilado -> destino, cantidad pedida
--      de cada talla. Por eso Compensacion, Cambios ERP, borrado de registros y
--      produccion diaria ya los tratan como "no es trabajo de nadie".
--   3. Despues del envio el pedido pasa a Completadas de Refilado. Desde ahi
--      Refilado o el Validador pueden "Deshacer envio" mientras ningun proceso
--      siguiente haya registrado nada (ni haya despachos ni devoluciones). Queda
--      en log_eliminaciones.
--   4. Las reglas dejan de actuar: el disparador de pedidos nuevos ya no las
--      consulta. Las tablas de reglas NO se borran (quedan sin uso).
--   5. Una linea NUEVA que llegue de Access a un pedido ya enrutado sigue el
--      destino del pedido, automaticamente.
--
-- QUE HACE ESTE ARCHIVO
--   a. order_destino: columnas enrutado_por y enrutado_at (distinguen un envio
--      hecho por Refilado de uno hecho por una regla antigua).
--   b. enrutar_pedido_manual(pedido, destino) y deshacer_envio_enrutado(pedido).
--   c. fn_auto_enrutar_pedido(): ya no usa reglas (regla 5).
--   d. vw_pedido_progreso: 2 columnas nuevas AL FINAL (enrutado_manual,
--      enrutado_destino). Todo lo demas igual que 090.
--   e. vw_pedido_progreso_atributos: se recrea para incluirlas.
--
-- NO TOCA: movimientos existentes, reglas_enrutamiento, aplicar_regla_enrutamiento,
-- el Excel (Regla/ReglaProceso ya leen order_destino.es_automatico y destino).
--
-- REQUIERE: 090 ya ejecutado.
-- Reversa: 091_revertir_envio_enrutado_manual.sql
-- Todo va en UNA transaccion.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- a. Quien enruto y cuando
-- ---------------------------------------------------------------------
alter table public.order_destino
  add column if not exists enrutado_por uuid references public.profiles(id),
  add column if not exists enrutado_at timestamptz;

comment on column public.order_destino.enrutado_por is
  'Perfil que hizo "Envio Enrutado" (091). Null = el destino lo confirmo una persona de forma normal o lo puso una regla antigua (es_automatico = true sin enrutado_por).';

-- ---------------------------------------------------------------------
-- b1. Envio Enrutado
-- ---------------------------------------------------------------------
create or replace function public.enrutar_pedido_manual(p_order_number text, p_destino text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil uuid;
  v_rol text;
  v_dest record;
  v_fila record;
  v_n integer := 0;
begin
  select pr.id, lower(pr.role) into v_perfil, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil is null or v_rol not in ('refilado', 'validador') then
    raise exception 'Solo Refilado (o el Validador actuando como Refilado) puede enrutar un pedido.';
  end if;

  if p_destino is null or p_destino not in ('Acabado', 'Mateado', 'Empaque') then
    raise exception 'Destino invalido: debe ser Acabado, Mateado o Empaque.';
  end if;

  -- Dos clics o dos personas a la vez no deben duplicar el envio.
  perform pg_advisory_xact_lock(hashtext('enrutar:' || p_order_number));

  if exists (select 1 from public.pedido_cierre_forzado f where f.order_number = p_order_number) then
    raise exception 'El pedido % esta cerrado a la fuerza: no admite registros.', p_order_number;
  end if;

  if not exists (
    select 1 from public.p_pedidosh p
     where p."PedidoNo"::text = p_order_number
       and not coalesce(p."Cancelado", false)
       and coalesce(p."CantidadP", 0) > 0
  ) then
    raise exception 'El pedido % no existe o no tiene tallas por enrutar.', p_order_number;
  end if;

  if exists (select 1 from public.production_movements m where m.order_number::text = p_order_number) then
    raise exception 'El pedido % ya tiene registros: no se puede enrutar. Se enruta completo o no se hace.', p_order_number;
  end if;

  select * into v_dest from public.order_destino d where d.order_number = p_order_number;
  if not found then
    raise exception 'Primero confirma el destino del pedido.';
  end if;
  if v_dest.destino <> p_destino then
    raise exception 'El destino confirmado del pedido es %, no %.', v_dest.destino, p_destino;
  end if;

  for v_fila in
    select p.item_id, p."NombreR" as nombre, p."Talla"::text as talla, p."CantidadP" as cantidad
      from public.p_pedidosh p
     where p."PedidoNo"::text = p_order_number
       and not coalesce(p."Cancelado", false)
       and coalesce(p."CantidadP", 0) > 0
  loop
    insert into public.production_movements (
      item_id, order_number, reference, size, quantity,
      from_process, to_process, user_id, observation, es_automatico
    ) values (
      v_fila.item_id, p_order_number, v_fila.nombre, v_fila.talla, v_fila.cantidad,
      'Refilado', p_destino, null,
      -- El texto "Enrutamiento automático" lo usan procesoDias.js y el Excel para reconocer estos movimientos.
      'Enrutamiento automático (Envío Enrutado por Refilado)', true
    );
    v_n := v_n + 1;
  end loop;

  update public.order_destino
     set es_automatico = true, enrutado_por = v_perfil, enrutado_at = now()
   where order_number = p_order_number;

  return v_n;
end;
$$;

revoke all on function public.enrutar_pedido_manual(text, text) from public, anon;
grant execute on function public.enrutar_pedido_manual(text, text) to authenticated;

comment on function public.enrutar_pedido_manual(text, text) is
  'Envio Enrutado (091): manda el pedido completo al destino confirmado, con movimientos automaticos (no cuentan como trabajo de Refilado). Solo Refilado/Validador, pedido sin registros.';

-- ---------------------------------------------------------------------
-- b2. Deshacer envio
-- ---------------------------------------------------------------------
create or replace function public.deshacer_envio_enrutado(p_order_number text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil uuid;
  v_rol text;
  v_n integer;
begin
  select pr.id, lower(pr.role) into v_perfil, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil is null or v_rol not in ('refilado', 'validador') then
    raise exception 'Solo Refilado (o el Validador) puede deshacer un envio enrutado.';
  end if;

  perform pg_advisory_xact_lock(hashtext('enrutar:' || p_order_number));

  if not exists (
    select 1 from public.order_destino d
     where d.order_number = p_order_number and d.enrutado_por is not null
  ) then
    raise exception 'El pedido % no fue enviado con Envio Enrutado.', p_order_number;
  end if;

  if exists (select 1 from public.pedido_cierre_forzado f where f.order_number = p_order_number) then
    raise exception 'El pedido % esta cerrado a la fuerza.', p_order_number;
  end if;

  if exists (
    select 1 from public.production_movements m
     where m.order_number::text = p_order_number and not m.es_automatico
  ) then
    raise exception 'No se puede deshacer: un proceso siguiente ya registro trabajo en el pedido %.', p_order_number;
  end if;

  if exists (select 1 from public.despacho_orden_items i where i.order_number = p_order_number) then
    raise exception 'No se puede deshacer: el pedido % ya tiene despachos.', p_order_number;
  end if;

  if exists (select 1 from public.returns r where r.order_number = p_order_number) then
    raise exception 'No se puede deshacer: el pedido % tiene devoluciones.', p_order_number;
  end if;

  -- Queda constancia de lo que se elimino.
  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  select 'production_movements', m.id, to_jsonb(m), v_perfil, 'Deshacer Envío Enrutado'
    from public.production_movements m
   where m.order_number::text = p_order_number and m.es_automatico;

  delete from public.production_movements m
   where m.order_number::text = p_order_number and m.es_automatico;
  get diagnostics v_n = row_count;

  -- El destino queda confirmado y editable (el pedido no tiene registros).
  update public.order_destino
     set es_automatico = false, enrutado_por = null, enrutado_at = null
   where order_number = p_order_number;

  return v_n;
end;
$$;

revoke all on function public.deshacer_envio_enrutado(text) from public, anon;
grant execute on function public.deshacer_envio_enrutado(text) to authenticated;

comment on function public.deshacer_envio_enrutado(text) is
  'Deshace un Envio Enrutado (091) mientras ningun proceso siguiente haya registrado nada, sin despachos ni devoluciones. Deja log en log_eliminaciones.';

-- ---------------------------------------------------------------------
-- c. El disparador de lineas nuevas ya no usa reglas
-- ---------------------------------------------------------------------
create or replace function public.fn_auto_enrutar_pedido()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_destino text;
begin
  -- Solo si el pedido YA fue enrutado (envio manual o regla antigua): la linea
  -- nueva sigue su destino. Un pedido nuevo no tiene order_destino: no hace nada.
  select d.destino into v_destino
    from public.order_destino d
   where d.order_number = NEW."PedidoNo"::text and d.es_automatico;

  if v_destino is null or coalesce(NEW."Cancelado", false) or coalesce(NEW."CantidadP", 0) <= 0 then
    return NEW;
  end if;

  insert into public.production_movements (
    item_id, order_number, reference, size, quantity,
    from_process, to_process, user_id, observation, es_automatico
  ) values (
    NEW.item_id, NEW."PedidoNo"::text, NEW."NombreR", NEW."Talla"::text, NEW."CantidadP",
    'Refilado', v_destino, null,
    'Enrutamiento automático (línea nueva de un pedido ya enrutado)', true
  );

  return NEW;
end;
$$;

-- ---------------------------------------------------------------------
-- d. vw_pedido_progreso con 2 columnas nuevas al final
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
  select order_number, destino, es_automatico, enrutado_por
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
  coalesce(cb.ok_e, 0)::bigint     as tallas_ok_empaque,
  -- NUEVAS (091): el pedido fue enviado con "Envio Enrutado" por Refilado (no por una regla).
  (dc.enrutado_por is not null)    as enrutado_manual,
  case when dc.enrutado_por is not null then dc.destino end as enrutado_destino
from orden_progreso op
left join movimientos_orden_calc mo on mo.order_number = op.order_number
left join destino_calc dc on dc.order_number = op.order_number
left join cobertura cb on cb.order_number = op.order_number
left join public.pedido_cierre_forzado pcf on pcf.order_number = op.order_number
left join public.profiles cpr on cpr.id = pcf.cerrado_por;

;

comment on view public.vw_pedido_progreso is
  'Progreso agregado por PedidoNo. Desde 090 los pendientes, % por proceso, estado y etapa Fin se calculan POR TALLA y el % no se redondea a 100 si falta algo. tallas_* = tallas con el proceso cubierto. Desde 091: enrutado_manual / enrutado_destino = el pedido se envio con Envio Enrutado de Refilado.';

-- ---------------------------------------------------------------------
-- e. La vista con atributos copia las columnas al crearse: se recrea.
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

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (despues de ejecutar)
--
-- A) Las columnas nuevas existen y, hoy, ningun pedido figura como enrutado a mano:
--   select count(*) filter (where enrutado_manual) as enrutados_a_mano, count(*) as pedidos
--     from public.vw_pedido_progreso;
--   -- esperado: 0 enrutados a mano, y el mismo numero de pedidos de siempre.
--
-- B) Las funciones existen:
--   select proname from pg_proc
--    where proname in ('enrutar_pedido_manual', 'deshacer_envio_enrutado', 'fn_auto_enrutar_pedido');
--   -- esperado: 3 filas.
--
-- C) Sin sesion, las funciones se niegan (no cambia nada):
--   select public.enrutar_pedido_manual('1', 'Mateado');
--   -- esperado: error "Solo Refilado ...".
-- =====================================================================
