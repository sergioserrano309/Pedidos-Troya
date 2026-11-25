-- =====================================================================
-- 092_salidas_acabado.sql
--
-- Pestaña "Salidas(A)" para Acabado (y el Validador): un registro
-- INFORMATIVO de lo que Acabado saca de su proceso, con la misma mecanica
-- de Despachos (Por Salir -> Crear Salida -> Salida) pero totalmente aparte.
--
-- IMPORTANTE (decidido con el usuario, 2026-11-24)
--   * NO afecta el flujo Acabado -> Empaque ni Despachos. Salidas(A) solo LEE
--     production_movements (lo que Acabado proceso); nunca escribe en ellos.
--     Si Acabado procesa 5 pares, esos 5 van a Empaque como siempre Y quedan
--     disponibles en "Por Salir".
--   * Modulo PARALELO: tablas, funciones y vistas propias (prefijo salida_a /
--     salidas_a). No se toca ninguna pieza de Despachos.
--   * Solo cuenta lo que Acabado procese DESDE HOY (2026-11-24, hora de
--     Colombia). El historico anterior no aparece en "Por Salir".
--
-- REGLAS
--   - Consecutivo propio: A1000, A1001, ...
--   - Salida por talla (parcial): lo disponible por talla = procesado por
--     Acabado (desde la fecha de inicio) - lo ya sacado en otras salidas.
--   - Visto bueno "Revisado": solo el Validador. Revisada, la salida no se
--     puede eliminar (salvo que el Validador quite el visto bueno).
--   - Pedidos cerrados a la fuerza: no admiten salidas nuevas (igual que Despachos).
--   - Si Acabado intenta borrar un registro suyo cuya talla ya salio, la base
--     lo impide: "elimina primero la salida".
--   - Comentario editable solo por el Validador (como Despachos, 063).
--   - Quien las ve: Acabado y Validador.
--
-- QUE CREA
--   a. salidas_a_config (fecha de inicio, ajustable) y 5 tablas + su secuencia.
--   b. Vistas: saldo por talla, pedidos por salir, estado por pedido y registro.
--   c. Funciones: crear_salida_a, eliminar_salida_a_con_motivo,
--      marcar_salida_a_revisada, editar_comentario_salida_a.
--   d. Candados: saldo de ultimo recurso, pedido cerrado, borrado de salida
--      revisada y borrado de registros de Acabado ya sacados.
--   e. Actualizacion en vivo (realtime) de salidas_a.
--
-- NO TOCA: Despachos, Empaque, Troya, Dashboard de unidades, Compensacion,
-- Cambios ERP, movimientos de produccion existentes.
--
-- Reversa: 092_revertir_salidas_acabado.sql
-- Todo va en UNA transaccion: si algo falla, no se aplica nada.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- a. Configuracion y tablas
-- ---------------------------------------------------------------------
create table if not exists public.salidas_a_config (
  id integer primary key default 1 check (id = 1),
  inicio timestamptz not null
);

-- "Desde hoy": 24/11/2026 a las 00:00 hora de Colombia (UTC-5).
insert into public.salidas_a_config (id, inicio)
values (1, timestamptz '2026-11-24 00:00:00-05')
on conflict (id) do nothing;

alter table public.salidas_a_config enable row level security;
drop policy if exists "salidas_a_config_select" on public.salidas_a_config;
create policy "salidas_a_config_select" on public.salidas_a_config
  for select to authenticated using (true);
grant select on public.salidas_a_config to authenticated;
revoke insert, update, delete on public.salidas_a_config from authenticated, anon;

comment on table public.salidas_a_config is
  'Fecha desde la cual cuenta lo que Acabado proceso para "Por Salir" (092). Una sola fila.';

create or replace function public.fn_salida_a_inicio()
returns timestamptz
language sql
stable
as $$
  select inicio from public.salidas_a_config where id = 1;
$$;

create sequence if not exists public.salidas_a_numero_seq start with 1000 increment by 1;

create table if not exists public.salidas_a (
  id uuid primary key default gen_random_uuid(),
  numero_salida integer not null default nextval('public.salidas_a_numero_seq') unique,
  consecutivo text generated always as ('A' || numero_salida::text) stored,
  total_bultos integer not null check (total_bultos > 0),
  comentario text,
  revisado boolean not null default false,
  revisado_por uuid references public.profiles(id),
  revisado_at timestamptz,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  constraint salidas_a_comentario_largo check (comentario is null or char_length(comentario) <= 255)
);

