-- =====================================================================
-- GRUTA · registro de acessos (quem entrou, quando, o que assistiu)
-- =====================================================================
-- Uma linha por acontecimento: cadastro, login, logout, app aberto,
-- aula aberta, aula concluída, trilha liberada, troca de plano...
--
-- * O app grava pela função gruta.registrar_evento (a pessoa e o horário
--   vêm do servidor, ninguém consegue gravar em nome de outro).
-- * Aula concluída, trilha liberada e troca de plano são gravadas pelo
--   próprio banco (gatilhos), então valem mesmo se o app falhar.
-- * Os tipos ficam na tabela gruta.tipos_evento: para criar um tipo novo
--   no futuro basta inserir uma linha, sem mudar o app nem esta estrutura.
-- * Visões prontas para consulta (as "planilhas"):
--     gruta.v_acessos            tudo, com nome, aula e horário de Brasília
--     gruta.v_ultimo_acesso      último acesso e dias sem entrar (avisos)
--     gruta.v_aulas_mais_vistas  aberturas, conclusões e pessoas por aula
--     gruta.v_frequencia_diaria  pessoas ativas e logins por dia
--   Só administradores (e o painel do Supabase) enxergam os dados de todos.
--
-- Pode rodar mais de uma vez sem problema.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Tipos de evento (parametrizável)
-- ---------------------------------------------------------------------
create table if not exists gruta.tipos_evento (
  tipo       text primary key check (tipo ~ '^[a-z_]{3,40}$'),
  descricao  text not null,
  origem     text not null default 'app' check (origem in ('app', 'servidor'))
);
comment on table gruta.tipos_evento is
  'Tipos aceitos em gruta.eventos. origem=app: o app pode gravar; servidor: só gatilhos do banco.';

insert into gruta.tipos_evento (tipo, descricao, origem) values
  ('cadastro',           'Criou a conta',                 'app'),
  ('login',              'Entrou no app',                 'app'),
  ('logout',             'Saiu do app',                   'app'),
  ('app_aberto',         'Abriu o app (já logado)',       'app'),
  ('app_retomado',       'Voltou ao app depois de 30 min','app'),
  ('aula_aberta',        'Abriu uma aula',                'app'),
  ('tutorial_concluido', 'Terminou o tutorial',           'app'),
  ('aula_concluida',     'Concluiu uma aula',             'servidor'),
  ('trilha_liberada',    'Liberou uma trilha',            'servidor'),
  ('plano_alterado',     'Mudou de plano',                'servidor')
on conflict (tipo) do update
  set descricao = excluded.descricao, origem = excluded.origem;

alter table gruta.tipos_evento enable row level security;
drop policy if exists tipos_evento_ler on gruta.tipos_evento;
create policy tipos_evento_ler on gruta.tipos_evento
  for select to authenticated using (true);
drop policy if exists tipos_evento_admin on gruta.tipos_evento;
create policy tipos_evento_admin on gruta.tipos_evento
  for all to authenticated using (gruta.eh_admin()) with check (gruta.eh_admin());
revoke all on gruta.tipos_evento from anon, authenticated;
grant select, insert, update, delete on gruta.tipos_evento to authenticated;

-- ---------------------------------------------------------------------
-- 2. Eventos
-- ---------------------------------------------------------------------
create table if not exists gruta.eventos (
  id          bigint generated always as identity primary key,
  usuario_id  uuid not null references auth.users(id) on delete cascade,
  tipo        text not null references gruta.tipos_evento(tipo) on update cascade,
  aula_id     uuid references gruta.aulas(id) on delete set null,
  trilha_id   uuid references gruta.trilhas(id) on delete set null,
  plataforma  text check (plataforma is null or char_length(plataforma) <= 20),
  versao_app  text check (versao_app is null or char_length(versao_app) <= 20),
  detalhes    jsonb not null default '{}'::jsonb
                check (pg_column_size(detalhes) <= 2048),
  criado_em   timestamptz not null default now()
);
comment on table gruta.eventos is
  'Registro de acessos: uma linha por login, logout, aula aberta/concluída etc.';

create index if not exists eventos_usuario_data on gruta.eventos (usuario_id, criado_em desc);
create index if not exists eventos_tipo_data    on gruta.eventos (tipo, criado_em desc);
create index if not exists eventos_aula         on gruta.eventos (aula_id) where aula_id is not null;
create index if not exists eventos_data         on gruta.eventos (criado_em desc);

