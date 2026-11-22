-- Leitura do OCR x correção final da equipe (para melhorar o leitor de notas).
create table if not exists public.notas_correcoes (
  id            uuid primary key default gen_random_uuid(),
  nota_id       uuid references public.notas_importadas(id) on delete set null,
  origem        text,
  texto_bruto   text,
  itens_lidos   jsonb not null default '[]'::jsonb,
  itens_finais  jsonb not null default '[]'::jsonb,
  total_lido    numeric(12,2),
  total_final   numeric(12,2),
  criado_em     timestamptz not null default now()
);

alter table public.notas_correcoes enable row level security;

-- App ainda sem login: acesso aberto (restringir quando houver login).
drop policy if exists notas_correcoes_all on public.notas_correcoes;
create policy notas_correcoes_all on public.notas_correcoes
  for all to anon, authenticated using (true) with check (true);
