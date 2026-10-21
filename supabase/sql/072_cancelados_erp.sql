-- =====================================================================
-- 072_cancelados_erp.sql
-- FASE 3 de "Cambios ERP": pedidos CANCELADOS en Access -> CIERRE A LA FUERZA.
--
-- POR QUE
--   Cuando un pedido se cancela en Access, el programa lo sigue mostrando
--   activo. Esta fase lo cierra a la fuerza (el mismo cierre que hace el
--   Validador a mano, 057) con el motivo "Cancelado en Troya".
--
-- QUE HACE
--   * Cierra a la fuerza un pedido SOLO si TODAS sus lineas estan canceladas
--     en Access y el pedido NO esta completo y NO esta ya cerrado.
--     (El cierre solo agrega una fila en pedido_cierre_forzado: no cambia
--      cantidades, producciones, despachos ni ninguna linea del pedido.)
--   * Quien figura como "cerrado por" queda VACIO: las pantallas ya muestran
--     "el Validador" cuando viene vacio.
--   * Pedido cancelado en Access que YA estaba cerrado a la fuerza (a mano):
--     se da por atendido ("ya cerrado"); no se toca.
--   * Pedido cancelado pero COMPLETO: NO se cierra; queda pendiente para
--     revision manual.
--   * Si Access vuelve a dejar activo un pedido que cerro el SISTEMA, lo
--     reabre solo (nunca toca un cierre hecho a mano).
--   * Cancelaciones PARCIALES (solo algunas lineas): no hacen nada aqui.
--
-- PROTECCIONES
--   * Se enciende con el MISMO interruptor por campo de 071:
--       update public.erp_cambios_estado
--          set aplicar_campos = array_append(aplicar_campos, 'Cancelado');
--     y se apaga quitando 'Cancelado' de la lista. Apagado de fabrica.
--   * Solo actua sobre diferencias vistas IGUAL en 2 revisiones seguidas y
--     revisadas en los ultimos 30 minutos.
--   * Tope: mas de 10 cierres nuevos en una corrida -> NO cierra ninguno.
--   * Reabrir exige que Access lo deje activo en 2 revisiones seguidas y
--     solo borra el cierre cuando fue hecho por el sistema con el motivo
--     "Cancelado en Troya" (cerrado_por vacio).
--   * DESHACER (boton de la pestana Cambios ERP, solo Validador): reabre el
--     pedido y deja la diferencia como "deshecha" para que no se cierre otra
--     vez mientras Access no cambie.
--
-- DETALLE TECNICO IMPORTANTE
--   En los textos la diferencia desaparece sola al aplicarse. En un
--   cancelado NO (el programa no marca las lineas como canceladas), asi que
--   esta migracion ajusta erp_registrar_cambios para no repetir la fila cada
--   5 minutos y para contar cuando la cancelacion desaparece de Access.
--
-- CAMBIO EN UNA TABLA EXISTENTE (unico):
--   pedido_cierre_forzado.cerrado_por pasa a admitir vacio (NULL).
--
-- Reversa: 072_revertir_cancelados_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. El cierre hecho por el sistema no tiene un usuario que lo firme.
-- ---------------------------------------------------------------------
alter table public.pedido_cierre_forzado
  alter column cerrado_por drop not null;

comment on column public.pedido_cierre_forzado.cerrado_por is
  'Quien cerro. NULL = lo cerro el sistema (072: pedido cancelado en Access); la pantalla muestra "el Validador".';

-- ---------------------------------------------------------------------
-- 2. erp_registrar_cambios: igual a 069 mas el tratamiento de los
--    cancelados YA aplicados (la diferencia persiste mientras Access siga
--    cancelado). Todo lo demas se comporta exactamente igual.
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
      where c.estado = 'aplicado' and c.tipo = 'cancelado' and s.tipo = 'cancelado'
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
   where c.estado = 'aplicado' and c.tipo = 'cancelado' and c.contexto ? 'ausencias'
     and exists (
       select 1 from pg_temp._erp_snapshot s
        where s.pedido = c.pedido and s.tipo = 'cancelado'
          and coalesce(s.talla, '') = coalesce(c.talla, '')
          and coalesce(s.campo, '') = coalesce(c.campo, '')
          and coalesce(s.clave_linea, '') = coalesce(c.clave_linea, ''));

  update public.erp_cambios c
     set contexto = jsonb_set(c.contexto, '{ausencias}',
                              to_jsonb(coalesce((c.contexto ->> 'ausencias')::integer, 0) + 1)),
         ultima_revision_at = now()
   where c.estado = 'aplicado' and c.tipo = 'cancelado'
     and not exists (
       select 1 from pg_temp._erp_snapshot s
        where s.pedido = c.pedido and s.tipo = 'cancelado'
          and coalesce(s.talla, '') = coalesce(c.talla, '')
          and coalesce(s.campo, '') = coalesce(c.campo, '')
          and coalesce(s.clave_linea, '') = coalesce(c.clave_linea, ''));

  update public.erp_cambios c
     set estado = 'resuelto',
         resuelto_at = now()
   where c.estado = 'aplicado' and c.tipo = 'cancelado'
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
  'Concilia el conjunto completo de diferencias Access vs programa de una revision (069, ajustada en 072 para cancelados ya aplicados). No modifica ningun pedido. Solo service_role.';

