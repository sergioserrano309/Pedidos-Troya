-- =====================================================================
-- 045_crear_despacho_parcial.sql
-- crear_despacho pasa a recibir el desglose por talla (p_items) y a
-- validar contra SALDO en vez de "esta orden ya fue despachada".
--
-- Reemplaza la version de 038 (que a su vez venia de 031/030). Como
-- cambia la firma, hay que dropear la anterior explicitamente.
--
-- Se ELIMINAN dos validaciones:
--   1. "Los siguientes pedidos ya pertenecen a otro despacho" (038:95-103)
--      — es justamente lo que ahora queremos permitir.
--   2. porcentaje_empaque = 100 (038:84-93)
--      — ahora se despacha lo que este empacado, sin esperar al pedido
--        completo. El techo lo pone cantidad_disponible.
--
-- Se CONSERVA sin cambios todo lo demas: pesos, cobertura exacta de
-- bultos 1..N, atomicidad, y las dos correcciones de 038 (el WHERE y el
-- RETURNING calificados).
--
-- Concurrencia: se toma un advisory lock por orden, en orden alfabetico
-- para evitar deadlocks. Sin el, dos empaques despachando el mismo
-- pedido a la vez podrian sobregirar el saldo — cada transaccion veria
-- el saldo antes de la otra (READ COMMITTED).
-- =====================================================================

-- Se dropean AMBAS firmas: la vieja de 4 parametros (038) porque queda
-- obsoleta y convivir con la nueva dejaria a PostgREST sin saber cual
-- llamar; y la nueva de 5, para que este archivo se pueda re-ejecutar
-- sin dar "function already exists with same argument types".
drop function if exists public.crear_despacho(text[], integer, numeric[], jsonb);
drop function if exists public.crear_despacho(text[], integer, numeric[], jsonb, jsonb);

create function public.crear_despacho(
  p_order_numbers text[],
  p_total_bultos integer,
  p_pesos numeric[],
  p_asignaciones jsonb,
  p_items jsonb
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
  v_item_invalido text;
  v_sin_saldo text;
  v_ordenes_sin_items text[];
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

  -- Serializa la creacion de despachos por pedido. En orden alfabetico
  -- para que dos llamadas con pedidos solapados no se bloqueen entre si.
  perform pg_advisory_xact_lock(hashtext(t.x))
     from (select unnest(v_ordenes) as x order by 1) t;

  -- ---- Bultos y pesos (sin cambios respecto a 038) ----
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

  -- ---- Desglose por talla (NUEVO) ----
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Debes indicar cuantas unidades salen de cada talla.';
  end if;

  -- Toda talla enviada debe existir y pertenecer a una de las ordenes
  -- seleccionadas.
  select elem->>'item_id' into v_item_invalido
    from jsonb_array_elements(p_items) elem
    where not exists (
      select 1 from public.vw_item_despacho_saldo s
      where s.item_id = elem->>'item_id' and s.order_number = any(v_ordenes)
    )
    limit 1;
  if v_item_invalido is not null then
    raise exception 'La talla % no pertenece a ninguno de los pedidos de esta salida.', v_item_invalido;
  end if;

  -- Cantidades positivas.
  if exists (
    select 1 from jsonb_array_elements(p_items) elem
    where coalesce((elem->>'cantidad')::integer, 0) <= 0
  ) then
    raise exception 'Las cantidades a despachar deben ser mayores a 0.';
  end if;

  -- SALDO: nadie puede despachar mas de lo empacado y aun no despachado.
  select string_agg(
           format('pedido %s talla %s (pide %s, disponible %s)',
                  s.order_number, s.talla, (elem->>'cantidad')::integer, s.cantidad_disponible),
           '; ' order by s.order_number, s.talla)
    into v_sin_saldo
    from jsonb_array_elements(p_items) elem
    join public.vw_item_despacho_saldo s on s.item_id = elem->>'item_id'
    where (elem->>'cantidad')::integer > s.cantidad_disponible;

  if v_sin_saldo is not null then
    raise exception 'No hay saldo suficiente para despachar: %', v_sin_saldo;
  end if;

  -- Cada pedido seleccionado debe aportar al menos una talla.
  select array_agg(x) into v_ordenes_sin_items
    from unnest(v_ordenes) x
    where not exists (
      select 1
      from jsonb_array_elements(p_items) elem
      join public.vw_item_despacho_saldo s on s.item_id = elem->>'item_id'
      where s.order_number = x
    );
  if v_ordenes_sin_items is not null and array_length(v_ordenes_sin_items, 1) > 0 then
    raise exception 'Los siguientes pedidos no tienen unidades asignadas: %', array_to_string(v_ordenes_sin_items, ', ');
  end if;

  -- ---- Asignacion pedido->bulto (sin cambios respecto a 038) ----
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

  -- Desglose por talla. order_number y talla se resuelven desde el saldo
  -- para no confiar en lo que mande el cliente.
  insert into public.despacho_orden_items (despacho_id, order_number, item_id, talla, cantidad)
  select v_id, s.order_number, s.item_id, s.talla, (elem->>'cantidad')::integer
  from jsonb_array_elements(p_items) elem
  join public.vw_item_despacho_saldo s on s.item_id = elem->>'item_id';

  -- Se inserta ANTES de confirmar: el trigger de 027 exige
  -- asignacion_confirmada=false para permitir el insert.
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

grant execute on function public.crear_despacho(text[], integer, numeric[], jsonb, jsonb) to authenticated;

comment on function public.crear_despacho(text[], integer, numeric[], jsonb, jsonb) is
  'Crea un despacho completo (pedidos + bultos + asignacion + desglose por talla) en una transaccion atomica. Desde 045 admite despachos PARCIALES: valida contra saldo disponible por talla en vez de exigir que el pedido no tenga despachos previos.';
