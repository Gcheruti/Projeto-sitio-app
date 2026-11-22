-- ============================================================
-- HISTÓRICO DE TESTE (rode DEPOIS de 00_zerar_tudo.sql e seed_teste.sql)
-- Gera: comandas ativas (com pedidos em preparo), ~140 vendas fechadas
-- nos últimos 30 dias, reposições, baixas, notas importadas, notificações
-- e atividades dos colaboradores. Dados aleatórios, só para teste.
-- Para apagar tudo isto de novo: rode 00_zerar_tudo.sql.
-- ============================================================
alter table public.itens_comanda
  add column if not exists processual boolean not null default false,
  add column if not exists status_preparo text;

create table if not exists public.notificacoes (
  id text primary key, titulo text not null, descricao text not null default '',
  ativa boolean not null default true, local text,
  criado_em timestamptz not null default now()
);
alter table public.notificacoes add column if not exists editado_por text;
alter table public.notificacoes add column if not exists editado_em  timestamptz;
alter table public.notificacoes add column if not exists criado_por  text;
alter table public.notificacoes add column if not exists excluida boolean not null default false;

select setseed(0.42);

-- ---------------- Notificações ----------------
insert into public.notificacoes (id, titulo, descricao, ativa, local, criado_por, editado_por) values
  ('teste_1','Manutenção do forno','Forno em manutenção amanhã das 14h às 16h.',true,'restaurante','Administrador','Administrador'),
  ('teste_2','Novo prato do dia','Costela ao molho barbecue disponível hoje.',true,'restaurante','Staff','Staff'),
  ('teste_3','Chegada de cristais','Lote novo de ametista e quartzo rosa na Cosmória.',true,'mercado','Administrador','Administrador'),
  ('teste_4','Agenda de tarô lotada','Sábado: todos os horários de atendimento reservados.',true,'casa_bruxa','Staff','Staff'),
  ('teste_5','Aula de Tarô Iniciante','Turma de domingo com poucas vagas restantes.',true,'gruta','Administrador','Administrador'),
  ('teste_6','Pedido de compra enviado','Pedido de IPA e vinhos enviado ao fornecedor.',false,'restaurante','Administrador','Administrador'),
  ('teste_7','Reunião da equipe','Segunda, 9h, alinhamento geral.',true,null,'Administrador','Administrador')
on conflict (id) do nothing;

-- ---------------- Comandas ativas (6) ----------------
do $$
declare
  i int; v_cod text; n int;
begin
  for i in 1..6 loop
    v_cod := 'A' || lpad(i::text, 3, '0');
    insert into public.comandas (codigo, status, pagamento) values (v_cod, 'ativa', null);
    n := 2 + floor(random() * 3)::int;
    insert into public.itens_comanda
      (comanda_codigo, produto_id, nome, quantidade, preco, processual, status_preparo)
    select v_cod, p.id, p.nome, 1 + floor(random() * 2)::int, p.preco, p.processual,
           case when p.processual
                then (array['aberto','preparo','finalizado'])[1 + floor(random() * 3)::int]
                else null end
    from public.produtos p
    where p.publico and p.codigo_barras like 'TESTE-%' and p.ambiente in ('Salão','Loja')
    order by random() limit n;
  end loop;
  -- uma comanda vazia
  insert into public.comandas (codigo, status, pagamento) values ('A007', 'ativa', null);
end $$;

-- ---------------- Vendas fechadas (30 dias) ----------------
do $$
declare
  i int; v_cod text; v_id public.comandas.id%type; v_dt timestamptz;
  v_pag text; v_itens jsonb; v_total numeric; n int;
