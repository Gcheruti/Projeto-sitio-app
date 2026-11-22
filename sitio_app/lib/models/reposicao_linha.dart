class LinhaRepos {
  LinhaRepos({
    required this.nome,
    this.produtoId,
    this.estoqueAtual = 0,
    this.qtdEntrada = 0,
    this.pendente = false,
    this.codigoBarras,
    this.validade,
  });

  String nome;
  String? produtoId;
  int estoqueAtual;
  int qtdEntrada;
  bool pendente;
  String? codigoBarras;

  /// Validade do lote que está entrando (opcional).
  DateTime? validade;
}