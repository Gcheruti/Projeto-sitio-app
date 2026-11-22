# Modo administrador (/adm)

## Como entrar

1. Abra o **site** da Gruta com `/adm` no fim do endereço:
   `https://seu-site/adm` (ou `https://seu-site/#/adm`, que funciona em
   qualquer hospedagem). Rodando local: `flutter run -d chrome` e troque o
   endereço para `http://localhost:XXXX/#/adm`.
2. Entre com seu usuário e senha da Gruta.
3. Se sua conta for admin, aparece um **ícone de ferramentas** verde no canto
   superior direito, ao lado do botão dos serviços. O resto do app é igual.

Para a rota `/adm` (sem `#`) funcionar no site publicado, a hospedagem precisa
mandar qualquer caminho para o `index.html` (no Netlify, Vercel e Firebase
Hosting é a opção "single-page app" / rewrite para `/index.html`).

## Como virar admin

No painel do Supabase > SQL Editor:

```sql
update gruta.perfis set papel = 'admin' where login = 'seu_usuario';
```

Só o banco muda o papel; ninguém vira admin pelo app.

## O que dá para fazer

**Avisos**: título, descrição e ícone. "Enviar para todos" grava em
`gruta.notificacoes`. Cada pessoa vê no sino da tela Hoje e, no celular,
recebe uma notificação na próxima vez que abrir o app.

**Aulas**: escolha a Jornada ou uma trilha, toque numa aula e edite título,
descrição, pergunta do Grimório, duração, vídeo e capa. "Enviar vídeo do
computador" sobe o arquivo para o Storage (bucket `gruta`, pasta
`aulas/<id>`) e preenche o endereço sozinho. Também dá para colar um
endereço externo (Bunny, YouTube não serve: precisa ser MP4 ou HLS).
"Nova aula" cria a próxima da lista.

Limite: 50 MB por arquivo (plano gratuito do Supabase). Exporte os vídeos em
720p, H.264.

## Push com o app fechado (ainda não ligado)

Para o aviso chegar com o celular bloqueado e o app fechado é preciso o
Firebase Cloud Messaging:

1. Criar o projeto no Firebase e registrar os apps Android
   (`com.tocadoscoelhos.gruta`) e iOS.
2. Baixar `google-services.json` (Android) e `GoogleService-Info.plist` (iOS).
3. No iOS, gerar a chave APNs na conta de desenvolvedor da Apple e subir no Firebase.
4. Adicionar `firebase_messaging` ao app, inscrever cada aparelho no tópico
   `gruta-todos`.
5. Completar a função `supabase/functions/gruta-push` com a conta de serviço
   do Firebase (segredo `FCM_SERVICE_ACCOUNT`).

O painel já chama `gruta-push` depois de gravar o aviso; enquanto ela não
existir, o aviso fica só no sino.
