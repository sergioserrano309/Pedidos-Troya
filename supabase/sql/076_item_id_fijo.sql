-- =====================================================================
-- 076_item_id_fijo.sql
-- PASO 3 de 3 de la Etapa 1 de la Fase 5: CONGELAR el codigo interno
-- (item_id) de cada linea de p_pedidosh.
--
-- ORDEN: 1) 076a_respaldo_p_pedidosh.sql  2) la PRUEBA SEGURA (al final de
-- este archivo, se cancela sola)  3) este archivo.
--
-- POR QUE
--   item_id es hoy una columna GENERADA: se recalcula siempre a partir de
--   pedido + referencia + talla + material + color. Si Access corrige el
--   color o el material y se actualiza la linea, el codigo cambiaria solo y
--   la linea perderia su historial (registros de produccion, devoluciones,
--   despachos), que cuelga de ese codigo. Para poder aplicar esos cambios
--   (Fase 5) el codigo debe quedar FIJO.
--
-- QUE HACE
--   1. DROP EXPRESSION: la columna item_id pasa de "generada" a normal. Se
--      CONSERVAN todos sus valores actuales (no se recalcula nada, no se
--      reescribe la tabla).
--   2. Un disparador BEFORE INSERT calcula el codigo cuando se inserta una
--      linea nueva (el sincronizador de la oficina sigue funcionando igual,
--      sin enviar item_id), con la MISMA funcion generar_item_id de siempre.
--   3. item_id queda NOT NULL.
--   4. VERIFICA que el codigo de TODAS las lineas sigue siendo exactamente
--      el que daria la formula de siempre. Si una sola difiere, se deshace
--      todo (esta dentro de una transaccion).
--
-- QUE NO CAMBIA
--   Ningun dato, ninguna vista, ninguna pantalla, ningun calculo. Los
--   codigos son los mismos que antes. Lo unico distinto: de aqui en adelante
--   un cambio de material/color/referencia NO cambia el codigo de la linea.
--
-- CUANDO EJECUTARLO
--   Toma un candado breve sobre p_pedidosh (segundos). Hagalo en un minuto en
--   que no corran las tareas de la oficina: las de pedidos corren en :00 y
--   :05, Inyectado en :02 y :07, Cambios ERP en :04 y :09 -> use :03 u :08.
--   Si la tabla esta ocupada y no se libera en 20 s, se cancela sola y puede
--   repetirlo.
--
-- REVERSA: ver 076_revertir_item_id_fijo.sql (la forma segura es el respaldo).
-- =====================================================================

begin;

set local lock_timeout = '20s';
lock table public.p_pedidosh in access exclusive mode;

-- 0. Comprobaciones previas
do $$
declare
  v_gen "char";
  v_nulos bigint;
begin
  select a.attgenerated into v_gen
    from pg_attribute a
   where a.attrelid = 'public.p_pedidosh'::regclass and a.attname = 'item_id' and not a.attisdropped;
  if not found then
    raise exception 'p_pedidosh no tiene la columna item_id.';
  end if;

  if v_gen = 's' then
    select count(*) into v_nulos from public.p_pedidosh where item_id is null;
    if v_nulos > 0 then
      raise exception '% lineas tienen item_id vacio; no se congela.', v_nulos;
    end if;
  end if;

  if to_regclass('public.p_pedidosh_respaldo_076') is null then
    raise exception 'Falta la copia de respaldo (076a_respaldo_p_pedidosh.sql). Ejecutela primero.';
  end if;
end $$;

-- 1. La columna deja de ser generada; conserva sus valores.
alter table public.p_pedidosh alter column item_id drop expression if exists;

-- 2. Las lineas nuevas reciben su codigo con la formula de siempre.
create or replace function public.fn_item_id_al_insertar()
returns trigger
language plpgsql
set search_path = public
as $f$
begin
  if new.item_id is null then
    new.item_id := public.generar_item_id(
      new."PedidoNo"::text, new."Referencia", new."Talla"::text, new."MaterialP", new."ColorP");
  end if;
  return new;
