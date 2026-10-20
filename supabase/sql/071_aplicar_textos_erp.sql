-- =====================================================================
-- 071_aplicar_textos_erp.sql
-- FASE 2 (completa) de "Cambios ERP": APLICAR los datos de TEXTO por CAMPO,
-- con un interruptor por campo y UNA sola funcion generica.
--
-- POR QUE
--   070 aplicaba solo el Cliente con un interruptor fijo. Para no tener que
--   copiar el script de la oficina en cada entrega, el script llama SIEMPRE a
--   erp_aplicar_cambios() y es Supabase quien decide que campos se aplican:
--
--     update public.erp_cambios_estado set aplicar_campos = array['Cliente'];
--     update public.erp_cambios_estado set aplicar_campos = array['Cliente','Vira','Acabado'];
--     update public.erp_cambios_estado set aplicar_campos = '{}';   -- todo apagado
--
-- CAMPOS QUE SE PUEDEN APLICAR (lista cerrada; cualquier otro se ignora)
--   Cliente                     (todas las lineas del pedido)
--   Vira, DetalleVira, Acabado, DetalleAcab, Esterilla, DetalleEsterilla,
--   Marquilla                   (la linea de ESA talla)
--   NombreR                     (la linea de esa talla)  *** VER AVISO ***
--
-- AVISO SOBRE NombreR (nombre de la suela)
--   El precio que se congela en cada movimiento nuevo
--   (fn_congelar_precio_movimiento, 024) se calcula con NombreR, MaterialP y
--   ColorP. Cambiar NombreR puede cambiar el precio (y por tanto lo que se
--   paga) de las unidades que se produzcan DESPUES. Lo ya registrado no cambia.
--   Vira, acabado, esterilla, marquilla, sus detalles y el Cliente NO entran
--   en ese calculo. Encienda NombreR solo cuando lo decida a conciencia.
--
-- PROTECCIONES (iguales a 070)
--   * Todo APAGADO de fabrica (aplicar_campos vacio).
--   * Solo aplica una diferencia vista IGUAL en 2 revisiones seguidas y
--     revisada en los ultimos 30 minutos.
--   * Solo si TODAS las lineas afectadas siguen teniendo el valor que el
--     detector anoto (si alguien lo cambio mientras tanto, se omite).
--   * Solo lineas sin ambiguedad: por talla debe haber exactamente UNA linea.
--   * No aplica un valor vacio (borrar un dato queda para revision manual).
--   * Los campos de casilla (Vira, Acabado, Esterilla, Marquilla) solo
--     aceptan TRUE o FALSE. En la base son columnas booleanas: la funcion
--     lee el tipo real de cada columna y escribe con ese tipo.
--   * Topes: mas de 30 pedidos o 300 filas listas en una corrida -> NO aplica
--     nada y avisa.
--   * Atomico: si algo falla, no queda nada a medias.
--   * Historial en erp_cambios (valor anterior tal cual estaba, y nuevo).
--
-- DESHACER: boton en la pestana Cambios ERP (solo Validador) o
--   select public.erp_revertir_cambio_interno(<id>, 'manual');
--   Restaura el valor anterior SOLO si el actual sigue siendo el aplicado.
--
-- Reversa: 071_revertir_aplicar_textos_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Interruptores por campo (reemplazan al interruptor unico de 070)
-- ---------------------------------------------------------------------
alter table public.erp_cambios_estado
  add column if not exists aplicar_campos text[] not null default '{}';

comment on column public.erp_cambios_estado.aplicar_campos is
  'Campos de texto que se aplican solos (071). Vacio = solo se detecta y se muestra. Ej.: array[''Cliente'',''Vira''].';

-- Conserva lo que hubiera encendido con 070.
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'erp_cambios_estado'
                and column_name = 'aplicar_cliente') then
    update public.erp_cambios_estado
       set aplicar_campos = array_append(aplicar_campos, 'Cliente')
     where aplicar_cliente and not ('Cliente' = any (aplicar_campos));
  end if;
