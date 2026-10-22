-- =====================================================================
-- 074_cantidades_erp.sql
-- FASE 4 (primera entrega) de "Cambios ERP": CANTIDADES por talla.
--
-- POR QUE
--   Access puede cambiar la cantidad pedida de una talla despues de cargar
--   el pedido (hoy: 31 filas en 7 pedidos). Esa cantidad alimenta el avance,
--   el estado "Completado", las COMISIONES (el trabajo de cada rol se
--   liquida cuando acumula el 100% del total pedido) y los despachos.
--   Por eso estos cambios NUNCA se aplican solos: solo con el boton Aplicar
--   del Validador, viendo antes el impacto.
--
-- QUE AGREGA
--   * erp_estado_talla(pedido, talla)  datos de una talla: cantidad actual,
--       lo ya procesado, lo ya despachado y si tiene enrutamiento automatico.
--   * erp_evaluar_cantidad(id)         evalua un cambio de cantidad:
--       - BLOQUEADO si la nueva cantidad queda por debajo de lo ya procesado
--         (en cualquier proceso) o despachado, si la talla tiene unidades
--         de enrutamiento automatico, o si no hay exactamente una linea;
--       - IMPACTO: total del pedido antes/despues, si sigue "Completado" y,
--         por rol, si su trabajo sigue "liquidable" (acumulado >= total).
--   * erp_impacto_cambios(ids)         lo mismo para varios cambios (el
--       panel lo usa para habilitar o no el boton Aplicar y mostrar el impacto).
--   * erp_aplicar_cambio_interno       ahora tambien aplica CANTIDAD.
--   * erp_revertir_cambio_interno      ahora tambien deshace CANTIDAD.
--
-- QUE ESCRIBE
--   Solo p_pedidosh."CantidadP" de UNA linea (pedido + talla), a peticion del
--   Validador. No toca movimientos, despachos ni cierres. El detalle del
--   enrutamiento automatico (movimientos creados con la cantidad original)
--   NO se ajusta: por eso una talla con unidades automaticas queda bloqueada.
--
-- SEGURIDAD
--   * Solo Validador (se verifica en la base). Funciones internas solo
--     service_role (las usan las pruebas seguras).
--   * Solo lineas sin ambiguedad (clave_linea vacia) y con la cantidad del
--     programa igual a la que el detector anoto.
--   * Deshacer solo si la cantidad actual sigue siendo la aplicada y la
--     cantidad anterior no queda por debajo de lo ya procesado/despachado.
--
-- Reversa: 074_revertir_cantidades_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Datos de una talla (una sola linea de p_pedidosh)
-- ---------------------------------------------------------------------
create or replace function public.erp_estado_talla(p_pedido text, p_talla text)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_lineas integer;
  v_actual integer;
  v_item text;
  v_proc_max integer;
  v_despachadas integer;
  v_auto integer;
begin
  select count(*), min(p."CantidadP"), min(p.item_id)
    into v_lineas, v_actual, v_item
    from public.p_pedidosh p
   where p."PedidoNo"::text = p_pedido
     and upper(trim(p."Talla"::text)) = upper(trim(p_talla))
     and not coalesce(p."Cancelado", false);

  if v_lineas <> 1 then
    return jsonb_build_object('lineas', v_lineas);
  end if;

  -- Lo mas que salio de cualquier proceso (movimientos hechos por personas).
  select coalesce(max(s.total), 0) into v_proc_max
    from (select sum(m.quantity) as total
            from public.production_movements m
           where m.item_id = v_item and not coalesce(m.es_automatico, false)
           group by m.from_process) s;

  select coalesce(sum(i.cantidad), 0) into v_despachadas
    from public.despacho_orden_items i where i.item_id = v_item;

  select coalesce(sum(m.quantity), 0) into v_auto
    from public.production_movements m
   where m.item_id = v_item and coalesce(m.es_automatico, false);

  return jsonb_build_object(
    'lineas', v_lineas, 'item_id', v_item, 'actual', coalesce(v_actual, 0),
    'proc_max', v_proc_max, 'despachadas', v_despachadas, 'auto', v_auto,
    'minimo', greatest(v_proc_max, v_despachadas));
end;
$$;

comment on function public.erp_estado_talla(text, text) is
  'Datos de una talla para decidir un cambio de cantidad (074): cantidad actual, procesado, despachado y unidades automaticas. Solo service_role.';

revoke all on function public.erp_estado_talla(text, text) from public, anon, authenticated;
grant execute on function public.erp_estado_talla(text, text) to service_role;

