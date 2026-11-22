# Como rodar a Gruta com `flutter run`

## O que o `flutter run` faz

`flutter run` compila o app e abre em **um** dispositivo por vez: um celular
ligado no USB, um emulador, o Chrome ou o próprio Linux. Enquanto ele roda, o
terminal fica "ligado" ao app e você vê as mudanças do código na hora.

Não existe uma visualização "de todos ao mesmo tempo" num comando só. Para ver
em dois lugares, abra dois terminais e rode um `flutter run -d ...` em cada.
Como a Gruta usa o **mesmo layout** em tudo, o Chrome já mostra fielmente
como vai ficar no celular.

## Primeira vez

```bash
cd ~/Sitio/Claude/Gruta_app
flutter pub get        # baixa os pacotes
flutter doctor         # mostra o que falta (Android SDK, Chrome, etc.)
```

## Escolher onde abrir (`-d`)

```bash
flutter devices                 # lista o que está disponível agora
flutter run                     # se houver mais de um, ele pergunta qual
flutter run -d chrome           # navegador Chrome
flutter run -d linux            # janela no próprio Linux (se habilitado)
flutter run -d <id>             # um aparelho específico (id do "flutter devices")
```

Exemplos de saída do `flutter devices`:

```
Pixel 7 (mobile)  • 2B211FDH2003XY • android-arm64  • Android 15
Chrome (web)      • chrome         • web-javascript • Google Chrome 131
```

Para usar o Pixel: `flutter run -d 2B211FDH2003XY` (ou só as primeiras
letras do id, ou o nome: `-d pixel`).

### Celular Android pelo cabo
1. No celular: Configurações > Sobre o telefone > toque 7x em "Número da versão".
2. Opções do desenvolvedor > ligue "Depuração USB".
3. Ligue o cabo, aceite a pergunta no celular e rode `flutter devices`.

### Emulador Android
```bash
flutter emulators                       # lista os emuladores criados
flutter emulators --launch <nome>       # abre um
flutter run                             # roda nele
```
(Emuladores são criados no Android Studio > Device Manager.)

### iPhone
Para rodar no iPhone ou no simulador de iPhone **é obrigatório um Mac com Xcode**
(regra da Apple). No Linux o `flutter devices` nunca mostra iPhone. Opções:
usar um Mac emprestado, um Mac na nuvem (MacinCloud) ou um serviço de build
(Codemagic, GitHub Actions com macOS). O projeto iOS já está configurado; veja
[PERMISSOES.md](PERMISSOES.md) e [PUBLICAR.md](PUBLICAR.md).

## Teclas enquanto o app roda

| Tecla | O que faz |
|---|---|
| `r` | **Hot reload**: aplica a mudança do código em ~1 s, mantendo a tela onde está |
| `R` | **Hot restart**: reinicia o app do zero (use quando mudar algo no `main`) |
| `q` | sai |
| `d` | desliga do app, mas deixa ele aberto |
| `h` | lista todas as teclas |

## Ver como celular no Chrome

No Chrome aberto pelo `flutter run -d chrome`, aperte **F12** e depois
**Ctrl+Shift+M**: aparece o modo dispositivo, onde dá para escolher
"iPhone 14", "Pixel 7" etc. Na janela larga normal, a Gruta mostra a coluna
central de celular com a gruta escura dos lados (de propósito).

## Banco real e modo demonstração

O app já vem ligado ao Supabase da Gruta (schema `gruta`): é só `flutter run`.
A URL e a chave publicável ficam em `lib/config/app_config.dart`. Elas são
públicas por natureza (vão dentro de qualquer app); quem protege os dados são
as regras RLS do banco. A chave `service_role` nunca entra no app.

Para apontar para outro projeto Supabase (ex.: um de testes):
```bash
flutter run -d chrome --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
                      --dart-define=SUPABASE_ANON_KEY=sb_publishable_...
```

O modo demonstração (sem banco, tudo salvo no aparelho) só liga se pedir:
```bash
flutter run -d chrome --dart-define=GRUTA_DEMO=true
```

Dicas do modo demonstração:
- Perfil > "Simular 12 dias da Jornada" preenche a ofensiva e já dá uma moeda.
- O modo `/adm` também funciona na demonstração: `http://localhost:XXXX/#/adm`
  (qualquer conta é admin; envio de arquivo só com o banco ligado).
- Na aula há "Pular vídeo (só na demonstração)" para testar a comemoração.
- Para recomeçar do zero no Chrome: F12 > Application > Storage > "Clear site data".

## Modos de compilação

```bash
flutter run                 # debug (padrão): hot reload, mais lento
flutter run --profile       # medir desempenho
flutter run --release       # como o app final (sem hot reload)
flutter build apk           # gera APK em build/app/outputs/flutter-apk/
flutter build appbundle     # gera .aab para a Play Store
flutter build web           # gera o site em build/web/
```

Depois de trocar o nome do pacote ou mexer no Android/iOS, se algo estranho
acontecer: `flutter clean && flutter pub get`.
