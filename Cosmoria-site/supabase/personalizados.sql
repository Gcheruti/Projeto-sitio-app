-- =====================================================================
-- PORTAL COSMORIA · PRODUTOS PERSONALIZADOS
-- Cole tudo no Supabase > SQL Editor > New query e clique em "Run".
-- Tudo fica no esquema "Cosmoria". Pode rodar mais de uma vez sem problema.
-- =====================================================================

-- 1) Produtos personalizáveis, cores e tamanhos -------------------------
alter table "Cosmoria".produtos add column if not exists modelo_personalizado text;
alter table "Cosmoria".produtos drop constraint if exists produtos_modelo_personalizado_check;
alter table "Cosmoria".produtos add constraint produtos_modelo_personalizado_check
  check (modelo_personalizado in ('camiseta','babylook','moletom','caneca','ecobag'));
comment on column "Cosmoria".produtos.modelo_personalizado is 'Se preenchido, o produto abre no editor de personalizados (personalizar.html) com este molde.';

alter table "Cosmoria".variantes add column if not exists cor text;
alter table "Cosmoria".variantes add column if not exists cor_hex text;
alter table "Cosmoria".variantes add column if not exists tamanho text;
alter table "Cosmoria".variantes drop constraint if exists variantes_cor_hex_check;
alter table "Cosmoria".variantes add constraint variantes_cor_hex_check check (cor_hex ~ '^#[0-9A-Fa-f]{6}$');

-- 2) Preço da personalização: por cm² do espaço ocupado pela arte (você pode mudar aqui) --
-- Em cada lado do produto, o site mede o retângulo que envolve toda a arte e cobra por cm².
-- centavos_por_cm2: 10 = R$ 0,10 por cm²  ·  minimo_por_lado_centavos: 500 = R$ 5,00 por lado com arte
create table if not exists "Cosmoria".config_personalizacao (
  id integer primary key default 1 check (id = 1),
  centavos_por_cm2 numeric(8,2) not null default 10 check (centavos_por_cm2 >= 0),
  minimo_por_lado_centavos integer not null default 500 check (minimo_por_lado_centavos >= 0),
  atualizado_em timestamptz not null default now()
);
comment on table "Cosmoria".config_personalizacao is 'Preço da personalização: centavos por cm² do espaço ocupado pela arte em cada lado, e valor mínimo por lado.';
insert into "Cosmoria".config_personalizacao (id) values (1) on conflict (id) do nothing;
alter table "Cosmoria".config_personalizacao enable row level security;
drop policy if exists "config: leitura pública" on "Cosmoria".config_personalizacao;
create policy "config: leitura pública" on "Cosmoria".config_personalizacao for select to anon, authenticated using (true);
grant select on "Cosmoria".config_personalizacao to anon, authenticated;
-- a tabela antiga de preço por tipo de elemento não é mais usada
drop table if exists "Cosmoria".precos_personalizacao;

-- 3) Tamanho real (cm) da área de impressão de cada produto -------------
-- Roupas: o corpo todo, sem as mangas. Caneca: uma faixa só que dá a volta inteira (20 x 8,6 cm).
-- O site usa a largura; a altura é calculada pela proporção do desenho.
create table if not exists "Cosmoria".moldes_personalizacao (
  modelo text not null,
  lado text not null check (lado in ('frente','verso')),
  rotulo text not null,
  largura_cm numeric(5,1) not null check (largura_cm > 0),
  altura_cm numeric(5,1) not null check (altura_cm > 0),
  primary key (modelo, lado)
);
comment on table "Cosmoria".moldes_personalizacao is 'Tamanho real (cm) da área de impressão de cada molde do editor. O site usa a largura (a altura vem da proporção do desenho).';
insert into "Cosmoria".moldes_personalizacao values
  ('camiseta','frente','Frente',52,74),('camiseta','verso','Costas',52,74),
  ('babylook','frente','Frente',46,65.2),('babylook','verso','Costas',46,65.2),
  ('moletom','frente','Frente',58,76.4),('moletom','verso','Costas',58,75.8),
  ('caneca','frente','Volta inteira',20,8.6),
  ('ecobag','frente','Frente',30,38),('ecobag','verso','Verso',30,38)