begin
  for i in 1..140 loop
    v_cod := 'H' || lpad(i::text, 3, '0');
    v_dt := date_trunc('day', now())
            - (floor(random() * 30)::int) * interval '1 day'
            + (11 + floor(random() * 11)::int) * interval '1 hour'
            + floor(random() * 60)::int * interval '1 minute';
    if v_dt > now() then v_dt := v_dt - interval '1 day'; end if;
    v_pag := (array['PIX','CARTAO','DINHEIRO'])[1 + floor(random() * 3)::int];
    n := 1 + floor(random() * 4)::int;

    insert into public.comandas (codigo, status, pagamento)
      values (v_cod, 'inativa', v_pag) returning id into v_id;

    create temp table if not exists _pick on commit drop as
      select p.id as pid, p.nome, p.preco, 1 as q
      from public.produtos p limit 0;
    truncate _pick;
    insert into _pick
      select p.id, p.nome, p.preco, 1 + floor(random() * 3)::int
      from public.produtos p
      where p.publico and p.codigo_barras like 'TESTE-%'
      order by random() limit n;

    select jsonb_agg(jsonb_build_object(
             'nome', nome, 'quantidade', q, 'preco_unitario', preco,
             'subtotal', preco * q, 'produto_id', pid)),
           sum(preco * q)
      into v_itens, v_total from _pick;

    insert into public.comandas_historico
      (comanda_id, comanda_codigo, codigo, pagamento, total, total_itens,
       valor_cobrado, itens_json, fechado_em)
    values (v_id, v_cod, v_cod, v_pag, v_total, v_total, v_total, v_itens, v_dt);

    insert into public.itens_comanda (comanda_codigo, produto_id, nome, quantidade, preco)
      select v_cod, pid, nome, q, preco from _pick;
  end loop;
end $$;

-- ---------------- Reposições (aquisições) ----------------
do $$
declare
  i int; v_rep uuid; v_dt timestamptz; v_total numeric;
begin
  for i in 1..9 loop
    v_dt := now() - (i * 3 + floor(random() * 3)::int) * interval '1 day'
            + interval '10 hours';
    create temp table if not exists _rep on commit drop as
      select p.id as pid, p.nome, 1 as q, 1 as antes, 1 as depois,
             0::numeric as custo
      from public.produtos p limit 0;
    truncate _rep;
    insert into _rep
      select p.id, p.nome, q.q, greatest(p.quantidade - q.q, 0), p.quantidade,
             round((p.preco * 0.45 * q.q)::numeric, 2)
      from (select p.* from public.produtos p
            where p.codigo_barras like 'TESTE-%' and p.controla_estoque
            order by random() limit 3 + floor(random() * 4)::int) p
      cross join lateral (select 5 + floor(random() * 26)::int as q) q;
    select coalesce(sum(custo), 0) into v_total from _rep;
    insert into public.reposicoes (observacao, valor_investido, criado_em)
      values ('Reposição de teste #' || i, v_total, v_dt) returning id into v_rep;
    insert into public.reposicoes_itens
      (reposicao_id, produto_id, nome, quantidade_entrada, estoque_antes, estoque_depois)
      select v_rep, pid, nome, q, antes, depois from _rep;
  end loop;
end $$;

-- ---------------- Baixas de estoque ----------------
insert into public.baixas_estoque (produto_id, nome, quantidade, motivo, criado_em)
select p.id, p.nome, 1 + floor(random() * 3)::int,
       (array['Validade','Perda','Quebra','Consumo interno'])[1 + floor(random() * 4)::int],
       now() - floor(random() * 30)::int * interval '1 day'
         - floor(random() * 10)::int * interval '1 hour'
from public.produtos p
cross join generate_series(1, 2) g
where p.codigo_barras like 'TESTE-%' and p.controla_estoque
  and p.ambiente in ('Salão','Loja') and random() < 0.18;

insert into public.baixas_estoque (produto_id, nome, quantidade, motivo, criado_em)
select p.id, p.nome, 3 + floor(random() * 6)::int, 'Preparo de Pudim de leite',
       now() - g * interval '2 days'
from public.produtos p cross join generate_series(1, 6) g
where p.nome in ('Ovos (unidade)','Leite condensado (lata)');

