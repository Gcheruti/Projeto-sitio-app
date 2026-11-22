# Publicar nas lojas (checklist)

## Antes de tudo
- [ ] Ícone do app (1024×1024, sem transparência para iOS). Pode usar o pacote
      `flutter_launcher_icons` para gerar todos os tamanhos.
- [ ] Política de privacidade publicada num endereço (as duas lojas pedem o link).
- [ ] Supabase de produção com as migrations e os vídeos reais.
- [ ] Versão em `pubspec.yaml` (`version: 1.0.0+1`: o número depois do `+`
      precisa subir a cada envio).

## Google Play (Android)
1. Conta de desenvolvedor Google Play (taxa única de US$ 25).
2. Criar a chave de upload (uma vez só; **guardar com cuidado**, sem ela não
   dá para atualizar o app):
   ```bash
   keytool -genkey -v -keystore ~/gruta-upload.jks -keyalg RSA -keysize 2048 \
           -validity 10000 -alias upload
   ```
3. Criar `android/key.properties` (não vai para o git) e ligar no
   `build.gradle.kts` (passo a passo: https://docs.flutter.dev/deployment/android).
4. `flutter build appbundle --release` (a configuração do Supabase já está no app)
5. Enviar o `.aab` no Play Console, preencher "Segurança dos dados" (mesmas
   respostas do manifesto de privacidade do iOS) e classificação de conteúdo.
6. Contas novas de pessoa física precisam de **teste fechado com 12+ testadores
   por 14 dias** antes de publicar.

## App Store (iPhone)
1. Conta Apple Developer (US$ 99/ano). Para empresa (CNPJ), precisa do número D-U-N-S.
2. **Precisa de um Mac com Xcode** (ou serviço de build na nuvem, como Codemagic).
3. No Xcode: abrir `ios/Runner.xcworkspace` > Runner > Signing & Capabilities
   > escolher o Team. Bundle ID já é `com.tocadoscoelhos.gruta`.
4. `flutter build ipa --release`
5. Enviar pelo app Transporter ou Xcode > Organizer; testar no TestFlight.
6. App Store Connect: "App Privacy" (ver [PERMISSOES.md](PERMISSOES.md)),
   capturas de tela, conta de teste para o revisor (e-mail e senha).

## Revisão: o que costuma reprovar
- Falta de "excluir conta" no app (já tem).
- Botões ou telas "em breve" demais: no envio, esconder os planos pagos se a compra
  ainda não estiver pronta.
- Conteúdo de saúde (chás, plantas) sem aviso: as trilhas já têm o texto
  "não substitui orientação médica"; manter isso nas aulas também.
