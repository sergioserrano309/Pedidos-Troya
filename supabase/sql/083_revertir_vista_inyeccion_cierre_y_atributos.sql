-- Reversa de 083: deja vw_pedido_inyeccion como en 080 (sin cierre forzado ni
-- atributos). Una vista no puede perder columnas con "create or replace", por eso
-- se borra y se vuelve a crear. No toca datos.
drop view if exists public.vw_pedido_inyeccion;

create view public.vw_pedido_inyeccion
with (security_invoker = true)
as
select
  p."PedidoNo"::text                                  as order_number,
  max(p."Cliente")                                    as cliente,
  max(p."FechaP")                                     as fecha_pedido,
  max(p."NombreR")                                    as nombre_referencia,
  max(p."MaterialP")                                  as material,
  max(p."ColorP")                                     as color,
  sum(coalesce(p."CantidadP", 0))::numeric            as total_solicitado,
  sum(coalesce(p."Total01Iny", 0))::numeric           as total_procesado,
  greatest(sum(coalesce(p."CantidadP", 0)) - sum(coalesce(p."Total01Iny", 0)), 0)::numeric
                                                      as total_pendiente,
  case when sum(coalesce(p."CantidadP", 0)) > 0
    then least(round(sum(coalesce(p."Total01Iny", 0))::numeric / sum(coalesce(p."CantidadP", 0))::numeric * 100), 100)
    else 0
  end                                                 as porcentaje_completado,
  case when sum(coalesce(p."CantidadP", 0)) > 0
        and sum(coalesce(p."Total01Iny", 0)) >= sum(coalesce(p."CantidadP", 0))
    then 'Completado' else 'En Proceso'
  end                                                 as estatus_general,
  'Inyeccion'::text                                   as etapa_actual,
  extract(day from (now() - max(p."FechaP")))::int    as dias_orden,
  false                                               as cierre_forzado
from public.p_pedidosh p
where coalesce(p."Cancelado", false) = false
  and case when p."PedidoNo"::text ~ '^[0-9]+$' then p."PedidoNo"::text::bigint end >= 3095
group by p."PedidoNo"::text;

grant select on public.vw_pedido_inyeccion to authenticated;
revoke select on public.vw_pedido_inyeccion from anon;
