# Modelo de negócio (proposta)

## Ideia central

Hábito diário curto: **5 minutos, uma vela por dia**. O que segura a pessoa é a
ofensiva (não querer apagar a vela), não a quantidade de conteúdo. Por isso:

- **Uma aula nova por dia por trilha.** Cria expectativa ("o que vem
  amanhã?") e faz o catálogo gravado durar mais.
- **Amuletos** perdoam um dia perdido a cada 7 dias seguidos: a pessoa não
  desiste por causa de um único esquecimento (o maior motivo de abandono em
  apps de ofensiva).
- **Lembrete só nos dias de vela apagada**: quem já estudou não é incomodado.
- **Grimório**: o que a pessoa escreve fica no app; é um motivo a mais para voltar.

## Planos

| | Visitante | Aprendiz | Mestre |
|---|---|---|---|
| Preço | grátis | R$ 19,90/mês | em desenvolvimento |
| Jornada | aula piloto + 2 aulas | as 60 aulas | as 60 aulas |
| Trilhas | nenhuma | até 4 das 8, com moedas | todas, sem moedas |
| Vela, amuletos, Grimório | sim | sim | sim |

## Jornada e moedas

- A **Jornada** são 60 aulas diárias genéricas (aula piloto + 59). Uma por dia
  de calendário: a próxima abre depois da meia-noite, não 24 horas depois.
- Concluir as aulas **5, 15, 30, 45 e 59** dá uma **moeda** (métrica
  provisória; muda em `lib/logic/regras.dart` e em `gruta.config`).
- Cada moeda abre a trilha que a pessoa escolher. O Aprendiz usa até 4; a
  quinta moeda serve de incentivo para o Mestre.
- Haverá também a **compra avulsa** de uma trilha, sem moeda (botão já está
  no app, "em breve").

Enquanto o pagamento não existe, `gruta.config.planos_teste = true` faz o
plano Aprendiz ser liberado só de escolher. **Desligar antes de lançar.**

O botão "Conheça nossos outros serviços" leva para a Cosmória (velas,
incensos) e o Sítio dos Coelhos (eventos, tarô, loja física, cursos
presenciais): o app vira porta de entrada para o resto da empresa.

## Regras das lojas (importante)

- **iPhone e Android: conteúdo digital vendido dentro do app tem que usar a
  compra da própria loja** (Apple In-App Purchase / Google Play Billing). As
  lojas ficam com 15% (programa para pequenas empresas, até US$ 1 milhão/ano)
  a 30%.
- Vender pelo **site** (Pix, cartão) não paga a taxa, mas as regras para
  mandar a pessoa do app para o site mudam conforme o país e estão mudando
  (EUA e Brasil tiveram decisões recentes). Conferir a regra vigente antes de
  colocar qualquer link de compra fora da loja dentro do app.
- Uma assinatura comprada no site pode liberar o app normalmente: a tabela
  `gruta.assinaturas` aceita `plataforma = 'web'`.

## Métricas para acompanhar

- Retenção D1 / D7 / D30 (quantos voltam no dia seguinte, em uma semana, em um mês).
- Ofensiva média e % de pessoas com ofensiva ≥ 7.
- Conversão Visitante → Aprendiz (o momento é a aula 3 da Jornada, quando o
  plano grátis acaba).
