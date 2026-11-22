import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/borda_papel.dart';
import '../widgets/natureza_overlay.dart' show BordaRunica;

/// Identidade visual de um mês (as "Luas"): tons de pergaminho, pedra e
/// madeira. fundo = pergaminho, superficie = cards, acento = tom fechado
/// (legível sobre o fundo), detalhe = pastel (bordas e destaques).
class TemaMensal {
  const TemaMensal(this.mes, this.nome, this.frase, this.fundo,
      this.superficie, this.acento, this.detalhe);

  final int mes; // 1..12
  final String nome;
  final String frase;
  final Color fundo;
  final Color superficie;
  final Color acento;
  final Color detalhe;

  String get nomeMes => const [
        '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
        'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
      ][mes];
}

const List<TemaMensal> kTemasMensais = [
  TemaMensal(1, 'Lua do Lobo', 'O uivo atravessa o sítio.',
      Color(0xFFECEEEC), Color(0xFFDADFDD), Color(0xFF4A5E6B), Color(0xFFA9B8C0)),
  TemaMensal(2, 'Lua da Tempestade', 'Algo se move entre as nuvens.',
      Color(0xFFEDEBF0), Color(0xFFDCD8E4), Color(0xFF5A4F7E), Color(0xFFB5ACD0)),
  TemaMensal(3, 'Lua do Corvo', 'Os corvos trazem recados.',
      Color(0xFFE9EDEA), Color(0xFFD6DDD8), Color(0xFF3E5F57), Color(0xFF9DB8AE)),
  TemaMensal(4, 'Lua Rosa', 'A terra desperta em rosa.',
      Color(0xFFF5EAE6), Color(0xFFEBD6D1), Color(0xFF94485F), Color(0xFFDDA9B8)),
  TemaMensal(5, 'Lua das Flores', 'Jardim aberto, ervas no ponto.',
      Color(0xFFEFF1E4), Color(0xFFDDE3C9), Color(0xFF546B3A), Color(0xFFB2C48F)),
  TemaMensal(6, 'Lua do Morango', 'Doce e vermelha, a noite chega cedo.',
      Color(0xFFF6E9E4), Color(0xFFEDD3CB), Color(0xFF9C3B3F), Color(0xFFE2A399)),
  TemaMensal(7, 'Lua do Trovão', 'Raios sobre o salão.',
      Color(0xFFF5EFDC), Color(0xFFEADFBE), Color(0xFF7A5C10), Color(0xFFE3C772)),
  TemaMensal(8, 'Lua do Esturjão', 'Águas fundas, segredos antigos.',
      Color(0xFFE6EEEE), Color(0xFFD1E0E0), Color(0xFF2F6670), Color(0xFF9CC4C6)),
  TemaMensal(9, 'Lua da Colheita', 'Fartura na mesa, equilíbrio na balança.',
      Color(0xFFF3EBD9), Color(0xFFE6D6B4), Color(0xFF855313), Color(0xFFD9AE63)),
  TemaMensal(10, 'Lua do Caçador', 'Fogueiras acesas, o véu afina.',
      Color(0xFFF3E7DB), Color(0xFFE7D0B9), Color(0xFF8F4318), Color(0xFFD8A07A)),
  TemaMensal(11, 'Lua do Castor', 'Hora de honrar quem já partiu.',
      Color(0xFFEFE6D8), Color(0xFFDFCFB8), Color(0xFF5C3D29), Color(0xFFB08E70)),
  TemaMensal(12, 'Lua Fria', 'Noite longa, velas acesas.',
      Color(0xFFECEFF2), Color(0xFFDCE2E8), Color(0xFF3E5575), Color(0xFFA8B8CC)),
];

/// As quatro estações (hemisfério sul). Índice 0..3 = primavera, verão,
/// outono, inverno. O campo `mes` aqui é só um número de série (não é mês).
const List<TemaMensal> kTemasEstacoes = [
  TemaMensal(1, 'Primavera', 'O jardim floresce.',
      Color(0xFFFBF0F2), Color(0xFFF4DDE4), Color(0xFF3F7D4B), Color(0xFFF2B3C6)),
  TemaMensal(2, 'Verão', 'Sol alto, noites quentes.',
      Color(0xFFFFF6DA), Color(0xFFFBE7A8), Color(0xFFA14A00), Color(0xFFFFC247)),
  TemaMensal(3, 'Outono', 'As folhas pedem passagem.',
      Color(0xFFF6E8D8), Color(0xFFEBCFAE), Color(0xFF8A2D14), Color(0xFFD9822B)),
  TemaMensal(4, 'Inverno', 'Silêncio branco sobre o sítio.',
      Color(0xFFEEF3F8), Color(0xFFDCE7F2), Color(0xFF2C5C8A), Color(0xFFA9CBE6)),
];

