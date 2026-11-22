import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paleta da Gruta: uma biblioteca escavada no arenito, iluminada por
/// lamparinas. Fundo escuro e quente, pedra, papel velho e a luz âmbar da
/// chama. O dourado (ouro) é o mesmo dos sites do Sítio e da Cosmória.
/// Uma paleta completa. Há duas: escura (a gruta à luz de lamparina) e
/// clara (pergaminho de dia). Os nomes são os mesmos nas duas.
class Paleta {
  const Paleta({
    required this.escura,
    required this.noite,
    required this.rocha,
    required this.rochaClara,
    required this.linha,
    required this.arenito,
    required this.chama,
    required this.brasa,
    required this.ouro,
    required this.pergaminho,
    required this.textoSuave,
    required this.textoApagado,
    required this.musgo,
    required this.erro,
    required this.fundoTopo,
    required this.fundoMeio,
    required this.lados,
    required this.sombra,
  });

  final bool escura;
  final Color noite, rocha, rochaClara, linha, arenito, chama, brasa, ouro;
  final Color pergaminho, textoSuave, textoApagado, musgo, erro;
  final Color fundoTopo, fundoMeio, lados, sombra;

  static const gruta = Paleta(
    escura: true,
    noite: Color(0xFF120E0B), // fundo da gruta
    rocha: Color(0xFF1E1814), // cartões
    rochaClara: Color(0xFF2A221C), // cartões em destaque
    linha: Color(0xFF3A2F26), // bordas e divisórias
    arenito: Color(0xFFC8A57A), // paredes de arenito
    chama: Color(0xFFF0A63A), // luz da lamparina (acento)
    brasa: Color(0xFFD9772B),
    ouro: Color(0xFFC9A45C), // dourado da marca
    pergaminho: Color(0xFFF3EBDC), // texto principal
    textoSuave: Color(0xFFB9AC98),
    textoApagado: Color(0xFF7D7062),
    musgo: Color(0xFF7FA878),
    erro: Color(0xFFE07A5F),
    fundoTopo: Color(0xFF3A2A1C),
    fundoMeio: Color(0xFF1A140F),
    lados: Color(0xFF0B0907),
    sombra: Color(0x80000000),
  );

  static const dia = Paleta(
    escura: false,
    noite: Color(0xFFF6F1E7), // fundo creme (o mesmo da Cosmória)
    rocha: Color(0xFFFFFDF8),
    rochaClara: Color(0xFFF1E9D9),
    linha: Color(0xFFDCCFB4),
    arenito: Color(0xFF8A6A3F),
    chama: Color(0xFFB8650F), // âmbar mais fechado para ler no claro
    brasa: Color(0xFFA14A00),
    ouro: Color(0xFF8A6624),
    pergaminho: Color(0xFF2A2119), // texto principal
    textoSuave: Color(0xFF5E5246),
    textoApagado: Color(0xFF8E8172),
    musgo: Color(0xFF4F7A48),
    erro: Color(0xFFB3401F),
    fundoTopo: Color(0xFFF3E2C4),
    fundoMeio: Color(0xFFF6EEDF),
    lados: Color(0xFFE9E0CE),
    sombra: Color(0x26473520),
  );
}

/// Cores do app. Sempre leia daqui (GrutaCores.chama etc.): o valor muda
/// conforme o tema escolhido (escuro, claro ou o do aparelho).
class GrutaCores {
  GrutaCores._();

  static Paleta p = Paleta.gruta;

  static Color get noite => p.noite;
  static Color get rocha => p.rocha;
  static Color get rochaClara => p.rochaClara;
  static Color get linha => p.linha;
  static Color get arenito => p.arenito;
  static Color get chama => p.chama;
  static Color get brasa => p.brasa;
  static Color get ouro => p.ouro;
  static Color get pergaminho => p.pergaminho;
  static Color get textoSuave => p.textoSuave;
  static Color get textoApagado => p.textoApagado;
  static Color get musgo => p.musgo;
  static Color get erro => p.erro;
  static Color get fundoTopo => p.fundoTopo;
  static Color get fundoMeio => p.fundoMeio;
  static Color get lados => p.lados;
  static Color get sombra => p.sombra;
  static bool get claro => identical(p, Paleta.dia);

