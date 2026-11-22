import 'package:material_ui/material_ui.dart';

import '../models/trilha.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';
import 'liberar_trilha.dart';
import 'trilha_screen.dart';

/// Aba Trilhas: a estante com os 8 temas, todos com cadeado até serem
/// liberados com moedas (ou abertos pelo plano Mestre).
class TrilhasScreen extends StatelessWidget {
  const TrilhasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final faltam = appState.faltamMoeda;
        return SafeArea(
          bottom: false,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  GrutaMedidas.margem, 20, GrutaMedidas.margem, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Expanded(child: Olho('A estante')),
                      ContadorMoedas(quantidade: appState.moedas),
                      const ReservaTopo(),
                    ]),
                    const SizedBox(height: 4),
                    Text('Trilhas', style: GrutaTema.titulo(40)),
                    const SizedBox(height: 6),
                    Text(
                        appState.plano.todasAsTrilhas
                            ? 'No plano Mestre todas as trilhas estão '
                                'abertas. Uma aula nova por dia em cada uma.'
                            : 'Faça suas aulas diárias da Jornada para ganhar '
                                'moedas e ir liberando trilhas. Cada moeda '
                                'abre a trilha que você escolher.',
                        style: TextStyle(
                            color: GrutaCores.textoSuave, height: 1.45)),
                    if (!appState.plano.todasAsTrilhas && faltam != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Moeda(tamanho: 18, apagada: true),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Próxima moeda em $faltam '
                            '${faltam == 1 ? 'aula' : 'aulas'} da Jornada',
                            style: TextStyle(
                                color: GrutaCores.ouro,
                                fontWeight: FontWeight.w700,
                                fontSize: 13),
                          ),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  GrutaMedidas.margem, 0, GrutaMedidas.margem, 32),
              sliver: SliverList.separated(
                itemCount: appState.trilhas.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) =>
                    _CartaoTrilha(trilha: appState.trilhas[i]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class _CartaoTrilha extends StatelessWidget {
  const _CartaoTrilha({required this.trilha});
  final Trilha trilha;

  @override
  Widget build(BuildContext context) {
    final t = trilha;
    final aberta = appState.trilhaLiberada(t.id);
    final feitas = appState.concluidasNa(t.id);
    final total = appState.aulasDa(t.id).length;
    final cor = aberta ? t.cor : GrutaCores.textoApagado;
    return CartaoPedra(
      brilho: aberta ? t.cor : null,
      onTap: () async {
        if (!aberta && !await pedirLiberacao(context, t)) return;
        if (!context.mounted) return;
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => TrilhaScreen(trilhaId: t.id)));
      },
      child: Row(children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.cor.withValues(alpha: aberta ? .14 : .06),
            border: Border.all(color: cor.withValues(alpha: .5)),
          ),
          child: Icon(t.iconData,
              color: aberta ? t.cor : t.cor.withValues(alpha: .45), size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.titulo,
                  style: GrutaTema.titulo(25,
                      cor: aberta ? null : GrutaCores.textoSuave)),
              const SizedBox(height: 2),
              Text(t.subtitulo,
                  style: TextStyle(
                      color: GrutaCores.textoSuave, fontSize: 13.5)),
              const SizedBox(height: 10),
              if (aberta)
                Row(children: [
                  Expanded(
                      child: BarraProgresso(
                          valor: total == 0 ? 0 : feitas / total, cor: t.cor)),
                  const SizedBox(width: 10),
                  Text('$feitas/$total',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: GrutaCores.textoSuave)),
                ])
              else
                Text('$total aulas · toque para liberar',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: GrutaCores.ouro)),
            ],
          ),
        ),
        const SizedBox(width: 6),
        aberta
            ? Icon(Icons.chevron_right, color: GrutaCores.textoApagado)
            : Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GrutaCores.noite.withValues(alpha: .5),
                  border: Border.all(color: GrutaCores.ouro.withValues(alpha: .5)),
                ),
                child: Icon(Icons.lock_outline,
                    size: 18, color: GrutaCores.ouro),
              ),
      ]),
    );
  }
}
