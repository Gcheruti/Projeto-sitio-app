create table if not exists public.notificacoes (
  id         text primary key,
  titulo     text not null,
  descricao  text not null default '',
  ativa      boolean not null default true,
  local      text,
  criado_em  timestamptz not null default now()
);
alter table public.notificacoes enable row level security;
drop policy if exists notificacoes_all on public.notificacoes;
create policy notificacoes_all on public.notificacoes
  for all to anon, authenticated using (true) with check (true);
