-- ============================================================
-- DADOS DE TESTE das novidades da 1.0.6. Rode DEPOIS de:
--   00_zerar_tudo, seed_teste, seed_historico, seed_financeiro
-- e dos SQLs: lotes_validade, produtos_dias_validade, agenda,
-- freelancers, comandas_v2 e totem.
-- Não mexe nas contas Adm/Staff. Para apagar tudo: 00_zerar_tudo.sql.
--
-- Contas criadas (login / senha):
--   maria, joao, ana, pedro  /  freela   (freelancers)
--   totem                    /  totem    (modo totem)
-- Comandas novas para testar o totem (digite o código): B001, B002, B003
-- ============================================================

-- ---------------- Contas: freelancers e totem ----------------
insert into public.usuarios (nome, login, senha_hash, papel)
select v.nome, v.login,
       encode(sha256(convert_to('sitio:' || v.senha, 'UTF8')), 'hex'),
       v.papel
from (values
  ('Maria (freelancer)', 'maria', 'freela', 'freelancer'),
  ('João (freelancer)',  'joao',  'freela', 'freelancer'),
  ('Ana (freelancer)',   'ana',   'freela', 'freelancer'),
  ('Pedro (freelancer)', 'pedro', 'freela', 'freelancer'),
  ('Totem da entrada',   'totem', 'totem',  'totem')
) as v(nome, login, senha, papel)
where not exists (
  select 1 from public.usuarios u where lower(u.login) = v.login
);

-- ---------------- Prazo de aviso de validade por item ----------------
update public.produtos p set dias_aviso_validade = v.dias
from (values
  ('TESTE-030', 1), ('TESTE-031', 2), ('TESTE-036', 5), ('TESTE-004', 2),
  ('TESTE-059', 7), ('TESTE-081', 3), ('TESTE-067', 5), ('TESTE-041', 3)
) as v(cod, dias)
where p.codigo_barras = v.cod;

-- ---------------- Lotes com validade (alguns perto de vencer) ----------------
-- O estoque atual de cada item é a soma dos lotes (saída pelo mais antigo).
do $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  insert into public.lotes (produto_id, quantidade, validade)
  select p.id::text, v.qtd, hoje + v.dias
  from (values
    ('TESTE-036', 10, 1),  ('TESTE-036', 14, 20),   -- Leite: 10 vencem amanhã
    ('TESTE-004', 10, 2),  ('TESTE-004', 15, 14),   -- Suco de laranja
    ('TESTE-005', 6, -1),  ('TESTE-005', 14, 30),   -- Suco de uva: 6 VENCIDOS
    ('TESTE-030', 10, 1),                            -- Pudim
    ('TESTE-031', 8, 2),                             -- Torta de maçã
    ('TESTE-041', 3, 2),   ('TESTE-041', 5, 7),     -- Cogumelos
    ('TESTE-059', 8, 6),   ('TESTE-059', 22, 120),  -- Chá camomila (Cosmória)
    ('TESTE-067', 6, 3),   ('TESTE-067', 24, 90),   -- Alecrim (Cosmória)
    ('TESTE-081', 10, 1),  ('TESTE-081', 30, 10)    -- Chá Ritual (Casa da Bruxa)
  ) as v(cod, qtd, dias)
  join public.produtos p on p.codigo_barras = v.cod;
end $$;

-- ---------------- Comandas novas (para o totem) ----------------
do $$
begin
  insert into public.comandas (codigo, status, pagamento)
  select c, 'ativa', null from (values ('B001'), ('B002'), ('B003')) v(c)
  where not exists (select 1 from public.comandas where codigo = v.c);

  insert into public.itens_comanda
    (comanda_codigo, produto_id, nome, quantidade, preco, processual, status_preparo, desconto)
  select v.cod, p.id, p.nome, v.qtd, p.preco, p.processual,
         case when p.processual then 'aberto' else null end, v.desconto_v
  from (values
    ('B001', 'TESTE-081', 2, 0),
    ('B001', 'TESTE-075', 1, 0),
    ('B001', 'TESTE-083', 1, 18),
    ('B002', 'TESTE-057', 2, 0),
    ('B002', 'TESTE-064', 1, 4.5),
    ('B002', 'TESTE-060', 1, 0),
    ('B003', 'TESTE-028', 1, 0),
    ('B003', 'TESTE-013', 2, 0)
  ) as v(cod, codbar, qtd, desconto_v)
  join public.produtos p on p.codigo_barras = v.codbar;
end $$;

-- ---------------- Desconto por item em comandas já existentes ----------------
update public.itens_comanda set desconto = round((preco * quantidade * 0.10)::numeric, 2)
where id in (
  select distinct on (comanda_codigo) id from public.itens_comanda
  where comanda_codigo in ('A002', 'A004') and quantidade > 0
  order by comanda_codigo, nome
);

