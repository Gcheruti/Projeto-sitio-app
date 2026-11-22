import 'package:material_ui/material_ui.dart';

import '../logic/datas.dart';
import '../models/progresso.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';

/// Aba Grimório: o caderno pessoal com as anotações das aulas.
class GrimorioScreen extends StatelessWidget {
  const GrimorioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final notas = appState.notas;
        return SafeArea(
          bottom: false,
          child: Stack(children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                  GrutaMedidas.margem, 20, GrutaMedidas.margem, 110),
              children: [
                const Olho('Seu caderno'),
                const SizedBox(height: 6),
                Text('Grimório', style: GrutaTema.titulo(40)),
                const SizedBox(height: 6),
                Text(
                    'O que você aprendeu, com suas palavras. Só você vê.',
                    style: TextStyle(color: GrutaCores.textoSuave)),
                const SizedBox(height: 22),
                if (notas.isEmpty)
                  CartaoPedra(
                    child: Column(children: [
                      Icon(Icons.edit_note,
                          size: 44, color: GrutaCores.textoApagado),
                      SizedBox(height: 10),
                      Text(
                        'Ainda em branco. Depois de cada aula você pode '
                        'anotar o que ficou.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: GrutaCores.textoSuave, height: 1.5),
                      ),
                    ]),
                  )
                else
                  for (final n in notas) ...[
                    _CartaoNota(nota: n),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: FloatingActionButton.extended(
                backgroundColor: GrutaCores.chama,
                foregroundColor: GrutaCores.noite,
                onPressed: () => _novaNota(context),
                icon: const Icon(Icons.edit),
                label: const Text('Anotar',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ]),
        );
      },
    );
  }

  Future<void> _novaNota(BuildContext context) async {
    final c = TextEditingController();
    final texto = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GrutaCores.rocha,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 22, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Nova anotação', style: GrutaTema.titulo(28)),
          const SizedBox(height: 14),
          TextField(
            controller: c,
            autofocus: true,
            minLines: 4,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Escreva aqui'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(c.text.trim()),
            child: const Text('Guardar'),
          ),
        ]),
      ),
    );
    c.dispose();
    if (texto != null && texto.isNotEmpty) await appState.anotar(texto);
  }
}

class _CartaoNota extends StatelessWidget {
  const _CartaoNota({required this.nota});
  final NotaGrimorio nota;

  String? get _titulo =>
      nota.aulaTitulo ??
      (nota.aulaId == null ? null : appState.aulaPorId(nota.aulaId!)?.titulo);

  @override
  Widget build(BuildContext context) {
    return CartaoPedra(
      onTap: () {},
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Olho(
              _titulo == null
                  ? dataCurta(nota.criadaEm)
                  : '${dataCurta(nota.criadaEm)} · $_titulo',
              cor: GrutaCores.arenito,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.delete_outline,
                size: 20, color: GrutaCores.textoApagado),
            tooltip: 'Apagar',
            onPressed: () => _apagar(context),
          ),
        ]),
        const SizedBox(height: 4),
        Text(nota.texto,
            style: GrutaTema.titulo(21, peso: FontWeight.w500)
                .copyWith(height: 1.35)),
      ]),
    );
  }

  Future<void> _apagar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GrutaCores.rocha,
        title: const Text('Apagar anotação?'),
        content: const Text('Não dá para desfazer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Apagar')),
        ],
      ),
    );
    if (ok == true) await appState.apagarNota(nota.id);
  }
}