alter table gruta.eventos enable row level security;
drop policy if exists eventos_ler on gruta.eventos;
create policy eventos_ler on gruta.eventos
  for select to authenticated using (usuario_id = auth.uid() or gruta.eh_admin());
revoke all on gruta.eventos from anon, authenticated;
grant select on gruta.eventos to authenticated;
-- gravação só pela função abaixo e pelos gatilhos.

-- ---------------------------------------------------------------------
-- 3. Função que o app chama
-- ---------------------------------------------------------------------
create or replace function gruta.registrar_evento(
  p_tipo       text,
  p_aula_id    uuid  default null,
  p_trilha_id  uuid  default null,
  p_plataforma text  default null,
  p_versao     text  default null,
  p_detalhes   jsonb default '{}'::jsonb
) returns void
language plpgsql security definer set search_path = gruta as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'Precisa estar logado.' using errcode = '42501';
  end if;
  if not exists (select 1 from gruta.tipos_evento where tipo = p_tipo and origem = 'app') then
    raise exception 'Tipo de evento inválido: %', p_tipo using errcode = '22023';
  end if;
  -- Ids que não existem (ex.: aula apagada) viram nulo em vez de erro.
  if p_aula_id is not null and not exists (select 1 from gruta.aulas where id = p_aula_id) then
    p_aula_id := null;
  end if;
  if p_trilha_id is not null and not exists (select 1 from gruta.trilhas where id = p_trilha_id) then
    p_trilha_id := null;
  end if;
  insert into gruta.eventos (usuario_id, tipo, aula_id, trilha_id, plataforma, versao_app, detalhes)
  values (v_uid, p_tipo, p_aula_id, p_trilha_id,
          left(p_plataforma, 20), left(p_versao, 20), coalesce(p_detalhes, '{}'::jsonb));
end $$;
revoke all on function gruta.registrar_evento(text, uuid, uuid, text, text, jsonb) from public, anon;
grant execute on function gruta.registrar_evento(text, uuid, uuid, text, text, jsonb) to authenticated;

-- ---------------------------------------------------------------------
-- 4. Gatilhos: o que o banco já sabe, ele mesmo registra
-- ---------------------------------------------------------------------
create or replace function gruta.evento_aula_concluida()
returns trigger language plpgsql security definer set search_path = gruta as $$
begin
  if new.concluida_em is not null
     and (tg_op = 'INSERT' or old.concluida_em is null) then
    insert into gruta.eventos (usuario_id, tipo, aula_id, trilha_id, detalhes)
    select new.usuario_id, 'aula_concluida', new.aula_id, a.trilha_id,
           jsonb_build_object('assistido_seg', new.assistido_seg)
      from gruta.aulas a where a.id = new.aula_id;
  end if;
  return new;
end $$;
drop trigger if exists progresso_evento on gruta.progresso_aulas;
create trigger progresso_evento after insert or update of concluida_em on gruta.progresso_aulas
  for each row execute function gruta.evento_aula_concluida();

create or replace function gruta.evento_trilha_liberada()
returns trigger language plpgsql security definer set search_path = gruta as $$
begin
  insert into gruta.eventos (usuario_id, tipo, trilha_id, detalhes)
  values (new.usuario_id, 'trilha_liberada', new.trilha_id,
          jsonb_build_object('origem', new.origem));
  return new;
end $$;
drop trigger if exists liberada_evento on gruta.trilhas_liberadas;
create trigger liberada_evento after insert on gruta.trilhas_liberadas
  for each row execute function gruta.evento_trilha_liberada();

create or replace function gruta.evento_plano_alterado()
returns trigger language plpgsql security definer set search_path = gruta as $$
begin
  if new.plano is distinct from old.plano then
    insert into gruta.eventos (usuario_id, tipo, detalhes)
    values (new.id, 'plano_alterado',
            jsonb_build_object('de', old.plano, 'para', new.plano));
  end if;
  return new;
end $$;
drop trigger if exists perfis_plano_evento on gruta.perfis;
create trigger perfis_plano_evento after update of plano on gruta.perfis
  for each row execute function gruta.evento_plano_alterado();

-- ---------------------------------------------------------------------
-- 5. Visões para consulta e relatórios
-- (security_invoker: respeitam o RLS; admin vê todos, a pessoa só a si)
-- ---------------------------------------------------------------------

