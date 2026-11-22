-- =====================================================================
-- GRUTA · estrutura do banco, toda dentro do schema "gruta"
-- =====================================================================
-- O projeto Supabase é compartilhado com outros apps (Sítio, Cosmória).
-- Por isso:
--   * tudo da Gruta fica no schema gruta (nada em public);
--   * nenhum gatilho em auth.users: a conta e o perfil são criados pela
--     Edge Function gruta-cadastro;
--   * as contas da Gruta usam e-mails internos <usuario>@usuarios.gruta.app
--     e app_metadata.app = 'gruta'.
--
-- Depois de aplicar: Painel > Project Settings > Data API > Exposed schemas
-- > adicionar "gruta". Sem isso o app não enxerga as tabelas.
--
-- Segurança: app PÚBLICO, então TUDO tem RLS. Cada pessoa só lê e grava o
-- que é dela; catálogo é só leitura; plano e papel só mudam pelo servidor.
-- Administradores (perfis.papel = 'admin') gravam catálogo e avisos.
-- =====================================================================

create schema if not exists gruta;
grant usage on schema gruta to anon, authenticated, service_role;
grant all on all tables in schema gruta to service_role;
alter default privileges in schema gruta grant all on tables to service_role;
alter default privileges in schema gruta grant all on sequences to service_role;
alter default privileges in schema gruta grant execute on functions to service_role;
-- Funções novas não ficam abertas para todo mundo por padrão.
alter default privileges in schema gruta revoke execute on functions from public;

-- ---------------------------------------------------------------------
-- 0. Configuração (chaves que a equipe muda sem publicar app novo)
-- ---------------------------------------------------------------------
create table if not exists gruta.config (
  chave  text primary key,
  valor  jsonb not null
);
alter table gruta.config enable row level security;
-- sem policy: só o servidor (service_role) e as funções abaixo leem.

insert into gruta.config (chave, valor) values
  -- Enquanto o pagamento não existe, escolher "Aprendiz" já libera o plano.
  -- Desligue (false) quando a cobrança de verdade entrar.
  ('planos_teste', 'true'),
  -- Aulas da Jornada que dão moeda (ordem 0 = aula piloto).
  ('marcos_moeda', '[5, 15, 30, 45, 59]')
on conflict (chave) do nothing;

create or replace function gruta.config_bool(p_chave text)
returns boolean language sql stable security definer set search_path = gruta as $$
  select coalesce((select (valor)::text::boolean from gruta.config where chave = p_chave), false);
$$;

create or replace function gruta.marcos_moeda()
returns int[] language sql stable security definer set search_path = gruta as $$
  select coalesce(
    (select array_agg(x::int) from gruta.config c,
       jsonb_array_elements_text(c.valor) x where c.chave = 'marcos_moeda'),
    array[5, 15, 30, 45, 59]);
$$;

-- ---------------------------------------------------------------------
-- 1. Perfis (1 por conta da Gruta)
-- ---------------------------------------------------------------------
create table if not exists gruta.perfis (
  id                uuid primary key references auth.users(id) on delete cascade,
  login             text not null check (login ~ '^[a-z0-9._]{3,20}$'),
  nome              text not null default '' check (char_length(nome) <= 80),
  nome_completo     text not null default '' check (char_length(nome_completo) <= 160),
  nascimento        date,
  plano             text not null default 'visitante'
                      check (plano in ('visitante', 'aprendiz', 'mestre')),
  papel             text not null default 'aluno' check (papel in ('aluno', 'admin')),
  meta_minutos      int  not null default 5  check (meta_minutos between 1 and 120),
  lembrete_hora     int  not null default 20 check (lembrete_hora between 0 and 23),
  lembrete_minuto   int  not null default 0  check (lembrete_minuto between 0 and 59),
  lembrete_ativo    boolean not null default true,
  trilhas_interesse text[] not null default '{}',
  fuso              text not null default 'America/Sao_Paulo', -- define o "dia"
  criado_em         timestamptz not null default now(),
  atualizado_em     timestamptz not null default now()
);
create unique index if not exists perfis_login on gruta.perfis (lower(login));
comment on table gruta.perfis is 'Cadastro e preferências. login, plano e papel só mudam pelo servidor.';

