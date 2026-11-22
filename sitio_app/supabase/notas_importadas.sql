-- Sítio • notas importadas (foto / QR Code) para a Reposição
-- Rode UMA vez no Supabase: SQL Editor → New query → colar → Run.
-- Pode rodar de novo sem problema (usa IF NOT EXISTS / DROP POLICY IF EXISTS).
--
-- Fluxo no app:
--   1) foto/QR → itens lidos → grava aqui com status 'rascunho'
--   2) conferência editável (edições regravam os itens do rascunho)
--   3) ao confirmar a reposição → status 'confirmada' + reposicao_id + valor_investido
--
-- Obs.: reposicao_id é TEXT sem FK de propósito: não dá para ter certeza do tipo
-- do id da tabela "reposicoes" já existente (uuid ou bigint) e uma FK errada
-- quebraria este script. Se quiser a FK, crie depois com o tipo correto.

create table if not exists public.notas_importadas (
  id              uuid primary key default gen_random_uuid(),
  origem          text not null check (origem in ('foto', 'qr')),
  status          text not null default 'rascunho'
                    check (status in ('rascunho', 'confirmada', 'cancelada')),
  chave_acesso    text,                 -- 44 dígitos da NFC-e, quando lida
  url_qr          text,                 -- URL do QR, quando origem = 'qr'
  total_nota      numeric(12,2),        -- total lido (editável na conferência)
  valor_investido numeric(12,2),        -- preenchido ao confirmar
  texto_bruto     text,                 -- texto do OCR (ajuda a melhorar a leitura)
  qtd_fotos       int  not null default 0,
  reposicao_id    text,                 -- reposição gerada ao confirmar
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now(),
  confirmado_em   timestamptz
);

create table if not exists public.notas_importadas_itens (
  id             uuid primary key default gen_random_uuid(),
  nota_id        uuid not null references public.notas_importadas(id) on delete cascade,
  ordem          int  not null default 0,
  nome           text not null,
  quantidade     numeric(12,3) not null default 1,
  valor_unitario numeric(12,2),
  valor_total    numeric(12,2),
  codigo         text                   -- EAN/código impresso na linha, se houver
);

create index if not exists notas_importadas_status_idx
  on public.notas_importadas (status, criado_em desc);
create index if not exists notas_importadas_chave_idx
  on public.notas_importadas (chave_acesso) where chave_acesso is not null;
create index if not exists notas_importadas_itens_nota_idx
  on public.notas_importadas_itens (nota_id, ordem);

-- Acesso: o app ainda não tem login (usa a chave anon), então as políticas
-- abaixo liberam anon + authenticated, igual ao uso atual das outras tabelas.
-- QUANDO ENTRAR O LOGIN POR USUÁRIO: troque por políticas restritas
-- (ex.: using (auth.uid() is not null)).
alter table public.notas_importadas       enable row level security;
alter table public.notas_importadas_itens enable row level security;

drop policy if exists "equipe_notas"       on public.notas_importadas;
drop policy if exists "equipe_notas_itens" on public.notas_importadas_itens;

create policy "equipe_notas" on public.notas_importadas
  for all to anon, authenticated using (true) with check (true);
create policy "equipe_notas_itens" on public.notas_importadas_itens
  for all to anon, authenticated using (true) with check (true);
