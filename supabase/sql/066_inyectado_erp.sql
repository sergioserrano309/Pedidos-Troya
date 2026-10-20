-- =====================================================================
-- 066_inyectado_erp.sql
-- PASO 4: mantener al dia el "Total Inyectado" (Access) en Supabase.
--
-- POR QUE
--   p_pedidosh.Total01Iny se carga UNA vez, cuando el pedido entra (casi
--   siempre en 0, porque aun no se ha inyectado) y nunca se vuelve a
--   actualizar. El diagnostico del 2026-10-19 midio 3.254 lineas de 562
--   pedidos con un valor mas bajo que el de Access (70.681 pares).
--
-- QUE AGREGA (todo NUEVO; no cambia ninguna tabla ni vista existente)
--   1. erp_sync_estado   Una sola fila: ultima corrida, resultado, conteos
--                        e INTERRUPTOR (activo). De aqui saldra el
--                        "actualizado hace X min" de la pantalla.
--   2. erp_inyectado_log Una fila por cada cambio real: pedido, talla,
--                        valor anterior y nuevo. Permite auditar y revertir.
--   3. erp_actualizar_inyectado(jsonb)  Aplica un lote de cambios.
--   4. erp_registrar_corrida(jsonb)     Guarda el resumen de la corrida.
--   5. erp_revertir_corrida(uuid)       Deshace una corrida.
--
-- REGLAS DE SEGURIDAD
--   * La funcion SOLO modifica la columna "Total01Iny". Ninguna otra.
--   * Solo pedidos >= 3095 (del 1 de agosto en adelante).
--   * La linea se identifica por PEDIDO + TALLA (decision del dueno):
--     referencia, material, color y vira pueden cambiar sin afectar.
--     Si en Supabase hay 0 o mas de 1 linea para ese pedido y talla, se
--     OMITE (no se adivina) y se cuenta.
--   * Aplica subidas y bajadas (Access es la fuente de verdad); cada
--     cambio guarda el valor anterior.
--   * Las funciones solo las puede ejecutar service_role (la llave del
--     script de la oficina). Ningun usuario de la aplicacion.
--   * INTERRUPTOR: update public.erp_sync_estado set activo = false;
--     pausa todo sin tocar el script ni la tarea programada.
--   * Cada llamada es atomica: si algo falla, no queda un lote a medias.
--
-- NO TOCA vistas, politicas de p_pedidosh, triggers ni el sincronizador
-- actual. Un UPDATE sobre p_pedidosh no dispara nada (el unico trigger,
-- 013, es AFTER INSERT).
--
-- Reversa: 066_revertir_inyectado_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Estado de la sincronizacion (una sola fila)
-- ---------------------------------------------------------------------
create table if not exists public.erp_sync_estado (
  id integer primary key default 1,
  constraint erp_sync_estado_fila_unica check (id = 1),
  activo boolean not null default true,
  ultima_ejecucion timestamptz,
  ultima_actualizacion timestamptz,
  ultimo_resultado text,
  lineas_access integer,
  lineas_supabase integer,
  lineas_actualizadas integer,
  lineas_sin_cambio integer,
  lineas_omitidas integer
);

insert into public.erp_sync_estado (id) values (1) on conflict (id) do nothing;

comment on table public.erp_sync_estado is
  'Estado de la sincronizacion Access -> Supabase del Total Inyectado (066). Una sola fila. activo=false pausa las actualizaciones.';
comment on column public.erp_sync_estado.ultima_ejecucion is
  'Ultima vez que el script de la oficina corrio (aunque no haya cambiado nada). Base del "actualizado hace X min".';
comment on column public.erp_sync_estado.ultima_actualizacion is
  'Ultima vez que realmente cambio algun Total Inyectado.';

-- ---------------------------------------------------------------------
-- 2. Registro de cambios (solo cambios reales)
-- ---------------------------------------------------------------------
create table if not exists public.erp_inyectado_log (
  id bigint generated always as identity primary key,
  corrida_id uuid not null,
  registrado_at timestamptz not null default now(),
  pedido text not null,
  talla text not null,
  inyectado_anterior integer,
  inyectado_nuevo integer not null,
  solicitado integer,
  revertido boolean not null default false
);

create index if not exists idx_erp_inyectado_log_corrida on public.erp_inyectado_log (corrida_id);
create index if not exists idx_erp_inyectado_log_pedido on public.erp_inyectado_log (pedido);

comment on table public.erp_inyectado_log is
  'Una fila por cada cambio real de Total Inyectado aplicado desde Access (066): valor anterior y nuevo. Permite auditar y revertir con erp_revertir_corrida.';

-- ---------------------------------------------------------------------
-- 3. Seguridad de las tablas: solo el Validador las puede LEER; nadie
--    desde la aplicacion las puede escribir (solo service_role).
-- ---------------------------------------------------------------------
alter table public.erp_sync_estado enable row level security;
alter table public.erp_inyectado_log enable row level security;