create or replace function gruta.eh_admin()
returns boolean language sql stable security definer set search_path = gruta as $$
  select exists (select 1 from gruta.perfis where id = auth.uid() and papel = 'admin');
$$;

alter table gruta.perfis enable row level security;
drop policy if exists perfis_ler on gruta.perfis;
create policy perfis_ler on gruta.perfis
  for select to authenticated using (id = auth.uid() or gruta.eh_admin());
drop policy if exists perfis_editar on gruta.perfis;
create policy perfis_editar on gruta.perfis
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- Permissão por coluna: login, plano e papel ficam de fora.
revoke all on gruta.perfis from anon, authenticated;
grant select on gruta.perfis to authenticated;
grant update (nome, nome_completo, nascimento, meta_minutos, lembrete_hora,
              lembrete_minuto, lembrete_ativo, trilhas_interesse, fuso)
  on gruta.perfis to authenticated;

create or replace function gruta.tocar_atualizado_em()
returns trigger language plpgsql set search_path = gruta as $$
begin new.atualizado_em := now(); return new; end $$;

drop trigger if exists perfis_atualizado on gruta.perfis;
create trigger perfis_atualizado before update on gruta.perfis
  for each row execute function gruta.tocar_atualizado_em();

-- Regras dos planos (as mesmas de lib/models/plano.dart).
create or replace function gruta.plano_aulas_jornada(p_plano text)
returns int language sql immutable as $$
  select case p_plano when 'visitante' then 3 else 60 end;
$$;
create or replace function gruta.plano_limite_trilhas(p_plano text)
returns int language sql immutable as $$
  select case p_plano when 'aprendiz' then 4 when 'mestre' then 99 else 0 end;
$$;

-- ---------------------------------------------------------------------
-- 2. Assinaturas (pagamento) — escritas só pelo servidor (webhook da loja)
-- ---------------------------------------------------------------------
create table if not exists gruta.assinaturas (
  id                  uuid primary key default gen_random_uuid(),
  usuario_id          uuid not null references auth.users(id) on delete cascade,
  plano               text not null check (plano in ('aprendiz', 'mestre')),
  plataforma          text not null check (plataforma in ('apple', 'google', 'web', 'cortesia')),
  produto             text not null,                 -- ex.: 'gruta_aprendiz_mensal'
  status              text not null check (status in ('ativa', 'teste', 'cancelada', 'expirada')),
  inicio              timestamptz not null default now(),
  expira_em           timestamptz,
  transacao_original  text unique,
  atualizado_em       timestamptz not null default now()
);
create index if not exists assinaturas_usuario on gruta.assinaturas (usuario_id);
alter table gruta.assinaturas enable row level security;
drop policy if exists assinaturas_ler on gruta.assinaturas;
create policy assinaturas_ler on gruta.assinaturas
  for select to authenticated using (usuario_id = auth.uid());
revoke all on gruta.assinaturas from anon, authenticated;
grant select on gruta.assinaturas to authenticated;

-- Mantém perfis.plano igual à melhor assinatura ativa.
create or replace function gruta.sincronizar_plano()
returns trigger language plpgsql security definer set search_path = gruta as $$
declare
  v_uid uuid := coalesce(new.usuario_id, old.usuario_id);
  v_plano text;
begin
  select case when bool_or(plano = 'mestre') then 'mestre' else 'aprendiz' end
    into v_plano
    from gruta.assinaturas
   where usuario_id = v_uid and status in ('ativa', 'teste')
     and (expira_em is null or expira_em > now())
  having count(*) > 0;
  update gruta.perfis set plano = coalesce(v_plano, 'visitante') where id = v_uid;
  return null;
end $$;
drop trigger if exists assinaturas_sincronizar on gruta.assinaturas;
create trigger assinaturas_sincronizar
  after insert or update or delete on gruta.assinaturas
  for each row execute function gruta.sincronizar_plano();

