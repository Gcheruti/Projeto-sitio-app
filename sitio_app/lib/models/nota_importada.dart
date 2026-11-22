/// Linha de uma nota/cupom lida (por foto ou QR Code).
///
/// Mutável de propósito: a tela de conferência edita estes objetos direto.
class NotaItem {
  NotaItem({
    required this.nome,
    this.quantidade = 1,
    this.valorUnitario,
    this.valorTotal,
    this.codigo,
    this.suspeito = false,
  });

  String nome;
  double quantidade;
  double? valorUnitario;
  double? valorTotal;

  /// Código/EAN impresso na linha (ajuda a achar o produto no estoque).
  String? codigo;

  /// true quando quantidade × unitário não bate com o total lido
  /// (provável erro de leitura). A conferência destaca essas linhas.
  bool suspeito;

  /// Total da linha: o lido, ou quantidade × unitário quando só há unitário.
  double? get totalCalculado {
    if (valorTotal != null) return valorTotal;
    final u = valorUnitario;
    return u == null ? null : quantidade * u;
  }

  NotaItem copy() => NotaItem(
        nome: nome,
        quantidade: quantidade,
        valorUnitario: valorUnitario,
        valorTotal: valorTotal,
        codigo: codigo,
        suspeito: suspeito,
      );
}

/// Contrato único de saída das leituras de nota.
/// A foto (OCR) e o QR Code (API de consulta) devolvem exatamente isto.
class NotaParseResult {
  NotaParseResult({
    required this.itens,
    this.totalNota,
    this.chaveAcesso,
    this.urlQr,
    this.fonte = 'foto',
    this.textoBruto = '',
    this.erro,
  });

  /// Resultado de falha, com mensagem pronta para mostrar ao usuário.
  factory NotaParseResult.falha(
    String erro, {
    String fonte = 'foto',
    String? chaveAcesso,
    String? urlQr,
    String textoBruto = '',
  }) =>
      NotaParseResult(
        itens: [],
        erro: erro,
        fonte: fonte,
        chaveAcesso: chaveAcesso,
        urlQr: urlQr,
        textoBruto: textoBruto,
      );

  final List<NotaItem> itens;
  final double? totalNota;
  final String? chaveAcesso;
  final String? urlQr;

  /// 'foto' | 'qr' | 'mock'
  final String fonte;

  /// Texto cru do OCR (vazio no QR). Guardado no rascunho para depuração.
  final String textoBruto;
  final String? erro;

  bool get ok => erro == null && itens.isNotEmpty;
}

/// Nota importada guardada no Supabase (cabeçalho + itens).
/// status: rascunho (pendente de conferência) | confirmada | cancelada
class NotaImportada {
  NotaImportada({
    this.id,
    required this.origem,
    this.status = 'rascunho',
    this.chaveAcesso,
    this.urlQr,
    this.totalNota,
    this.textoBruto = '',
    this.qtdFotos = 0,
    List<NotaItem>? itens,
    this.criadoEm,
  }) : itens = itens ?? [];

  /// null enquanto o rascunho não foi gravado no servidor.
  String? id;

  /// 'foto' | 'qr'
  final String origem;
  String status;
  String? chaveAcesso;
  String? urlQr;
  double? totalNota;
  String textoBruto;
  int qtdFotos;
  final List<NotaItem> itens;
  DateTime? criadoEm;
}
