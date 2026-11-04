-- Reversa de 084: quita las dos vistas de solo lectura. No toca datos.
drop view if exists public.vw_dashboard_despachos;
drop view if exists public.vw_dashboard_lineas;
