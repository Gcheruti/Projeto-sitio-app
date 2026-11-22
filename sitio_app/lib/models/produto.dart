class Produto {
  Produto({
    required this.id,
    required this.nome,
    required this.quantidade,
    required this.minimo,
    required this.preco,
    required this.ambiente,
    this.codigoBarras,
    this.processual = false,
    this.subcategoria,
    this.publico = true,
    this.controlaEstoque = true,
    this.diasAvisoValidade = 3,
  });

  final String id;
  String nome;
  int quantidade;
  int minimo;
  double preco;
  String ambiente;
  String? codigoBarras;

  /// Produto que passa por preparo (aparece na aba Pedidos ao entrar na comanda).
  bool processual;

  String? subcategoria;

  /// Voltado ao público: só estes aparecem para adicionar à comanda.
  bool publico;

  /// false = item preparado no dia (ex.: pudim): sem mínimo nem alerta de
  /// estoque baixo; a quantidade é o que foi preparado e ainda não saiu.
  bool controlaEstoque;

  /// Quantos dias antes de vencer o app avisa (cada item tem sua urgência).
  int diasAvisoValidade;

  bool get estoqueBaixo => controlaEstoque && quantidade <= minimo;

  Produto copyWith({
    String? nome,
    int? quantidade,
    int? minimo,
    double? preco,
    String? ambiente,
    String? codigoBarras,
    bool? processual,
    String? subcategoria,
    bool limparSubcategoria = false,
    bool? publico,
    bool? controlaEstoque,
    int? diasAvisoValidade,
  }) {
    return Produto(
      id: id,
      nome: nome ?? this.nome,
      quantidade: quantidade ?? this.quantidade,
      minimo: minimo ?? this.minimo,
      preco: preco ?? this.preco,
      ambiente: ambiente ?? this.ambiente,
      codigoBarras: codigoBarras ?? this.codigoBarras,
      processual: processual ?? this.processual,
      subcategoria:
          limparSubcategoria ? null : (subcategoria ?? this.subcategoria),
      publico: publico ?? this.publico,
      controlaEstoque: controlaEstoque ?? this.controlaEstoque,
      diasAvisoValidade: diasAvisoValidade ?? this.diasAvisoValidade,
    );
  }
}