/// Estação do dia no hemisfério sul: 0 primavera, 1 verão, 2 outono, 3 inverno.
int estacaoDoDia(DateTime d) {
  final md = d.month * 100 + d.day;
  if (md >= 1221 || md < 320) return 1;
  if (md < 621) return 2;
  if (md < 922) return 3;
  return 0;
}

/// Texturas de fundo. Os arquivos são cinza claro já normalizados e são
/// multiplicados pela cor de fundo do tema (mês ou Base), então cada textura
/// assume a coloração escolhida.
class TexturaTema {
  const TexturaTema(this.id, this.nome, this.asset);
  final String id;
  final String nome;
  final String asset;
}

const List<TexturaTema> kTexturas = [
  TexturaTema('pedra', 'Muro de pedra', 'assets/images/textura_pedra.jpg'),
  TexturaTema('pergaminho', 'Pergaminho', 'assets/images/textura_pergaminho.jpg'),
  TexturaTema('ardosia', 'Ardósia', 'assets/images/textura_ardosia.jpg'),
  TexturaTema('fumaca', 'Fumaça', 'assets/images/textura_fumaca.jpg'),
  TexturaTema('papel', 'Papel artesanal', 'assets/images/textura_papel.jpg'),
  TexturaTema('concreto', 'Concreto', 'assets/images/textura_concreto.jpg'),
  TexturaTema('linho', 'Linho', 'assets/images/textura_linho.jpg'),
];

/// Fundos das estações (mesmo padrão: cinza claro tingido pela cor do tema).
/// Índice 0..3 = primavera, verão, outono, inverno.
const List<TexturaTema> kTexturasEstacoes = [
  TexturaTema('primavera', 'Primavera (pétalas)', 'assets/images/textura_primavera.jpg'),
  TexturaTema('verao', 'Verão (luz entre folhas)', 'assets/images/textura_verao.jpg'),
  TexturaTema('outono', 'Outono (folhas caídas)', 'assets/images/textura_outono.jpg'),
  TexturaTema('inverno', 'Inverno (cristais de gelo)', 'assets/images/textura_inverno.jpg'),
];

/// Id especial: usa o fundo da estação do tema (ou do calendário).
const String kTexturaDaEstacao = 'estacao';

const _chaveTextura = 'tema_textura'; // 'nenhuma' ou id da textura

/// Preto ou branco, o que contrastar mais com [fundo].
Color _pretoOuBranco(Color fundo) =>
    fundo.computeLuminance() > 0.5 ? Colors.black : Colors.white;

const _texto = Color(0xFF3A2F27); // marrom escuro, igual todo mês
const _textoSuave = Color(0xFF6B5E50);
const _chave = 'tema_mensal'; // 'auto' ou '1'..'12'

/// Escolha do tema: automático (segue o mês) ou um mês fixo.
class TemaState extends ChangeNotifier {
  /// null = automático; 0 = Base (pergaminho claro); 1..12 = lua do mês.
  int? mesEscolhido;

  bool get base => mesEscolhido == 0;

  /// Códigos: 100 = estações automáticas; 101..104 = primavera, verão,
  /// outono, inverno fixos.
  static const int estacoesAuto = 100;

  /// 0..3 quando o tema é de estação (fixa ou automática); senão null.
  int? get estacao {
    final m = mesEscolhido;
    if (m == estacoesAuto) return estacaoDoDia(DateTime.now());
    if (m != null && m >= 101 && m <= 104) return m - 101;
    return null;
  }

  /// Liga/desliga os efeitos animados (folhas, runas, coelho) no Android.
  bool efeitos = true;

  /// Cartões de pergaminho envelhecido (Android). Desligado = cartões comuns.
  bool cartoesPapel = true;

  /// null = fundo liso (sem textura).
  String? texturaId;

  TexturaTema? get textura {
    if (texturaId == kTexturaDaEstacao) {
      return kTexturasEstacoes[estacao ?? estacaoDoDia(DateTime.now())];
    }
    for (final t in [...kTexturas, ...kTexturasEstacoes]) {
      if (t.id == texturaId) return t;
    }
    return null;
  }

