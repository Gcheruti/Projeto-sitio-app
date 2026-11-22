-- DESATIVADO (modo vitrine, nov/2026): frete agora é do Mercado Livre. As tabelas de frete continuam no banco, sem uso. Pode voltar.
-- =====================================================================
-- FRETE DA LOJA (schema "Cosmoria") — pode rodar mais de uma vez sem estragar nada.
-- Cole no Supabase: SQL Editor > New query > Run.
-- Valores são de TESTE (ilustrativos).
-- =====================================================================

-- 1) Peso e medidas dos produtos (padrão de teste: 300 g, 10 x 15 x 10 cm)
alter table "Cosmoria".produtos
  add column if not exists peso_gramas integer not null default 300 check (peso_gramas > 0),
  add column if not exists altura_cm numeric(6,1) not null default 10 check (altura_cm > 0),
  add column if not exists largura_cm numeric(6,1) not null default 15 check (largura_cm > 0),
  add column if not exists comprimento_cm numeric(6,1) not null default 10 check (comprimento_cm > 0);

-- Só preencha nas variantes quando uma opção pesar diferente do produto
alter table "Cosmoria".variantes
  add column if not exists peso_gramas integer check (peso_gramas > 0),
  add column if not exists altura_cm numeric(6,1) check (altura_cm > 0),
  add column if not exists largura_cm numeric(6,1) check (largura_cm > 0),
  add column if not exists comprimento_cm numeric(6,1) check (comprimento_cm > 0);

-- 2) Como cada pedido vai ser entregue
alter table "Cosmoria".pedidos
  add column if not exists frete_modalidade text check (frete_modalidade in ('motoboy','pac','sedex')),
  add column if not exists frete_prazo_dias integer,
  add column if not exists frete_distancia_km numeric(6,1);

-- 3) Regras do frete (uma linha só)
create table if not exists "Cosmoria".frete_config (
  id boolean primary key default true check (id),
  cep_origem text not null,
  origem_lat double precision not null,
  origem_lng double precision not null,
  preco_km_centavos integer not null default 100,          -- R$ 1,00 por km
  km_gratis numeric(5,1) not null default 5,               -- até 5 km grátis
  km_maximo numeric(5,1) not null default 20,              -- motoboy até 20 km
  fator_rota numeric(4,2) not null default 1.3,            -- linha reta x 1,3
  frete_gratis_acima_centavos integer not null default 15000, -- R$ 150
  motoboy_prazo_dias integer not null default 1,
  manuseio_dias integer not null default 1,                -- somado ao prazo dos Correios
  pac_adicional_kg_centavos integer not null default 400,  -- por kg acima de 1 kg
  sedex_adicional_kg_centavos integer not null default 700,
  atualizado_em timestamptz not null default now()
);
-- Ponto de partida de TESTE: Av. Paulista. Troque pelo CEP real quando abrir a loja.
insert into "Cosmoria".frete_config (cep_origem, origem_lat, origem_lng)
values ('01310-100', -23.5614, -46.6559)
on conflict (id) do nothing;

-- 4) Tabela provisória dos Correios por estado (até 1 kg; valores ilustrativos)
create table if not exists "Cosmoria".frete_tabela_estados (
  uf char(2) primary key,
  pac_centavos integer not null,
  pac_prazo_dias integer not null,
  sedex_centavos integer not null,
  sedex_prazo_dias integer not null
);
insert into "Cosmoria".frete_tabela_estados values
 ('SP',1800,5,2800,2),
 ('RJ',2400,7,3800,3),('MG',2400,7,3800,3),('ES',2400,7,3800,3),
 ('PR',2600,8,4200,4),('SC',2600,8,4200,4),('RS',2600,8,4200,4),
 ('DF',2900,9,4800,4),('GO',2900,9,4800,4),('MT',2900,9,4800,4),('MS',2900,9,4800,4),
 ('BA',3200,10,5600,5),('SE',3200,10,5600,5),('AL',3200,10,5600,5),('PE',3200,10,5600,5),('PB',3200,10,5600,5),
 ('RN',3200,10,5600,5),('CE',3200,10,5600,5),('PI',3200,10,5600,5),('MA',3200,10,5600,5),
 ('PA',3800,12,6800,6),('AP',3800,12,6800,6),('AM',3800,12,6800,6),('RR',3800,12,6800,6),
 ('AC',3800,12,6800,6),('RO',3800,12,6800,6),('TO',3800,12,6800,6)
on conflict (uf) do nothing;

-- 5) Distâncias já calculadas (para não consultar o mapa de novo)
create table if not exists "Cosmoria".frete_distancias (
  cep text primary key check (cep ~ '^[0-9]{8}$'),
  lat double precision,
  lng double precision,
  km numeric(7,1),
  metodo text not null default 'linha_reta',
  atualizado_em timestamptz not null default now()
);

-- 6) Segurança: só a função de frete (no servidor) lê e grava essas tabelas
alter table "Cosmoria".frete_config enable row level security;
alter table "Cosmoria".frete_tabela_estados enable row level security;
alter table "Cosmoria".frete_distancias enable row level security;

-- =====================================================================
-- EXEMPLOS DE AJUSTE (rode só o que quiser mudar)
-- update "Cosmoria".frete_config set preco_km_centavos = 150;        -- R$ 1,50/km
-- update "Cosmoria".frete_config set cep_origem = '00000-000', origem_lat = -23.5, origem_lng = -46.6;
-- update "Cosmoria".frete_tabela_estados set pac_centavos = 2000 where uf = 'SP';
-- update "Cosmoria".produtos set peso_gramas = 450 where slug = 'vela-lua-cheia';
-- =====================================================================
