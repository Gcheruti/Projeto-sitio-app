-- =====================================================================
-- PORTAL COSMORIA · VITRINE DO MERCADO LIVRE
-- O site vira vitrine: cada produto aponta para um anúncio do Mercado Livre,
-- e a compra acontece lá. Os dados (nome, preço, fotos, descrição, atributos,
-- variações) vêm do anúncio pela função "vitrine-ml" do Supabase.
--
-- Rode no Supabase > SQL Editor. Pode rodar mais de uma vez sem problema.
-- Rode DEPOIS do sql/admin.sql (usa a função "Cosmoria".eh_admin()).
--
-- O cadastro antigo (tabelas produtos, variantes, produto_imagens...) NÃO foi
-- apagado: só deixou de ser usado pelo site enquanto window.COSMORIA.modoVitrine = true
-- (arquivo js/config.js). Para voltar, mude para false.
-- =====================================================================

-- 1) Produtos da vitrine ------------------------------------------------
create table if not exists "Cosmoria".vitrine_ml (
  id bigint generated always as identity primary key,
  link text not null,                          -- link que o administrador colou
  ml_item_id text unique,                      -- anúncio (MLB + números, vem do wid= ou do buy box)
  ml_produto_id text,                          -- produto de catálogo (o MLB... depois de /p/)
  permalink text,                              -- link limpo do anúncio, usado no botão "Comprar no Mercado Livre"
  slug text not null unique,
  nome text not null,
  preco_centavos integer,                      -- preço atual
  preco_original_centavos integer,             -- preço "de" (riscado), quando há desconto
  desconto_pct integer,
  fotos jsonb not null default '[]',           -- ["https://...", ...]
  descricao text,
  atributos jsonb not null default '[]',       -- [{"nome":"Cor","valor":"Preto"}, ...]
  variacoes jsonb not null default '[]',       -- [{"nome":"Voltagem","opcoes":[{"valor":"127V","foto":"...","estoque":3}]}]
  condicao text,                               -- novo / usado
  estoque integer,
  vendidos integer,
  frete_gratis boolean,
  ml_status text,                              -- active, paused, closed...
  categoria_id bigint references "Cosmoria".categorias(id) on delete set null,
  ativo boolean not null default true,         -- aparece na vitrine
  destaque boolean not null default false,     -- aparece em "Destaques" na página inicial
  auto_atualizar boolean not null default true,-- entra na atualização diária
  travar_textos boolean not null default false, -- true = a atualização não muda o nome nem a descrição (o admin reescreveu)
  fonte text,                                  -- api | pagina | manual
  atualizado_ml_em timestamptz,                -- última vez que os dados vieram do ML
  ultimo_erro text,
  exemplo boolean not null default false,      -- produto de teste
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);
comment on table "Cosmoria".vitrine_ml is 'Produtos da vitrine. Cada linha é um anúncio do Mercado Livre; a compra acontece no ML.';
create index if not exists vitrine_ml_categoria on "Cosmoria".vitrine_ml (categoria_id);

create or replace function "Cosmoria".vitrine_ml_tocar() returns trigger language plpgsql set search_path = '' as $$
begin new.atualizado_em := now(); return new; end $$;
drop trigger if exists vitrine_ml_tocar on "Cosmoria".vitrine_ml;
create trigger vitrine_ml_tocar before update on "Cosmoria".vitrine_ml for each row execute function "Cosmoria".vitrine_ml_tocar();

alter table "Cosmoria".vitrine_ml enable row level security;
drop policy if exists "vitrine: todos veem os ativos" on "Cosmoria".vitrine_ml;
create policy "vitrine: todos veem os ativos" on "Cosmoria".vitrine_ml
  for select to anon, authenticated using (ativo or (select "Cosmoria".eh_admin()));
drop policy if exists "vitrine: admin cadastra" on "Cosmoria".vitrine_ml;
create policy "vitrine: admin cadastra" on "Cosmoria".vitrine_ml
  for insert to authenticated with check ((select "Cosmoria".eh_admin()));
drop policy if exists "vitrine: admin edita" on "Cosmoria".vitrine_ml;
create policy "vitrine: admin edita" on "Cosmoria".vitrine_ml
  for update to authenticated using ((select "Cosmoria".eh_admin())) with check ((select "Cosmoria".eh_admin()));
drop policy if exists "vitrine: admin apaga" on "Cosmoria".vitrine_ml;
create policy "vitrine: admin apaga" on "Cosmoria".vitrine_ml
  for delete to authenticated using ((select "Cosmoria".eh_admin()));
