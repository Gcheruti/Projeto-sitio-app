import 'package:flutter/material.dart';
import '../state/auth_state.dart';
import '../state/app_state.dart';

class BaixaEstoqueScreen extends StatefulWidget {
  const BaixaEstoqueScreen({super.key});

  @override
  State<BaixaEstoqueScreen> createState() => _BaixaEstoqueScreenState();
}

class _BaixaEstoqueScreenState extends State<BaixaEstoqueScreen> {
  String? _produtoId;
  final _qtdCtrl = TextEditingController(text: '1');
  String _motivo = 'Validade';

  static const _motivos = [
    'Validade',
    'Perda',
    'Consumo interno',
    'Outro',
  ];

  @override
  void dispose() {
    _qtdCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (_produtoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escolha o produto')),
      );
      return;
    }
    final qtd = int.tryParse(_qtdCtrl.text) ?? 0;
    if (qtd <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantidade inválida')),
      );
      return;
    }

    final senhaCtrl = TextEditingController();
    var erro = false;
    final okSenha = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Senha'),
              content: TextField(
                controller: senhaCtrl,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Sua senha (do login atual)',
                  border: const OutlineInputBorder(),
                  errorText: erro ? 'Senha incorreta' : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!await authState.senhaConfere(senhaCtrl.text)) {
                      setLocal(() => erro = true);
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
    if (okSenha != true || !mounted) return;

    final ok = await appState.baixaManual(
      produtoId: _produtoId!,
      quantidade: qtd,
      motivo: _motivo,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Baixa registrada' : (appState.ultimoErro ?? 'Erro'),
        ),
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Baixa de estoque')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<String>(
                value: _produtoId,
                decoration: const InputDecoration(
                  labelText: 'Produto',
                  border: OutlineInputBorder(),
                ),
                items: appState.produtos
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.nome} (est: ${p.quantidade})'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _produtoId = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Motivo'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _motivos.map((m) {
                  return ChoiceChip(
                    label: Text(m),
                    selected: _motivo == m,
                    onSelected: (_) => setState(() => _motivo = m),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _confirmar,
                child: const Text('Registrar baixa'),
              ),
            ],
          ),
        );
      },
    );
  }
}