-- ---------------- Avisos nas comandas ----------------
insert into public.comanda_avisos (comanda_codigo, texto, criado_por, criado_em) values
  ('A001', 'Trocou Coca por Guaraná', 'Staff', now() - interval '40 minutes'),
  ('A001', 'Mesa pediu para esperar o prato principal', 'Staff', now() - interval '25 minutes'),
  ('A002', 'Água trocada por água com gás', 'Staff', now() - interval '30 minutes'),
  ('A003', 'Cliente alérgico a amendoim', 'Administrador', now() - interval '55 minutes'),
  ('A004', 'Pagamento será dividido em 3 pessoas', 'Staff', now() - interval '10 minutes'),
  ('B001', 'Atendimento de tarô marcado pelo totem', 'Totem', now() - interval '5 minutes');

-- ---------------- Pagamento dividido em vendas fechadas ----------------
update public.comandas_historico h
set pagamentos_json = jsonb_build_array(
      jsonb_build_object('forma', 'PIX',
        'valor', round((h.valor_cobrado::numeric) / 2, 2), 'pago', true),
      jsonb_build_object('forma', 'DINHEIRO',
        'valor', h.valor_cobrado::numeric - round((h.valor_cobrado::numeric) / 2, 2), 'pago', true))
where h.id in (select id from public.comandas_historico order by random() limit 8);

-- ---------------- Agenda: eventos gerais e atendimentos ----------------
do $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  tz text := 'America/Sao_Paulo';
begin
  -- agenda geral (alguns com local e item cobrado na presença)
  insert into public.agenda_eventos
    (agenda, tipo, titulo, descricao, inicio, fim, produto_id, criado_por, local)
  select 'geral', v.tipo, v.titulo, v.descr,
         ((hoje + v.d) + v.ini)::timestamp at time zone tz,
         ((hoje + v.d) + v.fim)::timestamp at time zone tz,
         (select p.id::text from public.produtos p where p.codigo_barras = v.cod),
         'Administrador', v.local
  from (values
    ('Reunião',    'Reunião de alinhamento', 'Equipe toda',                 0, time '09:00', time '10:00', null,        null),
    ('Entrega',    'Entrega de bebidas',     'Fornecedor de cervejas',      0, time '11:00', time '12:00', null,        'restaurante'),
    ('Evento',     'Degustação de vinhos',   'Taças de vinho em promoção',  0, time '19:30', time '21:00', null,        'restaurante'),
    ('Evento',     'Chegada de cristais',    'Lote novo na Cosmória',       0, time '15:00', time '16:00', null,        'mercado'),
    ('Evento',     'Aula de Tarô Iniciante', 'Turma de hoje',               0, time '14:00', time '17:00', 'TESTE-083', 'gruta'),
    ('Evento',     'Oficina de Velas Rituais','Traga um pote de vidro',     0, time '18:00', time '20:00', 'TESTE-087', 'gruta'),
    ('Manutenção', 'Manutenção do forno',    'Forno parado das 14h às 16h', 1, time '14:00', time '16:00', null,        'restaurante'),
    ('Evento',     'Ritual de Lua Cheia',    'Grupo, até 20 pessoas',       2, time '20:00', time '22:00', 'TESTE-090', 'gruta'),
    ('Evento',     'Cerimônia de Cacau',     null,                          3, time '19:00', time '21:00', 'TESTE-092', 'gruta'),
    ('Evento',     'Workshop de Defumadores','Aprenda a preparar o seu',    5, time '16:00', time '18:00', 'TESTE-088', 'gruta'),
    ('Reunião',    'Reunião mensal',         'Metas do mês',                7, time '10:00', time '11:00', null,        null)
  ) as v(tipo, titulo, descr, d, ini, fim, cod, local);

  -- agenda da Casa da Bruxa (atendimentos; alguns vindos do totem)
  insert into public.agenda_eventos
    (agenda, titulo, descricao, inicio, fim, produto_id, criado_por, local, comanda_codigo)
  select 'casa_bruxa', p.nome, v.descr,
         ((hoje + v.d) + v.ini)::timestamp at time zone tz,
         ((hoje + v.d) + v.ini + interval '1 hour')::timestamp at time zone tz,
         p.id::text, v.por, 'casa_bruxa', v.cmd
  from (values
    ('TESTE-075', 0, time '10:00', 'Cliente da mesa 3',            'Staff', null),
    ('TESTE-078', 0, time '13:00', 'Comanda A003 (totem)',         'Totem', 'A003'),
    ('TESTE-077', 0, time '15:00', 'Comanda A002 (totem)',         'Totem', 'A002'),
    ('TESTE-079', 0, time '17:00', 'Comanda B001 (totem)',         'Totem', 'B001'),
    ('TESTE-080', 1, time '11:00', null,                           'Administrador', null),
    ('TESTE-076', 1, time '16:00', 'Comanda A001 (totem)',         'Totem', 'A001'),
    ('TESTE-075', 2, time '10:00', null,                           'Staff', null)
  ) as v(cod, d, ini, descr, por, cmd)
  join public.produtos p on p.codigo_barras = v.cod;
