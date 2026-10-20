-- =====================================================================
-- 070_aplicar_cliente_erp.sql
-- FASE 2 (primera entrega) de "Cambios ERP": APLICAR el cambio de CLIENTE.
--
-- POR QUE
--   El cliente de un pedido a veces se corrige en Access despues de cargarlo
--   (hoy: 3431, 3467, 3468, 3469). La fase 1 ya los detecta y los muestra.
--   Esta entrega hace que el programa CORRIJA SOLO el nombre del cliente.
--
-- QUE HACE (y solo esto)
--   * Cambia unicamente p_pedidosh."Cliente", en todas las lineas del pedido.
--     Es un texto: no toca cantidades, producciones, despachos, precios ni el
--     estado de ningun pedido. (Se verifico que no hay disparadores sobre
--     p_pedidosh que reaccionen a este cambio, que ninguna tabla guarda una
--     copia del cliente y que el precio no usa el cliente del pedido.)
--   * Aplica en cualquier pedido (abierto, cerrado o despachado).
--
-- PROTECCIONES
--   1. INTERRUPTOR PROPIO, APAGADO de fabrica: erp_cambios_estado.aplicar_cliente.
--      Nada se aplica hasta que usted lo encienda:
--        update public.erp_cambios_estado set aplicar_cliente = true;
--      y se apaga con = false.
--   2. Solo aplica una diferencia que el detector vio IGUAL en 2 revisiones
--      seguidas (~10 min) y revisada en los ultimos 30 minutos.
--   3. Solo aplica si TODAS las lineas del pedido siguen teniendo el cliente
--      que el detector anoto. Si alguien lo cambio mientras tanto, se omite.
--   4. Tope: si hay mas de 10 pedidos listos en una corrida, NO aplica nada
--      y avisa (algo raro pasa).
--   5. Todo es atomico: si algo falla, no queda nada a medias.
--   6. Queda historial en erp_cambios (valor anterior y nuevo, y cuando).
--
-- DESHACER
--   Boton "Deshacer" en la pestana Cambios ERP (solo Validador), o:
--     select public.erp_revertir_cambio_interno(<id de erp_cambios>, 'manual');
--   Restaura el cliente anterior SOLO si el actual sigue siendo el que puso
--   la aplicacion. El cambio queda "rechazado": el detector no lo vuelve a
--   aplicar mientras Access no lo cambie otra vez.
--
-- Reversa: 070_revertir_aplicar_cliente_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Interruptor (apagado de fabrica)
-- ---------------------------------------------------------------------
alter table public.erp_cambios_estado
  add column if not exists aplicar_cliente boolean not null default false;

comment on column public.erp_cambios_estado.aplicar_cliente is
  'Interruptor de la aplicacion automatica del cambio de Cliente (070). false = solo se detecta y se muestra.';

-- ---------------------------------------------------------------------
-- 2. Normalizacion de texto (misma idea que el detector: sin espacios
--    sobrantes y sin diferencia de mayusculas)
-- ---------------------------------------------------------------------
create or replace function public.erp_norm_texto(p text)
returns text
language sql
immutable
as $$
  select upper(regexp_replace(trim(coalesce(p, '')), '\s+', ' ', 'g'))
$$;

-- ---------------------------------------------------------------------
-- 3. Aplicar los cambios de Cliente que ya estan listos
-- ---------------------------------------------------------------------
create or replace function public.erp_aplicar_cambios_cliente()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c_max constant integer := 10;
  v_activo boolean;
  v_aplicar boolean;
  v_listos integer;
  r record;
  v_lineas integer;
  v_coinciden integer;
  v_filas integer;
  v_aplicados integer := 0;
  v_omitidos integer := 0;