  /// Cor de fundo do tema em uso (a textura é tingida com ela).
  Color get fundoAtual => base ? _papel : atual.fundo;

  bool get automatico => mesEscolhido == null;

  TemaMensal get atual {
    final e = estacao;
    if (e != null) return kTemasEstacoes[e];
    final m = mesEscolhido;
    return kTemasMensais[((m == null || m == 0) ? DateTime.now().month : m) - 1];
  }

  Future<void> restaurar() async {
    try {
      final v = (await SharedPreferences.getInstance()).getString(_chave);
      final n = int.tryParse(v ?? '');
      mesEscolhido = (v == 'base') ? 0 : ((n != null && ((n >= 1 && n <= 12) || (n >= 100 && n <= 104))) ? n : null);
      final tx = (await SharedPreferences.getInstance()).getString(_chaveTextura);
      texturaId = (tx == kTexturaDaEstacao ||
              [...kTexturas, ...kTexturasEstacoes].any((t) => t.id == tx))
          ? tx
          : null;
      efeitos = (await SharedPreferences.getInstance()).getBool('tema_efeitos') ?? true;
      cartoesPapel = (await SharedPreferences.getInstance()).getBool('tema_cartoes_papel') ?? true;
    } catch (_) {}
  }

  Future<void> escolher(int? mes) async {
    mesEscolhido = mes;
    // Tema de estação: o fundo passa a acompanhar a estação. Dá para trocar
    // depois em "Fundo".
    final virouEstacao = estacao != null && texturaId != kTexturaDaEstacao;
    if (virouEstacao) texturaId = kTexturaDaEstacao;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
          _chave, mes == null ? 'auto' : (mes == 0 ? 'base' : '$mes'));
      if (virouEstacao) await p.setString(_chaveTextura, kTexturaDaEstacao);
    } catch (_) {}
  }

  Future<void> definirEfeitos(bool ligado) async {
    efeitos = ligado;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setBool('tema_efeitos', ligado);
    } catch (_) {}
  }

  Future<void> definirCartoesPapel(bool ligado) async {
    cartoesPapel = ligado;
    notifyListeners();
    try {
      await (await SharedPreferences.getInstance())
          .setBool('tema_cartoes_papel', ligado);
    } catch (_) {}
  }

  Future<void> escolherTextura(String? id) async {
    texturaId = id;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_chaveTextura, id ?? 'nenhuma');
    } catch (_) {}
  }

  ThemeData get tema {
    var t = base ? construirTemaBase() : construirTema(atual);
    // Moldura/papel dos cartões valem em todas as plataformas; o ajuste de
    // site (cabeçalho, densidade) vem por cima só no navegador/computador.
    t = _aparenciaDeSitio(t,
        papel: cartoesPapel, base: base, estacao: estacao);
    if (ehSite) t = _aparenciaDeSite(t);
    // Com textura, o Scaffold fica transparente e o fundo é
    // desenhado por página (ver TransicaoComTextura), sem ver a tela de trás
    // durante as animações de navegação.
    final comTextura = textura != null;
    return t.copyWith(
      scaffoldBackgroundColor: comTextura ? Colors.transparent : null,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: TransicaoComTextura(),
        TargetPlatform.iOS: TransicaoComTextura(),
        TargetPlatform.linux: TransicaoComTextura(),
        TargetPlatform.macOS: TransicaoComTextura(),
        TargetPlatform.windows: TransicaoComTextura(),
      }),
    );
  }
}

/// true no navegador (Chrome) e em computador (Linux/Windows/macOS).
/// No Android nativo é false: o app do celular não muda.
bool get ehSite =>
    kIsWeb ||
    (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS);

