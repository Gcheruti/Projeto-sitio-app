import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Camada de natureza animada (só no app Android): poucas folhas caindo (ou
/// neve no inverno), brilho de lua/sol, runas que surgem e somem de tempos em
/// tempos, a silhueta de um coelho que cruza a tela (a cada 2 min) ou espia por
/// uma borda (a cada 1 min) e patinhas de coelho andando. Não recebe toque (IgnorePointer).
class NaturezaOverlay extends StatefulWidget {
  const NaturezaOverlay({super.key, required this.child, this.estacao});
  final Widget child;

  /// null = visual padrão; 0 primavera, 1 verão, 2 outono, 3 inverno.
  final int? estacao;

  @override
  State<NaturezaOverlay> createState() => _NaturezaOverlayState();
}

class _NaturezaOverlayState extends State<NaturezaOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 240),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        Positioned.fill(child: widget.child),
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _NaturezaPainter(_c, widget.estacao)),
            ),
          ),
        ),
      ],
    );
  }
}

const _salvia = Color(0xFF8FA67F);
const _ouro = Color(0xFFC9A55A);
const _lua = Color(0xFFF5ECC8);

// ---------------------------------------------------------------------------
// Runas desenhadas à mão (traços), para não depender de fonte com runas.
// Cada runa cabe numa caixa de 10 x 20; o último grupo são símbolos extras.
// ---------------------------------------------------------------------------
const List<List<List<double>>> _runas = [
  [[2, 20, 2, 0], [2, 6, 9, 0], [2, 12, 9, 6]], // fehu
  [[1, 20, 1, 0], [1, 0, 8, 6], [8, 6, 8, 20]], // uruz
  [[2, 0, 2, 20], [2, 5, 8, 10], [8, 10, 2, 15]], // thurisaz
  [[2, 0, 2, 20], [2, 0, 8, 5], [2, 7, 8, 12]], // ansuz
  [[2, 0, 2, 20], [2, 0, 8, 5], [8, 5, 2, 10], [2, 10, 8, 20]], // raidho
  [[8, 4, 2, 10], [2, 10, 8, 16]], // kenaz
  [[2, 2, 8, 18], [8, 2, 2, 18]], // gebo
  [[2, 0, 2, 20], [2, 0, 8, 5], [8, 5, 2, 10]], // wunjo
  [[7, 0, 3, 7], [3, 7, 7, 13], [7, 13, 3, 20]], // sowilo
  [[5, 0, 5, 20], [5, 0, 1, 6], [5, 0, 9, 6]], // tiwaz
  [[2, 0, 2, 20], [2, 0, 8, 5], [8, 5, 2, 10], [2, 10, 8, 15], [8, 15, 2, 20]], // berkano
  [[2, 0, 2, 20], [8, 0, 8, 20], [2, 0, 5, 7], [5, 7, 8, 0]], // mannaz
  [[5, 20, 5, 0], [5, 8, 1, 0], [5, 8, 9, 0]], // algiz
  [[2, 0, 2, 20], [8, 0, 8, 20], [2, 0, 8, 20], [8, 0, 2, 20]], // dagaz
];
const int _qtdRunas = 14;
const int _simboloLua = 14;
const int _simboloEstrela = 15;
const int _totalGlifos = 16;

/// Desenha o glifo [i] com a caixa centrada em [c] e altura [h].
void desenharGlifo(Canvas canvas, int i, Offset c, double h, Color cor,
    {double traco = 1.8}) {
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = traco
    ..color = cor;
  final k = h / 20;
  if (i < _qtdRunas) {
    for (final s in _runas[i]) {
      canvas.drawLine(
        Offset(c.dx + (s[0] - 5) * k, c.dy + (s[1] - 10) * k),
        Offset(c.dx + (s[2] - 5) * k, c.dy + (s[3] - 10) * k),
        p,
      );
    }
  } else if (i == _simboloLua) {
    final r = h * 0.45;
    final path = Path()
      ..addArc(Rect.fromCircle(center: c, radius: r), math.pi * .5, math.pi)
      ..arcToPoint(Offset(c.dx, c.dy + r),
          radius: Radius.circular(r * 0.9), clockwise: true);
    canvas.drawPath(path, p);
  } else {
    final r = h * 0.5;
    final pts = [
      for (var j = 0; j < 5; j++)
        Offset(c.dx + r * math.sin(j * 4 * math.pi / 5),
            c.dy - r * math.cos(j * 4 * math.pi / 5))
    ];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var j = 1; j < 5; j++) {
      path.lineTo(pts[j].dx, pts[j].dy);
    }
    path.close();
    canvas.drawPath(path, p);
    canvas.drawCircle(c, r * 1.12, p..strokeWidth = traco * .7);
  }
}

