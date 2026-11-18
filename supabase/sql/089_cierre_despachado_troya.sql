-- =====================================================================
-- 089_cierre_despachado_troya.sql
-- Cierre a la fuerza con dos tipos nuevos para pedidos que SI se despacharon
-- en Troya (el programa anterior) pero en esta plataforma figuran sin despachar:
--
--   despachado_troya_total    Todo lo que faltaba por despachar salio en Troya.
--   despachado_troya_parcial  Se reparte lo que faltaba, POR TALLA, en tres:
--        (i)   despachado en Troya,
--        (ii)  no se despacho y SIGUE pendiente,
--        (iii) no se despacho y YA NO se va a despachar (no cuenta como pendiente).
--
-- QUE CAMBIA
--   1. pedido_cierre_forzado: el check de tipo_cierre acepta los 2 tipos nuevos
--      y gana la columna fecha_despacho_troya (opcional: el dia que salio en Troya).
--   2. Tabla nueva pedido_cierre_troya: por talla (item_id) los pares (i) y (iii)
--      del cierre parcial. Lo pendiente (ii) NO se guarda: es lo que sobra, asi
--      si Access cambia una cantidad despues nada queda descuadrado.
--      Si se reabre el pedido (se borra el cierre) se borran estos pares solos.
--   3. cerrar_pedido_forzado gana p_fecha_troya y p_lineas (opcionales).
--      Una pestana vieja que llame solo con tres datos sigue funcionando.
--   4. Funcion nueva cambiar_tipo_cierre_forzado: el Validador cambia el tipo de
--      un cierre ya hecho (o sin clasificar), con auditoria (tipo anterior y nuevo).
--   5. Las vistas del dashboard (088) ganan 4 columnas AL FINAL (tipo_cierre,
--      troya_despachado, troya_no_se_despacha, fecha_troya). Lo demas igual.
--
-- NO CAMBIA: Despachos, movimientos, candados del cierre, reabrir, pedidos.
-- Un pedido cancelado en Access sigue mandando sobre cualquier tipo.
--
-- REQUIERE: 057, 084, 087 y 088 ya ejecutados.
-- Reversa: 089_revertir_cierre_despachado_troya.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Tipos nuevos y fecha opcional
-- ---------------------------------------------------------------------
alter table public.pedido_cierre_forzado
  drop constraint if exists pedido_cierre_forzado_tipo_check;
alter table public.pedido_cierre_forzado
  add constraint pedido_cierre_forzado_tipo_check
    check (tipo_cierre is null or tipo_cierre in
      ('cancelado', 'no_terminado', 'operativo', 'despachado_troya_total', 'despachado_troya_parcial'));

alter table public.pedido_cierre_forzado
  add column if not exists fecha_despacho_troya date;

comment on column public.pedido_cierre_forzado.fecha_despacho_troya is
  'Dia en que salio el pedido en Troya (089). Opcional; solo para los tipos despachado_troya_*. Con fecha cuenta tambien en el despachado por fecha de despacho.';

-- ---------------------------------------------------------------------
-- 2. Pares por talla del cierre parcial
-- ---------------------------------------------------------------------
create table if not exists public.pedido_cierre_troya (
  order_number     text    not null references public.pedido_cierre_forzado(order_number) on delete cascade,
  item_id          text    not null,
  talla            text,
  despachado_troya integer not null default 0 check (despachado_troya >= 0),
  no_se_despacha   integer not null default 0 check (no_se_despacha >= 0),
  primary key (order_number, item_id)
);

alter table public.pedido_cierre_troya enable row level security;

drop policy if exists "pedido_cierre_troya_select" on public.pedido_cierre_troya;
create policy "pedido_cierre_troya_select"
  on public.pedido_cierre_troya
  for select
  to authenticated
  using (true);

revoke insert, update, delete on public.pedido_cierre_troya from authenticated, anon;
grant select on public.pedido_cierre_troya to authenticated;

