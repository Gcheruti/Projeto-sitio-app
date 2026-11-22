import 'package:flutter/material.dart';

import '../services/inscricoes_site.dart';
import '../services/relatorio_export.dart';
import '../services/relatorio_service.dart';
import '../services/supabase_repository.dart';
import '../state/app_state.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/graficos_simples.dart';
import 'relatorio_itens_screen.dart';

class RelatorioFinanceiroScreen extends StatefulWidget {
  const RelatorioFinanceiroScreen({
    super.key,
    this.embutido = false,
    this.ambiente,
    this.titulo = 'Financeiro do Sítio',
    this.cursos = false,
  });

  /// true = aba "Cursos e eventos": mostra também as inscrições do site.
  final bool cursos;

  /// null = tudo; 'Loja' = só a Cosmória.
  final String? ambiente;
  final String titulo;

  /// true = dentro das abas do Financeiro (sem barra de título própria).
  final bool embutido;

  @override
  State<RelatorioFinanceiroScreen> createState() =>
      _RelatorioFinanceiroScreenState();
}

class _RelatorioFinanceiroScreenState extends State<RelatorioFinanceiroScreen> {
  final _repo = SupabaseRepository();

  PeriodoSel _periodo = const PeriodoSel(PeriodoTipo.dias7);
  String? _pagamento; // null = todas as formas
  bool _carregando = false;
  String? _erro;
  DadosBrutos _bruto = DadosBrutos();

  /// Dados já filtrados por pagamento e ambiente: é o que as LISTAS e o
  /// PDF/CSV mostram, para bater com os totais do resumo.
  DadosBrutos _vista = DadosBrutos();
  RelatorioDados? _dados;
  InscricoesResultado? _insc;

  static const _pagamentos = ['PIX', 'CARTAO', 'DINHEIRO'];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _recalcular() {
    _vista = _bruto
        .comPagamento(_pagamento)
        .comAmbiente(widget.ambiente, appState.produtos);
    _dados = RelatorioDados(_vista, appState.produtos);
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final fInsc = widget.cursos
          ? buscarInscricoesSite(_periodo.inicio, _periodo.fim)
          : null;
      final b = await carregarDadosBrutos(_repo, _periodo.inicio, _periodo.fim);
      final insc = fInsc == null ? null : await fInsc;
      if (!mounted) return;
      setState(() {
        _bruto = b;
        _insc = insc;
        _recalcular();
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

  String _s(dynamic v) => v?.toString() ?? '';

  double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  String _dataStr(dynamic v) {
    final d = DateTime.tryParse(_s(v))?.toLocal();
    return d == null ? '-' : fmtData(d);
  }

  /// Faturamento por dia; em períodos longos agrupa por semana.
  List<(String, double)> _serieFaturamento(RelatorioDados d) {
    final ini = _periodo.inicio;
    final dias = _periodo.fim.difference(ini).inDays;
    final out = <(String, double)>[];
    if (dias <= 31) {
      for (var i = 0; i < dias; i++) {
        final dia = ini.add(Duration(days: i));
        out.add((dia.day.toString(), d.faturamentoPorDia[dia] ?? 0));
      }
    } else {
      for (var i = 0; i < dias; i += 7) {
        var soma = 0.0;
        for (var j = i; j < i + 7 && j < dias; j++) {
          soma += d.faturamentoPorDia[ini.add(Duration(days: j))] ?? 0;
        }
        final dia = ini.add(Duration(days: i));
        out.add(('${dia.day}/${dia.month}', soma));
      }
    }
    return out;
  }

  DocRel _doc(RelatorioDados d) {
    return DocRel(
      titulo: widget.cursos
          ? 'Cursos e eventos - Relatório financeiro'
          : widget.ambiente == null
              ? 'Sítio - Relatório financeiro geral'
              : 'Cosmória - Relatório financeiro',
      periodo:
          'Período: ${_periodo.rotulo}${_pagamento == null ? '' : ' | Pagamento: $_pagamento'}',
      secoes: [
        SecaoRel('Resumo', ['Indicador', 'Valor'], [
          ['Total cobrado', fmtMoeda(d.totalCobrado)],
          ['Total investido', fmtMoeda(d.totalInvestido)],
          ['Saldo (cobrado - investido)', fmtMoeda(d.saldo)],
          ['Comandas fechadas', '${d.comandasFechadas}'],
          ['Ticket médio', fmtMoeda(d.ticketMedio)],
          ['Reposições', '${d.qtdReposicoes}'],
          ['Qtd. baixas', '${d.qtdBaixas}'],
        ]),
        if (widget.cursos && _insc != null) ...[
          SecaoRel('Inscrições pelo site', ['Indicador', 'Valor'], [
            ['Inscrições válidas', '${_insc!.validas.length}'],
            ['Pessoas', '${_insc!.pessoas}'],
            ['Valor previsto', fmtMoeda(_insc!.valor)],
            ['Sem vagas', '${_insc!.contar('sem_vaga')}'],
            ['Sem item no estoque', '${_insc!.contar('sem_produto')}'],
            ['Canceladas', '${_insc!.contar('cancelado')}'],
          ]),
          SecaoRel('Inscrições (site)',
              ['Data', 'Curso/evento', 'Pessoas', 'Valor', 'Situação'], [
            for (final i in _insc!.lista)
              [
                fmtData(i.criadoEm),
                i.nome,
                '${i.quantidade}',
                fmtMoeda(i.valorTotal),
                i.statusTexto,
              ],
          ]),
        ],
        SecaoRel(
          'Fechamentos',
          ['Data', 'Comanda', 'Pagamento', 'Valor'],
          [
            for (final f in _vista.fechamentos)
              [
                _dataStr(f['fechado_em']),
                _s(f['codigo'] ?? f['comanda_codigo']),
                _s(f['pagamento']),
                fmtMoeda(_d(f['valor_cobrado'] ?? f['total_itens'] ?? f['total'])),
              ],
          ],
        ),
        SecaoRel('Reposições', ['Data', 'Valor investido'], [
          for (final r in _vista.reposicoes)
            [_dataStr(r['criado_em']), fmtMoeda(_d(r['valor_investido']))],
        ]),
        SecaoRel('Baixas', ['Data', 'Produto', 'Qtd', 'Motivo'], [
          for (final b in _vista.baixas)
            [
              _dataStr(b['criado_em']),
              _s(b['nome']),
              _s(b['quantidade']),
              _s(b['motivo']),
            ],
        ]),
      ],
    );
  }

  Widget _titulo(String t) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(t, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _grafico(String titulo, String sub, Widget g) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.titleSmall),
              Text(sub, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              g,
            ],
          ),
        ),
      );

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