// Contorno do coelho (vetorizado da imagem de referência), normalizado pela
// altura: x de 0 a ~0,884 e y de 0 a 1. Pontos x,y,x,y...
const double _larguraCoelho = 0.884;
const List<double> _ptsCoelho = [
  0.256, 0.014, 0.243, 0.020, 0.215, 0.051, 0.185, 0.116, 0.181, 0.140, 0.181, 0.262, 0.174, 0.268, 0.134, 0.278, 0.081, 0.310, 0.037, 0.365, 0.000, 0.440, 0.002, 0.471, 0.024, 0.499, 0.061, 0.519, 0.114, 0.529, 0.122, 0.535, 0.118, 0.621, 0.128, 0.661, 0.158, 0.710, 0.231, 0.779, 0.243, 0.801, 0.245, 0.840, 0.233, 0.890, 0.211, 0.923, 0.183, 0.937, 0.170, 0.949, 0.166, 0.974, 0.181, 0.990, 0.201, 0.996, 0.260, 0.998, 0.286, 0.992, 0.318, 0.970, 0.365, 0.882, 0.385, 0.864, 0.442, 0.897, 0.452, 0.911, 0.446, 0.919, 0.416, 0.923, 0.385, 0.941, 0.379, 0.951, 0.379, 0.970, 0.398, 0.986, 0.422, 0.992, 0.688, 0.992, 0.720, 0.984, 0.753, 0.961, 0.775, 0.927, 0.817, 0.919, 0.840, 0.907, 0.858, 0.888, 0.880, 0.844, 0.882, 0.811, 0.878, 0.793, 0.868, 0.777, 0.850, 0.769, 0.807, 0.777, 0.799, 0.696, 0.773, 0.629, 0.732, 0.572, 0.677, 0.521, 0.633, 0.493, 0.576, 0.467, 0.501, 0.446, 0.400, 0.436, 0.377, 0.428, 0.365, 0.416, 0.361, 0.351, 0.351, 0.331, 0.331, 0.310, 0.381, 0.252, 0.426, 0.170, 0.448, 0.093, 0.448, 0.020, 0.432, 0.000, 0.416, 0.002, 0.394, 0.016, 0.337, 0.079, 0.296, 0.152, 0.292, 0.148, 0.300, 0.110, 0.296, 0.039, 0.282, 0.016
];
Path? _coelhoCache;
Path _caminhoCoelho() {
  final cached = _coelhoCache;
  if (cached != null) return cached;
  final n = _ptsCoelho.length ~/ 2;
  Offset p(int i) => Offset(_ptsCoelho[(i % n) * 2], _ptsCoelho[(i % n) * 2 + 1]);
  Offset m(int i) => (p(i) + p(i + 1)) / 2;
  final path = Path()..moveTo(m(n - 1).dx, m(n - 1).dy);
  for (var i = 0; i < n; i++) {
    path.quadraticBezierTo(p(i).dx, p(i).dy, m(i).dx, m(i).dy);
  }
  path.close();
  return _coelhoCache = path;
}

class _NaturezaPainter extends CustomPainter {
  _NaturezaPainter(this.anim, this.estacao) : super(repaint: anim);
  final Animation<double> anim;
  final int? estacao;

  double get _t => anim.value * 240; // segundos

  @override
  void paint(Canvas canvas, Size s) {
    final t = _t;
    _brilho(canvas, s, t);
    _folhas(canvas, s, t);
    _runasFlutuantes(canvas, s, t);
    _raios(canvas, s, t);
    _patinhas(canvas, s, t);
    _borboleta(canvas, s, t);
    _coelho(canvas, s, t);
    _espiar(canvas, s, t);
  }

