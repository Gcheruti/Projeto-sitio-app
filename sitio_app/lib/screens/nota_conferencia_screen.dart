import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/nota_importada.dart';
import '../models/produto.dart';
import '../models/reposicao_linha.dart';
import '../services/produto_matcher.dart';
import '../state/app_state.dart';
import 'reposicao_revisao_screen.dart';

String _fmtMoeda(double? v) =>
    v == null ? '' : v.toStringAsFixed(2).replaceAll('.', ',');

String _fmtQtd(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(3).replaceFirst(RegExp(r'0+$'), '').replaceAll('.', ',');
}

/// "1.299,90" | "7,5" | "2.5" → double; vazio/inválido → null.
double? _num(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  if (t.contains(',')) {
    return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.'));
  }
  return double.tryParse(t);
}

/// Estado editável de uma linha da conferência.
class _LinhaEdit {
  _LinhaEdit(NotaItem i, this.produto)
      : nome = TextEditingController(text: i.nome),
        qtd = TextEditingController(text: _fmtQtd(i.quantidade)),
        unit = TextEditingController(text: _fmtMoeda(i.valorUnitario)),
        total = TextEditingController(text: _fmtMoeda(i.totalCalculado)),
        codigo = i.codigo,
        suspeito = i.suspeito;

  final TextEditingController nome;
  final TextEditingController qtd;
  final TextEditingController unit;
  final TextEditingController total;
  final String? codigo;
  Produto? produto; // produto do estoque vinculado (null = produto novo)
  bool suspeito;

  void dispose() {
    nome.dispose();
    qtd.dispose();
    unit.dispose();
    total.dispose();
  }
}

class _Escolha {
  const _Escolha(this.produto);
  final Produto? produto;
}

/// Conferência da nota lida (foto ou QR): tabela totalmente editável.
/// Ao confirmar, segue o fluxo normal de reposição ([StockInReviewScreen]).
class NotaConferenciaScreen extends StatefulWidget {
  const NotaConferenciaScreen({super.key, required this.nota});

  final NotaImportada nota;

  /// Ponto único de entrada para foto e QR: grava o rascunho no Supabase
  /// (status "rascunho") e abre a conferência. Se o servidor falhar, a
  /// conferência abre mesmo assim (só não fica salva).
  static Future<void> abrir(
    BuildContext context,
    NotaParseResult resultado, {
    required String origem,
    int qtdFotos = 0,
    bool substituirTela = false,
  }) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final nota = await appState.salvarNotaRascunho(
      resultado,
      origem: origem,
      qtdFotos: qtdFotos,
    );
    if (nota.id == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Não consegui salvar o rascunho no servidor. '
            'Você ainda pode conferir e confirmar.',
          ),
        ),
      );
    }

    final rota = MaterialPageRoute<void>(
      builder: (_) => NotaConferenciaScreen(nota: nota),
    );
    if (substituirTela) {
      await nav.pushReplacement(rota);
    } else {
      await nav.push(rota);
    }
  }

  @override
  State<NotaConferenciaScreen> createState() => _NotaConferenciaScreenState();
}

class _NotaConferenciaScreenState extends State<NotaConferenciaScreen> {
  final _scroll = ScrollController();
  final _totalCtrl = TextEditingController();
  late final List<_LinhaEdit> _linhas;
  final List<_LinhaEdit> _removidas = [];
  bool _salvando = false;
  // O que o OCR/QR leu, antes de qualquer edição (para comparar ao confirmar).
  late final List<Map<String, dynamic>> _lidos;
  late final double? _totalLido;

  static Map<String, dynamic> _mapa(NotaItem i) => {
        'nome': i.nome,
        'quantidade': i.quantidade,
        'valor_unitario': i.valorUnitario,
        'valor_total': i.valorTotal,
        'codigo': i.codigo,
      };

  @override
  void initState() {
    super.initState();
    _lidos = widget.nota.itens.map(_mapa).toList();
    _totalLido = widget.nota.totalNota;
    _linhas = widget.nota.itens
        .map(
          (i) => _LinhaEdit(
            i,
            ProdutoMatcher.sugerir(
              appState.produtos,
              i.nome,
              codigoBarras: i.codigo,
            ),
          ),
        )
        .toList();
    _totalCtrl.text = _fmtMoeda(widget.nota.totalNota);
  }

