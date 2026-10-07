-- =====================================================================
-- 060_borrado_por_unidades_y_lote_atomico.sql
-- CAMBIO DE REGLA DE NEGOCIO (segunda parte de 059): eliminar registros de
-- produccion (production_movements) desde Registros.
-- Fecha: 2026-10-06. Pedido por el dueno del programa (usuario final).
-- Estado: REGLA NUEVA (060).  REGLA ANTERIOR: la de 059 (que a su vez
--         reemplazo a 055/014). Reversa: 060_revertir_borrado_por_unidades.sql
--         (vuelve EXACTAMENTE al estado 059).
--
-- ---------------------------------------------------------------------
-- 1. POR QUE SE CAMBIO
-- ---------------------------------------------------------------------
-- 059 dejo intacta la regla 046: "si CUALQUIER unidad de una talla ya fue
-- despachada, NINGUN registro de esa talla se puede borrar (de ningun
-- proceso)". Caso real (pedido 3186, 2026-10-02): la talla 35 tenia 84
-- unidades despachadas (D1074: 40, D1076: 44). Mateado registro por error
-- 86 unidades (eran de otro pedido) que Empaque aun NO habia usado
-- (recibido 170, empacado 84, despachado 84). Mateado no podia borrar ese
-- registro y habria tenido que eliminar dos despachos completos (565
-- unidades) y repetirlos, aunque las unidades despachadas no tenian nada
-- que ver con el error.
-- El sistema ya despacha por CANTIDADES por talla (vw_item_despacho_saldo:
-- empacado - despachado = disponible, y el trigger de 051 impide
-- despachar mas de lo empacado). La proteccion de borrado debe usar la
-- misma cuenta: lo YA despachado no se puede borrar; lo que aun no salio,
-- si.
--
-- Ademas: el borrado de VARIOS registros a la vez (boton "Eliminar N
-- registros") se hacia en un bucle del navegador, uno por uno y sin
-- transaccion: si uno fallaba, los anteriores ya estaban borrados.
--
-- ---------------------------------------------------------------------
-- 2. REGLA ANTERIOR (059, vigente hasta antes de este archivo)
-- ---------------------------------------------------------------------
--   Se bloquea el borrado si:
--   (0)  no es del autor / sin motivo;
--   (046) la TALLA tiene alguna unidad despachada en cualquier despacho
--        (bloqueaba TODOS los registros de esa talla, de cualquier proceso);
--   (R1) el mismo proceso registro despues otro movimiento de esa talla;
--   (R2) el proceso que recibio las unidades ya las uso (balance).
--   Borrado multiple: un bucle en el navegador, sin transaccion.
--
-- ---------------------------------------------------------------------
-- 3. REGLA NUEVA (060). Se bloquea el borrado si:
-- ---------------------------------------------------------------------
--   (0)  no es del autor / sin motivo ............. sin cambios.
--   (R5) NUEVA, solo registros de EMPAQUE (from_process = 'Empaque'):
--        quitar este registro dejaria menos unidades empacadas que
--        despachadas para esa talla:
--            empacado(talla) - quantity < despachado(talla)
--        donde empacado = suma de quantity con from_process='Empaque' y
--        despachado = suma de despacho_orden_items.cantidad de esa talla.
--        REEMPLAZA a 046. Como R1 obliga a borrar primero el registro
--        mas reciente, esto equivale a "primero empacado, primero
--        despachado" (la misma convencion de vw_movimiento_despacho). Un
--        registro PARTIDO por un despacho (parte salio, parte no) queda
--        bloqueado: un registro no se divide; hay que eliminar antes el
--        despacho.
--   (R1) registro posterior del mismo proceso en la talla .. sin cambios.
--   (R2) el proceso que recibio las unidades ya las uso .... sin cambios.
--        (Para registros de Refilado/Acabado/Mateado la proteccion de los
--        despachos es INDIRECTA: Empaque no despacha mas de lo que
--        recibio y R2 impide quitarle lo recibido si ya lo empaco.)
--   YA NO bloquea porque la talla tenga ALGUN despacho (046).
--
-- ---------------------------------------------------------------------
-- 4. CANDADOS NUEVOS
-- ---------------------------------------------------------------------
--   * Bloqueo por pedido (pg_advisory_xact_lock(hashtext(pedido))), el
--     MISMO que usa crear_despacho (045/048/051): borrar y despachar el
--     mismo pedido a la vez ya no pueden cruzarse.
--   * Trigger de ULTIMO RECURSO trg_validar_saldo_empaque_al_borrar
--     (BEFORE DELETE en production_movements): aplica R5 venga de donde
--     venga el DELETE. OJO operativo: una limpieza manual con DELETE sobre
--     production_movements de Empaque con despachos existentes puede ser
--     rechazada; elimine antes los despachos o desactive el trigger
--     (alter table public.production_movements disable trigger
--     trg_validar_saldo_empaque_al_borrar) y vuelva a activarlo despues.
--
-- ---------------------------------------------------------------------
-- 5. BORRADO MULTIPLE "TODOS O NINGUNO"
-- ---------------------------------------------------------------------
--   Nuevo RPC eliminar_movimientos_con_motivo(uuid[], text): borra todos
--   los registros indicados DENTRO DE UNA SOLA TRANSACCION (una funcion
--   plpgsql es atomica: si cualquiera falla, no se borra ninguno y el
--   mensaje dice cual y por que). Los procesa del MAS RECIENTE al mas
--   antiguo (los registros posteriores primero), que es el orden en que
--   las reglas R1/R2/R5 permiten borrar una cadena. Cada registro deja
--   su propia fila en log_eliminaciones.
--   Un solo registro sigue usando eliminar_movimiento_con_motivo(uuid,
--   text) con la misma firma de siempre.
--
-- ---------------------------------------------------------------------
-- 6. ESTRUCTURA
-- ---------------------------------------------------------------------
--   * fn_eliminar_movimiento_validado(uuid, uuid, text): TODA la logica de
--     validacion y borrado (antes vivia dentro de
--     eliminar_movimiento_con_motivo). Interna: no ejecutable por
--     usuarios.
--   * eliminar_movimiento_con_motivo(uuid, text): envoltorio delgado, misma
--     firma y comportamiento externo; comprueba el perfil y llama a la
--     interna.
--   * eliminar_movimientos_con_motivo(uuid[], text): el lote atomico.
--   * vw_historial: copia de 059 + UNA columna nueva AL FINAL,
--     bloqueado_por_despacho (R5, para poner el boton gris). La columna
--     tiene_movimiento_posterior (R1+R2) y fecha_despacho (solo
--     informativa, columna "Confirmado") no cambian.
--   * Frontend: historyPage.js usa bloqueado_por_despacho y el RPC de
--     lote; movementsService.js tiene la nueva funcion.
--
-- ---------------------------------------------------------------------
-- 7. EJEMPLO (talla 35 del pedido 3186, datos reales 2026-10-02)
-- ---------------------------------------------------------------------
--   Mateado -> Empaque: 44 (29/09), 40 y 86 (2/10). Empaque recibio 170,
--   empaco 84 (40 + 44) y se despacharon 84 (D1074 y D1076).
--   Borrar el de 86 (Mateado): R1 no aplica (es el mas reciente de
--   Mateado en esa talla); R2: 170 - 86 = 84 >= 84 empacadas -> PERMITIDO.
--   Borrar el de 44 de Empaque: R5: 84 - 44 = 40 < 84 despachadas ->
--   BLOQUEADO.
--   Si se borran los dos de Mateado y Refilado (86 y 86) en lote, se
--   procesan Mateado primero y Refilado despues: permitido.
--
-- ---------------------------------------------------------------------
-- 8. RIESGOS CONOCIDOS QUE ESTE CAMBIO NO CIERRA (decididos con el dueno)
-- ---------------------------------------------------------------------
--   a) La base NO impide que un proceso registre mas de lo que recibio:
--      esa validacion vive solo en el frontend (movementsService.js). Las
--      reglas R2/R5 suponen que se cumple.
--   b) Carrera entre un borrado y un registro aguas abajo que ocurran a
--      la vez: el borrado toma el bloqueo por pedido, pero el INSERT
--      directo de un registro no. Ventana muy pequena.
--   c) Comisiones: al permitir mas borrados, los totales de Compensacion
--      de periodos anteriores pueden cambiar. Decision del dueno: se
--      acepta, sin ningun candado adicional.
--   d) Devoluciones (tabla returns) no entran en estas cuentas.
--
-- Va en una transaccion: si algo falla, no queda nada a medias.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
-- A. vw_historial (copia de 059 + columna nueva AL FINAL).
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
  md.despacho_fecha as despacho_fecha_registro,
  -- 060: R5. Registro de Empaque que NO se puede borrar porque dejaria
  -- menos unidades empacadas que despachadas en esa talla. Columna nueva,
  -- siempre al final (create or replace view solo deja agregar).
  (h.tipo = 'movimiento' and h.from_process = 'Empaque' and (
     select coalesce(sum(e.quantity), 0)
       from public.production_movements e
      where e.item_id = h.item_id and e.from_process = 'Empaque'
   ) - h.quantity < (
     select coalesce(sum(doi.cantidad), 0)
       from public.despacho_orden_items doi
      where doi.item_id = h.item_id
   )) as bloqueado_por_despacho
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
  'Linea de tiempo de production_movements + returns. fecha_despacho = talla (decide el bloqueo por despacho); despacho_consecutivo / despacho_fecha_registro = remesa concreta de ESTE registro (049); despacho_confirmado = completitud del pedido; tiene_movimiento_posterior (059) bloquea por TALLA: registro posterior del mismo proceso, o el proceso que recibio las unidades ya las uso (balance). bloqueado_por_despacho (060): registro de Empaque que no se puede borrar porque dejaria menos empacado que despachado en la talla (R5). Ver 060_borrado_por_unidades_y_lote_atomico.sql.';

