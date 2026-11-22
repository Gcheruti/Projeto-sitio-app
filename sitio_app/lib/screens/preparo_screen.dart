import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../state/app_state.dart';

/// Registro de preparo: quantas unidades foram feitas e o que foi usado.
class PreparoScreen extends StatefulWidget {
  const PreparoScreen({super.key, required this.produto});
  final Produto produto;

  @override
  State<PreparoScreen> createState() => _PreparoState();
}

class _Linha {
  String? produtoId;
  final TextEditingController qtd = TextEditingController(text: '1');
}

class _PreparoState extends State<PreparoScreen> {
  final _qtd = TextEditingController(text: '1');
  final List<_Linha> _linhas = [];
  bool _salvando = false;

  List<Produto> get _insumos => appState.produtos
      .where((p) => p.controlaEstoque && p.id != widget.produto.id)
      .toList()
    ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));

  Future<void> _salvar() async {
    final q = int.tryParse(_qtd.text.trim()) ?? 0;
    final usos = <String, int>{};
    for (final l in _linhas) {
      final id = l.produtoId;
      final n = int.tryParse(l.qtd.text.trim()) ?? 0;
      if (id == null || n <= 0) continue;
      usos[id] = (usos[id] ?? 0) + n;
    }
    setState(() => _salvando = true);
    final ok = await appState.registrarPreparo(
      produtoId: widget.produto.id,
      quantidade: q,
      ingredientes: usos,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? 'Preparo registrado: +$q ${widget.produto.nome}'
          : (appState.ultimoErro ?? 'Erro ao registrar')),
    ));
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final insumos = _insumos;
    return Scaffold(
      appBar: AppBar(title: Text('Preparo • ${widget.produto.nome}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _qtd,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Quantas unidades foram preparadas?',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          Text('Ingredientes usados (saem do estoque)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final l in _linhas)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: l.produtoId,
                      decoration: const InputDecoration(
                          labelText: 'Ingrediente',
                          border: OutlineInputBorder()),
                      items: [
                        for (final p in insumos)
                          DropdownMenuItem(
                            value: p.id,
                            child: Text('${p.nome} (${p.quantidade})',
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => setState(() => l.produtoId = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: l.qtd,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Qtd', border: OutlineInputBorder()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remover',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _linhas.remove(l)),
                  ),
                ],
              ),
            ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _linhas.add(_Linha())),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar ingrediente'),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: const Icon(Icons.local_fire_department_outlined),
            label: Text(_salvando ? 'Salvando...' : 'Registrar preparo'),
          ),
        ],
      ),
    );
  }
}
