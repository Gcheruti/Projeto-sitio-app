-- Dados de TESTE do financeiro (rode depois de financeiro.sql).
insert into public.fin_recorrentes (tipo, categoria, descricao, valor, dia_vencimento) values
  ('despesa','Água','Conta de água',180,10),
  ('despesa','Luz','Conta de luz',620,12),
  ('despesa','Internet','Internet fibra',150,5),
  ('despesa','Funcionários (salários)','Salário - cozinha',2400,5),
  ('despesa','Funcionários (salários)','Salário - atendimento',2100,5),
  ('despesa','Encargos e impostos','Encargos trabalhistas',1300,20);

do $$
declare m int; d date; r record;
begin
  for m in 0..2 loop
    d := (date_trunc('month', now()) - (m || ' months')::interval)::date;
    for r in select * from public.fin_recorrentes loop
      insert into public.fin_lancamentos
        (tipo, categoria, descricao, valor, data, competencia, pago, recorrente_id, criado_por)
      values (r.tipo, r.categoria, r.descricao,
              round((r.valor * (0.9 + random() * 0.2))::numeric, 2),
              d + (least(r.dia_vencimento, 28) - 1),
              to_char(d, 'YYYY-MM'),
              (m > 0 or r.dia_vencimento <= extract(day from now())::int),
              r.id, 'Administrador');
    end loop;
    insert into public.fin_lancamentos (tipo, categoria, descricao, valor, data, competencia, pago, criado_por) values
      ('despesa','Contratações','Taxa de contratação - auxiliar de salão', 450, d + 14, to_char(d,'YYYY-MM'), true, 'Administrador'),
      ('despesa','Manutenção','Reparo do telhado da Toca', 780, d + 8, to_char(d,'YYYY-MM'), true, 'Administrador'),
      ('despesa','Marketing','Impulsionamento de posts', 200, d + 3, to_char(d,'YYYY-MM'), true, 'Administrador'),
      ('receita','Aporte','Aporte dos sócios', 3000, d + 1, to_char(d,'YYYY-MM'), true, 'Administrador');
  end loop;
end $$;
