-- =====================================================================
-- 016_item_id_materializado.sql
-- CAUSA RAÍZ del rendimiento: item_id se recalculaba con generar_item_id()
-- (SHA-256 + un ciclo de 64 pasos en PL/pgSQL) en CADA fila, CADA vez que
-- se consultaba vw_pedido_progreso — más de 25.000 veces por consulta
-- (confirmado con EXPLAIN ANALYZE: ese cálculo repetido explicaba
-- prácticamente los 5.5 segundos completos de la consulta).
--
-- Esta migración guarda item_id como una columna REAL en p_pedidosh
-- (calculada una sola vez, automáticamente, por fila) y la indexa. De
-- aquí en adelante, las uniones (joins) usan ese valor ya guardado en
-- vez de recalcularlo.
--
-- Es segura: no borra ni cambia ningún dato existente, solo agrega una
-- columna calculada y un índice. Con ~16.500 filas, el cálculo inicial
-- (una sola vez, al correr esta migración) toma unos segundos; después
-- de eso, nunca se vuelve a calcular para esas filas.
-- =====================================================================

alter table public.p_pedidosh
  add column if not exists item_id text
  generated always as (
    public.generar_item_id("PedidoNo"::text, "Referencia", "Talla"::text, "MaterialP", "ColorP")
  ) stored;

create index if not exists idx_pedidosh_item_id on public.p_pedidosh (item_id);

-- vw_pedidos_con_id ya no necesita calcular nada: item_id ya viene
-- incluido en pp.* como columna real.
create or replace view public.vw_pedidos_con_id
with (security_invoker = true) as
select pp.*
from public.p_pedidosh pp;

-- El disparador de enrutamiento automático tampoco necesita recalcularlo:
-- NEW.item_id ya viene resuelto por Postgres antes de que el trigger
-- se ejecute (es una columna generada de la misma fila).
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

-- El backfill también dejaba de usar el item_id ya calculado; lo mismo
-- aplicaba aquí en el WHERE NOT EXISTS.
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
