class ItemComanda {
  ItemComanda({
    required this.produtoId,
    required this.nome,
    required this.quantidade,
    required this.precoUnitario,
    this.processual = false,
    this.statusPreparo,
    this.desconto = 0,
  });

  final String produtoId;
  final String nome;
  int quantidade;
  final double precoUnitario;

  /// Veio de produto processual (passa por preparo).
  final bool processual;

  /// 'aberto' | 'preparo' | 'finalizado' (null se não for processual).
  String? statusPreparo;

  bool get emAndamento =>
      processual && quantidade > 0 && statusPreparo != 'finalizado';

  /// Desconto em R$ aplicado a este item (linha inteira).
  double desconto;

  double get bruto => quantidade * precoUnitario;

  double get subtotal {
    final v = bruto - desconto;
    return v < 0 ? 0 : v;
  }
}

class Comanda {
  Comanda({
    required this.id,
    required this.codigo,
    required this.status,
    List<ItemComanda>? itens,
    this.formaPagamento,
  }) : itens = itens ?? [];

  final String id;
  final String codigo;
  String status; // ativa | inativa
  final List<ItemComanda> itens;
  String? formaPagamento; // PIX | CARTAO | DINHEIRO

  bool get isAtiva => status == 'ativa';

  /// Itens processuais ainda não finalizados.
  List<ItemComanda> get itensEmAndamento =>
      itens.where((i) => i.emAndamento).toList();

  /// Todos os itens processuais com quantidade (para o acompanhamento).
  List<ItemComanda> get itensProcessuais =>
      itens.where((i) => i.processual && i.quantidade > 0).toList();

  double get total => itens.fold(0.0, (s, i) => s + i.subtotal);

  String get resumoItens {
    final comQtd = itens.where((i) => i.quantidade > 0).toList();
    if (comQtd.isEmpty) return 'Sem itens';
    return comQtd
        .take(3)
        .map((i) => '${i.quantidade}x ${i.nome}')
        .join(' • ');
  }
}

/// Uma parte do pagamento quando a comanda é dividida entre pessoas.
class PagamentoParte {
  PagamentoParte({required this.forma, required this.valor, this.pago = false});

  String forma; // PIX | CARTAO | DINHEIRO
  double valor;
  bool pago;

  Map<String, dynamic> toMap() => {'forma': forma, 'valor': valor, 'pago': pago};
}
