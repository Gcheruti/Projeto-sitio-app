-- Marca se o evento é voltado ao público (aparece no totem). Rode uma vez.
alter table public.agenda_eventos add column if not exists publico boolean not null default true;
-- Eventos internos já existentes (não são para o público):
update public.agenda_eventos set publico = false
 where agenda = 'geral' and tipo in ('Reunião', 'Manutenção', 'Entrega');
