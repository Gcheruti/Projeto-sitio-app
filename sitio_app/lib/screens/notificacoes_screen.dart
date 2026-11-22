import 'package:flutter/material.dart';
import '../widgets/borda_papel.dart' show papelCom;
import '../models/notificacao.dart';
import '../services/auditoria.dart';
import '../state/auth_state.dart';
import '../state/permissoes_state.dart';
import 'notificacao_detalhe_screen.dart';

class NotificacoesScreen extends StatefulWidget {
  const NotificacoesScreen({
    super.key,
    required this.notificacoes,
    required this.onChanged,
  });

  final List<Notificacao> notificacoes;
  final VoidCallback onChanged;

  @override
  State<NotificacoesScreen> createState() => _NotificacoesScreenState();
}

class _NotificacoesScreenState extends State<NotificacoesScreen> {
  /// 0 = Ativas, 1 = Inativas
  int _filtro = 0;

  /// Filtro por local: 'todos', 'geral' (sem local) ou uma chave de [kLocais].
  String _local = 'todos';

  List<Notificacao> get _filtradas {
    final querAtiva = _filtro == 0;
    return widget.notificacoes
        .where((n) => !n.excluida && n.ativa == querAtiva)
        .where((n) => switch (_local) {
              'todos' => true,
              'geral' => n.local == null,
              _ => n.local == _local,
            })
        .toList();
  }

  void _criar() {
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? local;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setD) => AlertDialog(
          title: const Text('Nova notificação'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: tituloCtrl,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                value: local,
                decoration: const InputDecoration(
                  labelText: 'Local',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Geral')),
                  ...kLocais.entries.map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ),
                ],
                onChanged: (v) => setD(() => local = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final t = tituloCtrl.text.trim();
                if (t.isEmpty) return;
                setState(() {
                  widget.notificacoes.insert(
                    0,
                    Notificacao(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      titulo: t,
                      descricao: descCtrl.text.trim(),
                      local: local,
                      criadoPor: authState.usuario?.nome,
                      editadoPor: authState.usuario?.nome,
                    ),
                  );
                });
                Auditoria.registrar('notificacao_criada', 'Criou "$t"',
                    entidade: 'notificacao');
                widget.onChanged();
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtradas;
    // Quem não tem a permissão "notif_editar" só lê os avisos.
    final somenteLeitura = !permissoes.pode('notif_editar');

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      floatingActionButton: somenteLeitura
          ? null
          : FloatingActionButton(
              onPressed: _criar,
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Ativas')),
                ButtonSegment(value: 1, label: Text('Inativas')),
              ],
              selected: {_filtro},
              onSelectionChanged: (s) => setState(() => _filtro = s.first),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final e in <String, String>{
                  'todos': 'Todos',
                  'geral': 'Geral',
                  ...kLocais,
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _local == e.key,
                      onSelected: (_) => setState(() => _local = e.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: lista.isEmpty
                ? const Center(child: Text('Nenhuma notificação nesta lista'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: lista.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final n = lista[i];
                      return Card(
                        shape: papelCom(context, n.id),
                        child: ListTile(
                          title: Text(n.titulo),
                          subtitle: Text(
                            '${n.localNome == null ? '' : '${n.localNome} • '}${n.descricao}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            if (somenteLeitura) {
                              await showDialog<void>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(n.titulo),
                                  content: Text(
                                      '${n.localNome == null ? '' : '${n.localNome}\n\n'}${n.descricao}'),
                                  actions: [
                                    TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Fechar')),
                                  ],
                                ),
                              );
                              return;
                            }
                            await Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => NotificacaoDetalheScreen(
                                notificacao: n,
                                onChanged: widget.onChanged,
                              ),
                            ));
                            if (mounted) setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}