grant select on "Cosmoria".vitrine_ml to anon;
grant select, insert, update, delete on "Cosmoria".vitrine_ml to authenticated;
grant usage on schema "Cosmoria" to service_role;
grant select, insert, update on "Cosmoria".vitrine_ml to service_role;
grant select on "Cosmoria".perfis to service_role; -- a função confere se quem chamou é admin

-- 2) Chaves do Mercado Livre e ajustes (só o servidor lê; o site não enxerga) ----
create table if not exists "Cosmoria".ajustes_ml (
  chave text primary key,
  valor text not null default '',
  atualizado_em timestamptz not null default now()
);
alter table "Cosmoria".ajustes_ml enable row level security;
revoke all on "Cosmoria".ajustes_ml from anon, authenticated;
grant select, insert, update, delete on "Cosmoria".ajustes_ml to service_role;

-- segredo que a atualização diária usa para chamar a função (gerado uma vez)
insert into "Cosmoria".ajustes_ml (chave, valor)
values ('cron_segredo', encode(extensions.gen_random_bytes(24), 'hex'))
on conflict (chave) do nothing;

-- O admin cola o Client ID e a Secret Key do app do ML pelo painel. Ninguém consegue ler de volta.
create or replace function "Cosmoria".salvar_chaves_ml(p_client_id text, p_client_secret text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not "Cosmoria".eh_admin() then raise exception 'Apenas administradores podem fazer isso.'; end if;
  if coalesce(trim(p_client_id), '') = '' or coalesce(trim(p_client_secret), '') = '' then raise exception 'Preencha o Client ID e a Secret Key.'; end if;
  insert into "Cosmoria".ajustes_ml (chave, valor) values ('client_id', trim(p_client_id)), ('client_secret', trim(p_client_secret))
  on conflict (chave) do update set valor = excluded.valor, atualizado_em = now();
  -- chaves novas: o token antigo deixa de valer
  delete from "Cosmoria".ajustes_ml where chave in ('access_token', 'token_expira_em', 'refresh_token');
end $$;
revoke all on function "Cosmoria".salvar_chaves_ml(text, text) from public;
grant execute on function "Cosmoria".salvar_chaves_ml(text, text) to authenticated;

-- O painel só fica sabendo SE está configurado (nunca os valores).
create or replace function "Cosmoria".status_ml()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
begin
  if not "Cosmoria".eh_admin() then raise exception 'Apenas administradores podem fazer isso.'; end if;
  return jsonb_build_object(
    'tem_chaves', exists (select 1 from "Cosmoria".ajustes_ml where chave = 'client_secret' and valor <> ''),
    'autorizado', exists (select 1 from "Cosmoria".ajustes_ml where chave = 'refresh_token' and valor <> ''),
    'client_id', (select valor from "Cosmoria".ajustes_ml where chave = 'client_id'),
    'ultima_rodada', (select valor from "Cosmoria".ajustes_ml where chave = 'ultima_rodada'));
end $$;
revoke all on function "Cosmoria".status_ml() from public;
grant execute on function "Cosmoria".status_ml() to authenticated;

-- 3) Atualização automática diária (todo dia às 6h de Brasília = 9h UTC) -----------
-- Uma chamada por dia para a função, que atualiza todos os produtos com auto_atualizar = true
-- em lotes de 20 anúncios por pedido ao ML. Uso do plano gratuito: 1 chamada de função por dia.
create extension if not exists pg_cron;
create extension if not exists pg_net;

create or replace function "Cosmoria".atualizar_vitrine_ml_agendado()
returns bigint language plpgsql security definer set search_path = '' as $$
declare segredo text;
begin
  select valor into segredo from "Cosmoria".ajustes_ml where chave = 'cron_segredo';
  return net.http_post(
    url := 'https://cucabiqhtwqlxujgflnq.supabase.co/functions/v1/vitrine-ml',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-segredo', segredo),
    body := jsonb_build_object('acao', 'atualizar_todos', 'origem', 'agendado'),
    timeout_milliseconds := 120000);
end $$;
revoke all on function "Cosmoria".atualizar_vitrine_ml_agendado() from public, anon, authenticated;

select cron.unschedule(jobid) from cron.job where jobname = 'cosmoria-vitrine-ml-diaria';
select cron.schedule('cosmoria-vitrine-ml-diaria', '0 9 * * *', $$select "Cosmoria".atualizar_vitrine_ml_agendado()$$);

-- Para desligar a atualização diária:
--   select cron.unschedule('cosmoria-vitrine-ml-diaria');
-- Para apagar só os produtos de teste:
--   delete from "Cosmoria".vitrine_ml where exemplo;