alter sequence public.salidas_a_numero_seq owned by public.salidas_a.numero_salida;
create index if not exists idx_salidas_a_created_at on public.salidas_a(created_at);

create table if not exists public.salida_a_ordenes (
  id uuid primary key default gen_random_uuid(),
  salida_id uuid not null references public.salidas_a(id) on delete cascade,
  order_number text not null,
  created_at timestamptz not null default now(),
  unique (salida_id, order_number)
);
create index if not exists idx_salida_a_ordenes_order on public.salida_a_ordenes(order_number);
create index if not exists idx_salida_a_ordenes_salida on public.salida_a_ordenes(salida_id);

create table if not exists public.salida_a_bultos (
  id uuid primary key default gen_random_uuid(),
  salida_id uuid not null references public.salidas_a(id) on delete cascade,
  bulto_numero integer not null check (bulto_numero >= 1),
  peso numeric(10,2) not null check (peso > 0),
  created_at timestamptz not null default now(),
  unique (salida_id, bulto_numero)
);
create index if not exists idx_salida_a_bultos_salida on public.salida_a_bultos(salida_id);

create table if not exists public.salida_a_orden_bultos (
  id uuid primary key default gen_random_uuid(),
  salida_id uuid not null,
  order_number text not null,
  bulto_numero integer not null check (bulto_numero >= 1),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (salida_id, order_number, bulto_numero),
  foreign key (salida_id, order_number)
    references public.salida_a_ordenes(salida_id, order_number) on delete cascade,
  foreign key (salida_id) references public.salidas_a(id) on delete cascade
);
create index if not exists idx_salida_a_orden_bultos_salida on public.salida_a_orden_bultos(salida_id);

create table if not exists public.salida_a_orden_items (
  id uuid primary key default gen_random_uuid(),
  salida_id uuid not null references public.salidas_a(id) on delete cascade,
  order_number text not null,
  item_id text not null,
  talla text not null,
  cantidad integer not null check (cantidad > 0),
  created_at timestamptz not null default now(),
  unique (salida_id, item_id),
  foreign key (salida_id, order_number)
    references public.salida_a_ordenes(salida_id, order_number) on delete cascade
);
create index if not exists idx_salida_a_orden_items_item on public.salida_a_orden_items(item_id);
create index if not exists idx_salida_a_orden_items_orden on public.salida_a_orden_items(order_number);
create index if not exists idx_salida_a_orden_items_salida on public.salida_a_orden_items(salida_id);

-- RLS: Acabado y Validador leen; nadie escribe directo (solo las funciones).
do $$
declare
  t text;
begin
  foreach t in array array['salidas_a', 'salida_a_ordenes', 'salida_a_bultos', 'salida_a_orden_bultos', 'salida_a_orden_items']
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists %I on public.%I', t || '_select', t);
    execute format(
      'create policy %I on public.%I for select to authenticated using (exists (select 1 from public.profiles pr where pr.auth_id = auth.uid() and lower(pr.role) in (''acabado'', ''validador'')))',
      t || '_select', t);
    execute format('grant select on public.%I to authenticated', t);
    execute format('revoke insert, update, delete on public.%I from authenticated, anon', t);
  end loop;
end
$$;

comment on table public.salidas_a is 'Salidas de Acabado (092): registro informativo, paralelo a Despachos. Consecutivo A1000, A1001...';
comment on table public.salida_a_orden_items is 'Unidades por talla de cada salida de Acabado (092).';