  /// Texto/ícone em cima de um botão cor de chama.
  static Color get sobreChama =>
      p.escura ? Paleta.gruta.noite : const Color(0xFFFFFBF2);
}

/// Medidas usadas no app inteiro. A largura máxima faz o app ter o mesmo
/// desenho no celular, no tablet e no navegador (fica uma coluna central).
class GrutaMedidas {
  GrutaMedidas._();
  static const larguraMaxima = 480.0;
  static const raio = 20.0;
  static const margem = 20.0;
}

class GrutaTema {
  GrutaTema._();

  static TextStyle titulo(double tamanho,
          {Color? cor, FontWeight peso = FontWeight.w600}) =>
      GoogleFonts.cormorantGaramond(
          fontSize: tamanho,
          fontWeight: peso,
          color: cor ?? GrutaCores.pergaminho,
          height: 1.05,
          // números "de régua" (o padrão da fonte deixa o 0 parecendo um o)
          fontFeatures: const [FontFeature.liningFigures()]);

  /// Monta o ThemeData com a paleta atual (GrutaCores.p).
  static ThemeData construir() {
    final escura = GrutaCores.p.escura;
    final base = ThemeData(
      useMaterial3: true,
      brightness: escura ? Brightness.dark : Brightness.light,
      colorScheme: ColorScheme.light(
        primary: GrutaCores.chama,
        onPrimary: GrutaCores.sobreChama,
        secondary: GrutaCores.ouro,
        onSecondary: GrutaCores.noite,
        tertiary: GrutaCores.musgo,
        surface: GrutaCores.rocha,
        onSurface: GrutaCores.pergaminho,
        surfaceContainerHighest: GrutaCores.rochaClara,
        outline: GrutaCores.linha,
        outlineVariant: GrutaCores.linha,
        error: GrutaCores.erro,
      ).copyWith(brightness: escura ? Brightness.dark : Brightness.light),
      scaffoldBackgroundColor: GrutaCores.noite,
    );

    final texto = GoogleFonts.manropeTextTheme(base.textTheme).apply(
      bodyColor: GrutaCores.pergaminho,
      displayColor: GrutaCores.pergaminho,
    );

    return base.copyWith(
      textTheme: texto.copyWith(
        displaySmall: titulo(40),
        headlineMedium: titulo(32),
        headlineSmall: titulo(26),
        titleLarge: titulo(24),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: GrutaCores.pergaminho,
        titleTextStyle: titulo(24),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: GrutaCores.chama,
          foregroundColor: GrutaCores.sobreChama,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.manrope(
              fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: .3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: GrutaCores.pergaminho,
          minimumSize: const Size.fromHeight(54),
          side: BorderSide(color: GrutaCores.linha, width: 1.5),
          shape: const StadiumBorder(),
          textStyle:
              GoogleFonts.manrope(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: GrutaCores.chama),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: GrutaCores.rocha,
        hintStyle: TextStyle(color: GrutaCores.textoApagado),
        labelStyle: TextStyle(color: GrutaCores.textoSuave),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: GrutaCores.linha),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: GrutaCores.linha),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: GrutaCores.chama, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GrutaCores.rocha,
        indicatorColor: GrutaCores.chama.withValues(alpha: .18),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) =>
            GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: s.contains(WidgetState.selected)
                    ? GrutaCores.chama
                    : GrutaCores.textoSuave)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? GrutaCores.chama
                : GrutaCores.textoSuave)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: GrutaCores.rochaClara,
        contentTextStyle: TextStyle(color: GrutaCores.pergaminho),
      ),
      dividerTheme: DividerThemeData(color: GrutaCores.linha),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? GrutaCores.noite
                : GrutaCores.textoSuave),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? GrutaCores.chama
                : GrutaCores.rochaClara),
      ),
    );
  }
}
