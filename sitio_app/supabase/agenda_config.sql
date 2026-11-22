-- Cor e ícone de cada tipo de agendamento (Casa da Bruxa e Agenda geral).
-- Rode uma vez no SQL Editor. Sem ele o app usa cores/ícones padrão e não consegue salvar a escolha.
create table if not exists public.agenda_config (
  escopo text not null,          -- 'casa_bruxa' | 'geral'
  chave text not null,           -- id do atendimento (casa_bruxa) ou tipo (geral)
  cor text not null,
  icone text not null,
  atualizado_em timestamptz not null default now(),
  primary key (escopo, chave)
);
alter table public.agenda_config enable row level security;
drop policy if exists agenda_config_all on public.agenda_config;
create policy agenda_config_all on public.agenda_config
  for all to anon, authenticated using (true) with check (true);
