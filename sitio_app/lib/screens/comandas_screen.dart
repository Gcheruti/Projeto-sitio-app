import 'package:flutter/material.dart';
import '../widgets/borda_papel.dart' show papelCom;
import '../state/app_state.dart';
import '../state/permissoes_state.dart';
import 'detalhe_comanda_screen.dart';

class ComandasScreen extends StatefulWidget {
  const ComandasScreen({super.key});

  @override
  State<ComandasScreen> createState() => _ComandasScreenState();
}

class _ComandasScreenState extends State<ComandasScreen> {
  String _statusFiltro = 'Ativas';
  String _textoFiltro = '';

  void _dialogNovaComanda() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Nova comanda'),
          content: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Código',
              hintText: 'Ex: SITIO:010',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await appState.criarComanda(ctrl.text);
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      ok ? 'Comanda criada' : (appState.ultimoErro ?? 'Erro'),
                    ),
                  ),
                );
              },
              child: const Text('Criar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, permissoes]),
      builder: (context, _) {
        final lista = appState.comandas.where((c) {
          final okStatus = _statusFiltro == 'Todas' ||
              (_statusFiltro == 'Ativas' && c.isAtiva) ||
              (_statusFiltro == 'Inativas' && !c.isAtiva);
          final okTexto = _textoFiltro.isEmpty ||
              c.codigo.toLowerCase().contains(_textoFiltro.toLowerCase());
          return okStatus && okTexto;
        }).toList();

        return Scaffold(
          appBar: AppBar(title: const Text('Comandas')),
          floatingActionButton: permissoes.pode('comanda_criar')
              ? FloatingActionButton(
                  onPressed: _dialogNovaComanda,
                  child: const Icon(Icons.add),
                )
              : null,
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Todas', 'Ativas', 'Inativas'].map((s) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(s),
                              selected: _statusFiltro == s,
                              onSelected: (_) =>
                                  setState(() => _statusFiltro = s),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filtrar por código',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _textoFiltro = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: lista.isEmpty
                    ? const Center(child: Text('Nenhuma comanda encontrada'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: lista.length,
                        itemBuilder: (context, i) {
                          final c = lista[i];
                          return Card(
                            shape: papelCom(context, c.id),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(c.codigo),
                              subtitle: Text(c.resumoItens),
                              trailing: Chip(
                                label: Text(
                                  c.status.toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                ),
                                visualDensity: VisualDensity.compact,
                              ),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => DetalheComandaScreen(
                                      comandaId: c.id,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}