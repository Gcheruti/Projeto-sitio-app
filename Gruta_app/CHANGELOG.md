# Registro de mudanças da Gruta

A versão fica em `pubspec.yaml` (`version: X.Y.Z+N`) e em
`lib/config/app_config.dart` (`versaoApp`), sempre iguais.
`X.Y.Z` é o número que as pessoas veem; `+N` sobe 1 a cada APK/IPA enviado
às lojas (o Google e a Apple exigem que só aumente).

## 1.0.1 (build 2) · 21/11/2026

- Questionário de interesses e ritual diário agora vem **depois** do login
  e fica salvo na conta (não aparece de novo). Dá para mudar em
  Perfil › Configurações.
- App liga direto no Supabase: não precisa mais de `--dart-define`.
  Modo demonstração só com `--dart-define=GRUTA_DEMO=true`.
- **Tutorial** da primeira entrada (tela escura com destaque): avisos,
  serviços, vela, aula do dia, moedas, Trilhas, Grimório, Lives e Perfil.
  Aparece uma vez por conta; "Rever tutorial do app" nas Configurações.
- Cadastro com **telefone** e **e-mail** (contato), editáveis em
  "Dados do cadastro". SQL: `20261121000003_gruta_contato.sql`.
- **Registro de acessos** (`gruta.eventos`): login, logout, cadastro, app
  aberto, aula aberta/concluída, trilha liberada, troca de plano, com
  visões para relatórios. SQL: `20261121000004_gruta_acessos.sql`.
  Ver `docs/ACESSOS.md`.
- **Ícone** provisório (vela no arco da gruta) no Android (inclui ícone
  adaptativo), iOS e web.

## 1.0.0 (build 1)

- Primeira versão: Jornada de 60 aulas, trilhas com moedas, Grimório,
  Lives, planos, painel /adm, temas claro e escuro.
