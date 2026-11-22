import 'package:flutter/material.dart';

import '../services/relatorio_export.dart';
import '../services/relatorio_service.dart';
import '../state/app_state.dart';
import '../widgets/filtro_periodo.dart';

/// Itens com entradas e saídas no período, com valor investido e lucro.
class RelatorioItensScreen extends StatelessWidget {
  const RelatorioItensScreen({
    super.key,
    required this.dados,
    required this.periodoRotulo,
  });

  final RelatorioDados dados;
  final String periodoRotulo;

  String _descricao(MovItem i) {
    final p = i.produtoId == null ? null : appState.produtoPorId(i.produtoId!);
    if (p == null) return 'Item fora do cadastro';
    return '${p.ambiente} • venda ${fmtMoeda(p.preco)}'
        '${p.codigoBarras == null ? '' : ' • cód. ${p.codigoBarras}'}';
  }

  DocRel _doc(List<MovItem> itens) => DocRel(
        titulo: 'Sítio - Entradas e saídas por item',
        periodo: 'Período: $periodoRotulo (investido é estimado)',
        secoes: [
          SecaoRel(
            'Itens',
            [
              'Item',
              'Descrição',
              'Entradas',
              'Investido',
              'Vendas',
              'Baixas',
              'Receita',
              'Lucro',
            ],
            [
              for (final i in itens)
                [
                  i.nome,
                  _descricao(i),
                  fmtQtd(i.entradas),
                  fmtMoeda(i.investido),
                  fmtQtd(i.vendas),
                  fmtQtd(i.baixas),
                  fmtMoeda(i.receita),
                  fmtMoeda(i.lucro),
                ],
            ],
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final itens = dados.itens;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Itens: entradas e saídas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Exportar (PDF ou CSV)',
            onPressed: () =>
                exportarRelatorio(context, _doc(itens), 'sitio_itens'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Período: $periodoRotulo',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            'Investido é estimado: o valor de cada reposição é dividido entre '
            'os itens pela quantidade e pelo preço de venda. Lucro = receita '
            'das vendas - investido.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (itens.isEmpty) const Text('Nenhuma movimentação no período.'),
          for (final i in itens)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.nome, style: Theme.of(context).textTheme.titleSmall),
                    Text(_descricao(i),
                        style: Theme.of(context).textTheme.bodySmall),
                    const Divider(height: 20),
                    _par('Entradas', fmtQtd(i.entradas), 'Investido',
                        fmtMoeda(i.investido)),
                    const SizedBox(height: 6),
                    _par(
                      'Saídas',
                      '${fmtQtd(i.saidas)} (vendas ${fmtQtd(i.vendas)}, baixas ${fmtQtd(i.baixas)})',
                      'Lucro',
                      fmtMoeda(i.lucro),
                      corDir: i.lucro < 0 ? scheme.error : scheme.secondary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _par(String l1, String v1, String l2, String v2, {Color? corDir}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '$l1: '),
            TextSpan(
                text: v1, style: const TextStyle(fontWeight: FontWeight.bold)),
          ])),
        ),
        const SizedBox(width: 8),
        Text.rich(TextSpan(children: [
          TextSpan(text: '$l2: '),
          TextSpan(
              text: v2,
              style: TextStyle(fontWeight: FontWeight.bold, color: corDir)),
        ])),
      ],
    );
  }
}