-- A "planilha" completa, em horário de Brasília.
create or replace view gruta.v_acessos with (security_invoker = true) as
select e.id,
       (e.criado_em at time zone 'America/Sao_Paulo')::timestamp(0) as data_hora,
       p.login,
       p.nome_completo,
       e.tipo,
       t.descricao                       as acao,
       a.titulo                          as aula,
       case when a.id is null then null
            when a.trilha_id is null then 'Jornada'
            else tr.titulo end           as trilha_da_aula,
       tl.titulo                         as trilha,
       e.plataforma,
       e.versao_app,
       e.detalhes,
       e.usuario_id,
       e.criado_em
  from gruta.eventos e
  left join gruta.perfis p       on p.id  = e.usuario_id
  left join gruta.tipos_evento t on t.tipo = e.tipo
  left join gruta.aulas a        on a.id  = e.aula_id
  left join gruta.trilhas tr     on tr.id = a.trilha_id
  left join gruta.trilhas tl     on tl.id = e.trilha_id;

-- Último acesso de cada pessoa (base para avisos de inatividade).
create or replace view gruta.v_ultimo_acesso with (security_invoker = true) as
select p.id as usuario_id,
       p.login,
       p.nome_completo,
       p.plano,
       (p.criado_em at time zone 'America/Sao_Paulo')::timestamp(0) as cadastro_em,
       (u.ultimo at time zone 'America/Sao_Paulo')::timestamp(0)    as ultimo_acesso,
       (u.ultimo_login at time zone 'America/Sao_Paulo')::timestamp(0) as ultimo_login,
       (current_date - (coalesce(u.ultimo, p.criado_em) at time zone 'America/Sao_Paulo')::date)
                                                                    as dias_sem_acessar,
       coalesce(u.aulas_concluidas, 0) as aulas_concluidas,
       coalesce(u.logins, 0)           as logins
  from gruta.perfis p
  left join lateral (
    select max(e.criado_em)                                        as ultimo,
           max(e.criado_em) filter (where e.tipo = 'login')        as ultimo_login,
           count(*) filter (where e.tipo = 'aula_concluida')       as aulas_concluidas,
           count(*) filter (where e.tipo = 'login')                as logins
      from gruta.eventos e where e.usuario_id = p.id
  ) u on true;

-- Aulas mais vistas.
create or replace view gruta.v_aulas_mais_vistas with (security_invoker = true) as
select a.id as aula_id,
       coalesce(t.titulo, 'Jornada') as trilha,
       a.ordem,
       a.titulo as aula,
       count(*) filter (where e.tipo = 'aula_aberta')                       as aberturas,
       count(*) filter (where e.tipo = 'aula_concluida')                    as conclusoes,
       count(distinct e.usuario_id) filter (where e.tipo = 'aula_aberta')   as pessoas_que_abriram,
       count(distinct e.usuario_id) filter (where e.tipo = 'aula_concluida') as pessoas_que_concluiram,
       (max(e.criado_em) at time zone 'America/Sao_Paulo')::timestamp(0)    as ultima_vez
  from gruta.aulas a
  left join gruta.trilhas t on t.id = a.trilha_id
  left join gruta.eventos e on e.aula_id = a.id
 group by a.id, t.titulo, a.ordem, a.titulo;

-- Frequência por dia (horário de Brasília).
create or replace view gruta.v_frequencia_diaria with (security_invoker = true) as
select (e.criado_em at time zone 'America/Sao_Paulo')::date as dia,
       count(distinct e.usuario_id)                                  as pessoas_ativas,
       count(*) filter (where e.tipo = 'login')                      as logins,
       count(*) filter (where e.tipo = 'cadastro')                   as cadastros,
       count(*) filter (where e.tipo = 'aula_aberta')                as aulas_abertas,
       count(*) filter (where e.tipo = 'aula_concluida')             as aulas_concluidas
  from gruta.eventos e
 group by 1;

revoke all on gruta.v_acessos, gruta.v_ultimo_acesso,
              gruta.v_aulas_mais_vistas, gruta.v_frequencia_diaria from anon;
grant select on gruta.v_acessos, gruta.v_ultimo_acesso,
                gruta.v_aulas_mais_vistas, gruta.v_frequencia_diaria to authenticated;
