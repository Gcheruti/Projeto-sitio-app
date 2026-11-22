# Gruta

App de cursos em vídeo curtos, no estilo "ofensiva" do Duolingo: todo dia uma
aula nova de uns 5 minutos sobre bruxaria, ocultismo, tarô, angelologia,
búzios, bruxaria natural, chás medicinais e cura pelas plantas.

Flutter para **Android, iOS e navegador**, com o **mesmo layout** em todos
(uma coluna central de até 480 px; no computador sobra a "gruta" escura dos lados).

## Começar em 1 minuto

```bash
cd ~/Sitio/Claude/Gruta_app
flutter pub get
flutter run -d chrome        # abre no Chrome, em modo demonstração
```

Sem o Supabase configurado o app abre em **modo demonstração**: catálogo de
exemplo, progresso salvo só no aparelho. Tudo sobre `flutter run` (escolher
celular, emulador, Chrome) está em [docs/COMO_RODAR.md](docs/COMO_RODAR.md).

## A ideia (o que está pronto)

| Parte | O que faz |
|---|---|
| **Cadastro** | Nome completo, data de nascimento, usuário, senha e plano. Entra-se com **usuário e senha** (Google: em breve). |
| **Planos** | Visitante (grátis: aula piloto + 2 aulas), Aprendiz (R$ 19,90/mês: Jornada completa e até 4 trilhas), Mestre (em desenvolvimento: todas as trilhas). |
| **Jornada** | 60 aulas diárias genéricas, da aula piloto (0) à 59. **Uma por dia de calendário**: concluiu hoje, a próxima abre depois da meia-noite. |
| **Moedas** | Concluir as aulas 5, 15, 30, 45 e 59 da Jornada dá uma moeda, com pop-up "você desbloqueou uma trilha de conhecimento nova". |
| **Trilhas** | As 8 trilhas começam com cadeado. Tocar numa trilha gasta uma moeda (ou mostra "comprar esta trilha", em breve). Contador de moedas no topo. |
| **Vela (ofensiva)** | Cada dia com pelo menos uma aula acende a vela. Amuleto a cada 7 dias seguidos (máx. 2) salva um dia perdido. |
| **Grimório** | Caderno pessoal com as anotações das aulas. |
| **Lives** | Aba nova, "em desenvolvimento" (depois: calendário e lives no app). |
| **Perfil** | Números, plano, ritual (meta e lembrete), sair e excluir conta. A **engrenagem** abre: nome de exibição, dados do cadastro (e senha) e tema escuro / claro / seguir o aparelho. |
| **Avisos** | Sino na tela Hoje com os avisos enviados pela equipe. |
| **Outros serviços** | Botão flutuante no canto superior direito das abas: Cosmória, Sítio dos Coelhos e Consultas. |
| **Modo /adm** | No site, abrir o endereço com `/adm` (ou `#/adm`). Mesma tela, mais um ícone de ferramentas: enviar avisos e cuidar das aulas (textos, vídeo e capa direto do computador). Ver [docs/ADMIN.md](docs/ADMIN.md). |

Regras ajustáveis: `lib/logic/regras.dart` (Jornada, marcos de moeda),
`lib/models/plano.dart` (planos) e `lib/config/app_config.dart`. O banco
repete as mesmas regras, então mudou aqui, muda lá também.

## Estrutura

```
lib/
  main.dart                 portão: apresentação -> entrar -> app
  config/app_config.dart    Supabase (--dart-define) e regras do jogo
  theme/gruta_tema.dart     cores (gruta, lamparina, arenito) e fontes
  logic/ofensiva.dart       cálculo da ofensiva e amuletos (com testes)
  logic/regras.dart         Jornada, moedas e planos (com testes)
  logic/datas.dart          datas em português
  models/                   Trilha, Aula, Plano, Perfil, NotaGrimorio, Notificacao
  data/catalogo_demo.dart   trilhas e aulas de exemplo (modo demonstração)
  data/jornada_demo.dart    as 60 aulas de exemplo da Jornada
  data/servicos.dart        lista "Conheça nossos outros serviços" (endereços)
  services/
    repositorio.dart        contrato de dados
    repositorio_local.dart  modo demonstração (shared_preferences)
    repositorio_supabase.dart  banco real
    lembrete_service.dart   notificações locais diárias
  state/                    app_state, auth_state (login) e tema_state
  screens/                  abertura, entrar (cadastro), shell (5 abas), hoje,
                            trilhas, trilha, aula, conclusao, grimorio, lives,
                            perfil, configuracoes, planos, avisos, servicos,
                            liberar_trilha, admin (painel /adm)
  widgets/                  vela animada, fundo da gruta, cartões, semana
supabase/migrations/        schema gruta (estrutura + catálogo de exemplo)
supabase/functions/         gruta-cadastro (criar conta) e gruta-push (esqueleto)
docs/                       como rodar, permissões/iOS, arquitetura, negócio, publicar
test/                       testes da ofensiva e das regras
```

Mesmo padrão do app do Sítio: `ChangeNotifier` global (`appState`,
`authState`) + `ListenableBuilder`, nomes em português.

## Documentos

- [docs/COMO_RODAR.md](docs/COMO_RODAR.md): `flutter run`, dispositivos, Chrome, emulador, Supabase.
- [docs/PERMISSOES.md](docs/PERMISSOES.md): o que foi configurado no iOS e no Android e por quê.
- [docs/ARQUITETURA.md](docs/ARQUITETURA.md): schema gruta no Supabase, segurança e onde guardar os vídeos.
- [docs/ADMIN.md](docs/ADMIN.md): modo /adm, avisos, envio de vídeos e como virar administrador.
- [docs/NEGOCIO.md](docs/NEGOCIO.md): planos, moedas e regras das lojas.
- [docs/PUBLICAR.md](docs/PUBLICAR.md): passos para Play Store e App Store.

## Verificado

- `flutter analyze`: sem avisos. `flutter test`: 13 testes (ofensiva e regras) passando.
- `flutter build web`: compila; telas conferidas no navegador, no tema escuro e no claro, inclusive o modo `/adm`.
- Banco: as duas migrations rodadas duas vezes num PostgreSQL 16, com RLS
  testado: visitante só vê 3 aulas, uma aula da Jornada por dia, moedas e
  limite de 4 trilhas, só admin grava aulas, avisos e arquivos.
- **Não testado aqui:** build Android e iOS (precisa do Android SDK/Mac) e as
  Edge Functions (precisam do Supabase). Rode `flutter run` no celular para conferir.