-- ---------------------------------------------------------------------
-- b. Vistas
-- ---------------------------------------------------------------------
-- Saldo por talla: procesado por Acabado (desde la fecha de inicio) menos lo
-- que ya salio. Solo aparecen tallas que Acabado proceso desde esa fecha.
create or replace view public.vw_item_salida_a_saldo
with (security_invoker = true) as
with ped as (
  select
    p.item_id,
    max(p."PedidoNo"::text)               as order_number,
    max(p."Talla"::text)                  as talla,
    sum(coalesce(p."CantidadP", 0))       as cantidad_solicitada
  from public.p_pedidosh p
  where not coalesce(p."Cancelado", false)
  group by p.item_id
),
ac as (
  select m.item_id, sum(m.quantity) as cantidad_procesada
  from public.production_movements m
  where m.from_process = 'Acabado'
    and m.created_at >= public.fn_salida_a_inicio()
  group by m.item_id
),
sa as (
  select i.item_id,
         sum(i.cantidad)               as cantidad_salida,
         count(distinct i.salida_id)   as numero_salidas
  from public.salida_a_orden_items i
  group by i.item_id
)
select
  ped.item_id,
  ped.order_number,
  ped.talla,
  ped.cantidad_solicitada,
  ac.cantidad_procesada,
  coalesce(sa.cantidad_salida, 0)        as cantidad_salida,
  greatest(ac.cantidad_procesada - coalesce(sa.cantidad_salida, 0), 0) as cantidad_disponible,
  coalesce(sa.numero_salidas, 0)         as numero_salidas
from ped
join ac on ac.item_id = ped.item_id
left join sa on sa.item_id = ped.item_id;

grant select on public.vw_item_salida_a_saldo to authenticated;

comment on view public.vw_item_salida_a_saldo is
  'Saldo por talla de Salidas(A): procesado por Acabado desde la fecha de inicio - ya sacado = disponible (092).';

-- Pedidos con algo por salir (columnas explicitas: no dependen de vw_pedido_progreso.*).
create or replace view public.vw_pedidos_por_salir_a
with (security_invoker = true) as
select
  vp.order_number,
  vp.cliente,
  vp.fecha_pedido,
  vp.nombre_referencia,
  vp.material,
  vp.color,
  vp.total_solicitado,
  vp.dias_orden,
  vp.etapa_actual,
  vp.estatus_general,
  vp.total_acabado,
  vp.procesado_acabado,
  vp.pendiente_acabado,
  vp.porcentaje_acabado,
  disp.unidades_disponibles
from public.vw_pedido_progreso vp
join (
  select order_number, sum(cantidad_disponible) as unidades_disponibles
  from public.vw_item_salida_a_saldo
  group by order_number
  having sum(cantidad_disponible) > 0
) disp on disp.order_number = vp.order_number::text;

grant select on public.vw_pedidos_por_salir_a to authenticated;

comment on view public.vw_pedidos_por_salir_a is
  'Pedidos con unidades procesadas por Acabado que aun no han salido (092).';

-- En cuantas salidas esta cada pedido (contador de "Crear Salida").
create or replace view public.vw_pedido_salida_a_estado
with (security_invoker = true) as
select
  i.order_number,
  count(distinct i.salida_id) as numero_salidas,
  sum(i.cantidad)             as unidades_salidas
from public.salida_a_orden_items i
group by i.order_number;

grant select on public.vw_pedido_salida_a_estado to authenticated;

-- Listado de la seccion "Salida": una fila por salida con sus agregados.
create or replace view public.vw_salidas_a_registro
with (security_invoker = true) as
select
  s.id,
  s.numero_salida,
  s.consecutivo,
  s.created_at,
  s.total_bultos,
  s.comentario,
  s.revisado,
  s.revisado_por,
  pr.name                              as revisado_por_nombre,
  s.revisado_at,
  coalesce(o.order_numbers, '{}')      as order_numbers,
  coalesce(o.numero_ordenes, 0)        as numero_ordenes,
  coalesce(c.clientes, '{}')           as clientes,
  coalesce(b.peso_total, 0)            as peso_total,
  coalesce(i.total_unidades, 0)        as total_unidades
from public.salidas_a s
left join public.profiles pr on pr.id = s.revisado_por
left join (
  select salida_id, array_agg(order_number order by order_number) as order_numbers, count(*) as numero_ordenes
  from public.salida_a_ordenes
  group by salida_id
) o on o.salida_id = s.id
left join (
  select so.salida_id, array_agg(distinct p."Cliente") filter (where p."Cliente" is not null) as clientes
  from public.salida_a_ordenes so
  join public.p_pedidosh p on p."PedidoNo"::text = so.order_number
  group by so.salida_id
) c on c.salida_id = s.id
left join (
  select salida_id, sum(peso) as peso_total from public.salida_a_bultos group by salida_id
) b on b.salida_id = s.id
left join (
  select salida_id, sum(cantidad) as total_unidades from public.salida_a_orden_items group by salida_id
) i on i.salida_id = s.id;

