import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/gruta_tema.dart';

/// A vela da ofensiva. Acesa = estudou hoje (ou a ofensiva está viva);
/// apagada = só o pavio com um fio de fumaça. A chama tremula sozinha.
class Vela extends StatefulWidget {
  const Vela({
    super.key,
    required this.acesa,
    this.tamanho = 64,
    this.animada = true,
  });

  final bool acesa;
  final double tamanho; // altura total
  final bool animada;

  @override
  State<Vela> createState() => _VelaState();
}

class _VelaState extends State<Vela> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    if (widget.animada) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant Vela old) {
    super.didUpdateWidget(old);
    if (widget.animada && !_c.isAnimating) _c.repeat();
    if (!widget.animada && _c.isAnimating) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semAnimacao = MediaQuery.of(context).disableAnimations;
    return RepaintBoundary(
      child: SizedBox(
        width: widget.tamanho * .7,
        height: widget.tamanho,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _PintorVela(
                t: semAnimacao ? 0 : _c.value, acesa: widget.acesa),
          ),
        ),
      ),
    );
  }
}

class _PintorVela extends CustomPainter {
  _PintorVela({required this.t, required this.acesa});
  final double t;
  final bool acesa;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;
    final cx = w / 2;
    final corpoTopo = h * .48;
    final corpoL = w * .42;

    // Brilho em volta da chama
    if (acesa) {
      final pulso = .85 + .15 * math.sin(t * math.pi * 2);
      canvas.drawCircle(
        Offset(cx, h * .32),
        w * .62 * pulso,
        Paint()
          ..shader = RadialGradient(colors: [
            GrutaCores.chama.withValues(alpha: .40),
            GrutaCores.chama.withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(
              center: Offset(cx, h * .32), radius: w * .62 * pulso)),
      );
    }

    // Corpo da vela (cera)
    final corpo = RRect.fromRectAndCorners(
      Rect.fromLTWH(cx - corpoL / 2, corpoTopo, corpoL, h - corpoTopo),
      topLeft: const Radius.circular(3),
      topRight: const Radius.circular(3),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas.drawRRect(
      corpo,
      Paint()
        ..shader = LinearGradient(
          colors: acesa
              ? const [Color(0xFFF6E7C8), Color(0xFFD9BD8E)]
              : const [Color(0xFF7D7062), Color(0xFF55493E)],
        ).createShader(corpo.outerRect),
    );
    // Cera escorrida
    final pingo = Path()
      ..moveTo(cx - corpoL / 2, corpoTopo + 2)
      ..quadraticBezierTo(cx - corpoL * .35, corpoTopo + h * .12,
          cx - corpoL * .22, corpoTopo + 2)
      ..close();
    canvas.drawPath(
        pingo,
        Paint()
          ..color = acesa ? const Color(0xFFFFF4DC) : const Color(0xFF8A7D6E));

    // Pavio
    final pavio = Paint()
      ..color = const Color(0xFF2A1E14)
      ..strokeWidth = math.max(1.5, w * .035)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, corpoTopo), Offset(cx, corpoTopo - h * .06), pavio);

    if (acesa) {
      // Chama: duas gotas sobrepostas, balançando
      final balanco = math.sin(t * math.pi * 2) * w * .04;
      final estica = 1 + .06 * math.sin(t * math.pi * 4);
      _chama(canvas, Offset(cx, corpoTopo - h * .04), w * .26, h * .30 * estica,
          balanco, const [Color(0xFFD9772B), Color(0xFFF0A63A), Color(0xFFFFE08A)]);
      _chama(canvas, Offset(cx, corpoTopo - h * .05), w * .12, h * .15 * estica,
          balanco * .6, const [Color(0xFFFFF6D8), Color(0xFFFFFFFF)]);
    } else {
      // Fio de fumaça
      final fumaca = Path()..moveTo(cx, corpoTopo - h * .06);
      for (var i = 1; i <= 4; i++) {
        final y = corpoTopo - h * .06 - i * h * .07;
        final x = cx + math.sin(t * math.pi * 2 + i) * w * .08;
        fumaca.lineTo(x, y);
      }
      canvas.drawPath(
          fumaca,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = GrutaCores.textoApagado.withValues(alpha: .6));
    }
  }

  void _chama(Canvas c, Offset base, double largura, double altura,
      double balanco, List<Color> cores) {
    final topo = Offset(base.dx + balanco, base.dy - altura);
    final p = Path()
      ..moveTo(base.dx, base.dy)
      ..cubicTo(base.dx - largura, base.dy - altura * .25, topo.dx - largura * .4,
          topo.dy + altura * .35, topo.dx, topo.dy)
      ..cubicTo(topo.dx + largura * .4, topo.dy + altura * .35,
          base.dx + largura, base.dy - altura * .25, base.dx, base.dy)
      ..close();
    c.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: cores,
        ).createShader(p.getBounds()),
    );
  }

  @override
  bool shouldRepaint(covariant _PintorVela old) =>
      old.t != t || old.acesa != acesa;
}
