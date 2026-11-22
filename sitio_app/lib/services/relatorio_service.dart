import 'dart:convert';

import '../models/produto.dart';
import 'supabase_repository.dart';

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

String _s(dynamic v) => v?.toString() ?? '';

DateTime? _data(dynamic v) {
  if (v == null) return null;
  return DateTime.tryParse(v.toString())?.toLocal();
}

/// Dados crus do período, como vêm do Supabase.
class DadosBrutos {
  DadosBrutos({
    this.fechamentos = const [],
    this.reposicoes = const [],
    this.reposicoesItens = const [],
    this.baixas = const [],
  });

  final List<Map<String, dynamic>> fechamentos;
  final List<Map<String, dynamic>> reposicoes;
  final List<Map<String, dynamic>> reposicoesItens;
  final List<Map<String, dynamic>> baixas;

  /// Só os fechamentos da forma de pagamento (null = todos).
  DadosBrutos comPagamento(String? pagamento) {
    if (pagamento == null) return this;
    return DadosBrutos(
      fechamentos: fechamentos
          .where((f) => _s(f['pagamento']).toUpperCase() == pagamento)
          .toList(),
      reposicoes: reposicoes,
      reposicoesItens: reposicoesItens,
      baixas: baixas,
    );
  }

  /// Só o que é de um ambiente (ex.: 'Loja' = Cosmória): itens vendidos,
  /// reposições (valor proporcional aos itens do ambiente) e baixas.
  /// Descontos dados na comanda não são rateados: vale o subtotal dos itens.
  DadosBrutos comAmbiente(String? ambiente, List<Produto> produtos) {
    if (ambiente == null) return this;
    final ids = {
      for (final p in produtos)
        if (p.ambiente == ambiente) p.id
    };
    final preco = {for (final p in produtos) p.id: p.preco};

    final fech = <Map<String, dynamic>>[];
    for (final f in fechamentos) {
      final itens = RelatorioDados._lista(f['itens_json'])
          .where((it) => ids.contains(_s(it['produto_id'])))
          .toList();
      if (itens.isEmpty) continue;
      var total = 0.0;
      for (final it in itens) {
        total += it['subtotal'] != null
            ? _d(it['subtotal'])
            : _d(it['quantidade']) * _d(it['preco_unitario']);
      }
      fech.add({
        ...f,
        'itens_json': itens,
        'valor_cobrado': total,
        'total_itens': total,
        'total': total,
      });
    }

    final itensRep =
        reposicoesItens.where((ri) => ids.contains(_s(ri['produto_id']))).toList();
    double peso(Map<String, dynamic> ri) {
      final p = preco[_s(ri['produto_id'])] ?? 0;
      return _d(ri['quantidade_entrada']) * (p > 0 ? p : 1);
    }

    final reps = <Map<String, dynamic>>[];
    for (final r in reposicoes) {
      final todos =
          reposicoesItens.where((ri) => _s(ri['reposicao_id']) == _s(r['id']));
      final soma = todos.fold(0.0, (a, ri) => a + peso(ri));
      final meus = todos
          .where((ri) => ids.contains(_s(ri['produto_id'])))
          .fold(0.0, (a, ri) => a + peso(ri));
      if (meus <= 0 || soma <= 0) continue;
      reps.add({...r, 'valor_investido': _d(r['valor_investido']) * meus / soma});
    }

    return DadosBrutos(
      fechamentos: fech,
      reposicoes: reps,
      reposicoesItens: itensRep,
      baixas: baixas.where((b) => ids.contains(_s(b['produto_id']))).toList(),
    );
  }
}

Future<DadosBrutos> carregarDadosBrutos(
  SupabaseRepository repo,
  DateTime inicio,
  DateTime fim,
) async {
  final f = await repo.fetchFechamentos(inicio: inicio, fim: fim);
  final r = await repo.fetchReposicoes(inicio: inicio, fim: fim);
  final b = await repo.fetchBaixas(inicio: inicio, fim: fim);
  final ids = r.map((x) => _s(x['id'])).where((x) => x.isNotEmpty).toList();
  final ri = await repo.fetchReposicoesItens(ids);
  return DadosBrutos(
    fechamentos: f,
    reposicoes: r,
    reposicoesItens: ri,
    baixas: b,
  );
}

/// Movimentação de um item no período.
class MovItem {
  MovItem(this.chave, this.nome, {this.produtoId});

  final String chave;
  String nome;
  final String? produtoId;
  double entradas = 0; // unidades repostas
  double vendas = 0; // unidades vendidas em comandas
  double baixas = 0; // perdas/validade/consumo
  double receita = 0;

  /// Estimado: o valor investido da reposição é rateado entre os itens
  /// proporcionalmente a (quantidade × preço de venda).
  double investido = 0;

  double get saidas => vendas + baixas;
  double get lucro => receita - investido;
}