grant select on public.vw_salidas_a_registro to authenticated;

comment on view public.vw_salidas_a_registro is
  'Una fila por salida de Acabado con bultos, kilos, unidades, pedidos y clientes (092).';

-- ---------------------------------------------------------------------
-- c. Funciones
-- ---------------------------------------------------------------------
create or replace function public.crear_salida_a(
  p_order_numbers text[],
  p_total_bultos integer,
  p_pesos numeric[],
  p_asignaciones jsonb,
  p_items jsonb,
  p_comentario text default null
)
returns table (
  id uuid,
  numero_salida integer,
  consecutivo text,
  total_bultos integer,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_ordenes text[];
  v_id uuid;
  v_numero integer;
  v_consecutivo text;
  v_created_at timestamptz;
  i integer;
  v_asig_ordenes text[];
  v_asig_bultos integer[];
  v_orden_invalida text;
  v_bulto_invalido integer;
  v_sin_bulto text[];
  v_bultos_sin_uso integer[];
  v_item_invalido text;
  v_sin_saldo text;
  v_ordenes_sin_items text[];
  v_comentario text;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('acabado', 'validador') then
    raise exception 'No tienes permiso para crear salidas de Acabado.';
  end if;

  v_comentario := nullif(trim(coalesce(p_comentario, '')), '');
  if v_comentario is not null and char_length(v_comentario) > 255 then
    raise exception 'El comentario no puede superar 255 caracteres (tiene %).', char_length(v_comentario);
  end if;

  select array_agg(distinct x) into v_ordenes
    from unnest(p_order_numbers) x
    where x is not null and trim(x) <> '';

  if v_ordenes is null or array_length(v_ordenes, 1) = 0 then
    raise exception 'Debes seleccionar al menos un pedido.';
  end if;

  -- Serializa por pedido (orden alfabetico para no bloquearse entre llamadas).
  perform pg_advisory_xact_lock(hashtext('salida_a:' || t.x))
     from (select unnest(v_ordenes) as x order by 1) t;

  if p_total_bultos is null or p_total_bultos <= 0 then
    raise exception 'Debes indicar al menos 1 bulto.';
  end if;

  if p_pesos is null or array_length(p_pesos, 1) is distinct from p_total_bultos then
    raise exception 'Debes indicar el peso de cada uno de los % bultos.', p_total_bultos;
  end if;

  for i in 1..p_total_bultos loop
    if p_pesos[i] is null or p_pesos[i] <= 0 then
      raise exception 'El peso del bulto % debe ser mayor a 0.', i;
    end if;
  end loop;

  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Debes indicar cuantas unidades salen de cada talla.';
  end if;

  select elem->>'item_id' into v_item_invalido
    from jsonb_array_elements(p_items) elem
    where not exists (
      select 1 from public.vw_item_salida_a_saldo s
      where s.item_id = elem->>'item_id' and s.order_number = any(v_ordenes)
    )
    limit 1;
  if v_item_invalido is not null then
    raise exception 'La talla % no pertenece a ninguno de los pedidos de esta salida o no tiene unidades procesadas por Acabado.', v_item_invalido;
  end if;

  if exists (
    select 1 from jsonb_array_elements(p_items) elem
    where coalesce((elem->>'cantidad')::integer, 0) <= 0
  ) then
    raise exception 'Las cantidades de la salida deben ser mayores a 0.';
  end if;

  select string_agg(
           format('pedido %s talla %s (pide %s, disponible %s)',
                  s.order_number, s.talla, (elem->>'cantidad')::integer, s.cantidad_disponible),
           '; ' order by s.order_number, s.talla)
    into v_sin_saldo
    from jsonb_array_elements(p_items) elem
    join public.vw_item_salida_a_saldo s on s.item_id = elem->>'item_id'
    where (elem->>'cantidad')::integer > s.cantidad_disponible;

  if v_sin_saldo is not null then
    raise exception 'No hay saldo suficiente para la salida: %', v_sin_saldo;
  end if;

  select array_agg(x) into v_ordenes_sin_items
    from unnest(v_ordenes) x
    where not exists (
      select 1
      from jsonb_array_elements(p_items) elem
      join public.vw_item_salida_a_saldo s on s.item_id = elem->>'item_id'
      where s.order_number = x
    );
  if v_ordenes_sin_items is not null and array_length(v_ordenes_sin_items, 1) > 0 then
    raise exception 'Los siguientes pedidos no tienen unidades asignadas: %', array_to_string(v_ordenes_sin_items, ', ');
  end if;

  if p_asignaciones is null or jsonb_array_length(p_asignaciones) = 0 then
    raise exception 'Debes asignar al menos un bulto a cada pedido.';
  end if;

  select array_agg(elem->>'order_number'), array_agg((elem->>'bulto_numero')::integer)
    into v_asig_ordenes, v_asig_bultos
    from jsonb_array_elements(p_asignaciones) elem;

  select x into v_orden_invalida
    from unnest(v_asig_ordenes) x
    where x is null or not (x = any(v_ordenes))
    limit 1;
  if v_orden_invalida is not null then
    raise exception 'El pedido % en las asignaciones no pertenece a esta salida.', v_orden_invalida;
  end if;

  select b into v_bulto_invalido
    from unnest(v_asig_bultos) b
    where b is null or b < 1 or b > p_total_bultos
    limit 1;
  if v_bulto_invalido is not null then
    raise exception 'Numero de bulto fuera de rango (1-%): %', p_total_bultos, v_bulto_invalido;
  end if;

  select array_agg(x) into v_sin_bulto
    from unnest(v_ordenes) x
    where not (x = any(v_asig_ordenes));
  if v_sin_bulto is not null and array_length(v_sin_bulto, 1) > 0 then
    raise exception 'Los siguientes pedidos no tienen ningun bulto asignado: %', array_to_string(v_sin_bulto, ', ');
  end if;

  select array_agg(s) into v_bultos_sin_uso
    from generate_series(1, p_total_bultos) s
    where not (s = any(v_asig_bultos));
  if v_bultos_sin_uso is not null and array_length(v_bultos_sin_uso, 1) > 0 then
    raise exception 'Los siguientes numeros de bulto no fueron asignados a ningun pedido: %', array_to_string(v_bultos_sin_uso, ', ');
  end if;

  insert into public.salidas_a (total_bultos, created_by, comentario)
  values (p_total_bultos, v_perfil_id, v_comentario)
  returning salidas_a.id, salidas_a.numero_salida, salidas_a.consecutivo, salidas_a.created_at
    into v_id, v_numero, v_consecutivo, v_created_at;

  insert into public.salida_a_ordenes (salida_id, order_number)
  select v_id, x from unnest(v_ordenes) x;

  insert into public.salida_a_bultos (salida_id, bulto_numero, peso)
  select v_id, s, p_pesos[s] from generate_series(1, p_total_bultos) s;

  -- order_number y talla se resuelven desde el saldo, no de lo que mande el cliente.
  insert into public.salida_a_orden_items (salida_id, order_number, item_id, talla, cantidad)
  select v_id, s.order_number, s.item_id, s.talla, (elem->>'cantidad')::integer
  from jsonb_array_elements(p_items) elem
  join public.vw_item_salida_a_saldo s on s.item_id = elem->>'item_id';

  insert into public.salida_a_orden_bultos (salida_id, order_number, bulto_numero, created_by)
  select v_id, elem->>'order_number', (elem->>'bulto_numero')::integer, v_perfil_id
  from jsonb_array_elements(p_asignaciones) elem;

  return query select v_id, v_numero, v_consecutivo, p_total_bultos, v_created_at;
end;
$$;

revoke all on function public.crear_salida_a(text[], integer, numeric[], jsonb, jsonb, text) from public, anon;
grant execute on function public.crear_salida_a(text[], integer, numeric[], jsonb, jsonb, text) to authenticated;

comment on function public.crear_salida_a(text[], integer, numeric[], jsonb, jsonb, text) is
  'Crea una salida de Acabado completa (bultos, pesos, pedidos, unidades por talla y comentario) en una transaccion (092). Solo Acabado/Validador. No escribe en production_movements.';

create or replace function public.eliminar_salida_a_con_motivo(p_salida_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_snapshot jsonb;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('acabado', 'validador') then
    raise exception 'No tienes permiso para eliminar salidas de Acabado.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar esta salida.';
  end if;

  select jsonb_build_object(
           'salida', to_jsonb(s),
           'ordenes', coalesce((select jsonb_agg(to_jsonb(o) order by o.order_number)
                                  from public.salida_a_ordenes o where o.salida_id = s.id), '[]'::jsonb),
           'items', coalesce((select jsonb_agg(to_jsonb(it) order by it.order_number, it.talla)
                                from public.salida_a_orden_items it where it.salida_id = s.id), '[]'::jsonb),
           'bultos', coalesce((select jsonb_agg(to_jsonb(b) order by b.bulto_numero)
                                 from public.salida_a_bultos b where b.salida_id = s.id), '[]'::jsonb),
           'asignaciones', coalesce((select jsonb_agg(to_jsonb(ob) order by ob.order_number, ob.bulto_numero)
                                       from public.salida_a_orden_bultos ob where ob.salida_id = s.id), '[]'::jsonb)
         )
    into v_snapshot
    from public.salidas_a s
   where s.id = p_salida_id;

  if v_snapshot is null then
    raise exception 'La salida no existe o ya fue eliminada.';
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('salidas_a', p_salida_id, v_snapshot, v_perfil_id, trim(p_motivo));

  -- Las tablas hijas caen por cascade. El candado de "revisada" es un trigger (abajo).
  delete from public.salidas_a where id = p_salida_id;
end;
$$;

revoke all on function public.eliminar_salida_a_con_motivo(uuid, text) from public, anon;
grant execute on function public.eliminar_salida_a_con_motivo(uuid, text) to authenticated;

create or replace function public.marcar_salida_a_revisada(p_salida_id uuid, p_revisado boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_valor boolean := coalesce(p_revisado, false);
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede marcar una salida como revisada.';
  end if;

  update public.salidas_a
     set revisado     = v_valor,
         revisado_por = case when v_valor then v_perfil_id else null end,
         revisado_at  = case when v_valor then now() else null end
   where salidas_a.id = p_salida_id;

  if not found then
    raise exception 'La salida no existe o ya fue eliminada.';
  end if;
end;
$$;

revoke all on function public.marcar_salida_a_revisada(uuid, boolean) from public, anon;
grant execute on function public.marcar_salida_a_revisada(uuid, boolean) to authenticated;

create or replace function public.editar_comentario_salida_a(p_salida_id uuid, p_comentario text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_nuevo text;
  v_anterior text;
  v_consecutivo text;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede editar el comentario de una salida.';
  end if;

  v_nuevo := nullif(trim(coalesce(p_comentario, '')), '');
  if v_nuevo is not null and char_length(v_nuevo) > 255 then
    raise exception 'El comentario no puede superar 255 caracteres (tiene %).', char_length(v_nuevo);
  end if;

  select s.comentario, s.consecutivo into v_anterior, v_consecutivo
    from public.salidas_a s where s.id = p_salida_id for update;
  if not found then
    raise exception 'La salida no existe o ya fue eliminada.';
  end if;

  update public.salidas_a set comentario = v_nuevo where salidas_a.id = p_salida_id;

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (v_perfil_id, 'editar_comentario_salida_a', 'Acabado', v_consecutivo,
          jsonb_build_object('anterior', v_anterior, 'nuevo', v_nuevo), null);
end;
$$;

revoke all on function public.editar_comentario_salida_a(uuid, text) from public, anon;
grant execute on function public.editar_comentario_salida_a(uuid, text) to authenticated;

-- ---------------------------------------------------------------------
-- d. Candados
-- ---------------------------------------------------------------------
-- (1) Ultimo recurso: lo sacado de una talla nunca supera lo procesado por Acabado.
create or replace function public.fn_validar_saldo_salida_a_item()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_procesado numeric;
  v_salido numeric;
begin
  select coalesce(sum(m.quantity), 0) into v_procesado
    from public.production_movements m
   where m.item_id = new.item_id
     and m.from_process = 'Acabado'
     and m.created_at >= public.fn_salida_a_inicio();

  select coalesce(sum(i.cantidad), 0) into v_salido
    from public.salida_a_orden_items i
   where i.item_id = new.item_id;

  if v_salido > v_procesado then
    raise exception 'Saldo excedido en el pedido % talla %: se intentan sacar % unidades y Acabado solo ha procesado %.',
      new.order_number, new.talla, v_salido, v_procesado;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_validar_saldo_salida_a_item on public.salida_a_orden_items;
create constraint trigger trg_validar_saldo_salida_a_item
  after insert or update on public.salida_a_orden_items
  deferrable initially immediate
  for each row
  execute function public.fn_validar_saldo_salida_a_item();

-- (2) Pedido cerrado a la fuerza: no admite salidas nuevas (misma funcion que usa Despachos, 057).
drop trigger if exists trg_bloquear_salida_a_items_pedido_cerrado on public.salida_a_orden_items;
create trigger trg_bloquear_salida_a_items_pedido_cerrado
  before insert or delete on public.salida_a_orden_items
  for each row
  execute function public.fn_bloquear_pedido_cerrado_forzado();

-- (3) Una salida revisada por el Validador no la elimina nadie mas.
create or replace function public.fn_bloquear_borrado_salida_a_revisada()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rol text;
begin
  if old.revisado then
    select lower(pr.role) into v_rol from public.profiles pr where pr.auth_id = auth.uid();
    if coalesce(v_rol, '') <> 'validador' then
      raise exception 'La salida % tiene el visto bueno del Validador. Pidele que lo quite antes de eliminarla.', old.consecutivo;
    end if;
  end if;
  return old;
end;
$$;

drop trigger if exists trg_bloquear_borrado_salida_a_revisada on public.salidas_a;
create trigger trg_bloquear_borrado_salida_a_revisada
  before delete on public.salidas_a
  for each row
  execute function public.fn_bloquear_borrado_salida_a_revisada();

-- (4) Acabado no puede borrar un registro suyo si la talla ya salio por encima de lo que quedaria.
create or replace function public.fn_validar_saldo_acabado_al_borrar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_procesado numeric;
  v_salido numeric;
begin
  if old.from_process <> 'Acabado' or old.created_at < public.fn_salida_a_inicio() then
    return old;
  end if;

  select coalesce(sum(i.cantidad), 0) into v_salido
    from public.salida_a_orden_items i where i.item_id = old.item_id;

  if v_salido = 0 then
    return old;
  end if;

  select coalesce(sum(m.quantity), 0) into v_procesado
    from public.production_movements m
   where m.item_id = old.item_id
     and m.from_process = 'Acabado'
     and m.created_at >= public.fn_salida_a_inicio();

  if v_procesado - old.quantity < v_salido then
    raise exception 'No se puede eliminar: la talla % del pedido % quedaria con menos unidades procesadas por Acabado (%) que las que ya salieron en Salidas(A) (%). Elimina primero la salida.',
      old.size, old.order_number, v_procesado - old.quantity, v_salido;
  end if;

  return old;
end;
$$;

drop trigger if exists trg_validar_saldo_acabado_al_borrar on public.production_movements;
create trigger trg_validar_saldo_acabado_al_borrar
  before delete on public.production_movements
  for each row
  execute function public.fn_validar_saldo_acabado_al_borrar();

-- ---------------------------------------------------------------------
-- e. En vivo: crear/eliminar/revisar/comentar una salida refresca a los demas
-- ---------------------------------------------------------------------
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'salidas_a'
  ) then
    alter publication supabase_realtime add table public.salidas_a;
  end if;
end
$$;

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (despues de ejecutar)
--
-- A) Las vistas responden (hoy deberian dar 0 filas: nada ha salido ni Acabado
--    ha procesado desde la fecha de inicio, o solo lo de hoy):
--   select count(*) from public.vw_pedidos_por_salir_a;
--   select count(*) from public.salidas_a;   -- 0
--
-- B) La fecha de inicio:
--   select inicio from public.salidas_a_config;   -- 2026-11-24 00:00 -05
--
-- C) Sin sesion, la funcion se niega (no cambia nada):
--   select public.crear_salida_a(array['1'], 1, array[1], '[]'::jsonb, '[]'::jsonb);
--   -- esperado: error "No tienes permiso para crear salidas de Acabado."
--
-- D) El candado de borrado de registros de Acabado existe:
--   select tgname from pg_trigger where tgname = 'trg_validar_saldo_acabado_al_borrar' and not tgisinternal;
-- =====================================================================
