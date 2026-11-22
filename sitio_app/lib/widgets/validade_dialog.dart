import 'package:flutter/material.dart';
import '../models/lote.dart';
import '../models/reposicao_linha.dart';

/// Pergunta a validade do lote de cada item que está entrando na reposição.
/// Devolve true ao continuar (validades ficam em [LinhaRepos.validade]).
Future<bool> pedirValidades(BuildContext context, List<LinhaRepos> linhas) async {
  final itens = linhas
      .where((l) => !l.pendente && l.qtdEntrada > 0 && l.produtoId != null)
      .toList();
  if (itens.isEmpty) return true;
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setLocal) => AlertDialog(
        title: const Text('Validade dos lotes'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final l in itens)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${l.nome} (+${l.qtdEntrada})'),
                  subtitle: Text(l.validade == null
                      ? 'Sem validade'
                      : 'Vence em ${formatarData(l.validade!)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (l.validade != null)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setLocal(() => l.validade = null),
                      ),
                    IconButton(
                      icon: const Icon(Icons.event),
                      onPressed: () async {
                        final hoje = DateTime.now();
                        final d = await showDatePicker(
                          context: ctx,
                          initialDate: l.validade ?? hoje.add(const Duration(days: 30)),
                          firstDate: DateTime(hoje.year - 1),
                          lastDate: DateTime(hoje.year + 10),
                        );
                        if (d != null) {
                          setLocal(() => l.validade = DateTime(d.year, d.month, d.day));
                        }
                      },
                    ),
                  ]),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ),
  );
  return r == true;
}
