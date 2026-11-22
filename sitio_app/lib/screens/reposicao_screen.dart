import 'package:flutter/material.dart';
import '../widgets/borda_papel.dart' show papelCom;
import '../models/categorias.dart';
import '../widgets/campos_produto.dart';
import 'package:image_picker/image_picker.dart';
import '../models/reposicao_linha.dart';
import '../services/nota_fiscal_service.dart';
import '../state/app_state.dart';
import 'barcode_scan_screen.dart';
import 'reposicao_revisao_screen.dart';
import '../models/produto.dart';
import 'cupom_ocr_screen.dart';
import 'nota_conferencia_screen.dart';
import 'nfce_webview_screen.dart';
import '../widgets/campo_codigo_barras.dart';
import '../config/nfce_config.dart';
import '../models/nota_importada.dart';
import '../services/nfce_sp_parser.dart';

class StockInScreen extends StatefulWidget {
  const StockInScreen({super.key});

  @override
  State<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends State<StockInScreen> {
  final TextEditingController _buscaCtrl = TextEditingController();
  final List<LinhaRepos> _linhas = <LinhaRepos>[];
  // Contrato de leitura por QR: hoje NotaFiscalService (API ainda opcional).
  final NotaQrParser _qrParser = NotaFiscalService();

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  void _adicionarPorTexto(String texto) {
    final String nome = texto.trim();
    if (nome.isEmpty) return;

    final existente = appState.buscarProdutoPorNome(nome);
    final int jaNaLista = _linhas.indexWhere(
      (LinhaRepos l) => l.nome.toLowerCase() == nome.toLowerCase(),
    );

    setState(() {
      if (jaNaLista >= 0) {
        _linhas[jaNaLista].qtdEntrada += 1;
      } else if (existente != null) {
        _linhas.add(
          LinhaRepos(
            nome: existente.nome,
            produtoId: existente.id,
            estoqueAtual: existente.quantidade,
            qtdEntrada: 1,
            pendente: false,
          ),
        );
      } else {
        _linhas.add(
          LinhaRepos(
            nome: nome,
            qtdEntrada: 1,
            pendente: true,
          ),
        );
      }
    });
    _buscaCtrl.clear();
  }

    Future<void> _escanearBarras() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (codigo == null || !mounted) return;
    _adicionarPorBarras(codigo.trim());
  }

    void _adicionarPorBarras(String codigo) {
    final c = codigo.trim();
    if (c.isEmpty) return;

    final p = appState.buscarProdutoPorBarras(c);
    if (p != null) {
      final idx = _linhas.indexWhere(
        (l) =>
            l.produtoId == p.id ||
            (l.codigoBarras != null && l.codigoBarras == c),
      );
      setState(() {
        if (idx >= 0) {
          _linhas[idx].qtdEntrada += 1;
        } else {
          _linhas.add(
            LinhaRepos(
              nome: p.nome,
              produtoId: p.id,
              estoqueAtual: p.quantidade,
              qtdEntrada: 1,
              pendente: false,
              codigoBarras: c,
            ),
          );
        }
      });
      return;
    }

    // Não existe → popup de cadastro (não cria pendente com EAN como nome)
    _dialogCadastroPorBarras(c);
  }