comment on table public.pedido_cierre_troya is
  'Cierre parcial "despachado en Troya" (089): por talla, pares despachados en Troya y pares que ya no se despacharan. Lo pendiente es el resto. Solo lo escriben las funciones del cierre.';

-- ---------------------------------------------------------------------
-- 3. Auxiliar interna: valida y guarda fecha + pares segun el tipo.
--    No se concede a nadie: solo la llaman las dos funciones de abajo.
-- ---------------------------------------------------------------------
create or replace function public.fn_guardar_cierre_troya(
  p_order_number text,
  p_tipo text,
  p_fecha_troya date,
  p_lineas jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_falta numeric;
  v_talla text;
  v_hay boolean := false;
begin
  -- Siempre se parte de cero: se borran los pares anteriores del pedido.
  delete from public.pedido_cierre_troya where order_number = p_order_number;

  if p_tipo not in ('despachado_troya_total', 'despachado_troya_parcial') then
    update public.pedido_cierre_forzado
       set fecha_despacho_troya = null
     where order_number = p_order_number;
    return;
  end if;

  if p_fecha_troya is not null
     and p_fecha_troya > (now() at time zone 'America/Bogota')::date then
    raise exception 'La fecha de despacho en Troya no puede ser futura.';
  end if;

  update public.pedido_cierre_forzado
     set fecha_despacho_troya = p_fecha_troya
   where order_number = p_order_number;

  if p_tipo = 'despachado_troya_total' then
    -- Se calcula solo: lo que falte de cada talla es lo despachado en Troya.
    if not exists (select 1 from public.vw_dashboard_lineas l where l.order_number = p_order_number) then
      raise exception 'El pedido % no aparece en el dashboard de unidades (solo pedidos desde el 3095).', p_order_number;
    end if;
    return;
  end if;

  -- Parcial: hace falta el reparto por talla.
  if p_lineas is null or jsonb_typeof(p_lineas) <> 'array' or jsonb_array_length(p_lineas) = 0 then
    raise exception 'En el cierre parcial hay que indicar los pares por talla.';
  end if;

  for r in
    select e ->> 'item_id' as item_id,
           coalesce((e ->> 'despachado_troya')::integer, 0) as i,
           coalesce((e ->> 'no_se_despacha')::integer, 0) as iii
      from jsonb_array_elements(p_lineas) e
  loop
    if r.i < 0 or r.iii < 0 then
      raise exception 'Los pares no pueden ser negativos.';
    end if;

    select greatest(l.solicitado - l.despachado, 0), l.talla
      into v_falta, v_talla
      from public.vw_dashboard_lineas l
     where l.order_number = p_order_number and l.item_id = r.item_id
     limit 1;

    if not found then
      raise exception 'Una talla indicada no pertenece al pedido %.', p_order_number;
    end if;

    if r.i + r.iii > v_falta then
      raise exception 'En la talla % indicaste % pares entre "despachados en Troya" y "ya no se despacharan", pero solo faltan % por despachar.',
        v_talla, r.i + r.iii, v_falta;
    end if;

    if r.i + r.iii > 0 then
      insert into public.pedido_cierre_troya (order_number, item_id, talla, despachado_troya, no_se_despacha)
      values (p_order_number, r.item_id, v_talla, r.i, r.iii)
      on conflict (order_number, item_id) do update
        set despachado_troya = excluded.despachado_troya,
            no_se_despacha = excluded.no_se_despacha;
      v_hay := true;
    end if;
  end loop;

  if not v_hay then
    raise exception 'Escribe al menos un par despachado en Troya o que ya no se vaya a despachar. Si todo sigue pendiente, usa "No se terminó de despachar".';
  end if;
end;
$$;

revoke all on function public.fn_guardar_cierre_troya(text, text, date, jsonb) from public, anon, authenticated;

-- ---------------------------------------------------------------------
-- 4. Cerrar a la fuerza (ahora con fecha y reparto opcionales)
-- ---------------------------------------------------------------------
drop function if exists public.cerrar_pedido_forzado(text, text, text);

create or replace function public.cerrar_pedido_forzado(
  p_order_number text,
  p_motivo text,
  p_tipo text default null,
  p_fecha_troya date default null,
  p_lineas jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede cerrar un pedido a la fuerza.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar el motivo del cierre.';
  end if;

  if p_tipo is null or p_tipo not in
     ('cancelado', 'no_terminado', 'operativo', 'despachado_troya_total', 'despachado_troya_parcial') then
    raise exception 'Debes clasificar el cierre. Si la pantalla no te lo pide, recarga la pagina.';
  end if;

  if not exists (select 1 from public.p_pedidosh where "PedidoNo"::text = p_order_number) then
    raise exception 'El pedido % no existe.', p_order_number;
  end if;

  if exists (select 1 from public.pedido_cierre_forzado where order_number = p_order_number) then
    raise exception 'El pedido % ya esta cerrado a la fuerza.', p_order_number;
  end if;

  insert into public.pedido_cierre_forzado (order_number, motivo, cerrado_por, tipo_cierre)
  values (p_order_number, trim(p_motivo), v_perfil_id, p_tipo);

  perform public.fn_guardar_cierre_troya(p_order_number, p_tipo, p_fecha_troya, p_lineas);

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (v_perfil_id, 'cerrar_forzado', 'Validador', p_order_number,
          jsonb_build_object('tipo_cierre', p_tipo, 'fecha_troya', p_fecha_troya, 'lineas', p_lineas),
          trim(p_motivo));
end;
$$;

revoke all on function public.cerrar_pedido_forzado(text, text, text, date, jsonb) from public, anon;
grant execute on function public.cerrar_pedido_forzado(text, text, text, date, jsonb) to authenticated;

comment on function public.cerrar_pedido_forzado(text, text, text, date, jsonb) is
  'Cierra un pedido a la fuerza (057) con motivo y tipo obligatorios (087/089). Los tipos despachado_troya_* aceptan fecha y reparto por talla. Solo Validador. Audita en audit_validador.';

-- ---------------------------------------------------------------------
-- 5. Cambiar el tipo de un cierre ya hecho
-- ---------------------------------------------------------------------
create or replace function public.cambiar_tipo_cierre_forzado(
  p_order_number text,
  p_tipo text,
  p_fecha_troya date default null,
  p_lineas jsonb default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_anterior text;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede cambiar el tipo de un cierre a la fuerza.';
  end if;

  if p_tipo is null or p_tipo not in
     ('cancelado', 'no_terminado', 'operativo', 'despachado_troya_total', 'despachado_troya_parcial') then
    raise exception 'Tipo de cierre invalido.';
  end if;

  select f.tipo_cierre into v_anterior
    from public.pedido_cierre_forzado f
   where f.order_number = p_order_number
   for update;

  if not found then
    raise exception 'El pedido % no esta cerrado a la fuerza.', p_order_number;
  end if;

  update public.pedido_cierre_forzado
     set tipo_cierre = p_tipo
   where order_number = p_order_number;

  perform public.fn_guardar_cierre_troya(p_order_number, p_tipo, p_fecha_troya, p_lineas);

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (v_perfil_id, 'cambiar_tipo_cierre_forzado', 'Validador', p_order_number,
          jsonb_build_object('tipo_anterior', v_anterior, 'tipo_nuevo', p_tipo,
                             'fecha_troya', p_fecha_troya, 'lineas', p_lineas),
          null);
end;
$$;

revoke all on function public.cambiar_tipo_cierre_forzado(text, text, date, jsonb) from public, anon;
grant execute on function public.cambiar_tipo_cierre_forzado(text, text, date, jsonb) to authenticated;

comment on function public.cambiar_tipo_cierre_forzado(text, text, date, jsonb) is
  'Cambia el tipo de un cierre a la fuerza ya hecho, o lo clasifica si estaba sin clasificar (089). Solo Validador. Audita tipo anterior y nuevo.';

-- ---------------------------------------------------------------------
-- 6. Vistas del dashboard: mismas columnas de 088 + 4 al final
-- ---------------------------------------------------------------------
create or replace view public.vw_dashboard_lineas
with (security_invoker = true)
as
with vivas as (
  select p.*
    from public.p_pedidosh p
   where coalesce(p."Cancelado", false) = false
     and case when p."PedidoNo"::text ~ '^[0-9]+$' then p."PedidoNo"::text::bigint end >= 3095
),
despachado as (
  select doi.item_id, sum(doi.cantidad)::numeric as despachado
    from public.despacho_orden_items doi
   group by doi.item_id
),
cancelados as (
  select distinct c.pedido
    from public.erp_cambios c
   where c.tipo = 'cancelado'
     and c.estado in ('pendiente', 'aplicado', 'rechazado')
),
numeradas as (
  select v.*,
         row_number() over (partition by v.item_id order by v."Talla", v."DetalleVira") as rn
    from vivas v
)
select
  n."PedidoNo"::text                                   as order_number,
  n.item_id                                            as item_id,
  n."Talla"::text                                      as talla,
  n."Cliente"                                          as cliente,
  n."NombreR"                                          as nombre_suela,
  n."MaterialP"                                        as material,
  n."ColorP"                                           as color,
  lower(coalesce(n."Vira"::text, ''))      in ('true', 't', '1', 'si', 'sí') as vira,
  lower(coalesce(n."Acabado"::text, ''))   in ('true', 't', '1', 'si', 'sí') as acabado,
  lower(coalesce(n."Esterilla"::text, '')) in ('true', 't', '1', 'si', 'sí') as esterilla,
  lower(coalesce(n."Marquilla"::text, '')) in ('true', 't', '1', 'si', 'sí') as marquilla,
  n."FechaP"                                           as fecha_pedido,
  coalesce(n."CantidadP", 0)::numeric                  as solicitado,
  case when n.rn = 1 then coalesce(d.despachado, 0) else 0 end as despachado,
  (pcf.order_number is not null)                       as cierre_forzado,
  (can.pedido is not null or pcf.tipo_cierre = 'cancelado') as cancelado_access,
  pcf.tipo_cierre                                      as tipo_cierre,
  case when n.rn = 1 then coalesce(t.despachado_troya, 0) else 0 end::numeric as troya_despachado,
  case when n.rn = 1 then coalesce(t.no_se_despacha, 0) else 0 end::numeric   as troya_no_se_despacha,
  pcf.fecha_despacho_troya                             as fecha_troya
from numeradas n
left join despachado d on d.item_id = n.item_id
left join public.pedido_cierre_forzado pcf on pcf.order_number = n."PedidoNo"::text
left join public.pedido_cierre_troya t
       on t.order_number = n."PedidoNo"::text and t.item_id = n.item_id
left join cancelados can on can.pedido = n."PedidoNo"::text;

grant select on public.vw_dashboard_lineas to authenticated;
revoke select on public.vw_dashboard_lineas from anon;

comment on view public.vw_dashboard_lineas is
  'Dashboard de unidades (084/088/089): una fila por linea viva (pedido x talla) desde el 3095, con solicitado, despachado, atributos, estado del pedido y, si aplica, lo despachado en Troya. Solo lectura.';

-- vw_dashboard_despachos NO cambia (sigue como en 088): solo trae despachos reales.

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (despues de ejecutar)
--
-- A) Las vistas siguen respondiendo y las columnas nuevas existen:
--   select order_number, tipo_cierre, troya_despachado, troya_no_se_despacha, fecha_troya
--     from public.vw_dashboard_lineas limit 5;
--
-- B) Las funciones existen y estan protegidas (sin sesion responden
--    "Solo el Validador..."):
--   select public.cambiar_tipo_cierre_forzado('1', 'operativo');
--
-- C) Ningun dato cambia al ejecutar: los cierres existentes siguen igual.
--   select coalesce(tipo_cierre,'(sin clasificar)'), count(*)
--     from public.pedido_cierre_forzado group by 1;
-- =====================================================================
