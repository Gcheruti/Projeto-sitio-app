-- PUSH (FCM). Rode UMA vez no SQL Editor, DEPOIS de publicar a função enviar-push
-- e de trocar 'TROQUE_PELO_SEGREDO' abaixo pelo mesmo valor do PUSH_SECRET.
create extension if not exists pg_net;

create table if not exists public.dispositivos_push (
  token text primary key,
  usuario_id text,
  papel text not null,
  atualizado_em timestamptz not null default now()
);
alter table public.dispositivos_push enable row level security;
drop policy if exists dispositivos_push_all on public.dispositivos_push;
create policy dispositivos_push_all on public.dispositivos_push
  for all to anon, authenticated using (true) with check (true);

-- Configuração (URL da função + segredo). Só o servidor lê; sem policy = anon não vê.
create table if not exists public.push_config (
  id int primary key default 1 check (id = 1),
  url text not null,
  segredo text not null
);
alter table public.push_config enable row level security;
insert into public.push_config (id, url, segredo) values
  (1, 'https://cucabiqhtwqlxujgflnq.supabase.co/functions/v1/enviar-push', 'TROQUE_PELO_SEGREDO')
on conflict (id) do update set url = excluded.url, segredo = excluded.segredo;

-- Dispara a função. Nunca derruba o INSERT original se o push falhar.
create or replace function public.push_enviar(p_papeis text[], p_titulo text, p_corpo text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare cfg record;
begin
  select * into cfg from public.push_config where id = 1;
  if cfg is null or cfg.segredo = 'TROQUE_PELO_SEGREDO' then return; end if;
  perform net.http_post(
    url := cfg.url,
    headers := jsonb_build_object('Content-Type','application/json','x-push-secret',cfg.segredo),
    body := jsonb_build_object('papeis', p_papeis, 'titulo', p_titulo, 'corpo', p_corpo)
  );
exception when others then null;
end $$;

-- 1) Nova notificação do início (Adm-only vai só para Adm)
create or replace function public.trg_push_notificacao() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.ativa is not true then return new; end if;
  perform public.push_enviar(
    case when coalesce(new.somente_adm,false) then array['adm'] else array['adm','staff','freelancer'] end,
    new.titulo, left(coalesce(new.descricao,''), 140));
  return new;
end $$;
drop trigger if exists push_notificacao on public.notificacoes;
create trigger push_notificacao after insert on public.notificacoes
  for each row execute function public.trg_push_notificacao();

-- 2) Novo item processual (cozinha)
create or replace function public.trg_push_pedido() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.processual,false) then
    perform public.push_enviar(array['cozinha','adm','staff'], 'Novo pedido na cozinha',
      coalesce(new.quantidade,1)::text || 'x ' || coalesce(new.nome,'item'));
  end if;
  return new;
end $$;
drop trigger if exists push_pedido on public.itens_comanda;
create trigger push_pedido after insert on public.itens_comanda
  for each row execute function public.trg_push_pedido();

-- 3) Reposição de estoque (novo lote)
create or replace function public.trg_push_reposicao() returns trigger
language plpgsql security definer set search_path = public as $$
declare nome_p text;
begin
  select nome into nome_p from public.produtos where id = new.produto_id;
  perform public.push_enviar(array['adm','staff'], 'Estoque reposto',
    new.quantidade::text || ' un. de ' || coalesce(nome_p, 'produto'));
  return new;
end $$;
drop trigger if exists push_reposicao on public.lotes;
create trigger push_reposicao after insert on public.lotes
  for each row execute function public.trg_push_reposicao();
