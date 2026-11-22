-- Lotes com validade (criados na reposição). Rode uma vez no SQL Editor.
create table if not exists public.lotes (
  id uuid primary key default gen_random_uuid(),
  produto_id text not null,
  quantidade integer not null check (quantidade > 0),
  validade date not null,
  criado_em timestamptz not null default now()
);
create index if not exists lotes_produto_idx on public.lotes (produto_id);
alter table public.lotes enable row level security;
drop policy if exists "lotes_all" on public.lotes;
create policy "lotes_all" on public.lotes for all using (true) with check (true);
