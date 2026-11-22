import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/aula.dart';
import '../models/trilha.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/fundo_gruta.dart';
import '../widgets/pecas.dart';
import 'planos_sheet.dart';
import 'aula_screen.dart';

/// Uma trilha: o caminho de aulas descendo pela gruta, em zigue-zague.
class TrilhaScreen extends StatelessWidget {
  const TrilhaScreen({super.key, required this.trilhaId});
  final String trilhaId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final t = appState.trilhaPorId(trilhaId)!;
        final aulas = appState.aulasDa(trilhaId);
        final feitas = appState.concluidasNa(trilhaId);
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(),
          body: FundoGruta(
            child: ListView(
              padding: EdgeInsets.fromLTRB(GrutaMedidas.margem,
                  MediaQuery.of(context).padding.top + 56, GrutaMedidas.margem, 48),
              children: [
                Center(
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: t.cor.withValues(alpha: .14),
                      border: Border.all(color: t.cor, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: t.cor.withValues(alpha: .35),
                            blurRadius: 40),
                      ],
                    ),
                    child: Icon(t.iconData, color: t.cor, size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                Center(child: Text(t.titulo, style: GrutaTema.titulo(42))),
                const SizedBox(height: 4),
                Center(
                  child: Text(t.subtitulo,
                      style: TextStyle(
                          color: t.cor, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 14),
                Text(t.descricao,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: GrutaCores.textoSuave, height: 1.5)),
                const SizedBox(height: 18),
                Row(children: [
                  Expanded(
                      child: BarraProgresso(
                          valor: aulas.isEmpty ? 0 : feitas / aulas.length,
                          cor: t.cor)),
                  const SizedBox(width: 10),
                  Text('$feitas de ${aulas.length} aulas',
                      style: TextStyle(
                          fontSize: 13, color: GrutaCores.textoSuave)),
                ]),
                const SizedBox(height: 30),
                for (var i = 0; i < aulas.length; i++)
                  _NoCaminho(
                    aula: aulas[i],
                    trilha: t,
                    indice: i,
                    ultimo: i == aulas.length - 1,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NoCaminho extends StatelessWidget {
  const _NoCaminho({
    required this.aula,
    required this.trilha,
    required this.indice,
    required this.ultimo,
  });

  final Aula aula;
  final Trilha trilha;
  final int indice;
  final bool ultimo;

  // Deslocamento horizontal em zigue-zague suave (-1..1).
  double get _dx => math.sin(indice * 1.1) * .55;

  @override
  Widget build(BuildContext context) {
    final estado = appState.estadoDa(aula);
    final (IconData icone, Color fundo, Color cor, String? selo) =
        switch (estado) {
      EstadoAula.concluida => (Icons.check_rounded, trilha.cor, GrutaCores.noite, null),
      EstadoAula.disponivel => (
          Icons.play_arrow_rounded,
          GrutaCores.chama,
          GrutaCores.noite,
          'HOJE'
        ),
      EstadoAula.amanha => (
          Icons.nightlight_round,
          GrutaCores.rochaClara,
          GrutaCores.ouro,
          'AMANHÃ'
        ),
      EstadoAula.trancada => (
          Icons.lock_outline,
          GrutaCores.rochaClara,
          GrutaCores.ouro,
          'PLANO'
        ),
      EstadoAula.bloqueada => (
          Icons.lock_outline,
          GrutaCores.rocha,
          GrutaCores.textoApagado,
          null
        ),
    };
    final destaque = estado == EstadoAula.disponivel;
    final apagado = estado == EstadoAula.bloqueada;

    return SizedBox(
      height: ultimo ? 150 : 200,
      child: Stack(children: [
        if (!ultimo)
          Positioned.fill(
            child: CustomPaint(
              painter: _Trilho(
                de: _dx,
                para: math.sin((indice + 1) * 1.1) * .55,
                cor: estado == EstadoAula.concluida
                    ? trilha.cor.withValues(alpha: .6)
                    : GrutaCores.linha,
              ),
            ),
          ),
        Align(
          alignment: Alignment(_dx, -1),
          child: GestureDetector(
            onTap: () => _tocar(context, estado),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: destaque ? 84 : 72,
                height: destaque ? 84 : 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fundo,
                  border: Border.all(
                      color: apagado ? GrutaCores.linha : cor.withValues(alpha: .6),
                      width: 2),
                  boxShadow: [
                    if (destaque)
                      BoxShadow(
                          color: GrutaCores.chama.withValues(alpha: .55),
                          blurRadius: 32,
                          spreadRadius: 2),
                    const BoxShadow(
                        color: Color(0x99000000),
                        blurRadius: 10,
                        offset: Offset(0, 6)),
                  ],
                ),
                child: Icon(icone, color: cor, size: destaque ? 44 : 34),
              ),
              const SizedBox(height: 8),
              if (selo != null)
                Text(selo,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.6,
                        color: destaque ? GrutaCores.chama : GrutaCores.ouro)),
              SizedBox(
                width: 170,
                child: Text(
                  '${aula.ordem}. ${aula.titulo}',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: apagado
                          ? GrutaCores.textoApagado
                          : GrutaCores.pergaminho),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  void _tocar(BuildContext context, EstadoAula estado) {
    switch (estado) {
      case EstadoAula.concluida:
      case EstadoAula.disponivel:
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => AulaScreen(aula: aula)));
      case EstadoAula.trancada:
        mostrarPlanos(context);
      case EstadoAula.amanha:
        _aviso(context, 'Esta aula abre amanhã. Uma vela por dia!');
      case EstadoAula.bloqueada:
        _aviso(context, 'Conclua as aulas anteriores para chegar aqui.');
    }
  }

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }
}

/// Linha pontilhada ligando um nó ao próximo.
class _Trilho extends CustomPainter {
  _Trilho({required this.de, required this.para, required this.cor});
  final double de, para;
  final Color cor;

  @override
  void paint(Canvas canvas, Size s) {
    double x(double a) => s.width / 2 + a * (s.width / 2 - 42);
    // Começa abaixo do título da aula e termina em cima do próximo círculo.
    final inicio = Offset(x(de), 138);
    final fim = Offset(x(para), s.height - 4);
    final meio = (fim.dy - inicio.dy) / 2;
    final path = Path()
      ..moveTo(inicio.dx, inicio.dy)
      ..cubicTo(inicio.dx, inicio.dy + meio, fim.dx, fim.dy - meio, fim.dx,
          fim.dy);
    final p = Paint()
      ..color = cor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 12) {
        final a = m.getTangentForOffset(d)!.position;
        canvas.drawCircle(a, 1.8, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Trilho old) =>
      old.de != de || old.para != para || old.cor != cor;
}
