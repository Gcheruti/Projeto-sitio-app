import 'package:flutter/material.dart';

import '../models/lancamento.dart';
import '../services/financeiro_repository.dart';
import '../services/relatorio_service.dart';
import '../services/supabase_repository.dart';
import '../state/app_state.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/graficos_simples.dart';
import 'financeiro_screen.dart';
import 'relatorio_financeiro_screen.dart';

/// Financeiro em um só lugar: Resumo geral + Sítio (vendas/estoque) +
/// Cosmória (só a loja) + Toca dos Coelhos (gastos) + Cursos e eventos
/// (itens da Gruta vendidos no app + inscrições do site).
class FinanceiroHubScreen extends StatelessWidget {
  const FinanceiroHubScreen({super.key, this.abaInicial = 0});
  final int abaInicial;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: abaInicial,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Financeiro'),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: 'Resumo'),
              Tab(icon: Icon(Icons.storefront_outlined), text: 'Sítio'),
              Tab(icon: Icon(Icons.local_mall_outlined), text: 'Cosmória'),
              Tab(icon: Icon(Icons.cottage_outlined), text: 'Toca'),
              Tab(icon: Icon(Icons.school_outlined), text: 'Cursos e eventos'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ResumoGeral(),
            RelatorioFinanceiroScreen(embutido: true),
            RelatorioFinanceiroScreen(
              embutido: true,
              ambiente: 'Loja',
              titulo: 'Financeiro da Cosmória',
            ),
            FinanceiroScreen(embutido: true),
            RelatorioFinanceiroScreen(
              embutido: true,
              ambiente: 'Gruta',
              titulo: 'Cursos e eventos',
              cursos: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Visão consolidada: o que entrou e saiu no Sítio + gastos da Toca.
class _ResumoGeral extends StatefulWidget {
  const _ResumoGeral();

  @override
  State<_ResumoGeral> createState() => _ResumoState();
}

class _ResumoState extends State<_ResumoGeral>
    with AutomaticKeepAliveClientMixin {
  PeriodoSel _periodo = const PeriodoSel(PeriodoTipo.mes);
  bool _carregando = true;
  String? _erro;
  RelatorioDados? _sitio;
  List<Lancamento> _toca = [];
  bool _tocaOk = true;

  @override
  bool get wantKeepAlive => true;

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
      final b = await carregarDadosBrutos(
          SupabaseRepository(), _periodo.inicio, _periodo.fim);
      final s = RelatorioDados(b, appState.produtos);
      var toca = <Lancamento>[];
      var ok = true;
      try {
        toca = await FinanceiroRepository()
            .lancamentosPeriodo(_periodo.inicio, _periodo.fim);
      } catch (_) {
        ok = false; // tabelas do financeiro ainda não criadas
      }
      if (!mounted) return;
      setState(() {
        _sitio = s;
        _toca = toca;
        _tocaOk = ok;
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

  double _soma(bool Function(Lancamento) f) =>
      _toca.where(f).fold(0.0, (a, l) => a + l.valor);

  Widget _kpi(String t, double v, {Color? cor, String? dica}) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(fmtMoeda(v),
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, color: cor)),
                ),
                if (dica != null)
                  Text(dica, style: const TextStyle(fontSize: 10)),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final erro = Theme.of(context).colorScheme.error;
    final s = _sitio;

    final vendas = s?.totalCobrado ?? 0;
    final estoque = s?.totalInvestido ?? 0;
    final despesasToca = _soma((l) => l.despesa && l.pago);
    final aPagar = _soma((l) => l.despesa && !l.pago);
    final outrasReceitas = _soma((l) => !l.despesa && l.pago);
    final resultado = vendas + outrasReceitas - estoque - despesasToca;

    final porCat = <String, double>{};
    for (final l in _toca.where((l) => l.despesa)) {
      porCat[l.categoria] = (porCat[l.categoria] ?? 0) + l.valor;
    }
    final topCat = porCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: FiltroPeriodo(
            selecionado: _periodo,
            onChanged: (p) {
              _periodo = p;
              _carregar();
            },
          ),
        ),
        if (_carregando) const LinearProgressIndicator(),
        Expanded(
          child: _erro != null
              ? Center(child: Text(_erro!, style: TextStyle(color: erro)))
              : s == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Resultado do período',
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                const SizedBox(height: 4),
                                Text(fmtMoeda(resultado),
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: resultado < 0 ? erro : null)),
                                const Text(
                                  'vendas + outras receitas − estoque comprado − despesas pagas da Toca',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(children: [
                          _kpi('Vendas (Sítio)', vendas),
                          _kpi('Estoque comprado', estoque),
                        ]),
                        Row(children: [
                          _kpi('Despesas pagas (Toca)', despesasToca),
                          _kpi('A pagar (Toca)', aPagar,
                              cor: aPagar > 0 ? erro : null),
                        ]),
                        if (!_tocaOk)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: Text(
                              'Financeiro da Toca indisponível: rode financeiro.sql no Supabase.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                          child: Text('Para onde foi o dinheiro',
                              style: Theme.of(context).textTheme.titleSmall),
                        ),
                        GraficoHorizontal(
                          dados: [
                            ('Vendas', vendas),
                            ('Outras receitas', outrasReceitas),
                            ('Estoque', estoque),
                            ('Despesas Toca', despesasToca),
                          ],
                          formato: (v) => fmtMoeda(v),
                        ),
                        if (topCat.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                            child: Text('Maiores gastos da Toca',
                                style: Theme.of(context).textTheme.titleSmall),
                          ),
                          GraficoHorizontal(
                            dados: [
                              for (final e in topCat.take(5)) (e.key, e.value)
                            ],
                            formato: (v) => fmtMoeda(v),
                          ),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}
