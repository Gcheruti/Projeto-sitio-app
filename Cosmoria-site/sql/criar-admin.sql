-- =====================================================================
-- PORTAL COSMORIA · CONTA DE ADMINISTRADOR
-- Antes de rodar: crie a conta em Supabase > Authentication > Users > "Add user" > "Create new user"
--   E-mail: adm@portalcosmoria.com.br   Senha: ADM123   (marque "Auto Confirm User")
-- Depois cole este arquivo no SQL Editor e clique em Run.
-- Só LÊ o login (auth.users) e grava o perfil no esquema "Cosmoria".
-- =====================================================================

-- 1) Diagnóstico: todas as contas de login, se o e-mail foi confirmado e se já têm perfil na Cosmoria
select u.email,
       u.created_at as criada_em,
       case when u.email_confirmed_at is null then 'NÃO confirmado (falta clicar no link do e-mail)' else 'confirmado' end as email,
       case when p.id is null then 'sem perfil na Cosmoria' else 'perfil ok · papel ' || coalesce(p.papel, '-') end as cosmoria
from auth.users u
left join "Cosmoria".perfis p on p.id = u.id
order by u.created_at desc;

-- 2) Cria (ou atualiza) o perfil de administrador da conta adm@portalcosmoria.com.br
insert into "Cosmoria".perfis (id, email, nome, papel)
select id, email, 'Administrador', 'admin' from auth.users where email = 'adm@portalcosmoria.com.br'
on conflict (id) do update set papel = 'admin';

-- 3) Conferência: deve aparecer adm@portalcosmoria.com.br como admin
select nome, email, papel from "Cosmoria".perfis where papel = 'admin';
