-- =====================================================================
-- 069_cambios_erp.sql
-- FASE 1 de "cambios de Access": DETECTAR, REGISTRAR y MOSTRAR.
--
-- POR QUE
--   Los pedidos se cargan una vez y despues se modifican en Access (el
--   cliente cambia una cantidad, se corrige un color, se cancela...). El
--   programa no se entera. El diagnostico del 2026-10-19 encontro 58
--   pedidos (de 803) con diferencias que importan.
--
-- QUE AGREGA (todo NUEVO; no cambia ninguna tabla ni vista existente)
--   1. erp_cambios         Una fila por diferencia detectada, con su
--                          historial (cuando aparecio, cuantas revisiones
--                          seguidas se vio igual, en que quedo).
--   2. erp_cambios_estado  Una sola fila: ultima corrida del detector,
--                          conteos e INTERRUPTOR (activo).
--   3. erp_registrar_cambios(jsonb, jsonb)  Recibe el conjunto COMPLETO de
--                          diferencias de una revision y lo concilia.
--
-- ESTA FASE NO MODIFICA NINGUN PEDIDO. Nada escribe en p_pedidosh,
-- production_movements, despachos ni pedido_cierre_forzado. Solo se
-- registran y se muestran las diferencias. Aplicarlas es de las fases
-- siguientes.
--
-- CICLO DE VIDA DE UNA DIFERENCIA
--   pendiente  Access y el programa difieren (estado inicial).
--   resuelto   Access y el programa volvieron a coincidir (por ejemplo,
--              revirtieron el cambio en Access). Queda como historial.
--   aplicado / rechazado   Reservados para las fases siguientes.
--   Si Access cambia OTRA VEZ el mismo dato, la diferencia se actualiza
--   y su contador de "revisiones seguidas" vuelve a 1 (la regla de
--   esperar 2 revisiones iguales evita aplicar una edicion a medias).
--
-- IDENTIFICACION DE UNA DIFERENCIA ACTIVA
--   (pedido, talla, tipo, campo, clave_linea). talla es NULL en los
--   cambios de todo el pedido (cliente, cancelacion completa).
--
-- SEGURIDAD
--   * erp_cambios la leen TODOS los roles (la nota del detalle de la orden
--     la ve cualquiera); NADIE la escribe desde la aplicacion.
--   * erp_cambios_estado solo la lee el Validador.
--   * La funcion solo la ejecuta service_role (la llave del script).
--   * Rechaza una lectura vacia o incompleta de Access (menos de la mitad
--     de las lineas de la corrida anterior): antes no registrar que marcar
--     como "resueltas" cientos de diferencias por una lectura mala.
--   * Cada llamada es atomica.
--   * INTERRUPTOR: update public.erp_cambios_estado set activo = false;
--
-- Reversa: 069_revertir_cambios_erp.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Estado del detector (una sola fila)
-- ---------------------------------------------------------------------
create table if not exists public.erp_cambios_estado (
  id integer primary key default 1,
  constraint erp_cambios_estado_fila_unica check (id = 1),
  activo boolean not null default true,
  ultima_ejecucion timestamptz,
  ultimo_resultado text,
  lineas_access integer,
  lineas_supabase integer,
  cambios_pendientes integer,
  nuevas integer,
  resueltas integer
);

insert into public.erp_cambios_estado (id) values (1) on conflict (id) do nothing;

comment on table public.erp_cambios_estado is
  'Estado del detector de cambios Access -> programa (069). Una sola fila. activo=false pausa el registro.';

-- ---------------------------------------------------------------------
-- 2. Diferencias detectadas
-- ---------------------------------------------------------------------
create table if not exists public.erp_cambios (
  id bigint generated always as identity primary key,
  pedido text not null,
  talla text,
  tipo text not null check (tipo in (
    'texto', 'identidad', 'cantidad', 'cancelado', 'cancelado_parcial',
    'linea_nueva', 'linea_sobrante'
  )),
  campo text,
  clave_linea text,
  valor_access text,
  valor_programa text,
  ambiguo boolean not null default false,
  estado text not null default 'pendiente'
    check (estado in ('pendiente', 'aplicado', 'rechazado', 'resuelto')),
  detectado_at timestamptz not null default now(),
  ultima_revision_at timestamptz not null default now(),
  revisiones_consecutivas integer not null default 1,
  resuelto_at timestamptz,
  aplicado_at timestamptz,
  aplicado_por text,
  contexto jsonb not null default '{}'::jsonb,
  historial jsonb not null default '[]'::jsonb
);

