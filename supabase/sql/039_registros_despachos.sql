-- =====================================================================
-- 039_registros_despachos.sql
-- Pestaña "RegistrosD" (Registros de Despachos): vista de consulta con
-- los agregados por despacho + RPC para eliminar un despacho COMPLETO
-- con motivo obligatorio.
--
-- Decisiones:
--   - Vista NUEVA (no se amplía vw_despachos_resumen): "create or replace
--     view" solo permite AGREGAR columnas al final, nunca reordenar ni
--     quitar — misma restricción documentada en 026. vw_despachos_resumen
--     sigue alimentando el acordeón "Despachado" sin cambios.
--   - El borrado es TODO-O-NADA por despacho: no existe eliminación
--     parcial de órdenes dentro de un despacho (lo pidió el usuario).
--     Las 3 tablas hijas caen por "on delete cascade" (ver 027).
--   - Se reutiliza log_eliminaciones (014) en vez de crear una tabla
--     nueva: su columna tabla_origen fue diseñada justo para esto.
--   - Al borrar el despacho, sus órdenes vuelven solas a "A Despachar",
--     porque vw_pedidos_por_despachar usa "not exists" sobre
--     despacho_ordenes (028).
-- =====================================================================

-- ---------------------------------------------------------------------
-- Revertir la política UPDATE que agregó 038.
--
-- 038 la creó como defensa por si el UPDATE de crear_despacho fallaba
-- por RLS. Ya quedó demostrado que la causa real era la referencia
-- ambigua a "id"/"asignacion_confirmada" (al calificarlas, funciona),
-- así que esta política sobra — y mientras exista, un usuario Empaque
-- podría marcar asignacion_confirmada por API saltándose el RPC.
-- Se restaura la postura original de 029: el cliente NUNCA escribe
-- directamente en despachos, solo a través de funciones security definer.
-- ---------------------------------------------------------------------
drop policy if exists "despachos_update_own_empaque_validador" on public.despachos;
revoke update on public.despachos from authenticated, anon;

-- ---------------------------------------------------------------------
-- vw_despachos_registro — una fila por despacho, con todo lo que la
-- pestaña necesita mostrar sin consultas adicionales.
-- ---------------------------------------------------------------------
drop view if exists public.vw_despachos_registro;

create view public.vw_despachos_registro
with (security_invoker = true) as
with ordenes as (
  select do2.despacho_id,
         count(*)                                                  as numero_ordenes,
         array_agg(do2.order_number order by do2.order_number)     as order_numbers
    from public.despacho_ordenes do2
   group by do2.despacho_id
),
bultos as (
  select db.despacho_id,
         sum(db.peso) as peso_total
    from public.despacho_bultos db
   group by db.despacho_id
),
unidades as (
  -- "PedidoNo" es bigint en la base (009 lo declara text — drift
  -- repo/BD). Se castea a text igual que 013:83 y 016:79, que es el
  -- patrón ya establecido en el proyecto para este mismo join.
  select do2.despacho_id,
         sum(coalesce(ph."CantidadP", 0)) as total_unidades
    from public.despacho_ordenes do2
    join public.p_pedidosh ph on ph."PedidoNo"::text = do2.order_number
   where ph."Cancelado" is null or ph."Cancelado" = false
   group by do2.despacho_id
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
       d.asignacion_confirmada,
       d.confirmed_at
  from public.despachos d
  left join public.profiles pr on pr.id = d.created_by
  left join ordenes  o on o.despacho_id = d.id
  left join bultos   b on b.despacho_id = d.id
  left join unidades u on u.despacho_id = d.id;

grant select on public.vw_despachos_registro to authenticated;

comment on view public.vw_despachos_registro is
  'Una fila por despacho con agregados (bultos, kilos, unidades, órdenes) para la pestaña RegistrosD.';

-- ---------------------------------------------------------------------
-- eliminar_despacho_con_motivo — análoga a eliminar_movimiento_con_motivo
-- (014): valida, guarda snapshot completo en log_eliminaciones y borra.
-- ---------------------------------------------------------------------
create or replace function public.eliminar_despacho_con_motivo(
  p_despacho_id uuid,
  p_motivo text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_perfil_id uuid;
  v_rol text;
  v_snapshot jsonb;
begin
  select pr.id, lower(pr.role) into v_perfil_id, v_rol
    from public.profiles pr where pr.auth_id = auth.uid();

  if v_perfil_id is null or v_rol not in ('empaque', 'validador') then
    raise exception 'No tienes permiso para eliminar despachos.';
  end if;

  if p_motivo is null or trim(p_motivo) = '' then
    raise exception 'Debes indicar un motivo para eliminar este despacho.';
  end if;

  -- Snapshot completo ANTES de borrar: el despacho y sus 3 tablas hijas,
  -- para que la eliminación sea reconstruible desde el log.
  select jsonb_build_object(
           'despacho', to_jsonb(d),
           'ordenes', coalesce(
             (select jsonb_agg(to_jsonb(o) order by o.order_number)
                from public.despacho_ordenes o where o.despacho_id = d.id), '[]'::jsonb),
           'bultos', coalesce(
             (select jsonb_agg(to_jsonb(b) order by b.bulto_numero)
                from public.despacho_bultos b where b.despacho_id = d.id), '[]'::jsonb),
           'asignaciones', coalesce(
             (select jsonb_agg(to_jsonb(ob) order by ob.order_number, ob.bulto_numero)
                from public.despacho_orden_bultos ob where ob.despacho_id = d.id), '[]'::jsonb)
         )
    into v_snapshot
    from public.despachos d
   where d.id = p_despacho_id;

  if v_snapshot is null then
    raise exception 'El despacho no existe o ya fue eliminado.';
  end if;

  insert into public.log_eliminaciones (tabla_origen, registro_id, snapshot, eliminado_por, motivo)
  values ('despachos', p_despacho_id, v_snapshot, v_perfil_id, trim(p_motivo));

  -- despacho_ordenes / despacho_bultos / despacho_orden_bultos caen por
  -- cascade (027). El trigger de validación es BEFORE INSERT OR UPDATE,
  -- así que no interfiere con el DELETE.
  delete from public.despachos where id = p_despacho_id;
end;
$$;

grant execute on function public.eliminar_despacho_con_motivo(uuid, text) to authenticated;

comment on function public.eliminar_despacho_con_motivo(uuid, text) is
  'Elimina un despacho COMPLETO (con sus órdenes, bultos y asignaciones) exigiendo motivo, dejando snapshot en log_eliminaciones. No existe borrado parcial.';