-- ---------------------------------------------------------------------
-- 3. Catálogo: trilhas e aulas (trilha_id null = aula da Jornada)
-- ---------------------------------------------------------------------
create table if not exists gruta.trilhas (
  id         uuid primary key default gen_random_uuid(),
  slug       text not null unique,
  titulo     text not null,
  subtitulo  text not null default '',
  descricao  text not null default '',
  icone      text not null default 'estrela', -- chave (lib/models/trilha.dart)
  cor        text not null default '#C9A45C',
  ordem      int  not null default 0,
  publicada  boolean not null default false,
  criado_em  timestamptz not null default now()
);
alter table gruta.trilhas enable row level security;
drop policy if exists trilhas_ler on gruta.trilhas;
create policy trilhas_ler on gruta.trilhas
  for select to anon, authenticated using (publicada or gruta.eh_admin());
drop policy if exists trilhas_admin on gruta.trilhas;
create policy trilhas_admin on gruta.trilhas
  for all to authenticated using (gruta.eh_admin()) with check (gruta.eh_admin());
grant select on gruta.trilhas to anon, authenticated;
grant insert, update, delete on gruta.trilhas to authenticated;

create table if not exists gruta.aulas (
  id           uuid primary key default gen_random_uuid(),
  trilha_id    uuid references gruta.trilhas(id) on delete cascade, -- null = Jornada
  ordem        int  not null check (ordem >= 0),
  titulo       text not null,
  descricao    text not null default '',
  reflexao     text,
  video_url    text not null default '',
  duracao_seg  int  not null default 300 check (duracao_seg > 0),
  capa_url     text,
  publicada    boolean not null default true,
  publicar_em  timestamptz not null default now(),
  criado_em    timestamptz not null default now(),
  constraint aulas_ordem_unica unique nulls not distinct (trilha_id, ordem)
);
-- A tabela tem o endereço dos vídeos: só admin lê direto. O app lê pela
-- view aulas_app, que esconde o vídeo de quem ainda não pode ver.
alter table gruta.aulas enable row level security;
drop policy if exists aulas_admin on gruta.aulas;
create policy aulas_admin on gruta.aulas
  for all to authenticated using (gruta.eh_admin()) with check (gruta.eh_admin());
revoke all on gruta.aulas from anon, authenticated;
grant select, insert, update, delete on gruta.aulas to authenticated;

-- ---------------------------------------------------------------------
-- 4. Progresso, dias de estudo, trilhas liberadas e Grimório
-- ---------------------------------------------------------------------
create table if not exists gruta.progresso_aulas (
  usuario_id     uuid not null references auth.users(id) on delete cascade,
  aula_id        uuid not null references gruta.aulas(id) on delete cascade,
  assistido_seg  int  not null default 0,
  concluida_em   timestamptz,
  dia_local      date,           -- dia da conclusão no fuso da pessoa
  atualizado_em  timestamptz not null default now(),
  primary key (usuario_id, aula_id)
);
alter table gruta.progresso_aulas enable row level security;
drop policy if exists progresso_ler on gruta.progresso_aulas;
create policy progresso_ler on gruta.progresso_aulas
  for select to authenticated using (usuario_id = auth.uid());
revoke all on gruta.progresso_aulas from anon, authenticated;
grant select on gruta.progresso_aulas to authenticated;
-- gravação só pela função concluir_aula.

create table if not exists gruta.dias_estudo (
  usuario_id  uuid not null references auth.users(id) on delete cascade,
  dia         date not null,
  aulas       int  not null default 0,
  segundos    int  not null default 0,
  primary key (usuario_id, dia)
);
alter table gruta.dias_estudo enable row level security;
drop policy if exists dias_ler on gruta.dias_estudo;
create policy dias_ler on gruta.dias_estudo
  for select to authenticated using (usuario_id = auth.uid());
revoke all on gruta.dias_estudo from anon, authenticated;
grant select on gruta.dias_estudo to authenticated;

