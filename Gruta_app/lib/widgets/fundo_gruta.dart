import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/gruta_tema.dart';

/// Fundo da Gruta: escuro quente, uma luz de lamparina vinda do alto e
/// poeira dourada flutuando devagar. Desliga a animação se o sistema pedir.
class FundoGruta extends StatefulWidget {
  const FundoGruta({super.key, required this.child, this.poeira = true});
  final Widget child;
  final bool poeira;

  @override
  State<FundoGruta> createState() => _FundoGrutaState();
}

class _FundoGrutaState extends State<FundoGruta>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(seconds: 40))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animar = widget.poeira && !MediaQuery.of(context).disableAnimations;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -1.1),
              radius: 1.25,
              colors: [GrutaCores.fundoTopo, GrutaCores.fundoMeio, GrutaCores.noite],
              stops: [0, .45, 1],
            ),
          ),
        ),
        if (animar)
          IgnorePointer(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, _) =>
                    CustomPaint(painter: _Poeira(_c.value)),
              ),
            ),
          ),
        widget.child,
      ],
    );
  }
}

class _Poeira extends CustomPainter {
  _Poeira(this.t);
  final double t;
  static final _r = math.Random(7);
  static final _graos = List.generate(
      26,
      (_) => (
            x: _r.nextDouble(),
            y: _r.nextDouble(),
            v: .3 + _r.nextDouble() * .7,
            tam: .6 + _r.nextDouble() * 1.6,
            fase: _r.nextDouble() * math.pi * 2,
          ));

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint();
    for (final g in _graos) {
      final y = (g.y - t * g.v) % 1.0;
      final x = g.x + math.sin(t * math.pi * 2 * g.v + g.fase) * .02;
      final brilho = (.25 + .35 * (1 - y)) *
          (.6 + .4 * math.sin(t * math.pi * 8 + g.fase));
      p.color = GrutaCores.chama.withValues(alpha: brilho.clamp(0, 1) * .5);
      canvas.drawCircle(Offset(x * s.width, y * s.height), g.tam, p);
    }
  }

  @override
  bool shouldRepaint(covariant _Poeira old) => old.t != t;
}

/// Mantém o MESMO layout em celular, tablet e navegador: o app vira uma
/// coluna de no máximo 480 px centralizada, com a gruta escura dos lados.
class MolduraApp extends StatelessWidget {
  const MolduraApp({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final largura = MediaQuery.of(context).size.width;
    if (largura <= GrutaMedidas.larguraMaxima + 40) return child;
    return ColoredBox(
      color: GrutaCores.lados,
      child: Center(
        child: Container(
          constraints:
              const BoxConstraints(maxWidth: GrutaMedidas.larguraMaxima),
          decoration: BoxDecoration(
            border: Border.symmetric(
                vertical: BorderSide(color: GrutaCores.linha)),
            boxShadow: [
              BoxShadow(color: GrutaCores.chama.withValues(alpha: .4), blurRadius: 80, spreadRadius: -30),
            ],
          ),
          child: ClipRect(
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  size: Size(GrutaMedidas.larguraMaxima,
                      MediaQuery.of(context).size.height)),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
