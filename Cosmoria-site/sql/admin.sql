-- =====================================================================
-- PORTAL COSMORIA · PAINEL DO ADMINISTRADOR (admin.html)
-- Cole tudo no Supabase > SQL Editor > New query e clique em "Run".
-- Tudo fica no esquema "Cosmoria". Pode rodar mais de uma vez sem problema.
-- Rode DEPOIS do frete.sql e do personalizados.sql.
-- =====================================================================

-- 1) Quem é administrador ----------------------------------------------
-- Usa a mesma coluna "papel" da tabela perfis que a página de artes já usa (papel = 'admin').
alter table "Cosmoria".perfis add column if not exists papel text not null default 'cliente';

create or replace function "Cosmoria".eh_admin()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from "Cosmoria".perfis where id = (select auth.uid()) and papel = 'admin');
$$;
revoke all on function "Cosmoria".eh_admin() from public;
grant execute on function "Cosmoria".eh_admin() to anon, authenticated;

-- Trava de segurança: um cliente comum NÃO consegue se transformar em admin
-- editando o próprio perfil. Só um admin (pelo painel) ou você (aqui no SQL Editor) muda o papel.
create or replace function "Cosmoria".proteger_papel()
returns trigger language plpgsql set search_path = '' as $$
begin
  if current_user in ('anon', 'authenticated') and not "Cosmoria".eh_admin() then
    if tg_op = 'INSERT' and new.papel = 'admin' then
      raise exception 'Sem permissão para definir o papel de administrador.';
    end if;
    if tg_op = 'UPDATE' and new.papel is distinct from old.papel then
      raise exception 'Sem permissão para mudar o papel da conta.';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists proteger_papel on "Cosmoria".perfis;
create trigger proteger_papel before insert or update on "Cosmoria".perfis
  for each row execute function "Cosmoria".proteger_papel();

-- Admin vê a lista de clientes (para dar ou tirar acesso de administrador)
alter table "Cosmoria".perfis enable row level security;
drop policy if exists "perfis: admin vê todos" on "Cosmoria".perfis;
create policy "perfis: admin vê todos" on "Cosmoria".perfis
  for select to authenticated using ((select "Cosmoria".eh_admin()));
drop policy if exists "perfis: admin edita todos" on "Cosmoria".perfis;
create policy "perfis: admin edita todos" on "Cosmoria".perfis
  for update to authenticated using ((select "Cosmoria".eh_admin())) with check ((select "Cosmoria".eh_admin()));
grant select, update on "Cosmoria".perfis to authenticated;

-- Dar ou tirar o acesso de administrador (só um admin consegue chamar)
create or replace function "Cosmoria".definir_admin(p_perfil uuid, p_admin boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not "Cosmoria".eh_admin() then raise exception 'Apenas administradores podem fazer isso.'; end if;
  if p_admin then
    update "Cosmoria".perfis set papel = 'admin' where id = p_perfil;
  else
    if (select count(*) from "Cosmoria".perfis where papel = 'admin' and id <> p_perfil) = 0 then
      raise exception 'A loja precisa ter pelo menos um administrador.';
    end if;
    update "Cosmoria".perfis set papel = default where id = p_perfil;
  end if;
end $$;
revoke all on function "Cosmoria".definir_admin(uuid, boolean) from public, anon;
grant execute on function "Cosmoria".definir_admin(uuid, boolean) to authenticated;

-- 2) Fotos dos produtos -------------------------------------------------
-- produtos.imagem = foto de capa pequena (usada nas vitrines).
-- produto_imagens = todas as fotos do produto, na ordem da galeria.
alter table "Cosmoria".produtos add column if not exists imagem text;
alter table "Cosmoria".produtos drop constraint if exists produtos_imagem_check;
alter table "Cosmoria".produtos add constraint produtos_imagem_check
  check (imagem is null or ((imagem like 'data:image/%' or imagem like 'https://%') and octet_length(imagem) < 400000));