  // Brilho de lua (ou sol, no verão) no canto superior direito.
  void _brilho(Canvas c, Size s, double t) {
    final k = 0.75 + 0.25 * math.sin(t / 8 * math.pi);
    final centro = Offset(s.width * 0.86, s.height * 0.07);
    final r = s.width * (estacao == 1 ? 0.8 : 0.55);
    final cor = estacao == 1
        ? const Color(0xFFFFD36B)
        : estacao == 3
            ? const Color(0xFFDDEBFF)
            : _lua;
    c.drawCircle(
      centro,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          cor.withValues(alpha: (estacao == 1 ? 0.4 : 0.28) * k),
          cor.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: centro, radius: r)),
    );
  }

  void _folha(Canvas c, Offset o, double tam, double ang, Paint p) {
    c.save();
    c.translate(o.dx, o.dy);
    c.rotate(ang);
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(tam * .7, -tam * .3, 0, -tam)
      ..quadraticBezierTo(-tam * .7, -tam * .3, 0, 0);
    c.drawPath(path, p);
    c.restore();
  }

  // Poucas folhas (neve no inverno) caindo devagar.
  void _folhas(Canvas c, Size s, double t) {
    final p = Paint();
    if (estacao == 3) {
      for (var i = 0; i < 22; i++) {
        final per = 11.0 + (i * 1.3) % 7;
        final fase = (t / per + i * 0.137) % 1.0;
        final y = -10 + fase * (s.height + 20);
        final x = (i * 0.0713 % 1.0) * s.width +
            math.sin(fase * math.pi * 3 + i) * 22;
        p.color = Colors.white.withValues(alpha: 0.8);
        c.drawCircle(Offset(x, y), 1.6 + (i % 4) * 0.7, p);
      }
      return;
    }
    final cores = switch (estacao) {
      0 => const [Color(0xFFF2B3C6), Color(0xFFFFFFFF), _salvia],
      1 => const [Color(0xFFFFC247), _salvia, Color(0xFFE8D26A)],
      2 => const [Color(0xFFD9822B), Color(0xFF9A3412), Color(0xFFC9A55A)],
      _ => const [_salvia, _salvia, _ouro],
    };
    final qtd = estacao == 2 ? 7 : 5;
    for (var i = 0; i < qtd; i++) {
      final per = 16.0 + (i * 2.3) % 9;
      final fase = (t / per + i * 0.21) % 1.0;
      final y = -30 + fase * (s.height + 60);
      final x = (i * 0.1931 % 1.0) * s.width +
          math.sin(fase * math.pi * 4 + i) * 38;
      p.color = cores[i % 3].withValues(alpha: 0.6);
      _folha(c, Offset(x, y), 13 + (i % 3) * 3, fase * math.pi * 6 + i, p);
    }
  }

  // Uma runa/símbolo por vez surge num ponto da tela, brilha e some.
  void _runasFlutuantes(Canvas c, Size s, double t) {
    const periodo = 13.0, vida = 8.0;
    final slot = (t / periodo).floor();
    final dentro = t - slot * periodo;
    if (dentro > vida) return;
    final a = math.sin(dentro / vida * math.pi);
    final r = math.Random(slot * 7919 + 13);
    final glifo = r.nextInt(_totalGlifos);
    final pos = Offset(
      s.width * (0.1 + r.nextDouble() * 0.8),
      s.height * (0.14 + r.nextDouble() * 0.66),
    );
    final cor = estacao == 3 ? const Color(0xFFBFD8F0) : _ouro;
    final h = 34 + r.nextDouble() * 12;
    desenharGlifo(c, glifo, pos, h * 1.6, cor.withValues(alpha: 0.18 * a),
        traco: 7);
    desenharGlifo(c, glifo, pos, h, cor.withValues(alpha: 0.75 * a),
        traco: 2.2);
  }

  // A cada 40 s, 4 patinhas andam na mesma direção (esquerda -> direita,
  // subindo um pouco), uma a cada 1,2 s, alternando esquerda/direita.
  void _patinhas(Canvas c, Size s, double t) {
    const ciclo = 40.0;
    final d = (t % ciclo) - 14;
    if (d < 0 || d > 12) return;
    final r = math.Random((t / ciclo).floor() + 5);
    final x0 = s.width * (0.08 + r.nextDouble() * 0.15);
    final y0 = s.height * (0.7 + r.nextDouble() * 0.12);
    const ang = -0.38;
    final dir = Offset(math.cos(ang), math.sin(ang));
    final lado = Offset(-dir.dy, dir.dx);
    final passo = s.width * 0.2;
    for (var i = 0; i < 4; i++) {
      final idade = d - i * 1.2;
      if (idade < 0 || idade > 4.5) continue;
      final a = idade < 0.5 ? idade / 0.5 : (idade > 3 ? (4.5 - idade) / 1.5 : 1.0);
      final centro = Offset(x0, y0) + dir * (passo * i) +
          lado * (i.isEven ? 10.0 : -10.0);
      c.save();
      c.translate(centro.dx, centro.dy);
      c.rotate(ang + math.pi / 2);
      final p = Paint()
        ..color = const Color(0xFF3A2A1C).withValues(alpha: 0.4 * a);
      c.drawOval(const Rect.fromLTWH(-6, -2, 12, 14), p);
      c.drawOval(const Rect.fromLTWH(-11, -11, 5.5, 8.5), p);
      c.drawOval(const Rect.fromLTWH(-2.8, -15, 5.6, 9.5), p);
      c.drawOval(const Rect.fromLTWH(5.5, -11, 5.5, 8.5), p);
      c.restore();
    }
  }

  // Silhueta do coelho (contorno vetorizado de uma imagem de referência),
  // desenhada de uma vez só, cor única e transparente: sem sobreposição.
  // [x],[y] = centro da base dos pés; [h] = altura; [paraDireita] = quando
  // true o coelho olha para a direita (o desenho original olha para a esquerda).
  void _silhueta(Canvas c, double x, double y, double h, bool paraDireita,
      double ang, {double sx = 1, double sy = 1}) {
    c.save();
    c.translate(x, y);
    c.rotate(ang);
    c.scale((paraDireita ? -h : h) * sx, h * sy);
    c.translate(-_larguraCoelho / 2, -1.0);
    c.drawPath(_caminhoCoelho(), Paint()..color = Colors.black.withValues(alpha: 0.3));
    c.restore();
  }

  double _suave(double u) => u * u * (3 - 2 * u);

  // A cada 2 min a silhueta de um coelho atravessa a tela (~7,5 s), ora da
  // esquerda para a direita, ora ao contrário: 8 saltos em arco, com o
  // corpo esticando no ar e encolhendo ao tocar o chão, nariz para cima na
  // subida e para baixo na descida, e uma paradinha no meio para farejar.
  void _coelho(Canvas c, Size s, double t) {
    final d = t % 120;
    const total = 7.5, pausa = 0.9, saltos = 8, pausaApos = 4;
    if (d > total) return;
    final n = (t / 120).floor();
    final paraDireita = math.Random(n * 31 + 7).nextBool();
    final sinal = paraDireita ? 1.0 : -1.0;
    const durSalto = (total - pausa) / saltos;
    final inicio = paraDireita ? -s.width * 0.1 : s.width * 1.1;
    final passo = s.width * 1.2 / saltos * sinal;
    final chao = s.height - 24;
    const h = 46.0;

    final iniPausa = pausaApos * durSalto;
    if (d >= iniPausa && d < iniPausa + pausa) {
      // parado, farejando (cabeça sobe e desce de leve)
      final u = (d - iniPausa) / pausa;
      final fareja = math.sin(u * 5 * math.pi) * 0.05 * (u > 0.15 && u < 0.85 ? 1 : 0);
      _silhueta(c, inicio + passo * pausaApos, chao, h, paraDireita,
          -fareja * sinal);
      return;
    }
    final tempoSalto = d < iniPausa ? d : d - pausa;
    final k = (tempoSalto / durSalto).floor().clamp(0, saltos - 1).toInt();
    final u = ((tempoSalto - k * durSalto) / durSalto).clamp(0.0, 1.0).toDouble();
    // avanço mais rápido no meio do salto
    final avanco = _suave(u);
    final x = inicio + passo * (k + avanco);
    final altura = 4 * u * (1 - u) * 18;
    final ar = math.sin(u * math.pi); // 0 no chão, 1 no alto
    final sy = 0.9 + 0.16 * ar; // encolhe no chão, estica no ar
    final sx = 1.08 - 0.12 * ar;
    final ang = (0.5 - u) * 0.32 * -sinal; // nariz sobe e depois desce
    _silhueta(c, x, chao - altura, h, paraDireita, ang, sx: sx, sy: sy);
  }

  // A cada 60 s o coelho espia por uma borda (esquerda, direita ou embaixo,
  // sorteado), fareja e volta: ~1,2 s.
  void _espiar(Canvas c, Size s, double t) {
    final d = (t % 60) - 24;
    const dur = 1.2;
    if (d < 0 || d > dur) return;
    final r = math.Random((t / 60).floor() * 17 + 3);
    final lado = r.nextInt(3); // 0 esquerda, 1 direita, 2 embaixo
    final u = d / dur;
    final e = _suave(u < 0.25 ? u / 0.25 : (u > 0.75 ? (1 - u) / 0.25 : 1.0));
    final fareja = (u > 0.25 && u < 0.75) ? math.sin(u * 7 * math.pi) * 0.06 : 0.0;
    const h = 64.0;
    const w = h * _larguraCoelho;
    if (lado == 0) {
      final y0 = s.height * (0.3 + r.nextDouble() * 0.5);
      _silhueta(c, 0.5 * w * e - w / 2 + w * 0.0, y0 + h / 2, h, true, fareja);
    } else if (lado == 1) {
      final y0 = s.height * (0.3 + r.nextDouble() * 0.5);
      _silhueta(c, s.width - 0.5 * w * e + w / 2, y0 + h / 2, h, false, -fareja);
    } else {
      final x0 = s.width * (0.15 + r.nextDouble() * 0.7);
      _silhueta(c, x0, s.height + h * (1 - 0.55 * e), h, r.nextBool(), fareja);
    }
  }

  // Primavera: uma borboleta atravessa a tela de vez em quando.
  void _borboleta(Canvas c, Size s, double t) {
    if (estacao != 0) return;
    final d = (t % 45) - 12;
    if (d < 0 || d > 10) return;
    final f = d / 10;
    final x = s.width * (-0.05 + f * 1.1);
    final y = s.height * (0.35 + 0.1 * math.sin(f * 5 * math.pi)) +
        math.sin(f * 20) * 8;
    final bate = 0.35 + 0.65 * math.sin(d * 16).abs();
    c.save();
    c.translate(x, y);
    final asa = Paint()..color = const Color(0xFFE59AB5).withValues(alpha: 0.7);
    for (final lado in [-1.0, 1.0]) {
      c.save();
      c.scale(lado * bate, 1);
      c.drawOval(const Rect.fromLTWH(0, -9, 11, 10), asa);
      c.drawOval(const Rect.fromLTWH(0, -1, 8, 8), asa);
      c.restore();
    }
    c.drawLine(const Offset(0, -6), const Offset(0, 7),
        Paint()..color = const Color(0xFF3A2A1C).withValues(alpha: 0.7)..strokeWidth = 1.6);
    c.restore();
  }

  // Verão: raios de sol suaves saindo do canto superior.
  void _raios(Canvas c, Size s, double t) {
    if (estacao != 1) return;
    final origem = Offset(s.width * 0.9, -10);
    final k = 0.6 + 0.4 * math.sin(t / 5);
    for (var i = 0; i < 5; i++) {
      final a = 1.9 + i * 0.28;
      final len = s.height * 0.9;
      final p = Path()
        ..moveTo(origem.dx, origem.dy)
        ..lineTo(origem.dx + math.cos(a - 0.05) * len, origem.dy + math.sin(a - 0.05) * len)
        ..lineTo(origem.dx + math.cos(a + 0.05) * len, origem.dy + math.sin(a + 0.05) * len)
        ..close();
      c.drawPath(p, Paint()..color = const Color(0xFFFFE08A).withValues(alpha: 0.07 * k));
    }
  }

  @override
  bool shouldRepaint(covariant _NaturezaPainter old) =>
      old.estacao != estacao;
}