on conflict (modelo, lado) do update set rotulo = excluded.rotulo, largura_cm = excluded.largura_cm, altura_cm = excluded.altura_cm;
delete from "Cosmoria".moldes_personalizacao where modelo = 'caneca' and lado = 'verso';
alter table "Cosmoria".moldes_personalizacao enable row level security;
drop policy if exists "moldes: leitura pública" on "Cosmoria".moldes_personalizacao;
create policy "moldes: leitura pública" on "Cosmoria".moldes_personalizacao for select to anon, authenticated using (true);
grant select on "Cosmoria".moldes_personalizacao to anon, authenticated;

-- 4) Artes criadas pelos clientes ---------------------------------------
create table if not exists "Cosmoria".personalizacoes (
  id uuid primary key default gen_random_uuid(),
  criado_em timestamptz not null default now(),
  cliente_id uuid references auth.users(id) on delete set null,
  produto_id bigint references "Cosmoria".produtos(id) on delete set null,
  variante_id bigint references "Cosmoria".variantes(id) on delete set null,
  produto_nome text not null,
  variante_nome text,
  modelo text not null,
  dados jsonb not null default '{}'::jsonb,
  lados_usados text[] not null default '{}',
  miniatura text, previa_frente text, previa_verso text, arte_frente text, arte_verso text,
  status text not null default 'no_carrinho'
);
alter table "Cosmoria".personalizacoes
  add column if not exists cliente_nome text,
  add column if not exists cliente_contato text,
  add column if not exists observacoes text,
  add column if not exists quantidade integer not null default 1,
  add column if not exists preco_base_centavos integer,
  add column if not exists preco_adicional_centavos integer,
  add column if not exists preco_total_centavos integer,
  add column if not exists orcamento jsonb not null default '[]'::jsonb,
  add column if not exists elementos jsonb not null default '[]'::jsonb,
  add column if not exists imagens_enviadas jsonb not null default '[]'::jsonb,
  add column if not exists notificado_em timestamptz,
  add column if not exists notificacao jsonb;
comment on table "Cosmoria".personalizacoes is 'Artes do editor de personalizados. arte_* = PNG da área de impressão; previa_* = produto com a arte; imagens_enviadas = fotos originais do cliente; elementos = textos, fontes, cores e medidas.';

alter table "Cosmoria".personalizacoes drop constraint if exists personalizacoes_status_check;
alter table "Cosmoria".personalizacoes add constraint personalizacoes_status_check
  check (status in ('no_carrinho','em_pedido','em_producao','concluida','descartada'));
alter table "Cosmoria".personalizacoes drop constraint if exists imagens_validas;
alter table "Cosmoria".personalizacoes add constraint imagens_validas check (
  coalesce(miniatura,'data:image/') like 'data:image/%' and coalesce(previa_frente,'data:image/') like 'data:image/%' and
  coalesce(previa_verso,'data:image/') like 'data:image/%' and coalesce(arte_frente,'data:image/') like 'data:image/%' and
  coalesce(arte_verso,'data:image/') like 'data:image/%');
alter table "Cosmoria".personalizacoes drop constraint if exists tamanho_maximo;
alter table "Cosmoria".personalizacoes add constraint tamanho_maximo check (
  octet_length(dados::text) + octet_length(imagens_enviadas::text) + coalesce(octet_length(previa_frente),0) + coalesce(octet_length(previa_verso),0) +
  coalesce(octet_length(arte_frente),0) + coalesce(octet_length(arte_verso),0) + coalesce(octet_length(miniatura),0) < 30000000);
alter table "Cosmoria".personalizacoes drop constraint if exists contato_obrigatorio;
alter table "Cosmoria".personalizacoes add constraint contato_obrigatorio
  check (length(trim(coalesce(cliente_nome,''))) > 0 and length(trim(coalesce(cliente_contato,''))) > 0) not valid;
alter table "Cosmoria".personalizacoes drop constraint if exists quantidade_valida;
alter table "Cosmoria".personalizacoes add constraint quantidade_valida check (quantidade between 1 and 999);

