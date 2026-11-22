-- Estoque e itens de comanda somados NO SERVIDOR (atômico).
-- Resolve a "corrida": dois aparelhos mexendo no mesmo produto ao mesmo tempo
-- não se sobrescrevem mais, e não dá para vender além do estoque.
-- Rode uma vez no SQL Editor. Pode rodar de novo sem problema.

create table if not exists public.operacoes_aplicadas (
  id text primary key,
  criada_em timestamptz not null default now()
);
alter table public.operacoes_aplicadas enable row level security;
drop policy if exists "op_all" on public.operacoes_aplicadas;
create policy "op_all" on public.operacoes_aplicadas for all using (true) with check (true);

-- Soma p_delta ao estoque. Se p_minimo for informado e o resultado ficaria
-- abaixo dele, recusa com 'estoque_insuficiente'. p_op (opcional) torna a
-- chamada repetível sem duplicar (usado pela fila offline).
create or replace function public.ajustar_estoque(
  p_id text,
  p_delta integer,
  p_minimo integer default null,
  p_op text default null
) returns integer
language plpgsql
as $$
declare
  nova integer;
begin
  if p_op is not null then
    insert into public.operacoes_aplicadas (id) values ('estoque:' || p_op)
      on conflict (id) do nothing;
    if not found then
      select quantidade::integer into nova from public.produtos where id::text = p_id;
      return nova;
    end if;
  end if;

  update public.produtos
     set quantidade = quantidade + p_delta
   where id::text = p_id
     and (p_minimo is null or quantidade + p_delta >= p_minimo)
  returning quantidade::integer into nova;

  if not found then
    if exists (select 1 from public.produtos where id::text = p_id) then
      raise exception 'estoque_insuficiente';
    end if;
    raise exception 'produto_nao_encontrado';
  end if;
  return nova;
end;
$$;

-- Soma p_delta à quantidade de uma linha de itens_comanda.
create or replace function public.somar_item_comanda(
  p_id text,
  p_delta integer
) returns integer
language plpgsql
as $$
declare
  nova integer;
begin
  update public.itens_comanda
     set quantidade = greatest(0, quantidade + p_delta)
   where id::text = p_id
  returning quantidade::integer into nova;
  return nova;
end;
$$;

notify pgrst, 'reload schema';

-- Registra a mudança de UM item de comanda E o estoque numa só transação.
-- p_delta > 0 = item entrou na comanda (estoque sai); p_delta < 0 = voltou.
-- p_op identifica a operação: repetir a mesma chamada (fila offline) não
-- duplica. Devolve o estoque novo do produto.
create or replace function public.registrar_item_comanda(
  p_op text,
  p_codigo text,
  p_produto_id text,
  p_nome text,
  p_preco numeric,
  p_processual boolean,
  p_delta integer
) returns integer
language plpgsql
as $$
declare
  v_cod text := upper(p_codigo);
  v_estoque integer;
  v_id text;
begin
  if p_op is not null then
    insert into public.operacoes_aplicadas (id) values ('item:' || p_op)
      on conflict (id) do nothing;
    if not found then
      select quantidade::integer into v_estoque
        from public.produtos where id::text = p_produto_id;
      return v_estoque;
    end if;
  end if;

  update public.produtos
     set quantidade = quantidade - p_delta
   where id::text = p_produto_id
     and (p_delta <= 0 or quantidade >= p_delta)
  returning quantidade::integer into v_estoque;

  if not found then
    if exists (select 1 from public.produtos where id::text = p_produto_id) then
      raise exception 'estoque_insuficiente';
    end if;
    raise exception 'produto_nao_encontrado';
  end if;

  select id::text into v_id
    from public.itens_comanda
   where comanda_codigo = v_cod and produto_id::text = p_produto_id
   limit 1;

  if v_id is not null then
    update public.itens_comanda
       set quantidade = greatest(0, quantidade + p_delta),
           status_preparo = case
             when p_delta > 0 and p_processual then 'aberto'
             else status_preparo end,
           desconto = case
             when greatest(0, quantidade + p_delta) = 0 then 0
             else desconto end
     where id::text = v_id;
  elsif p_delta > 0 then
    execute format(
      'insert into public.itens_comanda (comanda_codigo, produto_id, nome, quantidade, preco, processual, status_preparo) values (%L, %L, %L, %s, %s, %L, %L)',
      v_cod, p_produto_id, p_nome, p_delta, p_preco, p_processual,
      case when p_processual then 'aberto' else null end);
  end if;

  return v_estoque;
end;
$$;

notify pgrst, 'reload schema';
