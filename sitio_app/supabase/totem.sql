-- Login "Totem" + local/comanda nos eventos da agenda. Rode uma vez.
-- (precisa de usuarios.sql e agenda.sql já rodados; mantém o papel freelancer)
alter table public.usuarios drop constraint if exists usuarios_papel_check;
alter table public.usuarios add constraint usuarios_papel_check
  check (papel in ('adm','staff','freelancer','totem','cozinha'));

alter table public.agenda_eventos add column if not exists local text;           -- restaurante | mercado | casa_bruxa | gruta
alter table public.agenda_eventos add column if not exists comanda_codigo text;  -- quem agendou (totem)
