-- =====================================================================
-- 077_identidad_erp.sql
-- FASE 5 (Etapa 2) de "Cambios ERP": MATERIAL, COLOR y REFERENCIA.
--
-- REQUISITO: 076_item_id_fijo.sql ya ejecutado (el codigo interno de cada
-- linea esta congelado). Por eso estas funciones se NIEGAN a actuar si
-- item_id todavia fuera una columna calculada: cambiarian el codigo y la
-- linea perderia su historial.
--
-- QUE HACE
--   Con el boton Aplicar (nunca solo), cambia p_pedidosh."MaterialP",
--   "ColorP" o "Referencia" de TODAS las tallas de un pedido que Access
--   corrigio (el mismo cambio en todas: se aplica POR PEDIDO, no por talla).
--   Como el codigo interno esta congelado, la linea conserva todo su
--   historial: registros de produccion, devoluciones y despachos.
--
-- IMPACTO PREVIO (lo muestra la pantalla antes de confirmar)
--   * Tallas afectadas, registros de produccion y unidades despachadas.
--   * PRECIO POR PAR de cada rol antes y despues del cambio (se calcula con
--     nombre de suela + material + color + destino). Solo afecta a los
--     registros que se hagan DESPUES: los ya hechos conservan su precio.
--   * Si el pedido tiene despachos: sus fichas y PDF mostraran el dato nuevo
--     (leen el dato en vivo).
--
-- BLOQUEO (no hay boton Aplicar)
--   * item_id aun calculado (falta 076).
--   * Alguna talla no tiene exactamente UNA linea, o su valor en el
--     programa ya no es el que el detector anoto.
--   * El valor nuevo viene vacio (borrar un dato queda a revision manual).
--
-- DESCARTAR / DESHACER tambien actuan sobre todo el pedido (todas sus
-- tallas). Deshacer restaura el valor anterior TAL CUAL estaba.
--
-- Reversa: 077_revertir_identidad_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Ayudas
-- ---------------------------------------------------------------------
create or replace function public.erp_columna_identidad(p_campo text)
returns text
language sql
immutable
as $$
  select case p_campo
    when 'MaterialP' then 'MaterialP'
    when 'ColorP' then 'ColorP'
    when 'Referencia' then 'Referencia'
    else null
  end
$$;

create or replace function public.erp_item_id_congelado()
returns boolean
language sql
stable
as $$
  select coalesce((select a.attgenerated = ''
                     from pg_attribute a
                    where a.attrelid = 'public.p_pedidosh'::regclass
                      and a.attname = 'item_id' and not a.attisdropped), false)
$$;

-- Las filas de un mismo cambio de identidad: mismo pedido, campo, valor
-- nuevo y estado (pendiente o descartado).
create or replace function public.erp_grupo_identidad(p_id bigint)
returns bigint[]
language sql
stable
as $$
  select coalesce(array_agg(m.id order by m.id), '{}'::bigint[])
    from public.erp_cambios r
    join public.erp_cambios m
      on m.pedido = r.pedido and m.tipo = 'identidad' and m.campo is not distinct from r.campo
     and m.valor_access is not distinct from r.valor_access
     and m.estado = r.estado
     and m.talla is not null and m.clave_linea is null
   where r.id = p_id
$$;

revoke all on function public.erp_columna_identidad(text) from public, anon, authenticated;
revoke all on function public.erp_item_id_congelado() from public, anon, authenticated;
revoke all on function public.erp_grupo_identidad(bigint) from public, anon, authenticated;
grant execute on function public.erp_columna_identidad(text) to service_role;
grant execute on function public.erp_item_id_congelado() to service_role;
grant execute on function public.erp_grupo_identidad(bigint) to service_role;