/// Borda de cartão com moldura dupla (a de dentro mais fina e apagada) e uma
/// runa (Algiz) desenhada no canto.
class BordaRunica extends OutlinedBorder {
  const BordaRunica({super.side = BorderSide.none, this.raio = 14});
  final double raio;

  RRect _rr(Rect r, [double r0 = 0]) =>
      RRect.fromRectAndRadius(r, Radius.circular(math.max(0.0, raio - r0)));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rr(rect.deflate(side.width), side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rr(rect));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawRRect(
      _rr(rect.deflate(side.width / 2), side.width / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..color = side.color,
    );
    if (rect.shortestSide < 44) return;
    canvas.drawRRect(
      _rr(rect.deflate(6), 6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = _ouro.withValues(alpha: 0.4),
    );
    // runa no canto superior direito (varia com a posição para não repetir)
    final g = ((rect.left + rect.top).abs() ~/ 7) % _totalGlifos;
    desenharGlifo(canvas, g, Offset(rect.right - 20, rect.top + 21), 16,
        _ouro.withValues(alpha: 0.85),
        traco: 1.6);
  }

  @override
  ShapeBorder scale(double t) => BordaRunica(side: side.scale(t), raio: raio * t);

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      BordaRunica(side: side ?? this.side, raio: raio);
}