revoke all on function public.erp_registrar_cambios(jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.erp_registrar_cambios(jsonb, jsonb) to service_role;

-- ---------------------------------------------------------------------
-- 3. Cierres y reaperturas por cancelacion
-- ---------------------------------------------------------------------
create or replace function public.erp_aplicar_cancelados()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  c_max_cierres constant integer := 10;
  v_activo boolean;
  v_campos text[];
  v_por_cerrar integer;
  r record;
  v_n integer;
  v_cerrados integer := 0;
  v_ya_cerrados integer := 0;
  v_completos integer := 0;
  v_reabiertos integer := 0;
  v_omitidos integer := 0;
begin
  select e.activo, e.aplicar_campos into v_activo, v_campos
    from public.erp_cambios_estado e where e.id = 1;

  if not coalesce(v_activo, true) or not ('Cancelado' = any (coalesce(v_campos, '{}'::text[]))) then
    return jsonb_build_object('resultado', 'apagado');
  end if;

  -- Cierres NUEVOS que haria (sin contar los ya cerrados ni los completos).
  select count(*) into v_por_cerrar
    from public.erp_cambios c
   where c.estado = 'pendiente' and c.tipo = 'cancelado' and c.talla is null and not c.ambiguo
     and c.revisiones_consecutivas >= 2
     and c.ultima_revision_at > now() - interval '30 minutes'
     and c.pedido ~ '^[0-9]{1,9}$'
     and case when c.pedido ~ '^[0-9]{1,9}$' then c.pedido::bigint end >= 3095
     and exists (select 1 from public.p_pedidosh p where p."PedidoNo"::text = c.pedido)
     and not exists (select 1 from public.pedido_cierre_forzado f where f.order_number = c.pedido)
     and not coalesce((select v.estatus_general = 'Completado'
                         from public.vw_pedido_progreso v
                        where v.order_number::text = c.pedido limit 1), false);

  if v_por_cerrar > c_max_cierres then
    return jsonb_build_object('resultado', 'detenido', 'por_cerrar', v_por_cerrar,
      'motivo', format('%s pedidos por cerrar por cancelacion (tope %s): se revisa a mano',
                       v_por_cerrar, c_max_cierres));
  end if;

  -- A) Cierres.
  for r in
    select c.*
      from public.erp_cambios c
     where c.estado = 'pendiente' and c.tipo = 'cancelado' and c.talla is null and not c.ambiguo
       and c.revisiones_consecutivas >= 2
       and c.ultima_revision_at > now() - interval '30 minutes'
       and c.pedido ~ '^[0-9]{1,9}$'
       and case when c.pedido ~ '^[0-9]{1,9}$' then c.pedido::bigint end >= 3095
     order by c.pedido, c.id
       for update
  loop
    if not exists (select 1 from public.p_pedidosh p where p."PedidoNo"::text = r.pedido) then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;

    if exists (select 1 from public.pedido_cierre_forzado f where f.order_number = r.pedido) then
      -- Ya estaba cerrado a la fuerza (a mano): se da por atendido, no se toca.
      update public.erp_cambios c
         set estado = 'aplicado', aplicado_at = now(), aplicado_por = 'ya cerrado',
             historial = c.historial || jsonb_build_array(jsonb_build_object(
               'en', now(), 'accion', 'ya_cerrado'))
       where c.id = r.id;
      v_ya_cerrados := v_ya_cerrados + 1;
      continue;
    end if;

    if coalesce((select v.estatus_general = 'Completado'
                   from public.vw_pedido_progreso v
                  where v.order_number::text = r.pedido limit 1), false) then
      -- Completo: no se cierra; queda pendiente para revision manual.
      v_completos := v_completos + 1;
      continue;
    end if;

    -- UNICA escritura: una fila de cierre forzado (cerrado_por vacio = sistema).
    insert into public.pedido_cierre_forzado (order_number, motivo, cerrado_por)
    values (r.pedido, 'Cancelado en Troya', null)
    on conflict (order_number) do nothing;
    get diagnostics v_n = row_count;

    if v_n = 0 then
      v_omitidos := v_omitidos + 1;
      continue;
    end if;

    update public.erp_cambios c
       set estado = 'aplicado', aplicado_at = now(), aplicado_por = 'automatico',
           historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', 'cerrado', 'motivo', 'Cancelado en Troya'))
     where c.id = r.id;
    v_cerrados := v_cerrados + 1;
  end loop;

  -- B) Reaperturas: Access volvio a dejar activo un pedido que cerro el
  --    SISTEMA. Solo se borra un cierre con cerrado_por vacio y ese motivo.
  for r in
    select c.*
      from public.erp_cambios c
     where c.tipo = 'cancelado' and c.estado = 'resuelto'
       and exists (select 1 from jsonb_array_elements(c.historial) e where e ->> 'accion' = 'cerrado')
       and not exists (select 1 from jsonb_array_elements(c.historial) e
                        where e ->> 'accion' in ('reabierto', 'reapertura_omitida'))
     order by c.id
       for update
  loop
    delete from public.pedido_cierre_forzado f
     where f.order_number = r.pedido and f.cerrado_por is null and f.motivo = 'Cancelado en Troya';
    get diagnostics v_n = row_count;

    update public.erp_cambios c
       set historial = c.historial || jsonb_build_array(jsonb_build_object(
             'en', now(), 'accion', case when v_n > 0 then 'reabierto' else 'reapertura_omitida' end))
     where c.id = r.id;

    if v_n > 0 then
      v_reabiertos := v_reabiertos + 1;
    else
      v_omitidos := v_omitidos + 1;
    end if;
  end loop;

  return jsonb_build_object('resultado', 'ok', 'cerrados', v_cerrados, 'ya_cerrados', v_ya_cerrados,
    'completos_sin_cerrar', v_completos, 'reabiertos', v_reabiertos, 'omitidos', v_omitidos);
