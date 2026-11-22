import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/gruta_tema.dart';

/// Tema escolhido em Perfil > engrenagem: escuro, claro ou o do aparelho.
/// Fica salvo só neste aparelho.
class TemaState extends ChangeNotifier {
  static const _chave = 'gruta_tema';

  ThemeMode modo = ThemeMode.dark; // a Gruta nasce escura

  Future<void> restaurar() async {
    final s = (await SharedPreferences.getInstance()).getString(_chave);
    modo = switch (s) {
      'claro' => ThemeMode.light,
      'sistema' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> escolher(ThemeMode m) async {
    modo = m;
    notifyListeners();
    (await SharedPreferences.getInstance()).setString(
        _chave,
        switch (m) {
          ThemeMode.light => 'claro',
          ThemeMode.system => 'sistema',
          ThemeMode.dark => 'escuro',
        });
  }

  /// Aplica a paleta certa conforme o modo e o brilho do aparelho.
  /// Retorna true se mudou.
  bool aplicar(Brightness doAparelho) {
    final escura = switch (modo) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => doAparelho == Brightness.dark,
    };
    final nova = escura ? Paleta.gruta : Paleta.dia;
    if (identical(GrutaCores.p, nova)) return false;
    GrutaCores.p = nova;
    return true;
  }
}

final temaState = TemaState();
