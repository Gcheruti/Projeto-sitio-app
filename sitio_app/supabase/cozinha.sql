-- Login "Cozinha" (1.0.7). Rode uma vez. Mantém adm, staff, freelancer e totem.
alter table public.usuarios drop constraint if exists usuarios_papel_check;
alter table public.usuarios add constraint usuarios_papel_check
  check (papel in ('adm','staff','freelancer','totem','cozinha'));
