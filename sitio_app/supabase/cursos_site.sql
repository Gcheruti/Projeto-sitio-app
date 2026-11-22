-- Sítio · Inscrições do site em cursos/eventos -> baixa de vagas no estoque.
--
-- O site grava os formulários em site.cadastros (só inserção, chave pública).
-- Este script liga isso ao app:
--   * cada inscrição em CURSO ou EVENTO (categoria 'curso' ou 'evento_presenca')
--     vira uma linha em public.inscricoes_cursos e tira as vagas do produto
--     ligado ao evento (produtos.quantidade -= pessoas);
--   * se a inscrição for cancelada/recusada no site (status), as vagas voltam.
-- Nenhum dado pessoal (nome, telefone, e-mail) é copiado para o schema public.
-- Nunca bloqueia o site: se algo falhar, a inscrição é salva do mesmo jeito.
-- Pode rodar de novo sem problema.

-- Nome comparável: minúsculas, sem acento, sem "(3h)" no fim, espaços únicos.
create or replace function public.nome_norm(t text) returns text
language sql immutable as $$
  select btrim(regexp_replace(regexp_replace(
    translate(lower(coalesce(t, '')),
      'áàâãäéèêëíìîïóòôõöúùûüçñ', 'aaaaaeeeeiiiiooooouuuucn'),
    '\s*\([^)]*\)\s*$', ''), '\s+', ' ', 'g'));
$$;

create table if not exists public.inscricoes_cursos (
  id uuid primary key default gen_random_uuid(),
  cadastro_id uuid not null unique,   -- site.cadastros.id
  criado_em timestamptz not null default now(),
  origem text not null default 'site',
  categoria text,                     -- curso | evento_presenca
  evento_id uuid,                     -- agenda_eventos.id (quando houver)
  evento_titulo text,
  evento_inicio timestamptz,
  produto_id uuid,
  produto_nome text,
  quantidade integer not null default 1,
  valor_unitario numeric(10,2),
  valor_total numeric(10,2),
  -- baixado = vagas descontadas; registrado = produto sem controle de estoque;
  -- sem_vaga = não havia vagas suficientes; sem_produto = curso/evento sem item
  -- no estoque; cancelado = cancelado no site (vagas devolvidas)
  status text not null
);
create index if not exists inscricoes_cursos_data on public.inscricoes_cursos (criado_em desc);
create index if not exists inscricoes_cursos_produto on public.inscricoes_cursos (produto_id);

alter table public.inscricoes_cursos enable row level security;
drop policy if exists inscricoes_cursos_leitura on public.inscricoes_cursos;
create policy inscricoes_cursos_leitura on public.inscricoes_cursos
  for select to anon, authenticated using (true);

do $$ begin
  alter publication supabase_realtime add table public.inscricoes_cursos;
exception when others then null; end $$;

-- Inscrição nova vinda do site.
create or replace function public.site_registrar_inscricao()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_qtd integer := greatest(coalesce(new.pessoas, 1), 1);
  v_ev agenda_eventos%rowtype;
  v_prod produtos%rowtype;
  v_titulo text;
  v_status text;
begin
  if new.categoria not in ('curso', 'evento_presenca') then
    return new;
  end if;

  -- 1) evento da agenda escolhido no site (referencia_id = agenda_eventos.id)
  if new.referencia_id ~* '^[0-9a-f-]{36}$' then
    select * into v_ev from agenda_eventos where id = new.referencia_id::uuid;
  end if;

  -- 2) produto ligado ao evento
  if v_ev.produto_id ~* '^[0-9a-f-]{36}$' then
    select * into v_prod from produtos where id = v_ev.produto_id::uuid;
  end if;

  -- 3) sem ligação: procura pelo nome (do evento ou do texto escolhido no site,
  --    que vem como "Título · dd/mm/aaaa hh:mm")
  if v_prod.id is null then
    v_titulo := coalesce(v_ev.titulo, split_part(coalesce(new.referencia_titulo, ''), ' · ', 1));
    select * into v_prod from produtos
     where nome_norm(nome) = nome_norm(v_titulo)
     order by (ambiente = 'Gruta') desc limit 1;
  end if;

  if v_prod.id is null then
    v_status := 'sem_produto';
  elsif not coalesce(v_prod.controla_estoque, true) then
    v_status := 'registrado';
  else
    update produtos set quantidade = quantidade - v_qtd
     where id = v_prod.id and quantidade >= v_qtd;
    v_status := case when found then 'baixado' else 'sem_vaga' end;
  end if;

  insert into inscricoes_cursos (cadastro_id, criado_em, categoria, evento_id,
      evento_titulo, evento_inicio, produto_id, produto_nome, quantidade,
      valor_unitario, valor_total, status)
  values (new.id, new.criado_em, new.categoria, v_ev.id,
      coalesce(v_ev.titulo, split_part(coalesce(new.referencia_titulo, ''), ' · ', 1)),
      v_ev.inicio, v_prod.id, v_prod.nome, v_qtd,
      v_prod.preco, round((coalesce(v_prod.preco, 0) * v_qtd)::numeric, 2), v_status)
  on conflict (cadastro_id) do nothing;
  return new;
exception when others then
  raise warning 'site_registrar_inscricao: %', sqlerrm;
  return new; -- o site nunca fica sem salvar a inscrição
end $$;

-- Cancelado/recusado no site: devolve as vagas (uma vez só, e só se tinham
-- sido tiradas).
create or replace function public.site_cancelar_inscricao()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_ins inscricoes_cursos%rowtype;
begin
  if new.status in ('cancelado', 'cancelada', 'recusado', 'recusada')
     and old.status is distinct from new.status then
    select * into v_ins from inscricoes_cursos
     where cadastro_id = new.id and status <> 'cancelado';
    if v_ins.id is not null then
      update inscricoes_cursos set status = 'cancelado' where id = v_ins.id;
      if v_ins.status = 'baixado' then
        update produtos set quantidade = quantidade + v_ins.quantidade
         where id = v_ins.produto_id;
      end if;
    end if;
  end if;
  return new;
exception when others then
  raise warning 'site_cancelar_inscricao: %', sqlerrm;
  return new;
end $$;

drop trigger if exists inscricao_curso on site.cadastros;
create trigger inscricao_curso after insert on site.cadastros
  for each row execute function public.site_registrar_inscricao();

drop trigger if exists inscricao_curso_cancelada on site.cadastros;
create trigger inscricao_curso_cancelada after update of status on site.cadastros
  for each row execute function public.site_cancelar_inscricao();
