-- =====================================================================
-- 059_regla_borrado_por_talla.sql
-- CAMBIO DE REGLA DE NEGOCIO: bloqueo para ELIMINAR un registro de
-- produccion (production_movements) desde Registros.
-- Fecha: 2026-10-02. Pedido por el dueno del programa (usuario final).
-- Estado: REGLA NUEVA (059).  REGLA ANTERIOR: la de 055 (ver mas abajo).
-- Reversa completa: 059_revertir_regla_borrado_por_talla.sql
--
-- ---------------------------------------------------------------------
-- 1. POR QUE SE CAMBIO
-- ---------------------------------------------------------------------
-- Caso real (pedido 3186, 2026-09-29/30): Empaque registro 338 unidades
-- (Empaque -> Completado) y las despacho; el despacho se elimino por un
-- error y las unidades volvieron a "A Despachar". Empaque quiso corregir
-- sus registros y NO pudo, porque al dia siguiente Refilado (Lady)
-- registro mas unidades de ese mismo pedido para Mateado. La regla de 055
-- bloqueaba TODO registro anterior de la orden en cuanto OTRO proceso
-- registraba despues sobre ella, aunque ese trabajo no tuviera nada que
-- ver con lo que Empaque queria corregir.
-- El principio correcto es por TALLA y por DEPENDENCIA: un registro solo
-- debe quedar bloqueado si algo posterior DEPENDE de el (el proceso
-- siguiente ya uso esas unidades), no por el simple paso del tiempo.
--
-- ---------------------------------------------------------------------
-- 2. REGLA ANTERIOR (055, y 014 para el punto a). YA NO APLICA
-- ---------------------------------------------------------------------
--   Un registro se bloqueaba si se cumplia CUALQUIERA de:
--   (a) existia un movimiento posterior de la MISMA TALLA (item_id) de
--       CUALQUIER proceso (014);
--   (b) existia un movimiento posterior de OTRO proceso en la MISMA ORDEN
--       (cualquier talla) (055).
--   Ademas, por talla despachada (046) y por no ser del autor.
--
-- ---------------------------------------------------------------------
-- 3. REGLA NUEVA (059). Por talla (item_id = pedido+referencia+talla+
--    material+color). Se puede eliminar un registro si NO se cumple:
-- ---------------------------------------------------------------------
--   (0) NO es del autor / sin motivo ........... bloquea (sin cambios).
--   (046) La talla ya fue despachada ........... bloquea (sin cambios).
--   (R1) El MISMO proceso (from_process) registro DESPUES otro movimiento
--        de esa MISMA talla ..................... bloquea. Se elimina
--        primero el mas reciente (orden inverso). Ignora los movimientos
--        automaticos por regla de enrutamiento (es_automatico).
--   (R2) El proceso que RECIBIO estas unidades (to_process = Q) ya las
--        uso, en terminos de cantidades, para esa talla:
--            recibido(Q)  = suma de quantity con to_process = Q
--            despachado(Q)= suma de quantity con from_process = Q
--                           (sin los automaticos de Refilado)
--            BLOQUEA si  recibido(Q) - quantity_del_registro < despachado(Q)
--        Q debe ser Refilado/Acabado/Mateado/Empaque. Si el destino es
--        'Completado' (registros de Empaque) no hay proceso siguiente y
--        R2 no aplica.
--   YA NO bloquea que otro proceso haya registrado despues en la orden,
--   ni que exista un movimiento posterior de la talla de otro proceso.
--
-- ---------------------------------------------------------------------
-- 4. EJEMPLOS (talla 34)
-- ---------------------------------------------------------------------
--   * Refilado envia 10 a Acabado; Acabado los registra (10 -> Empaque)
--     y se da cuenta de que eran 13. Empaque NO ha procesado: Acabado
--     PUEDE borrar su registro. (No podra procesar mas de lo recibido.)
--   * Igual, pero Empaque ya empaco los 10: recibido(Empaque)=10,
--     despachado(Empaque)=10 -> 10-10 < 10 -> BLOQUEADO (R2). Primero
--     Empaque borra el suyo, luego Acabado.
--   * Empaque recibio 10 de Acabado y 20 directo de Refilado (recibido 30,
--     dos procesos distintos); Empaque empaco 25. Borrar el lote de 10 de
--     Acabado: 30-10=20 < 25 -> BLOQUEADO (R2). Si Empaque hubiera
--     empacado 15: 20 >= 15 -> permitido.
--     (Si los dos lotes hubieran venido del MISMO proceso, el de 10 seguiria
--     bloqueado por R1 hasta borrar primero el de 20.)
--   * Empaque registra 10 (->Completado), Refilado registra mas unidades
--     de la misma talla despues: Empaque PUEDE borrar sus 10 y registrar
--     13 (R1 no aplica: Refilado es otro proceso; R2 no aplica: Completado).
--   * Empaque registra 10 y despues otros 5 de la misma talla: para borrar
--     los 10 primero debe borrar los 5 (R1).
--
-- ---------------------------------------------------------------------
-- 5. QUE CAMBIA EN LA BASE (todo es sustitucion de definiciones; no se
--    toca ningun dato)
-- ---------------------------------------------------------------------
--   * vw_historial: SOLO cambia la expresion de la columna
--     tiene_movimiento_posterior (misma posicion, mismas demas columnas;
--     el resto de la vista es copia literal de 055). Esa columna solo
--     sirve para poner el boton "x" en gris (src/ui/historyPage.js).
--   * eliminar_movimiento_con_motivo(uuid, text): el candado real. Se
--     reemplaza el bloque (a)+(b) por (R1)+(R2). Todo lo demas (autor,
--     motivo, talla despachada, log_eliminaciones, delete) igual a 055.
--   * Frontend (src/ui/historyPage.js): solo el texto del tooltip.
--
-- ---------------------------------------------------------------------
-- 6. NO CUBIERTO (a proposito)
-- ---------------------------------------------------------------------
--   * Devoluciones (tabla returns) no entran en la cuenta R2; hoy
--     tampoco bloqueaban este borrado.
--   * La regla de talla despachada (046) se conserva tal cual (no se
--     volvio por cantidades).
--
-- ---------------------------------------------------------------------
-- 7. COMO VOLVER A LA REGLA ANTERIOR
-- ---------------------------------------------------------------------
--   Ejecutar 059_revertir_regla_borrado_por_talla.sql: restaura
--   textualmente vw_historial y eliminar_movimiento_con_motivo de 055.
--   (Y revertir el texto del tooltip en src/ui/historyPage.js.)
--
-- Va en una transaccion: si algo falla, no queda nada a medias.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- A. vw_historial (copia de 055 con la nueva expresion de
--    tiene_movimiento_posterior). create or replace: mismas columnas.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- B. El candado real: eliminar_movimiento_con_motivo con la regla nueva.
-- ---------------------------------------------------------------------
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


commit;

-- =====================================================================
-- PRUEBAS sugeridas (solo lectura) despues de ejecutar, con el pedido 3186:
--
--   -- Debe quedar en false para los 6 registros de Empaque del 29/09
--   -- (Empaque -> Completado) y en true para los de Mateado -> Empaque
--   -- (Empaque ya los uso):
--   select created_at at time zone 'America/Bogota' as fecha, from_process, to_process,
--          size, quantity, tiene_movimiento_posterior
--     from public.vw_historial
--    where order_number = '3186' and tipo = 'movimiento'
--    order by created_at, size;
-- =====================================================================