/// Ajustes só para o app Android: cartões e janelas com moldura dupla e
/// runa, brilho dourado nas sombras e destaque dourado na barra de baixo.
ThemeData _aparenciaDeSitio(ThemeData t,
    {required bool papel, required bool base, int? estacao}) {
  const ouro = Color(0xFFC9A55A);
  final cs = t.colorScheme;
  final lado = (t.cardTheme.shape is OutlinedBorder)
      ? (t.cardTheme.shape as OutlinedBorder).side
      : BorderSide(color: cs.outline);
  return t.copyWith(
    cardTheme: papel
        ? t.cardTheme.copyWith(
            // Papel quase monocromático: base neutra de pergaminho com só um
            // toque da cor do tema; o desgaste usa um marrom-cinza que também
            // puxa um pouco para o acento. Muda sutilmente de tema para tema.
            // No tema Base o papel é um bege claro fixo (sem tom verde).
            color: base
                ? const Color(0xFFF8F4EB)
                : Color.lerp(const Color(0xFFE9E1CE), cs.secondary, 0.22),
            elevation: 5,
            shadowColor: const Color(0xFF3A2E20).withValues(alpha: 0.6),
            shape: BordaPapel(
              tinta: base
                  ? const Color(0xFF5A4630)
                  : Color.lerp(const Color(0xFF574A3A), cs.primary, 0.28)!,
              estacao: estacao,
            ),
          )
        : t.cardTheme.copyWith(
            elevation: 4,
            shadowColor: ouro.withValues(alpha: 0.55),
            shape: BordaRunica(side: lado, raio: 14),
          ),
    dialogTheme: t.dialogTheme.copyWith(
      elevation: 14,
      shadowColor: ouro.withValues(alpha: 0.6),
      shape: BordaRunica(side: lado, raio: 18),
    ),
    navigationBarTheme: t.navigationBarTheme.copyWith(
      indicatorColor: ouro.withValues(alpha: 0.45),
    ),
  );
}

/// Ajustes só para navegador/computador: aparência de site (barra lisa com
/// título à esquerda, cartões planos com borda fina, painéis inferiores
/// viram janelas centralizadas, controles mais compactos).
ThemeData _aparenciaDeSite(ThemeData t) {
  return t.copyWith(
    visualDensity: VisualDensity.compact,
    appBarTheme: t.appBarTheme.copyWith(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: t.cardTheme.copyWith(
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    bottomSheetTheme: t.bottomSheetTheme.copyWith(
      constraints: const BoxConstraints(maxWidth: 720),
      showDragHandle: false,
    ),
    dialogTheme: t.dialogTheme.copyWith(
      constraints: const BoxConstraints(maxWidth: 560),
    ),
    hoverColor: t.colorScheme.primary.withValues(alpha: 0.06),
  );
}

/// Fundo (liso ou texturizado) por trás de uma página.
class FundoTextura extends StatelessWidget {
  const FundoTextura({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: temaState,
      child: child,
      builder: (context, filho) {
        final tx = temaState.textura;
        final cor = temaState.fundoAtual;
        // A estrutura é sempre a mesma (Stack com 2 filhos) para a página não
        // perder estado ao ligar/desligar a textura.
        return Stack(
          fit: StackFit.expand,
          children: [
            tx == null
                ? const SizedBox.shrink()
                : DecoratedBox(
                    decoration: BoxDecoration(
                      color: cor,
                      image: DecorationImage(
                        image: AssetImage(tx.asset),
                        fit: BoxFit.cover,
                        colorFilter: ColorFilter.mode(cor, BlendMode.multiply),
                      ),
                    ),
                  ),
            filho!,
          ],
        );
      },
    );
  }
}

/// Mantém a animação padrão de navegação, desenhando o fundo junto com cada
/// página.
class TransicaoComTextura extends PageTransitionsBuilder {
  const TransicaoComTextura();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const ZoomPageTransitionsBuilder().buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      FundoTextura(child: child),
    );
  }
}

final TemaState temaState = TemaState();

