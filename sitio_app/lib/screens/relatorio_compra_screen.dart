import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../services/relatorio_export.dart';
import '../services/relatorio_service.dart';
import '../services/supabase_repository.dart';
import '../state/app_state.dart';
import '../widgets/filtro_periodo.dart';

class _ItemCompra {
  _ItemCompra(this.produto, this.vendas7d);
  final Produto produto;
  final double vendas7d;

  bool get baixo => produto.estoqueBaixo;

  /// Vendeu nos últimos 7 dias tanto ou mais do que ainda tem em estoque.
  bool get altaSaida => vendas7d > 0 && vendas7d >= produto.quantidade;

  /// Sugestão para repor: cobrir os últimos 7 dias (ou o mínimo, se maior).
  int get sugestao {
    final alvo = vendas7d > produto.minimo ? vendas7d : produto.minimo.toDouble();
    final faltam = (alvo - produto.quantidade).ceil();
    return faltam < 1 ? 1 : faltam;
  }
}

/// Lista de compra: estoque baixo + itens de alta saída (últimos 7 dias).
class RelatorioCompraScreen extends StatefulWidget {
  const RelatorioCompraScreen({super.key});

  @override
  State<RelatorioCompraScreen> createState() => _RelatorioCompraScreenState();
}

class _RelatorioCompraScreenState extends State<RelatorioCompraScreen> {
  final _repo = SupabaseRepository();
  bool _filtroBaixo = true;
  bool _filtroAlta = true;
  bool _carregando = true;
  String? _erro;
  Map<String, double> _vendas7d = {};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      const sel = PeriodoSel(PeriodoTipo.dias7);
      final f = await _repo.fetchFechamentos(inicio: sel.inicio, fim: sel.fim);
      final d = RelatorioDados(DadosBrutos(fechamentos: f), appState.produtos);
      if (!mounted) return;
      setState(() {
        _vendas7d = d.vendasPorProdutoId;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível calcular as vendas: $e';
        _carregando = false;
      });
    }
  }

  List<_ItemCompra> get _itens {
    final todos = appState.produtos
        .where((p) => p.controlaEstoque)
        .map((p) => _ItemCompra(p, _vendas7d[p.id] ?? 0));
    final l = todos.where((i) {
      if (_filtroBaixo && i.baixo) return true;
      if (_filtroAlta && i.altaSaida) return true;
      return false;
    }).toList();
    // mais urgentes primeiro: os dois avisos, depois baixo, depois alta saída
    int peso(_ItemCompra i) => (i.baixo ? 2 : 0) + (i.altaSaida ? 1 : 0);
    l.sort((a, b) {
      final c = peso(b).compareTo(peso(a));
      return c != 0 ? c : a.produto.nome.compareTo(b.produto.nome);
    });
    return l;
  }

  DocRel _doc(List<_ItemCompra> itens) => DocRel(
        titulo: 'Sítio - Lista de compra',
        periodo: 'Vendas dos últimos 7 dias até ${fmtData(DateTime.now())}',
        secoes: [
          SecaoRel(
            'Itens para comprar',
            ['Item', 'Ambiente', 'Estoque', 'Mínimo', 'Vendas 7d', 'Aviso', 'Sugestão'],
            [
              for (final i in itens)
                [
                  i.produto.nome,
                  i.produto.ambiente,
                  '${i.produto.quantidade}',
                  '${i.produto.minimo}',
                  fmtQtd(i.vendas7d),
                  [if (i.baixo) 'Estoque baixo', if (i.altaSaida) 'Alta saida']
                      .join(' + '),
                  '${i.sugestao}',
                ],
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final itens = _itens;
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Compra'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'Exportar (PDF ou CSV)',
                onPressed: (_carregando || itens.isEmpty)
                    ? null
                    : () => exportarRelatorio(context, _doc(itens), 'sitio_compra'),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_carregando) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('Itens baixos no estoque'),
                      selected: _filtroBaixo,
                      onSelected: (v) => setState(() => _filtroBaixo = v),
                    ),
                    FilterChip(
                      label: const Text('Mais vendidos (alta saída)'),
                      selected: _filtroAlta,
                      onSelected: (v) => setState(() => _filtroAlta = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Alta saída: vendeu nos últimos 7 dias tanto ou mais do que '
                  'ainda tem em estoque. A sugestão cobre as vendas de 7 dias '
                  '(ou o estoque mínimo, se maior).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_erro!, style: TextStyle(color: scheme.error)),
                ),
              Expanded(
                child: itens.isEmpty
                    ? const Center(child: Text('Nenhum item para comprar.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: itens.length,
                        itemBuilder: (_, i) {
                          final it = itens[i];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(it.produto.nome,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall),
                                      ),
                                      Text('Comprar ~${it.sugestao}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${it.produto.ambiente} • estoque ${it.produto.quantidade} '
                                    '(mínimo ${it.produto.minimo}) • vendas 7d: ${fmtQtd(it.vendas7d)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    children: [
                                      if (it.baixo)
                                        _Tarja(
                                          'Estoque baixo',
                                          scheme.errorContainer,
                                          scheme.onErrorContainer,
                                        ),
                                      if (it.altaSaida)
                                        const _Tarja(
                                          'Alta saída • possível compra',
                                          Color(0xFFF2D675),
                                          Color(0xFF4A3A00),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
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

class _Tarja extends StatelessWidget {
  const _Tarja(this.texto, this.fundo, this.tinta);
  final String texto;
  final Color fundo;
  final Color tinta;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(texto, style: TextStyle(fontSize: 12, color: tinta)),
    );
  }
}