begin
  select e.activo, e.aplicar_cliente into v_activo, v_aplicar
    from public.erp_cambios_estado e where e.id = 1;

  if not coalesce(v_activo, true) or not coalesce(v_aplicar, false) then
    return jsonb_build_object('resultado', 'apagado');
  end if;

  select count(*) into v_listos
    from public.erp_cambios c
   where c.estado = 'pendiente' and c.tipo = 'texto' and c.campo = 'Cliente'
     and c.talla is null and not c.ambiguo
     and c.revisiones_consecutivas >= 2
     and c.ultima_revision_at > now() - interval '30 minutes'
     and c.pedido ~ '^[0-9]{1,9}$'
     and case when c.pedido ~ '^[0-9]{1,9}$' then c.pedido::bigint end >= 3095;

  if v_listos > c_max then
    return jsonb_build_object('resultado', 'detenido', 'listos', v_listos,
      'motivo', format('%s pedidos listos (tope %s): se revisa a mano', v_listos, c_max));
  end if;

  for r in
    select c.*
      from public.erp_cambios c
     where c.estado = 'pendiente' and c.tipo = 'texto' and c.campo = 'Cliente'
       and c.talla is null and not c.ambiguo
       and c.revisiones_consecutivas >= 2
       and c.ultima_revision_at > now() - interval '30 minutes'
       and c.pedido ~ '^[0-9]{1,9}$'
       and case when c.pedido ~ '^[0-9]{1,9}$' then c.pedido::bigint end >= 3095
     order by c.id
       for update
  loop
    if length(trim(coalesce(r.valor_access, ''))) = 0 or length(r.valor_access) > 200 then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;

    select count(*),
           count(*) filter (where public.erp_norm_texto(p."Cliente") = public.erp_norm_texto(r.valor_programa))
      into v_lineas, v_coinciden
      from public.p_pedidosh p
     where p."PedidoNo"::text = r.pedido;

    -- Si el pedido no existe o su cliente ya no es el anotado, no se toca.
    if v_lineas = 0 or v_coinciden <> v_lineas then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;

    -- UNICA escritura sobre p_pedidosh: la columna Cliente.
    update public.p_pedidosh p
       set "Cliente" = trim(r.valor_access)
     where p."PedidoNo"::text = r.pedido;

    get diagnostics v_filas = row_count;
    if v_filas <> v_lineas then
      raise exception 'Se esperaba actualizar % lineas y fueron % (pedido %). Se deshace todo.',
        v_lineas, v_filas, r.pedido;
    end if;

    update public.erp_cambios c
       set estado = 'aplicado',
           aplicado_at = now(),
           aplicado_por = 'automatico',
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'aplicado',
             'antes', r.valor_programa, 'despues', r.valor_access, 'lineas', v_filas))
     where c.id = r.id;

    v_aplicados := v_aplicados + 1;
  end loop;

  return jsonb_build_object('resultado', 'ok', 'aplicados', v_aplicados, 'omitidos', v_omitidos);
end;
$$;

comment on function public.erp_aplicar_cambios_cliente() is
  'Aplica los cambios de Cliente detectados (070): solo p_pedidosh."Cliente", tras 2 revisiones iguales, con interruptor apagado de fabrica y tope de 10 pedidos. Solo service_role.';

revoke all on function public.erp_aplicar_cambios_cliente() from public, anon, authenticated;
grant execute on function public.erp_aplicar_cambios_cliente() to service_role;

