-- =====================================================================
-- 048_despacho_todo_disponible.sql
-- Ajuste de flujo confirmado con el usuario: al crear una salida NO se
-- digitan cantidades por talla. Sale TODO lo que este disponible de los
-- pedidos seleccionados.
--
-- El despacho parcial sigue existiendo, pero nace de la realidad del
-- taller y no de un formulario: si de un pedido de 8 pares solo se han
-- empacado 5, la salida lleva esos 5 y el pedido reaparece en
-- "A Despachar" con el saldo cuando se empaquen los otros 3.
--
-- Cambios:
--   1. crear_despacho pierde p_items: el desglose por talla lo calcula
--      el propio RPC desde vw_item_despacho_saldo.
--   2. vw_despachos_resumen expone pedidos_completos, para que el badge
--      del acordeon "Despachado" diga No mientras alguno de sus pedidos
--      siga incompleto.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. vw_despachos_resumen — badge por completitud de sus pedidos
--
-- Se agregan columnas AL FINAL (unica posicion que permite
-- create or replace view). asignacion_confirmada se deja donde estaba:
-- sigue significando "la asignacion a bultos quedo confirmada" y la
-- consume el trigger de 027. El badge de la UI pasa a mirar
-- pedidos_completos vs numero_ordenes.
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
  array_agg(do2.order_number order by do2.order_number) as order_numbers,
  count(*) filter (where e.pedido_completo) as pedidos_completos
from public.despachos d
left join public.despacho_ordenes do2 on do2.despacho_id = d.id
left join public.vw_pedido_despacho_estado e on e.order_number = do2.order_number
group by d.id;

grant select on public.vw_despachos_resumen to authenticated;

comment on view public.vw_despachos_resumen is
  'Un despacho por fila. pedidos_completos (048) cuenta cuantos de sus pedidos ya salieron al 100% sumando todas sus remesas: el badge dice Si solo cuando pedidos_completos = numero_ordenes.';

-- ---------------------------------------------------------------------
-- 2. crear_despacho — sin p_items, despacha todo lo disponible
-- ---------------------------------------------------------------------
drop function if exists public.crear_despacho(text[], integer, numeric[], jsonb);
drop function if exists public.crear_despacho(text[], integer, numeric[], jsonb, jsonb);

create function public.crear_despacho(
  p_order_numbers text[],
  p_total_bultos integer,
  p_pesos numeric[],
  p_asignaciones jsonb
)
returns table (
  id uuid,
  numero_despacho integer,
  consecutivo text,
  total_bultos integer,
  created_at timestamptz,
  asignacion_confirmada boolean
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
  v_confirmada boolean;
  i integer;
  v_asig_ordenes text[];
  v_asig_bultos integer[];
  v_orden_invalida text;
  v_bulto_invalido integer;
  v_sin_bulto text[];
  v_bultos_sin_uso integer[];
  v_sin_saldo text[];
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('empaque', 'validador') then
    raise exception 'No tienes permiso para crear despachos.';
  end if;

  select array_agg(distinct x) into v_ordenes
    from unnest(p_order_numbers) x
    where x is not null and trim(x) <> '';

  if v_ordenes is null or array_length(v_ordenes, 1) = 0 then
    raise exception 'Debes seleccionar al menos un pedido.';
  end if;

  -- Serializa por pedido: sin esto, dos empaques despachando el mismo
  -- pedido a la vez veria cada uno el saldo antes del otro y se
  -- despacharia dos veces lo mismo.
  perform pg_advisory_xact_lock(hashtext(t.x))
     from (select unnest(v_ordenes) as x order by 1) t;

  -- Cada pedido debe tener algo empacado y sin despachar.
  select array_agg(x) into v_sin_saldo
    from unnest(v_ordenes) x
    where not exists (
      select 1 from public.vw_item_despacho_saldo s
      where s.order_number = x and s.cantidad_disponible > 0
    );
  if v_sin_saldo is not null and array_length(v_sin_saldo, 1) > 0 then
    raise exception 'Los siguientes pedidos no tienen unidades disponibles para despachar: %', array_to_string(v_sin_saldo, ', ');
  end if;

  -- ---- Bultos y pesos ----
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

  -- ---- Asignacion pedido->bulto ----
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

  -- ---- Todo valido: crear atomicamente ----
  insert into public.despachos (total_bultos, created_by)
  values (p_total_bultos, v_perfil_id)
  returning despachos.id, despachos.numero_despacho, despachos.consecutivo, despachos.created_at
    into v_id, v_numero, v_consecutivo, v_created_at;

  insert into public.despacho_ordenes (despacho_id, order_number)
  select v_id, x from unnest(v_ordenes) x;

  insert into public.despacho_bultos (despacho_id, bulto_numero, peso)
  select v_id, s, p_pesos[s] from generate_series(1, p_total_bultos) s;

  -- Desglose por talla: TODO lo disponible de cada pedido seleccionado.
  -- La subconsulta ve el saldo previo al insert, que es el correcto.
  insert into public.despacho_orden_items (despacho_id, order_number, item_id, talla, cantidad)
  select v_id, s.order_number, s.item_id, s.talla, s.cantidad_disponible
  from public.vw_item_despacho_saldo s
  where s.order_number = any(v_ordenes) and s.cantidad_disponible > 0;

  -- Antes de confirmar: el trigger de 027 exige asignacion_confirmada=false.
  insert into public.despacho_orden_bultos (despacho_id, order_number, bulto_numero, created_by)
  select v_id, elem->>'order_number', (elem->>'bulto_numero')::integer, v_perfil_id
  from jsonb_array_elements(p_asignaciones) elem;

  update public.despachos
    set asignacion_confirmada = true, confirmed_by = v_perfil_id, confirmed_at = now()
    where despachos.id = v_id
    returning despachos.asignacion_confirmada into v_confirmada;

  return query select v_id, v_numero, v_consecutivo, p_total_bultos, v_created_at, v_confirmada;
end;
$$;

grant execute on function public.crear_despacho(text[], integer, numeric[], jsonb) to authenticated;

comment on function public.crear_despacho(text[], integer, numeric[], jsonb) is
  'Crea un despacho con TODO lo disponible de los pedidos seleccionados (048). El desglose por talla lo calcula el RPC desde vw_item_despacho_saldo; el cliente no envia cantidades. Los despachos parciales nacen de lo que haya empacado, no de un formulario.';
