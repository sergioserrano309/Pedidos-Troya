-- =====================================================================
-- 086_revertir_despachos_ocultos_rapido.sql
-- Deshace 086: devuelve las politicas de despachos y despacho_bultos a la
-- version de 058 (fn_despacho_oculto por fila) y borra la vista nueva.
-- No toca datos.
-- =====================================================================

begin;

drop policy if exists "oculto_pedidos_anteriores" on public.despachos;
create policy "oculto_pedidos_anteriores"
  on public.despachos
  as restrictive
  for select
  to authenticated
  using (not public.fn_despacho_oculto(id));

drop policy if exists "oculto_pedidos_anteriores" on public.despacho_bultos;
create policy "oculto_pedidos_anteriores"
  on public.despacho_bultos
  as restrictive
  for select
  to authenticated
  using (not public.fn_despacho_oculto(despacho_id));

drop view if exists public.vw_despachos_ocultos;

commit;