create table if not exists gruta.trilhas_liberadas (
  usuario_id  uuid not null references auth.users(id) on delete cascade,
  trilha_id   uuid not null references gruta.trilhas(id) on delete cascade,
  origem      text not null default 'moeda' check (origem in ('moeda', 'compra', 'cortesia')),
  criada_em   timestamptz not null default now(),
  primary key (usuario_id, trilha_id)
);
alter table gruta.trilhas_liberadas enable row level security;
drop policy if exists liberadas_ler on gruta.trilhas_liberadas;
create policy liberadas_ler on gruta.trilhas_liberadas
  for select to authenticated using (usuario_id = auth.uid());
revoke all on gruta.trilhas_liberadas from anon, authenticated;
grant select on gruta.trilhas_liberadas to authenticated;
-- gravação só pela função gastar_moeda (ou pelo servidor, numa compra).

create table if not exists gruta.grimorio_notas (
  id          uuid primary key default gen_random_uuid(),
  usuario_id  uuid not null default auth.uid() references auth.users(id) on delete cascade,
  aula_id     uuid references gruta.aulas(id) on delete set null,
  texto       text not null check (char_length(texto) between 1 and 5000),
  criada_em   timestamptz not null default now()
);
create index if not exists grimorio_usuario on gruta.grimorio_notas (usuario_id, criada_em desc);
alter table gruta.grimorio_notas enable row level security;
drop policy if exists grimorio_tudo on gruta.grimorio_notas;
create policy grimorio_tudo on gruta.grimorio_notas
  for all to authenticated
  using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());
revoke all on gruta.grimorio_notas from anon, authenticated;
grant select, insert, delete on gruta.grimorio_notas to authenticated;

-- ---------------------------------------------------------------------
-- 5. Avisos (notificações do painel /adm para todo mundo)
-- ---------------------------------------------------------------------
create table if not exists gruta.notificacoes (
  id          uuid primary key default gen_random_uuid(),
  titulo      text not null check (char_length(titulo) between 1 and 80),
  descricao   text not null default '' check (char_length(descricao) <= 400),
  icone       text not null default 'vela',
  criada_por  uuid default auth.uid() references auth.users(id) on delete set null,
  criada_em   timestamptz not null default now()
);
create index if not exists notificacoes_data on gruta.notificacoes (criada_em desc);
alter table gruta.notificacoes enable row level security;
drop policy if exists notificacoes_ler on gruta.notificacoes;
create policy notificacoes_ler on gruta.notificacoes
  for select to authenticated using (true);
drop policy if exists notificacoes_admin on gruta.notificacoes;
create policy notificacoes_admin on gruta.notificacoes
  for insert to authenticated with check (gruta.eh_admin());
revoke all on gruta.notificacoes from anon, authenticated;
grant select, insert on gruta.notificacoes to authenticated;

-- ---------------------------------------------------------------------
-- 6. Regras de acesso (Jornada, moedas, trilhas)
-- ---------------------------------------------------------------------
create or replace function gruta.meu_plano(p_uid uuid default auth.uid())
returns text language sql stable security definer set search_path = gruta as $$
  select coalesce((select plano from gruta.perfis where id = p_uid), 'visitante');
$$;

create or replace function gruta.moedas_ganhas(p_uid uuid default auth.uid())
returns int language sql stable security definer set search_path = gruta as $$
  select count(*)::int
    from gruta.progresso_aulas p join gruta.aulas a on a.id = p.aula_id
   where p.usuario_id = p_uid and p.concluida_em is not null
     and a.trilha_id is null and a.ordem = any (gruta.marcos_moeda());
$$;

create or replace function gruta.trilha_aberta(p_trilha uuid, p_uid uuid default auth.uid())
returns boolean language sql stable security definer set search_path = gruta as $$
  select gruta.meu_plano(p_uid) = 'mestre'
      or exists (select 1 from gruta.trilhas_liberadas
                  where usuario_id = p_uid and trilha_id = p_trilha);
$$;

