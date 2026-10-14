-- =====================================================================
-- 060_revertir_borrado_por_unidades.sql
-- REVERSA de 060_borrado_por_unidades_y_lote_atomico.sql (2026-10-06).
-- Vuelve EXACTAMENTE al estado de 059_regla_borrado_por_talla.sql:
--   * se restaura eliminar_movimiento_con_motivo con la logica completa de
--     059 (incluye el bloqueo 046: una talla con algun despacho no admite
--     borrar ningun registro);
--   * se eliminan el RPC de lote, la funcion interna y el trigger de 060;
--   * se restaura vw_historial de 059 (sin la columna
--     bloqueado_por_despacho; por eso se hace drop + create, ya que
--     create or replace view no puede quitar columnas).
-- No toca ningun dato. Despues de correrlo, revertir tambien en el
-- frontend (git: cambio "060"): historyPage.js y movementsService.js.
-- Si ademas se quiere volver a la regla 055/014, ejecutar despues
-- 059_revertir_regla_borrado_por_talla.sql.
-- =====================================================================

begin;

-- 1. La funcion de un registro vuelve a la version 059 (autonoma).
create or replace function public.eliminar_movimiento_con_motivo(p_movimiento_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registro public.production_movements;
  v_perfil_id uuid;
  v_consecutivos text;
  v_recibido numeric;
  v_despachado numeric;
begin
  select id into v_perfil_id from public.profiles where auth_id = auth.uid();
  if v_perfil_id is null then
    raise exception 'Usuario no valido.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este registro.';
  end if;

  select * into v_registro from public.production_movements where id = p_movimiento_id;
  if v_registro.id is null then
    raise exception 'El registro no existe o ya fue eliminado.';
  end if;

  if v_registro.user_id is distinct from v_perfil_id then
    raise exception 'Solo puedes eliminar registros que tu mismo creaste.';
  end if;

  -- Bloqueo por talla despachada (046). SIN CAMBIOS en 059.
  select string_agg(distinct d.consecutivo, ', ')
    into v_consecutivos
    from public.despacho_orden_items doi
    join public.despachos d on d.id = doi.despacho_id
   where doi.item_id = v_registro.item_id;

  if v_consecutivos is not null then
    raise exception 'No puedes eliminar este registro: la talla % del pedido % ya fue despachada (%). Elimina primero ese despacho en Despachos > Despachado.',
      v_registro.size, v_registro.order_number, v_consecutivos;
  end if;

  -- (R1, 059) El MISMO proceso registro despues otra vez esta MISMA talla:
  --     se elimina primero el mas reciente. (Reemplaza a 055-a, que
  --     bloqueaba por cualquier movimiento posterior de la talla, de
  --     cualquier proceso.)
  if exists (
    select 1 from public.production_movements m2
    where m2.item_id = v_registro.item_id
      and m2.from_process is not distinct from v_registro.from_process
      and m2.es_automatico = false
      and m2.id <> v_registro.id
      and m2.created_at > v_registro.created_at
  ) then
    raise exception 'No puedes eliminar este registro: % ya registro despues otro movimiento de esta talla. Elimina primero el mas reciente.',
      v_registro.from_process;
  end if;

  -- (R2, 059) El proceso que RECIBIO estas unidades ya las uso: si al
  --     quitarlas lo recibido no alcanza para lo que ese proceso ya
  --     despacho, se bloquea. (Reemplaza a 055-b, que bloqueaba la orden
  --     entera si OTRO proceso registraba despues.) Si el destino es
  --     'Completado' no hay proceso siguiente y no aplica.
  if v_registro.to_process in ('Refilado', 'Acabado', 'Mateado', 'Empaque') then
    select coalesce(sum(r.quantity), 0) into v_recibido
      from public.production_movements r
     where r.item_id = v_registro.item_id and r.to_process = v_registro.to_process;

    select coalesce(sum(d.quantity), 0) into v_despachado
      from public.production_movements d
     where d.item_id = v_registro.item_id
       and d.from_process = v_registro.to_process
       and d.es_automatico = false;

    if v_recibido - v_registro.quantity < v_despachado then
      raise exception 'No puedes eliminar este registro: % ya proceso unidades de la talla % del pedido % que llegaron de este envio. Elimina primero el registro de %.',
        v_registro.to_process, v_registro.size, v_registro.order_number, v_registro.to_process;
    end if;
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('production_movements', v_registro.id, to_jsonb(v_registro), v_perfil_id, trim(p_motivo));

  delete from public.production_movements where id = p_movimiento_id;
end;
$$;

grant execute on function public.eliminar_movimiento_con_motivo(uuid, text) to authenticated;

comment on function public.eliminar_movimiento_con_motivo(uuid, text) is
  'Elimina un movimiento con motivo obligatorio y snapshot en log_eliminaciones. Bloquea por TALLA (059): talla despachada (046); registro posterior del mismo proceso en la misma talla (R1); o el proceso que recibio las unidades ya las uso (R2, balance recibido - despachado). Antes de 059 (regla 055): cualquier movimiento posterior de la talla o de otro proceso en la orden.';

-- 2. Se quita lo nuevo de 060.
drop trigger if exists trg_validar_saldo_empaque_al_borrar on public.production_movements;
drop function if exists public.fn_validar_saldo_empaque_al_borrar();
drop function if exists public.eliminar_movimientos_con_motivo(uuid[], text);
drop function if exists public.fn_eliminar_movimiento_validado(uuid, uuid, text);

-- 3. vw_historial vuelve a la version 059 (sin bloqueado_por_despacho).
--    Nada depende de esta vista dentro de la base (solo la consulta el
--    frontend).
drop view if exists public.vw_historial;

create or replace view public.vw_historial
with (security_invoker = true) as
select
  h.id,
  h.tipo,
  h.order_number,
  h.item_id,
  h.reference,
  h.size,
  h.quantity,
  h.from_process,
  h.to_process,
  h.causal,
  h.failed_process,
  h.action,
  h.observation,
  h.user_id,
  pr.name as user_name,
  pr.role as user_role,
  h.created_at,
  coalesce(ep.paso_refilado, false) as paso_refilado,
  coalesce(ep.paso_mateado, false) as paso_mateado,
  coalesce(ep.paso_acabado, false) as paso_acabado,
  coalesce(ep.paso_empaque, false) as paso_empaque,
  h.precio_cop,
  h.valor_cop,
  tal.fecha_despacho,
  coalesce(est.pedido_completo, false) as despacho_confirmado,
  -- 059: NUEVA regla de bloqueo por TALLA (ver cabecera de este archivo).
  -- Un registro de produccion queda bloqueado si:
  --   (R1) el MISMO proceso registro despues otra vez esa MISMA talla
  --        (se borra primero el mas reciente), o
  --   (R2) el proceso que RECIBIO estas unidades ya despacho mas de lo que
  --        le quedaria recibido si se borran (el siguiente ya las uso).
  -- Ya NO bloquea porque OTRO proceso haya registrado despues en la orden
  -- (055-b) ni por cualquier movimiento posterior de la talla (014/055-a).
  (h.tipo = 'movimiento' and (
     exists (
       select 1 from public.production_movements m2
       where m2.item_id = h.item_id
         and m2.from_process is not distinct from h.from_process
         and m2.es_automatico = false
         and m2.id <> h.id
         and m2.created_at > h.created_at
     )
     or (
       h.to_process in ('Refilado', 'Acabado', 'Mateado', 'Empaque')
       and (
         select coalesce(sum(r.quantity), 0)
           from public.production_movements r
          where r.item_id = h.item_id and r.to_process = h.to_process
       ) - h.quantity < (
         select coalesce(sum(d.quantity), 0)
           from public.production_movements d
          where d.item_id = h.item_id and d.from_process = h.to_process and d.es_automatico = false
       )
     )
   )) as tiene_movimiento_posterior,
  -- Las dos ultimas columnas son de 049 (el despacho concreto en que
  -- salio ESTE registro de Empaque). Van despues de
  -- tiene_movimiento_posterior y no se pueden mover: create or replace
  -- view no deja reordenar ni quitar columnas, solo agregar al final.
  md.despacho_consecutivo,
  md.despacho_fecha as despacho_fecha_registro
from (
  select
    m.id,
    'movimiento'::text as tipo,
    m.order_number,
    m.item_id,
    m.reference,
    m.size,
    m.quantity,
    m.from_process,
    m.to_process,
    null::text as causal,
    null::text as failed_process,
    null::text as action,
    m.observation,
    m.user_id,
    m.created_at,
    m.precio_cop,
    m.valor_cop
  from public.production_movements m

  union all

  select
    r.id,
    'devolucion'::text as tipo,
    r.order_number,
    r.item_id,
    null::text as reference,
    r.size,
    r.quantity,
    r.failed_process as from_process,
    coalesce(r.reprocess_destination, 'N/A') as to_process,
    r.causal,
    r.failed_process,
    r.action,
    r.observation,
    r.user_id,
    r.created_at,
    null::numeric as precio_cop,
    null::numeric as valor_cop
  from public.returns r
) h
left join public.profiles pr on pr.id = h.user_id
left join public.vw_pedido_estado_procesos ep on ep.order_number = h.order_number
left join (
  -- Fecha en que ESTA talla salio (la ultima vez, si salio en varias remesas).
  select doi.item_id,
         max(coalesce(d.confirmed_at, d.created_at)) as fecha_despacho
  from public.despacho_orden_items doi
  join public.despachos d on d.id = doi.despacho_id
  group by doi.item_id
) tal on tal.item_id = h.item_id
left join public.vw_pedido_despacho_estado est on est.order_number = h.order_number
left join public.vw_movimiento_despacho md on md.movimiento_id = h.id;

comment on view public.vw_historial is
  'Linea de tiempo de production_movements + returns. fecha_despacho = talla (decide el bloqueo por despacho); despacho_consecutivo / despacho_fecha_registro = remesa concreta de ESTE registro (049); despacho_confirmado = completitud del pedido; tiene_movimiento_posterior (059) bloquea por TALLA: registro posterior del mismo proceso, o el proceso que recibio las unidades ya las uso (balance). Ver 059_regla_borrado_por_talla.sql.';

grant select on public.vw_historial to authenticated;

commit;
