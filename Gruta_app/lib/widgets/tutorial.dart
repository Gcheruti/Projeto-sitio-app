import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/gruta_tema.dart';

/// Pontos da tela que o tutorial destaca. Cada tela marca o seu com
/// `KeyedSubtree(key: TutorialAlvos.x, child: ...)`.
class TutorialAlvos {
  TutorialAlvos._();
  static final vela = GlobalKey(debugLabel: 'tutorial-vela');
  static final aula = GlobalKey(debugLabel: 'tutorial-aula');
  static final moedas = GlobalKey(debugLabel: 'tutorial-moedas');
  static final avisos = GlobalKey(debugLabel: 'tutorial-avisos');
  static final servicos = GlobalKey(debugLabel: 'tutorial-servicos');

  /// A barra de abas de baixo; o passo diz qual aba (0 a 4) destacar.
  static final abas = GlobalKey(debugLabel: 'tutorial-abas');

  /// Rolagem da aba Hoje, para voltar ao topo quando o alvo sumiu da tela.
  static final rolagemHoje = ScrollController();
  static const totalAbas = 5;
}

/// Um passo do tutorial. Sem [alvo] nem [aba], o cartão aparece no centro.
class PassoTutorial {
  const PassoTutorial({
    required this.titulo,
    required this.texto,
    required this.icone,
    this.alvo,
    this.aba,
  });
  final String titulo;
  final String texto;
  final IconData icone;
  final GlobalKey? alvo;
  final int? aba;
}

/// O roteiro da primeira entrada.
final List<PassoTutorial> kPassosTutorial = [
  const PassoTutorial(
    icone: Icons.auto_awesome,
    titulo: 'Boas-vindas à Gruta',
    texto:
        'Um passeio rápido para você saber onde fica cada coisa. '
        'Leva menos de um minuto.',
  ),
  PassoTutorial(
    alvo: TutorialAlvos.avisos,
    icone: Icons.notifications_none_rounded,
    titulo: 'Avisos',
    texto: 'Novidades, lives e recados da Gruta chegam aqui.',
  ),
  PassoTutorial(
    alvo: TutorialAlvos.servicos,
    icone: Icons.storefront_outlined,
    titulo: 'Outros serviços',
    texto: 'Conheça também a Cosmória e o Sítio dos Coelhos.',
  ),
  PassoTutorial(
    alvo: TutorialAlvos.vela,
    icone: Icons.local_fire_department,
    titulo: 'Sua vela',
    texto:
        'Cada dia em que você faz a aula, a vela acende. Dias seguidos '
        'formam sua sequência. Se passar um dia sem aula, ela apaga.',
  ),
  PassoTutorial(
    alvo: TutorialAlvos.aula,
    icone: Icons.play_circle_outline,
    titulo: 'A aula do dia',
    texto:
        'A Jornada tem 60 aulas curtas em vídeo, uma por dia. Assista '
        'até o fim para concluir. A próxima abre à meia-noite.',
  ),
  PassoTutorial(
    alvo: TutorialAlvos.moedas,
    icone: Icons.nightlight_round,
    titulo: 'Moedas',
    texto:
        'Ao avançar na Jornada você ganha moedas. Cada moeda abre uma '
        'trilha de conhecimento à sua escolha.',
  ),
  const PassoTutorial(
    aba: 1,
    icone: Icons.auto_stories,
    titulo: 'Trilhas',
    texto:
        'Tarô, bruxaria, chás medicinais, plantas e mais. Elas começam '
        'trancadas: abra com suas moedas ou com o plano Aprendiz.',
  ),
  const PassoTutorial(
    aba: 2,
    icone: Icons.menu_book,
    titulo: 'Grimório',
    texto:
        'Seu caderno pessoal. O que você escreve ao fim de cada aula '
        'fica guardado aqui.',
  ),
  const PassoTutorial(
    aba: 3,
    icone: Icons.live_tv,
    titulo: 'Lives',
    texto: 'Encontros ao vivo com a Gruta: veja as próximas datas.',
  ),
  const PassoTutorial(
    aba: 4,
    icone: Icons.person,
    titulo: 'Perfil',
    texto:
        'Seu progresso e seu plano. Na engrenagem você muda nome, tema, '
        'interesses e pode rever este tutorial quando quiser.',
  ),
];

