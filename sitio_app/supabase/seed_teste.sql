-- Itens de TESTE (todas as categorias). Seguro rodar mais de uma vez:
-- não repete item com o mesmo nome.
-- Antes, rode: produtos_subcategoria.sql e produtos_preparado.sql
--  (e produtos_processual, se ainda não rodou: coluna "processual").
--
-- Observações:
--  * Serviços/atendimentos usam quantidade 999 (= sem limite).
--  * Aulas/oficinas da Gruta: a quantidade são as VAGAS restantes.
--  * Pratos, entradas, porções, lanches, sobremesas e combos são
--    "preparados no dia" (controla_estoque = false): use "Registrar preparo".
--  * Ingredientes (ovos, leite, farinha...) são internos (publico = false).
--
-- Para APAGAR todos os itens de teste depois:
--   delete from public.produtos where codigo_barras like 'TESTE-%';

alter table public.produtos add column if not exists processual boolean not null default false;
alter table public.produtos add column if not exists subcategoria text;
alter table public.produtos add column if not exists publico boolean not null default true;
alter table public.produtos add column if not exists controla_estoque boolean not null default true;

with novos(nome, quantidade, minimo, preco, ambiente, subcategoria, publico,
           controla_estoque, processual, codigo_barras) as (
  values
    ('Água mineral 500ml', 60, 12, 6.00, 'Salão', 'Bebidas', true, true, false, 'TESTE-001'),
    ('Água com gás 500ml', 40, 10, 7.00, 'Salão', 'Bebidas', true, true, false, 'TESTE-002'),
    ('Refrigerante lata', 48, 12, 7.00, 'Salão', 'Refrigerantes e sucos', true, true, false, 'TESTE-003'),
    ('Suco de laranja 300ml', 25, 8, 10.00, 'Salão', 'Refrigerantes e sucos', true, true, false, 'TESTE-004'),
    ('Suco de uva integral 300ml', 20, 6, 11.00, 'Salão', 'Refrigerantes e sucos', true, true, false, 'TESTE-005'),
    ('Cerveja artesanal IPA', 36, 10, 22.00, 'Salão', 'Cervejas', true, true, false, 'TESTE-006'),
    ('Cerveja Pilsen long neck', 48, 12, 12.00, 'Salão', 'Cervejas', true, true, false, 'TESTE-007'),
    ('Cerveja de trigo Weiss', 24, 6, 20.00, 'Salão', 'Cervejas', true, true, false, 'TESTE-008'),
    ('Taça de vinho tinto', 20, 6, 28.00, 'Salão', 'Vinhos', true, true, false, 'TESTE-009'),
    ('Garrafa de vinho tinto', 12, 3, 95.00, 'Salão', 'Vinhos', true, true, false, 'TESTE-010'),
    ('Taça de hidromel', 15, 4, 30.00, 'Salão', 'Vinhos', true, true, false, 'TESTE-011'),
    ('Garrafa de vinho branco', 10, 3, 89.00, 'Salão', 'Vinhos', true, true, false, 'TESTE-012'),
    ('Poção Lunar (gin tônica)', 100, 0, 34.00, 'Salão', 'Drinks', true, true, true, 'TESTE-013'),
    ('Elixir da Bruxa (caipirinha de frutas vermelhas)', 100, 0, 30.00, 'Salão', 'Drinks', true, true, true, 'TESTE-014'),
    ('Veneno de Maçã (cidra e canela)', 100, 0, 28.00, 'Salão', 'Drinks', true, true, true, 'TESTE-015'),
    ('Mojito do Bosque', 100, 0, 32.00, 'Salão', 'Drinks', true, true, true, 'TESTE-016'),
    ('Café espresso', 80, 15, 7.00, 'Salão', 'Cafés e chás', true, true, false, 'TESTE-017'),
    ('Chá da Casa (infusão de ervas)', 40, 10, 12.00, 'Salão', 'Cafés e chás', true, true, true, 'TESTE-018'),
    ('Tábua de queijos e frios', 10, 0, 58.00, 'Salão', 'Entradas', true, false, true, 'TESTE-019'),
    ('Bruschetta de cogumelos', 12, 0, 26.00, 'Salão', 'Entradas', true, false, true, 'TESTE-020'),
    ('Caldo verde da gruta', 14, 0, 22.00, 'Salão', 'Entradas', true, false, true, 'TESTE-021'),
    ('Batata rústica com alecrim', 20, 0, 32.00, 'Salão', 'Porções', true, false, true, 'TESTE-022'),
    ('Isca de frango empanada', 18, 0, 38.00, 'Salão', 'Porções', true, false, true, 'TESTE-023'),
    ('Polenta frita com parmesão', 16, 0, 30.00, 'Salão', 'Porções', true, false, true, 'TESTE-024'),
    ('Macarrão ao molho de ervas', 15, 0, 48.00, 'Salão', 'Pratos principais', true, false, true, 'TESTE-025'),
    ('Risoto de cogumelos', 12, 0, 62.00, 'Salão', 'Pratos principais', true, false, true, 'TESTE-026'),
    ('Costela ao molho barbecue', 10, 0, 78.00, 'Salão', 'Pratos principais', true, false, true, 'TESTE-027'),
    ('Hambúrguer do Caldeirão', 14, 0, 42.00, 'Salão', 'Lanches', true, false, true, 'TESTE-028'),
    ('Sanduíche natural da Bruxa', 12, 0, 28.00, 'Salão', 'Lanches', true, false, true, 'TESTE-029'),
    ('Pudim de leite', 10, 0, 14.00, 'Salão', 'Sobremesas', true, false, true, 'TESTE-030'),
    ('Torta de maçã e canela', 8, 0, 16.00, 'Salão', 'Sobremesas', true, false, true, 'TESTE-031'),
    ('Brownie com sorvete', 12, 0, 24.00, 'Salão', 'Sobremesas', true, false, true, 'TESTE-032'),
    ('Mousse de chocolate', 10, 0, 15.00, 'Salão', 'Sobremesas', true, false, true, 'TESTE-033'),
    ('Combo Sabá (prato + bebida + sobremesa)', 10, 0, 89.00, 'Salão', 'Combos', true, false, true, 'TESTE-034'),
    ('Ovos (unidade)', 120, 30, 1.00, 'Salão', 'Outros', false, true, false, 'TESTE-035'),
    ('Leite (litro)', 24, 6, 6.00, 'Salão', 'Outros', false, true, false, 'TESTE-036'),
    ('Leite condensado (lata)', 18, 5, 7.00, 'Salão', 'Outros', false, true, false, 'TESTE-037'),
    ('Farinha de trigo (kg)', 15, 4, 6.00, 'Salão', 'Outros', false, true, false, 'TESTE-038'),
    ('Açúcar (kg)', 20, 5, 5.00, 'Salão', 'Outros', false, true, false, 'TESTE-039'),
    ('Queijo muçarela (kg)', 10, 3, 42.00, 'Salão', 'Outros', false, true, false, 'TESTE-040'),
    ('Cogumelos (bandeja)', 8, 3, 14.00, 'Salão', 'Outros', false, true, false, 'TESTE-041'),
    ('Macarrão (pacote)', 20, 5, 6.00, 'Salão', 'Outros', false, true, false, 'TESTE-042'),
    ('Caneca Corvo', 20, 5, 49.00, 'Loja', 'Canecas', true, true, false, 'TESTE-043'),
    ('Caneca Lua Cheia', 18, 5, 49.00, 'Loja', 'Canecas', true, true, false, 'TESTE-044'),
    ('Camiseta Sítio preta M', 15, 4, 79.00, 'Loja', 'Camisetas', true, true, false, 'TESTE-045'),
    ('Camiseta Sítio preta G', 15, 4, 79.00, 'Loja', 'Camisetas', true, true, false, 'TESTE-046'),
    ('Camiseta Lua Tripla P', 10, 3, 85.00, 'Loja', 'Camisetas', true, true, false, 'TESTE-047'),
    ('Moletom Bruxa Sênior M', 8, 2, 189.00, 'Loja', 'Blusas', true, true, false, 'TESTE-048'),
    ('Blusa cropped Lua', 10, 3, 99.00, 'Loja', 'Blusas', true, true, false, 'TESTE-049'),
    ('Pêndulo de cristal', 14, 3, 65.00, 'Loja', 'Itens mágicos', true, true, false, 'TESTE-050'),
    ('Athame decorativo', 6, 2, 120.00, 'Loja', 'Itens mágicos', true, true, false, 'TESTE-051'),
    ('Kit altar de bolso', 9, 3, 95.00, 'Loja', 'Itens mágicos', true, true, false, 'TESTE-052'),
    ('Baralho de Tarô Rider-Waite', 10, 3, 120.00, 'Loja', 'Livros e baralhos', true, true, false, 'TESTE-053'),
    ('Baralho de Oráculo das Fadas', 8, 3, 110.00, 'Loja', 'Livros e baralhos', true, true, false, 'TESTE-054'),
    ('Livro Ervas e Feitiços', 6, 2, 89.00, 'Loja', 'Livros e baralhos', true, true, false, 'TESTE-055'),
    ('Vela 7 dias vermelha', 25, 6, 18.00, 'Loja', 'Velas', true, true, false, 'TESTE-056'),
    ('Vela de soja lavanda', 30, 8, 35.00, 'Loja', 'Velas', true, true, false, 'TESTE-057'),
    ('Vela preta proteção', 20, 5, 22.00, 'Loja', 'Velas', true, true, false, 'TESTE-058'),
    ('Chá de camomila e lavanda', 30, 8, 24.00, 'Loja', 'Chás', true, true, false, 'TESTE-059'),
    ('Chá Prosperidade', 25, 6, 26.00, 'Loja', 'Chás', true, true, false, 'TESTE-060'),
    ('Chá do Sono Profundo', 22, 6, 26.00, 'Loja', 'Chás', true, true, false, 'TESTE-061'),
    ('Incenso de sândalo (caixa)', 50, 10, 12.00, 'Loja', 'Incensos', true, true, false, 'TESTE-062'),
    ('Defumador de sálvia branca', 20, 5, 29.00, 'Loja', 'Incensos', true, true, false, 'TESTE-063'),
    ('Ametista bruta', 15, 4, 45.00, 'Loja', 'Cristais e pedras', true, true, false, 'TESTE-064'),
    ('Quartzo rosa', 20, 5, 32.00, 'Loja', 'Cristais e pedras', true, true, false, 'TESTE-065'),
    ('Obsidiana negra', 12, 3, 38.00, 'Loja', 'Cristais e pedras', true, true, false, 'TESTE-066'),
    ('Alecrim seco (saquinho)', 30, 8, 9.00, 'Loja', 'Ervas', true, true, false, 'TESTE-067'),
    ('Arruda seca (saquinho)', 20, 5, 9.00, 'Loja', 'Ervas', true, true, false, 'TESTE-068'),
    ('Lavanda seca (saquinho)', 25, 6, 11.00, 'Loja', 'Ervas', true, true, false, 'TESTE-069'),
    ('Pingente pentagrama', 12, 3, 58.00, 'Loja', 'Joias e acessórios', true, true, false, 'TESTE-070'),
    ('Anel Lua Crescente', 10, 3, 69.00, 'Loja', 'Joias e acessórios', true, true, false, 'TESTE-071'),
    ('Caldeirão decorativo', 6, 2, 110.00, 'Loja', 'Decoração', true, true, false, 'TESTE-072'),
    ('Cortina de ervas penduradas', 8, 2, 45.00, 'Loja', 'Decoração', true, true, false, 'TESTE-073'),
    ('Sacola de pano Sítio', 40, 10, 15.00, 'Loja', 'Outros', true, true, false, 'TESTE-074'),
    ('Consulta de Tarô (30 min)', 999, 0, 120.00, 'Tarô', 'Atendimentos', true, true, false, 'TESTE-075'),
    ('Leitura de Oráculo (20 min)', 999, 0, 90.00, 'Tarô', 'Atendimentos', true, true, false, 'TESTE-076'),
    ('Mapa Astral (60 min)', 999, 0, 180.00, 'Tarô', 'Atendimentos', true, true, false, 'TESTE-077'),
    ('Sessão de Reiki (45 min)', 999, 0, 140.00, 'Tarô', 'Atendimentos', true, true, false, 'TESTE-078'),
    ('Leitura de Runas (30 min)', 999, 0, 100.00, 'Tarô', 'Atendimentos', true, true, false, 'TESTE-079'),
    ('Limpeza energética (40 min)', 999, 0, 130.00, 'Tarô', 'Atendimentos', true, true, false, 'TESTE-080'),
    ('Chá Ritual de Boas-Vindas', 40, 8, 14.00, 'Tarô', 'Chás', true, true, true, 'TESTE-081'),
    ('Chá da Intuição', 40, 8, 16.00, 'Tarô', 'Chás', true, true, true, 'TESTE-082'),
    ('Aula de Tarô Iniciante (3h)', 12, 2, 180.00, 'Gruta', 'Aulas', true, true, false, 'TESTE-083'),
    ('Aula de Ervas e Chás (2h)', 12, 2, 150.00, 'Gruta', 'Aulas', true, true, false, 'TESTE-084'),
    ('Curso de Cristaloterapia (4h)', 10, 2, 220.00, 'Gruta', 'Aulas', true, true, false, 'TESTE-085'),
    ('Aula de Astrologia Básica (3h)', 12, 2, 170.00, 'Gruta', 'Aulas', true, true, false, 'TESTE-086'),
    ('Oficina de Velas Rituais', 10, 2, 130.00, 'Gruta', 'Oficinas e workshops', true, true, false, 'TESTE-087'),
    ('Workshop de Defumadores', 10, 2, 110.00, 'Gruta', 'Oficinas e workshops', true, true, false, 'TESTE-088'),
    ('Roda de Leitura de Runas', 8, 2, 90.00, 'Gruta', 'Oficinas e workshops', true, true, false, 'TESTE-089'),
    ('Ritual de Lua Cheia (grupo)', 20, 3, 85.00, 'Gruta', 'Serviços', true, true, false, 'TESTE-090'),
    ('Jornada Meditativa guiada', 15, 3, 70.00, 'Gruta', 'Serviços', true, true, false, 'TESTE-091'),
    ('Cerimônia de Cacau', 12, 3, 110.00, 'Gruta', 'Serviços', true, true, false, 'TESTE-092'),
    ('Aluguel da Gruta para evento', 3, 0, 600.00, 'Gruta', 'Serviços', true, true, false, 'TESTE-093')
)
insert into public.produtos
  (nome, quantidade, minimo, preco, ambiente, subcategoria, publico,
   controla_estoque, processual, codigo_barras)
select n.nome, n.quantidade, n.minimo, n.preco, n.ambiente, n.subcategoria,
       n.publico, n.controla_estoque, n.processual, n.codigo_barras
from novos n
where not exists (select 1 from public.produtos p where p.nome = n.nome);
