/// Configuração da leitura de NFC-e por QR Code.
///
/// Padrão: o próprio celular consulta a página pública da SEFAZ-SP
/// (a SEFAZ bloqueia servidores fora do Brasil, então não usa Edge Function).
/// Para usar uma API própria no lugar:
///   flutter run --dart-define=NFCE_PARSE_URL=https://.../parse-nfce
class NfceConfig {
  NfceConfig._();

  static const String parseUrl = String.fromEnvironment(
    'NFCE_PARSE_URL',
    defaultValue: '',
  );

  static bool get usarApi => parseUrl.trim().isNotEmpty;
}
