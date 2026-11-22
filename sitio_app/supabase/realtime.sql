-- Liga o TEMPO REAL do Supabase nas tabelas que o app acompanha (1.0.8).
-- Rode uma vez no SQL Editor. Pode rodar de novo sem problema.
do $$
declare t text;
begin
  foreach t in array array[
    'produtos', 'comandas', 'itens_comanda', 'notificacoes',
    'lotes', 'agenda_eventos', 'comanda_avisos'
  ] loop
    if to_regclass('public.' || t) is not null
       and not exists (
         select 1 from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public' and tablename = t
       ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
