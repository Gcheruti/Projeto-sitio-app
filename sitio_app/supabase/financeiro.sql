-- Controle financeiro da Toca dos Coelhos (gastos e receitas).
-- Modelo inspirado em apps open source de finanças (lançamentos +
-- categorias + contas fixas recorrentes), em versão enxuta.
create table if not exists public.fin_lancamentos (
  id            uuid primary key default gen_random_uuid(),
  tipo          text not null check (tipo in ('despesa','receita')),
  categoria     text not null,
  descricao     text not null,
  valor         numeric(12,2) not null check (valor >= 0),
  data          date not null,
  competencia   text not null,              -- 'AAAA-MM'
  pago          boolean not null default false,
  recorrente_id uuid,
  observacao    text,
  criado_por    text,
  editado_por   text,
  excluido      boolean not null default false,   -- "excluir" só esconde
  criado_em     timestamptz not null default now()
);

create table if not exists public.fin_recorrentes (
  id             uuid primary key default gen_random_uuid(),
  tipo           text not null default 'despesa' check (tipo in ('despesa','receita')),
  categoria      text not null,
  descricao      text not null,
  valor          numeric(12,2) not null default 0,
  dia_vencimento int  not null default 5 check (dia_vencimento between 1 and 31),
  ativo          boolean not null default true,
  criado_em      timestamptz not null default now()
);

create index if not exists fin_lanc_data on public.fin_lancamentos (data desc);
create index if not exists fin_lanc_comp on public.fin_lancamentos (competencia);

alter table public.fin_lancamentos enable row level security;
alter table public.fin_recorrentes enable row level security;
drop policy if exists fin_lanc_all on public.fin_lancamentos;
create policy fin_lanc_all on public.fin_lancamentos
  for all to anon, authenticated using (true) with check (true);
drop policy if exists fin_rec_all on public.fin_recorrentes;
create policy fin_rec_all on public.fin_recorrentes
  for all to anon, authenticated using (true) with check (true);
