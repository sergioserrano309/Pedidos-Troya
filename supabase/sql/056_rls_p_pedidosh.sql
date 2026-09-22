-- =====================================================================
-- 056_rls_p_pedidosh.sql
-- Cierra p_pedidosh, que esta hoy en "Unrestricted" (sin RLS): con la
-- anon key —que viaja publica dentro del javascript de la pagina—
-- cualquiera puede leer la tabla completa de pedidos SIN iniciar sesion.
--
-- POR QUE SIGUE ABIERTA SI YA LO HABIAMOS PREVISTO
-- 006_rls_policies.sql ya traia exactamente este bloque... pero 006 se
-- ejecuta ANTES de 009, que es la migracion que CREA p_pedidosh. Cuando
-- se corrio 006 la tabla todavia no existia, esa parte del script fallo
-- o se salto, y nadie volvio sobre ella. Esta migracion repite el mismo
-- bloque ahora que la tabla si existe. No inventa reglas nuevas: aplica
-- las que el proyecto ya habia decidido.
--
-- POR QUE NO ROMPE NADA
--   - Ningun modulo del frontend lee p_pedidosh directamente: todos
--     pasan por vistas (vw_item_progreso, vw_pedido_progreso,
--     vw_item_despacho_saldo, ...). Esas vistas son security_invoker, o
--     sea que consultan la tabla CON LOS PERMISOS DEL USUARIO — y la
--     politica de abajo le da select a todo usuario autenticado, que es
--     exactamente lo que puede hacer hoy.
--   - Realtime solo escucha production_movements y returns, no esta
--     tabla.
--   - Las funciones security definer (crear_despacho,
--     eliminar_movimiento_con_motivo, ...) corren como su dueno y no
--     pasan por RLS.
--   - La carga desde el ERP usa la service_role key, que ignora RLS
--     por completo.
--
-- Lo unico que deja de poder hacerse es leer la tabla SIN sesion
-- iniciada, que es justamente el agujero.
-- =====================================================================

alter table public.p_pedidosh enable row level security;

drop policy if exists "p_pedidosh_select_authenticated" on public.p_pedidosh;
create policy "p_pedidosh_select_authenticated"
on public.p_pedidosh
for select
to authenticated
using (true);

-- Sin politicas de insert/update/delete a proposito: p_pedidosh es un
-- espejo de solo lectura del ERP. Solo service_role puede escribirla.
grant select on public.p_pedidosh to authenticated;
revoke insert, update, delete on public.p_pedidosh from authenticated, anon;
revoke select on public.p_pedidosh from anon;

comment on table public.p_pedidosh is
  'Espejo de solo lectura de los pedidos del ERP. RLS: select para authenticated; escritura solo con service_role (056).';
