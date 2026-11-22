-- AVISOS PROGRAMADOS + AVISO MANUAL + ESTOQUE BAIXO (push nos celulares)
-- Depende de push.sql (push_enviar, dispositivos_push). NÃO zera o segredo.
-- Horário: America/Sao_Paulo (UTC-3, sem horário de verão).

create extension if not exists pg_cron;

-- Controle para não avisar duas vezes o mesmo evento.
create table if not exists public.avisos_enviados (
  chave text primary key,
  criado_em timestamptz not null default now()
);
alter table public.avisos_enviados enable row level security;

-- Nome bonito do local (chave -> texto)
create or replace function public.nome_do_local(p_local text) returns text
language sql immutable as $$
  select case p_local
    when 'restaurante' then 'Salão'
    when 'mercado' then 'Cosmória'
    when 'casa_bruxa' then 'Casa da Bruxa'
    when 'gruta' then 'Gruta'
    when 'spa' then 'Spa'
    when 'estacionamento' then 'Estacionamento'
    when 'espaco_ritual' then 'Espaço Ritualístico'
    when 'apiario' then 'Apiário'
    else null end
$$;

-- 1) Aviso manual do Adm: chega a todos os aparelhos logados, menos o totem
--    (a tela do totem é pública).
create or replace function public.enviar_aviso_geral(p_titulo text, p_corpo text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if coalesce(trim(p_titulo), '') = '' then
    raise exception 'titulo_vazio';
  end if;
  perform public.push_enviar(array['adm','staff','freelancer','cozinha'],
    left(trim(p_titulo), 80), left(coalesce(p_corpo, ''), 300));
end $$;

-- 2) Estoque baixo: avisa uma vez, quando o item CRUZA o mínimo para baixo.
create or replace function public.trg_push_estoque_baixo() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(new.controla_estoque, true)
     and new.quantidade <= coalesce(new.minimo, 0)
     and (old.quantidade > coalesce(old.minimo, 0)
          or not coalesce(old.controla_estoque, true)) then
    perform public.push_enviar(array['adm','staff','freelancer','cozinha'],
      'Estoque baixo',
      new.nome || ': restam ' || new.quantidade::text);
  end if;
  return new;
end $$;
drop trigger if exists push_estoque_baixo on public.produtos;
create trigger push_estoque_baixo after update of quantidade on public.produtos
  for each row when (new.quantidade is distinct from old.quantidade)
  execute function public.trg_push_estoque_baixo();

-- 3) Evento (agenda GERAL; atendimentos da Casa da Bruxa não entram) a 30 min.
create or replace function public.push_eventos_30min() returns void
language plpgsql security definer set search_path = public as $$
declare e record; faltam int;
begin
  for e in
    select a.id, a.titulo, a.inicio, a.local
      from public.agenda_eventos a
     where a.agenda = 'geral'
       and a.inicio > now()
       and a.inicio <= now() + interval '30 minutes'
       and not exists (select 1 from public.avisos_enviados v
                        where v.chave = 'ev30:' || a.id::text)
  loop
    insert into public.avisos_enviados (chave) values ('ev30:' || e.id::text)
      on conflict do nothing;
    faltam := greatest(1, ceil(extract(epoch from (e.inicio - now())) / 60)::int);
    perform public.push_enviar(array['adm','staff','freelancer'],
      'Evento em ' || faltam::text || ' min',
      e.titulo || ' às ' || to_char(e.inicio at time zone 'America/Sao_Paulo', 'HH24:MI')
        || coalesce(' • ' || public.nome_do_local(e.local), ''));
  end loop;
  -- limpeza do controle (eventos de mais de 3 dias)
  delete from public.avisos_enviados where criado_em < now() - interval '3 days';
end $$;

-- 4) 9h: aviso GRAVADO (aparece na central de avisos, "Geral") listando os
--    eventos de hoje. O gatilho de notificações já manda o push.
create or replace function public.avisar_eventos_do_dia() returns void
language plpgsql security definer set search_path = public as $$
declare
  hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  n int; lista text; id_aviso text;
begin
  id_aviso := 'resumo_' || hoje::text;
  -- os resumos dos dias anteriores saem da lista de ativos
  update public.notificacoes set ativa = false
   where id like 'resumo\_%' and id <> id_aviso and ativa;

  select count(*),
         string_agg(to_char(inicio at time zone 'America/Sao_Paulo', 'HH24:MI')
                    || ' ' || titulo
                    || coalesce(' (' || public.nome_do_local(local) || ')', ''),
                    E'\n' order by inicio)
    into n, lista
    from public.agenda_eventos
   where agenda = 'geral'
     and (inicio at time zone 'America/Sao_Paulo')::date = hoje;

  if n = 0 then return; end if;
  insert into public.notificacoes (id, titulo, descricao, ativa, local, criado_por, somente_adm)
  values (id_aviso, 'Eventos de hoje (' || n::text || ')', lista, true, null, 'Sistema', false)
  on conflict (id) do nothing;
end $$;

-- O push da notificação nova passa a levar até 300 caracteres (lista inteira).
create or replace function public.trg_push_notificacao() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.ativa is not true then return new; end if;
  perform public.push_enviar(
    case when coalesce(new.somente_adm,false) then array['adm'] else array['adm','staff','freelancer'] end,
    new.titulo, left(coalesce(new.descricao,''), 300));
  return new;
end $$;

-- Agendamentos (pg_cron roda em UTC: 12:00 UTC = 09:00 em São Paulo)
select cron.schedule('push-eventos-30min', '* * * * *', 'select public.push_eventos_30min()');
select cron.schedule('push-resumo-do-dia', '0 12 * * *', 'select public.avisar_eventos_do_dia()');

notify pgrst, 'reload schema';
