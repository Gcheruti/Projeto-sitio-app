-- Registro de tudo que a equipe faz no app (quem fez, o quê e quando).
create table if not exists public.atividades (
  id             uuid primary key default gen_random_uuid(),
  criado_em      timestamptz not null default now(),
  usuario_id     text,
  usuario_nome   text,
  usuario_login  text,
  acao           text not null,
  entidade       text,
  detalhe        text,
  comanda_codigo text
);

create index if not exists atividades_usuario_data
  on public.atividades (usuario_id, criado_em desc);
create index if not exists atividades_data
  on public.atividades (criado_em desc);

alter table public.atividades enable row level security;

-- App ainda sem login do Supabase: acesso aberto (restringir depois).
drop policy if exists atividades_all on public.atividades;
create policy atividades_all on public.atividades
  for all to anon, authenticated using (true) with check (true);
