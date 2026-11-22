import 'package:flutter/foundation.dart';

/// Configuração do app.
///
/// O app já vem ligado ao Supabase da Gruta (schema `gruta`): basta
/// `flutter run`. A URL e a chave abaixo são PÚBLICAS (publishable/anon),
/// feitas para ir dentro do app; quem protege os dados são as regras de
/// segurança (RLS) do banco. A chave service_role nunca entra aqui.
///
/// Para apontar para outro projeto, ainda dá para sobrescrever:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Modo demonstração (sem banco, tudo salvo no aparelho) só liga se pedir:
///   flutter run --dart-define=GRUTA_DEMO=true
class AppConfig {
  AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL',
      defaultValue: 'https://cucabiqhtwqlxujgflnq.supabase.co');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_qn6l-R9jyqMa1yTNZfQGLQ_iSQailRZ');

  /// Versão gravada no registro de acessos (manter igual ao pubspec.yaml).
  static const versaoApp = '1.0.1';

  /// true só com --dart-define=GRUTA_DEMO=true.
  static const modoDemonstracao = bool.fromEnvironment('GRUTA_DEMO');

  static bool get temSupabase =>
      !modoDemonstracao &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;

  /// Endereço para onde o e-mail de confirmação/recuperação de senha volta.
  /// O mesmo esquema está no Info.plist (iOS) e no AndroidManifest.xml.
  static const deepLink = 'gruta://entrar';

  /// Regra do "um vídeo novo por dia": depois de concluir uma aula, a próxima
  /// da mesma trilha só abre no dia seguinte. false = libera na hora.
  static const umaAulaNovaPorDia = true;

  /// Meta diária padrão, em minutos.
  static const metaDiariaPadrao = 5;

  /// Quantos dias de ofensiva valem um amuleto (protege um dia perdido).
  static const diasPorAmuleto = 7;
  static const maximoAmuletos = 2;

  /// Fração do vídeo que precisa ser assistida para a aula contar.
  static const fracaoParaConcluir = 0.9;

  /// Modo administrador: só no site, abrindo o endereço com /adm no fim
  /// (ex.: https://gruta.app/adm ou https://gruta.app/#/adm). A tela é a
  /// mesma do app, com um ícone de ferramentas a mais para quem tem
  /// papel 'admin' no banco.
  static final bool modoAdm = kIsWeb && _temAdm(Uri.base);

  static bool _temAdm(Uri u) {
    final caminho = u.path.replaceAll(RegExp(r'/+$'), '');
    return caminho.endsWith('/adm') ||
        u.fragment.replaceAll(RegExp(r'/+$'), '').endsWith('/adm') ||
        u.queryParameters.containsKey('adm');
  }
}
