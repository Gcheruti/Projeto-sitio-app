-- Login da equipe: contas Adm e Staff.
-- Senha guardada como hash: sha256('sitio:' + senha) em hexadecimal.
create table if not exists public.usuarios (
  id          uuid primary key default gen_random_uuid(),
  nome        text not null,
  login       text not null,
  senha_hash  text not null,
  papel       text not null default 'staff' check (papel in ('adm','staff')),
  ativo       boolean not null default true,
  criado_em   timestamptz not null default now()
);

create unique index if not exists usuarios_login_unico on public.usuarios (lower(login));

alter table public.usuarios enable row level security;

-- App ainda usa só a chave anon: acesso aberto (restringir com Supabase Auth no futuro).
drop policy if exists usuarios_all on public.usuarios;
create policy usuarios_all on public.usuarios
  for all to anon, authenticated using (true) with check (true);

-- Contas iniciais (login - senha): adm - adm  |  staf - staf
insert into public.usuarios (nome, login, senha_hash, papel)
select 'Administrador', 'adm', encode(sha256(convert_to('sitio:adm','UTF8')),'hex'), 'adm'
where not exists (select 1 from public.usuarios where lower(login)='adm');

insert into public.usuarios (nome, login, senha_hash, papel)
select 'Staff', 'staf', encode(sha256(convert_to('sitio:staf','UTF8')),'hex'), 'staff'
where not exists (select 1 from public.usuarios where lower(login)='staf');