/// Abre o tutorial por cima do app. Termina quando a pessoa chega ao fim
/// ou toca em "Pular".
Future<void> mostrarTutorial(
  NavigatorState nav, {
  List<PassoTutorial>? passos,
}) {
  return nav.push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) =>
          _TutorialOverlay(passos: passos ?? kPassosTutorial),
      transitionsBuilder: (_, anim, _, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _TutorialOverlay extends StatefulWidget {
  const _TutorialOverlay({required this.passos});
  final List<PassoTutorial> passos;

  @override
  State<_TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<_TutorialOverlay>
    with TickerProviderStateMixin {
  late final List<PassoTutorial> _passos;
  int _i = 0;
  Rect? _de, _para;

  late final _mover = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final _pulso = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void initState() {
    super.initState();
    // Passos cujo alvo não está na tela (ex.: moedas para quem já tem
    // todas as trilhas) são pulados.
    _passos = widget.passos.where((p) {
      if (p.alvo == null) return true;
      final box = p.alvo!.currentContext?.findRenderObject() as RenderBox?;
      return box != null && box.hasSize && box.size.height > 4;
    }).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) => _irPara(0));
  }

  @override
  void dispose() {
    _mover.dispose();
    _pulso.dispose();
    super.dispose();
  }

  PassoTutorial get _passo => _passos[_i];

  Future<void> _irPara(int i) async {
    final p = _passos[i];
    final rol = TutorialAlvos.rolagemHoje;
    if (p.alvo != null && p.alvo!.currentContext == null && rol.hasClients) {
      // O alvo saiu da tela ao rolar: volta a aba Hoje para o topo.
      await rol.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (!mounted) return;
    }
    final ctx = p.alvo?.currentContext;
    if (ctx != null && ctx.mounted && Scrollable.maybeOf(ctx) != null) {
      await Scrollable.ensureVisible(
        ctx,
        alignment: .35,
        duration: const Duration(milliseconds: 300),
      );
    }
    if (!mounted) return;
    setState(() {
      _de = _atual;
      _i = i;
      _para = _rectDo(p);
    });
    _mover.forward(from: 0);
  }

  Rect? get _atual =>
      _de == null ? _para : Rect.lerp(_de, _para, _curva(_mover.value));

  static double _curva(double t) => Curves.easeInOutCubic.transform(t);

  Rect? _rectDo(PassoTutorial p) {
    final key = p.alvo ?? (p.aba != null ? TutorialAlvos.abas : null);
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    final eu = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || eu == null) return null;
    final origem = eu.globalToLocal(box.localToGlobal(Offset.zero));
    var r = origem & box.size;
    if (p.aba != null) {
      final w = r.width / TutorialAlvos.totalAbas;
      r = Rect.fromLTWH(r.left + w * p.aba!, r.top, w, r.height);
    }
    return r;
  }

  void _fechar() {
    final rol = TutorialAlvos.rolagemHoje;
    if (rol.hasClients) {
      rol.animateTo(0,
          duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
    Navigator.of(context).pop();
  }

  void _proximo() {
    if (_i + 1 >= _passos.length) {
      _fechar();
    } else {
      _irPara(_i + 1);
    }
  }

  void _voltar() {
    if (_i > 0) _irPara(_i - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (_passos.isEmpty) return const SizedBox.shrink();
    return Material(
      type: MaterialType.transparency,
      child: AnimatedBuilder(
        animation: Listenable.merge([_mover, _pulso]),
        builder: (context, _) {
          final alvo = _atual;
          final tela = MediaQuery.of(context).size;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _proximo,
                  child: CustomPaint(
                    painter: _Escuro(
                      alvo: alvo,
                      pulso: _pulso.value,
                      cor: GrutaCores.ouro,
                    ),
                  ),
                ),
              ),
              _cartao(alvo, tela),
            ],
          );
        },
      ),
    );
  }

  Widget _cartao(Rect? alvo, Size tela) {
    final largura = math.min(tela.width - 32, 380.0);
    final esquerda = (tela.width - largura) / 2;
    final ultimo = _i == _passos.length - 1;

    final conteudo = Container(
      width: largura,
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
      decoration: BoxDecoration(
        color: GrutaCores.rochaClara,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: GrutaCores.ouro.withValues(alpha: .45)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_passo.icone, color: GrutaCores.chama, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(_passo.titulo, style: GrutaTema.titulo(24))),
              Text(
                '${_i + 1} de ${_passos.length}',
                style: TextStyle(
                  color: GrutaCores.textoApagado,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(
              _passo.texto,
              style: TextStyle(
                color: GrutaCores.textoSuave,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!ultimo)
                TextButton(
                  onPressed: _fechar,
                  child: Text(
                    'Pular',
                    style: TextStyle(color: GrutaCores.textoApagado),
                  ),
                ),
              const Spacer(),
              if (_i > 0)
                IconButton(
                  tooltip: 'Voltar',
                  onPressed: _voltar,
                  icon: Icon(Icons.arrow_back, color: GrutaCores.textoSuave),
                ),
              const SizedBox(width: 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                ),
                onPressed: _proximo,
                child: Text(ultimo ? 'Acender minha vela' : 'Próximo'),
              ),
            ],
          ),
        ],
      ),
    );

    if (alvo == null) {
      return Positioned(
        left: esquerda,
        top: tela.height * .32,
        child: conteudo,
      );
    }
    const folga = 22.0;
    final embaixo = alvo.center.dy < tela.height / 2;
    return Positioned(
      left: esquerda,
      top: embaixo ? alvo.bottom + folga : null,
      bottom: embaixo ? null : tela.height - alvo.top + folga,
      child: conteudo,
    );
  }
}