-- Una sola diferencia ACTIVA por clave (las resueltas/aplicadas son historial).
create unique index if not exists uq_erp_cambios_activo
  on public.erp_cambios (pedido, coalesce(talla, ''), tipo, coalesce(campo, ''), coalesce(clave_linea, ''))
  where estado in ('pendiente', 'rechazado');

create index if not exists idx_erp_cambios_pedido on public.erp_cambios (pedido);
create index if not exists idx_erp_cambios_estado on public.erp_cambios (estado);

comment on table public.erp_cambios is
  'Diferencias entre Access y el programa (069), con su historial. Fase 1: solo se registran y se muestran; ninguna modifica pedidos.';
comment on column public.erp_cambios.contexto is
  'Foto al registrar: movimientos hechos por personas (sin los automaticos), despachos, si el pedido esta completo y si esta cerrado a la fuerza.';
comment on column public.erp_cambios.revisiones_consecutivas is
  'Cuantas revisiones seguidas se vio la diferencia exactamente igual. Vuelve a 1 si Access cambia el valor otra vez.';

-- ---------------------------------------------------------------------
-- 3. Seguridad de las tablas
-- ---------------------------------------------------------------------
alter table public.erp_cambios enable row level security;
alter table public.erp_cambios_estado enable row level security;

drop policy if exists "erp_cambios_select_autenticados" on public.erp_cambios;
create policy "erp_cambios_select_autenticados"
on public.erp_cambios
for select
to authenticated
using (true);

drop policy if exists "erp_cambios_estado_select_validador" on public.erp_cambios_estado;
create policy "erp_cambios_estado_select_validador"
on public.erp_cambios_estado
for select
to authenticated
using (
  exists (
    select 1 from public.profiles pr
    where pr.auth_id = auth.uid() and lower(pr.role) = 'validador'
  )
);

revoke all on public.erp_cambios from anon, authenticated;
revoke all on public.erp_cambios_estado from anon, authenticated;
grant select on public.erp_cambios to authenticated;
grant select on public.erp_cambios_estado to authenticated;

-- ---------------------------------------------------------------------
-- 4. Conciliar una revision
--    p_cambios = [{"pedido":"3379","talla":"39","tipo":"cantidad",
--                  "campo":"CantidadP","clave_linea":null,
--                  "valor_access":"85","valor_programa":"60",
--                  "ambiguo":false}, ...]   (el conjunto COMPLETO)
--    p_resumen = {"lineas_access": 4696, "lineas_supabase": 4701}
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

  -- 2) Diferencias nuevas.
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
  'Concilia el conjunto completo de diferencias Access vs programa de una revision (069): crea las nuevas, actualiza las existentes y marca como resueltas las que ya no aparecen. No modifica ningun pedido. Solo service_role.';

revoke all on function public.erp_registrar_cambios(jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.erp_registrar_cambios(jsonb, jsonb) to service_role;

commit;

-- =====================================================================
-- PRUEBA SEGURA (copiar y ejecutar APARTE, DESPUES de ejecutar este archivo)
-- Termina forzando un error a proposito: Postgres DESHACE todo lo que hizo
-- el bloque, asi que NO queda ninguna fila. El "error" trae el resultado.
--
-- Debe mostrar: primera = 1 nueva, 1 valida; segunda (sin diferencias) =
-- 1 resuelta; y el contexto del pedido 3379 (movimientos y despachos reales).
--
--   do $$
--   declare r1 jsonb; r2 jsonb; ctx jsonb;
--   begin
--     r1 := public.erp_registrar_cambios(
--       '[{"pedido":"3379","talla":"39","tipo":"cantidad","campo":"CantidadP","valor_access":"85","valor_programa":"60"}]'::jsonb,
--       '{"lineas_access":4696,"lineas_supabase":4701}'::jsonb);
--     select c.contexto into ctx from public.erp_cambios c where c.pedido = '3379' and c.estado = 'pendiente';
--     r2 := public.erp_registrar_cambios('[]'::jsonb, '{"lineas_access":4696,"lineas_supabase":4701}'::jsonb);
--     raise exception 'PRUEBA (se deshizo todo): primera=% | contexto=% | segunda=%', r1, ctx, r2;
--   end $$;
-- =====================================================================