  @override
  void dispose() {
    for (final l in [..._linhas, ..._removidas]) {
      l.dispose();
    }
    _totalCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ---------- edição ----------

  double get _soma =>
      _linhas.fold(0.0, (s, l) => s + (_num(l.total.text) ?? 0));

  /// Mexeu em qtd ou unitário → recalcula o total da linha.
  void _recalcTotal(_LinhaEdit l) {
    final q = _num(l.qtd.text);
    final u = _num(l.unit.text);
    if (q != null && u != null) l.total.text = _fmtMoeda(q * u);
    setState(() => l.suspeito = false);
  }

  /// Mexeu no total → recalcula o unitário.
  void _recalcUnit(_LinhaEdit l) {
    final q = _num(l.qtd.text);
    final t = _num(l.total.text);
    if (q != null && q > 0 && t != null) l.unit.text = _fmtMoeda(t / q);
    setState(() => l.suspeito = false);
  }

  void _adicionarLinha() {
    setState(() {
      _linhas.add(_LinhaEdit(NotaItem(nome: '', quantidade: 1), null));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _remover(int i) {
    final removida = _linhas.removeAt(i);
    _removidas.add(removida);
    setState(() {});
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Linha removida'),
          action: SnackBarAction(
            label: 'Desfazer',
            onPressed: () {
              if (!mounted) return;
              setState(() {
                _removidas.remove(removida);
                final pos = i > _linhas.length ? _linhas.length : i;
                _linhas.insert(pos, removida);
              });
            },
          ),
        ),
      );
  }

  Future<void> _escolherProduto(_LinhaEdit l) async {
    final escolha = await showModalBottomSheet<_Escolha>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _SeletorProduto(),
    );
    if (escolha == null || !mounted) return;
    setState(() => l.produto = escolha.produto);
  }

  void _aviso(String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- coleta / validação ----------

  /// Lê a tabela da tela. [estrito]: valida e avisa; senão só ignora linhas vazias.
  List<NotaItem>? _coletar({required bool estrito}) {
    final out = <NotaItem>[];
    for (var i = 0; i < _linhas.length; i++) {
      final l = _linhas[i];
      final nome = l.nome.text.trim();
      final q = _num(l.qtd.text);
      if (nome.isEmpty && !estrito) continue;
      if (nome.isEmpty) {
        _aviso('Linha ${i + 1}: informe o nome do item');
        return null;
      }
      if (q == null || q <= 0) {
        _aviso('Linha ${i + 1}: quantidade inválida');
        return null;
      }
      out.add(
        NotaItem(
          nome: nome,
          quantidade: q,
          valorUnitario: _num(l.unit.text),
          valorTotal: _num(l.total.text),
          codigo: l.codigo,
        ),
      );
    }
    if (out.isEmpty && estrito) {
      _aviso('Adicione ao menos um item');
      return null;
    }
    return out;
  }

  /// Passa a tabela editada para a nota (e para o servidor, se houver id).
  Future<bool> _gravarEdicao(List<NotaItem> itens) async {
    final nota = widget.nota;
    nota.itens
      ..clear()
      ..addAll(itens);
    nota.totalNota = _num(_totalCtrl.text);
    return appState.atualizarNotaRascunho(nota);
  }

  Future<void> _salvarRascunho() async {
    if (widget.nota.id == null) {
      _aviso('Este rascunho não está no servidor, então não dá para salvar.');
      return;
    }
    final itens = _coletar(estrito: false);
    if (itens == null) return;
    setState(() => _salvando = true);
    final ok = await _gravarEdicao(itens);
    if (!mounted) return;
    setState(() => _salvando = false);
    _aviso(ok
        ? 'Rascunho salvo. Dá para retomar em "Notas pendentes".'
        : (appState.ultimoErro ?? 'Não foi possível salvar o rascunho'));
  }

  // ---------- confirmar → fluxo normal de reposição ----------

  Future<void> _confirmar() async {
    if (_salvando) return;
    final itens = _coletar(estrito: true);
    if (itens == null) return;

    setState(() => _salvando = true);
    await _gravarEdicao(itens); // melhor esforço; a reposição não depende disso
    if (!mounted) return;
    setState(() => _salvando = false);

    final linhas = <LinhaRepos>[];
    for (var i = 0; i < itens.length; i++) {
      final item = itens[i];
      final p = _linhas[i].produto;
      final qtd = item.quantidade.round().clamp(1, 999999).toInt();

      if (p != null) {
        final idx = linhas.indexWhere((x) => x.produtoId == p.id);
        if (idx >= 0) {
          linhas[idx].qtdEntrada += qtd;
        } else {
          linhas.add(LinhaRepos(
            nome: p.nome,
            produtoId: p.id,
            estoqueAtual: p.quantidade,
            qtdEntrada: qtd,
            codigoBarras: p.codigoBarras,
          ));
        }
      } else {
        final chave = ProdutoMatcher.normalizar(item.nome);
        final idx = linhas.indexWhere(
          (x) => x.pendente && ProdutoMatcher.normalizar(x.nome) == chave,
        );
        if (idx >= 0) {
          linhas[idx].qtdEntrada += qtd;
        } else {
          linhas.add(LinhaRepos(
            nome: item.nome,
            qtdEntrada: qtd,
            pendente: true,
            codigoBarras: item.codigo,
          ));
        }
      }
    }

    final nota = widget.nota;
    // Registra leitura x correção (sem esperar; falha não atrapalha).
    appState.registrarCorrecaoNota(
      notaId: nota.id,
      origem: nota.origem,
      textoBruto: nota.textoBruto,
      itensLidos: _lidos,
      itensFinais: itens.map(_mapa).toList(),
      totalLido: _totalLido,
      totalFinal: _num(_totalCtrl.text),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StockInReviewScreen(
          linhas: linhas,
          valorInvestidoSugerido: _num(_totalCtrl.text) ?? _soma,
          chaveAcesso: nota.chaveAcesso,
          urlQr: nota.urlQr,
          notaId: nota.id,
        ),
      ),
    );
  }

  void _mostrarTextoLido() {
    final texto = widget.nota.textoBruto.trim();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Texto lido pelo app',
                        style: Theme.of(ctx).textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copiar'),
                    onPressed: texto.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: texto));
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Texto copiado.')),
                            );
                          },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: ctrl,
                  child: SelectableText(
                    texto.isEmpty
                        ? 'Nenhum texto guardado para esta nota.'
                        : texto,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalNota = _num(_totalCtrl.text);
    final soma = _soma;
    final difere = totalNota != null && (soma - totalNota).abs() > 0.05;
    final origem = widget.nota.origem == 'qr' ? 'QR Code' : 'foto';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conferir nota'),
        actions: [
          IconButton(
            tooltip: 'Texto lido pelo app',
            icon: const Icon(Icons.text_snippet_outlined),
            onPressed: _mostrarTextoLido,
          ),
          IconButton(
            tooltip: 'Salvar rascunho',
            icon: const Icon(Icons.save_outlined),
            onPressed: _salvando ? null : _salvarRascunho,
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.nota.id == null)
            MaterialBanner(
              content: const Text(
                'Rascunho não salvo no servidor. Confira e confirme normalmente.',
              ),
              actions: const [SizedBox.shrink()],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lida por $origem • ${_linhas.length} linha(s). '
                  'Edite o que estiver errado antes de confirmar.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _totalCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Total da nota (opcional)',
                    prefixText: 'R\$ ',
                    helperText: 'Soma dos itens: R\$ ${_fmtMoeda(soma)}',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                if (difere)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'A soma dos itens difere do total da nota: '
                      'pode faltar ou sobrar uma linha.',
                      style: TextStyle(color: scheme.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _linhas.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nenhum item lido. Use "Adicionar linha" para '
                        'preencher à mão.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    itemCount: _linhas.length,
                    itemBuilder: (context, i) => _cardLinha(i, _linhas[i]),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _adicionarLinha,
                    icon: const Icon(Icons.add),
                    label: const Text('Linha'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _salvando ? null : _confirmar,
                      child: _salvando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Confirmar conferência'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardLinha(int i, _LinhaEdit l) {
    final scheme = Theme.of(context).colorScheme;
    final p = l.produto;

    return Card(
      key: ObjectKey(l),
      color: l.suspeito ? scheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: l.nome,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Item ${i + 1}',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Remover linha',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remover(i),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: l.qtd,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Qtd',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _recalcTotal(l),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: l.unit,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Unitário',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _recalcTotal(l),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: l.total,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Total',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => _recalcUnit(l),
                    ),
                  ),
                ],
              ),
            ),
            if (l.suspeito)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: Text(
                  'Quantidade × unitário não bate com o total: confira a leitura.',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            InkWell(
              onTap: () => _escolherProduto(l),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
                child: Row(
                  children: [
                    Icon(
                      p != null ? Icons.link : Icons.add_box_outlined,
                      size: 18,
                      color: p != null ? scheme.primary : scheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        p != null
                            ? 'Estoque: ${p.nome} (atual ${p.quantidade})'
                            : 'Produto novo: será cadastrado na próxima etapa',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      p != null ? 'Trocar' : 'Vincular',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Escolha de produto do estoque para uma linha
// ---------------------------------------------------------------------------

class _SeletorProduto extends StatefulWidget {
  const _SeletorProduto();

  @override
  State<_SeletorProduto> createState() => _SeletorProdutoState();
}

class _SeletorProdutoState extends State<_SeletorProduto> {
  final _busca = TextEditingController();

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = ProdutoMatcher.normalizar(_busca.text);
    final lista = appState.produtos
        .where((p) => q.isEmpty || ProdutoMatcher.normalizar(p.nome).contains(q))
        .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _busca,
                decoration: const InputDecoration(
                  labelText: 'Buscar no estoque',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('Tratar como produto novo'),
              subtitle: const Text('Será cadastrado na próxima etapa'),
              onTap: () => Navigator.pop(context, const _Escolha(null)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: lista.length,
                itemBuilder: (context, i) {
                  final p = lista[i];
                  return ListTile(
                    title: Text(p.nome),
                    subtitle: Text('${p.ambiente} • estoque ${p.quantidade}'),
                    onTap: () => Navigator.pop(context, _Escolha(p)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notas pendentes (rascunhos) para retomar a conferência
// ---------------------------------------------------------------------------

Future<void> abrirNotasPendentes(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _NotasPendentesSheet(),
  );
}

class _NotasPendentesSheet extends StatefulWidget {
  const _NotasPendentesSheet();

  @override
  State<_NotasPendentesSheet> createState() => _NotasPendentesSheetState();
}

class _NotasPendentesSheetState extends State<_NotasPendentesSheet> {
  late Future<List<NotaImportada>> _futuro = appState.notasPendentes();

  String _dataHora(DateTime? d) {
    if (d == null) return '—';
    String dois(int n) => n.toString().padLeft(2, '0');
    return '${dois(d.day)}/${dois(d.month)} ${dois(d.hour)}:${dois(d.minute)}';
  }

  Future<void> _abrir(NotaImportada n) async {
    final id = n.id;
    if (id == null) return;
    final nota = await appState.abrirNota(id);
    if (!mounted) return;
    if (nota == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.ultimoErro ?? 'Não consegui abrir')),
      );
      return;
    }
    final nav = Navigator.of(context);
    nav.pop(); // fecha a lista
    nav.push(
      MaterialPageRoute<void>(builder: (_) => NotaConferenciaScreen(nota: nota)),
    );
  }

  Future<void> _descartar(NotaImportada n) async {
    final id = n.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descartar nota?'),
        content: const Text('O rascunho será cancelado e sai desta lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await appState.descartarNota(id);
    if (!mounted) return;
    setState(() => _futuro = appState.notasPendentes());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Notas pendentes de conferência',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: FutureBuilder<List<NotaImportada>>(
                future: _futuro,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final lista = snap.data ?? [];
                  if (lista.isEmpty) {
                    return const Center(child: Text('Nenhuma nota pendente'));
                  }
                  return ListView.builder(
                    itemCount: lista.length,
                    itemBuilder: (context, i) {
                      final n = lista[i];
                      return ListTile(
                        leading: Icon(
                          n.origem == 'qr'
                              ? Icons.qr_code_2
                              : Icons.photo_camera_outlined,
                        ),
                        title: Text(
                          '${_dataHora(n.criadoEm)} • '
                          '${n.origem == 'qr' ? 'QR Code' : 'Foto'}',
                        ),
                        subtitle: Text(
                          n.totalNota != null
                              ? 'Total lido: R\$ ${_fmtMoeda(n.totalNota)}'
                              : 'Sem total lido',
                        ),
                        trailing: IconButton(
                          tooltip: 'Descartar',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _descartar(n),
                        ),
                        onTap: () => _abrir(n),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
