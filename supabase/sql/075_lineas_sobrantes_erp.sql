-- =====================================================================
-- 075_lineas_sobrantes_erp.sql
-- FASE 4b de "Cambios ERP": LINEAS QUE SOBRAN (el programa tiene una linea
-- que Access ya no tiene).
--
-- POR QUE
--   Caso real: el pedido 3478 tiene DOS lineas por talla en el programa (la
--   que coincide con Access: 2, 2, 3 y 1 pares, y una linea vieja de 5, 7, 5 y
--   3 pares que Access ya no tiene). El programa suma las dos. El Validador
--   decidio que los datos correctos son los de Access.
--
-- QUE HACE
--   Con el boton Aplicar (nunca solo), OCULTA la linea que sobra usando la
--   marca p_pedidosh."Cancelado" = true: el mecanismo que la plataforma ya
--   usa para que una linea deje de contar (todas las vistas de avance y de
--   despachos la excluyen). NO borra la linea, ni movimientos, ni despachos.
--   Deshacer la vuelve a mostrar.
--
-- IMPACTO PREVIO
--   Igual que las cantidades: total del pedido antes/despues, si sigue
--   "Completado" y, por rol, si su trabajo sigue "liquidable". Ocultar una
--   linea con produccion puede completar el pedido de golpe y volver
--   liquidable el trabajo ya hecho.
--
-- BLOQUEO (no hay boton Aplicar)
--   * La linea es la UNICA de su talla y esa talla tiene produccion,
--     despachos o unidades automaticas (ocultarla dejaria la produccion
--     huerfana). Si otra linea visible comparte la talla (caso 3478), los
--     movimientos siguen asociados a esa otra linea y SI se permite.
--   * Ocultarla dejaria el pedido sin ninguna linea visible (use Cancelado).
--   * No se encuentra exactamente UNA linea visible con esos datos (por
--     ejemplo, un duplicado exacto).
--
-- AJUSTE AL DETECTOR (en Supabase, sin tocar el script de la oficina)
--   Una linea oculta sigue existiendo en el programa, asi que el detector
--   seguiria viendo la diferencia cada 5 minutos. Igual que con los
--   cancelados: erp_registrar_cambios no la repite mientras siga igual y la
--   da por resuelta si deja de aparecer 2 revisiones seguidas.
--
-- Reversa: 075_revertir_lineas_sobrantes_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Buscar una linea por su clave (referencia|material|color|detalle vira)
-- ---------------------------------------------------------------------
create or replace function public.erp_buscar_linea(
  p_pedido text, p_talla text, p_clave text, p_cantidad integer, p_cancelada boolean)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_n integer;
  v_item text;
begin
  -- Una clave con sufijo " #2" es un duplicado exacto: no se puede distinguir.
  if p_clave is null or p_clave ~ '\s#[0-9]+$' then
    return jsonb_build_object('n', -1);
  end if;

  select count(*), min(p.item_id) into v_n, v_item
    from public.p_pedidosh p
   where p."PedidoNo"::text = p_pedido
     and upper(trim(p."Talla"::text)) = upper(trim(p_talla))
     and coalesce(p."Cancelado", false) = p_cancelada
     and p."CantidadP" = p_cantidad
     and public.erp_norm_texto(p."Referencia") = public.erp_norm_texto(split_part(p_clave, '|', 1))
     and public.erp_norm_texto(p."MaterialP") = public.erp_norm_texto(split_part(p_clave, '|', 2))
     and public.erp_norm_texto(p."ColorP") = public.erp_norm_texto(split_part(p_clave, '|', 3))
     and public.erp_norm_texto(p."DetalleVira") = public.erp_norm_texto(split_part(p_clave, '|', 4));

  return jsonb_build_object('n', v_n, 'item_id', v_item);
end;
$$;

comment on function public.erp_buscar_linea(text, text, text, integer, boolean) is
  'Cuenta las lineas de p_pedidosh que coinciden con una clave (075). Solo service_role.';