  void _dialogCadastroPorBarras(String codigoBarras) {
    final nomeCtrl = TextEditingController();
    final barrasCtrl = TextEditingController(text: codigoBarras);
    final qtdEntradaCtrl = TextEditingController(text: '1');
    final minCtrl = TextEditingController(text: '0');
    final precoCtrl = TextEditingController(text: '0');
    String ambiente = 'Salão';
    String? sub;
    var publico = true;
    var preparado = false;
    final diasCtrl = TextEditingController(text: '3');

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Cadastrar produto'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nome',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 8),
                    CampoCodigoBarras(
                      controller: barrasCtrl,
                      label: 'Código de barras',
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtdEntradaCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Qtd. de entrada (reposição)',
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
                    DropdownButtonFormField<String>(
                      initialValue: ambiente,
                      decoration: const InputDecoration(
                        labelText: 'Ambiente',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final a in kAmbientes)
                          DropdownMenuItem(
                              value: a, child: Text(nomeAmbiente(a))),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setLocal(() {
                            ambiente = v;
                            sub = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    CampoSubcategoria(
                      ambiente: ambiente,
                      valor: sub,
                      onChanged: (v) => setLocal(() => sub = v),
                    ),
                    CheckPublico(
                      valor: publico,
                      onChanged: (v) => setLocal(() => publico = v),
                    ),
                    CheckPreparado(
                      valor: preparado,
                      onChanged: (v) => setLocal(() => preparado = v),
                    ),
                    const SizedBox(height: 8),
                    CampoDiasValidade(controller: diasCtrl),
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
                    final nome = nomeCtrl.text.trim();
                    if (nome.isEmpty) return;

                    final qtdEntrada =
                        int.tryParse(qtdEntradaCtrl.text.trim()) ?? 1;
                    if (qtdEntrada <= 0) return;

                    final ok = await appState.adicionarProduto(
                      Produto(
                        id: '',
                        nome: nome,
                        quantidade: 0, // estoque inicial 0
                        minimo: int.tryParse(minCtrl.text) ?? 0,
                        preco: double.tryParse(
                              precoCtrl.text.replaceAll(',', '.'),
                            ) ??
                            0,
                        ambiente: ambiente,
                        subcategoria: sub,
                        publico: publico,
                        controlaEstoque: !preparado,
                        diasAvisoValidade: int.tryParse(diasCtrl.text) ?? 3,
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

                    final salvo = appState.buscarProdutoPorBarras(
                          barrasCtrl.text.trim(),
                        ) ??
                        appState.buscarProdutoPorNome(nome);
                    if (salvo == null) return;

                    setState(() {
                      _linhas.add(
                        LinhaRepos(
                          nome: salvo.nome,
                          produtoId: salvo.id,
                          estoqueAtual: salvo.quantidade, // 0
                          qtdEntrada: qtdEntrada,
                          pendente: false,
                          codigoBarras: salvo.codigoBarras,
                        ),
                      );
                    });
                  },
                  child: const Text('Salvar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _lerQrNota() async {
    // 1) Câmera / scanner devolve a string do QR
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    if (raw == null || !mounted) return;
    final t = raw.trim();
    if (t.isEmpty) return;

    // 2) EAN de produto → NÃO é nota
    if (NotaFiscalService.pareceEanProduto(t)) {
      _adicionarPorBarras(t);
      return;
    }

    // 3) Não parece NFC-e
    if (!NotaFiscalService.pareceQrNfce(t)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'QR não parece NFC-e nem código de produto. Nada foi adicionado.',
          ),
        ),
      );
      return;
    }

    // 4) Consulta da nota
    final NotaParseResult resultado;
    if (NfceConfig.usarApi) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      resultado = await _qrParser.parseNotaPorQr(t);
      if (!mounted) return;
      Navigator.of(context).pop(); // fecha loading
    } else {
      // Navegador embutido: abre a página da SEFAZ-SP e lê os itens dela.
      final alvo = NfceSpParser.montarAlvo(t);
      if (alvo.erro != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(alvo.erro!)));
        return;
      }
      // Nota já lida antes? Reaproveita o que está salvo (a SEFAZ recusa
      // consultas repetidas da mesma nota).
      final existente = await appState.notaPorChave(alvo.chave!);
      if (!mounted) return;
      if (existente != null) {
        if (existente.status == 'confirmada') {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Esta nota já foi lida e confirmada antes. Nada foi adicionado.'),
          ));
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nota já lida: abrindo o rascunho salvo.'),
        ));
        await Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => NotaConferenciaScreen(nota: existente),
        ));
        return;
      }
      final r = await Navigator.of(context).push<NotaParseResult>(
        MaterialPageRoute(
          builder: (_) =>
              NfceWebViewScreen(chave: alvo.chave!, url: alvo.url!),
        ),
      );
      if (r == null || !mounted) return;
      resultado = r;
    }

    if (!resultado.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resultado.erro ?? 'Não foi possível ler a nota'),
        ),
      );
      return;
    }

    // Mesmo caminho da foto: grava rascunho no Supabase → conferência editável.
    await NotaConferenciaScreen.abrir(context, resultado, origem: 'qr');
  }

  void _continuar() {
    final List<LinhaRepos> comEntrada =
        _linhas.where((LinhaRepos l) => l.qtdEntrada > 0).toList();
    if (comEntrada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione quantidades de entrada')),
      );
      return;
    }
    Navigator.of(context)
        .push(
          MaterialPageRoute<void>(
            builder: (_) => StockInReviewScreen(linhas: comEntrada),
          ),
        )
        .then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final sugestoes = appState.sugerirProdutos(_buscaCtrl.text);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reposição'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            tooltip: 'Ler QR da nota (NFC-e)',
            onPressed: _lerQrNota,
          ),
          IconButton(
            tooltip: 'Ler cupom (foto)',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CupomOcrScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'Notas pendentes de conferência',
            icon: const Icon(Icons.pending_actions_outlined),
            onPressed: () => abrirNotasPendentes(context),
          ),
          // scanner de produto continua no campo de busca (qr_code_scanner)
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _buscaCtrl,
                  decoration: InputDecoration(
                    labelText: 'Buscar ou digitar nome',
                    border: const OutlineInputBorder(),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          onPressed: _escanearBarras,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () =>
                              _adicionarPorTexto(_buscaCtrl.text),
                        ),
                      ],
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _adicionarPorTexto,
                ),
                ...sugestoes.map(
                  (p) => ListTile(
                    dense: true,
                    title: Text(p.nome),
                    subtitle: Text('Estoque: ${p.quantidade}'),
                    onTap: () {
                      _buscaCtrl.text = p.nome;
                      _adicionarPorTexto(p.nome);
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _linhas.isEmpty
                ? const Center(child: Text('Nenhum item na entrada'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _linhas.length,
                    itemBuilder: (context, i) {
                      final LinhaRepos l = _linhas[i];
                      return Card(
                        shape: papelCom(context, 'repos$i'),
                        color: l.pendente
                            ? Theme.of(context).colorScheme.errorContainer
                            : null,
                        child: ListTile(
                          title: Text(l.nome),
                          subtitle: Text(
                            l.pendente
                                ? (l.codigoBarras != null
                                    ? 'Pendente • barras: ${l.codigoBarras}'
                                    : 'Pendente de cadastro')
                                : 'Estoque atual: ${l.estoqueAtual}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () {
                                  setState(() {
                                    if (l.qtdEntrada > 0) l.qtdEntrada--;
                                  });
                                },
                              ),
                              Text(
                                '${l.qtdEntrada}',
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  setState(() => l.qtdEntrada++);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _continuar,
                child: const Text('Continuar'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}