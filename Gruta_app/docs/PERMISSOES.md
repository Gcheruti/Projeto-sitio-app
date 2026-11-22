# Permissões e configuração de iOS e Android

## Resumo

A Gruta pede pouca coisa: **internet** (vídeos e banco) e **notificação**
(lembrete diário). Não usa câmera, fotos, localização, microfone, contatos
nem rastreamento. Quanto menos permissões, mais fácil passar na revisão das lojas.

| O quê | Android | iOS | Por quê |
|---|---|---|---|
| Internet | `INTERNET` no manifest | não precisa pedir | vídeos e Supabase |
| Notificação | `POST_NOTIFICATIONS` (Android 13+ pergunta) | pergunta na hora (sistema) | lembrete diário |
| Lembrete após reiniciar | `RECEIVE_BOOT_COMPLETED` | não precisa | reagendar os avisos |
| Link do e-mail | intent-filter `gruta://entrar` | `CFBundleURLTypes` `gruta` | abrir o app pela confirmação/nova senha |

## Como funciona no iOS (para quem só conhece Android)

- **No iOS não existe lista de permissões instaladas.** O app pede cada uma na
  hora de usar, com uma janela do sistema. A pessoa responde **uma vez só**: se
  negar, o app não pode perguntar de novo; só pelos Ajustes do iPhone.
  Por isso a Gruta pede a notificação no **fim da apresentação**, logo depois
  de a pessoa escolher o horário do lembrete (quando o pedido faz sentido), e
  não ao abrir o app.
- **Permissões sensíveis precisam de um texto explicando o motivo** no
  `Info.plist` (chaves `NS...UsageDescription`, por exemplo câmera ou fotos).
  Se o app usar a câmera sem esse texto, ele **fecha na hora** e a Apple
  recusa. Hoje a Gruta não usa nenhuma dessas, então não há texto. Se um dia
  houver foto de perfil, adicionar:
  `NSPhotoLibraryUsageDescription` = "Para escolher sua foto de perfil."
- **Notificação não precisa de chave no Info.plist**; só da pergunta na hora.
- **Vídeo não precisa de permissão.** Toca com som mesmo com o iPhone no
  silencioso (o player usa a categoria de áudio "playback").

## O que foi configurado no iOS (`ios/Runner/`)

| Arquivo | O que mudou |
|---|---|
| `Info.plist` | Nome "Gruta"; esquema de link `gruta://`; `ITSAppUsesNonExemptEncryption = false` (o app só usa HTTPS comum; evita a pergunta de criptografia a cada envio); só retrato no iPhone. |
| `PrivacyInfo.xcprivacy` | **Manifesto de privacidade** (obrigatório desde 2024). Declara: e-mail, nome, ID do usuário, aulas assistidas e anotações, todos só para o funcionamento do app, sem rastreamento. Também declara o uso de `UserDefaults` (preferências salvas). Já está incluído no projeto do Xcode. |
| `AppDelegate.swift` | Liga as notificações locais (mostrar o aviso mesmo com o app aberto e permitir o toque no aviso). |
| `Runner.xcodeproj` | Bundle ID `com.tocadoscoelhos.gruta`; iOS mínimo 15. |

Ao publicar, as respostas de **"App Privacy"** no App Store Connect precisam
bater com o `PrivacyInfo.xcprivacy`: Contact Info (e-mail, nome), Identifiers
(User ID), Usage Data (Product Interaction), User Content (Other), todos
"App Functionality", ligados à identidade, **sem** tracking.

## O que foi configurado no Android (`android/app/`)

| Arquivo | O que mudou |
|---|---|
| `build.gradle.kts` | Pacote `com.tocadoscoelhos.gruta`; `minSdk 24` (Android 7); `targetSdk 36`; desugaring (exigido pelo pacote de notificações). |
| `src/main/AndroidManifest.xml` | Nome "Gruta"; as 3 permissões acima; link `gruta://entrar`; receptores que reagendam os lembretes. |
| `res/.../launch_background.xml`, `styles.xml` | Tela de abertura escura (sem o flash branco). |

**Atenção ao `INTERNET`:** o Flutter coloca essa permissão só no modo debug.
Sem ela no manifest principal, o APK release instalado não acessa nada. Já está lá.

**Alarme exato:** não usamos `SCHEDULE_EXACT_ALARM`. O lembrete pode chegar
alguns minutos depois do horário, mas a Play Store exige justificativa para
alarme exato e um app de cursos não se encaixa.

## Supabase: login sem e-mail

A Gruta entra por usuário e senha; a conta é criada já confirmada pela
função `gruta-cadastro`, então nenhum e-mail é enviado e não é preciso mexer
nas URLs de retorno do projeto (que é compartilhado com a Cosmória). O link
`gruta://entrar` continua configurado para quando entrar o login com Google.

## Coisas que a Apple exige e já estão no app

- **Excluir a conta dentro do app** (Perfil > Excluir minha conta). Obrigatório
  para qualquer app com cadastro (a Play Store também exige).
- **Login com Apple** passa a ser obrigatório no iPhone quando entrar o login
  com Google. Hoje é só usuário e senha, então ainda não precisa.
- **Compras digitais** (planos e trilhas) no iPhone precisam usar a compra da Apple. Ver
  [NEGOCIO.md](NEGOCIO.md).

## Novidades da fase 2

- **iOS `NSPhotoLibraryUsageDescription`**: o seletor de arquivos do painel de
  administração pode abrir a galeria; a Apple exige o texto explicando.
- **Android `<queries>` com `https`**: necessário (Android 11+) para o botão
  "Conheça nossos outros serviços" abrir os sites no navegador.