-- ---------------------------------------------------------------------
-- 2. Evaluar un cambio de identidad (bloqueo e impacto)
-- ---------------------------------------------------------------------
create or replace function public.erp_evaluar_identidad(p_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  m record;
  v_ids bigint[];
  v_col text;
  v_nuevo text;
  v_lineas integer;
  v_coinciden integer;
  v_actual text;
  v_tallas text[] := '{}';
  v_bloqueado boolean := false;
  v_motivo text;
  v_nombre text;
  v_mat text;
  v_color text;
  v_destino text;
  v_precios jsonb;
  v_registros bigint;
  v_despachadas bigint;
begin
  select * into r from public.erp_cambios c where c.id = p_id;
  if not found or r.tipo <> 'identidad' or r.talla is null or r.clave_linea is not null then
    return jsonb_build_object('soportado', false);
  end if;
  v_col := public.erp_columna_identidad(r.campo);
  if v_col is null then
    return jsonb_build_object('soportado', false);
  end if;

  v_ids := public.erp_grupo_identidad(p_id);
  v_nuevo := trim(coalesce(r.valor_access, ''));

  if not public.erp_item_id_congelado() then
    v_bloqueado := true;
    v_motivo := 'El codigo interno de las lineas aun se calcula solo: falta congelarlo (076) antes de cambiar material, color o referencia.';
  elsif v_nuevo = '' or length(v_nuevo) > 200 then
    v_bloqueado := true;
    v_motivo := 'El valor nuevo esta vacio o es demasiado largo; borrar un dato queda para revision manual.';
  end if;

  for m in select * from public.erp_cambios c where c.id = any (v_ids) order by c.id loop
    execute format(
      'select count(*), '
      || 'count(*) filter (where public.erp_norm_texto(%1$I::text) = public.erp_norm_texto($1)), '
      || 'min(%1$I::text) '
      || 'from public.p_pedidosh '
      || 'where "PedidoNo"::text = $2 and upper(trim("Talla"::text)) = upper(trim($3)) '
      || 'and not coalesce("Cancelado", false)', v_col)
      into v_lineas, v_coinciden, v_actual
      using m.valor_programa, m.pedido, m.talla;

    v_tallas := v_tallas || m.talla;
    if not v_bloqueado then
      if v_lineas <> 1 then
        v_bloqueado := true;
        v_motivo := format('La talla %s no tiene exactamente una linea en el programa.', m.talla);
      elsif v_coinciden <> 1 then
        v_bloqueado := true;
        v_motivo := format('El dato de la talla %s cambio en el programa (ahora "%s"); espere la proxima revision.',
                           m.talla, coalesce(v_actual, ''));
      end if;
    end if;
  end loop;

  select count(*) into v_registros from public.production_movements pm
   where pm.order_number::text = r.pedido and not coalesce(pm.es_automatico, false);
  select coalesce(sum(i.cantidad), 0) into v_despachadas
    from public.despacho_orden_items i
    join public.p_pedidosh p on p.item_id = i.item_id
   where p."PedidoNo"::text = r.pedido;

  -- Precio por par (nuevos registros) con el dato actual y con el nuevo.
  select p."NombreR", p."MaterialP", p."ColorP"
    into v_nombre, v_mat, v_color
    from public.p_pedidosh p
   where p."PedidoNo"::text = r.pedido and upper(trim(p."Talla"::text)) = upper(trim(r.talla))
     and not coalesce(p."Cancelado", false)
   limit 1;
  select d.destino into v_destino from public.order_destino d where d.order_number = r.pedido;

  select coalesce(jsonb_agg(jsonb_build_object(
           'rol', x.rol,
           'hoy', public.fn_precio_aplicable(x.rol, v_nombre, v_mat, v_color, v_destino),
           'despues', public.fn_precio_aplicable(x.rol, v_nombre,
                        case when r.campo = 'MaterialP' then v_nuevo else v_mat end,
                        case when r.campo = 'ColorP' then v_nuevo else v_color end, v_destino)
         ) order by x.ord), '[]'::jsonb)
    into v_precios
    from (values ('refilado', 1), ('acabado', 2), ('mateado', 3), ('empaque', 4)) as x(rol, ord);

  return jsonb_build_object(
    'soportado', true, 'bloqueado', v_bloqueado, 'motivo', v_motivo, 'tipo', 'identidad',
    'campo', r.campo, 'actual', r.valor_programa, 'nuevo', v_nuevo,
    'tallas', to_jsonb(v_tallas), 'n_tallas', cardinality(v_tallas),
    'registros', v_registros, 'despachadas', v_despachadas,
    'cerrado', exists (select 1 from public.pedido_cierre_forzado f where f.order_number = r.pedido),
    'precios', v_precios);
end;
$$;

comment on function public.erp_evaluar_identidad(bigint) is
  'Evalua cambiar material, color o referencia de todas las tallas de un pedido (077): bloqueo e impacto (registros, despachos, precio por par). Solo service_role.';

revoke all on function public.erp_evaluar_identidad(bigint) from public, anon, authenticated;
grant execute on function public.erp_evaluar_identidad(bigint) to service_role;

-- ---------------------------------------------------------------------
-- 3. Reparto por tipo (la pantalla llama a esta): cantidad, linea que
--    sobra e identidad
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
  elsif v_tipo = 'identidad' then
    return public.erp_evaluar_identidad(p_id);
  end if;
  return jsonb_build_object('soportado', false);
end;
$$;

comment on function public.erp_evaluar_cambio(bigint) is
  'Evalua un cambio segun su tipo (074 cantidad, 075 linea que sobra, 077 identidad). Solo service_role.';

revoke all on function public.erp_evaluar_cambio(bigint) from public, anon, authenticated;
grant execute on function public.erp_evaluar_cambio(bigint) to service_role;

-- ---------------------------------------------------------------------
-- 4. Descartar: una identidad se descarta para TODAS las tallas del pedido
-- ---------------------------------------------------------------------
create or replace function public.erp_descartar_cambio_interno(p_id bigint, p_perfil uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  v_n integer;
begin
  if p_perfil is null then
    raise exception 'Falta el perfil del Validador.';
  end if;

  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  if r.estado <> 'pendiente' then
    raise exception 'Solo se puede descartar un cambio pendiente.';
  end if;

  if r.tipo = 'identidad' and r.talla is not null and r.clave_linea is null then
    update public.erp_cambios c
       set estado = 'rechazado',
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'descartado', 'por', p_perfil::text))
     where c.id = any (public.erp_grupo_identidad(p_id));
    get diagnostics v_n = row_count;
    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'descartado', 'filas', v_n);
  end if;

  update public.erp_cambios c
     set estado = 'rechazado',
         historial = c.historial || jsonb_build_array(jsonb_build_object(
           'en', now(), 'accion', 'descartado', 'por', p_perfil::text))
   where c.id = r.id;

  return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'accion', 'descartado');