revoke all on function public.erp_buscar_linea(text, text, text, integer, boolean) from public, anon, authenticated;
grant execute on function public.erp_buscar_linea(text, text, text, integer, boolean) to service_role;

-- ---------------------------------------------------------------------
-- 2. Evaluar ocultar una linea que sobra: bloqueo e impacto
-- ---------------------------------------------------------------------
create or replace function public.erp_evaluar_linea_sobrante(p_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  b jsonb;
  v_cant integer;
  v_item text;
  v_otras integer;
  v_otras_cantidad integer;
  v_proc integer;
  v_desp integer;
  v_auto integer;
  v_total_actual integer;
  v_total_nuevo integer;
  v_emp_out integer;
  v_roles jsonb;
  v_bloqueado boolean := false;
  v_motivo text;
begin
  select * into r from public.erp_cambios c where c.id = p_id;
  if not found or r.tipo <> 'linea_sobrante' or r.talla is null or r.clave_linea is null then
    return jsonb_build_object('soportado', false);
  end if;

  begin
    v_cant := r.valor_programa::integer;
  exception when others then
    return jsonb_build_object('soportado', true, 'bloqueado', true, 'tipo', 'linea_sobrante',
      'motivo', 'La cantidad de la linea no es valida.');
  end;

  b := public.erp_buscar_linea(r.pedido, r.talla, r.clave_linea, v_cant, false);
  if coalesce((b ->> 'n')::integer, 0) <> 1 then
    return jsonb_build_object('soportado', true, 'bloqueado', true, 'tipo', 'linea_sobrante',
      'motivo', 'No se encontro exactamente una linea visible con esos datos (pudo cambiar o es un duplicado exacto).');
  end if;
  v_item := b ->> 'item_id';

  -- Otras lineas visibles que comparten el mismo codigo de talla (item).
  select count(*) - 1, coalesce(sum(p."CantidadP"), 0) - v_cant into v_otras, v_otras_cantidad
    from public.p_pedidosh p
   where p."PedidoNo"::text = r.pedido and p.item_id = v_item
     and not coalesce(p."Cancelado", false);

  select coalesce(max(s.total), 0) into v_proc
    from (select sum(m.quantity) as total
            from public.production_movements m
           where m.item_id = v_item and not coalesce(m.es_automatico, false)
           group by m.from_process) s;
  select coalesce(sum(i.cantidad), 0) into v_desp
    from public.despacho_orden_items i where i.item_id = v_item;
  select coalesce(sum(m.quantity), 0) into v_auto
    from public.production_movements m
   where m.item_id = v_item and coalesce(m.es_automatico, false);

  select coalesce(sum(p."CantidadP"), 0) into v_total_actual
    from public.p_pedidosh p
   where p."PedidoNo"::text = r.pedido and not coalesce(p."Cancelado", false);
  v_total_nuevo := v_total_actual - v_cant;

  if v_total_nuevo <= 0 then
    v_bloqueado := true;
    v_motivo := 'Ocultar esta linea dejaria el pedido sin lineas visibles; para eso use la cancelacion del pedido.';
  elsif v_otras = 0 and (v_proc > 0 or v_desp > 0 or v_auto > 0) then
    v_bloqueado := true;
    if v_proc = 0 and v_desp = 0 then
      v_motivo := format('Es la unica linea de esa talla y tiene %s unidades de enrutamiento automatico: no se oculta sola.', v_auto);
    else
      v_motivo := format('Es la unica linea de esa talla y tiene produccion o despachos (procesado %s, despachado %s): no se oculta sola.',
                         v_proc, v_desp);
    end if;
  end if;

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
    'soportado', true, 'bloqueado', v_bloqueado, 'motivo', v_motivo, 'tipo', 'linea_sobrante',
    'talla', r.talla, 'cantidad', v_cant, 'comparte_item', v_otras > 0, 'otras_cantidad', v_otras_cantidad, 'procesado', v_proc,
    'total_actual', v_total_actual, 'total_nuevo', v_total_nuevo,
    'completo_hoy', (v_total_actual > 0 and v_emp_out >= v_total_actual),
    'completo_despues', (v_total_nuevo > 0 and v_emp_out >= v_total_nuevo),
    'cerrado', exists (select 1 from public.pedido_cierre_forzado f where f.order_number = r.pedido),
    'roles', v_roles);
