-- ============================================================
-- ZERAR O APP (deixa como novo). IRREVERSÍVEL.
-- Apaga: comandas e itens, avisos de comanda, fechamentos, reposições,
-- baixas, lotes de validade, notas importadas, correções, atividades,
-- notificações, financeiro (Toca), agenda, dias de freelancers e PRODUTOS.
-- Apaga também as contas de freelancer e totem.
-- MANTÉM: contas Adm e Staff (adm, staf, Thiago...) e os valores
-- de diária por cargo (freelancer_cargos).
--
-- Ordem para recriar os dados de teste (SQL Editor, um por vez):
--   1) 00_zerar_tudo.sql
--   2) seed_teste.sql
--   3) seed_historico.sql
--   4) seed_financeiro.sql
--   5) seed_novidades.sql   (validade, agenda, freelancers, totem, avisos...)
-- ============================================================
do $$
declare t text;
begin
  foreach t in array array[
    'atividades', 'notas_correcoes', 'notas_importadas_itens',
    'notas_importadas', 'reposicoes_itens', 'reposicoes',
    'baixas_estoque', 'comandas_historico', 'itens_comanda',
    'comanda_avisos', 'comandas', 'notificacoes',
    'lotes', 'agenda_eventos', 'freelancer_dias',
    'produtos', 'fin_lancamentos', 'fin_recorrentes'
  ] loop
    if to_regclass('public.' || t) is not null then
      execute format('delete from public.%I', t);
    end if;
  end loop;

  -- contas de freelancer e totem (Adm e Staff ficam intactos)
  if to_regclass('public.usuarios') is not null then
    delete from public.usuarios where papel in ('freelancer', 'totem');
  end if;
end $$;
