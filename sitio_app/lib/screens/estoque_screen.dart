import 'package:flutter/material.dart';
import '../widgets/borda_papel.dart' show papelCom;
import '../models/lote.dart';
import '../models/categorias.dart';
import '../widgets/campos_produto.dart';
import 'preparo_screen.dart';
import '../models/produto.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/permissoes_state.dart';
import 'barcode_scan_screen.dart';

class EstoqueScreen extends StatefulWidget {
  const EstoqueScreen({super.key});

  @override
  State<EstoqueScreen> createState() => _EstoqueScreenState();
}

class _EstoqueScreenState extends State<EstoqueScreen> {
  /// " • vence 12/12/2026 (3d)" do lote mais próximo ainda em estoque.
  String _textoValidade(Produto p) {
    final ls = appState.lotesEmEstoque(p);
    if (ls.isEmpty) return '';
    final l = ls.first.lote;
    final d = l.diasRestantes;
    return ' • vence ${formatarData(l.validade)}'
        '${d < 0 ? ' (VENCIDO)' : ' (${d}d)'}';
  }

  String _ambiente = 'Todos';
  String? _sub;
  bool _soInterno = false;
  bool _soPreparado = false;
  final _buscaCtrl = TextEditingController();
  String _busca = '';
  String _ordem = 'nome'; // nome | vendidos | maior | menor | preco_menor | preco_maior
  bool _soBaixo = false;
  bool _soProcessual = false;

  bool get _filtrando =>
      _ordem != 'nome' ||
      _soBaixo ||
      _soProcessual ||
      _soInterno ||
      _soPreparado;

  @override
  void dispose() {
    _buscaCtrl.dispose();
    super.dispose();
  }

  /// Unidades por produto nas comandas carregadas (aproxima "mais vendidos").
  Map<String, int> _vendidos() {
    final m = <String, int>{};
    for (final c in appState.comandas) {
      for (final i in c.itens) {
        m[i.produtoId] = (m[i.produtoId] ?? 0) + i.quantidade;
      }
    }
    return m;
  }

  List<Produto> _aplicar(List<Produto> base) {
    final q = _busca.trim().toLowerCase();
    var l = base.where((p) {
      if (_ambiente != 'Todos' && p.ambiente != _ambiente) return false;
      if (_sub != null && p.subcategoria != _sub) return false;
      if (_soInterno && p.publico) return false;
      if (_soPreparado && p.controlaEstoque) return false;
      if (q.isNotEmpty && !p.nome.toLowerCase().contains(q)) return false;
      if (_soBaixo && !p.estoqueBaixo) return false;
      if (_soProcessual && !p.processual) return false;
      return true;
    }).toList();
    final v = _ordem == 'vendidos' ? _vendidos() : const <String, int>{};
    int porNome(Produto a, Produto b) =>
        a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
    l.sort((a, b) {
      switch (_ordem) {
        case 'vendidos':
          final c = (v[b.id] ?? 0).compareTo(v[a.id] ?? 0);
          return c != 0 ? c : porNome(a, b);
        case 'maior':
          return b.quantidade.compareTo(a.quantidade);
        case 'menor':
          return a.quantidade.compareTo(b.quantidade);
        case 'preco_menor':
          return a.preco.compareTo(b.preco);
        case 'preco_maior':
          return b.preco.compareTo(a.preco);
        default:
          return porNome(a, b);
      }
    });
    return l;
  }

  void _abrirFiltros() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          void set(VoidCallback f) {
            setState(f);
            setSheet(() {});
          }

