import '../models/produto.dart';

/// Sugere qual produto do estoque corresponde a uma linha de nota.
///
/// Prefere acertar pouco a errar: se não houver certeza, devolve null e a
/// conferência deixa o usuário vincular na mão (ou cadastrar produto novo).
class ProdutoMatcher {
  ProdutoMatcher._();

  static const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  static const _semAcento = 'aaaaaeeeeiiiiooooouuuucn';

  /// minúsculas, sem acento, só letras/números, espaços simples.
  static String normalizar(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      final i = _comAcento.indexOf(ch);
      b.write(i >= 0 ? _semAcento[i] : ch);
    }
    return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  static Produto? sugerir(
    List<Produto> produtos,
    String nome, {
    String? codigoBarras,
  }) {
    // 1) código de barras idêntico
    final cod = codigoBarras?.trim();
    if (cod != null && cod.isNotEmpty) {
      for (final p in produtos) {
        if (p.codigoBarras == cod) return p;
      }
    }

    // 2) nome igual (ignorando acento/caixa) ou muito parecido
    final alvo = normalizar(nome);
    if (alvo.isEmpty) return null;
    final tokensAlvo = alvo.split(' ').toSet();

    Produto? melhor;
    var melhorScore = 0.0;
    for (final p in produtos) {
      final n = normalizar(p.nome);
      if (n == alvo) return p;
      final tokens = n.split(' ').toSet();
      final uniao = tokensAlvo.union(tokens).length;
      if (uniao == 0) continue;
      final score = tokensAlvo.intersection(tokens).length / uniao;
      if (score > melhorScore) {
        melhorScore = score;
        melhor = p;
      }
    }
    return melhorScore >= 0.6 ? melhor : null;
  }
}