end;
$$;

comment on function public.erp_evaluar_linea_sobrante(bigint) is
  'Evalua ocultar una linea que sobra (075): bloqueo e impacto en total, Completado y liquidacion por rol. Solo service_role.';

revoke all on function public.erp_evaluar_linea_sobrante(bigint) from public, anon, authenticated;
grant execute on function public.erp_evaluar_linea_sobrante(bigint) to service_role;

-- ---------------------------------------------------------------------
-- 3. Reparto por tipo (la pantalla llama a esta) y version para el Validador
-- ---------------------------------------------------------------------
create or replace function public.erp_evaluar_cambio(p_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_tipo text;
begin
  select c.tipo into v_tipo from public.erp_cambios c where c.id = p_id;
  if v_tipo = 'cantidad' then
    return public.erp_evaluar_cantidad(p_id) || jsonb_build_object('tipo', 'cantidad');
  elsif v_tipo = 'linea_sobrante' then
    return public.erp_evaluar_linea_sobrante(p_id);
  end if;
  return jsonb_build_object('soportado', false);
end;
$$;

comment on function public.erp_evaluar_cambio(bigint) is
  'Evalua un cambio segun su tipo (074 cantidad, 075 linea que sobra). Solo service_role.';

revoke all on function public.erp_evaluar_cambio(bigint) from public, anon, authenticated;
grant execute on function public.erp_evaluar_cambio(bigint) to service_role;

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
    v_res := v_res || jsonb_build_object(v_id::text, public.erp_evaluar_cambio(v_id));
  end loop;
  return v_res;
end;
$$;

comment on function public.erp_impacto_cambios(bigint[]) is
  'Bloqueo e impacto de varios cambios (cantidades 074, lineas que sobran 075) para la pestana Cambios ERP. Solo el Validador.';

revoke all on function public.erp_impacto_cambios(bigint[]) from public, anon;
grant execute on function public.erp_impacto_cambios(bigint[]) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Aplicar a mano: ahora tambien LINEA QUE SOBRA (ademas de cantidad 074
--    y cancelado 073)
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

  -- ---- CANTIDAD (074) ----
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

  -- ---- LINEA QUE SOBRA (075): se oculta con Cancelado = true ----
  if r.tipo = 'linea_sobrante' then
    ev := public.erp_evaluar_linea_sobrante(p_id);
    if not coalesce((ev ->> 'soportado')::boolean, false) then
      raise exception 'Este cambio todavia no se puede aplicar a mano.';
    end if;
    if coalesce((ev ->> 'bloqueado')::boolean, false) then
      raise exception '%', ev ->> 'motivo';
    end if;

    update public.p_pedidosh p
       set "Cancelado" = true
     where p."PedidoNo"::text = r.pedido
       and upper(trim(p."Talla"::text)) = upper(trim(r.talla))
       and not coalesce(p."Cancelado", false)
       and p."CantidadP" = r.valor_programa::integer
       and public.erp_norm_texto(p."Referencia") = public.erp_norm_texto(split_part(r.clave_linea, '|', 1))
       and public.erp_norm_texto(p."MaterialP") = public.erp_norm_texto(split_part(r.clave_linea, '|', 2))
       and public.erp_norm_texto(p."ColorP") = public.erp_norm_texto(split_part(r.clave_linea, '|', 3))
       and public.erp_norm_texto(p."DetalleVira") = public.erp_norm_texto(split_part(r.clave_linea, '|', 4));
    get diagnostics v_n = row_count;
    if v_n <> 1 then
      raise exception 'Se esperaba ocultar 1 linea y fueron % (pedido %, talla %). Se deshace todo.', v_n, r.pedido, r.talla;
    end if;

    update public.erp_cambios c
       set estado = 'aplicado', aplicado_at = now(), aplicado_por = 'validador',
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'ocultado', 'por', p_perfil::text,
             'cantidad', ev ->> 'cantidad',
             'total_antes', ev ->> 'total_actual', 'total_despues', ev ->> 'total_nuevo'))
     where c.id = r.id;

    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'talla', r.talla,
                              'accion', 'linea_ocultada', 'impacto', ev);
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
  'Aplica a mano un cambio pendiente (073/074/075): CANCELADO (cierra a la fuerza), CANTIDAD (cambia CantidadP) o LINEA QUE SOBRA (la oculta con Cancelado = true), con bloqueo. Solo service_role.';

