-- Rode DEPOIS de notificacoes.sql
alter table public.notificacoes add column if not exists editado_por text;
alter table public.notificacoes add column if not exists editado_em  timestamptz;
alter table public.notificacoes add column if not exists criado_por  text;
-- exclusão no app = apenas esconder; o registro continua no banco
alter table public.notificacoes add column if not exists excluida boolean not null default false;