end;
$$;

comment on function public.erp_aplicar_cancelados() is
  'Cierra a la fuerza (motivo "Cancelado en Troya", cerrado_por vacio) los pedidos cancelados en Access y reabre los que Access vuelve a dejar activos, solo si los cerro el sistema (072). Requiere "Cancelado" en erp_cambios_estado.aplicar_campos. Solo service_role.';

revoke all on function public.erp_aplicar_cancelados() from public, anon, authenticated;
grant execute on function public.erp_aplicar_cancelados() to service_role;

-- ---------------------------------------------------------------------
-- 4. La funcion que llama el script (sin cambios en la oficina) pasa a
--    hacer textos + cancelados. La de 071 se conserva como erp_aplicar_textos.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.erp_aplicar_textos()') is null then
    alter function public.erp_aplicar_cambios() rename to erp_aplicar_textos;
  end if;
end $$;

create or replace function public.erp_aplicar_cambios()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_textos jsonb;
  v_cancelados jsonb;
begin
  v_textos := public.erp_aplicar_textos();
  v_cancelados := public.erp_aplicar_cancelados();
  return v_textos || jsonb_build_object('cancelados', v_cancelados);
end;
$$;

comment on function public.erp_aplicar_cambios() is
  'Punto de entrada que llama el script de la oficina: aplica textos (071, erp_aplicar_textos) y cancelados (072, erp_aplicar_cancelados) segun erp_cambios_estado.aplicar_campos. Solo service_role.';

revoke all on function public.erp_aplicar_cambios() from public, anon, authenticated;
grant execute on function public.erp_aplicar_cambios() to service_role;

-- ---------------------------------------------------------------------
-- 5. Deshacer: la de 071 se conserva como erp_revertir_texto_interno y la
--    nueva reparte segun el tipo de cambio.
-- ---------------------------------------------------------------------
do $$
begin
  if to_regprocedure('public.erp_revertir_texto_interno(bigint,text)') is null then
    alter function public.erp_revertir_cambio_interno(bigint, text) rename to erp_revertir_texto_interno;
  end if;
end $$;

create or replace function public.erp_revertir_cambio_interno(p_id bigint, p_quien text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  r public.erp_cambios%rowtype;
  v_n integer;
begin
  select * into r from public.erp_cambios c where c.id = p_id for update;
  if not found then
    raise exception 'No existe el cambio %.', p_id;
  end if;

  if r.tipo <> 'cancelado' then
    return public.erp_revertir_texto_interno(p_id, p_quien);
  end if;

  if r.estado <> 'aplicado' or r.aplicado_por is distinct from 'automatico' then
    raise exception 'Solo se puede deshacer un cierre por cancelacion hecho automaticamente por el sistema.';
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
   where f.order_number = r.pedido and f.cerrado_por is null and f.motivo = 'Cancelado en Troya';
  get diagnostics v_n = row_count;
  if v_n = 0 then
    raise exception 'El pedido % ya no esta cerrado por el sistema (alguien lo reabrio o lo cerro a mano); no se toca.', r.pedido;
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
  'Deshace un cambio aplicado: texto (071, via erp_revertir_texto_interno) o cierre por cancelacion (072: reabre el pedido). Queda "rechazado": no se vuelve a aplicar. Solo service_role.';

revoke all on function public.erp_revertir_cambio_interno(bigint, text) from public, anon, authenticated;
grant execute on function public.erp_revertir_cambio_interno(bigint, text) to service_role;

commit;
