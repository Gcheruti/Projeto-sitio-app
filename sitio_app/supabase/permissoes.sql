-- Permissões por perfil (Manutenção de equipe > Permissões). Rode uma vez no SQL Editor.
-- Sem este script o app usa os valores padrão e não consegue salvar mudanças.
create table if not exists public.permissoes_perfil (
  perfil text not null,      -- staff | freelancer_<cargo> | freelancer | cozinha | totem
  permissao text not null,   -- chave da função (ex.: aba_comandas)
  habilitado boolean not null,
  atualizado_em timestamptz not null default now(),
  primary key (perfil, permissao)
);
alter table public.permissoes_perfil enable row level security;
drop policy if exists permissoes_perfil_all on public.permissoes_perfil;
create policy permissoes_perfil_all on public.permissoes_perfil
  for all to anon, authenticated using (true) with check (true);