-- Pode ver o vídeo desta aula? (admin vê tudo)
create or replace function gruta.pode_ver_aula(p_trilha uuid, p_ordem int)
returns boolean language sql stable security definer set search_path = gruta as $$
  select auth.uid() is not null and (
    gruta.eh_admin()
    or (p_trilha is null and p_ordem < gruta.plano_aulas_jornada(gruta.meu_plano()))
    or (p_trilha is not null and gruta.trilha_aberta(p_trilha)));
$$;

-- View que o app lê. Roda com as permissões do dono (enxerga a tabela
-- aulas) e devolve video_url vazio quando a pessoa ainda não pode ver.
create or replace view gruta.aulas_app as
  select a.id, a.trilha_id, a.ordem, a.titulo, a.descricao, a.reflexao,
         case when gruta.pode_ver_aula(a.trilha_id, a.ordem)
              then a.video_url else '' end as video_url,
         a.duracao_seg, a.capa_url
    from gruta.aulas a
    left join gruta.trilhas t on t.id = a.trilha_id
   where gruta.eh_admin()
      or (a.publicada and a.publicar_em <= now()
          and (a.trilha_id is null or t.publicada));
revoke all on gruta.aulas_app from anon, public;
grant select on gruta.aulas_app to authenticated;

-- ---------------------------------------------------------------------
-- 7. Funções chamadas pelo app
-- ---------------------------------------------------------------------

-- Conclui uma aula (atômico). Confere as regras no servidor:
--   * Jornada: na ordem, dentro do plano e UMA por dia de calendário
--     (a próxima abre depois da meia-noite no fuso da pessoa);
--   * Trilha: precisa estar liberada; uma aula nova por dia em cada trilha.
create or replace function gruta.concluir_aula(
  p_aula_id uuid, p_assistido_seg int, p_dia_local date default null)
returns json language plpgsql security definer set search_path = gruta as $$
declare
  v_uid   uuid := auth.uid();
  v_aula  gruta.aulas%rowtype;
  v_fuso  text;
  v_dia   date;
  v_nova  boolean;
  v_ja    boolean;
begin
  if v_uid is null then raise exception 'não autenticado'; end if;
  perform 1 from gruta.perfis where id = v_uid for update; -- uma conclusão por vez
  if not found then raise exception 'perfil da Gruta não encontrado'; end if;

  select * into v_aula from gruta.aulas
   where id = p_aula_id and publicada and publicar_em <= now();
  if not found then raise exception 'aula não encontrada'; end if;

  select fuso into v_fuso from gruta.perfis where id = v_uid;
  v_dia := (now() at time zone coalesce(v_fuso, 'America/Sao_Paulo'))::date;
  if p_dia_local is not null and abs(p_dia_local - v_dia) <= 1 then
    v_dia := p_dia_local;
  end if;

  v_ja := exists (select 1 from gruta.progresso_aulas
                   where usuario_id = v_uid and aula_id = p_aula_id
                     and concluida_em is not null);

  if not v_ja then
    if v_aula.trilha_id is null then
      if v_aula.ordem >= gruta.plano_aulas_jornada(gruta.meu_plano(v_uid)) then
        raise exception 'aula fora do seu plano';
      end if;
      if exists (select 1 from gruta.aulas a
                  where a.trilha_id is null and a.publicada and a.ordem < v_aula.ordem
                    and not exists (select 1 from gruta.progresso_aulas p
                                     where p.usuario_id = v_uid and p.aula_id = a.id
                                       and p.concluida_em is not null)) then
        raise exception 'conclua as aulas anteriores da Jornada';
      end if;
      if exists (select 1 from gruta.progresso_aulas p join gruta.aulas a on a.id = p.aula_id
                  where p.usuario_id = v_uid and a.trilha_id is null and p.dia_local = v_dia) then
        raise exception 'a próxima aula da Jornada abre amanhã';
      end if;
    else
      if not gruta.trilha_aberta(v_aula.trilha_id, v_uid) then
        raise exception 'trilha ainda não liberada';
      end if;
      if exists (select 1 from gruta.progresso_aulas p join gruta.aulas a on a.id = p.aula_id
                  where p.usuario_id = v_uid and a.trilha_id = v_aula.trilha_id
                    and p.dia_local = v_dia) then
        raise exception 'a próxima aula desta trilha abre amanhã';
      end if;
    end if;
  end if;

  insert into gruta.progresso_aulas (usuario_id, aula_id, assistido_seg, concluida_em, dia_local)
  values (v_uid, p_aula_id, greatest(p_assistido_seg, 0), now(), v_dia)
  on conflict (usuario_id, aula_id) do update
    set assistido_seg = greatest(progresso_aulas.assistido_seg, excluded.assistido_seg),
        concluida_em  = coalesce(progresso_aulas.concluida_em, excluded.concluida_em),
        dia_local     = coalesce(progresso_aulas.dia_local, excluded.dia_local),
        atualizado_em = now()
  returning (xmax = 0) into v_nova;

  if v_nova then
    insert into gruta.dias_estudo (usuario_id, dia, aulas, segundos)
    values (v_uid, v_dia, 1, v_aula.duracao_seg)
    on conflict (usuario_id, dia) do update
      set aulas = dias_estudo.aulas + 1,
          segundos = dias_estudo.segundos + excluded.segundos;
  end if;

  return json_build_object('dia', v_dia, 'nova', v_nova,
                           'moedas_ganhas', gruta.moedas_ganhas(v_uid));
