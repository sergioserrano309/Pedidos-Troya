-- =====================================================================
-- 011_filtros_opciones.sql
-- Vistas de solo lectura con los valores UNICOS (DISTINCT) de
-- NombreR/MaterialP/ColorP que existen hoy en p_pedidosh, usadas para
-- poblar los dropdowns de filtro del listado de ordenes. Al ser vistas
-- (no listas fijas), cada vez que se abre la pagina de Ordenes se
-- consultan de nuevo: si llega un pedido nuevo con un color que nunca se
-- habia usado, aparece automaticamente en el dropdown sin tocar codigo.
-- =====================================================================

create or replace view public.vw_nombres_suela
with (security_invoker = true) as
select distinct "NombreR" as nombre_referencia
from public.p_pedidosh
where "NombreR" is not null and "NombreR" <> ''
order by 1;

create or replace view public.vw_materiales
with (security_invoker = true) as
select distinct "MaterialP" as material
from public.p_pedidosh
where "MaterialP" is not null and "MaterialP" <> ''
order by 1;

create or replace view public.vw_colores
with (security_invoker = true) as
select distinct "ColorP" as color
from public.p_pedidosh
where "ColorP" is not null and "ColorP" <> ''
order by 1;

create or replace view public.vw_clientes
with (security_invoker = true) as
select distinct "Cliente" as cliente
from public.p_pedidosh
where "Cliente" is not null and "Cliente" <> ''
order by 1;

grant select on public.vw_nombres_suela to authenticated;
grant select on public.vw_materiales to authenticated;
grant select on public.vw_colores to authenticated;
grant select on public.vw_clientes to authenticated;