-- ---------------------------------------------------------------------
-- B. Funcion INTERNA con toda la validacion y el borrado de UN registro.
--    No la llama el usuario: la llaman los dos RPC de abajo (que son
--    security definer y comprueban el perfil).
-- ---------------------------------------------------------------------
create or replace function public.fn_eliminar_movimiento_validado(
  p_movimiento_id uuid,
  p_perfil_id uuid,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_registro public.production_movements;
  v_consecutivos text;
  v_recibido numeric;
  v_despachado numeric;
  v_empacado numeric;
begin
  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este registro.';
  end if;

  select * into v_registro from public.production_movements where id = p_movimiento_id;
  if v_registro.id is null then
    raise exception 'El registro no existe o ya fue eliminado.';
  end if;

  if v_registro.user_id is distinct from p_perfil_id then
    raise exception 'Solo puedes eliminar registros que tu mismo creaste.';
  end if;

  -- Mismo bloqueo por pedido que crear_despacho (051): borrar y despachar
  -- el mismo pedido a la vez no se cruzan. Es reentrante dentro de la
  -- misma transaccion (el lote lo toma antes, en orden).
  perform pg_advisory_xact_lock(hashtext(v_registro.order_number::text));

  -- (R5, 060) Solo registros de Empaque: quitar este registro no puede dejar
  --     menos unidades empacadas que despachadas en esa talla. Reemplaza al
  --     bloqueo de 046 por "talla con algun despacho".
  if v_registro.from_process = 'Empaque' then
    select coalesce(sum(m.quantity), 0) into v_empacado
      from public.production_movements m
     where m.item_id = v_registro.item_id and m.from_process = 'Empaque';

    select coalesce(sum(doi.cantidad), 0), string_agg(distinct d.consecutivo, ', ')
      into v_despachado, v_consecutivos
      from public.despacho_orden_items doi
      join public.despachos d on d.id = doi.despacho_id
     where doi.item_id = v_registro.item_id;

    if v_empacado - v_registro.quantity < v_despachado then
      raise exception 'No puedes eliminar este registro: la talla % del pedido % tiene % unidades despachadas (%) y al quitar este registro de % quedarian solo % empacadas. Elimina primero ese despacho en Despachos > Despachado.',
        v_registro.size, v_registro.order_number, v_despachado, v_consecutivos, v_registro.quantity, v_empacado - v_registro.quantity;
    end if;
  end if;

  -- (R1, 059) El MISMO proceso registro despues otra vez esta MISMA talla:
  --     se elimina primero el mas reciente.
  if exists (
    select 1 from public.production_movements m2
    where m2.item_id = v_registro.item_id
      and m2.from_process is not distinct from v_registro.from_process
      and m2.es_automatico = false
      and m2.id <> v_registro.id
      and m2.created_at > v_registro.created_at
  ) then
    raise exception 'No puedes eliminar este registro: % ya registro despues otro movimiento de la talla % del pedido %. Elimina primero el mas reciente.',
      v_registro.from_process, v_registro.size, v_registro.order_number;
  end if;

  -- (R2, 059) El proceso que RECIBIO estas unidades ya las uso. Si el
  --     destino es 'Completado' no hay proceso siguiente y no aplica.
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
  values ('production_movements', v_registro.id, to_jsonb(v_registro), p_perfil_id, trim(p_motivo));

  delete from public.production_movements where id = p_movimiento_id;
end;
$$;

-- Interna: nadie la ejecuta directamente (los RPC la llaman como duenos).
revoke all on function public.fn_eliminar_movimiento_validado(uuid, uuid, text) from public, anon, authenticated;

comment on function public.fn_eliminar_movimiento_validado(uuid, uuid, text) is
  'INTERNA (060). Valida y elimina UN movimiento: autor, motivo, R5 (Empaque: empacado - registro >= despachado), R1 (registro posterior del mismo proceso en la talla), R2 (el proceso que recibio ya las uso). Deja snapshot en log_eliminaciones. La llaman eliminar_movimiento_con_motivo y eliminar_movimientos_con_motivo.';

-- ---------------------------------------------------------------------
-- C. RPC de UN registro: misma firma de siempre (el frontend no cambia
--    esta llamada).
-- ---------------------------------------------------------------------
create or replace function public.eliminar_movimiento_con_motivo(p_movimiento_id uuid, p_motivo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
begin
  select id into v_perfil_id from public.profiles where auth_id = auth.uid();
  if v_perfil_id is null then
    raise exception 'Usuario no valido.';
  end if;

  perform public.fn_eliminar_movimiento_validado(p_movimiento_id, v_perfil_id, p_motivo);
end;
$$;

grant execute on function public.eliminar_movimiento_con_motivo(uuid, text) to authenticated;

comment on function public.eliminar_movimiento_con_motivo(uuid, text) is
  'Elimina UN movimiento con motivo obligatorio (060: envoltorio de fn_eliminar_movimiento_validado). Reglas por talla/unidades: R5 (Empaque no puede quedar con menos empacado que despachado), R1 (registro posterior del mismo proceso) y R2 (el proceso que recibio ya las uso). Antes de 060 bloqueaba cualquier talla con algun despacho (046).';

-- ---------------------------------------------------------------------
-- D. RPC de VARIOS registros, TODOS O NINGUNO (una sola transaccion).
-- ---------------------------------------------------------------------
create or replace function public.eliminar_movimientos_con_motivo(p_ids uuid[], p_motivo text)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_id uuid;
  v_borrados integer := 0;
  v_pedidos text[];
begin
  select id into v_perfil_id from public.profiles where auth_id = auth.uid();
  if v_perfil_id is null then
    raise exception 'Usuario no valido.';
  end if;

  if p_ids is null or coalesce(cardinality(p_ids), 0) = 0 then
    raise exception 'Selecciona al menos un registro para eliminar.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar los registros.';
  end if;

  -- Bloqueos por pedido en orden alfabetico (igual que crear_despacho):
  -- evita interbloqueos entre dos operaciones que tocan varios pedidos.
  select array_agg(distinct m.order_number::text order by m.order_number::text)
    into v_pedidos
    from public.production_movements m
   where m.id = any(p_ids);

  if v_pedidos is not null then
    perform pg_advisory_xact_lock(hashtext(p))
      from unnest(v_pedidos) as p;
  end if;

  -- Del MAS RECIENTE al mas antiguo: los registros posteriores primero,
  -- que es el orden en que R1/R2/R5 permiten borrar una cadena (por
  -- ejemplo, primero el de Mateado y despues el de Refilado).
  for v_id in
    select m.id
      from public.production_movements m
     where m.id = any(p_ids)
     order by m.created_at desc, m.id desc
  loop
    perform public.fn_eliminar_movimiento_validado(v_id, v_perfil_id, p_motivo);
    v_borrados := v_borrados + 1;
  end loop;

  -- Algun id no existia o ya habia sido eliminado: se deshace TODO.
  if v_borrados <> (select count(distinct x) from unnest(p_ids) as x) then
    raise exception 'Alguno de los registros seleccionados ya no existe. No se elimino ninguno.';
  end if;

  return v_borrados;
end;
$$;

grant execute on function public.eliminar_movimientos_con_motivo(uuid[], text) to authenticated;

comment on function public.eliminar_movimientos_con_motivo(uuid[], text) is
  'Elimina VARIOS movimientos propios en UNA sola transaccion: todos o ninguno (060). Los procesa del mas reciente al mas antiguo; si cualquiera incumple una regla, no se elimina ninguno y el error indica cual. Devuelve cuantos eliminó.';

-- ---------------------------------------------------------------------
-- E. Candado de ULTIMO RECURSO (R5), venga de donde venga el DELETE.
-- ---------------------------------------------------------------------
create or replace function public.fn_validar_saldo_empaque_al_borrar()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_empacado numeric;
  v_despachado numeric;
begin
  if old.from_process = 'Empaque' then
    select coalesce(sum(m.quantity), 0) into v_empacado
      from public.production_movements m
     where m.item_id = old.item_id and m.from_process = 'Empaque';

    select coalesce(sum(doi.cantidad), 0) into v_despachado
      from public.despacho_orden_items doi
     where doi.item_id = old.item_id;

    if v_empacado - old.quantity < v_despachado then
      raise exception 'No se puede eliminar: la talla % del pedido % quedaria con menos unidades empacadas (%) que despachadas (%).',
        old.size, old.order_number, v_empacado - old.quantity, v_despachado;
    end if;
  end if;

  return old;
end;
$$;

drop trigger if exists trg_validar_saldo_empaque_al_borrar on public.production_movements;
create trigger trg_validar_saldo_empaque_al_borrar
  before delete on public.production_movements
  for each row
  execute function public.fn_validar_saldo_empaque_al_borrar();

comment on function public.fn_validar_saldo_empaque_al_borrar() is
  'Candado de ultimo recurso (060): borrar un registro de Empaque nunca puede dejar la talla con menos unidades empacadas que despachadas. Misma garantia que fn_validar_saldo_despacho_item (051) pero del lado del borrado.';

commit;

-- =====================================================================
-- PRUEBAS sugeridas (solo lectura) despues de ejecutar, pedido 3186:
--
--   -- Para la talla 35 el registro de Mateado de 86 debe quedar libre
--   -- (tiene_movimiento_posterior = false, bloqueado_por_despacho = false)
--   -- y los registros de Empaque (40 y 44) deben salir bloqueados
--   -- (bloqueado_por_despacho = true):
--   select created_at at time zone 'America/Bogota' as fecha, from_process, to_process,
--          size, quantity, tiene_movimiento_posterior, bloqueado_por_despacho
--     from public.vw_historial
--    where order_number = '3186' and tipo = 'movimiento' and size::text = '35'
--    order by created_at;
-- =====================================================================