end $$;

-- La funcion de 070 queda reemplazada por la generica.
drop function if exists public.erp_aplicar_cambios_cliente();
alter table public.erp_cambios_estado drop column if exists aplicar_cliente;

-- ---------------------------------------------------------------------
-- 2. Ayudas: lista cerrada de campos y comparacion de valores
-- ---------------------------------------------------------------------
create or replace function public.erp_campo_columna(p_campo text)
returns text
language sql
immutable
as $$
  select case p_campo
    when 'Cliente' then 'Cliente'
    when 'Vira' then 'Vira'
    when 'DetalleVira' then 'DetalleVira'
    when 'Acabado' then 'Acabado'
    when 'DetalleAcab' then 'DetalleAcab'
    when 'Esterilla' then 'Esterilla'
    when 'DetalleEsterilla' then 'DetalleEsterilla'
    when 'Marquilla' then 'Marquilla'
    when 'NombreR' then 'NombreR'
    else null
  end
$$;

-- Valor comparable: casillas -> TRUE/FALSE; texto -> sin espacios sobrantes y en mayusculas.
create or replace function public.erp_valor_cmp(p_campo text, p_valor text)
returns text
language sql
immutable
as $$
  select case
    when p_campo in ('Vira', 'Acabado', 'Esterilla', 'Marquilla')
      then case when lower(trim(coalesce(p_valor, ''))) in ('1', '-1', 'true', 't', 'si', 'sí', 'yes')
                then 'TRUE' else 'FALSE' end
    else public.erp_norm_texto(p_valor)
  end
$$;

-- ---------------------------------------------------------------------
-- 3. Aplicar los cambios de texto listos, de los campos encendidos
-- ---------------------------------------------------------------------
create or replace function public.erp_aplicar_cambios()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c_max_pedidos constant integer := 30;
  c_max_filas constant integer := 300;
  v_activo boolean;
  v_campos text[];
  v_listas integer;
  v_pedidos integer;
  r record;
  v_col text;
  v_tipo text;
  v_talla text;
  v_nuevo text;
  v_lineas integer;
  v_coinciden integer;
  v_crudo text;
  v_filas integer;
  v_aplicados integer := 0;
  v_omitidos integer := 0;
