-- =====================================================================
-- 082_vista_pedido_atributos.sql
-- Filtros Si/No de Vira, Acabado, Esterilla y Marquilla en Ordenes >
-- Activas y Completadas (por ahora solo Empaque).
--
-- QUE HACE
--   Vista nueva de SOLO LECTURA: todas las columnas de vw_pedido_progreso
--   (la que alimenta las tarjetas) mas cuatro columnas booleanas por
--   pedido: vira, acabado, esterilla, marquilla.
--   Un pedido es "Si" en un atributo si ALGUNA de sus lineas (sin
--   canceladas) lo lleva; "No" si ninguna.
--
-- POR QUE UNA VISTA APARTE
--   vw_pedido_progreso es la vista central de la app y varias vistas
--   dependen de ella; no se toca. La pantalla usa esta nueva SOLO cuando
--   hay un filtro de Si/No activo; sin filtros sigue leyendo la de siempre.
--
-- NOTA: "vp.*" se fija al crear la vista. Si algun dia cambia
-- vw_pedido_progreso, hay que volver a ejecutar este archivo.
-- Reversa: 082_revertir_vista_pedido_atributos.sql
-- =====================================================================

create or replace view public.vw_pedido_progreso_atributos
with (security_invoker = true)
as
select
  vp.*,
  coalesce(a.vira, false)       as vira,
  coalesce(a.acabado, false)    as acabado,
  coalesce(a.esterilla, false)  as esterilla,
  coalesce(a.marquilla, false)  as marquilla
from public.vw_pedido_progreso vp
left join (
  select
    p."PedidoNo"::text as order_number,
    bool_or(lower(coalesce(p."Vira"::text, ''))       in ('true', 't', '1', 'si', 'sí')) as vira,
    bool_or(lower(coalesce(p."Acabado"::text, ''))    in ('true', 't', '1', 'si', 'sí')) as acabado,
    bool_or(lower(coalesce(p."Esterilla"::text, ''))  in ('true', 't', '1', 'si', 'sí')) as esterilla,
    bool_or(lower(coalesce(p."Marquilla"::text, ''))  in ('true', 't', '1', 'si', 'sí')) as marquilla
  from public.p_pedidosh p
  where coalesce(p."Cancelado", false) = false
  group by p."PedidoNo"::text
) a on a.order_number = vp.order_number;

grant select on public.vw_pedido_progreso_atributos to authenticated;
revoke select on public.vw_pedido_progreso_atributos from anon;

comment on view public.vw_pedido_progreso_atributos is
  'vw_pedido_progreso + vira/acabado/esterilla/marquilla por pedido (alguna linea = Si). Solo lectura; la usan los filtros Si/No de Activas y Completadas (082).';

-- =====================================================================
-- PRUEBA SEGURA (solo lectura):
--   select vira, acabado, esterilla, marquilla, count(*)
--     from public.vw_pedido_progreso_atributos group by 1,2,3,4 order by 5 desc;
--   -- debe repartir los pedidos en combinaciones; y el total debe ser igual a:
--   select count(*) from public.vw_pedido_progreso;
-- =====================================================================
