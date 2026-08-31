-- =====================================================================
-- 030_despachos_rpc.sql
-- RPCs del modulo Despachos. Ambas security definer, siguiendo el mismo
-- patron que eliminar_movimiento_con_motivo (014) y
-- registrar_audit_validador (017): resuelven el perfil real via
-- auth.uid(), validan todo dentro de la funcion, y cualquier
-- raise exception revierte todo lo insertado en esa misma llamada (sin
-- necesitar BEGIN/COMMIT explicito — un bloque plpgsql ya es atomico).
-- =====================================================================

-- ---------------------------------------------------------------------
-- crear_despacho: crea el despacho + vincula los pedidos + crea los N
-- bultos con su peso, todo en una sola transaccion. Valida que cada
-- pedido este 100% completo en Empaque y que ninguno ya pertenezca a
-- otro despacho (Fase 1: un pedido = un despacho, ver 027).
-- ---------------------------------------------------------------------
create or replace function public.crear_despacho(
  p_order_numbers text[],
  p_total_bultos integer,
  p_pesos numeric[]
)
returns table (
  id uuid,
  numero_despacho integer,
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
  v_invalidas text[];
  v_ya_despachadas text[];
  v_id uuid;
  v_numero integer;
  v_consecutivo text;
  v_created_at timestamptz;
  i integer;
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

  select array_agg(x) into v_invalidas
    from unnest(v_ordenes) x
    where not exists (
      select 1 from public.vw_pedido_progreso vp
      where vp.order_number = x and vp.porcentaje_empaque = 100
    );

  if v_invalidas is not null and array_length(v_invalidas, 1) > 0 then
    raise exception 'Los siguientes pedidos no están 100%% completos en Empaque: %', array_to_string(v_invalidas, ', ');
  end if;

  select array_agg(x) into v_ya_despachadas
    from unnest(v_ordenes) x
    where exists (
      select 1 from public.despacho_ordenes do2 where do2.order_number = x
    );

  if v_ya_despachadas is not null and array_length(v_ya_despachadas, 1) > 0 then
    raise exception 'Los siguientes pedidos ya pertenecen a otro despacho: %', array_to_string(v_ya_despachadas, ', ');
  end if;

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

  insert into public.despachos (total_bultos, created_by)
  values (p_total_bultos, v_perfil_id)
  returning despachos.id, despachos.numero_despacho, despachos.consecutivo, despachos.created_at
    into v_id, v_numero, v_consecutivo, v_created_at;

  insert into public.despacho_ordenes (despacho_id, order_number)
  select v_id, x from unnest(v_ordenes) x;

  insert into public.despacho_bultos (despacho_id, bulto_numero, peso)
  select v_id, s, p_pesos[s] from generate_series(1, p_total_bultos) s;

  return query select v_id, v_numero, v_consecutivo, p_total_bultos, v_created_at;
end;
$$;

grant execute on function public.crear_despacho(text[], integer, numeric[]) to authenticated;

-- ---------------------------------------------------------------------
-- confirmar_asignacion_despacho: valida (a) cada pedido tiene >=1 bulto
-- asignado y (b) la union de bultos usados es EXACTAMENTE {1..total_bultos}
-- — ni sobra ni falta ninguno (regla confirmada explícitamente con el
-- usuario, sin excepciones). Si algo falla, rechaza sin escribir nada.
-- ---------------------------------------------------------------------
create or replace function public.confirmar_asignacion_despacho(p_despacho_id uuid)
returns table (
  id uuid,
  consecutivo text,
  asignacion_confirmada boolean,
  confirmed_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_despacho public.despachos;
  v_sin_bulto text[];
  v_bultos_sin_uso integer[];
  v_fuera_de_rango integer;
  v_confirmed_at timestamptz;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('empaque', 'validador') then
    raise exception 'No tienes permiso para confirmar asignaciones de despacho.';
  end if;

  select * into v_despacho from public.despachos where id = p_despacho_id for update;

  if v_despacho.id is null then
    raise exception 'El despacho no existe.';
  end if;

  if v_despacho.asignacion_confirmada then
    raise exception 'Este despacho ya fue confirmado.';
  end if;

  select array_agg(do2.order_number) into v_sin_bulto
    from public.despacho_ordenes do2
    where do2.despacho_id = p_despacho_id
      and not exists (
        select 1 from public.despacho_orden_bultos dob
        where dob.despacho_id = p_despacho_id and dob.order_number = do2.order_number
      );

  if v_sin_bulto is not null and array_length(v_sin_bulto, 1) > 0 then
    raise exception 'Los siguientes pedidos no tienen ningún bulto asignado: %', array_to_string(v_sin_bulto, ', ');
  end if;

  select array_agg(s) into v_bultos_sin_uso
    from generate_series(1, v_despacho.total_bultos) s
    where not exists (
      select 1 from public.despacho_orden_bultos dob
      where dob.despacho_id = p_despacho_id and dob.bulto_numero = s
    );

  if v_bultos_sin_uso is not null and array_length(v_bultos_sin_uso, 1) > 0 then
    raise exception 'Los siguientes números de bulto no fueron asignados a ningún pedido: %', array_to_string(v_bultos_sin_uso, ', ');
  end if;

  select count(*) into v_fuera_de_rango
    from public.despacho_orden_bultos dob
    where dob.despacho_id = p_despacho_id and dob.bulto_numero > v_despacho.total_bultos;

  if v_fuera_de_rango > 0 then
    raise exception 'Se encontraron números de bulto fuera de rango (1-%).', v_despacho.total_bultos;
  end if;

  update public.despachos
    set asignacion_confirmada = true, confirmed_by = v_perfil_id, confirmed_at = now()
    where id = p_despacho_id
    returning despachos.confirmed_at into v_confirmed_at;

  return query select v_despacho.id, v_despacho.consecutivo, true, v_confirmed_at;
end;
$$;

grant execute on function public.confirmar_asignacion_despacho(uuid) to authenticated;