begin
  select e.activo, e.aplicar_campos into v_activo, v_campos
    from public.erp_cambios_estado e where e.id = 1;

  if not coalesce(v_activo, true) or coalesce(cardinality(v_campos), 0) = 0 then
    return jsonb_build_object('resultado', 'apagado');
  end if;

  select count(*), count(distinct c.pedido) into v_listas, v_pedidos
    from public.erp_cambios c
   where c.estado = 'pendiente' and c.tipo = 'texto'
     and c.campo = any (v_campos) and public.erp_campo_columna(c.campo) is not null
     and not c.ambiguo
     and c.revisiones_consecutivas >= 2
     and c.ultima_revision_at > now() - interval '30 minutes'
     and c.pedido ~ '^[0-9]{1,9}$'
     and case when c.pedido ~ '^[0-9]{1,9}$' then c.pedido::bigint end >= 3095
     and ((c.campo = 'Cliente' and c.talla is null)
          or (c.campo <> 'Cliente' and c.talla is not null and c.clave_linea is null));

  if v_pedidos > c_max_pedidos or v_listas > c_max_filas then
    return jsonb_build_object('resultado', 'detenido', 'listas', v_listas, 'pedidos', v_pedidos,
      'motivo', format('%s cambios en %s pedidos listos (topes %s y %s): se revisa a mano',
                       v_listas, v_pedidos, c_max_filas, c_max_pedidos));
  end if;

  for r in
    select c.*
      from public.erp_cambios c
     where c.estado = 'pendiente' and c.tipo = 'texto'
       and c.campo = any (v_campos) and public.erp_campo_columna(c.campo) is not null
       and not c.ambiguo
       and c.revisiones_consecutivas >= 2
       and c.ultima_revision_at > now() - interval '30 minutes'
       and c.pedido ~ '^[0-9]{1,9}$'
       and case when c.pedido ~ '^[0-9]{1,9}$' then c.pedido::bigint end >= 3095
       and ((c.campo = 'Cliente' and c.talla is null)
            or (c.campo <> 'Cliente' and c.talla is not null and c.clave_linea is null))
     order by c.pedido, c.id
       for update
  loop
    v_col := public.erp_campo_columna(r.campo);
    v_talla := case when r.campo = 'Cliente' then null else upper(trim(r.talla)) end;

    -- Tipo REAL de la columna (p. ej. Vira/Acabado/Esterilla/Marquilla son
    -- booleanas en la base, no texto): se escribe con ese tipo.
    select format_type(a.atttypid, a.atttypmod) into v_tipo
      from pg_attribute a
     where a.attrelid = 'public.p_pedidosh'::regclass and a.attname = v_col and not a.attisdropped;
    if v_tipo is null then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;

    -- Valor nuevo: nunca vacio; las casillas solo TRUE/FALSE.
    v_nuevo := trim(coalesce(r.valor_access, ''));
    if r.campo in ('Vira', 'Acabado', 'Esterilla', 'Marquilla') then
      v_nuevo := upper(v_nuevo);
      if v_nuevo not in ('TRUE', 'FALSE') then
        v_omitidos := v_omitidos + 1;
        continue;
      end if;
    elsif v_nuevo = '' or length(v_nuevo) > 200 then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;

    execute format(
      'select count(*), '
      || 'count(*) filter (where public.erp_valor_cmp($1, %1$I::text) = public.erp_valor_cmp($1, $2)), '
      || 'min(%1$I::text) '
      || 'from public.p_pedidosh '
      || 'where "PedidoNo"::text = $3 and ($4 is null or upper(trim("Talla"::text)) = $4)', v_col)
      into v_lineas, v_coinciden, v_crudo
      using r.campo, r.valor_programa, r.pedido, v_talla;

    -- No existe, el valor ya no es el anotado, o (por talla) no hay exactamente 1 linea.
    if v_lineas = 0 or v_coinciden <> v_lineas or (r.campo <> 'Cliente' and v_lineas <> 1) then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;
    -- Ya coincide con Access: no hay nada que escribir (el detector lo resolvera).
    if public.erp_valor_cmp(r.campo, v_nuevo) = public.erp_valor_cmp(r.campo, v_crudo) then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;

    -- UNICA escritura sobre p_pedidosh: la columna del campo (lista cerrada).
    execute format(
      'update public.p_pedidosh set %I = ($1)::%s '
      || 'where "PedidoNo"::text = $2 and ($3 is null or upper(trim("Talla"::text)) = $3)', v_col, v_tipo)
      using v_nuevo, r.pedido, v_talla;

    get diagnostics v_filas = row_count;
    if v_filas <> v_lineas then
      raise exception 'Se esperaba actualizar % lineas y fueron % (pedido %, campo %). Se deshace todo.',
        v_lineas, v_filas, r.pedido, r.campo;
    end if;

    update public.erp_cambios c
       set estado = 'aplicado',
           aplicado_at = now(),
           aplicado_por = 'automatico',
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'aplicado',
             'antes', r.valor_programa, 'antes_crudo', v_crudo,
             'despues', v_nuevo, 'lineas', v_filas))
     where c.id = r.id;

    v_aplicados := v_aplicados + 1;
  end loop;

  return jsonb_build_object('resultado', 'ok', 'aplicados', v_aplicados, 'omitidos', v_omitidos);
end;
$$;

comment on function public.erp_aplicar_cambios() is
  'Aplica los cambios de texto detectados (071) de los campos encendidos en erp_cambios_estado.aplicar_campos: lista cerrada de columnas de p_pedidosh, tras 2 revisiones iguales, atomico, con topes. Solo service_role.';

revoke all on function public.erp_aplicar_cambios() from public, anon, authenticated;
grant execute on function public.erp_aplicar_cambios() to service_role;

