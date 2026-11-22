import 'package:material_ui/material_ui.dart';

import '../config/app_config.dart';
import '../models/aula.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/fundo_gruta.dart';
import '../widgets/pecas.dart';
import '../widgets/vela.dart';
import 'liberar_trilha.dart';

/// Comemoração depois da aula: a vela acende, o número sobe e há um espaço
/// para anotar a reflexão no Grimório.
class ConclusaoScreen extends StatefulWidget {
  const ConclusaoScreen(
      {super.key, required this.aula, required this.resultado});
  final Aula aula;
  final ResultadoConclusao resultado;

  @override
  State<ConclusaoScreen> createState() => _ConclusaoScreenState();
}

class _ConclusaoScreenState extends State<ConclusaoScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrada = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();
  final _nota = TextEditingController();
  bool _acesa = false;

  @override
  void initState() {
    super.initState();
    // A vela começa apagada e acende logo depois (efeito de "acender").
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _acesa = true);
    });
    // Aula-marco da Jornada: pop-up da trilha nova, depois da vela acender.
    if (widget.resultado.ganhouMoeda) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) mostrarMoedaGanha(context);
      });
    }
  }

  @override
  void dispose() {
    _entrada.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _sair() async {
    final texto = _nota.text.trim();
    if (texto.isNotEmpty) {
      await appState.anotar(texto, aula: widget.aula);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final dias = r.depois.atual;
    final titulo = r.acendeuHoje
        ? (dias == 1 ? 'Primeira vela acesa!' : '$dias dias acesos!')
        : 'Mais uma aula na estante';
    final sub = r.acendeuHoje
        ? 'Volte amanhã para a próxima aula e mantenha a chama.'
        : 'Sua vela de hoje já estava acesa. Saber nunca é demais.';

    return Scaffold(
      body: FundoGruta(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              Center(
                child: ScaleTransition(
                  scale: CurvedAnimation(
                      parent: _entrada, curve: Curves.elasticOut),
                  child: Vela(acesa: _acesa, tamanho: 170),
                ),
              ),
              const SizedBox(height: 24),
              Text(titulo,
                  textAlign: TextAlign.center,
                  style: GrutaTema.titulo(40, cor: GrutaCores.chama)),
              const SizedBox(height: 10),
              Text(sub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: GrutaCores.textoSuave, height: 1.5)),
              if (r.ganhouMoeda) ...[
                const SizedBox(height: 18),
                CartaoPedra(
                  brilho: GrutaCores.ouro,
                  child: Row(children: [
                    const Moeda(tamanho: 34),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Você ganhou uma moeda! Use na aba Trilhas para '
                        'abrir uma trilha de conhecimento nova.',
                        style: TextStyle(height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ],
              if (r.ganhouAmuleto) ...[
                const SizedBox(height: 18),
                CartaoPedra(
                  brilho: GrutaCores.ouro,
                  child: Row(children: [
                    Icon(Icons.shield_moon_outlined,
                        color: GrutaCores.ouro, size: 30),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Você ganhou um amuleto! Ele protege sua ofensiva '
                        'se um dia você não conseguir assistir '
                        '(a cada ${AppConfig.diasPorAmuleto} dias seguidos).',
                        style: const TextStyle(height: 1.4),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              const Olho('Para o seu Grimório'),
              const SizedBox(height: 8),
              Text(widget.aula.reflexao ?? 'O que você quer guardar desta aula?',
                  style: GrutaTema.titulo(24)),
              const SizedBox(height: 12),
              TextField(
                controller: _nota,
                minLines: 3,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    hintText: 'Escreva aqui (opcional)'),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: _sair,
                child: const Text('Continuar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
