import 'package:flutter/material.dart';

import '../models/comanda.dart';
import '../state/app_state.dart';

const Map<String, String> _formas = {
  'PIX': 'Pix',
  'CARTAO': 'Cartão',
  'DINHEIRO': 'Dinheiro',
};

class _Pessoa {
  _Pessoa(this.ctrl);
  final TextEditingController ctrl;
  String? forma;
  bool pago = false;
  double get valor => double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
}

/// Página de fechamento: valor, forma de pagamento e divisão entre pessoas.
/// Só fecha quando a soma das partes é igual ao valor da comanda.
class FechamentoComandaScreen extends StatefulWidget {
  const FechamentoComandaScreen({super.key, required this.comandaId});

  final String comandaId;

  @override
  State<FechamentoComandaScreen> createState() => _FechamentoComandaScreenState();
}

class _FechamentoComandaScreenState extends State<FechamentoComandaScreen> {
  late final TextEditingController _totalCtrl;
  late final double _totalItens;
  String? _forma;
  bool _dividir = false;
  bool _fechando = false;
  final List<_Pessoa> _pessoas = [];

  @override
  void initState() {
    super.initState();
    _totalItens = appState.comandaPorId(widget.comandaId)?.total ?? 0;
    _totalCtrl = TextEditingController(text: _totalItens.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _totalCtrl.dispose();
    for (final p in _pessoas) {
      p.ctrl.dispose();
    }
    super.dispose();
  }

  double get _total => double.tryParse(_totalCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _soma => _pessoas.fold(0.0, (s, p) => s + p.valor);
  bool get _somaOk => (_soma - _total).abs() < 0.005;

  /// Divide igualmente (centavos que sobram vão para a última pessoa).
  void _redistribuir() {
    final n = _pessoas.length;
    if (n == 0) return;
    final cents = (_total * 100).round();
    final base = cents ~/ n;
    for (var i = 0; i < n; i++) {
      final c = i == n - 1 ? cents - base * (n - 1) : base;
      _pessoas[i].ctrl.text = (c / 100).toStringAsFixed(2);
    }
  }

  void _ligarDivisao(bool v) {
    setState(() {
      _dividir = v;
      if (v && _pessoas.isEmpty) {
        _pessoas.add(_Pessoa(TextEditingController()));
        _pessoas.add(_Pessoa(TextEditingController()));
        _redistribuir();
      }
    });
  }

  void _adicionar() {
    setState(() {
      _pessoas.add(_Pessoa(TextEditingController()));
      _redistribuir();
    });
  }

  void _remover(int i) {
    if (_pessoas.length <= 2) return;
    setState(() {
      _pessoas.removeAt(i).ctrl.dispose();
      _redistribuir();
    });
  }

  bool get _podeFechar {
    if (_total <= 0 || _fechando) return false;
    if (!_dividir) return _forma != null;
    return _somaOk &&
        _pessoas.every((p) => p.forma != null && p.valor > 0 && p.pago);
  }

  String get _dica {
    if (_total <= 0) return 'Informe o valor a cobrar.';
    if (!_dividir) return _forma == null ? 'Escolha a forma de pagamento.' : '';
    if (!_somaOk) return 'A soma das partes precisa ser igual ao total.';
    if (_pessoas.any((p) => p.forma == null)) return 'Escolha a forma de pagamento de cada pessoa.';
    if (!_pessoas.every((p) => p.pago)) return 'Marque cada pessoa como paga para fechar.';
    return '';
  }

  Future<void> _fechar() async {
    setState(() => _fechando = true);
    List<PagamentoParte>? partes;
    String principal;
    if (_dividir) {
      partes = [
        for (final p in _pessoas)
          PagamentoParte(forma: p.forma!, valor: p.valor, pago: p.pago),
      ];
      final soma = <String, double>{};
      for (final p in partes) {
        soma[p.forma] = (soma[p.forma] ?? 0) + p.valor;
      }
      principal = (soma.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .first
          .key;
    } else {
      principal = _forma!;
    }
    final ok = await appState.fecharComanda(
      widget.comandaId,
      principal,
      valorCobrado: _total,
      partes: partes,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _fechando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.ultimoErro ?? 'Erro ao fechar')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final erro = Theme.of(context).colorScheme.error;
    return Scaffold(
      appBar: AppBar(title: const Text('Fechar comanda')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dica.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(_dica, style: TextStyle(color: erro)),
                ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _podeFechar ? _fechar : null,
                child: Text(_fechando ? 'Fechando...' : 'Fechar comanda'),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Total dos itens: R\$ ${_totalItens.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _totalCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Valor a cobrar',
              hintText: 'Pode alterar se necessário',
              border: OutlineInputBorder(),
              prefixText: 'R\$ ',
            ),
            onChanged: (_) => setState(() {
              if (_dividir) _redistribuir();
            }),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Dividir comanda'),
            subtitle: const Text('Cada pessoa paga uma parte'),
            value: _dividir,
            onChanged: (v) => _ligarDivisao(v ?? false),
          ),
          const SizedBox(height: 8),
          if (!_dividir) ...[
            Text('Forma de pagamento', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final e in _formas.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _forma == e.key,
                    onSelected: (_) => setState(() => _forma = e.key),
                  ),
              ],
            ),
          ] else ...[
            Text('Pessoas', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            for (var i = 0; i < _pessoas.length; i++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  child: Row(
                    children: [
                      Text('${i + 1}'),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _pessoas[i].ctrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            prefixText: 'R\$ ',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: DropdownButton<String>(
                          isExpanded: true,
                          hint: const Text('Forma'),
                          value: _pessoas[i].forma,
                          items: [
                            for (final e in _formas.entries)
                              DropdownMenuItem(value: e.key, child: Text(e.value)),
                          ],
                          onChanged: (v) => setState(() => _pessoas[i].forma = v),
                        ),
                      ),
                      Tooltip(
                        message: 'Pago',
                        child: Checkbox(
                          value: _pessoas[i].pago,
                          onChanged: (v) => setState(() => _pessoas[i].pago = v ?? false),
                        ),
                      ),
                      if (_pessoas.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          tooltip: 'Tirar pessoa',
                          onPressed: () => _remover(i),
                        ),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _adicionar,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar pessoa (divide igualmente)'),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Soma das partes: R\$ ${_soma.toStringAsFixed(2)} de R\$ ${_total.toStringAsFixed(2)}'
              '${_somaOk ? '' : (_soma < _total ? ' — faltam R\$ ${(_total - _soma).toStringAsFixed(2)}' : ' — passou R\$ ${(_soma - _total).toStringAsFixed(2)}')}',
              style: TextStyle(color: _somaOk ? null : erro),
            ),
          ],
        ],
      ),
    );
  }
}
