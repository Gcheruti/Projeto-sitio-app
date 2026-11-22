import 'package:flutter/material.dart';

import '../models/produto.dart';
import '../services/inscricoes_site.dart';
import '../services/relatorio_export.dart';
import '../services/relatorio_service.dart';
import '../services/supabase_repository.dart';
import '../state/app_state.dart';
import '../widgets/filtro_periodo.dart';

/// Relatório de estoque: o foco é quantidade (entradas, saídas, mais usados).
class RelatorioEstoqueScreen extends StatefulWidget {
  const RelatorioEstoqueScreen({super.key});

  @override
  State<RelatorioEstoqueScreen> createState() => _RelatorioEstoqueScreenState();
}

class _RelatorioEstoqueScreenState extends State<RelatorioEstoqueScreen> {
  final _repo = SupabaseRepository();
  PeriodoSel _periodo = const PeriodoSel(PeriodoTipo.dias7);
  bool _carregando = false;
  String? _erro;
  RelatorioDados? _dados;
  InscricoesResultado? _insc;

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
      final fInsc = buscarInscricoesSite(_periodo.inicio, _periodo.fim);
      final b = await carregarDadosBrutos(_repo, _periodo.inicio, _periodo.fim);
      final insc = await fInsc;
      if (!mounted) return;
      setState(() {
        _dados = RelatorioDados(b, appState.produtos);
        _insc = insc;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = '$e';
        _carregando = false;
      });
    }
  }

  /// Cursos e eventos = itens da Gruta (aulas, oficinas, rituais...).
  /// Estoque desses itens = vagas.
  List<_LinhaCurso> _cursos(RelatorioDados d) {
    final app = d.vendasPorProdutoId;
    final site = _insc?.pessoasPorProduto ?? const <String, int>{};
    final l = [
      for (final Produto p in appState.produtos)
        if (p.ambiente == 'Gruta')
          _LinhaCurso(p.nome, (app[p.id] ?? 0).round(), site[p.id] ?? 0,
              p.quantidade),
    ];
    l.sort((a, b) => b.total.compareTo(a.total) != 0
        ? b.total.compareTo(a.total)
        : a.nome.compareTo(b.nome));
    return l;
  }

  DocRel _doc(RelatorioDados d) {
    List<List<String>> top(double Function(MovItem) v) => [
          for (final i in d.topPor(v, limite: 20)) [i.nome, fmtQtd(v(i))],
        ];
    return DocRel(
      titulo: 'Sítio - Relatório de estoque',
      periodo: 'Período: ${_periodo.rotulo}',
      secoes: [
        SecaoRel('Resumo', ['Indicador', 'Valor'], [
          ['Unidades que entraram', fmtQtd(d.totalEntradas)],
          ['Unidades vendidas', fmtQtd(d.totalVendas)],
          ['Unidades baixadas', '${d.qtdBaixas}'],
          ['Itens movimentados', '${d.itens.length}'],
        ]),
        SecaoRel('Itens mais vendidos / procurados', ['Item', 'Unidades'],
            top((i) => i.vendas)),
        SecaoRel('Itens que mais entraram', ['Item', 'Unidades'],
            top((i) => i.entradas)),
        SecaoRel('Itens com mais baixas', ['Item', 'Unidades'],
            top((i) => i.baixas)),
        SecaoRel('Cursos e eventos',
            ['Curso/evento', 'Vendidos no app', 'Inscritos pelo site', 'Total', 'Vagas restantes'], [
          for (final c in _cursos(d))
            [c.nome, '${c.app}', '${c.site}', '${c.total}', '${c.vagas}'],
        ]),
      ],
    );
  }

  Widget _linha(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(a),
            Text(b, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _lista(String titulo, List<MovItem> itens, double Function(MovItem) v) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        ),
        if (itens.isEmpty)
          const Text('Nada no período')
        else
          Card(
            child: Column(
              children: [
                for (var i = 0; i < itens.length; i++)
                  ListTile(
                    dense: true,
                    leading: Text('${i + 1}º'),
                    title: Text(itens[i].nome),
                    trailing: Text(fmtQtd(v(itens[i])),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _secaoCursos(RelatorioDados d) {
    final linhas = _cursos(d);
    final total = linhas.fold(0, (s, c) => s + c.total);
    final estilo = Theme.of(context).textTheme.bodySmall;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text('Cursos e eventos ($total vendidos no período)',
            style: Theme.of(context).textTheme.titleMedium),
      ),
      if (_insc?.erro != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(_insc!.erro!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      if (linhas.isEmpty)
        const Text('Nenhum curso ou evento cadastrado no estoque (ambiente Gruta)')
      else
        Card(
          child: Column(
            children: [
              for (final c in linhas)
                ListTile(
                  dense: true,
                  title: Text(c.nome),
                  subtitle: Text(
                      'App: ${c.app} • Site: ${c.site} • Vagas restantes: ${c.vagas}',
                      style: estilo),
                  trailing: Text('${c.total}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final d = _dados;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório de estoque'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Exportar (PDF ou CSV)',
            onPressed: (_carregando || d == null)
                ? null
                : () => exportarRelatorio(context, _doc(d), 'sitio_estoque'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_carregando) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FiltroPeriodo(
                  selecionado: _periodo,
                  onChanged: (p) {
                    setState(() => _periodo = p);
                    _carregar();
                  },
                ),
                if (_erro != null)
                  Text(_erro!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                if (d != null) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _linha('Unidades que entraram', fmtQtd(d.totalEntradas)),
                          _linha('Unidades vendidas', fmtQtd(d.totalVendas)),
                          _linha('Unidades baixadas', '${d.qtdBaixas}'),
                          _linha('Itens movimentados', '${d.itens.length}'),
                        ],
                      ),
                    ),
                  ),
                  _lista('Mais vendidos / procurados', d.topPor((i) => i.vendas),
                      (i) => i.vendas),
                  _lista('Mais entraram no estoque', d.topPor((i) => i.entradas),
                      (i) => i.entradas),
                  _lista('Mais baixas (perda, validade, consumo)',
                      d.topPor((i) => i.baixas), (i) => i.baixas),
                  ..._secaoCursos(d),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaCurso {
  _LinhaCurso(this.nome, this.app, this.site, this.vagas);
  final String nome;
  final int app; // vendidos em comandas no app
  final int site; // pessoas inscritas pelo site
  final int vagas; // estoque atual
  int get total => app + site;
}