create index if not exists personalizacoes_cliente_idx on "Cosmoria".personalizacoes(cliente_id);
create index if not exists personalizacoes_criado_idx on "Cosmoria".personalizacoes(criado_em desc);

-- liga a arte ao item do pedido (o checkout vai preencher)
alter table "Cosmoria".itens_pedido add column if not exists personalizacao_id uuid references "Cosmoria".personalizacoes(id) on delete set null;
create index if not exists itens_pedido_personalizacao_idx on "Cosmoria".itens_pedido(personalizacao_id);

-- 5) Segurança: quem pode salvar e ver as artes ------------------------
alter table "Cosmoria".personalizacoes enable row level security;
drop policy if exists "personalizacoes: qualquer um salva a própria arte" on "Cosmoria".personalizacoes;
drop policy if exists "personalizacoes: cliente logado salva a própria arte" on "Cosmoria".personalizacoes;
create policy "personalizacoes: cliente logado salva a própria arte" on "Cosmoria".personalizacoes
  for insert to authenticated
  with check (status = 'no_carrinho' and notificado_em is null and notificacao is null
              and cliente_id = (select auth.uid()));
drop policy if exists "personalizacoes: cliente vê as próprias, admin vê todas" on "Cosmoria".personalizacoes;
create policy "personalizacoes: cliente vê as próprias, admin vê todas" on "Cosmoria".personalizacoes
  for select to authenticated
  using (cliente_id = (select auth.uid()) or exists (select 1 from "Cosmoria".perfis p where p.id = (select auth.uid()) and p.papel = 'admin'));
drop policy if exists "personalizacoes: admin muda o status" on "Cosmoria".personalizacoes;
create policy "personalizacoes: admin muda o status" on "Cosmoria".personalizacoes
  for update to authenticated
  using (exists (select 1 from "Cosmoria".perfis p where p.id = (select auth.uid()) and p.papel = 'admin'))
  with check (exists (select 1 from "Cosmoria".perfis p where p.id = (select auth.uid()) and p.papel = 'admin'));
revoke insert on "Cosmoria".personalizacoes from anon;
grant insert on "Cosmoria".personalizacoes to authenticated;
grant select, update on "Cosmoria".personalizacoes to authenticated;

-- 6) Aviso automático ao designer (Telegram + e-mail) ------------------
-- Quando uma arte nova é salva, chama a função "cosmoria-designer" do Supabase,
-- usando o mesmo segredo que o aviso do Telegram que você já tem.
create or replace function "Cosmoria".avisar_designer()
returns trigger language plpgsql security definer set search_path = '' as $$
declare s text;
begin
  select decrypted_secret into s from vault.decrypted_secrets where name = 'telegram_webhook_secret';
  perform net.http_post(
    url := 'https://cucabiqhtwqlxujgflnq.supabase.co/functions/v1/cosmoria-designer',
    headers := jsonb_build_object('Content-Type','application/json','x-webhook-secret', s),
    body := jsonb_build_object('id', new.id),
    timeout_milliseconds := 20000);
  return new;
exception when others then
  return new;
end $$;
revoke all on function "Cosmoria".avisar_designer() from public, anon, authenticated;
drop trigger if exists avisar_designer on "Cosmoria".personalizacoes;
create trigger avisar_designer after insert on "Cosmoria".personalizacoes
  for each row execute function "Cosmoria".avisar_designer();

-- 7) Categoria e produtos de TESTE (exemplo = true) ---------------------
insert into "Cosmoria".categorias (slug, nome, descricao, ordem, icone)
values ('personalizados', 'Personalizados', 'Crie a sua peça: escolha o produto e coloque suas fotos, frases e símbolos.', 0, '🎨')
on conflict (slug) do nothing;