-- ---------------------------------------------------------------------
-- 4. Deshacer un cambio de texto ya aplicado (cualquier campo de la lista)
-- ---------------------------------------------------------------------
create or replace function public.erp_revertir_cambio_interno(p_id bigint, p_quien text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  v_col text;
  v_tipo text;
  v_talla text;
  v_prev text;
  v_lineas integer;
  v_coinciden integer;
  v_filas integer;
begin
  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  v_col := public.erp_campo_columna(r.campo);
  if r.estado <> 'aplicado' or r.tipo <> 'texto' or v_col is null then
    raise exception 'Solo se puede deshacer un cambio de texto que ya fue aplicado.';
  end if;
  v_talla := case when r.campo = 'Cliente' then null else upper(trim(r.talla)) end;

  select format_type(a.atttypid, a.atttypmod) into v_tipo
    from pg_attribute a
   where a.attrelid = 'public.p_pedidosh'::regclass and a.attname = v_col and not a.attisdropped;
  if v_tipo is null then
    raise exception 'No se pudo determinar el tipo de la columna %.', v_col;
  end if;

  execute format(
    'select count(*), '
    || 'count(*) filter (where public.erp_valor_cmp($1, %1$I::text) = public.erp_valor_cmp($1, $2)) '
    || 'from public.p_pedidosh '
    || 'where "PedidoNo"::text = $3 and ($4 is null or upper(trim("Talla"::text)) = $4)', v_col)
    into v_lineas, v_coinciden
    using r.campo, r.valor_access, r.pedido, v_talla;

  if v_lineas = 0 or v_coinciden <> v_lineas then
    raise exception 'El dato del pedido % cambio despues de la aplicacion; no se deshace para no pisar ese cambio.', r.pedido;
  end if;

  if exists (select 1 from public.erp_cambios c
              where c.id <> r.id and c.estado in ('pendiente', 'rechazado')
                and c.pedido = r.pedido and c.tipo = 'texto' and c.campo = r.campo
                and coalesce(c.talla, '') = coalesce(r.talla, '')
                and coalesce(c.clave_linea, '') = coalesce(r.clave_linea, '')) then
    raise exception 'El pedido % ya tiene otra diferencia abierta en este campo; resuelvala primero.', r.pedido;
  end if;

  -- Valor anterior tal cual estaba (si se aplico con 070, el anotado).
  select case when e ? 'antes_crudo' then e ->> 'antes_crudo' else r.valor_programa end
    into v_prev
    from jsonb_array_elements(r.historial) e
   where e ->> 'accion' = 'aplicado'
   order by e ->> 'en' desc
   limit 1;
  if not found then
    v_prev := r.valor_programa;
  end if;

  execute format(
    'update public.p_pedidosh set %I = ($1)::%s '
    || 'where "PedidoNo"::text = $2 and ($3 is null or upper(trim("Talla"::text)) = $3)', v_col, v_tipo)
    using v_prev, r.pedido, v_talla;

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
           'antes', r.valor_access, 'despues', v_prev))
   where c.id = r.id;

  return jsonb_build_object('resultado', 'ok', 'pedido', r.pedido, 'campo', r.campo, 'lineas', v_filas);
end;
$$;

comment on function public.erp_revertir_cambio_interno(bigint, text) is
  'Deshace un cambio de texto aplicado (071) si el valor actual sigue siendo el aplicado. Queda "rechazado": no se vuelve a aplicar. Solo service_role.';