create table if not exists "Cosmoria".produto_imagens (
  id bigint generated always as identity primary key,
  produto_id bigint not null references "Cosmoria".produtos(id) on delete cascade,
  ordem integer not null default 0,
  imagem text not null check ((imagem like 'data:image/%' or imagem like 'https://%') and octet_length(imagem) < 3000000),
  miniatura text check (miniatura is null or miniatura like 'data:image/%' or miniatura like 'https://%'),
  alt text,
  criado_em timestamptz not null default now()
);
comment on table "Cosmoria".produto_imagens is 'Fotos de cada produto (a primeira é a capa). Gerenciadas pelo painel admin.html.';
create index if not exists produto_imagens_produto_idx on "Cosmoria".produto_imagens(produto_id, ordem);
alter table "Cosmoria".produto_imagens enable row level security;
drop policy if exists "produto_imagens: leitura pública" on "Cosmoria".produto_imagens;
create policy "produto_imagens: leitura pública" on "Cosmoria".produto_imagens
  for select to anon, authenticated using (true);
grant select on "Cosmoria".produto_imagens to anon, authenticated;

-- 3) Textos do site e regras da loja ------------------------------------
create table if not exists "Cosmoria".textos_site (
  chave text primary key,
  grupo text not null,
  rotulo text not null,
  valor text not null default '',
  ajuda text,
  multilinha boolean not null default false,
  ordem integer not null default 0,
  atualizado_em timestamptz not null default now()
);
comment on table "Cosmoria".textos_site is 'Textos do site que o administrador muda pelo painel. Valor vazio = o site usa o texto padrão.';
insert into "Cosmoria".textos_site (chave, grupo, rotulo, valor, multilinha, ordem, ajuda) values
  ('faixa_topo',          'Topo e rodapé',      'Faixa dourada do topo', '', false, 1, 'Deixe vazio para o site montar sozinho com o frete grátis, as parcelas e o desconto no Pix.'),
  ('rodape_slogan',       'Topo e rodapé',      'Frase do rodapé', 'Artigos místicos e naturais para todos os caminhos.', false, 2, null),
  ('contato_whatsapp',    'Topo e rodapé',      'WhatsApp', '', false, 3, 'Ex.: (11) 99999-9999'),
  ('contato_email',       'Topo e rodapé',      'E-mail de atendimento', '', false, 4, null),
  ('inicio_olho',         'Página inicial',     'Chamada pequena acima do título', 'Nova coleção · Ervas da Lua Cheia', false, 10, null),
  ('inicio_titulo',       'Página inicial',     'Título principal', 'Atravesse o portal e encontre a sua magia', false, 11, null),
  ('inicio_subtitulo',    'Página inicial',     'Texto abaixo do título', 'Velas de cera vegetal, incensos de ervas, cristais da terra e peças com alma mística. Feitos com o que a natureza oferece, para quem pratica e para quem só gosta da estética.', true, 12, null),
  ('inicio_cat_titulo',   'Página inicial',     'Título das categorias', 'O que você procura?', false, 13, null),
  ('inicio_dest_titulo',  'Página inicial',     'Título dos destaques', 'Destaques do portal', false, 14, null),
  ('inicio_dest_texto',   'Página inicial',     'Texto dos destaques', 'Os favoritos da casa, feitos em pequenos lotes.', false, 15, null),
  ('inicio_col_titulo',   'Página inicial',     'Título das coleções', 'Escolha a sua energia', false, 16, null),
  ('inicio_col_texto',    'Página inicial',     'Texto das coleções', 'Coleções por intenção, por tema e pelos ciclos da natureza, para presentear ou para o seu altar.', true, 17, null),
  ('vant1_titulo',        'Vantagens (faixa verde clara)', 'Vantagem 1 · título', '🌿 Feito à mão', false, 20, null),
  ('vant1_texto',         'Vantagens (faixa verde clara)', 'Vantagem 1 · texto', 'Velas de cera vegetal e incensos de ervas, em pequenos lotes.', false, 21, null),
  ('vant2_titulo',        'Vantagens (faixa verde clara)', 'Vantagem 2 · título', '📦 Envio para todo o Brasil', false, 22, null),
  ('vant2_texto',         'Vantagens (faixa verde clara)', 'Vantagem 2 · texto', 'Embalagem com papel reciclado e código de rastreio por e-mail.', false, 23, null),
  ('vant3_titulo',        'Vantagens (faixa verde clara)', 'Vantagem 3 · título', '💳 Pix e cartão', false, 24, null),
  ('vant3_texto',         'Vantagens (faixa verde clara)', 'Vantagem 3 · texto', 'Desconto no Pix e parcelamento sem juros no cartão.', false, 25, null),
  ('vant4_titulo',        'Vantagens (faixa verde clara)', 'Vantagem 4 · título', '🌙 Para todos os caminhos', false, 26, null),
  ('vant4_texto',         'Vantagens (faixa verde clara)', 'Vantagem 4 · texto', 'Do curioso ao praticante, sem julgamento.', false, 27, null),
  ('news_titulo',         'Newsletter',         'Título', 'Receba a lua do mês', false, 30, null),
  ('news_texto',          'Newsletter',         'Texto', 'Lançamentos, rituais simples com ervas e cupons exclusivos, uma vez por lua.', true, 31, null),
  ('produto_trocas',      'Página do produto',  'Texto de "Trocas e envio"', 'Postagem em até 2 dias úteis após a confirmação do pagamento. Trocas em até 7 dias após o recebimento.', true, 40, 'Aparece em todos os produtos.')