-- ---------------------------------------------------------------------
-- 2. Evaluar un cambio de cantidad: bloqueo e impacto
-- ---------------------------------------------------------------------
create or replace function public.erp_evaluar_cantidad(p_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  t jsonb;
  v_nueva integer;
  v_registrada integer;
  v_actual integer;
  v_total_actual integer;
  v_total_nuevo integer;
  v_emp_out integer;
  v_roles jsonb;
  v_bloqueado boolean := false;
  v_motivo text;
begin
  select * into r from public.erp_cambios c where c.id = p_id;
  if not found or r.tipo <> 'cantidad' or r.talla is null or r.clave_linea is not null then
    return jsonb_build_object('soportado', false);
  end if;

  begin
    v_nueva := r.valor_access::integer;
    v_registrada := r.valor_programa::integer;
  exception when others then
    return jsonb_build_object('soportado', true, 'bloqueado', true,
      'motivo', 'El valor de la cantidad no es valido.');
  end;

  t := public.erp_estado_talla(r.pedido, r.talla);
  if coalesce((t ->> 'lineas')::integer, 0) <> 1 then
    return jsonb_build_object('soportado', true, 'bloqueado', true,
      'motivo', 'No hay exactamente una linea de esa talla en el programa.');
  end if;
  v_actual := (t ->> 'actual')::integer;

  if v_nueva < 0 then
    v_bloqueado := true; v_motivo := 'La cantidad no puede ser negativa.';
  elsif v_actual <> v_registrada then
    v_bloqueado := true;
    v_motivo := format('La cantidad del programa cambio (ahora %s); espere la proxima revision.', v_actual);
  elsif (t ->> 'auto')::integer > 0 then
    v_bloqueado := true;
    v_motivo := 'Esta talla tiene enrutamiento automatico: sus unidades automaticas no se ajustan solas.';
  elsif v_nueva < (t ->> 'minimo')::integer then
    v_bloqueado := true;
    v_motivo := format('La nueva cantidad (%s) queda por debajo de lo ya procesado o despachado (%s).',
                       v_nueva, (t ->> 'minimo')::integer);
  end if;

  select coalesce(sum(p."CantidadP"), 0) into v_total_actual
    from public.p_pedidosh p
   where p."PedidoNo"::text = r.pedido and not coalesce(p."Cancelado", false);
  v_total_nuevo := v_total_actual - v_actual + v_nueva;

  select coalesce(sum(m.quantity) filter (where m.from_process = 'Empaque'), 0) into v_emp_out
    from public.production_movements m where m.order_number::text = r.pedido;

  select coalesce(jsonb_agg(jsonb_build_object(
           'rol', x.rol, 'acumulado', x.acum,
           'liquidable_hoy', (v_total_actual > 0 and x.acum >= v_total_actual),
           'liquidable_despues', (v_total_nuevo > 0 and x.acum >= v_total_nuevo)) order by x.rol), '[]'::jsonb)
    into v_roles
    from (select lower(m.from_process) as rol, sum(m.quantity) as acum
            from public.production_movements m
           where m.order_number::text = r.pedido and not coalesce(m.es_automatico, false)
           group by lower(m.from_process)) x;

  return jsonb_build_object(
    'soportado', true, 'bloqueado', v_bloqueado, 'motivo', v_motivo,
    'actual', v_actual, 'nueva', v_nueva,
    'minimo', (t ->> 'minimo')::integer,
    'total_actual', v_total_actual, 'total_nuevo', v_total_nuevo,
    'completo_hoy', (v_total_actual > 0 and v_emp_out >= v_total_actual),
    'completo_despues', (v_total_nuevo > 0 and v_emp_out >= v_total_nuevo),
    'cerrado', exists (select 1 from public.pedido_cierre_forzado f where f.order_number = r.pedido),
    'roles', v_roles);
end;
$$;

comment on function public.erp_evaluar_cantidad(bigint) is
  'Evalua un cambio de cantidad (074): si esta bloqueado y que impacto tiene en el total, el estado Completado y la liquidacion por rol. Solo service_role.';

revoke all on function public.erp_evaluar_cantidad(bigint) from public, anon, authenticated;
grant execute on function public.erp_evaluar_cantidad(bigint) to service_role;

-- Version para la pantalla (varios cambios a la vez). Solo el Validador.
create or replace function public.erp_impacto_cambios(p_ids bigint[])
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_id bigint;
  v_res jsonb := '{}'::jsonb;
begin
  if auth.uid() is null or not exists (
    select 1 from public.profiles pr
     where pr.auth_id = auth.uid() and lower(pr.role) = 'validador'
  ) then
    raise exception 'Solo el Validador puede ver el impacto de los cambios.';
  end if;

  if p_ids is null or cardinality(p_ids) = 0 then
    return v_res;
  end if;
  if cardinality(p_ids) > 200 then
    raise exception 'Demasiados cambios en una sola consulta.';
  end if;

  foreach v_id in array p_ids loop
    v_res := v_res || jsonb_build_object(v_id::text, public.erp_evaluar_cantidad(v_id));
  end loop;
  return v_res;
end;
$$;

comment on function public.erp_impacto_cambios(bigint[]) is
  'Bloqueo e impacto de varios cambios de cantidad para la pestana Cambios ERP (074). Solo el Validador.';

revoke all on function public.erp_impacto_cambios(bigint[]) from public, anon;
grant execute on function public.erp_impacto_cambios(bigint[]) to authenticated;

-- ---------------------------------------------------------------------
-- 3. Aplicar a mano: ahora tambien CANTIDAD (ademas de CANCELADO, 073)
-- ---------------------------------------------------------------------
create or replace function public.erp_aplicar_cambio_interno(p_id bigint, p_perfil uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  ev jsonb;
  v_n integer;
begin
  if p_perfil is null then
    raise exception 'Falta el perfil del Validador.';
  end if;

  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  if r.estado not in ('pendiente', 'rechazado') then
    raise exception 'Este cambio ya no esta pendiente.';
  end if;

  -- ---- CANTIDAD ----
  if r.tipo = 'cantidad' then
    ev := public.erp_evaluar_cantidad(p_id);
    if not coalesce((ev ->> 'soportado')::boolean, false) then
      raise exception 'Este cambio de cantidad todavia no se puede aplicar a mano (varias lineas en la talla).';
    end if;
    if coalesce((ev ->> 'bloqueado')::boolean, false) then
      raise exception '%', ev ->> 'motivo';
    end if;

    update public.p_pedidosh p
       set "CantidadP" = (ev ->> 'nueva')::integer
     where p."PedidoNo"::text = r.pedido
       and upper(trim(p."Talla"::text)) = upper(trim(r.talla))
       and not coalesce(p."Cancelado", false);
    get diagnostics v_n = row_count;
    if v_n <> 1 then
      raise exception 'Se esperaba actualizar 1 linea y fueron % (pedido %, talla %). Se deshace todo.', v_n, r.pedido, r.talla;
    end if;

    update public.erp_cambios c
       set estado = 'aplicado', aplicado_at = now(), aplicado_por = 'validador',
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'aplicado', 'por', p_perfil::text,
             'antes', ev ->> 'actual', 'despues', ev ->> 'nueva',
             'total_antes', ev ->> 'total_actual', 'total_despues', ev ->> 'total_nuevo'))
     where c.id = r.id;

    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'talla', r.talla,
                              'accion', 'cantidad', 'impacto', ev);
  end if;

  -- ---- CANCELADO (073) ----
  if r.tipo <> 'cancelado' or r.talla is not null then
    raise exception 'Este tipo de cambio todavia no se puede aplicar a mano.';
  end if;

  if not exists (select 1 from public.p_pedidosh p where p."PedidoNo"::text = r.pedido) then
    raise exception 'El pedido % no existe.', r.pedido;
  end if;

  -- Ya estaba cerrado a la fuerza: se da por atendido, no se toca.
  if exists (select 1 from public.pedido_cierre_forzado f where f.order_number = r.pedido) then
    update public.erp_cambios c
       set estado = 'aplicado', aplicado_at = now(), aplicado_por = 'ya cerrado',
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'ya_cerrado', 'por', p_perfil::text))
     where c.id = r.id;
    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'ya_cerrado');
  end if;

  insert into public.pedido_cierre_forzado (order_number, motivo, cerrado_por)
  values (r.pedido, 'Cancelado en Troya', p_perfil);

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (p_perfil, 'cerrar_forzado', 'Validador', r.pedido, null, 'Cancelado en Troya');

  update public.erp_cambios c
     set estado = 'aplicado', aplicado_at = now(), aplicado_por = 'validador',
         historial = c.historial || jsonb_build_array(jsonb_build_object(
           'en', now(), 'accion', 'cerrado', 'motivo', 'Cancelado en Troya', 'por', p_perfil::text))
   where c.id = r.id;

  return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'cerrado');
