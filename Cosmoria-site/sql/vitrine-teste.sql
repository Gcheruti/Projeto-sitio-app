-- Produtos de TESTE da vitrine (anúncios de terceiros, só para testar cadastro e visualização; o site não está no ar).
-- Entram só com o link e o nome. Preço, fotos, descrição e características chegam com "↻ Atualizar todos" no painel
-- (depois que as chaves do app do Mercado Livre forem cadastradas).
-- Para apagar todos depois:  delete from "Cosmoria".vitrine_ml where exemplo;
insert into "Cosmoria".vitrine_ml (link, ml_produto_id, ml_item_id, slug, nome, exemplo, destaque, fonte) values
 ('https://www.mercadolivre.com.br/jogo-de-jantar-e-cha-20-pecas-unni-brisa-oxford-aw20-5903/p/MLB33795714?wid=MLB4481788370', 'MLB33795714', 'MLB4481788370', 'jogo-de-jantar-e-cha-20-pecas-unni-brisa-oxford', 'Jogo de Jantar e Chá 20 Peças Unni Brisa Oxford AW20-5903', true, true, 'manual'),
 ('https://www.mercadolivre.com.br/air-fryer-britania-8l-redstone-visor-glass-baf80a/p/MLB57719621?wid=MLB7319282630', 'MLB57719621', 'MLB7319282630', 'air-fryer-britania-8l-redstone-visor-glass-baf80a', 'Air Fryer Britânia 8L Redstone Visor Glass BAF80A', true, true, 'manual'),
 ('https://www.mercadolivre.com.br/air-fryer-philco-65l-visor-glass-e-redstone-1700w-paf65a-preto-127v/p/MLB52052995?wid=MLB5524906692', 'MLB52052995', 'MLB5524906692', 'air-fryer-philco-6-5l-visor-glass-redstone-paf65a', 'Air Fryer Philco 6,5L Visor Glass e Redstone 1700W PAF65A Preto 127V', true, true, 'manual'),
 ('https://www.mercadolivre.com.br/ventilador-philco-pvt41a-tecnologia-maxx-force-150w/p/MLB43067058?wid=MLB5286538026', 'MLB43067058', 'MLB5286538026', 'ventilador-philco-pvt41a-maxx-force-150w', 'Ventilador Philco PVT41A Tecnologia Maxx Force 150W', true, false, 'manual'),
 ('https://www.mercadolivre.com.br/bebedouro-de-agua-philco-gelada-natural-10l20l-bivolt-pbe14-cor-preto/p/MLB74480014?wid=MLB7126628750', 'MLB74480014', 'MLB7126628750', 'bebedouro-de-agua-philco-gelada-natural-pbe14', 'Bebedouro de Água Philco Gelada/Natural 10L/20L Bivolt PBE14 Preto', true, false, 'manual'),
 ('https://www.mercadolivre.com.br/panela-de-pressao-brinox-pressure-42l-20-x-145-cm-vanilla-baunilha/p/MLB22663071?wid=MLB3500865809', 'MLB22663071', 'MLB3500865809', 'panela-de-pressao-brinox-pressure-4-2l-vanilla', 'Panela de Pressão Brinox Pressure 4,2L 20 x 14,5 cm Vanilla', true, false, 'manual'),
 ('https://www.mercadolivre.com.br/air-fryer-oven-philco-16l-digital-com-visor-paf16c/p/MLB66895633?wid=MLB4604524273', 'MLB66895633', 'MLB4604524273', 'air-fryer-oven-philco-16l-digital-paf16c', 'Air Fryer Oven Philco 16L Digital com Visor PAF16C', true, false, 'manual')
on conflict (ml_item_id) do nothing;