end $$;

-- ---------------- Freelancers: dias agendados + gastos no financeiro ----------------
-- Passado: dias com login (gasto já lançado). Hoje: maria (garçom) e joao
-- (limpeza) ainda SEM login — entre com eles para ver o gasto entrar.
-- Futuro: dias agendados aleatórios.
do $$
declare
  u record; d int; cg text; v numeric; lid text; dt date; tz text := 'America/Sao_Paulo';
  hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  cargos text[] := array['limpeza', 'garcom', 'auxilio'];
  nomes jsonb := '{"limpeza":"Equipe de limpeza","garcom":"Equipe de garçons","auxilio":"Auxílio geral"}';
begin
  for u in select id, nome, lower(login) as login from public.usuarios
           where papel = 'freelancer' and lower(login) in ('maria', 'joao', 'ana', 'pedro') loop
    for d in -12..10 loop
      dt := hoje + d;
      if d = 0 then
        if u.login = 'maria' then cg := 'garcom';
        elsif u.login = 'joao' then cg := 'limpeza';
        else continue; end if;
      else
        if random() > 0.45 then continue; end if;
        cg := cargos[1 + floor(random() * 3)::int];
      end if;
      v := coalesce((select valor from public.freelancer_cargos where cargo = cg), 100);

      if d < 0 then
        insert into public.fin_lancamentos
          (tipo, categoria, descricao, valor, data, competencia, pago, criado_por)
        values ('despesa', 'Freelancers (diárias)', u.nome || ' — ' || (nomes ->> cg),
                v, dt, to_char(dt, 'YYYY-MM'), true, 'Login do freelancer')
        returning id::text into lid;
        insert into public.freelancer_dias
          (usuario_id, dia, cargo, valor, login_em, logout_em, lancamento_id, criado_por)
        values (u.id::text, dt, cg, v,
                (dt + time '17:55')::timestamp at time zone tz,
                (dt + time '23:10')::timestamp at time zone tz,
                lid, 'Administrador')
        on conflict (usuario_id, dia) do nothing;
      else
        insert into public.freelancer_dias (usuario_id, dia, cargo, valor, criado_por)
        values (u.id::text, dt, cg, v, 'Administrador')
        on conflict (usuario_id, dia) do nothing;
      end if;
    end loop;
  end loop;
end $$;

-- ---------------- Alertas só para Adm (exemplos) ----------------
insert into public.notificacoes (id, titulo, descricao, ativa, local, criado_por, somente_adm) values
  ('teste_adm_1', 'Desconto na comanda A002', 'Staff (Staff): R$ 12,00 em 1x Hambúrguer do Caldeirão', true, null, 'Staff', true),
  ('teste_adm_2', 'Item removido da comanda A003', 'Staff (Staff): tirou 1x Cerveja artesanal IPA', true, null, 'Staff', true),
  ('teste_adm_3', 'Comanda A005 reaberta', 'Staff (Staff): reaberta com os itens (R$ 96,00)', true, null, 'Staff', true),
  ('teste_adm_4', 'Aviso na comanda A001', 'Staff (Staff): Trocou Coca por Guaraná', true, null, 'Staff', true),
  ('teste_adm_5', 'Atendimento agendado no totem', 'Mapa Astral (60 min) às 15:00 • comanda A002', true, null, 'Totem', true)
on conflict (id) do nothing;

-- ---------------- Atividades novas (log) ----------------
insert into public.atividades
  (criado_em, usuario_id, usuario_nome, usuario_login, acao, entidade, detalhe, comanda_codigo)
select now() - (floor(random() * 5)::int) * interval '1 day'
             - floor(random() * 500)::int * interval '1 minute',
       u.id::text, u.nome, u.login, a.acao, a.entidade, a.detalhe, a.cod
from public.usuarios u
cross join (values
  ('comanda_desconto', 'comanda', 'Desconto de R$ 12.00 em Hambúrguer do Caldeirão (comanda A002)', 'A002'),
  ('comanda_reaberta', 'comanda', 'Reabriu a comanda A005 mantendo os itens', 'A005'),
  ('comanda_aviso', 'comanda', 'Aviso na comanda A001: Trocou Coca por Guaraná', 'A001'),
  ('comanda_item_remove', 'comanda', 'Removeu 1x Cerveja artesanal IPA da comanda A003', 'A003')
) as a(acao, entidade, detalhe, cod)
where u.papel in ('adm', 'staff') and u.ativo;
