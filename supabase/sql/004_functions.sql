-- =====================================================================
-- 004_functions.sql
-- Funcion SQL que replica EXACTAMENTE el algoritmo de generacion de ID
-- determinista usado en el frontend (src/lib/itemId.js), para poder
-- construir vistas en el servidor que agrupen production_movements /
-- returns contra p_pedidosh usando el mismo item_id de 10 digitos.
--
-- Algoritmo (debe coincidir con itemId.js):
--   1. Tomar PedidoNo, Referencia, Talla, MaterialP, ColorP.
--   2. A cada campo por separado: trim() + upper().
--   3. Concatenarlos (sin separador).
--   4. SHA-256 sobre el string resultante (UTF-8).
--   5. Convertir el hash hexadecimal completo a un entero grande y
--      tomar el resto modulo 10^10.
--   6. Rellenar con ceros a la izquierda hasta 10 digitos.
-- =====================================================================

-- pgcrypto provee la funcion digest() usada para SHA-256.
create extension if not exists pgcrypto with schema extensions;

create or replace function public.generar_item_id(
  p_pedido_no text,
  p_referencia text,
  p_talla text,
  p_material text,
  p_color text
) returns text
language plpgsql
immutable
as $$
declare
  v_input text;
  v_hash bytea;
  v_hex text;
  v_result numeric := 0;
  v_char text;
  v_digit int;
  i int;
begin
  v_input :=
    upper(trim(coalesce(p_pedido_no, ''))) ||
    upper(trim(coalesce(p_referencia, ''))) ||
    upper(trim(coalesce(p_talla, ''))) ||
    upper(trim(coalesce(p_material, ''))) ||
    upper(trim(coalesce(p_color, '')));

  v_hash := extensions.digest(convert_to(v_input, 'UTF8'), 'sha256');
  v_hex := encode(v_hash, 'hex');

  for i in 1..length(v_hex) loop
    v_char := lower(substr(v_hex, i, 1));
    v_digit := position(v_char in '0123456789abcdef') - 1;
    v_result := (v_result * 16 + v_digit) % 10000000000;
  end loop;

  return lpad(trunc(v_result)::text, 10, '0');
end;
$$;

comment on function public.generar_item_id is
  'Genera el ID logico deterministico de 10 digitos para un item de p_pedidosh. Debe coincidir exactamente con src/lib/itemId.js del frontend.';
