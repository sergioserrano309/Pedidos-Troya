-- =====================================================================
-- 087_tipo_cierre_forzado.sql
-- Clasificacion del cierre a la fuerza: al cerrar un pedido, el Validador
-- debe decir POR QUE, ademas de escribir el motivo:
--
--   cancelado     (a) el pedido se cancelo.
--   no_terminado  (b) no se termino de despachar y no se va a hacer mas.
--   operativo     (c) cualquier otro motivo operativo.
--
-- Sirve para el Dashboard de unidades: un cierre 'cancelado' no cuenta
-- como pendiente; los otros dos si (088 actualiza las vistas del dashboard).
--
-- QUE CAMBIA
--   1. Columna nueva pedido_cierre_forzado.tipo_cierre (NULL = sin
--      clasificar: todos los cierres hechos antes de este cambio).
--   2. Marca AUTOMATICA 'cancelado' en todo cierre con el motivo exacto
--      "Cancelado en Troya" (cierres del sistema y botones de Cambios ERP),
--      con un disparador al insertar. Las funciones de 072-077 no se tocan.
--      Los cierres "Cancelado en Troya" que ya existen se marcan ahora.
--   3. cerrar_pedido_forzado gana p_tipo, OBLIGATORIO. (Se reemplaza la
--      funcion de 057: misma regla de siempre + el tipo. Una pestana vieja
--      del navegador que aun no mande el tipo recibe un aviso claro y basta
--      recargar la pagina.)
--   4. Funcion nueva clasificar_cierre_forzado: el Validador clasifica un
--      cierre que esta sin clasificar. No permite cambiar uno ya clasificado
--      (para eso se reabre y se cierra otra vez).
--
-- NO CAMBIA: reabrir_pedido_forzado, los candados del cierre, vistas ni datos
-- de pedidos. Reabrir borra la fila, asi que el tipo se va con ella.
-- Reversa: 087_revertir_tipo_cierre_forzado.sql
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- 1. Columna
-- ---------------------------------------------------------------------
alter table public.pedido_cierre_forzado
  add column if not exists tipo_cierre text;

alter table public.pedido_cierre_forzado
  drop constraint if exists pedido_cierre_forzado_tipo_check;
alter table public.pedido_cierre_forzado
  add constraint pedido_cierre_forzado_tipo_check
    check (tipo_cierre is null or tipo_cierre in ('cancelado', 'no_terminado', 'operativo'));

comment on column public.pedido_cierre_forzado.tipo_cierre is
  'Por que se cerro (087): cancelado | no_terminado | operativo. NULL = sin clasificar (cierres anteriores a 087).';

-- ---------------------------------------------------------------------
-- 2. Marca automatica de los cierres por cancelacion en Access
-- ---------------------------------------------------------------------
create or replace function public.fn_tipo_cierre_automatico()
returns trigger
language plpgsql
as $$
begin
  if new.tipo_cierre is null and new.motivo = 'Cancelado en Troya' then
    new.tipo_cierre := 'cancelado';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_tipo_cierre_automatico on public.pedido_cierre_forzado;
create trigger trg_tipo_cierre_automatico
  before insert on public.pedido_cierre_forzado
  for each row execute function public.fn_tipo_cierre_automatico();

-- Los que ya existen con ese motivo.
update public.pedido_cierre_forzado
   set tipo_cierre = 'cancelado'
 where tipo_cierre is null
   and motivo = 'Cancelado en Troya';

-- ---------------------------------------------------------------------
-- 3. Cerrar a la fuerza: ahora con tipo obligatorio
-- ---------------------------------------------------------------------
drop function if exists public.cerrar_pedido_forzado(text, text);