end;
$$;

comment on function public.erp_aplicar_cambio_interno(bigint, uuid) is
  'Aplica a mano un cambio pendiente (073/074): CANCELADO (cierra a la fuerza) o CANTIDAD (cambia p_pedidosh.CantidadP de una linea, con bloqueo). Solo service_role.';

revoke all on function public.erp_aplicar_cambio_interno(bigint, uuid) from public, anon, authenticated;
grant execute on function public.erp_aplicar_cambio_interno(bigint, uuid) to service_role;

-- ---------------------------------------------------------------------
-- 4. Deshacer: ahora tambien CANTIDAD (ademas de texto 071 y cancelado 073)
-- ---------------------------------------------------------------------
create or replace function public.erp_revertir_cambio_interno(p_id bigint, p_quien text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  v_n integer;
  t jsonb;
  v_prev integer;
begin
  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  -- ---- CANTIDAD ----
  if r.tipo = 'cantidad' then
    if r.estado <> 'aplicado' or r.aplicado_por is distinct from 'validador' then
      raise exception 'Solo se puede deshacer un cambio de cantidad que el Validador aplico.';
    end if;

    t := public.erp_estado_talla(r.pedido, r.talla);
    if coalesce((t ->> 'lineas')::integer, 0) <> 1 then
      raise exception 'No hay exactamente una linea de esa talla; no se deshace.';
    end if;
    if (t ->> 'actual')::integer is distinct from r.valor_access::integer then
      raise exception 'La cantidad del pedido % talla % cambio despues de la aplicacion; no se deshace para no pisar ese cambio.', r.pedido, r.talla;
    end if;

    v_prev := r.valor_programa::integer;
    if v_prev < (t ->> 'minimo')::integer then
      raise exception 'No se puede deshacer: ya se procesaron o despacharon % unidades y la cantidad anterior (%) quedaria por debajo.',
        (t ->> 'minimo')::integer, v_prev;
    end if;

    if exists (select 1 from public.erp_cambios c
                where c.id <> r.id and c.estado in ('pendiente', 'rechazado')
                  and c.pedido = r.pedido and c.tipo = 'cantidad'
                  and coalesce(c.talla, '') = coalesce(r.talla, '')
                  and coalesce(c.clave_linea, '') = coalesce(r.clave_linea, '')) then
      raise exception 'El pedido % ya tiene otra diferencia de cantidad abierta en esa talla; resuelvala primero.', r.pedido;
    end if;

    update public.p_pedidosh p
       set "CantidadP" = v_prev
     where p."PedidoNo"::text = r.pedido
       and upper(trim(p."Talla"::text)) = upper(trim(r.talla))
       and not coalesce(p."Cancelado", false);
    get diagnostics v_n = row_count;
    if v_n <> 1 then
      raise exception 'Se esperaba restaurar 1 linea y fueron % (pedido %). Se deshace todo.', v_n, r.pedido;
    end if;

    update public.erp_cambios c
       set estado = 'rechazado',
           ultima_revision_at = now(),
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'revertido', 'por', p_quien,
             'antes', r.valor_access, 'despues', v_prev::text))
     where c.id = r.id;

    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'talla', r.talla, 'accion', 'cantidad_restaurada');
  end if;

  if r.tipo <> 'cancelado' then
    return public.erp_revertir_texto_interno(p_id, p_quien);
  end if;

  -- ---- CANCELADO (072/073) ----
  if r.estado <> 'aplicado' or r.aplicado_por not in ('automatico', 'validador') then
    raise exception 'Solo se puede deshacer un cierre por cancelacion hecho por el sistema o por el Validador con Aplicar.';
  end if;

  if exists (select 1 from public.erp_cambios c
              where c.id <> r.id and c.estado in ('pendiente', 'rechazado')
                and c.pedido = r.pedido and c.tipo = 'cancelado'
                and coalesce(c.talla, '') = coalesce(r.talla, '')
                and coalesce(c.campo, '') = coalesce(r.campo, '')
                and coalesce(c.clave_linea, '') = coalesce(r.clave_linea, '')) then
    raise exception 'El pedido % ya tiene otra diferencia de cancelacion abierta; resuelvala primero.', r.pedido;
  end if;

  delete from public.pedido_cierre_forzado f
   where f.order_number = r.pedido
     and f.motivo = 'Cancelado en Troya'
     and ((r.aplicado_por = 'automatico' and f.cerrado_por is null)
          or (r.aplicado_por = 'validador' and f.cerrado_por is not null));
  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'El pedido % ya no tiene el cierre que se aplico (alguien lo reabrio o lo cambio a mano); no se toca.', r.pedido;
  end if;

  update public.erp_cambios c
     set estado = 'rechazado',
         ultima_revision_at = now(),
         historial = c.historial || jsonb_build_array(jsonb_build_object(
           'en', now(), 'accion', 'revertido', 'por', p_quien))
   where c.id = r.id;

  return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'reabierto');
end;
$$;

comment on function public.erp_revertir_cambio_interno(bigint, text) is
  'Deshace un cambio aplicado: texto (071, via erp_revertir_texto_interno), cierre por cancelacion (072/073) o cantidad (074). Queda "rechazado": no se vuelve a aplicar. Solo service_role.';

revoke all on function public.erp_revertir_cambio_interno(bigint, text) from public, anon, authenticated;
grant execute on function public.erp_revertir_cambio_interno(bigint, text) to service_role;

commit;
