import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nfc_manager/nfc_manager.dart';

enum EstadoNfc { semSuporte, desligado, ligado }

/// Descobre o que o aparelho realmente tem (NFC, câmera) em vez de supor.
/// No Android a resposta vem do sistema (MainActivity.kt). Em outras
/// plataformas o NFC não existe e a câmera só é descoberta ao tentar usar.
class DispositivoService {
  DispositivoService._();

  static const _canal = MethodChannel('sitio/dispositivo');

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// semSuporte = o aparelho não tem NFC (ou não é Android);
  /// desligado = tem, mas está desligado nas configurações; ligado = pronto.
  static Future<EstadoNfc> estadoNfc() async {
    if (!_android) return EstadoNfc.semSuporte;
    try {
      switch (await _canal.invokeMethod<String>('estadoNfc')) {
        case 'ligado':
          return EstadoNfc.ligado;
        case 'desligado':
          return EstadoNfc.desligado;
        default:
          return EstadoNfc.semSuporte;
      }
    } catch (_) {
      // Versão do app sem o código nativo: usa só o que o plugin sabe.
      try {
        return await NfcManager.instance.isAvailable()
            ? EstadoNfc.ligado
            : EstadoNfc.desligado;
      } catch (_) {
        return EstadoNfc.desligado;
      }
    }
  }

  /// true/false no Android (o sistema responde). null = não dá para saber
  /// antes de tentar abrir a câmera (computador/navegador).
  static Future<bool?> temCamera() async {
    if (!_android) return null;
    try {
      return await _canal.invokeMethod<bool>('temCamera');
    } catch (_) {
      return null;
    }
  }

  /// Mostra um aviso na bandeja do Android (usado com o app aberto, quando
  /// o FCM não mostra nada sozinho).
  static Future<void> mostrarNotificacao(String titulo, String corpo) async {
    if (!_android) return;
    try {
      await _canal.invokeMethod('mostrarNotificacao',
          {'titulo': titulo, 'corpo': corpo});
    } catch (_) {}
  }

  /// Abre a tela de configurações de NFC do Android.
  static Future<bool> abrirConfigNfc() async {
    if (!_android) return false;
    try {
      return (await _canal.invokeMethod<bool>('abrirConfigNfc')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static String mensagemNfc(EstadoNfc e) {
    switch (e) {
      case EstadoNfc.ligado:
        return 'NFC ligado e pronto.';
      case EstadoNfc.desligado:
        return 'O NFC está desligado neste aparelho. Ligue nas configurações.';
      case EstadoNfc.semSuporte:
        return kIsWeb || defaultTargetPlatform != TargetPlatform.android
            ? 'NFC só funciona no app Android.'
            : 'Este aparelho não tem NFC.';
    }
  }
}
