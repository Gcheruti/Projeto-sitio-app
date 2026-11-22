-- Gruta: telefone e e-mail de contato no cadastro.
-- O e-mail aqui é só para contato; quem entra no app usa o usuário (login).
-- Pode rodar mais de uma vez sem problema.

alter table gruta.perfis add column if not exists telefone text;
alter table gruta.perfis add column if not exists email text;

alter table gruta.perfis drop constraint if exists perfis_telefone_tamanho;
alter table gruta.perfis add constraint perfis_telefone_tamanho
  check (telefone is null or char_length(telefone) <= 30);

alter table gruta.perfis drop constraint if exists perfis_email_formato;
alter table gruta.perfis add constraint perfis_email_formato
  check (email is null or email = ''
         or (char_length(email) <= 160 and email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'));

comment on column gruta.perfis.telefone is 'Telefone de contato com DDD.';
comment on column gruta.perfis.email is 'E-mail de contato (não é usado para entrar).';

-- A própria pessoa pode atualizar o seu contato (a regra RLS de editar o
-- próprio perfil já existe; aqui só libera as duas colunas novas).
grant update (telefone, email) on gruta.perfis to authenticated;