revoke all on function public.erp_revertir_cambio_interno(bigint, text) from public, anon, authenticated;
grant execute on function public.erp_revertir_cambio_interno(bigint, text) to service_role;

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (ejecutar APARTE, despues de este archivo).
-- Cada una termina en un "error" a proposito que CANCELA TODO: no queda
-- ningun cambio. Requieren que el detector ya haya registrado las
-- diferencias y las haya visto 2 veces (columna Rev. >= 2).
--
-- PRUEBA A: CLIENTE (3431: debe pasar de CAMEL a WISER y volver)
--
--   do $$
--   declare antes text; despues text; tras text; v_id bigint; r1 jsonb; r2 jsonb;
--   begin
--     update public.erp_cambios_estado set aplicar_campos = array['Cliente'] where id = 1;
--     select string_agg(distinct "Cliente", ' / ') into antes from public.p_pedidosh where "PedidoNo" = '3431';
--     r1 := public.erp_aplicar_cambios();
--     select string_agg(distinct "Cliente", ' / ') into despues from public.p_pedidosh where "PedidoNo" = '3431';
--     select id into v_id from public.erp_cambios where pedido = '3431' and campo = 'Cliente' and estado = 'aplicado';
--     r2 := public.erp_revertir_cambio_interno(v_id, 'prueba');
--     select string_agg(distinct "Cliente", ' / ') into tras from public.p_pedidosh where "PedidoNo" = '3431';
--     raise exception 'PRUEBA A (se deshizo todo): antes=% | aplicar=% | despues=% | deshacer=% | tras=%', antes, r1, despues, r2, tras;
--   end $$;
--
-- PRUEBA B: TEXTOS DE LINEA, sin NombreR (muestra el valor CRUDO entre corchetes)
--   Acabado/DetalleAcab del 3271 talla 35 y Vira/DetalleVira del 3403 talla 36.
--
--   do $$
--   declare a1 text; a2 text; a3 text; a4 text; b1 text; b2 text; b3 text; b4 text; c1 text; c2 text; c3 text; c4 text;
--           r1 jsonb; r2 jsonb; v_id bigint;
--   begin
--     update public.erp_cambios_estado
--        set aplicar_campos = array['Cliente','Vira','DetalleVira','Acabado','DetalleAcab','Esterilla','DetalleEsterilla','Marquilla'] where id = 1;
--     select '[' || coalesce("Acabado"::text,'<NULL>') || ']', '[' || coalesce("DetalleAcab",'<NULL>') || ']' into a1, a2 from public.p_pedidosh where "PedidoNo" = '3271' and "Talla" = '35';
--     select '[' || coalesce("Vira"::text,'<NULL>') || ']', '[' || coalesce("DetalleVira",'<NULL>') || ']' into a3, a4 from public.p_pedidosh where "PedidoNo" = '3403' and "Talla" = '36';
--     r1 := public.erp_aplicar_cambios();
--     select '[' || coalesce("Acabado"::text,'<NULL>') || ']', '[' || coalesce("DetalleAcab",'<NULL>') || ']' into b1, b2 from public.p_pedidosh where "PedidoNo" = '3271' and "Talla" = '35';
--     select '[' || coalesce("Vira"::text,'<NULL>') || ']', '[' || coalesce("DetalleVira",'<NULL>') || ']' into b3, b4 from public.p_pedidosh where "PedidoNo" = '3403' and "Talla" = '36';
--     for v_id in select id from public.erp_cambios where estado = 'aplicado' and pedido in ('3271','3403') and talla in ('35','36') loop
--       r2 := public.erp_revertir_cambio_interno(v_id, 'prueba');
--     end loop;
--     select '[' || coalesce("Acabado"::text,'<NULL>') || ']', '[' || coalesce("DetalleAcab",'<NULL>') || ']' into c1, c2 from public.p_pedidosh where "PedidoNo" = '3271' and "Talla" = '35';
--     select '[' || coalesce("Vira"::text,'<NULL>') || ']', '[' || coalesce("DetalleVira",'<NULL>') || ']' into c3, c4 from public.p_pedidosh where "PedidoNo" = '3403' and "Talla" = '36';
--     raise exception 'PRUEBA B (se deshizo todo): aplicar=% || 3271/35 antes=% % despues=% % tras=% % || 3403/36 antes=% % despues=% % tras=% %',
--       r1, a1, a2, b1, b2, c1, c2, a3, a4, b3, b4, c3, c4;
--   end $$;
-- =====================================================================