revoke all on function public.erp_aplicar_cambio_interno(bigint, uuid) from public, anon, authenticated;
grant execute on function public.erp_aplicar_cambio_interno(bigint, uuid) to service_role;

-- ---------------------------------------------------------------------
-- 5. Deshacer: ahora tambien LINEA QUE SOBRA (vuelve a mostrar la linea)
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
  b jsonb;
  v_prev integer;
begin
  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  -- ---- LINEA QUE SOBRA (075) ----
  if r.tipo = 'linea_sobrante' then
    if r.estado <> 'aplicado' or r.aplicado_por is distinct from 'validador' then
      raise exception 'Solo se puede deshacer una linea que el Validador oculto.';
    end if;

    b := public.erp_buscar_linea(r.pedido, r.talla, r.clave_linea, r.valor_programa::integer, true);
    if coalesce((b ->> 'n')::integer, 0) <> 1 then
      raise exception 'La linea oculta ya no se encuentra exactamente una vez (alguien la cambio); no se toca.';
    end if;

    if exists (select 1 from public.erp_cambios c
                where c.id <> r.id and c.estado in ('pendiente', 'rechazado')
                  and c.pedido = r.pedido and c.tipo = 'linea_sobrante'
                  and coalesce(c.talla, '') = coalesce(r.talla, '')
                  and coalesce(c.clave_linea, '') = coalesce(r.clave_linea, '')) then
      raise exception 'El pedido % ya tiene otra diferencia abierta para esa linea; resuelvala primero.', r.pedido;
    end if;

    update public.p_pedidosh p
       set "Cancelado" = false
     where p."PedidoNo"::text = r.pedido
       and upper(trim(p."Talla"::text)) = upper(trim(r.talla))
       and coalesce(p."Cancelado", false)
       and p."CantidadP" = r.valor_programa::integer
       and public.erp_norm_texto(p."Referencia") = public.erp_norm_texto(split_part(r.clave_linea, '|', 1))
       and public.erp_norm_texto(p."MaterialP") = public.erp_norm_texto(split_part(r.clave_linea, '|', 2))
       and public.erp_norm_texto(p."ColorP") = public.erp_norm_texto(split_part(r.clave_linea, '|', 3))
       and public.erp_norm_texto(p."DetalleVira") = public.erp_norm_texto(split_part(r.clave_linea, '|', 4));
    get diagnostics v_n = row_count;
    if v_n <> 1 then
      raise exception 'Se esperaba mostrar 1 linea y fueron % (pedido %). Se deshace todo.', v_n, r.pedido;
    end if;

    update public.erp_cambios c
       set estado = 'rechazado',
           ultima_revision_at = now(),
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'revertido', 'por', p_quien))
     where c.id = r.id;

    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'talla', r.talla, 'accion', 'linea_mostrada');
  end if;

  -- ---- CANTIDAD (074) ----
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
  'Deshace un cambio aplicado: texto (071, via erp_revertir_texto_interno), cierre por cancelacion (072/073), cantidad (074) o linea oculta (075). Queda "rechazado": no se vuelve a aplicar. Solo service_role.';

revoke all on function public.erp_revertir_cambio_interno(bigint, text) from public, anon, authenticated;
grant execute on function public.erp_revertir_cambio_interno(bigint, text) to service_role;

