-- Comandas: desconto por item, pagamento dividido, avisos na comanda e
-- alertas só para administradores. Rode uma vez no SQL Editor.
alter table public.itens_comanda add column if not exists desconto numeric not null default 0;
alter table public.comandas_historico add column if not exists pagamentos_json jsonb;
alter table public.notificacoes add column if not exists somente_adm boolean not null default false;

create table if not exists public.comanda_avisos (
  id uuid primary key default gen_random_uuid(),
  comanda_codigo text not null,
  texto text not null,
  criado_por text,
  criado_em timestamptz not null default now()
);
create index if not exists comanda_avisos_cod on public.comanda_avisos (comanda_codigo, criado_em);
alter table public.comanda_avisos enable row level security;
drop policy if exists comanda_avisos_all on public.comanda_avisos;
create policy comanda_avisos_all on public.comanda_avisos for all using (true) with check (true);