end;
$$;

comment on function public.erp_descartar_cambio_interno(bigint, uuid) is
  'Descarta (rechaza) una diferencia pendiente (073; 077: la identidad se descarta para todas las tallas del pedido). No toca ningun pedido. Solo service_role.';

revoke all on function public.erp_descartar_cambio_interno(bigint, uuid) from public, anon, authenticated;
grant execute on function public.erp_descartar_cambio_interno(bigint, uuid) to service_role;

-- ---------------------------------------------------------------------
-- 5. Aplicar a mano: ahora tambien IDENTIDAD (ademas de cantidad 074,
--    linea que sobra 075 y cancelado 073)
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
  m record;
  v_ids bigint[];
  v_col text;
  v_crudo text;
  v_nuevo text;
  v_ahora timestamptz := now();
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

  -- ---- IDENTIDAD (077): material / color / referencia de TODAS las tallas del pedido ----
  if r.tipo = 'identidad' then
    ev := public.erp_evaluar_identidad(p_id);
    if not coalesce((ev ->> 'soportado')::boolean, false) then
      raise exception 'Este cambio de identidad todavia no se puede aplicar a mano (varias lineas en la talla).';
    end if;
    if coalesce((ev ->> 'bloqueado')::boolean, false) then
      raise exception '%', ev ->> 'motivo';
    end if;
    if not public.erp_item_id_congelado() then
      raise exception 'El codigo interno de las lineas aun se calcula solo; falta congelarlo (076).';
    end if;

    v_col := public.erp_columna_identidad(r.campo);
    v_nuevo := trim(r.valor_access);
    v_ids := public.erp_grupo_identidad(p_id);

    for m in select * from public.erp_cambios c where c.id = any (v_ids) order by c.id for update loop
      execute format(
        'select %1$I::text from public.p_pedidosh '
        || 'where "PedidoNo"::text = $1 and upper(trim("Talla"::text)) = upper(trim($2)) '
        || 'and not coalesce("Cancelado", false)', v_col)
        into v_crudo using m.pedido, m.talla;

      -- UNICA escritura sobre p_pedidosh: la columna de identidad de esa linea.
      execute format(
        'update public.p_pedidosh set %1$I = $1 '
        || 'where "PedidoNo"::text = $2 and upper(trim("Talla"::text)) = upper(trim($3)) '
        || 'and not coalesce("Cancelado", false)', v_col)
        using v_nuevo, m.pedido, m.talla;
      get diagnostics v_n = row_count;
      if v_n <> 1 then
        raise exception 'Se esperaba actualizar 1 linea y fueron % (pedido %, talla %). Se deshace todo.', v_n, m.pedido, m.talla;
      end if;

      update public.erp_cambios c
         set estado = 'aplicado', aplicado_at = v_ahora, aplicado_por = 'validador',
             historial = c.historial || jsonb_build_array(jsonb_build_object(
               'en', v_ahora, 'accion', 'aplicado', 'por', p_perfil::text,
               'antes', m.valor_programa, 'antes_crudo', v_crudo, 'despues', v_nuevo))
       where c.id = m.id;
    end loop;

    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'campo', r.campo,
                              'accion', 'identidad', 'tallas', cardinality(v_ids), 'impacto', ev);
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

