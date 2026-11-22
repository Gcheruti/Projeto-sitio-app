import 'package:material_ui/material_ui.dart';

import '../models/plano.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';

/// Os três planos. O pagamento de verdade ainda não existe: com o modo de
/// teste ligado no banco, escolher o Aprendiz já libera (ver docs/NEGOCIO.md).
Future<void> mostrarPlanos(BuildContext context) => abrirFolha(
      context,
      (context) => ListenableBuilder(
        listenable: appState,
        builder: (context, _) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const Puxador(),
            const SizedBox(height: 20),
            const Olho('Planos'),
            const SizedBox(height: 6),
            Text('Escolha seu caminho', style: GrutaTema.titulo(32)),
            const SizedBox(height: 16),
            for (final p in Plano.values) ...[
              CartaoPlano(
                plano: p,
                atual: appState.plano == p,
                onEscolher: p.disponivel && appState.plano != p
                    ? () async {
                        final erro = await appState.escolherPlano(p);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                erro ?? 'Agora você é ${p.nome}!')));
                        if (erro == null) Navigator.pop(context);
                      }
                    : null,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Assinaturas pelo celular passam pela loja (Google Play ou '
              'App Store) e podem ser canceladas a qualquer momento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: GrutaCores.textoApagado, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );

/// Cartão de um plano (usado nos Planos e no cadastro).
class CartaoPlano extends StatelessWidget {
  const CartaoPlano({
    super.key,
    required this.plano,
    this.atual = false,
    this.selecionado = false,
    this.onEscolher,
  });

  final Plano plano;
  final bool atual;
  final bool selecionado;
  final VoidCallback? onEscolher;

  static const _itens = {
    Plano.visitante: [
      'Aula piloto + 2 aulas da Jornada',
      'Vela diária e Grimório',
    ],
    Plano.aprendiz: [
      'Jornada completa: 60 aulas, uma por dia',
      'Moedas para liberar até 4 das 8 trilhas',
      'Vela diária, amuletos e Grimório',
    ],
    Plano.mestre: [
      'Tudo do Aprendiz',
      'Todas as 8 trilhas abertas, sem moedas',
      'Lives com a equipe',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final cor = switch (plano) {
      Plano.visitante => GrutaCores.arenito,
      Plano.aprendiz => GrutaCores.chama,
      Plano.mestre => GrutaCores.ouro,
    };
    final destaque = atual || selecionado;
    return Opacity(
      opacity: plano.disponivel ? 1 : .6,
      child: CartaoPedra(
        brilho: destaque ? cor : null,
        onTap: onEscolher,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(
                switch (plano) {
                  Plano.visitante => Icons.explore_outlined,
                  Plano.aprendiz => Icons.local_fire_department,
                  Plano.mestre => Icons.auto_awesome,
                },
                color: cor),
            const SizedBox(width: 10),
            Expanded(child: Text(plano.nome, style: GrutaTema.titulo(26))),
            if (atual)
              _Etiqueta('Seu plano', cor)
            else if (!plano.disponivel)
              _Etiqueta('Em desenvolvimento', GrutaCores.textoApagado)
            else if (selecionado)
              Icon(Icons.check_circle, color: cor),
          ]),
          const SizedBox(height: 2),
          Text(plano.preco,
              style: TextStyle(
                  color: cor, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          for (final item in _itens[plano]!)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.check, size: 16, color: cor),
                ),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(item,
                        style: TextStyle(
                            color: GrutaCores.textoSuave, height: 1.35))),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto, this.cor);
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: cor.withValues(alpha: .6)),
        ),
        child: Text(texto,
            style: TextStyle(
                color: cor, fontSize: 11.5, fontWeight: FontWeight.w800)),
      );
}
