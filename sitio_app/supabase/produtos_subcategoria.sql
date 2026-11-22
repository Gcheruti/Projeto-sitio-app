-- Subcategoria e "voltado ao público" nos produtos.
alter table public.produtos add column if not exists subcategoria text;
alter table public.produtos add column if not exists publico boolean not null default true;