-- ---------------- Notas importadas ----------------
do $$
declare v_nota uuid; v_rep text;
begin
  select id::text into v_rep from public.reposicoes order by criado_em desc limit 1;

  insert into public.notas_importadas
    (origem, status, chave_acesso, total_nota, valor_investido, texto_bruto,
     qtd_fotos, reposicao_id, criado_em, confirmado_em)
  values ('qr','confirmada','35261100000000000000650010000012341000012345',
          187.40, 187.40, null, 0, v_rep, now() - interval '3 days', now() - interval '3 days')
  returning id into v_nota;
  insert into public.notas_importadas_itens (nota_id, ordem, nome, quantidade, valor_unitario, valor_total) values
    (v_nota,1,'LEITE CONDENSADO 395G',12,6.90,82.80),
    (v_nota,2,'OVOS BRANCOS CX 30',3,24.90,74.70),
    (v_nota,3,'FARINHA DE TRIGO 1KG',5,5.98,29.90);

  insert into public.notas_importadas
    (origem, status, total_nota, valor_investido, texto_bruto, qtd_fotos,
     criado_em, confirmado_em)
  values ('foto','confirmada', 312.00, 312.00,
          E'ATACADO BOM PREÇO\nVINHO TINTO 750ML 6 x 32,00\nCERVEJA IPA 24 x 5,00',
          2, now() - interval '9 days', now() - interval '9 days')
  returning id into v_nota;
  insert into public.notas_importadas_itens (nota_id, ordem, nome, quantidade, valor_unitario, valor_total) values
    (v_nota,1,'VINHO TINTO 750ML',6,32.00,192.00),
    (v_nota,2,'CERVEJA IPA LATA',24,5.00,120.00);

  -- rascunho pendente (aparece na lista de notas pendentes da Reposição)
  insert into public.notas_importadas
    (origem, status, total_nota, texto_bruto, qtd_fotos, criado_em)
  values ('foto','rascunho', 96.50,
          E'EMPORIO DAS ERVAS\nALECRIM SECO 10 x 4,50\nLAVANDA SECA 10 x 5,15',
          1, now() - interval '1 hour')
  returning id into v_nota;
  insert into public.notas_importadas_itens (nota_id, ordem, nome, quantidade, valor_unitario, valor_total) values
    (v_nota,1,'ALECRIM SECO',10,4.50,45.00),
    (v_nota,2,'LAVANDA SECA',10,5.15,51.50);

  insert into public.notas_correcoes
    (nota_id, origem, texto_bruto, itens_lidos, itens_finais, total_lido, total_final)
  values (v_nota,'foto','ALECRIM SECO 10 x 4,50',
          '[{"nome":"ALECRIM SEC0","quantidade":10}]'::jsonb,
          '[{"nome":"ALECRIM SECO","quantidade":10}]'::jsonb, 90.00, 96.50);
end $$;

-- ---------------- Atividades dos colaboradores ----------------
insert into public.atividades
  (criado_em, usuario_id, usuario_nome, usuario_login, acao, entidade, detalhe, comanda_codigo)
select now() - (floor(random() * 14)::int) * interval '1 day'
              - floor(random() * 600)::int * interval '1 minute',
       u.id::text, u.nome, u.login, a.acao, a.entidade, a.detalhe, a.cod
from public.usuarios u
cross join (values
  ('login','sessao','Entrou no app',null),
  ('comanda_criada','comanda','Criou a comanda A001','A001'),
  ('comanda_item_add','comanda','Adicionou 1x Hambúrguer do Caldeirão na comanda A002','A002'),
  ('comanda_item_add','comanda','Adicionou 2x Cerveja artesanal IPA na comanda A003','A003'),
  ('pedido_status','comanda','Pudim de leite (comanda A004) -> preparo','A004'),
  ('comanda_fechada','comanda','Fechou a comanda H010 (PIX)','H010'),
  ('comanda_excluida','comanda','Excluiu a comanda X001','X001'),
  ('preparo','produto','Preparou 8 x Pudim de leite (usou 6x Ovos (unidade))',null),
  ('baixa_estoque','produto','Baixa de 2 x Vela de soja lavanda (Quebra)',null),
  ('reposicao','reposicao','Reposição de 4 item(ns), investido R$ 187.40',null),
  ('notificacao_criada','notificacao','Criou "Manutenção do forno"',null),
  ('produto_editado','produto','Editou "Ametista bruta" (estoque 15)',null),
  ('logout','sessao','Saiu do app',null)
) as a(acao, entidade, detalhe, cod)
cross join generate_series(1, 3) g
where u.ativo;
