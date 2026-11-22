/// Lote de um produto com data de validade (criado na reposição).
class Lote {
  Lote({
    required this.id,
    required this.produtoId,
    required this.quantidade,
    required this.validade,
  });

  final String id;
  final String produtoId;
  final int quantidade;
  final DateTime validade; // só a data (sem hora)

  /// Dias até vencer (negativo = vencido).
  int get diasRestantes {
    final h = DateTime.now();
    return validade.difference(DateTime(h.year, h.month, h.day)).inDays;
  }
}

String formatarData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
