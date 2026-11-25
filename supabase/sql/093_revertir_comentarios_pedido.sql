-- Reversa de 093_comentarios_pedido.sql (BORRA todos los comentarios de ordenes).
begin;

do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'pedido_comentarios'
  ) then
    alter publication supabase_realtime drop table public.pedido_comentarios;
  end if;
end
$$;

drop function if exists public.agregar_comentario_pedido(text, text);
drop function if exists public.eliminar_comentario_pedido(uuid);
drop table if exists public.pedido_comentarios;
drop function if exists public.fn_pedido_comentarios_inmutable();

commit;