/// Pinta a tela escura com um furo iluminado no alvo e um anel pulsando.
/// Alvos pequenos ganham um círculo; alvos grandes, um retângulo arredondado.
class _Escuro extends CustomPainter {
  _Escuro({required this.alvo, required this.pulso, required this.cor});
  final Rect? alvo;
  final double pulso;
  final Color cor;

  @override
  void paint(Canvas canvas, Size size) {
    final fundo = Path()..addRect(Offset.zero & size);
    final escuro = Paint()..color = Colors.black.withValues(alpha: .78);
    if (alvo == null) {
      canvas.drawPath(fundo, escuro);
      return;
    }
    final r = alvo!;
    final redondo = r.width < 120 && r.height < 120;
    final Path furo;
    final Path Function(double) anel;
    if (redondo) {
      final raio = math.max(r.width, r.height) / 2 + 8;
      furo = Path()..addOval(Rect.fromCircle(center: r.center, radius: raio));
      anel = (extra) =>
          Path()
            ..addOval(Rect.fromCircle(center: r.center, radius: raio + extra));
    } else {
      final caixa = r.inflate(6);
      furo = Path()
        ..addRRect(RRect.fromRectAndRadius(caixa, const Radius.circular(22)));
      anel = (extra) => Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            caixa.inflate(extra),
            Radius.circular(22 + extra),
          ),
        );
    }
    canvas.drawPath(
      Path.combine(PathOperation.difference, fundo, furo),
      escuro,
    );
    canvas.drawPath(
      furo,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = cor.withValues(alpha: .9),
    );
    canvas.drawPath(
      anel(4 + pulso * 14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = cor.withValues(alpha: (1 - pulso) * .6),
    );
  }

  @override
  bool shouldRepaint(_Escuro old) =>
      old.alvo != alvo || old.pulso != pulso || old.cor != cor;
}