          Widget ordem(String v, String t) => RadioListTile<String>(
                dense: true,
                title: Text(t),
                value: v,
                groupValue: _ordem,
                onChanged: (x) => set(() => _ordem = x ?? 'nome'),
              );

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ordenar por',
                      style: Theme.of(ctx).textTheme.titleMedium),
                  ordem('nome', 'Nome (A–Z)'),
                  ordem('vendidos', 'Mais vendidos (nas comandas)'),
                  ordem('maior', 'Maior quantidade em estoque'),
                  ordem('menor', 'Menor quantidade em estoque'),
                  ordem('preco_menor', 'Menor preço'),
                  ordem('preco_maior', 'Maior preço'),
                  const Divider(),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Somente estoque baixo'),
                    value: _soBaixo,
                    onChanged: (x) => set(() => _soBaixo = x),
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Somente itens internos (não públicos)'),
                    value: _soInterno,
                    onChanged: (x) => set(() => _soInterno = x),
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Somente preparados no dia'),
                    value: _soPreparado,
                    onChanged: (x) => set(() => _soPreparado = x),
                  ),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Somente produtos processuais'),
                    value: _soProcessual,
                    onChanged: (x) => set(() => _soProcessual = x),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => set(() {
                        _ordem = 'nome';
                        _soBaixo = false;
                        _soProcessual = false;
                        _soInterno = false;
                        _soPreparado = false;
                      }),
                      child: const Text('Limpar filtros'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _abrirDetalhe(Produto p) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final atual = appState.produtoPorId(p.id) ?? p;
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    atual.nome,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text('Ambiente: ${nomeAmbiente(atual.ambiente)}'),
                  Text(atual.controlaEstoque
                      ? 'Estoque: ${atual.quantidade}'
                      : 'Preparados disponíveis: ${atual.quantidade}'),
                  if (atual.controlaEstoque) Text('Mínimo: ${atual.minimo}'),
                  Text('Preço: R\$ ${atual.preco.toStringAsFixed(2)}'),
                  if (atual.estoqueBaixo)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Estoque baixo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (!atual.controlaEstoque) ...[
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => PreparoScreen(produto: atual)));
                      },
                      icon: const Icon(Icons.local_fire_department_outlined),
                      label: const Text('Registrar preparo'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _abrirEditar(atual);
                    },
                    child: const Text('Editar'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirEditar(Produto p) {
    final qtdCtrl = TextEditingController(text: '${p.quantidade}');
    final precoCtrl = TextEditingController(text: p.preco.toStringAsFixed(2));
    final minCtrl = TextEditingController(text: '${p.minimo}');
    var processual = p.processual;
    var publico = p.publico;
    var preparado = !p.controlaEstoque;
    final diasCtrl = TextEditingController(text: '${p.diasAvisoValidade}');
    String? sub = p.subcategoria;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Editar ${p.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtdCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantidade',
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Preço',
                  border: OutlineInputBorder(),
                ),
              ),
              if (permissoes.pode('estoque_cadastrar'))
                StatefulBuilder(
                  builder: (_, setCheck) => Column(
                    children: [
                      const SizedBox(height: 8),
                      CampoSubcategoria(
                        ambiente: p.ambiente,
                        valor: sub,
                        onChanged: (v) => setCheck(() => sub = v),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                            'Produto processual (passa por preparo)'),
                        value: processual,
                        onChanged: (v) =>
                            setCheck(() => processual = v ?? false),
                      ),
                      CheckPublico(
                        valor: publico,
                        onChanged: (v) => setCheck(() => publico = v),
                      ),
                      CheckPreparado(
                        valor: preparado,
                        onChanged: (v) => setCheck(() => preparado = v),
                      ),
                      const SizedBox(height: 8),
                      CampoDiasValidade(controller: diasCtrl),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final q = int.tryParse(qtdCtrl.text) ?? p.quantidade;
                final m = int.tryParse(minCtrl.text) ?? p.minimo;
                final pr = double.tryParse(precoCtrl.text.replaceAll(',', '.')) ?? p.preco;
                final ok = await appState.atualizarProduto(
                  p.copyWith(
                    quantidade: q,
                    minimo: m,
                    preco: pr,
                    processual: processual,
                    publico: publico,
                    controlaEstoque: !preparado,
                    diasAvisoValidade: int.tryParse(diasCtrl.text) ?? p.diasAvisoValidade,
                    subcategoria: sub,
                    limparSubcategoria: sub == null,
                  ),
                );
                if (!context.mounted) return;
                Navigator.pop(ctx);
                if (!ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(appState.ultimoErro ?? 'Erro ao salvar')),
                  );
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _novoProduto() {
    final nomeCtrl = TextEditingController();
    final qtdCtrl = TextEditingController(text: '0');
    final minCtrl = TextEditingController(text: '0');
    final precoCtrl = TextEditingController(text: '0');
    final barrasCtrl = TextEditingController();
    String ambiente = 'Salão';
    var processual = false;
    var publico = true;
    var preparado = false;
    final diasCtrl = TextEditingController(text: '3');
    String? sub;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: const Text('Novo produto'),
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
                    ),
                    TextField(
                      controller: barrasCtrl,
                      decoration: InputDecoration(
                        labelText: 'Código de barras (opcional)',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.qr_code_scanner),
                          tooltip: 'Ler código',
                          onPressed: () async {
                            final codigo = await Navigator.of(context).push<String>(
                              MaterialPageRoute(
                                builder: (_) => const BarcodeScanScreen(),
                              ),
                            );
                            if (codigo != null && codigo.trim().isNotEmpty) {
                              setLocal(() {
                                barrasCtrl.text = codigo.trim();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: qtdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade',
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
                      value: ambiente,
                      decoration: const InputDecoration(
                        labelText: 'Ambiente',
                        border: OutlineInputBorder(),
                      ),
                      items: kAmbientes
                          .map((a) => DropdownMenuItem(
                              value: a, child: Text(nomeAmbiente(a))))
                          .toList(),
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
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title:
                          const Text('Produto processual (passa por preparo)'),
                      value: processual,
                      onChanged: (v) =>
                          setLocal(() => processual = v ?? false),
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
                    final ok = await appState.adicionarProduto(
                      Produto(
                        id: '',
                        nome: nome,
                        codigoBarras: barrasCtrl.text.trim().isEmpty
                            ? null
                            : barrasCtrl.text.trim(),
                        quantidade: int.tryParse(qtdCtrl.text) ?? 0,
                        minimo: int.tryParse(minCtrl.text) ?? 0,
                        preco: double.tryParse(
                              precoCtrl.text.replaceAll(',', '.'),
                            ) ??
                            0,
                        ambiente: ambiente,
                        processual: processual,
                        subcategoria: sub,
                        publico: publico,
                        controlaEstoque: !preparado,
                        diasAvisoValidade: int.tryParse(diasCtrl.text) ?? 3,
                      ),
                    );
                    if (!context.mounted) return;
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok ? 'Produto salvo' : (appState.ultimoErro ?? 'Erro ao criar'),
                        ),
                      ),
                    );
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

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final lista = _aplicar(appState.produtos);

        return Scaffold(
          appBar: AppBar(
            title: TextField(
              controller: _buscaCtrl,
              onChanged: (v) => setState(() => _busca = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar item do estoque',
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _busca.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _buscaCtrl.clear();
                          _busca = '';
                        }),
                      ),
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Filtros',
                onPressed: _abrirFiltros,
                icon: Badge(
                  isLabelVisible: _filtrando,
                  smallSize: 8,
                  child: const Icon(Icons.filter_list),
                ),
              ),
              // Cadastro de produto: só Adm
              if (permissoes.pode('estoque_cadastrar'))
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Novo produto',
                  onPressed: _novoProduto,
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todos', ...kAmbientes].map((a) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(nomeAmbiente(a)),
                          selected: _ambiente == a,
                          onSelected: (_) => setState(() {
                            _ambiente = a;
                            _sub = null;
                          }),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if ((kSubcategorias[_ambiente] ?? const <String>[]).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [null, ...kSubcategorias[_ambiente]!].map((s) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(s ?? 'Todas'),
                            selected: _sub == s,
                            onSelected: (_) => setState(() => _sub = s),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final p = lista[i];
                    return Card(
                      shape: papelCom(context, p.id),
                      margin: const EdgeInsets.only(bottom: 8),
                      color: p.estoqueBaixo
                          ? Theme.of(context).colorScheme.errorContainer
                          : null,
                      child: ListTile(
                        title: Text(p.nome),
                        subtitle: Text(
                          '${nomeAmbiente(p.ambiente)}'
                          '${p.subcategoria == null ? '' : ' / ${p.subcategoria}'}'
                          ' • estoque: ${p.quantidade}'
                          '${p.publico ? '' : ' • interno'}'
                          '${p.processual ? ' • processual' : ''}'
                          '${p.estoqueBaixo ? ' • BAIXO' : ''}'
                          '${_textoValidade(p)}',
                        ),
                        trailing: Text('R\$ ${p.preco.toStringAsFixed(2)}'),
                        onTap: () => _abrirDetalhe(p),
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