on conflict (chave) do nothing;
alter table "Cosmoria".textos_site enable row level security;
drop policy if exists "textos: leitura pública" on "Cosmoria".textos_site;
create policy "textos: leitura pública" on "Cosmoria".textos_site for select to anon, authenticated using (true);
grant select on "Cosmoria".textos_site to anon, authenticated;

create table if not exists "Cosmoria".config_loja (
  id integer primary key default 1 check (id = 1),
  parcelas_sem_juros integer not null default 3 check (parcelas_sem_juros between 1 and 24),
  desconto_pix_pct numeric(5,2) not null default 5 check (desconto_pix_pct between 0 and 90),
  atualizado_em timestamptz not null default now()
);
comment on table "Cosmoria".config_loja is 'Regras gerais da loja exibidas no site: parcelas sem juros e desconto no Pix (em %).';
insert into "Cosmoria".config_loja (id) values (1) on conflict (id) do nothing;
alter table "Cosmoria".config_loja enable row level security;
drop policy if exists "config_loja: leitura pública" on "Cosmoria".config_loja;
create policy "config_loja: leitura pública" on "Cosmoria".config_loja for select to anon, authenticated using (true);
grant select on "Cosmoria".config_loja to anon, authenticated;

-- Tudo o que o site precisa saber em uma chamada só (textos, parcelas, Pix e frete grátis)
create or replace function "Cosmoria".config_publica()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare r jsonb;
begin
  select jsonb_build_object(
    'parcelas_sem_juros', c.parcelas_sem_juros,
    'desconto_pix_pct', c.desconto_pix_pct,
    'textos', coalesce((select jsonb_object_agg(t.chave, t.valor) from "Cosmoria".textos_site t where t.valor <> ''), '{}'::jsonb))
  into r from "Cosmoria".config_loja c where c.id = 1;
  begin
    r := r || jsonb_build_object('frete_gratis_acima_centavos', (select f.frete_gratis_acima_centavos from "Cosmoria".frete_config f limit 1));
  exception when others then null;  -- tabela de frete ainda não criada
  end;
  return r;
end $$;
revoke all on function "Cosmoria".config_publica() from public;
grant execute on function "Cosmoria".config_publica() to anon, authenticated;