create or replace function public.cerrar_pedido_forzado(
  p_order_number text,
  p_motivo text,
  p_tipo text default null
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

  if p_tipo is null or p_tipo not in ('cancelado', 'no_terminado', 'operativo') then
    raise exception 'Debes clasificar el cierre: cancelado, no se termino de despachar u otro motivo operativo. Si la pantalla no te lo pide, recarga la pagina.';
  end if;

  if not exists (select 1 from public.p_pedidosh where "PedidoNo"::text = p_order_number) then
    raise exception 'El pedido % no existe.', p_order_number;
  end if;

  if exists (select 1 from public.pedido_cierre_forzado where order_number = p_order_number) then
    raise exception 'El pedido % ya esta cerrado a la fuerza.', p_order_number;
  end if;

  insert into public.pedido_cierre_forzado (order_number, motivo, cerrado_por, tipo_cierre)
  values (p_order_number, trim(p_motivo), v_perfil_id, p_tipo);

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (v_perfil_id, 'cerrar_forzado', 'Validador', p_order_number,
          jsonb_build_object('tipo_cierre', p_tipo), trim(p_motivo));
end;
$$;

revoke all on function public.cerrar_pedido_forzado(text, text, text) from public, anon;
grant execute on function public.cerrar_pedido_forzado(text, text, text) to authenticated;

comment on function public.cerrar_pedido_forzado(text, text, text) is
  'Cierra un pedido a la fuerza (057) con motivo y tipo obligatorios (087): cancelado | no_terminado | operativo. Solo Validador. Audita en audit_validador.';

-- ---------------------------------------------------------------------
-- 4. Clasificar un cierre que esta sin clasificar
-- ---------------------------------------------------------------------
create or replace function public.clasificar_cierre_forzado(
  p_order_number text,
  p_tipo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_actual text;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede clasificar un cierre a la fuerza.';
  end if;

  if p_tipo is null or p_tipo not in ('cancelado', 'no_terminado', 'operativo') then
    raise exception 'Tipo de cierre invalido.';
  end if;

  select f.tipo_cierre into v_actual
    from public.pedido_cierre_forzado f
   where f.order_number = p_order_number
   for update;

  if not found then
    raise exception 'El pedido % no esta cerrado a la fuerza.', p_order_number;
  end if;

  if v_actual is not null then
    raise exception 'El cierre del pedido % ya esta clasificado. Para cambiarlo hay que reabrir el pedido y cerrarlo de nuevo.', p_order_number;
  end if;

  update public.pedido_cierre_forzado
     set tipo_cierre = p_tipo
   where order_number = p_order_number;

  insert into public.audit_validador (validador_id, accion, rol_actuante, orden_id, detalle, razon)
  values (v_perfil_id, 'clasificar_cierre_forzado', 'Validador', p_order_number,
          jsonb_build_object('tipo_cierre', p_tipo), null);
end;
$$;

revoke all on function public.clasificar_cierre_forzado(text, text) from public, anon;
grant execute on function public.clasificar_cierre_forzado(text, text) to authenticated;

comment on function public.clasificar_cierre_forzado(text, text) is
  'Clasifica un cierre a la fuerza que esta sin clasificar (087). Solo Validador; no cambia uno ya clasificado.';

commit;

-- =====================================================================
-- PRUEBAS SEGURAS (correr DESPUES de ejecutar lo de arriba)
--
-- A) Cuantos cierres hay por tipo (los "Cancelado en Troya" deben quedar
--    como 'cancelado'; los hechos a mano, NULL = sin clasificar):
--   select coalesce(tipo_cierre, '(sin clasificar)') tipo, count(*)
--     from public.pedido_cierre_forzado group by 1 order by 2 desc;
--
-- B) El disparador (se deshace solo con el rollback; no deja nada):
--   begin;
--   insert into public.pedido_cierre_forzado (order_number, motivo, cerrado_por)
--     values ('PRUEBA-087', 'Cancelado en Troya', null),
--            ('PRUEBA-087B', 'Otro motivo', null);
--   select order_number, tipo_cierre from public.pedido_cierre_forzado
--    where order_number like 'PRUEBA-087%';
--   -- Esperado: PRUEBA-087 = cancelado; PRUEBA-087B = vacio.
--   rollback;
--
-- C) Que rechace un tipo invalido (debe dar error de check; usar rollback):
--   begin;
--   insert into public.pedido_cierre_forzado (order_number, motivo, cerrado_por, tipo_cierre)
--     values ('PRUEBA-087C', 'x', null, 'inventado');
--   rollback;
--
-- D) Las funciones desde el editor responden "Solo el Validador..." porque
--    no hay sesion de usuario: eso confirma que existen y estan protegidas.
--   select public.cerrar_pedido_forzado('1', 'x', 'operativo');
-- =====================================================================