end $$;

-- Gasta uma moeda numa trilha. Moedas disponíveis =
-- mínimo(ganhas, limite do plano) - trilhas já liberadas por moeda.
create or replace function gruta.gastar_moeda(p_trilha_id uuid)
returns json language plpgsql security definer set search_path = gruta as $$
declare
  v_uid    uuid := auth.uid();
  v_plano  text;
  v_gastas int;
  v_livres int;
begin
  if v_uid is null then raise exception 'não autenticado'; end if;
  select plano into v_plano from gruta.perfis where id = v_uid for update;
  if not found then raise exception 'perfil da Gruta não encontrado'; end if;
  if not exists (select 1 from gruta.trilhas where id = p_trilha_id and publicada) then
    raise exception 'trilha não encontrada';
  end if;
  if gruta.trilha_aberta(p_trilha_id, v_uid) then
    return json_build_object('ok', true, 'ja_aberta', true);
  end if;
  select count(*) into v_gastas from gruta.trilhas_liberadas
   where usuario_id = v_uid and origem = 'moeda';
  v_livres := least(gruta.moedas_ganhas(v_uid), gruta.plano_limite_trilhas(v_plano)) - v_gastas;
  if v_livres <= 0 then raise exception 'sem moedas disponíveis'; end if;
  insert into gruta.trilhas_liberadas (usuario_id, trilha_id, origem)
  values (v_uid, p_trilha_id, 'moeda');
  return json_build_object('ok', true, 'moedas', v_livres - 1);
end $$;

-- Troca de plano SEM pagamento, só enquanto config.planos_teste = true.
-- Mestre ainda não está disponível.
create or replace function gruta.escolher_plano_teste(p_plano text)
returns void language plpgsql security definer set search_path = gruta as $$
begin
  if auth.uid() is null then raise exception 'não autenticado'; end if;
  if not gruta.config_bool('planos_teste') then
    raise exception 'pagamento necessário';
  end if;
  if p_plano not in ('visitante', 'aprendiz') then
    raise exception 'plano indisponível';
  end if;
  update gruta.perfis set plano = p_plano where id = auth.uid();
end $$;

-- Ofensiva calculada no servidor (mesmas regras de lib/logic/ofensiva.dart).
create or replace function gruta.minha_ofensiva(p_usuario uuid default auth.uid())
returns table (atual int, recorde int, feito_hoje boolean, amuletos int)
language plpgsql stable security definer set search_path = gruta as $$
declare
  v_fuso  text;
  v_hoje  date;
  v_d     date;
  v_atual int := 0; v_rec int := 0; v_amu int := 0;
  v_tem   boolean;
