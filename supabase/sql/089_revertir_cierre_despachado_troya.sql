-- Reversa de 089: vuelve al estado de 087/088.
-- Antes de revertir, los cierres con tipo despachado_troya_* se pasan a
-- 'operativo' (para que el check anterior los acepte; vuelven a contar como
-- pendiente). Se pierden los pares por talla y la fecha de Troya.
begin;

update public.pedido_cierre_forzado
   set tipo_cierre = 'operativo'
 where tipo_cierre in ('despachado_troya_total', 'despachado_troya_parcial');

-- Vista como en 088 (sin las 4 columnas nuevas)
drop view if exists public.vw_dashboard_lineas;

create view public.vw_dashboard_lineas
with (security_invoker = true)
as
with vivas as (
  select p.*
    from public.p_pedidosh p
   where coalesce(p."Cancelado", false) = false
     and case when p."PedidoNo"::text ~ '^[0-9]+$' then p."PedidoNo"::text::bigint end >= 3095
),
despachado as (
  select doi.item_id, sum(doi.cantidad)::numeric as despachado
    from public.despacho_orden_items doi
   group by doi.item_id
),
cancelados as (
  select distinct c.pedido
    from public.erp_cambios c
   where c.tipo = 'cancelado'
     and c.estado in ('pendiente', 'aplicado', 'rechazado')
),
numeradas as (
  select v.*,
         row_number() over (partition by v.item_id order by v."Talla", v."DetalleVira") as rn
    from vivas v
)
select
  n."PedidoNo"::text                                   as order_number,
  n.item_id                                            as item_id,
  n."Talla"::text                                      as talla,
  n."Cliente"                                          as cliente,
  n."NombreR"                                          as nombre_suela,
  n."MaterialP"                                        as material,
  n."ColorP"                                           as color,
  lower(coalesce(n."Vira"::text, ''))      in ('true', 't', '1', 'si', 'sí') as vira,
  lower(coalesce(n."Acabado"::text, ''))   in ('true', 't', '1', 'si', 'sí') as acabado,
  lower(coalesce(n."Esterilla"::text, '')) in ('true', 't', '1', 'si', 'sí') as esterilla,
  lower(coalesce(n."Marquilla"::text, '')) in ('true', 't', '1', 'si', 'sí') as marquilla,
  n."FechaP"                                           as fecha_pedido,
  coalesce(n."CantidadP", 0)::numeric                  as solicitado,
  case when n.rn = 1 then coalesce(d.despachado, 0) else 0 end as despachado,
  (pcf.order_number is not null)                       as cierre_forzado,
  (can.pedido is not null or pcf.tipo_cierre = 'cancelado') as cancelado_access
from numeradas n
left join despachado d on d.item_id = n.item_id
left join public.pedido_cierre_forzado pcf on pcf.order_number = n."PedidoNo"::text
left join cancelados can on can.pedido = n."PedidoNo"::text;

grant select on public.vw_dashboard_lineas to authenticated;
revoke select on public.vw_dashboard_lineas from anon;

drop function if exists public.cambiar_tipo_cierre_forzado(text, text, date, jsonb);
drop function if exists public.cerrar_pedido_forzado(text, text, text, date, jsonb);
drop function if exists public.fn_guardar_cierre_troya(text, text, date, jsonb);

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

drop table if exists public.pedido_cierre_troya;

alter table public.pedido_cierre_forzado drop column if exists fecha_despacho_troya;

alter table public.pedido_cierre_forzado drop constraint if exists pedido_cierre_forzado_tipo_check;
alter table public.pedido_cierre_forzado
  add constraint pedido_cierre_forzado_tipo_check
    check (tipo_cierre is null or tipo_cierre in ('cancelado', 'no_terminado', 'operativo'));

commit;