ThemeData construirTema(TemaMensal t) {
  final scheme = ColorScheme.fromSeed(
    seedColor: t.acento,
    brightness: Brightness.light,
  ).copyWith(
    primary: t.acento,
    onPrimary: t.fundo,
    secondary: t.detalhe,
    onSecondary: _texto,
    tertiary: t.detalhe,
    surface: t.fundo,
    onSurface: _texto,
    onSurfaceVariant: _textoSuave,
    surfaceContainerLowest: t.fundo,
    surfaceContainerLow: t.superficie,
    surfaceContainer: t.superficie,
    surfaceContainerHigh: t.superficie,
    surfaceContainerHighest: t.superficie,
    outline: t.detalhe,
    outlineVariant: t.detalhe.withValues(alpha: 0.5),
  );

  final forma = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
    side: BorderSide(color: t.detalhe, width: 1),
  );
  final campo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: t.detalhe),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'serif',
    fontFamilyFallback: const ['Georgia', 'Times New Roman'],
    scaffoldBackgroundColor: t.fundo,
    // Barra superior lisa, igual à de navegação: cor da superfície do tema e
    // título/ícones em preto ou branco.
    appBarTheme: AppBarTheme(
      backgroundColor: t.superficie,
      foregroundColor: _pretoOuBranco(t.superficie),
      elevation: 2,
      shadowColor: _sombra(t.acento),
      scrolledUnderElevation: 2,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'serif',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: _pretoOuBranco(t.superficie),
      ),
      shape: Border(bottom: BorderSide(color: t.detalhe, width: 1)),
    ),
    cardTheme: CardThemeData(
      color: t.superficie,
      elevation: 2,
      shadowColor: _sombra(t.acento),
      surfaceTintColor: Colors.transparent,
      shape: forma,
    ),
    dialogTheme: DialogThemeData(
      elevation: 10,
      shadowColor: _sombra(t.acento),
      backgroundColor: t.superficie,
      surfaceTintColor: Colors.transparent,
      shape: forma,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      elevation: 10,
      shadowColor: _sombra(t.acento),
      backgroundColor: t.superficie,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: t.detalhe),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 4,
      shadowColor: _sombra(t.acento),
      backgroundColor: t.superficie,
      surfaceTintColor: Colors.transparent,
      indicatorColor: t.acento.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? t.acento : _textoSuave,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'serif',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.bold
              : FontWeight.normal,
          color: s.contains(WidgetState.selected) ? t.acento : _textoSuave,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.superficie,
      border: campo,
      enabledBorder: campo,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: t.acento, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: t.acento,
        foregroundColor: t.fundo,
        elevation: 2,
        shadowColor: _sombra(t.acento),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: t.acento,
        side: BorderSide(color: t.acento),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: t.acento),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t.acento,
      foregroundColor: t.fundo,
      elevation: 5,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t.superficie,
      elevation: 4,
      indicatorColor: t.acento.withValues(alpha: 0.18),
      selectedIconTheme: IconThemeData(color: t.acento),
      unselectedIconTheme: const IconThemeData(color: _textoSuave),
      selectedLabelTextStyle: TextStyle(
          fontFamily: 'serif', fontWeight: FontWeight.bold, color: t.acento),
      unselectedLabelTextStyle:
          const TextStyle(fontFamily: 'serif', color: _textoSuave),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    hoverColor: t.acento.withValues(alpha: 0.08),
    scrollbarTheme: _barraRolagem(t.acento),
    chipTheme: ChipThemeData(
      backgroundColor: t.superficie,
      selectedColor: t.acento.withValues(alpha: 0.25),
      side: BorderSide(color: t.detalhe),
      labelStyle: const TextStyle(fontFamily: 'serif', color: _texto),
    ),
    listTileTheme: ListTileThemeData(iconColor: t.acento),
    dividerTheme: DividerThemeData(color: t.detalhe.withValues(alpha: 0.6)),
    iconTheme: IconThemeData(color: t.acento),
  );
}

// ---------------------------------------------------------------------------
// Tema "Base": o visual pergaminho original (claro).
// ---------------------------------------------------------------------------
const _papel = Color(0xFFFBF8F2);
const _papelClaro = Color(0xFFFDFBF8);
const _papelEscuro = Color(0xFFF3EDE1);
const _tinta = Color(0xFF3A2A1C);
const _vinho = Color(0xFF6E1F2B);
const _borda = Color(0xFF8B6F47);
const _musgo = Color(0xFF5A6B3A);

/// Cores usadas na bolinha da lista de temas.
const Color kBaseAcento = _vinho;
const Color kBaseDetalhe = _papelEscuro;

