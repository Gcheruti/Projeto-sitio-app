-- Agenda (Geral e Casa da Bruxa). Rode uma vez no SQL Editor.
create table if not exists public.agenda_eventos (
  id uuid primary key default gen_random_uuid(),
  agenda text not null default 'geral',   -- 'geral' | 'casa_bruxa'
  tipo text,                               -- só na agenda geral
  titulo text not null,
  descricao text,
  inicio timestamptz not null,
  fim timestamptz not null,
  produto_id text,                         -- item de atendimento (Casa da Bruxa)
  criado_por text,
  criado_em timestamptz not null default now()
);
create index if not exists agenda_inicio_idx on public.agenda_eventos (agenda, inicio);
alter table public.agenda_eventos enable row level security;
drop policy if exists "agenda_all" on public.agenda_eventos;
create policy "agenda_all" on public.agenda_eventos for all using (true) with check (true);
