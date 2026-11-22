-- Aba Pedidos: produtos "processuais" e etapa de preparo dos itens da comanda.
alter table public.produtos
  add column if not exists processual boolean not null default false;

alter table public.itens_comanda
  add column if not exists processual boolean not null default false,
  add column if not exists status_preparo text
    check (status_preparo in ('aberto','preparo','finalizado'));
