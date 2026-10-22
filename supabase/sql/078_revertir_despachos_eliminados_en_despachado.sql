-- Reversa de 078: quita la funcion de solo lectura. No toca datos.
drop function if exists public.listar_despachos_eliminados(text, text, text, text, text);
