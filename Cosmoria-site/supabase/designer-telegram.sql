-- Portal Cosmoria · envio da arte ao designer (Telegram + e-mail) e link de visualização 3D.
-- Rode tudo de uma vez no SQL Editor do Supabase. Pode rodar de novo sem problema.
-- Tudo fica no schema "Cosmoria".

-- 1) A função do designer roda com a chave de serviço e precisa ler e marcar as artes
--    (sem isso aparecia "permission denied for table personalizacoes" e nada era enviado).
grant usage on schema "Cosmoria" to service_role;
grant select, update on "Cosmoria".personalizacoes to service_role;

-- 2) Chave secreta de cada arte, usada no link "Ver em 3D" que vai para o designer.
alter table "Cosmoria".personalizacoes add column if not exists chave_ver uuid not null default gen_random_uuid();

-- 3) Ajustes do envio (só a função do servidor lê; o site não enxerga).
create table if not exists "Cosmoria".ajustes_designer (
  chave text primary key,
  valor text not null default '',
  atualizado_em timestamptz not null default now()
);
alter table "Cosmoria".ajustes_designer enable row level security;
revoke all on "Cosmoria".ajustes_designer from anon, authenticated;
grant select, insert, update on "Cosmoria".ajustes_designer to service_role;

insert into "Cosmoria".ajustes_designer (chave, valor) values
  ('email_destino', 'coelhocheruti@gmail.com')
on conflict (chave) do update set valor = excluded.valor, atualizado_em = now();
-- Opcional: endereço público do site, para o link 3D (se ficar vazio, usa o endereço de onde a arte foi enviada).
-- insert into "Cosmoria".ajustes_designer (chave, valor) values ('site_url', 'https://seu-site.com.br/')
--   on conflict (chave) do update set valor = excluded.valor, atualizado_em = now();
-- Opcional: fixar a conversa do Telegram (a função descobre sozinha quando você manda /start para o bot).
-- insert into "Cosmoria".ajustes_designer (chave, valor) values ('telegram_chat_id', '123456789')
--   on conflict (chave) do update set valor = excluded.valor, atualizado_em = now();

-- 4) Página ver-arte.html: devolve só o produto e a arte (nada de nome ou contato do cliente),
--    e só para quem tem o link com a chave certa.
create or replace function "Cosmoria".arte_para_ver(p_id uuid, p_chave uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'codigo', upper(left(p.id::text, 8)),
    'nome_peca', p.dados->>'nome_peca',
    'produto', p.produto_nome,
    'variante', p.variante_nome,
    'modelo', p.modelo,
    'cor', p.dados->>'cor',
    'lados', p.lados_usados,
    'quantidade', p.quantidade,
    'criado_em', p.criado_em,
    'arte_frente', p.arte_frente,
    'arte_verso', p.arte_verso)
  from "Cosmoria".personalizacoes p
  where p.id = p_id and p.chave_ver = p_chave;
$$;
revoke all on function "Cosmoria".arte_para_ver(uuid, uuid) from public;
grant execute on function "Cosmoria".arte_para_ver(uuid, uuid) to anon, authenticated;
