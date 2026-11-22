-- DESATIVADO (modo vitrine, nov/2026): frete agora é do Mercado Livre. As tabelas de frete continuam no banco, sem uso. Pode voltar.
-- Teste do frete. Rode a PARTE 1, espere uns 10 segundos e rode a PARTE 2.

-- PARTE 1: limpa as distâncias antigas e pede 4 cotações de teste
delete from "Cosmoria".frete_distancias;
select net.http_post(
  'https://cucabiqhtwqlxujgflnq.supabase.co/functions/v1/calcular-frete',
  jsonb_build_object('cep', c, 'itens', jsonb_build_array(jsonb_build_object('variante_id', 30, 'quantidade', 1))),
  '{}'::jsonb, '{"Content-Type":"application/json"}'::jsonb, 30000) as pedido, c as cep
from unnest(array['01310-100','04094-050','06010-000','20040-020']) as c;

-- PARTE 2: mostra as respostas (as mais recentes primeiro)
select id, status_code, content::jsonb -> 'cep' as cep, content::jsonb -> 'distancia_km' as km,
       content::jsonb -> 'opcoes' as opcoes
from net._http_response
where content like '{%'   -- ignora respostas antigas que não são JSON
order by id desc limit 4;