drop policy if exists "erp_sync_estado_select_validador" on public.erp_sync_estado;
create policy "erp_sync_estado_select_validador"
on public.erp_sync_estado
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'validador'
  )
);

drop policy if exists "erp_inyectado_log_select_validador" on public.erp_inyectado_log;
create policy "erp_inyectado_log_select_validador"
on public.erp_inyectado_log
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'validador'
  )
);

revoke all on public.erp_sync_estado from anon, authenticated;
revoke all on public.erp_inyectado_log from anon, authenticated;
grant select on public.erp_sync_estado to authenticated;
grant select on public.erp_inyectado_log to authenticated;

-- ---------------------------------------------------------------------
-- 4. Aplicar un lote de cambios
--    p_items = [{"pedido": "3112", "talla": "27", "inyectado": 20}, ...]
-- ---------------------------------------------------------------------
create or replace function public.erp_actualizar_inyectado(p_items jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_activo boolean;
  v_corrida uuid := gen_random_uuid();
  v_item jsonb;
  v_pedido text;
  v_talla text;
  v_nuevo integer;
  v_coinciden integer;
  v_anterior integer;
  v_solicitado integer;
  v_filas integer;
  v_actualizadas integer := 0;
  v_sin_cambio integer := 0;
  v_sin_coincidencia integer := 0;
  v_ambiguas integer := 0;
  v_rechazadas integer := 0;
begin
  select e.activo into v_activo from public.erp_sync_estado e where e.id = 1;
  if not coalesce(v_activo, true) then
    return jsonb_build_object('resultado', 'pausado', 'corrida_id', v_corrida);
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items debe ser un arreglo JSON.';
  end if;

  for v_item in select value from jsonb_array_elements(p_items) loop
    v_pedido := trim(coalesce(v_item ->> 'pedido', ''));
    v_talla := upper(trim(coalesce(v_item ->> 'talla', '')));

    begin
      v_nuevo := (v_item ->> 'inyectado')::integer;
    exception when others then
      v_nuevo := null;
    end;

    -- Entradas invalidas o fuera de alcance: se rechazan sin tocar nada.
    if v_pedido !~ '^[0-9]+$'
       or length(v_pedido) > 9
       or v_talla = ''
       or v_nuevo is null
       or v_nuevo < 0
       or v_nuevo > 1000000 then
      v_rechazadas := v_rechazadas + 1;
      continue;
    end if;

    if v_pedido::bigint < 3095 then
      v_rechazadas := v_rechazadas + 1;
      continue;
    end if;

    select count(*) into v_coinciden
      from public.p_pedidosh p
     where p."PedidoNo"::text = v_pedido
       and upper(trim(p."Talla"::text)) = v_talla;

    if v_coinciden = 0 then
      v_sin_coincidencia := v_sin_coincidencia + 1;
      continue;
    elsif v_coinciden > 1 then
      v_ambiguas := v_ambiguas + 1;
      continue;
    end if;

    select p."Total01Iny", p."CantidadP"
      into v_anterior, v_solicitado
      from public.p_pedidosh p
     where p."PedidoNo"::text = v_pedido
       and upper(trim(p."Talla"::text)) = v_talla;

    if coalesce(v_anterior, 0) = v_nuevo then
      v_sin_cambio := v_sin_cambio + 1;
      continue;
    end if;

    -- UNICA escritura sobre p_pedidosh: la columna Total01Iny.
    update public.p_pedidosh p
       set "Total01Iny" = v_nuevo
     where p."PedidoNo"::text = v_pedido
       and upper(trim(p."Talla"::text)) = v_talla;

    get diagnostics v_filas = row_count;
    if v_filas <> 1 then
      -- No deberia pasar (se verifico 1 linea arriba). Si pasa, se deshace
      -- TODO el lote: antes un error visible que un dato a medias.
      raise exception 'Se esperaba actualizar 1 fila y fueron % (pedido %, talla %). Se deshace el lote.',
        v_filas, v_pedido, v_talla;
    end if;

    insert into public.erp_inyectado_log
      (corrida_id, pedido, talla, inyectado_anterior, inyectado_nuevo, solicitado)
    values
      (v_corrida, v_pedido, v_talla, v_anterior, v_nuevo, v_solicitado);

    v_actualizadas := v_actualizadas + 1;
  end loop;

  return jsonb_build_object(
    'resultado', 'ok',
    'corrida_id', v_corrida,
    'actualizadas', v_actualizadas,
    'sin_cambio', v_sin_cambio,
    'sin_coincidencia', v_sin_coincidencia,
    'ambiguas', v_ambiguas,
    'rechazadas', v_rechazadas
  );
end;
$$;

comment on function public.erp_actualizar_inyectado(jsonb) is
  'Aplica un lote de cambios de Total Inyectado desde Access (066). Solo modifica p_pedidosh."Total01Iny", solo pedidos >= 3095, identificando la linea por pedido + talla (omite si no hay exactamente una). Solo service_role.';

-- ---------------------------------------------------------------------
-- 5. Resumen de la corrida (hora de ultima ejecucion y conteos)
-- ---------------------------------------------------------------------
create or replace function public.erp_registrar_corrida(p_resumen jsonb)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.erp_sync_estado e
     set ultima_ejecucion = now(),
         ultima_actualizacion = case
           when coalesce(nullif(p_resumen ->> 'actualizadas', '')::integer, 0) > 0 then now()
           else e.ultima_actualizacion
         end,
         ultimo_resultado = coalesce(nullif(p_resumen ->> 'resultado', ''), 'ok'),
         lineas_access = nullif(p_resumen ->> 'lineas_access', '')::integer,
         lineas_supabase = nullif(p_resumen ->> 'lineas_supabase', '')::integer,
         lineas_actualizadas = nullif(p_resumen ->> 'actualizadas', '')::integer,
         lineas_sin_cambio = nullif(p_resumen ->> 'sin_cambio', '')::integer,
         lineas_omitidas = nullif(p_resumen ->> 'omitidas', '')::integer
   where e.id = 1;
end;
$$;

comment on function public.erp_registrar_corrida(jsonb) is
  'Guarda en erp_sync_estado el resumen de una corrida del script de la oficina (066). Solo service_role.';

-- ---------------------------------------------------------------------
-- 6. Revertir una corrida completa (usa el valor anterior del log).
--    Solo restaura una linea si su valor actual sigue siendo el que la
--    corrida puso (si alguien la cambio despues, no se toca).
-- ---------------------------------------------------------------------
create or replace function public.erp_revertir_corrida(p_corrida uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_revertidas integer;
begin
  with revertidas as (
    update public.p_pedidosh p
       set "Total01Iny" = l.inyectado_anterior
      from public.erp_inyectado_log l
     where l.corrida_id = p_corrida
       and not l.revertido
       and p."PedidoNo"::text = l.pedido
       and upper(trim(p."Talla"::text)) = upper(trim(l.talla))
       and coalesce(p."Total01Iny", 0) = l.inyectado_nuevo
       and (
         select count(*) from public.p_pedidosh q
          where q."PedidoNo"::text = l.pedido
            and upper(trim(q."Talla"::text)) = upper(trim(l.talla))
       ) = 1
    returning l.id
  )
  update public.erp_inyectado_log l
     set revertido = true
   where l.id in (select id from revertidas);

  get diagnostics v_revertidas = row_count;
  return v_revertidas;
end;
$$;

comment on function public.erp_revertir_corrida(uuid) is
  'Deshace una corrida de erp_actualizar_inyectado devolviendo cada linea a su valor anterior (066). Solo restaura lo que sigue igual a lo que puso la corrida. Solo service_role / SQL Editor.';

-- ---------------------------------------------------------------------
-- 7. Permisos: solo service_role ejecuta estas funciones.
-- ---------------------------------------------------------------------
revoke all on function public.erp_actualizar_inyectado(jsonb) from public, anon, authenticated;
revoke all on function public.erp_registrar_corrida(jsonb) from public, anon, authenticated;
revoke all on function public.erp_revertir_corrida(uuid) from public, anon, authenticated;

grant execute on function public.erp_actualizar_inyectado(jsonb) to service_role;
grant execute on function public.erp_registrar_corrida(jsonb) to service_role;
grant execute on function public.erp_revertir_corrida(uuid) to service_role;

commit;

-- =====================================================================
-- PRUEBA SEGURA (copiar y ejecutar APARTE, en el SQL Editor, DESPUES de
-- ejecutar este archivo).
--
-- Usa un bloque DO que termina forzando un error a proposito: Postgres
-- DESHACE todo lo que hizo el bloque, asi que NO queda ningun cambio.
-- El "error" que ve en pantalla es lo esperado: trae el resultado.
--
-- Prueba 1 - un cambio valido (cambie 3112 / 27 por un pedido y talla que
-- existan). Debe decir "actualizadas": 1  (o "sin_cambio": 1 si ya valia 7):
--
--   do $$
--   declare r jsonb;
--   begin
--     r := public.erp_actualizar_inyectado('[{"pedido":"3112","talla":"27","inyectado":7}]'::jsonb);
--     raise exception 'PRUEBA 1 (se deshizo todo): %', r;
--   end $$;
--
-- Prueba 2 - un pedido anterior al 3095 y uno inexistente. Debe decir
-- "rechazadas": 1 y "sin_coincidencia": 1:
--
--   do $$
--   declare r jsonb;
--   begin
--     r := public.erp_actualizar_inyectado('[{"pedido":"3050","talla":"36","inyectado":5},{"pedido":"3999","talla":"99","inyectado":5}]'::jsonb);
--     raise exception 'PRUEBA 2 (se deshizo todo): %', r;
--   end $$;
-- =====================================================================
