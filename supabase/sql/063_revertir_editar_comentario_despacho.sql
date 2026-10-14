-- =====================================================================
-- 063_revertir_editar_comentario_despacho.sql
-- Deshace 063: elimina el RPC editar_comentario_despacho. No toca la
-- columna despachos.comentario (062) ni los comentarios ya guardados, ni
-- los registros que ya quedaron en audit_validador.
-- Despues, revertir tambien el frontend (git): sin el RPC, el boton
-- "Guardar comentario" del Validador fallaria.
-- =====================================================================

drop function if exists public.editar_comentario_despacho(uuid, text);
