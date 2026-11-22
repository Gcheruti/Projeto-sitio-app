-- Ícone de cada freelancer (escolhido no cadastro/edição). Rode uma vez no SQL Editor.
alter table public.usuarios add column if not exists icone text;

-- Mantém o que já aparecia na agenda para os freelancers de teste (só se ainda não tiverem ícone).
update public.usuarios set icone = 'estrela' where papel = 'freelancer' and icone is null and lower(login) = 'pedro';
update public.usuarios set icone = 'coracao' where papel = 'freelancer' and icone is null and lower(login) = 'maria';
update public.usuarios set icone = 'pegada'  where papel = 'freelancer' and icone is null and lower(login) = 'joao';
update public.usuarios set icone = 'folha'   where papel = 'freelancer' and icone is null and lower(login) = 'ana';
