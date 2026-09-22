-- =====================================================================
-- 038_fix_asignacion_confirmada.sql
-- Correcciones del RPC crear_despacho (031) y políticas de seguridad:
--
-- 1. Bug de WHERE ambiguo: línea 181 de 031 usa `where id = v_id`
--    sin calificar. Como `id` es también columna de RETURNS TABLE,
--    PostgreSQL lanza error 42702 (ambiguous column reference).
--    Solución: calificar `where despachos.id = v_id`.
--
-- 2. Bug de retorno hardcodeado: línea 183 devuelve `true` como
--    literal en vez de leer el valor real. Si el UPDATE afecta 0 filas
--    (por falla de RLS o cualquier otra razón), el cliente se entera
--    pero piensa que sí ocurrió.
--    Solución: capturar el valor con `returning` y devolverlo real.
--
-- 3. Política UPDATE faltante: public.despachos tiene RLS activa
--    (029) pero solo políticas SELECT. Sin política UPDATE, el acceso
--    depende de la propiedad de la función vs la tabla. Riesgo si los
--    owners no coinciden: UPDATE afecta 0 filas en silencio.
--    Solución: política SELECT/UPDATE explícita para empaque/validador.
--
-- 4. Backfill: todos los despachos existentes (D1000–D1003) quedaron
--    con asignacion_confirmada=false porque 030 nunca la ponía en
--    true. Aunque el RPC de 031 la actualiza al final, todos los que
--    se crearon antes están atrapados.
--    Solución: UPDATE a true para los que realmente tienen asignaciones.
-- =====================================================================

-- Recapturar el valor real del UPDATE y devolverlo:
drop function if exists public.crear_despacho(text[], integer, numeric[], jsonb);

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
  v_invalidas text[];
  v_ya_despachadas text[];
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

  -- ---- Validación de asignaciones pedido->bulto (todo o nada) ----
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
    raise exception 'Número de bulto fuera de rango (1-%): %', p_total_bultos, v_bulto_invalido;
  end if;

  select array_agg(x) into v_sin_bulto
    from unnest(v_ordenes) x
    where not (x = any(v_asig_ordenes));
  if v_sin_bulto is not null and array_length(v_sin_bulto, 1) > 0 then
    raise exception 'Los siguientes pedidos no tienen ningún bulto asignado: %', array_to_string(v_sin_bulto, ', ');
  end if;

  select array_agg(s) into v_bultos_sin_uso
    from generate_series(1, p_total_bultos) s
    where not (s = any(v_asig_bultos));
  if v_bultos_sin_uso is not null and array_length(v_bultos_sin_uso, 1) > 0 then
    raise exception 'Los siguientes números de bulto no fueron asignados a ningún pedido: %', array_to_string(v_bultos_sin_uso, ', ');
  end if;

  -- ---- Todo válido: crear atómicamente ----
  insert into public.despachos (total_bultos, created_by)
  values (p_total_bultos, v_perfil_id)
  returning despachos.id, despachos.numero_despacho, despachos.consecutivo, despachos.created_at
    into v_id, v_numero, v_consecutivo, v_created_at;

  insert into public.despacho_ordenes (despacho_id, order_number)
  select v_id, x from unnest(v_ordenes) x;

  insert into public.despacho_bultos (despacho_id, bulto_numero, peso)
  select v_id, s, p_pesos[s] from generate_series(1, p_total_bultos) s;

  -- Se inserta ANTES de confirmar: el trigger de 027 exige
  -- asignacion_confirmada=false para permitir el insert.
  insert into public.despacho_orden_bultos (despacho_id, order_number, bulto_numero, created_by)
  select v_id, elem->>'order_number', (elem->>'bulto_numero')::integer, v_perfil_id
  from jsonb_array_elements(p_asignaciones) elem;

  -- CORRECCIÓN: calificar id y returning, capturar valor real
  update public.despachos
    set asignacion_confirmada = true, confirmed_by = v_perfil_id, confirmed_at = now()
    where despachos.id = v_id
    returning despachos.asignacion_confirmada into v_confirmada;

  -- CORRECCIÓN: devolver valor real, no true hardcodeado
  return query select v_id, v_numero, v_consecutivo, p_total_bultos, v_created_at, v_confirmada;
end;
$$;

grant execute on function public.crear_despacho(text[], integer, numeric[], jsonb) to authenticated;

-- =====================================================================
-- Política UPDATE explícita para evitar que el UPDATE dependa de la
-- propiedad de la función vs la tabla.
-- =====================================================================
drop policy if exists "despachos_update_own_empaque_validador" on public.despachos;
create policy "despachos_update_own_empaque_validador"
on public.despachos
for update
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid()
      and lower(pr.role) in ('empaque', 'validador')
  )
)
with check (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid()
      and lower(pr.role) in ('empaque', 'validador')
  )
);

grant update on public.despachos to authenticated;

-- =====================================================================
-- Backfill: todos los despachos existentes con asignaciones,
-- actualizar a asignacion_confirmada=true.
-- =====================================================================
update public.despachos d
   set asignacion_confirmada = true,
       confirmed_at = coalesce(d.confirmed_at, d.created_at),
       confirmed_by = coalesce(d.confirmed_by, d.created_by)
 where not d.asignacion_confirmada
   and exists (
     select 1 from public.despacho_orden_bultos ob
     where ob.despacho_id = d.id
   );

comment on function public.crear_despacho(text[], integer, numeric[], jsonb) is
  'Crea un despacho completo (pedidos + bultos + asignación pedido->bulto) en una sola transacción atómica. CORREGIDO en 038: WHERE calificado, asignacion_confirmada devuelta real.';
