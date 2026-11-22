import '../models/nota_importada.dart';

/// Limpa o número que vem antes do nome do item na nota fiscal.
///
/// - EAN com zero à esquerda (14 dígitos "0789...") vira EAN-13.
/// - Código interno da loja (itens por kg, ex.: "0000000013024") NÃO é código
///   de barras de produto: vira null para não poluir o campo.
/// - Número com dígito verificador inválido (provável erro de leitura) vira
///   null: melhor vazio do que um código errado.
class CodigoBarras {
  CodigoBarras._();

  static bool _gs1Valido(String d) {
    if (!RegExp(r'^\d+$').hasMatch(d)) return false;
    if (!{8, 12, 13, 14}.contains(d.length)) return false;
    var soma = 0;
    for (var i = 0; i < d.length - 1; i++) {
      final dig = int.parse(d[d.length - 2 - i]);
      soma += dig * (i.isEven ? 3 : 1);
    }
    return (10 - soma % 10) % 10 == int.parse(d[d.length - 1]);
  }

  static String? normalizar(String? raw) {
    if (raw == null) return null;
    var d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return null;
    if (d.startsWith('0000')) return null; // código interno da loja
    if (d.length == 14 && d.startsWith('0') && _gs1Valido(d.substring(1))) {
      return d.substring(1);
    }
    return _gs1Valido(d) ? d : null;
  }

  static void normalizarItens(List<NotaItem> itens) {
    for (final i in itens) {
      i.codigo = normalizar(i.codigo);
    }
  }
}