with cat as (select id from "Cosmoria".categorias where slug = 'personalizados'),
novos(slug, nome, descricao, preco, icone, modelo, sku) as (values
  ('camiseta-personalizada', 'Camiseta personalizada', 'Camiseta 100% algodão para você estampar do seu jeito, na frente e nas costas. Estampa feita sob encomenda.', 7990, '👕', 'camiseta', 'PERS-CAM'),
  ('baby-look-personalizada', 'Baby look personalizada', 'Baby look de algodão com caimento acinturado. Coloque sua foto, frase ou símbolo na frente e nas costas.', 6990, '👚', 'babylook', 'PERS-BABY'),
  ('moletom-personalizado', 'Moletom personalizado', 'Moletom com capuz e bolso canguru, felpado por dentro. Estampa na frente e nas costas.', 16990, '🧥', 'moletom', 'PERS-MOL'),
  ('caneca-personalizada', 'Caneca personalizada', 'Caneca de cerâmica de 325 ml. A estampa dá a volta inteira na caneca.', 4990, '☕', 'caneca', 'PERS-CAN'),
  ('ecobag-personalizada', 'Ecobag personalizada', 'Ecobag de algodão cru, resistente, para estampar dos dois lados.', 4490, '👜', 'ecobag', 'PERS-ECO'))
insert into "Cosmoria".produtos (slug, nome, descricao, categoria_id, preco_centavos, icone, modelo_personalizado, sku, exemplo, selo, destaque)
select slug, nome, descricao, (select id from cat), preco, icone, modelo, sku, true, 'Personalize', false from novos
on conflict (slug) do nothing;

with cores(modelo, cor, hex, ordem) as (values
  ('camiseta','Branca','#F4F3EF',1),('camiseta','Preta','#1C1C1E',2),('camiseta','Verde musgo','#3F5B45',3),('camiseta','Areia','#D9CBB0',4),('camiseta','Lilás','#B9A6D6',5),
  ('babylook','Branca','#F4F3EF',1),('babylook','Preta','#1C1C1E',2),('babylook','Lilás','#B9A6D6',3),('babylook','Rosa antigo','#D8A7A0',4),
  ('moletom','Preto','#1C1C1E',1),('moletom','Cinza mescla','#9C9EA0',2),('moletom','Verde floresta','#26402F',3),('moletom','Off-white','#EDE7DA',4),
  ('caneca','Branca','#F7F7F5',1),('caneca','Preta','#1C1C1E',2),
  ('ecobag','Cru','#EBE1CB',1),('ecobag','Preta','#1C1C1E',2)),
tams(modelo, tamanho, ordem) as (values
  ('camiseta','P',1),('camiseta','M',2),('camiseta','G',3),('camiseta','GG',4),
  ('babylook','P',1),('babylook','M',2),('babylook','G',3),
  ('moletom','P',1),('moletom','M',2),('moletom','G',3),('moletom','GG',4),
  ('caneca',null,1),('ecobag',null,1))
insert into "Cosmoria".variantes (produto_id, nome, sku, estoque, ordem, cor, cor_hex, tamanho)
select p.id, c.cor || coalesce(' · ' || t.tamanho, ''),
       p.sku || '-' || upper(left(regexp_replace(translate(c.cor,'áâãéêíóôúç','aaaeeioouc'),'[^A-Za-z]','','g'),4)) || coalesce('-' || t.tamanho, ''),
       case when (c.ordem * 7 + t.ordem * 3) % 11 = 0 then 0 else 4 + (c.ordem * 5 + t.ordem * 2) % 12 end,
       c.ordem * 10 + t.ordem, c.cor, c.hex, t.tamanho
from "Cosmoria".produtos p
join cores c on c.modelo = p.modelo_personalizado
join tams t on t.modelo = p.modelo_personalizado
where p.slug in ('camiseta-personalizada','baby-look-personalizada','moletom-personalizado','caneca-personalizada','ecobag-personalizada')
  and not exists (select 1 from "Cosmoria".variantes v where v.produto_id = p.id);

update "Cosmoria".produtos set descricao = 'Caneca de cerâmica de 325 ml. A estampa dá a volta inteira na caneca.' where slug = 'caneca-personalizada';

-- Conferência: deve listar 5 produtos e o preço por cm²
select 'produto' as tipo, nome as item from "Cosmoria".produtos where modelo_personalizado is not null
union all select 'preço', 'R$ ' || to_char(centavos_por_cm2 / 100.0, 'FM990D00') || ' por cm², mínimo R$ ' || to_char(minimo_por_lado_centavos / 100.0, 'FM990D00') || ' por lado' from "Cosmoria".config_personalizacao;
