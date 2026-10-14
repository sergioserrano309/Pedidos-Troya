-- =====================================================================
-- 062_revertir_despacho_comentario.sql
-- Deshace la parte de FUNCION de 062_despacho_comentario.sql: vuelve a
-- crear_despacho exactamente como en 051 (sin p_comentario).
--
-- NO borra la columna despachos.comentario ni su constraint, para no
-- destruir comentarios ya guardados; quedaria sin uso. Si de verdad se
-- quiere eliminarla (PIERDE los comentarios), ejecutar a mano:
--   alter table public.despachos drop constraint if exists despachos_comentario_largo;
--   alter table public.despachos drop column if exists comentario;
--
-- Despues de correrlo, revertir tambien el frontend (git): si el codigo
-- nuevo envia p_comentario contra la funcion de 051, el despacho con
-- comentario falla.
-- =====================================================================

begin;

drop function if exists public.crear_despacho(text[], integer, numeric[], jsonb, jsonb, text);
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

  -- Candado 1: serializa por pedido, en orden alfabetico para que dos
  -- llamadas con pedidos solapados no se bloqueen entre si.
  perform pg_advisory_xact_lock(hashtext(t.x))
     from (select unnest(v_ordenes) as x order by 1) t;

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

  -- ---- Desglose por talla ----
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'Debes indicar cuantas unidades salen de cada talla.';
  end if;

  -- Toda talla enviada debe existir y pertenecer a uno de los pedidos.
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

  if exists (
    select 1 from jsonb_array_elements(p_items) elem
    where coalesce((elem->>'cantidad')::integer, 0) <= 0
  ) then
    raise exception 'Las cantidades a despachar deben ser mayores a 0.';
  end if;

  -- Candado 2: nadie puede despachar mas de lo empacado y aun no despachado.
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

  -- order_number y talla se resuelven desde el saldo, no de lo que mande
  -- el cliente. El candado 3 (trigger) revisa cada fila insertada.
  insert into public.despacho_orden_items (despacho_id, order_number, item_id, talla, cantidad)
  select v_id, s.order_number, s.item_id, s.talla, (elem->>'cantidad')::integer
  from jsonb_array_elements(p_items) elem
  join public.vw_item_despacho_saldo s on s.item_id = elem->>'item_id';

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

grant execute on function public.crear_despacho(text[], integer, numeric[], jsonb, jsonb) to authenticated;

comment on function public.crear_despacho(text[], integer, numeric[], jsonb, jsonb) is
  'Crea un despacho completo en una transaccion atomica, con el desglose por talla que indica el usuario (051). Triple candado de saldo: advisory lock por pedido, validacion contra vw_item_despacho_saldo y trigger en despacho_orden_items.';

commit;
