-- =====================================================================
-- 065_revertir_listar_despachos_registro.sql
-- Deshace 065: elimina el RPC listar_despachos_registro. No toca
-- vw_despachos_registro ni las tablas de despachos.
-- El frontend, sin el RPC, cae a la vista (más lenta). Si también se
-- revierte el JS, el listado vuelve a consultar solo la vista.
-- =====================================================================

drop function if exists public.listar_despachos_registro(text, text, text, integer, integer);
