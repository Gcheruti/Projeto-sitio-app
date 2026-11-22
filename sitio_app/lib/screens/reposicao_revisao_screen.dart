import 'package:flutter/material.dart';
import '../state/auth_state.dart';
import '../widgets/validade_dialog.dart';
import '../models/categorias.dart';
import '../models/produto.dart';
import '../models/reposicao_linha.dart';
import '../state/app_state.dart';
import '../widgets/campo_codigo_barras.dart';
import 'shell_screen.dart';

class StockInReviewScreen extends StatefulWidget {
  const StockInReviewScreen({
    super.key,
    required this.linhas,
    this.valorInvestidoSugerido,
    this.chaveAcesso,
    this.urlQr,
    this.notaId,
  });

  final List<LinhaRepos> linhas;
  final double? valorInvestidoSugerido;
  final String? chaveAcesso;
  final String? urlQr;

  /// Nota importada (foto/QR) de origem; marcada como confirmada ao final.
  final String? notaId;

  @override
  State<StockInReviewScreen> createState() => _StockInReviewScreenState();
}

class _StockInReviewScreenState extends State<StockInReviewScreen> {
  late List<LinhaRepos> _linhas;
  final _valorCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _linhas = List<LinhaRepos>.from(widget.linhas);
    if (widget.valorInvestidoSugerido != null &&
        widget.valorInvestidoSugerido! > 0) {
      _valorCtrl.text = widget.valorInvestidoSugerido!.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    super.dispose();
  }

  bool get _temPendente =>
      _linhas.any((l) => l.pendente && l.qtdEntrada > 0);

  void _cadastrarPendente(LinhaRepos linha) {
    final precoCtrl = TextEditingController(text: '0');
    final minCtrl = TextEditingController(text: '0');
    final barrasCtrl = TextEditingController(
      text: linha.codigoBarras ?? '',
    );
    String ambiente = 'Salão';

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Cadastrar: ${linha.nome}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Nome: ${linha.nome}'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: precoCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Preço',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Mínimo',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CampoCodigoBarras(controller: barrasCtrl),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: ambiente,
                      items: const [
                        DropdownMenuItem(value: 'Salão', child: Text('Salão')),
                        DropdownMenuItem(value: 'Loja', child: Text('Cosmória')),
                        DropdownMenuItem(
                            value: 'Tarô', child: Text('Casa da Bruxa')),
                      ],
                      onChanged: (v) {
                        if (v != null) setLocal(() => ambiente = v);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Ambiente',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    final ok = await appState.adicionarProduto(
                      Produto(
                        id: '',
                        nome: linha.nome,
                        quantidade: 0,
                        minimo: int.tryParse(minCtrl.text) ?? 0,
                        preco: double.tryParse(
                              precoCtrl.text.replaceAll(',', '.'),
                            ) ??
                            0,
                        ambiente: ambiente,
                        codigoBarras: barrasCtrl.text.trim().isEmpty
                            ? null
                            : barrasCtrl.text.trim(),
                      ),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    if (!ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            appState.ultimoErro ?? 'Erro ao cadastrar',
                          ),
                        ),
                      );
                      return;
                    }
                    final p = appState.buscarProdutoPorNome(linha.nome);
                    setState(() {
                      linha.pendente = false;
                      linha.produtoId = p?.id;
                      linha.estoqueAtual = p?.quantidade ?? 0;
                    });
                  },
                  child: const Text('Salvar produto'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmar() async {
    final valor =
        double.tryParse(_valorCtrl.text.replaceAll(',', '.')) ?? 0;
    if (valor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o valor investido (maior que zero)'),
        ),
      );
      return;
    }

    if (!await pedirValidades(context, _linhas)) return;
    if (!mounted) return;

    final senhaCtrl = TextEditingController();
    var erro = false;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setLocal) {
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
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!await authState.senhaConfere(senhaCtrl.text)) {
                      setLocal(() => erro = true);
                      return;
                    }
                    Navigator.pop(ctx);

                    final ok = await appState.confirmarRepos(
                      _linhas,
                      valorInvestido: valor,
                      notaId: widget.notaId,
                    );
                    if (!context.mounted) return;

                    if (ok) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                      // ignore: avoid_dynamic_calls
                      (ShellScreen.navKey.currentState as dynamic)
                          ?.irParaEstoque();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Reposição confirmada'),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(appState.ultimoErro ?? 'Erro'),
                        ),
                      );
                    }
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visiveis = _linhas.where((l) => l.qtdEntrada > 0).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Revisar reposição')),
      body: Column(
        children: [
          if (_temPendente)
            const MaterialBanner(
              content: Text(
                'Cadastre os itens pendentes antes de confirmar',
              ),
              actions: [SizedBox.shrink()],
            ),
          if (widget.chaveAcesso != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Chave: ${widget.chaveAcesso}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visiveis.length,
              itemBuilder: (context, i) {
                final l = visiveis[i];
                return Card(
                  child: ListTile(
                    title: Text(
                      l.pendente && (l.nome.isEmpty || l.nome == 'Novo produto')
                          ? (l.codigoBarras != null
                              ? 'Cadastrar item (${l.codigoBarras})'
                              : 'Cadastrar item')
                          : l.nome,
                      style: TextStyle(
                        color: l.pendente
                            ? Theme.of(context).colorScheme.error
                            : null,
                        fontWeight:
                            l.pendente ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      l.pendente
                          ? (l.codigoBarras != null
                              ? 'Pendente de cadastro · ${l.codigoBarras}'
                              : 'Pendente de cadastro')
                          : 'Entrada: ${l.qtdEntrada} (estoque ${l.estoqueAtual})',
                    ),
                    trailing: l.pendente
                        ? IconButton(
                            icon: Icon(
                              Icons.add_circle,
                              color: Colors.green.shade700,
                            ),
                            onPressed: () => _cadastrarPendente(l),
                          )
                        : Text('+${l.qtdEntrada}'),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _valorCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor investido (R\$)',
                hintText: 'Total pago nesta compra',
                border: OutlineInputBorder(),
                prefixText: 'R\$ ',
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _temPendente ? null : _confirmar,
                child: const Text('Confirmar reposição'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}