end;
$f$;

comment on function public.fn_item_id_al_insertar() is
  'Calcula item_id al insertar una linea de p_pedidosh (076). Despues de insertada el codigo queda fijo aunque cambien referencia, material o color.';

revoke all on function public.fn_item_id_al_insertar() from public, anon, authenticated;

drop trigger if exists trg_item_id_al_insertar on public.p_pedidosh;
create trigger trg_item_id_al_insertar
  before insert on public.p_pedidosh
  for each row
  execute function public.fn_item_id_al_insertar();

-- 3. Nunca vacio.
alter table public.p_pedidosh alter column item_id set not null;

-- 4. Verificacion: el codigo de TODAS las lineas es el de la formula de siempre.
do $$
declare
  v_dif bigint;
begin
  select count(*) into v_dif
    from public.p_pedidosh p
   where p.item_id is distinct from public.generar_item_id(
           p."PedidoNo"::text, p."Referencia", p."Talla"::text, p."MaterialP", p."ColorP");
  if v_dif <> 0 then
    raise exception '% lineas tienen un codigo distinto al de la formula; se deshace todo.', v_dif;
  end if;
end $$;

commit;

-- =====================================================================
-- PRUEBA SEGURA (ejecutar ANTES de este archivo, DESPUES de la copia de
-- respaldo). Hace TODO esto dentro de una transaccion que se cancela sola
-- (termina en un "error" a proposito): no queda NINGUN cambio.
-- Compara las vistas de avance antes y despues de congelar, comprueba que
-- una linea nueva recibe su codigo y que cambiar el color de una linea con
-- registros ya NO le cambia el codigo ni le quita su historial.
--
--   do $$
--   declare
--     c_pedidos constant text[] := array['3818','3808','3130','3333','3302','3100','3391','3672'];
--     v_gen_antes text; v_gen_despues text;
--     v_filas_antes bigint; v_filas_despues bigint; v_cod_antes text; v_cod_despues text;
--     v_prog_antes text; v_prog_despues text; v_it_antes text; v_it_despues text;
--     v_dif bigint; v_nuevo text; v_esperado text;
--     v_item text; v_item_despues text; v_proc_antes numeric; v_proc_despues numeric; v_lineas_antes bigint; v_lineas_despues bigint;
--   begin
--     select a.attgenerated::text into v_gen_antes from pg_attribute a
--      where a.attrelid = 'public.p_pedidosh'::regclass and a.attname = 'item_id' and not a.attisdropped;
--     select count(*), md5(string_agg(x, ',' order by x)) into v_filas_antes, v_cod_antes
--       from (select concat_ws(':', p."PedidoNo"::text, p."Talla"::text, p.item_id) as x from public.p_pedidosh p) s;
--     select md5(string_agg(x, ',' order by x)) into v_prog_antes
--       from (select concat_ws(':', pp.order_number::text, pp.total_solicitado::text, pp.total_procesado::text, pp.porcentaje_completado::text, pp.etapa_actual) as x
--               from public.vw_pedido_progreso pp where pp.order_number::text = any (c_pedidos)) s;
--     select md5(string_agg(x, ',' order by x)) into v_it_antes
--       from (select concat_ws(':', ip.item_id, ip.cantidad_solicitada::text, ip.cantidad_procesada::text, ip.cantidad_pendiente::text) as x
--               from public.vw_item_progreso ip where ip.order_number::text = any (c_pedidos)) s;
--
--     alter table public.p_pedidosh alter column item_id drop expression if exists;
--     create or replace function public.fn_item_id_al_insertar() returns trigger language plpgsql set search_path = public as $f$
--     begin
--       if new.item_id is null then
--         new.item_id := public.generar_item_id(new."PedidoNo"::text, new."Referencia", new."Talla"::text, new."MaterialP", new."ColorP");
--       end if;
--       return new;
--     end; $f$;
--     drop trigger if exists trg_item_id_al_insertar on public.p_pedidosh;
--     create trigger trg_item_id_al_insertar before insert on public.p_pedidosh for each row execute function public.fn_item_id_al_insertar();
--     alter table public.p_pedidosh alter column item_id set not null;
--
--     select a.attgenerated::text into v_gen_despues from pg_attribute a
--      where a.attrelid = 'public.p_pedidosh'::regclass and a.attname = 'item_id' and not a.attisdropped;
--     select count(*), md5(string_agg(x, ',' order by x)) into v_filas_despues, v_cod_despues
--       from (select concat_ws(':', p."PedidoNo"::text, p."Talla"::text, p.item_id) as x from public.p_pedidosh p) s;
--     select md5(string_agg(x, ',' order by x)) into v_prog_despues
--       from (select concat_ws(':', pp.order_number::text, pp.total_solicitado::text, pp.total_procesado::text, pp.porcentaje_completado::text, pp.etapa_actual) as x
--               from public.vw_pedido_progreso pp where pp.order_number::text = any (c_pedidos)) s;
--     select md5(string_agg(x, ',' order by x)) into v_it_despues
--       from (select concat_ws(':', ip.item_id, ip.cantidad_solicitada::text, ip.cantidad_procesada::text, ip.cantidad_pendiente::text) as x
--               from public.vw_item_progreso ip where ip.order_number::text = any (c_pedidos)) s;
--     select count(*) into v_dif from public.p_pedidosh p
--      where p.item_id is distinct from public.generar_item_id(p."PedidoNo"::text, p."Referencia", p."Talla"::text, p."MaterialP", p."ColorP");
--
--     -- linea nueva: recibe su codigo por el disparador
--     insert into public.p_pedidosh ("PedidoNo", "Referencia", "Talla", "MaterialP", "ColorP", "CantidadP")
--     values (9999991, 'PRUEBA REF', '99', 'MAT PRUEBA', 'COLOR PRUEBA', 1) returning item_id into v_nuevo;
--     v_esperado := public.generar_item_id('9999991', 'PRUEBA REF', '99', 'MAT PRUEBA', 'COLOR PRUEBA');
--
--     -- cambiar el color de una linea CON registros (pedido 3302): el codigo ya no cambia
--     select m.item_id into v_item from public.production_movements m where m.order_number::text = '3302' limit 1;
--     select ip.cantidad_procesada into v_proc_antes from public.vw_item_progreso ip where ip.item_id = v_item limit 1;
--     select count(*) into v_lineas_antes from public.vw_item_progreso ip where ip.item_id = v_item;
--     update public.p_pedidosh set "ColorP" = 'COLOR DE PRUEBA' where item_id = v_item;
--     select p.item_id into v_item_despues from public.p_pedidosh p where p."ColorP" = 'COLOR DE PRUEBA' and p."PedidoNo"::text = '3302' limit 1;
--     select ip.cantidad_procesada into v_proc_despues from public.vw_item_progreso ip where ip.item_id = v_item limit 1;
--     select count(*) into v_lineas_despues from public.vw_item_progreso ip where ip.item_id = v_item;
--
--     raise exception E'PRUEBA CODIGO FIJO (se deshizo todo):\n1) columna generada antes=[%] despues=[%]  (s = generada, vacio = normal)\n2) filas % -> % | huella de codigos igual=%\n3) vista de pedidos igual=% | vista de lineas igual=%\n4) lineas con codigo distinto al de la formula=%\n5) linea nueva: codigo=% esperado=% igual=%\n6) cambio de color en 3302 (con registros): codigo igual=% | procesado % -> % igual=% | lineas % -> %',
--       v_gen_antes, v_gen_despues,
--       v_filas_antes, v_filas_despues, v_cod_antes = v_cod_despues,
--       v_prog_antes = v_prog_despues, v_it_antes = v_it_despues,
--       v_dif,
--       v_nuevo, v_esperado, v_nuevo = v_esperado,
--       v_item = v_item_despues, v_proc_antes, v_proc_despues, v_proc_antes = v_proc_despues, v_lineas_antes, v_lineas_despues;
--   end $$;
-- =====================================================================
