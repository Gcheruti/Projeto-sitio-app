# Registro de acessos

Tudo fica na tabela `gruta.eventos`: uma linha por acontecimento, com a pessoa,
o horário e (quando faz sentido) a aula ou a trilha.

| Tipo | Quem grava | Quando |
|---|---|---|
| `cadastro` | app | criou a conta |
| `login` | app | entrou com usuário e senha |
| `logout` | app | tocou em "Sair" |
| `app_aberto` | app | abriu o app já logado |
| `app_retomado` | app | voltou ao app depois de 30 min ou mais |
| `aula_aberta` | app | abriu a tela de uma aula |
| `tutorial_concluido` | app | terminou ou pulou o tutorial |
| `aula_concluida` | banco | concluiu uma aula (gatilho em progresso_aulas) |
| `trilha_liberada` | banco | liberou uma trilha (gatilho em trilhas_liberadas) |
| `plano_alterado` | banco | mudou de plano (gatilho em perfis) |

Os tipos ficam em `gruta.tipos_evento`. Para um tipo novo, basta inserir uma
linha (origem `app` se o app vai gravar, `servidor` se só o banco grava).

## Consultas prontas (Supabase › SQL Editor ou Table Editor › schema gruta)

```sql
-- A "planilha": tudo, do mais recente para o mais antigo (horário de Brasília)
select data_hora, login, nome_completo, acao, aula, trilha_da_aula, trilha, plataforma
  from gruta.v_acessos order by criado_em desc limit 500;

-- Quem está há 7 dias ou mais sem acessar (base para o aviso de inatividade)
select login, nome_completo, ultimo_acesso, dias_sem_acessar
  from gruta.v_ultimo_acesso where dias_sem_acessar >= 7 order by dias_sem_acessar desc;

-- Aulas mais vistas
select * from gruta.v_aulas_mais_vistas order by aberturas desc, conclusoes desc;

-- Frequência por dia
select * from gruta.v_frequencia_diaria order by dia desc;
```

Para levar para uma planilha: no SQL Editor, rode a consulta e use
"Export > CSV" (abre no Excel ou Google Planilhas).

## Privacidade
Cada pessoa só enxerga os próprios eventos; administradores (perfis.papel =
'admin') enxergam todos. Ninguém consegue gravar evento em nome de outra
pessoa, nem apagar ou editar eventos pelo app. Ao excluir a conta, os eventos
dela são apagados junto.
