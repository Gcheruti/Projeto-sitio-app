import '../models/nota_importada.dart';
import 'codigo_barras.dart';

/// Leitura da consulta pública da NFC-e de SP (página HTML do QR Code).
/// Dart puro: roda no próprio celular e dá para testar com `flutter test`.
class NfceAlvo {
  NfceAlvo({this.chave, this.url, this.erro});
  final String? chave;
  final String? url;
  final String? erro;
}

class NfceSpParser {
  NfceSpParser._();

  static const _hostsSp = {'www.nfce.fazenda.sp.gov.br', 'nfce.fazenda.sp.gov.br'};

  /// Dígito verificador da chave (módulo 11).
  static bool chaveValida(String chave) {
    if (!RegExp(r'^\d{44}$').hasMatch(chave)) return false;
    var soma = 0;
    var peso = 2;
    for (var i = 42; i >= 0; i--) {
      soma += int.parse(chave[i]) * peso;
      peso = peso == 9 ? 2 : peso + 1;
    }
    final resto = soma % 11;
    final dv = resto < 2 ? 0 : 11 - resto;
    return dv == int.parse(chave[43]);
  }

  /// Valida a chave e decide a URL. Só consulta hosts da SEFAZ-SP.
  static NfceAlvo montarAlvo(String raw) {
    final txt = raw.trim();
    final chave = RegExp(r'\d{44}').firstMatch(txt)?.group(0);
    if (chave == null) {
      return NfceAlvo(erro: 'Não encontrei a chave de 44 dígitos no QR Code.');
    }
    if (!chaveValida(chave)) {
      return NfceAlvo(erro: 'Chave de acesso inválida (dígito verificador não confere).');
    }
    if (chave.substring(0, 2) != '35') {
      return NfceAlvo(erro: 'Esta nota não é de São Paulo.');
    }
    if (chave.substring(20, 22) != '65') {
      return NfceAlvo(erro: 'Esta chave não é de NFC-e.');
    }
    final u = Uri.tryParse(txt);
    if (u != null && u.scheme == 'https' && _hostsSp.contains(u.host)) {
      return NfceAlvo(chave: chave, url: txt); // exatamente como veio no QR
    }
    return NfceAlvo(
      chave: chave,
      url: 'https://www.nfce.fazenda.sp.gov.br/qrcode?p=$chave|3|1',
    );
  }

  static String _decode(String s) => s
      .replaceAll(RegExp('&nbsp;', caseSensitive: false), ' ')
      .replaceAll(RegExp('&amp;', caseSensitive: false), '&')
      .replaceAll(RegExp('&lt;', caseSensitive: false), '<')
      .replaceAll(RegExp('&gt;', caseSensitive: false), '>')
      .replaceAll(RegExp('&quot;', caseSensitive: false), '"')
      .replaceAllMapped(RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)));

  static String _texto(String h) =>
      _decode(h.replaceAll(RegExp(r'<[^>]+>'), ' '))
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  /// "1.299,90" | "2,50" | "1.5" | "R$ 3,00" → número.
  static double? numBR(String? s) {
    if (s == null) return null;
    final m = RegExp(r'\d[\d.,]*').firstMatch(s);
    if (m == null) return null;
    var t = m.group(0)!;
    if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t);
  }

  static String _span(String bloco, String cls) {
    final re = RegExp(
      '<span[^>]*class=["\'][^"\']*\\b$cls\\b[^"\']*["\'][^>]*>([\\s\\S]*?)</span>',
      caseSensitive: false,
    );
    final m = re.firstMatch(bloco);
    return m == null ? '' : _texto(m.group(1)!);
  }

  /// Layout clássico: spans txtTit / RCod / Rqtd / RvlUnit / valor.
  static NotaParseResult parseHtml(String html,
      {String? chave, String? urlQr}) {
    final itens = <NotaItem>[];
    for (final bloco in html.split(RegExp(r'<tr[\s>]', caseSensitive: false))) {
      if (!RegExp('class=["\'][^"\']*\\btxtTit\\b', caseSensitive: false)
              .hasMatch(bloco) ||
          !RegExp(r'\bRqtd\b', caseSensitive: false).hasMatch(bloco)) {
        continue;
      }
      final nome = _span(bloco, 'txtTit');
      if (nome.isEmpty) continue;
      final qtd = numBR(_span(bloco, 'Rqtd')) ?? 1;
      final unit = numBR(_span(bloco, 'RvlUnit'));
      final total = numBR(_span(bloco, 'valor')) ??
          (unit == null ? null : (unit * qtd * 100).round() / 100);
      final txtBloco = _texto(bloco);
      final cod = RegExp(r'\d{3,}').firstMatch(_span(bloco, 'RCod'))?.group(0) ??
          RegExp(r'C[oó]digo:?\s*(\d{6,14})', caseSensitive: false)
              .firstMatch(txtBloco)
              ?.group(1) ??
          RegExp(r'(?<![\d.,])\d{8,14}(?![\d.,])').firstMatch(txtBloco)?.group(0);
      itens.add(NotaItem(
        nome: nome,
        quantidade: qtd,
        valorUnitario: unit,
        valorTotal: total,
        codigo: CodigoBarras.normalizar(cod),
      ));
    }

    double? totalNota;
    final mt = RegExp(
      '<span[^>]*class=["\'][^"\']*\\btotalNumb\\b[^"\']*\\btxtMax\\b[^"\']*["\'][^>]*>([\\s\\S]*?)</span>',
      caseSensitive: false,
    ).firstMatch(html);
    if (mt != null) totalNota = numBR(_texto(mt.group(1)!));
    totalNota ??= itens.isEmpty
        ? null
        : itens.fold<double>(0, (a, i) => a + (i.valorTotal ?? 0));

    return NotaParseResult(
      itens: itens,
      totalNota: totalNota,
      chaveAcesso: chave,
      urlQr: urlQr,
      fonte: 'qr',
    );
  }
}