revoke all on function public.erp_aplicar_cambio_interno(bigint, uuid) from public, anon, authenticated;
grant execute on function public.erp_aplicar_cambio_interno(bigint, uuid) to service_role;

comment on function public.erp_aplicar_cambio_interno(bigint, uuid) is
  'Aplica a mano un cambio pendiente (073/074/075/077): CANCELADO (cierra a la fuerza), CANTIDAD, LINEA QUE SOBRA (la oculta con Cancelado = true) o IDENTIDAD (material, color o referencia de todas las tallas del pedido), con bloqueo. Solo service_role.';


-- ---------------------------------------------------------------------
-- 6. Deshacer: ahora tambien IDENTIDAD (restaura el valor anterior TAL CUAL)
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
  m record;
  v_ids bigint[];
  v_col text;
  v_lineas integer;
  v_coinciden integer;
  v_prev_txt text;
begin
  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  -- ---- IDENTIDAD (077): se deshace todo el pedido aplicado junto ----
  if r.tipo = 'identidad' then
    if r.estado <> 'aplicado' or r.aplicado_por is distinct from 'validador' then
      raise exception 'Solo se puede deshacer un cambio de identidad que el Validador aplico.';
    end if;
    v_col := public.erp_columna_identidad(r.campo);
    if v_col is null then
      raise exception 'Campo de identidad no valido.';
    end if;

    select coalesce(array_agg(c.id order by c.id), '{}'::bigint[]) into v_ids
      from public.erp_cambios c
     where c.pedido = r.pedido and c.tipo = 'identidad' and c.campo is not distinct from r.campo
       and c.estado = 'aplicado' and c.aplicado_por = 'validador'
       and c.aplicado_at is not distinct from r.aplicado_at
       and c.valor_access is not distinct from r.valor_access;

    -- 1) Se comprueba TODO antes de tocar nada.
    for m in select * from public.erp_cambios c where c.id = any (v_ids) order by c.id loop
      execute format(
        'select count(*), '
        || 'count(*) filter (where public.erp_norm_texto(%1$I::text) = public.erp_norm_texto($1)) '
        || 'from public.p_pedidosh '
        || 'where "PedidoNo"::text = $2 and upper(trim("Talla"::text)) = upper(trim($3)) '
        || 'and not coalesce("Cancelado", false)', v_col)
        into v_lineas, v_coinciden using m.valor_access, m.pedido, m.talla;
      if v_lineas <> 1 or v_coinciden <> 1 then
        raise exception 'El dato de la talla % del pedido % cambio despues de la aplicacion; no se deshace para no pisar ese cambio.', m.talla, m.pedido;
      end if;
      if exists (select 1 from public.erp_cambios c
                  where c.estado in ('pendiente', 'rechazado') and c.pedido = m.pedido
                    and c.tipo = 'identidad' and c.campo is not distinct from m.campo
                    and coalesce(c.talla, '') = coalesce(m.talla, '')
                    and coalesce(c.clave_linea, '') = coalesce(m.clave_linea, '')) then
        raise exception 'La talla % del pedido % ya tiene otra diferencia abierta en ese campo; resuelvala primero.', m.talla, m.pedido;
      end if;
    end loop;

    -- 2) Se restaura el valor anterior TAL CUAL estaba (incluido vacio).
    for m in select * from public.erp_cambios c where c.id = any (v_ids) order by c.id for update loop
      select case when e ? 'antes_crudo' then e ->> 'antes_crudo' else m.valor_programa end
        into v_prev_txt
        from jsonb_array_elements(m.historial) e
       where e ->> 'accion' = 'aplicado'
       order by e ->> 'en' desc
       limit 1;
      if not found then
        v_prev_txt := m.valor_programa;
      end if;

      execute format(
        'update public.p_pedidosh set %1$I = $1 '
        || 'where "PedidoNo"::text = $2 and upper(trim("Talla"::text)) = upper(trim($3)) '
        || 'and not coalesce("Cancelado", false)', v_col)
        using v_prev_txt, m.pedido, m.talla;
      get diagnostics v_n = row_count;
      if v_n <> 1 then
        raise exception 'Se esperaba restaurar 1 linea y fueron % (pedido %, talla %). Se deshace todo.', v_n, m.pedido, m.talla;
      end if;

      update public.erp_cambios c
         set estado = 'rechazado',
             ultima_revision_at = now(),
             historial = c.historial || jsonb_build_array(jsonb_build_object(
               'en', now(), 'accion', 'revertido', 'por', p_quien,
               'antes', m.valor_access, 'despues', v_prev_txt))
       where c.id = m.id;
    end loop;

    return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'campo', r.campo,
                              'accion', 'identidad_restaurada', 'tallas', cardinality(v_ids));
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

