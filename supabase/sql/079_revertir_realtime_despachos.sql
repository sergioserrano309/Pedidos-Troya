-- Reversa de 079: la app deja de recibir avisos en vivo de despachos.
do $$
begin
  if exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'despachos'
  ) then
    alter publication supabase_realtime drop table public.despachos;
  end if;
end
$$;
