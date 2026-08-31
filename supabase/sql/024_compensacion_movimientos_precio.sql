-- =====================================================================
-- 024_compensacion_movimientos_precio.sql
-- Cada movimiento de produccion (production_movements) se valora UNA
-- SOLA VEZ, en el momento en que se crea: precio_cop/valor_cop quedan
-- CONGELADOS con el precio vigente en ese instante (segun rol +
-- reglas_precios/precios_por_par). Si el precio cambia despues, los
-- registros ya hechos NO se recalculan — asi cada tanda de trabajo
-- queda valorada al precio que tenia cuando se proceso, sin necesidad
-- de tablas de precios versionadas por rango de fechas.
--
-- Se implementa con un trigger BEFORE INSERT (no una vista que calcule
-- en vivo): mas simple, mas robusto, y evita que borrar/editar una
-- regla de precio despues afecte retroactivamente el valor de trabajo
-- ya realizado.
--
-- Movimientos automaticos (es_automatico=true, ver
-- 013_auto_enrutamiento_trigger.sql) NUNCA se valoran: no hay operario
-- al que pagarle una accion del sistema. precio_cop/valor_cop quedan
-- null para esas filas.
-- =====================================================================

alter table public.production_movements
  add column if not exists precio_cop numeric(12,2),
  add column if not exists valor_cop numeric(14,2);

-- ---------------------------------------------------------------------
-- fn_precio_aplicable: mismo patron de matching por especificidad que
-- aplicar_regla_enrutamiento (013) — reglas_precios gana sobre
-- precios_por_par si hay coincidencia, la regla mas especifica gana
-- entre varias. security definer + sin grant execute a authenticated:
-- solo alcanzable indirectamente via el trigger de abajo (que tambien
-- es security definer), nunca por llamada directa de un usuario normal
-- que no tiene permiso RLS sobre precios_por_par/reglas_precios.
-- ---------------------------------------------------------------------
create or replace function public.fn_precio_aplicable(
  p_rol text,
  p_nombre_referencia text,
  p_material text,
  p_color text,
  p_destino text
) returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select r.precio
      from public.reglas_precios r
      where r.tipo_usuario = p_rol
        and (r.nombre_referencia is null or r.nombre_referencia = p_nombre_referencia)
        and (r.material is null or r.material = p_material)
        and (r.color is null or r.color = p_color)
        and (r.destino is null or r.destino = p_destino)
      order by
        (case when r.nombre_referencia is not null then 1 else 0 end
         + case when r.material is not null then 1 else 0 end
         + case when r.color is not null then 1 else 0 end
         + case when r.destino is not null then 1 else 0 end) desc,
        r.created_at asc
      limit 1
    ),
    (select pp.precio from public.precios_por_par pp where pp.rol = p_rol)
  );
$$;

-- ---------------------------------------------------------------------
-- Trigger: resuelve item (Nombre Suela/Material/Color desde p_pedidosh)
-- y destino (order_destino.destino, mismo campo que usa reglas_precios,
-- puede ser null si Refilado aun no ha confirmado destino de esa orden)
-- para congelar precio_cop/valor_cop en la fila que se esta insertando.
-- security definer: un Refilado/Acabado/Mateado/Empaque normal no tiene
-- permiso RLS para leer precios_por_par/reglas_precios directamente,
-- pero el trigger corre con privilegio del dueño (igual que
-- fn_auto_enrutar_pedido en 013), asi el precio se resuelve sin
-- importar quien este insertando el movimiento.
-- ---------------------------------------------------------------------
create or replace function public.fn_congelar_precio_movimiento()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.p_pedidosh;
  v_destino text;
begin
  if new.es_automatico then
    new.precio_cop := null;
    new.valor_cop := null;
    return new;
  end if;

  select * into v_item
  from public.p_pedidosh
  where item_id = new.item_id
  limit 1;

  select destino into v_destino
  from public.order_destino
  where order_number = new.order_number;

  new.precio_cop := public.fn_precio_aplicable(
    lower(new.from_process),
    v_item."NombreR",
    v_item."MaterialP",
    v_item."ColorP",
    v_destino
  );
  new.valor_cop := new.quantity * new.precio_cop;

  return new;
end;
$$;

drop trigger if exists trg_congelar_precio_movimiento on public.production_movements;
create trigger trg_congelar_precio_movimiento
before insert on public.production_movements
for each row
execute function public.fn_congelar_precio_movimiento();

comment on column public.production_movements.precio_cop is
  'Precio COP por par vigente en el momento de este movimiento, ya congelado (trigger trg_congelar_precio_movimiento). Null si es_automatico=true.';
comment on column public.production_movements.valor_cop is
  'quantity * precio_cop, congelado. Null si es_automatico=true.';