-- "atualizado_em" se atualiza sozinho
create or replace function "Cosmoria".marcar_atualizado()
returns trigger language plpgsql set search_path = '' as $$
begin new.atualizado_em := now(); return new; end $$;
do $$
declare t text;
begin
  foreach t in array array['textos_site','config_loja','config_personalizacao','frete_config'] loop
    if to_regclass(format('"Cosmoria".%I', t)) is not null then
      execute format('drop trigger if exists marcar_atualizado on "Cosmoria".%I', t);
      execute format('create trigger marcar_atualizado before update on "Cosmoria".%I for each row execute function "Cosmoria".marcar_atualizado()', t);
    end if;
  end loop;
end $$;

-- 4) Permissões do administrador (RLS) ----------------------------------
-- Visitantes e clientes continuam só lendo o que já liam.
-- Quem tem papel = 'admin' pode criar, mudar e apagar nestas tabelas.
do $$
declare t text;
begin
  foreach t in array array['categorias','colecoes','produtos','variantes','produto_colecoes','produto_imagens',
                           'textos_site','config_loja','config_personalizacao','moldes_personalizacao',
                           'frete_config','frete_tabela_estados'] loop
    if to_regclass(format('"Cosmoria".%I', t)) is not null then
      execute format('alter table "Cosmoria".%I enable row level security', t);
      execute format('drop policy if exists "admin: gerencia tudo" on "Cosmoria".%I', t);
      execute format('create policy "admin: gerencia tudo" on "Cosmoria".%I for all to authenticated using ((select "Cosmoria".eh_admin())) with check ((select "Cosmoria".eh_admin()))', t);
      execute format('grant select, insert, update, delete on "Cosmoria".%I to authenticated', t);
    end if;
  end loop;

  -- Pedidos: admin vê todos e muda situação e rastreio
  if to_regclass('"Cosmoria".pedidos') is not null then
    drop policy if exists "pedidos: admin vê todos" on "Cosmoria".pedidos;
    create policy "pedidos: admin vê todos" on "Cosmoria".pedidos for select to authenticated using ((select "Cosmoria".eh_admin()));
    drop policy if exists "pedidos: admin atualiza" on "Cosmoria".pedidos;
    create policy "pedidos: admin atualiza" on "Cosmoria".pedidos for update to authenticated
      using ((select "Cosmoria".eh_admin())) with check ((select "Cosmoria".eh_admin()));
    grant select, update on "Cosmoria".pedidos to authenticated;
  end if;
  if to_regclass('"Cosmoria".itens_pedido') is not null then
    drop policy if exists "itens_pedido: admin vê todos" on "Cosmoria".itens_pedido;
    create policy "itens_pedido: admin vê todos" on "Cosmoria".itens_pedido for select to authenticated using ((select "Cosmoria".eh_admin()));
    grant select on "Cosmoria".itens_pedido to authenticated;
  end if;
  -- Newsletter: admin vê e remove e-mails
  if to_regclass('"Cosmoria".newsletter') is not null then
    drop policy if exists "newsletter: admin vê" on "Cosmoria".newsletter;
    create policy "newsletter: admin vê" on "Cosmoria".newsletter for select to authenticated using ((select "Cosmoria".eh_admin()));
    drop policy if exists "newsletter: admin remove" on "Cosmoria".newsletter;
    create policy "newsletter: admin remove" on "Cosmoria".newsletter for delete to authenticated using ((select "Cosmoria".eh_admin()));
    grant select, delete on "Cosmoria".newsletter to authenticated;
  end if;
end $$;

-- ids automáticos (necessário para cadastrar produtos, categorias etc. pelo painel)
grant usage on all sequences in schema "Cosmoria" to authenticated;

-- 5) Seu primeiro administrador ------------------------------------------
-- Troque pelo e-mail com que você entra no site e rode esta linha.
-- (Depois, você dá acesso a outras pessoas pelo próprio painel, em "Usuários".)
-- update "Cosmoria".perfis set papel = 'admin' where email = 'SEU E-MAIL';

-- Conferência: deve listar os administradores atuais
select nome, email, papel from "Cosmoria".perfis where papel = 'admin';