begin
  if p_usuario is distinct from auth.uid() and auth.role() <> 'service_role' then
    raise exception 'sem permissão';
  end if;
  select fuso into v_fuso from gruta.perfis where id = p_usuario;
  v_hoje := (now() at time zone coalesce(v_fuso, 'America/Sao_Paulo'))::date;
  select min(dia) into v_d from gruta.dias_estudo where usuario_id = p_usuario;
  if v_d is null then
    return query select 0, 0, false, 0; return;
  end if;
  while v_d <= v_hoje loop
    v_tem := exists (select 1 from gruta.dias_estudo where usuario_id = p_usuario and dia = v_d);
    if v_tem then
      v_atual := v_atual + 1;
      if v_atual % 7 = 0 and v_amu < 2 then v_amu := v_amu + 1; end if;
    elsif v_d = v_hoje then
      null;
    elsif v_atual > 0 and v_amu > 0 then
      v_amu := v_amu - 1;
    else
      v_atual := 0;
    end if;
    v_rec := greatest(v_rec, v_atual);
    v_d := v_d + 1;
  end loop;
  return query select v_atual, v_rec,
    exists (select 1 from gruta.dias_estudo where usuario_id = p_usuario and dia = v_hoje),
    v_amu;
end $$;

-- Excluir a própria conta (Apple e Google exigem). Só para contas da Gruta:
-- quem é só cliente da Cosmória/Sítio não é apagado por aqui.
create or replace function gruta.excluir_minha_conta()
returns void language plpgsql security definer set search_path = gruta, auth as $$
begin
  if auth.uid() is null then raise exception 'não autenticado'; end if;
  if not exists (select 1 from auth.users
                  where id = auth.uid() and raw_app_meta_data->>'app' = 'gruta') then
    raise exception 'esta conta não é da Gruta';
  end if;
  delete from auth.users where id = auth.uid();
end $$;

revoke execute on all functions in schema gruta from public, anon;
grant execute on function gruta.eh_admin() to anon, authenticated;
grant execute on function gruta.concluir_aula(uuid, int, date) to authenticated;
grant execute on function gruta.gastar_moeda(uuid) to authenticated;
grant execute on function gruta.escolher_plano_teste(text) to authenticated;
grant execute on function gruta.minha_ofensiva(uuid) to authenticated;
grant execute on function gruta.excluir_minha_conta() to authenticated;
-- usadas dentro das policies e da view:
grant execute on function gruta.pode_ver_aula(uuid, int) to authenticated;
grant execute on function gruta.meu_plano(uuid) to authenticated;
grant execute on function gruta.trilha_aberta(uuid, uuid) to authenticated;
grant execute on function gruta.plano_aulas_jornada(text) to authenticated;
grant execute on function gruta.marcos_moeda() to authenticated;
grant execute on function gruta.moedas_ganhas(uuid) to authenticated;
grant execute on function gruta.config_bool(text) to authenticated;
grant execute on all functions in schema gruta to service_role;

-- ---------------------------------------------------------------------
-- 8. Storage: vídeos e capas das aulas (bucket público "gruta")
-- ---------------------------------------------------------------------
-- 50 MB por arquivo é o limite do plano gratuito do Supabase.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('gruta', 'gruta', true, 52428800,
        array['video/mp4', 'video/quicktime', 'video/webm',
              'image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

drop policy if exists gruta_admin_enviar on storage.objects;
create policy gruta_admin_enviar on storage.objects
  for insert to authenticated with check (bucket_id = 'gruta' and gruta.eh_admin());
drop policy if exists gruta_admin_trocar on storage.objects;
create policy gruta_admin_trocar on storage.objects
  for update to authenticated using (bucket_id = 'gruta' and gruta.eh_admin());
drop policy if exists gruta_admin_apagar on storage.objects;
create policy gruta_admin_apagar on storage.objects
  for delete to authenticated using (bucket_id = 'gruta' and gruta.eh_admin());
drop policy if exists gruta_admin_listar on storage.objects;
create policy gruta_admin_listar on storage.objects
  for select to authenticated using (bucket_id = 'gruta' and gruta.eh_admin());
