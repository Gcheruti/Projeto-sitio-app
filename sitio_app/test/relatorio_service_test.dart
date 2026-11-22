import 'package:flutter_test/flutter_test.dart';
import 'package:sitio_app/models/produto.dart';
import 'package:sitio_app/services/relatorio_service.dart';

void main() {
  final produtos = [
    Produto(id: 'a', nome: 'Agua', quantidade: 10, minimo: 2, preco: 5, ambiente: 'Salão'),
    Produto(id: 'b', nome: 'Cafe', quantidade: 3, minimo: 1, preco: 10, ambiente: 'Salão'),
  ];

  test('resumo, vendas por item e rateio do investimento', () {
    final d = RelatorioDados(
      DadosBrutos(
        fechamentos: [
          {
            'fechado_em': '2026-11-10T15:00:00Z',
            'valor_cobrado': 30,
            'pagamento': 'PIX',
            'itens_json': [
              {'produto_id': 'a', 'nome': 'Agua', 'quantidade': 4, 'subtotal': 20},
              {'produto_id': 'b', 'nome': 'Cafe', 'quantidade': 1, 'subtotal': 10},
            ],
          },
        ],
        reposicoes: [
          {'id': 'r1', 'valor_investido': 40},
        ],
        reposicoesItens: [
          {'reposicao_id': 'r1', 'produto_id': 'a', 'nome': 'Agua', 'quantidade_entrada': 10},
          {'reposicao_id': 'r1', 'produto_id': 'b', 'nome': 'Cafe', 'quantidade_entrada': 2},
        ],
        baixas: [
          {'produto_id': 'a', 'nome': 'Agua', 'quantidade': 1},
        ],
      ),
      produtos,
    );

    expect(d.totalCobrado, 30);
    expect(d.totalInvestido, 40);
    expect(d.saldo, -10);
    expect(d.comandasFechadas, 1);
    expect(d.qtdBaixas, 1);
    expect(d.pagamentos['PIX'], 30);

    final agua = d.itens.firstWhere((i) => i.produtoId == 'a');
    expect(agua.vendas, 4);
    expect(agua.baixas, 1);
    expect(agua.entradas, 10);
    // pesos: agua 10x5=50, cafe 2x10=20 -> agua recebe 40*50/70
    expect(agua.investido, closeTo(28.571, 0.01));
    expect(d.vendasPorProdutoId['a'], 4);
  });

  test('itens_json como texto e comPagamento', () {
    final b = DadosBrutos(fechamentos: [
      {
        'fechado_em': '2026-11-10T15:00:00Z',
        'total': 10,
        'pagamento': 'DINHEIRO',
        'itens_json': '[{"produto_id":"a","nome":"Agua","quantidade":2,"subtotal":10}]',
      },
    ]);
    expect(RelatorioDados(b, produtos).totalVendas, 2);
    expect(RelatorioDados(b.comPagamento('PIX'), produtos).comandasFechadas, 0);
  });
}
