-- Sítio dos Coelhos · schema separado "site" para os cadastros do site.
-- Não altera nada no schema public. Rodar uma vez no SQL Editor do Supabase.

create schema if not exists site;
comment on schema site is 'Dados do site do Sítio dos Coelhos (cadastros, reservas, pré-inscrições). Separado do app.';

create table if not exists site.cadastros (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  categoria text not null check (categoria in ('visita','restaurante','evento_presenca','evento_orcamento','curso','espaco')),
  referencia_id text,          -- id do evento/curso na agenda_eventos (quando houver)
  referencia_titulo text,      -- nome do evento, curso ou espaço
  data_desejada text,
  nome text not null check (char_length(nome) between 1 and 200),
  telefone text check (char_length(telefone) <= 50),
  email text check (char_length(email) <= 200),
  pessoas integer check (pessoas between 0 and 10000),
  mensagem text check (char_length(mensagem) <= 4000),
  dados jsonb not null default '{}'::jsonb check (pg_column_size(dados) <= 16000), -- demais campos do formulário
  pagina text,
  status text not null default 'novo'
);
comment on table site.cadastros is 'Todos os pedidos enviados pelos formulários do site. A coluna categoria indica a origem.';
create index if not exists cadastros_categoria_data on site.cadastros (categoria, criado_em desc);

-- Segurança: o site (chave pública) só pode INSERIR. Ninguém de fora consegue ler, editar ou apagar.
alter table site.cadastros enable row level security;
grant usage on schema site to anon, authenticated, service_role;
grant insert (categoria, referencia_id, referencia_titulo, data_desejada, nome, telefone, email, pessoas, mensagem, dados, pagina)
  on site.cadastros to anon, authenticated;
grant all on site.cadastros to service_role;

drop policy if exists "site pode inserir cadastros" on site.cadastros;
create policy "site pode inserir cadastros" on site.cadastros
  for insert to anon, authenticated
  with check (status = 'novo');