class RelatorioDados {
  RelatorioDados(DadosBrutos bruto, List<Produto> produtos) {
    _calcular(bruto, produtos);
  }

  final Map<String, MovItem> _itens = {};
  final Map<DateTime, double> faturamentoPorDia = {};
  final Map<String, double> pagamentos = {};

  double totalCobrado = 0;
  double totalInvestido = 0;
  int comandasFechadas = 0;
  int qtdBaixas = 0;
  int qtdReposicoes = 0;

  double get saldo => totalCobrado - totalInvestido;
  double get ticketMedio =>
      comandasFechadas == 0 ? 0 : totalCobrado / comandasFechadas;

  List<MovItem> get itens {
    final l = _itens.values.toList();
    l.sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
    return l;
  }

  double get totalEntradas => _itens.values.fold(0.0, (s, i) => s + i.entradas);
  double get totalVendas => _itens.values.fold(0.0, (s, i) => s + i.vendas);

  /// Unidades vendidas por id de produto.
  Map<String, double> get vendasPorProdutoId => {
        for (final i in _itens.values)
          if (i.produtoId != null && i.vendas > 0) i.produtoId!: i.vendas,
      };

  List<MovItem> topPor(double Function(MovItem) valor, {int limite = 10}) {
    final l = _itens.values.where((i) => valor(i) > 0).toList();
    l.sort((a, b) => valor(b).compareTo(valor(a)));
    return l.take(limite).toList();
  }

  MovItem _item(String? produtoId, String nome) {
    final chave = (produtoId != null && produtoId.isNotEmpty)
        ? produtoId
        : 'n:${nome.trim().toLowerCase()}';
    return _itens.putIfAbsent(
      chave,
      () => MovItem(chave, nome,
          produtoId: (produtoId != null && produtoId.isNotEmpty)
              ? produtoId
              : null),
    );
  }

  static List<Map<String, dynamic>> _lista(dynamic raw) {
    var v = raw;
    if (v is String) {
      try {
        v = jsonDecode(v);
      } catch (_) {
        return [];
      }
    }
    if (v is! List) return [];
    return v
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  void _calcular(DadosBrutos b, List<Produto> produtos) {
    final precoPorId = {for (final p in produtos) p.id: p.preco};

    // fechamentos: cobrado, forma de pagamento, itens vendidos
    comandasFechadas = b.fechamentos.length;
    for (final f in b.fechamentos) {
      final valor = f['valor_cobrado'] != null
          ? _d(f['valor_cobrado'])
          : _d(f['total_itens'] ?? f['total']);
      totalCobrado += valor;

      final pag = _s(f['pagamento']).isEmpty
          ? 'OUTROS'
          : _s(f['pagamento']).toUpperCase();
      pagamentos[pag] = (pagamentos[pag] ?? 0) + valor;

      final dt = _data(f['fechado_em']);
      if (dt != null) {
        final dia = DateTime(dt.year, dt.month, dt.day);
        faturamentoPorDia[dia] = (faturamentoPorDia[dia] ?? 0) + valor;
      }

      for (final it in _lista(f['itens_json'])) {
        final qtd = _d(it['quantidade']);
        if (qtd <= 0) continue;
        final m = _item(_s(it['produto_id']), _s(it['nome']));
        m.vendas += qtd;
        m.receita += it['subtotal'] != null
            ? _d(it['subtotal'])
            : qtd * _d(it['preco_unitario']);
      }
    }

    // reposições: entradas e investimento (rateado por item)
    qtdReposicoes = b.reposicoes.length;
    final itensPorRepos = <String, List<Map<String, dynamic>>>{};
    for (final ri in b.reposicoesItens) {
      itensPorRepos.putIfAbsent(_s(ri['reposicao_id']), () => []).add(ri);
    }
    for (final r in b.reposicoes) {
      final valor = _d(r['valor_investido']);
      totalInvestido += valor;
      final linhas = itensPorRepos[_s(r['id'])] ?? const [];
      var soma = 0.0;
      final pesos = <double>[];
      for (final ri in linhas) {
        final qtd = _d(ri['quantidade_entrada']);
        final preco = precoPorId[_s(ri['produto_id'])] ?? 0;
        final w = qtd * (preco > 0 ? preco : 1);
        pesos.add(w);
        soma += w;
      }
      for (var i = 0; i < linhas.length; i++) {
        final ri = linhas[i];
        final qtd = _d(ri['quantidade_entrada']);
        final m = _item(_s(ri['produto_id']), _s(ri['nome']));
        m.entradas += qtd;
        if (soma > 0) m.investido += valor * pesos[i] / soma;
      }
    }

    // baixas
    for (final bx in b.baixas) {
      final qtd = _d(bx['quantidade']);
      qtdBaixas += qtd.round();
      final m = _item(_s(bx['produto_id']), _s(bx['nome']));
      m.baixas += qtd;
    }
  }
}
