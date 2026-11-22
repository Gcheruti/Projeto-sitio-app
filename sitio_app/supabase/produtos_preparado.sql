-- Itens preparados no dia não têm estoque mínimo nem alerta de estoque baixo.
alter table public.produtos add column if not exists controla_estoque boolean not null default true;
