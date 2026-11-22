import 'package:material_ui/material_ui.dart';

import '../models/plano.dart';
import '../models/trilha.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';
import 'planos_sheet.dart';
import 'shell_screen.dart';

/// Pergunta se a pessoa quer gastar uma moeda nesta trilha (ou comprar).
/// Retorna true se a trilha ficou aberta.
Future<bool> pedirLiberacao(BuildContext context, Trilha t) async {
  final moedas = appState.moedas;
  final plano = appState.plano;
  final String explicacao;
  if (moedas > 0) {
    explicacao = moedas == 1
        ? 'Você tem 1 moeda. Use para abrir esta trilha?'
        : 'Você tem $moedas moedas. Use uma para abrir esta trilha?';
  } else if (plano == Plano.visitante) {
    explicacao = 'No plano Visitante as trilhas ficam fechadas. Com o plano '
        'Aprendiz, as aulas da Jornada dão moedas para abrir até 4 trilhas.';
  } else if (!appState.cabeMaisTrilha) {
    explicacao = 'Você já abriu as ${plano.limiteTrilhas} trilhas do plano '
        '${plano.nome}. O plano Mestre abre todas.';
  } else {
    final f = appState.faltamMoeda;
    explicacao = f == null
        ? 'Você já ganhou todas as moedas da Jornada.'
        : 'Faltam $f ${f == 1 ? 'aula' : 'aulas'} da Jornada para a sua '
            'próxima moeda.';
  }

  final escolha = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: GrutaCores.rocha,
      icon: Stack(alignment: Alignment.bottomRight, children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.cor.withValues(alpha: .14),
            border: Border.all(color: t.cor.withValues(alpha: .5)),
          ),
          child: Icon(t.iconData, color: t.cor, size: 36),
        ),
        CircleAvatar(
          radius: 15,
          backgroundColor: GrutaCores.rochaClara,
          child: Icon(Icons.lock, size: 16, color: GrutaCores.ouro),
        ),
      ]),
      title: Text(t.titulo,
          textAlign: TextAlign.center, style: GrutaTema.titulo(30)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(t.subtitulo,
            textAlign: TextAlign.center,
            style: TextStyle(color: t.cor, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(explicacao,
            textAlign: TextAlign.center,
            style: TextStyle(color: GrutaCores.textoSuave, height: 1.45)),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowDirection: VerticalDirection.down,
      actionsOverflowButtonSpacing: 8,
      actions: [
        if (moedas > 0)
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, 'moeda'),
            icon: const Moeda(tamanho: 20),
            label: const Text('Usar 1 moeda'),
          )
        else if (plano == Plano.visitante || !appState.cabeMaisTrilha)
          FilledButton(
            onPressed: () => Navigator.pop(context, 'planos'),
            child: const Text('Ver planos'),
          ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, 'comprar'),
          icon: const Icon(Icons.shopping_bag_outlined),
          label: const Text('Comprar esta trilha'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Agora não'),
        ),
      ],
    ),
  );
  if (!context.mounted) return false;
  switch (escolha) {
    case 'moeda':
      final erro = await appState.gastarMoeda(t.id);
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(erro ?? 'Trilha ${t.titulo} aberta. Bons estudos!')));
      return erro == null;
    case 'planos':
      await mostrarPlanos(context);
    case 'comprar':
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A compra avulsa de trilhas chega em breve.')));
  }
  return false;
}

/// Pop-up de quando uma aula da Jornada dá moeda.
Future<void> mostrarMoedaGanha(BuildContext context) async {
  final ir = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: GrutaCores.rocha,
      icon: const Moeda(tamanho: 84),
      title: Text('Você desbloqueou uma trilha de conhecimento nova!',
          textAlign: TextAlign.center, style: GrutaTema.titulo(28)),
      content: Text(
        appState.moedas > 0
            ? 'Ganhou uma moeda. Escolha qual trilha você quer abrir.'
            : 'Ganhou uma moeda pela Jornada. Para usar, seu plano precisa '
                'ter espaço para mais trilhas.',
        textAlign: TextAlign.center,
        style: TextStyle(color: GrutaCores.textoSuave, height: 1.45),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(appState.moedas > 0 ? 'Escolher trilha' : 'Ver trilhas'),
        ),
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Depois')),
      ],
    ),
  );
  if (ir == true && context.mounted) {
    ShellScreen.aba.value = 1;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}
