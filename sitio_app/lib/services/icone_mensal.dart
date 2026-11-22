import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../theme/temas_mensais.dart';

/// Mantém o ícone do app igual ao tema escolhido (Android).
///
/// - Automático: ícone do mês atual.
/// - Mês fixo (ex.: fevereiro com o relógio em outubro): ícone desse mês.
/// - Base: ícone do tema Base.
///
/// Aliases `base`, `m01`..`m12` no AndroidManifest; imagens
/// `ic_launcher_<nome>.png` nos mipmaps. A troca é adiada para quando o app
/// for para segundo plano, para não fechar o app na cara de quem está usando.
class IconeMensal with WidgetsBindingObserver {
  IconeMensal._();
  static final IconeMensal _instancia = IconeMensal._();
  static bool _iniciado = false;

  /// Nome do ícone para o estado atual do tema.
  static String nomeAtual() {
    if (temaState.base) return 'base';
    return 'm${temaState.atual.mes.toString().padLeft(2, '0')}';
  }

  /// Chame uma vez, depois de `temaState.restaurar()`.
  static Future<void> iniciar() async {
    // Em debug o `flutter run` só enxerga a MainActivity, não os aliases.
    if (kDebugMode || defaultTargetPlatform != TargetPlatform.android) return;
    if (_iniciado) return;
    _iniciado = true;
    WidgetsBinding.instance.addObserver(_instancia);
    temaState.addListener(sincronizar); // trocou o tema -> troca o ícone
    await sincronizar();
  }

  static Future<void> sincronizar() async {
    try {
      final alvo = nomeAtual();
      final atual = await DynamicAppIconFlutterPlus.getAlternateIconName();
      if (atual == alvo) return;
      await DynamicAppIconFlutterPlus.setAlternateIconName(alvo,
          deferUntilBackground: true);
    } catch (_) {
      // Ícone é detalhe visual: nunca deve travar o app.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      DynamicAppIconFlutterPlus.applyPendingIcon().catchError((_) {});
    }
  }
}