revoke all on function public.erp_revertir_cambio_interno(bigint, text) from public, anon, authenticated;
grant execute on function public.erp_revertir_cambio_interno(bigint, text) to service_role;

comment on function public.erp_revertir_cambio_interno(bigint, text) is
  'Deshace un cambio aplicado: texto (071), cierre por cancelacion (072/073), cantidad (074), linea oculta (075) o identidad (077, todo el pedido). Queda "rechazado": no se vuelve a aplicar. Solo service_role.';


commit;

-- =====================================================================
-- PRUEBA SEGURA 077 (ejecutar DESPUES de este archivo, en el SQL Editor).
-- Aplica y deshace cambios REALES de identidad (3818, 3302, 3100, 3130, 3333)
-- dentro de una transaccion que se cancela sola al final: no queda NINGUN
-- cambio. Compara una huella del pedido (codigos de linea, avance, registros,
-- despachadas) antes y despues de aplicar y de deshacer.
--
--   do $$
--   declare
--     v_perfil uuid; v_id bigint;
--     e1 jsonb; e2 jsonb; e3 jsonb; e4 jsonb; ef jsonb;
--     h0 text; h1 text; h2 text;
--     v_orig text; v_rest text; v_n integer; v_cierre_antes boolean; v_cierre_despues boolean;
--     v_est text; v_est2 text; v_nuevas text; v_resumen jsonb; v_snap jsonb; v_reg jsonb;
--     a1 text; a2 text; a3 text; a4 text; a5 text; a6 text; a7 text; a8 text;
--   begin
--     select id into v_perfil from public.profiles where lower(role) = 'validador' order by id limit 1;
--
--     -- Huella de un pedido: codigos, avance, registros, despachadas y avance por linea.
--     create or replace function pg_temp.huella(p_pedido text) returns text language sql stable as $f$
--       select concat_ws('|',
--         (select md5(string_agg(ph.item_id || ':' || ph."Talla"::text, ',' order by ph."Talla"::text, ph.item_id)) from public.p_pedidosh ph where ph."PedidoNo"::text = p_pedido),
--         (select concat_ws(':', pp.total_solicitado::text, pp.total_procesado::text, pp.porcentaje_completado::text, pp.etapa_actual) from public.vw_pedido_progreso pp where pp.order_number::text = p_pedido limit 1),
--         (select count(*)::text from public.production_movements m where m.order_number::text = p_pedido),
--         (select coalesce(sum(i.cantidad), 0)::text from public.despacho_orden_items i join public.p_pedidosh p2 on p2.item_id = i.item_id where p2."PedidoNo"::text = p_pedido),
--         (select md5(string_agg(concat_ws(':', ip.item_id, ip.cantidad_solicitada::text, ip.cantidad_procesada::text, ip.cantidad_pendiente::text), ',' order by ip.item_id)) from public.vw_item_progreso ip where ip.order_number::text = p_pedido))
--     $f$;
--
--     -- A) 3818: color vacio -> PANELA, sin registros (el caso mas simple)
--     select min(id) into v_id from public.erp_cambios where pedido = '3818' and tipo = 'identidad' and campo = 'ColorP' and estado = 'pendiente';
--     e1 := public.erp_evaluar_identidad(v_id);
--     h0 := pg_temp.huella('3818');
--     select string_agg(coalesce("ColorP", '<NULL>'), ',' order by "Talla"::text) into v_orig from public.p_pedidosh where "PedidoNo"::text = '3818';
--     perform public.erp_aplicar_cambio_interno(v_id, v_perfil);
--     select count(*) into v_n from public.p_pedidosh where "PedidoNo"::text = '3818' and "ColorP" = 'PANELA';
--     h1 := pg_temp.huella('3818');
--     a1 := format('bloqueado=%s tallas=%s | lineas con PANELA=%s | huella igual=%s', e1 ->> 'bloqueado', e1 ->> 'n_tallas', v_n, h0 = h1);
--     perform public.erp_revertir_cambio_interno(v_id, 'prueba');
--     select string_agg(coalesce("ColorP", '<NULL>'), ',' order by "Talla"::text) into v_rest from public.p_pedidosh where "PedidoNo"::text = '3818';
--     select string_agg(distinct estado, ',') into v_est from public.erp_cambios where pedido = '3818' and tipo = 'identidad';
--     a2 := format('deshacer: color restaurado igual=%s | estados=[%s] | huella igual=%s', v_orig = v_rest, v_est, h0 = pg_temp.huella('3818'));
--
--     -- B) 3302: color vacio -> BEIGE FABY, CON registros de produccion
--     select min(id) into v_id from public.erp_cambios where pedido = '3302' and tipo = 'identidad' and campo = 'ColorP' and estado = 'pendiente';
--     e2 := public.erp_evaluar_identidad(v_id);
--     h0 := pg_temp.huella('3302');
--     perform public.erp_aplicar_cambio_interno(v_id, v_perfil);
--     h1 := pg_temp.huella('3302');
--     perform public.erp_revertir_cambio_interno(v_id, 'prueba');
--     a3 := format('bloqueado=%s registros=%s | huella igual aplicado=%s | igual deshecho=%s', e2 ->> 'bloqueado', e2 ->> 'registros', h0 = h1, h0 = pg_temp.huella('3302'));
--
--     -- C) 3100: material EXPANSO -> TR, con 65 unidades despachadas
--     select min(id) into v_id from public.erp_cambios where pedido = '3100' and tipo = 'identidad' and campo = 'MaterialP' and estado = 'pendiente';
--     e3 := public.erp_evaluar_identidad(v_id);
--     h0 := pg_temp.huella('3100');
--     perform public.erp_aplicar_cambio_interno(v_id, v_perfil);
--     h1 := pg_temp.huella('3100');
--     select string_agg(distinct "MaterialP", ',') into v_rest from public.p_pedidosh where "PedidoNo"::text = '3100';
--     perform public.erp_revertir_cambio_interno(v_id, 'prueba');
--     a4 := format('bloqueado=%s despachadas=%s registros=%s | material tras aplicar=[%s] | huella igual=%s | igual deshecho=%s | precios=%s',
--       e3 ->> 'bloqueado', e3 ->> 'despachadas', e3 ->> 'registros', v_rest, h0 = h1, h0 = pg_temp.huella('3100'), e3 -> 'precios');
--
--     -- D) 3130: pedido CERRADO a la fuerza: sigue cerrado
--     select min(id) into v_id from public.erp_cambios where pedido = '3130' and tipo = 'identidad' and campo = 'ColorP' and estado = 'pendiente';
--     e4 := public.erp_evaluar_identidad(v_id);
--     v_cierre_antes := exists (select 1 from public.pedido_cierre_forzado where order_number = '3130');
--     perform public.erp_aplicar_cambio_interno(v_id, v_perfil);
--     v_cierre_despues := exists (select 1 from public.pedido_cierre_forzado where order_number = '3130');
--     select string_agg(distinct "ColorP", ',') into v_rest from public.p_pedidosh where "PedidoNo"::text = '3130';
--     perform public.erp_revertir_cambio_interno(v_id, 'prueba');
--     a5 := format('bloqueado=%s cerrado=%s | cerrado antes=%s despues=%s | color tras aplicar=[%s]', e4 ->> 'bloqueado', e4 ->> 'cerrado', v_cierre_antes, v_cierre_despues, v_rest);
--
--     -- E) 3333: descartar todo el pedido y despues aplicarlo (interruptor)
--     select min(id) into v_id from public.erp_cambios where pedido = '3333' and tipo = 'identidad' and campo = 'ColorP' and estado = 'pendiente';
--     perform public.erp_descartar_cambio_interno(v_id, v_perfil);
--     select string_agg(distinct estado, ',') into v_est from public.erp_cambios where pedido = '3333' and tipo = 'identidad';
--     select count(*) into v_n from public.erp_cambios where pedido = '3333' and tipo = 'identidad' and estado = 'rechazado';
--     perform public.erp_aplicar_cambio_interno(v_id, v_perfil);
--     select string_agg(distinct estado, ',') into v_est2 from public.erp_cambios where pedido = '3333' and tipo = 'identidad';
--     select count(*) into v_nuevas from public.p_pedidosh where "PedidoNo"::text = '3333' and "ColorP" = 'PANELA';
--     a6 := format('descartar: estados=[%s] filas=%s | aplicar el descartado: estados=[%s] lineas con PANELA=%s', v_est, v_n, v_est2, v_nuevas);
--
--     -- F) Bloqueo: si alguien cambio el dato en el programa, no se aplica a ciegas
--     select min(id) into v_id from public.erp_cambios where pedido = '3808' and tipo = 'identidad' and estado = 'pendiente';
--     update public.p_pedidosh set "ColorP" = 'OTRO COLOR' where "PedidoNo"::text = '3808' and "Talla"::text = (select talla from public.erp_cambios where id = v_id);
--     ef := public.erp_evaluar_identidad(v_id);
--     a7 := format('bloqueado=%s motivo=[%s]', ef ->> 'bloqueado', ef ->> 'motivo');
--
--     -- G) La siguiente corrida del detector no debe crear filas nuevas
--     select jsonb_build_object('lineas_access', lineas_access, 'lineas_supabase', lineas_supabase) into v_resumen from public.erp_cambios_estado where id = 1;
--     select coalesce(jsonb_agg(jsonb_build_object('pedido', c.pedido, 'talla', c.talla, 'tipo', c.tipo, 'campo', c.campo,
--              'clave_linea', c.clave_linea, 'valor_access', c.valor_access, 'valor_programa', c.valor_programa, 'ambiguo', c.ambiguo)), '[]'::jsonb)
--       into v_snap from public.erp_cambios c
--      where c.estado in ('pendiente', 'rechazado') or (c.estado = 'aplicado' and c.tipo in ('cancelado', 'linea_sobrante'));
--     v_reg := public.erp_registrar_cambios(v_snap, v_resumen);
--     a8 := format('detector nuevas=%s', v_reg ->> 'nuevas');
--
--     raise exception E'PRUEBA IDENTIDAD (se deshizo todo):\nA) 3818: %\n   %\nB) 3302: %\nC) 3100: %\nD) 3130: %\nE) 3333: %\nF) 3808 con el dato cambiado: %\nG) %',
--       a1, a2, a3, a4, a5, a6, a7, a8;
--   end $$;
-- =====================================================================
