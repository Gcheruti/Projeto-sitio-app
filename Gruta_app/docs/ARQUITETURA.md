# Arquitetura: schema `gruta` no Supabase e vídeos

## Onde fica o banco

No projeto Supabase que já existe (o mesmo do Sítio e da Cosmória), num
**schema só da Gruta**, chamado `gruta`. Nada é criado em `public`, e não há
gatilho em `auth.users`.

Por ser um app **público e comercial**:

- **RLS em todas as tabelas**: cada pessoa só lê e grava o que é dela;
- **funções atômicas** para o que vale "pontos" (concluir aula, gastar moeda),
  para ninguém forjar progresso mandando dados direto;
- **plano e papel** (admin) só mudam pelo servidor;
- a tabela `aulas` (que tem o endereço dos vídeos) só é lida por admin; o app
  lê a view `aulas_app`, que esconde o vídeo de quem ainda não pode ver.

## Login por usuário

O Supabase Auth trabalha com e-mail. A Gruta usa **usuário**: o app transforma
`cheruti` em `cheruti@usuarios.gruta.app`, um e-mail interno que ninguém
recebe. A conta é criada pela Edge Function `gruta-cadastro`, já confirmada,
porque o projeto exige confirmação de e-mail para os outros apps (Cosmória)
e isso não pode ser desligado para todos. As contas da Gruta levam
`app_metadata.app = 'gruta'`.

Consequência: **"esqueci minha senha" não chega por e-mail**. Por enquanto a
equipe troca a senha pelo painel do Supabase (Authentication > Users). Quando
entrar o login com Google, isso deixa de ser problema para quem usar Google.

## Tabelas (`supabase/migrations/20261121000001_gruta_estrutura.sql`)

| Tabela | Para quê | Quem grava |
|---|---|---|
| `config` | `planos_teste` (liberar plano sem pagamento) e `marcos_moeda` | equipe, pelo painel do Supabase |
| `perfis` | usuário, nome, nome completo, nascimento, plano, papel, meta, lembrete, fuso | a pessoa (menos usuário, plano e papel) |
| `assinaturas` | pagamentos (Apple, Google, web, cortesia); mantém `perfis.plano` | só o servidor (webhook) |
| `trilhas` | as 8 trilhas | admin |
| `aulas` | Jornada (`trilha_id` vazio, ordem 0 a 59) e aulas das trilhas | admin |
| `progresso_aulas` | aula concluída por pessoa, com o dia local | só a função `concluir_aula` |
| `dias_estudo` | um registro por dia com aula (base da ofensiva) | só a função `concluir_aula` |
| `trilhas_liberadas` | trilhas abertas com moeda (ou compradas) | só a função `gastar_moeda` |
| `grimorio_notas` | anotações | a pessoa |
| `notificacoes` | avisos do painel /adm | admin |

Funções que o app chama: `concluir_aula`, `gastar_moeda`,
`escolher_plano_teste`, `minha_ofensiva`, `excluir_minha_conta` (só apaga
contas da Gruta). Regras usadas pela view e pelas funções: `eh_admin`,
`pode_ver_aula`, `trilha_aberta`, `moedas_ganhas`.

Storage: bucket público `gruta` (vídeos e capas, até 50 MB por arquivo);
só admin envia, troca ou apaga.

`20261121000002_gruta_catalogo_exemplo.sql`: as 8 trilhas com 6 aulas cada
e as 60 aulas da Jornada, com vídeos de amostra.

`20261121000003_gruta_contato.sql`: colunas `telefone` e `email` (contato)
em `gruta.perfis`. O app funciona mesmo antes de rodar, só não grava o contato.

`20261121000004_gruta_acessos.sql`: registro de acessos (`gruta.eventos`) e
visões para relatórios. Ver [ACESSOS.md](ACESSOS.md).

### Depois de aplicar

1. Painel > Project Settings > **Data API > Exposed schemas**: adicionar `gruta`.
2. Publicar a função: `supabase functions deploy gruta-cadastro --no-verify-jwt`.
3. Virar admin (ver [ADMIN.md](ADMIN.md)).
4. Pronto: a URL e a chave publicável já estão em `lib/config/app_config.dart`.

## Onde guardar os vídeos

| Opção | Prós | Contras |
|---|---|---|
| **Supabase Storage** (bucket `gruta`, já pronto) | envio direto pelo painel /adm | 50 MB por arquivo no plano grátis; sem qualidade adaptável; link aberto |
| **Bunny Stream** | barato, HLS com qualidade adaptável, proteção de link | mais uma conta |
| **Cloudflare Stream / Mux** | HLS, ótimas ferramentas | mais caro |

Para começar, o Storage basta (vídeos de 5 min em 720p cabem em 50 MB). O
app toca qualquer MP4 ou HLS (`.m3u8`): trocar de serviço é só colar outro
endereço no editor da aula.

## Próximos passos técnicos

1. Pagamento: `in_app_purchase` ou RevenueCat + função que grava em
   `assinaturas`; depois desligar `planos_teste`.
2. Push com o app fechado (Firebase), ver [ADMIN.md](ADMIN.md).
3. Login com Google (e, no iPhone, com Apple, que passa a ser obrigatório).
4. Lives: calendário e player ao vivo.
5. Compra avulsa de trilhas (`trilhas_liberadas.origem = 'compra'`).
6. Ícone do app e capas reais das aulas.