-- ---------------------------------------------------------------------
-- 6. erp_registrar_cambios: igual a 072, y las LINEAS QUE SOBRAN ya
--    aplicadas (ocultas) tampoco se repiten mientras siga la diferencia.
-- ---------------------------------------------------------------------
create or replace function public.erp_registrar_cambios(p_cambios jsonb, p_resumen jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_activo boolean;
  v_prev_access integer;
  v_access integer := nullif(p_resumen ->> 'lineas_access', '')::integer;
  v_supabase integer := nullif(p_resumen ->> 'lineas_supabase', '')::integer;
  v_recibidas integer;
  v_validas integer;
  v_nuevas integer := 0;
  v_actualizadas integer := 0;
  v_con_cambio integer := 0;
  v_resueltas integer := 0;
  v_resueltas_cancel integer := 0;
  v_pendientes integer;
begin
  select e.activo, e.lineas_access into v_activo, v_prev_access
    from public.erp_cambios_estado e where e.id = 1;

  if not coalesce(v_activo, true) then
    update public.erp_cambios_estado
       set ultima_ejecucion = now(), ultimo_resultado = 'pausado'
     where id = 1;
    return jsonb_build_object('resultado', 'pausado');
  end if;

  if p_cambios is null or jsonb_typeof(p_cambios) <> 'array' then
    raise exception 'p_cambios debe ser un arreglo JSON.';
  end if;

  -- Una lectura vacia o recortada NO se registra: marcaria como "resueltas"
  -- diferencias que siguen existiendo.
  if coalesce(v_access, 0) <= 0 or coalesce(v_supabase, 0) <= 0 then
    raise exception 'La lectura de Access o de Supabase llego vacia; no se registra nada.';
  end if;
  if v_prev_access is not null and v_access < v_prev_access * 0.5 then
    raise exception 'Access devolvio % lineas y la corrida anterior % (menos de la mitad): lectura incompleta, no se registra nada.',
      v_access, v_prev_access;
  end if;

  v_recibidas := jsonb_array_length(p_cambios);
  if v_recibidas > 5000 then
    raise exception 'Demasiadas diferencias en una corrida (%): se detiene por seguridad.', v_recibidas;
  end if;

  -- Conjunto actual, validado y sin repetidos.
  drop table if exists pg_temp._erp_snapshot;
  create temp table _erp_snapshot on commit drop as
  select distinct on (x.pedido, coalesce(x.talla, ''), x.tipo, coalesce(x.campo, ''), coalesce(x.clave_linea, ''))
         x.pedido, x.talla, x.tipo, x.campo, x.clave_linea,
         x.valor_access, x.valor_programa, coalesce(x.ambiguo, false) as ambiguo
    from (
      select trim(r.pedido) as pedido,
             nullif(trim(r.talla), '') as talla,
             r.tipo,
             nullif(trim(r.campo), '') as campo,
             nullif(trim(r.clave_linea), '') as clave_linea,
             r.valor_access,
             r.valor_programa,
             r.ambiguo
        from jsonb_to_recordset(p_cambios) as r(
          pedido text, talla text, tipo text, campo text, clave_linea text,
          valor_access text, valor_programa text, ambiguo boolean)
    ) x
   where x.pedido ~ '^[0-9]{1,9}$'
     and case when x.pedido ~ '^[0-9]{1,9}$' then x.pedido::bigint end >= 3095
     and x.tipo in ('texto', 'identidad', 'cantidad', 'cancelado', 'cancelado_parcial',
                    'linea_nueva', 'linea_sobrante');

  select count(*) into v_validas from pg_temp._erp_snapshot;

  -- Contexto de cada pedido (foto al registrar).
  drop table if exists pg_temp._erp_ctx;
  create temp table _erp_ctx on commit drop as
  select p.pedido,
         jsonb_build_object(
           'movimientos', (select count(*) from public.production_movements m
                            where m.order_number::text = p.pedido
                              and not coalesce(m.es_automatico, false)),
           'despachos', (select count(*) from public.despacho_ordenes d
                          where d.order_number::text = p.pedido),
           'completo', coalesce((select v.etapa_actual = 'Fin'
                                   from public.vw_pedido_progreso v
                                  where v.order_number::text = p.pedido
                                  limit 1), false),
           'cerrado', exists (select 1 from public.pedido_cierre_forzado c
                               where c.order_number::text = p.pedido)
         ) as contexto
    from (select distinct pedido from pg_temp._erp_snapshot) p;

  -- 1) Diferencias que ya estaban: se actualizan (y cuentan una revision mas
  --    si siguen exactamente igual).
  with m as (
    select c.id,
           s.valor_access as va, s.valor_programa as vp, s.ambiguo as amb,
           x.contexto,
           (c.valor_access is distinct from s.valor_access
            or c.valor_programa is distinct from s.valor_programa) as cambio
      from public.erp_cambios c
      join pg_temp._erp_snapshot s
        on s.pedido = c.pedido
       and coalesce(s.talla, '') = coalesce(c.talla, '')
       and s.tipo = c.tipo
       and coalesce(s.campo, '') = coalesce(c.campo, '')
       and coalesce(s.clave_linea, '') = coalesce(c.clave_linea, '')
      join pg_temp._erp_ctx x on x.pedido = s.pedido
     where c.estado in ('pendiente', 'rechazado')
  ), act as (
    update public.erp_cambios c
       set ultima_revision_at = now(),
           revisiones_consecutivas = case when m.cambio then 1
                                          else least(c.revisiones_consecutivas + 1, 100000) end,
           historial = case when m.cambio
                            then c.historial || jsonb_build_array(jsonb_build_object(
                                   'en', now(), 'access', m.va, 'programa', m.vp))
                            else c.historial end,
           valor_access = m.va,
           valor_programa = m.vp,
           ambiguo = m.amb,
           contexto = m.contexto,
           -- Si Access cambio el valor despues de un rechazo, vuelve a ser
           -- una propuesta nueva.
           estado = case when m.cambio and c.estado = 'rechazado' then 'pendiente' else c.estado end
      from m
     where c.id = m.id
    returning m.cambio
  )
  select count(*), count(*) filter (where cambio)
    into v_actualizadas, v_con_cambio
    from act;

  -- 2) Diferencias nuevas. (072) Un CANCELADO ya aplicado no se vuelve a
  --    crear mientras Access siga cancelado: la diferencia persiste porque
  --    el programa no marca las lineas como canceladas.
  insert into public.erp_cambios
    (pedido, talla, tipo, campo, clave_linea, valor_access, valor_programa,
     ambiguo, contexto, historial)
  select s.pedido, s.talla, s.tipo, s.campo, s.clave_linea, s.valor_access,
         s.valor_programa, s.ambiguo, x.contexto,
         jsonb_build_array(jsonb_build_object(
           'en', now(), 'access', s.valor_access, 'programa', s.valor_programa))
    from pg_temp._erp_snapshot s
    join pg_temp._erp_ctx x on x.pedido = s.pedido
   where not exists (
     select 1 from public.erp_cambios c
      where c.estado in ('pendiente', 'rechazado')
        and c.pedido = s.pedido
        and coalesce(c.talla, '') = coalesce(s.talla, '')
        and c.tipo = s.tipo
        and coalesce(c.campo, '') = coalesce(s.campo, '')
        and coalesce(c.clave_linea, '') = coalesce(s.clave_linea, ''))
     and not exists (
     select 1 from public.erp_cambios c
      where c.estado = 'aplicado' and c.tipo in ('cancelado', 'linea_sobrante') and s.tipo = c.tipo
        and c.pedido = s.pedido
        and coalesce(c.talla, '') = coalesce(s.talla, '')
        and coalesce(c.campo, '') = coalesce(s.campo, '')
        and coalesce(c.clave_linea, '') = coalesce(s.clave_linea, ''));
  get diagnostics v_nuevas = row_count;

  -- 3) Las que ya no aparecen: Access y el programa volvieron a coincidir.
  update public.erp_cambios c
     set estado = 'resuelto',
         resuelto_at = now(),
         ultima_revision_at = now()
   where c.estado in ('pendiente', 'rechazado')
     and not exists (
       select 1 from pg_temp._erp_snapshot s
        where s.pedido = c.pedido
          and coalesce(s.talla, '') = coalesce(c.talla, '')
          and s.tipo = c.tipo
          and coalesce(s.campo, '') = coalesce(c.campo, '')
          and coalesce(s.clave_linea, '') = coalesce(c.clave_linea, ''));
  get diagnostics v_resueltas = row_count;

  -- 3b) (072) Cancelados YA aplicados. Mientras Access siga cancelado la fila
  --     sigue en la lectura: se limpia el contador de ausencias. Si deja de
  --     aparecer se cuenta la ausencia; con 2 revisiones seguidas pasa a
  --     "resuelto" (Access ya no lo tiene cancelado) y se podra reabrir.
  update public.erp_cambios c
     set contexto = c.contexto - 'ausencias'
   where c.estado = 'aplicado' and c.tipo in ('cancelado', 'linea_sobrante') and c.contexto ? 'ausencias'
     and exists (
       select 1 from pg_temp._erp_snapshot s
        where s.pedido = c.pedido and s.tipo = c.tipo
          and coalesce(s.talla, '') = coalesce(c.talla, '')
          and coalesce(s.campo, '') = coalesce(c.campo, '')
          and coalesce(s.clave_linea, '') = coalesce(c.clave_linea, ''));

  update public.erp_cambios c
     set contexto = jsonb_set(c.contexto, '{ausencias}',
                              to_jsonb(coalesce((c.contexto ->> 'ausencias')::integer, 0) + 1)),
         ultima_revision_at = now()
   where c.estado = 'aplicado' and c.tipo in ('cancelado', 'linea_sobrante')
     and not exists (
       select 1 from pg_temp._erp_snapshot s
        where s.pedido = c.pedido and s.tipo = c.tipo
          and coalesce(s.talla, '') = coalesce(c.talla, '')
          and coalesce(s.campo, '') = coalesce(c.campo, '')
          and coalesce(s.clave_linea, '') = coalesce(c.clave_linea, ''));

  update public.erp_cambios c
     set estado = 'resuelto',
         resuelto_at = now()
   where c.estado = 'aplicado' and c.tipo in ('cancelado', 'linea_sobrante')
     and coalesce((c.contexto ->> 'ausencias')::integer, 0) >= 2;
  get diagnostics v_resueltas_cancel = row_count;
  v_resueltas := v_resueltas + v_resueltas_cancel;

  select count(*) into v_pendientes from public.erp_cambios where estado = 'pendiente';

  update public.erp_cambios_estado
     set ultima_ejecucion = now(),
         ultimo_resultado = 'ok',
         lineas_access = v_access,
         lineas_supabase = v_supabase,
         cambios_pendientes = v_pendientes,
         nuevas = v_nuevas,
         resueltas = v_resueltas
   where id = 1;

  return jsonb_build_object(
    'resultado', 'ok',
    'recibidas', v_recibidas,
    'validas', v_validas,
    'descartadas', v_recibidas - v_validas,
    'nuevas', v_nuevas,
    'actualizadas', v_actualizadas,
    'con_valor_distinto', v_con_cambio,
    'resueltas', v_resueltas,
    'pendientes', v_pendientes
  );
end;
$$;

comment on function public.erp_registrar_cambios(jsonb, jsonb) is
  'Concilia el conjunto completo de diferencias Access vs programa de una revision (069, ajustada en 072 para cancelados y en 075 para lineas ocultas ya aplicados). No modifica ningun pedido. Solo service_role.';

revoke all on function public.erp_registrar_cambios(jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.erp_registrar_cambios(jsonb, jsonb) to service_role;


commit;
