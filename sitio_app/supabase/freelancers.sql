-- Freelancers: conta de login (papel 'freelancer'), diárias e valores por cargo.
-- Rode DEPOIS de usuarios.sql e financeiro.sql.

-- 1) permitir o papel 'freelancer' em usuarios
alter table public.usuarios drop constraint if exists usuarios_papel_check;
alter table public.usuarios add constraint usuarios_papel_check
  check (papel in ('adm','staff','freelancer','totem','cozinha'));

-- 2) valor da diária por cargo (editável no app)
create table if not exists public.freelancer_cargos (
  cargo text primary key,        -- 'limpeza' | 'garcom' | 'auxilio'
  valor numeric not null default 0
);
insert into public.freelancer_cargos (cargo, valor) values
  ('limpeza', 100), ('garcom', 100), ('auxilio', 100)
on conflict (cargo) do nothing;

-- 3) dias agendados de cada freelancer
create table if not exists public.freelancer_dias (
  id uuid primary key default gen_random_uuid(),
  usuario_id text not null,
  dia date not null,
  cargo text not null,
  valor numeric not null default 0,   -- valor travado no momento do agendamento
  login_em timestamptz,               -- 1º login do dia (gera o gasto)
  logout_em timestamptz,
  lancamento_id text,                 -- gasto criado em fin_lancamentos
  criado_por text,
  criado_em timestamptz not null default now(),
  unique (usuario_id, dia)
);
create index if not exists freelancer_dias_usuario on public.freelancer_dias (usuario_id, dia);

alter table public.freelancer_cargos enable row level security;
alter table public.freelancer_dias enable row level security;
drop policy if exists fcargos_all on public.freelancer_cargos;
create policy fcargos_all on public.freelancer_cargos for all using (true) with check (true);
drop policy if exists fdias_all on public.freelancer_dias;
create policy fdias_all on public.freelancer_dias for all using (true) with check (true);