-- ---------------------------------------------------------------------
-- 4. Deshacer un cambio de Cliente ya aplicado
-- ---------------------------------------------------------------------
create or replace function public.erp_revertir_cambio_interno(p_id bigint, p_quien text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  v_lineas integer;
  v_coinciden integer;
  v_filas integer;
begin
  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;
  if r.estado <> 'aplicado' or r.tipo <> 'texto' or r.campo is distinct from 'Cliente' then
    raise exception 'Solo se puede deshacer un cambio de Cliente que ya fue aplicado.';
  end if;

  select count(*),
         count(*) filter (where public.erp_norm_texto(p."Cliente") = public.erp_norm_texto(r.valor_access))
    into v_lineas, v_coinciden
    from public.p_pedidosh p
   where p."PedidoNo"::text = r.pedido;

  if v_lineas = 0 or v_coinciden <> v_lineas then
    raise exception 'El cliente del pedido % cambio despues de la aplicacion; no se deshace para no pisar ese cambio.', r.pedido;
  end if;

  if exists (select 1 from public.erp_cambios c
              where c.id <> r.id and c.estado in ('pendiente', 'rechazado')
                and c.pedido = r.pedido and c.tipo = 'texto' and c.campo = 'Cliente'
                and c.talla is null) then
    raise exception 'El pedido % ya tiene otra diferencia de Cliente abierta; resuelvala primero.', r.pedido;
  end if;

  update public.p_pedidosh p
     set "Cliente" = r.valor_programa
   where p."PedidoNo"::text = r.pedido;

  get diagnostics v_filas = row_count;
  if v_filas <> v_lineas then
    raise exception 'Se esperaba restaurar % lineas y fueron % (pedido %). Se deshace todo.',
      v_lineas, v_filas, r.pedido;
  end if;

  update public.erp_cambios c
     set estado = 'rechazado',
         ultima_revision_at = now(),
         historial = c.historial || jsonb_build_array(jsonb_build_object(
           'en', now(), 'accion', 'revertido', 'por', p_quien,
           'antes', r.valor_access, 'despues', r.valor_programa))
   where c.id = r.id;

  return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'lineas', v_filas);
end;
$$;

comment on function public.erp_revertir_cambio_interno(bigint, text) is
  'Deshace un cambio de Cliente aplicado (070) si el cliente actual sigue siendo el aplicado. Queda "rechazado": no se vuelve a aplicar. Solo service_role.';

revoke all on function public.erp_revertir_cambio_interno(bigint, text) from public, anon, authenticated;
grant execute on function public.erp_revertir_cambio_interno(bigint, text) to service_role;

-- Version para el boton de la pantalla: solo el Validador.
create or replace function public.erp_revertir_cambio(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles pr
     where pr.auth_id = auth.uid() and lower(pr.role) = 'validador'
  ) then
    raise exception 'Solo el Validador puede deshacer cambios.';
  end if;
  return public.erp_revertir_cambio_interno(p_id, auth.uid()::text);
end;
$$;

comment on function public.erp_revertir_cambio(bigint) is
  'Boton "Deshacer" de la pestana Cambios ERP (070). Solo el Validador.';

revoke all on function public.erp_revertir_cambio(bigint) from public, anon;
grant execute on function public.erp_revertir_cambio(bigint) to authenticated;

commit;

-- =====================================================================
-- PRUEBA SEGURA (ejecutar APARTE, despues de este archivo).
-- Aplica y deshace el cambio de cliente DENTRO de una transaccion que se
-- cancela sola al final: no queda NINGUN cambio. El "error" trae el
-- resultado. Requiere que el detector ya haya registrado el cambio de 3431
-- y lo haya visto 2 veces (columna Rev. >= 2 en la pestana Cambios ERP).
--
--   do $$
--   declare antes text; despues text; tras text; v_id bigint; r1 jsonb; r2 jsonb;
--   begin
--     update public.erp_cambios_estado set aplicar_cliente = true where id = 1;
--     select string_agg(distinct "Cliente", ' / ') into antes from public.p_pedidosh where "PedidoNo" = '3431';
--     r1 := public.erp_aplicar_cambios_cliente();
--     select string_agg(distinct "Cliente", ' / ') into despues from public.p_pedidosh where "PedidoNo" = '3431';
--     select id into v_id from public.erp_cambios where pedido = '3431' and campo = 'Cliente' and estado = 'aplicado';
--     r2 := public.erp_revertir_cambio_interno(v_id, 'prueba');
--     select string_agg(distinct "Cliente", ' / ') into tras from public.p_pedidosh where "PedidoNo" = '3431';
--     raise exception 'PRUEBA (se deshizo todo): antes=% | aplicar=% | despues=% | deshacer=% | tras deshacer=%', antes, r1, despues, r2, tras;
--   end $$;
-- =====================================================================
