import 'package:flutter/material.dart';

import '../models/agenda_visual.dart';
import '../services/agenda_config_repository.dart';

class ItemConfigAgenda {
  const ItemConfigAgenda(this.chave, this.nome);
  final String chave;
  final String nome;
}

/// Pop-up de configurações da agenda: escolher cor e ícone de cada tipo.
Future<void> abrirConfigAgenda(
  BuildContext context, {
  required String titulo,
  required String escopo,
  required List<ItemConfigAgenda> itens,
  required AgendaVisualResolver resolver,
  String vazio = 'Nenhum item para configurar.',
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ConfigDialog(
      titulo: titulo,
      escopo: escopo,
      itens: itens,
      resolver: resolver,
      vazio: vazio,
    ),
  );
}

class _ConfigDialog extends StatefulWidget {
  const _ConfigDialog({
    required this.titulo,
    required this.escopo,
    required this.itens,
    required this.resolver,
    required this.vazio,
  });
  final String titulo;
  final String escopo;
  final List<ItemConfigAgenda> itens;
  final AgendaVisualResolver resolver;
  final String vazio;

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
  final _repo = AgendaConfigRepository();

  Future<void> _editar(ItemConfigAgenda item) async {
    final atual = widget.resolver.de(item.chave);
    var cor = atual.corChave;
    var icone = atual.iconeChave;
    var salvando = false;
    final icones = widget.resolver.icones;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final scheme = Theme.of(ctx).colorScheme;
          final corAtual = kCoresAgenda[cor]!;
          return AlertDialog(
            title: Text(item.nome),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cor', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in kCoresAgenda.entries)
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => setD(() => cor = e.key),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: e.value,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cor == e.key
                                    ? scheme.onSurface
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: cor == e.key
                                ? const Icon(Icons.check,
                                    size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Ícone', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 280,
                    height: 200,
                    child: GridView.count(
                      crossAxisCount: 6,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        for (final e in icones.entries)
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setD(() => icone = e.key),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: icone == e.key
                                    ? corAtual.withValues(alpha: 0.2)
                                    : null,
                                border: Border.all(
                                  color: icone == e.key
                                      ? corAtual
                                      : scheme.outlineVariant,
                                ),
                              ),
                              child: Icon(e.value,
                                  size: 22,
                                  color: icone == e.key
                                      ? corAtual
                                      : scheme.onSurface),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: salvando ? null : () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: salvando
                    ? null
                    : () async {
                        setD(() => salvando = true);
                        final v = VisualAgenda(cor, icone);
                        try {
                          await _repo.salvar(widget.escopo, item.chave, v);
                          widget.resolver.config[item.chave] = v;
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (_) {
                          setD(() => salvando = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text(
                                  'Não foi possível salvar (rode supabase/agenda_config.sql).'),
                            ));
                          }
                        }
                      },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resolver;
    return AlertDialog(
      title: Text(widget.titulo),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.itens.isEmpty
            ? Text(widget.vazio)
            : ListView(
                shrinkWrap: true,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Toque num item para escolher a cor e o ícone.'),
                  ),
                  for (final item in widget.itens)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: r.cor(item.chave).withValues(alpha: 0.2),
                        child: Icon(r.icone(item.chave), color: r.cor(item.chave)),
                      ),
                      title: Text(item.nome),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => _editar(item),
                    ),
                ],
              ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}
