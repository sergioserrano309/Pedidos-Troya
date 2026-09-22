-- =====================================================================
-- 053_despacho_revisado.sql
-- Visto bueno del Validador sobre un despacho ya realizado.
--
-- Regla pedida por el usuario:
--   - SOLO el validador puede prender y apagar el visto bueno.
--   - Con el visto bueno prendido, Empaque NO puede eliminar ese
--     despacho.
--   - Si el validador lo apaga, Empaque vuelve a poder eliminarlo.
--   - El validador nunca queda bloqueado (si lo estuviera, le bastaria
--     apagar su propio visto bueno para saltarselo).
--
-- El candado vive en la BASE, no en la pantalla: esconder el boton solo
-- oculta la accion, no la impide. Cualquiera con la sesion abierta puede
-- invocar el RPC de borrado por su cuenta, asi que la regla tiene que
-- estar donde nadie la pueda rodear. Misma decision que en 041 con el
-- bloqueo de borrado de movimientos despachados.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Columnas. Se guarda quien y cuando, no solo el booleano: un visto
--    bueno sin autor no sirve para auditar despues.
-- ---------------------------------------------------------------------
alter table public.despachos
  add column if not exists revisado boolean not null default false;

alter table public.despachos
  add column if not exists revisado_por uuid references public.profiles(id);

alter table public.despachos
  add column if not exists revisado_at timestamptz;

comment on column public.despachos.revisado is
  'Visto bueno del Validador. Mientras este en true, Empaque no puede eliminar el despacho (ver trg_bloquear_borrado_despacho_revisado).';

-- ---------------------------------------------------------------------
-- 2. RPC para prender/apagar. Es la UNICA via de escritura: las RLS de
--    029 no dan update sobre despachos a nadie, y esto no las abre.
-- ---------------------------------------------------------------------
create or replace function public.marcar_despacho_revisado(
  p_despacho_id uuid,
  p_revisado boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_valor boolean := coalesce(p_revisado, false);
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol <> 'validador' then
    raise exception 'Solo el Validador puede marcar un despacho como revisado.';
  end if;

  -- despachos.id calificado a proposito: sin el, "id" es ambiguo entre
  -- la columna y una variable, que fue justo el error de 038.
  update public.despachos
     set revisado     = v_valor,
         revisado_por = case when v_valor then v_perfil_id else null end,
         revisado_at  = case when v_valor then now() else null end
   where despachos.id = p_despacho_id;

  if not found then
    raise exception 'El despacho no existe o ya fue eliminado.';
  end if;
end;
$$;

grant execute on function public.marcar_despacho_revisado(uuid, boolean) to authenticated;

-- ---------------------------------------------------------------------
-- 3. El candado, como trigger y no dentro de eliminar_despacho_con_motivo.
--
--    Asi cubre CUALQUIER via de borrado, no solo ese RPC, y no hay que
--    reescribir una funcion de 60 lineas (039) para meterle un if — que
--    ademas obligaria a mantener dos copias de la misma logica el dia que
--    cambie el snapshot.
-- ---------------------------------------------------------------------
create or replace function public.fn_bloquear_borrado_despacho_revisado()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_rol text;
begin
  if old.revisado then
    select lower(pr.role) into v_rol
      from public.profiles pr where pr.auth_id = auth.uid();

    if coalesce(v_rol, '') <> 'validador' then
      raise exception 'El despacho % tiene el visto bueno del Validador. Pidele que lo quite antes de eliminarlo.', old.consecutivo;
    end if;
  end if;

  return old;
end;
$$;

drop trigger if exists trg_bloquear_borrado_despacho_revisado on public.despachos;

create trigger trg_bloquear_borrado_despacho_revisado
  before delete on public.despachos
  for each row
  execute function public.fn_bloquear_borrado_despacho_revisado();

-- ---------------------------------------------------------------------
-- 4. La vista del listado "Despachado" expone el estado.
--    Las columnas nuevas van AL FINAL: create or replace view solo deja
--    agregar, nunca reordenar ni renombrar.
-- ---------------------------------------------------------------------
create or replace view public.vw_despachos_registro
with (security_invoker = true) as
with ordenes as (
  select do2.despacho_id,
         count(*)                                              as numero_ordenes,
         array_agg(do2.order_number order by do2.order_number)  as order_numbers,
         count(*) filter (where e.pedido_completo)              as pedidos_completos
    from public.despacho_ordenes do2
    left join public.vw_pedido_despacho_estado e on e.order_number = do2.order_number
   group by do2.despacho_id
),
bultos as (
  select db.despacho_id, sum(db.peso) as peso_total
    from public.despacho_bultos db
   group by db.despacho_id
),
unidades as (
  select doi.despacho_id, sum(doi.cantidad) as total_unidades
    from public.despacho_orden_items doi
   group by doi.despacho_id
)
select d.id,
       d.numero_despacho,
       d.consecutivo,
       d.created_at,
       d.created_by,
       pr.name                                       as creado_por_nombre,
       d.total_bultos,
       coalesce(b.peso_total, 0)                     as peso_total,
       coalesce(o.numero_ordenes, 0)                 as numero_ordenes,
       coalesce(o.order_numbers, array[]::text[])    as order_numbers,
       coalesce(u.total_unidades, 0)                 as total_unidades,
       coalesce(o.pedidos_completos, 0)              as pedidos_completos,
       d.asignacion_confirmada,
       d.confirmed_at,
       d.revisado,
       d.revisado_at,
       rv.name                                       as revisado_por_nombre
  from public.despachos d
  left join public.profiles pr on pr.id = d.created_by
  left join public.profiles rv on rv.id = d.revisado_por
  left join ordenes  o on o.despacho_id = d.id
  left join bultos   b on b.despacho_id = d.id
  left join unidades u on u.despacho_id = d.id;

grant select on public.vw_despachos_registro to authenticated;

comment on view public.vw_despachos_registro is
  'Una fila por despacho. total_unidades = lo realmente despachado (despacho_orden_items), no el total del pedido. pedidos_completos alimenta el contador "N de M completos". revisado es el visto bueno del Validador (053).';