  /// Aba Cursos e eventos: inscrições feitas pelo site no período.
  List<Widget> _secaoSite() {
    final r = _insc;
    if (r == null) return const [];
    return [
      _titulo('Inscrições pelo site (${r.lista.length})'),
      if (r.erro != null)
        Text(r.erro!, style: TextStyle(color: Theme.of(context).colorScheme.error))
      else ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _linha('Inscrições válidas', '${r.validas.length}'),
                _linha('Pessoas', '${r.pessoas}'),
                _linha('Valor previsto (preço × pessoas)', fmtMoeda(r.valor)),
                if (r.contar('sem_vaga') > 0)
                  _linha('Sem vagas no estoque', '${r.contar('sem_vaga')}'),
                if (r.contar('sem_produto') > 0)
                  _linha('Sem item no estoque', '${r.contar('sem_produto')}'),
                if (r.contar('cancelado') > 0)
                  _linha('Canceladas', '${r.contar('cancelado')}'),
              ],
            ),
          ),
        ),
        if (r.lista.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Nenhuma inscrição no período'),
          )
        else
          for (final i in r.lista.take(30))
            Card(
              child: ListTile(
                leading: Icon(
                  i.categoria == 'curso' ? Icons.school_outlined : Icons.event_outlined,
                ),
                title: Text(i.nome),
                subtitle: Text('${fmtData(i.criadoEm)} • ${i.quantidade} '
                    '${i.quantidade == 1 ? 'pessoa' : 'pessoas'} • ${i.statusTexto}'),
                trailing: Text(fmtMoeda(i.valorTotal)),
              ),
            ),
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Valor previsto: inscrição pelo site ainda não é pagamento. '
            'O resto desta aba são vendas no app de itens da Gruta.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final d = _dados;
    final scheme = Theme.of(context).colorScheme;
    final exportar = IconButton(
      icon: const Icon(Icons.share_outlined),
      tooltip: 'Exportar (PDF ou CSV)',
      onPressed: (_carregando || d == null)
          ? null
          : () => exportarRelatorio(context, _doc(d),
              widget.cursos
                  ? 'cursos_eventos_financeiro'
                  : widget.ambiente == null
                      ? 'sitio_financeiro'
                      : 'cosmoria_financeiro'),
    );
    return Scaffold(
      appBar: widget.embutido
          ? null
          : AppBar(title: Text(widget.titulo), actions: [exportar]),
      body: Column(
        children: [
          if (widget.embutido)
            Align(alignment: Alignment.centerRight, child: exportar),
          if (_carregando) const LinearProgressIndicator(),
          Expanded(
            child: d == null
                ? Center(
                    child: _erro != null
                        ? Text(_erro!, style: TextStyle(color: scheme.error))
                        : const SizedBox.shrink(),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_erro != null)
                        Text(_erro!, style: TextStyle(color: scheme.error)),
                      // ---------- Dashboard ----------
                      _grafico(
                        'Faturamento por dia',
                        'Total cobrado nas comandas fechadas',
                        GraficoBarras(
                          dados: _serieFaturamento(d),
                          mostrarValores: _serieFaturamento(d).length <= 8,
                          formato: (v) => v.toStringAsFixed(0),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _grafico(
                        'Itens mais vendidos',
                        'Unidades vendidas no período',
                        GraficoHorizontal(
                          dados: [
                            for (final i in d.topPor((i) => i.vendas, limite: 5))
                              (i.nome, i.vendas),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _grafico(
                        'Cobrado x investido',
                        'Saldo = cobrado - investido em reposição',
                        GraficoHorizontal(
                          dados: [
                            ('Cobrado', d.totalCobrado),
                            ('Investido', d.totalInvestido),
                            ('Saldo', d.saldo),
                          ],
                          cores: [
                            scheme.primary,
                            scheme.tertiary,
                            d.saldo >= 0 ? scheme.secondary : scheme.error,
                          ],
                          formato: fmtMoeda,
                        ),
                      ),
                      if (widget.cursos) ..._secaoSite(),
                      // ---------- Filtros ----------
                      _titulo('Filtros'),
                      FiltroPeriodo(
                        selecionado: _periodo,
                        onChanged: (p) {
                          setState(() => _periodo = p);
                          _carregar();
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final p in [null, ..._pagamentos])
                            ChoiceChip(
                              label: Text(p ?? 'Todos os pagamentos'),
                              selected: _pagamento == p,
                              onSelected: (_) => setState(() {
                                _pagamento = p;
                                _recalcular();
                              }),
                            ),
                        ],
                      ),
                      // ---------- Resumo ----------
                      _titulo('Resumo'),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              _linha('Total cobrado', fmtMoeda(d.totalCobrado)),
                              _linha('Total investido', fmtMoeda(d.totalInvestido)),
                              _linha('Saldo', fmtMoeda(d.saldo)),
                              _linha('Comandas fechadas', '${d.comandasFechadas}'),
                              _linha('Ticket médio', fmtMoeda(d.ticketMedio)),
                              _linha('Reposições', '${d.qtdReposicoes}'),
                              _linha('Qtd. baixas', '${d.qtdBaixas}'),
                            ],
                          ),
                        ),
                      ),
                      _titulo(
                          'Fechamentos (${_vista.fechamentos.length})'),
                      if (_vista.fechamentos.isEmpty)
                        const Text('Nenhum no período')
                      else
                        for (final f in _vista.fechamentos)
                          Card(
                            child: ListTile(
                              title: Text(_s(f['codigo'] ?? f['comanda_codigo'])),
                              subtitle: Text(
                                  '${_dataStr(f['fechado_em'])} • ${_s(f['pagamento'])}'),
                              trailing: Text(fmtMoeda(_d(f['valor_cobrado'] ??
                                  f['total_itens'] ??
                                  f['total']))),
                            ),
                          ),
                      _titulo('Reposições (${_vista.reposicoes.length})'),
                      if (_vista.reposicoes.isEmpty)
                        const Text('Nenhuma no período')
                      else
                        for (final r in _vista.reposicoes)
                          Card(
                            child: ListTile(
                              title: Text(_dataStr(r['criado_em'])),
                              trailing: Text(fmtMoeda(_d(r['valor_investido']))),
                            ),
                          ),
                      _titulo('Baixas (${_vista.baixas.length})'),
                      if (_vista.baixas.isEmpty)
                        const Text('Nenhuma no período')
                      else
                        for (final b in _vista.baixas)
                          Card(
                            child: ListTile(
                              title: Text(_s(b['nome'])),
                              subtitle: Text(
                                  '${_dataStr(b['criado_em'])} • ${_s(b['motivo'])}'),
                              trailing: Text('-${_s(b['quantidade'])}'),
                            ),
                          ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        icon: const Icon(Icons.list_alt),
                        label: const Text('Entradas e saídas por item'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RelatorioItensScreen(
                              dados: d,
                              periodoRotulo: _periodo.rotulo,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
