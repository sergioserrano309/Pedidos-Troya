-- =====================================================================
-- 013_auto_enrutamiento_trigger.sql
-- Enrutamiento 100% automático: cuando un pedido nuevo llega a
-- p_pedidosh (sincronizado desde el ERP) y cumple una regla de
-- reglas_enrutamiento, el SISTEMA crea de inmediato el movimiento
-- Refilado -> destino para cada talla, sin que ningún usuario Refilado
-- tenga que abrir ni ver ese pedido.
--
-- Estos movimientos quedan marcados con es_automatico = true, para:
--   1. Excluirse del "Procesado" que ve Refilado (no fue trabajo suyo).
--   2. Que el pedido NO aparezca en el listado de Refilado (ver cambio
--      en ordersService.js / vw_pedido_progreso).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Columnas nuevas
-- ---------------------------------------------------------------------

alter table public.production_movements
  alter column user_id drop not null;

alter table public.production_movements
  add column if not exists es_automatico boolean not null default false;

alter table public.order_destino
  alter column confirmed_by drop not null;

alter table public.order_destino
  add column if not exists es_automatico boolean not null default false;

-- ---------------------------------------------------------------------
-- 2. Función compartida: aplica la regla (si hay alguna) a UNA fila de
--    p_pedidosh. La usan tanto el trigger (pedidos nuevos) como el
--    backfill (pedidos que ya existían antes de crear esta migración).
-- ---------------------------------------------------------------------

create or replace function public.aplicar_regla_enrutamiento(p_fila public.p_pedidosh)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_regla record;
  v_cantidad integer;
begin
  if coalesce(p_fila."Cancelado", false) then
    return;
  end if;

  v_cantidad := coalesce(p_fila."CantidadP", 0);
  if v_cantidad <= 0 then
    return;
  end if;

  -- Regla más específica (más criterios definidos) gana si hay varias
  -- coincidencias.
  select r.*
  into v_regla
  from public.reglas_enrutamiento r
  where (r.nombre_referencia is null or r.nombre_referencia = p_fila."NombreR")
    and (r.material is null or r.material = p_fila."MaterialP")
    and (r.color is null or r.color = p_fila."ColorP")
  order by
    (case when r.nombre_referencia is not null then 1 else 0 end
     + case when r.material is not null then 1 else 0 end
     + case when r.color is not null then 1 else 0 end) desc,
    r.created_at asc
  limit 1;

  if v_regla.id is null then
    return;
  end if;

  -- item_id ya viene resuelto en p_fila (columna generada+almacenada,
  -- ver supabase/sql/016_item_id_materializado.sql): no hace falta
  -- recalcularlo con generar_item_id().
  insert into public.production_movements (
    item_id, order_number, reference, size, quantity,
    from_process, to_process, user_id, observation, es_automatico
  ) values (
    p_fila.item_id,
    p_fila."PedidoNo"::text,
    p_fila."NombreR",
    p_fila."Talla"::text,
    v_cantidad,
    'Refilado',
    v_regla.destino,
    null,
    'Enrutamiento automático por regla de enrutamiento',
    true
  );

  insert into public.order_destino (order_number, destino, confirmed_by, es_automatico)
  values (p_fila."PedidoNo"::text, v_regla.destino, null, true)
  on conflict (order_number) do nothing;
end;
$$;

-- ---------------------------------------------------------------------
-- 3. Trigger: pedidos NUEVOS que lleguen de aquí en adelante.
-- ---------------------------------------------------------------------

create or replace function public.fn_auto_enrutar_pedido()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.aplicar_regla_enrutamiento(NEW);
  return NEW;
end;
$$;

drop trigger if exists trg_auto_enrutar_pedido on public.p_pedidosh;
create trigger trg_auto_enrutar_pedido
after insert on public.p_pedidosh
for each row
execute function public.fn_auto_enrutar_pedido();

-- ---------------------------------------------------------------------
-- 4. Backfill: aplica las reglas a pedidos que YA EXISTÍAN antes de esta
--    migración y que todavía no tienen ningún movimiento (para no
--    interferir con pedidos que un humano ya empezó a procesar).
--    Ejecutar UNA VEZ, después de crear tus reglas en el módulo
--    "Reglas de Enrutamiento": select public.backfill_auto_enrutamiento();
-- ---------------------------------------------------------------------

create or replace function public.backfill_auto_enrutamiento()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_fila public.p_pedidosh;
  v_contador integer := 0;
begin
  for v_fila in
    select p.*
    from public.p_pedidosh p
    where not exists (
      select 1 from public.production_movements m
      where m.item_id = p.item_id
    )
  loop
    perform public.aplicar_regla_enrutamiento(v_fila);
    v_contador := v_contador + 1;
  end loop;

  return v_contador;
end;
$$;

grant execute on function public.backfill_auto_enrutamiento() to authenticated;