ThemeData construirTemaBase() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _vinho,
    brightness: Brightness.light,
  ).copyWith(
    primary: _vinho,
    onPrimary: _papelClaro,
    secondary: _musgo,
    tertiary: const Color(0xFF9A6B2F),
    surface: _papel,
    onSurface: _tinta,
    onSurfaceVariant: const Color(0xFF6B5640),
    surfaceContainerHighest: _papelEscuro,
    surfaceContainerHigh: _papelEscuro,
    surfaceContainer: _papelClaro,
    outline: _borda,
    outlineVariant: const Color(0xFFC9B48A),
  );

  final forma = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10),
    side: const BorderSide(color: _borda, width: 1),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'serif',
    fontFamilyFallback: const ['Georgia', 'Times New Roman'],
    scaffoldBackgroundColor: _papel,
    // Barra superior lisa, igual à de navegação (papel escuro), com texto
    // preto.
    appBarTheme: const AppBarTheme(
      backgroundColor: _papelEscuro,
      foregroundColor: Colors.black,
      elevation: 2,
      shadowColor: Color(0x598B6F47),
      scrolledUnderElevation: 2,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'serif',
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        color: Colors.black,
      ),
      shape: Border(bottom: BorderSide(color: _borda, width: 1)),
    ),
    cardTheme: CardThemeData(
      color: _papelClaro,
      elevation: 2,
      shadowColor: const Color(0x598B6F47),
      surfaceTintColor: Colors.transparent,
      shape: forma,
    ),
    dialogTheme: DialogThemeData(
      elevation: 10,
      shadowColor: const Color(0x598B6F47),
      backgroundColor: _papelClaro,
      surfaceTintColor: Colors.transparent,
      shape: forma,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      elevation: 10,
      shadowColor: Color(0x598B6F47),
      backgroundColor: _papelClaro,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        side: BorderSide(color: _borda),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      elevation: 4,
      shadowColor: const Color(0x598B6F47),
      backgroundColor: _papelEscuro,
      surfaceTintColor: Colors.transparent,
      indicatorColor: _vinho.withValues(alpha: 0.15),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? _vinho : _tinta,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: 'serif',
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.bold
              : FontWeight.normal,
          color: s.contains(WidgetState.selected) ? _vinho : _tinta,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: _papelClaro,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borda),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _borda),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _vinho, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _vinho,
        foregroundColor: _papelClaro,
        elevation: 2,
        shadowColor: const Color(0x598B6F47),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _vinho,
        side: const BorderSide(color: _vinho),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _vinho),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _vinho,
      foregroundColor: _papelClaro,
      elevation: 5,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: _papelEscuro,
      elevation: 4,
      indicatorColor: _vinho.withValues(alpha: 0.15),
      selectedIconTheme: const IconThemeData(color: _vinho),
      unselectedIconTheme: const IconThemeData(color: _tinta),
      selectedLabelTextStyle: const TextStyle(
          fontFamily: 'serif', fontWeight: FontWeight.bold, color: _vinho),
      unselectedLabelTextStyle:
          const TextStyle(fontFamily: 'serif', color: _tinta),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    hoverColor: _vinho.withValues(alpha: 0.08),
    scrollbarTheme: _barraRolagem(_vinho),
    chipTheme: ChipThemeData(
      backgroundColor: _papelClaro,
      selectedColor: _vinho.withValues(alpha: 0.18),
      side: const BorderSide(color: _borda),
      labelStyle: const TextStyle(fontFamily: 'serif', color: _tinta),
    ),
    listTileTheme: const ListTileThemeData(iconColor: _vinho),
    dividerTheme: const DividerThemeData(color: Color(0x668B6F47)),
    iconTheme: const IconThemeData(color: _vinho),
  );
}

// ---------------------------------------------------------------------------
// Acabamento visual: sombras quentes, luz de vela e adaptação ao computador.
// ---------------------------------------------------------------------------

/// Sombra suave, puxada para o tom do tema (em vez de preto puro).
Color _sombra(Color acento) =>
    Color.lerp(Colors.black, acento, 0.5)!.withValues(alpha: 0.45);

bool get _ehComputador =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.linux ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS;

/// No computador a barra de rolagem fica visível; no celular, como sempre.
ScrollbarThemeData _barraRolagem(Color cor) => ScrollbarThemeData(
      thumbVisibility: WidgetStatePropertyAll(_ehComputador),
      thumbColor: WidgetStatePropertyAll(cor.withValues(alpha: 0.55)),
      radius: const Radius.circular(8),
    );

/// Permite rolar arrastando com o mouse ou o touchpad (no celular não muda).
class RolagemTodosOsDispositivos extends MaterialScrollBehavior {
  const RolagemTodosOsDispositivos();
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

/// Luz por cima de tudo, sem interferir nos toques: um brilho quente de vela
/// no alto e as bordas levemente escurecidas, como uma vinheta.
class LuzAmbiente extends StatelessWidget {
  const LuzAmbiente({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.7),
                  radius: 1.25,
                  colors: const [
                    Color(0x0AFFE9B0),
                    Color(0x00000000),
                    Color(0x0B000000),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
