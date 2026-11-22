import '../models/nota_importada.dart';
import 'codigo_barras.dart';

/// Converte o texto de um cupom/NFC-e/DANFE (saída do OCR) em itens.
///
/// Dart puro, sem plugins: dá para testar com `flutter test`.
///
/// Formatos reconhecidos (cupons brasileiros variam muito):
///  1. Uma linha:   `001 7891000100103 AGUA MINERAL 500ML 12 UN x 2,50 30,00`
///  2. Duas linhas: `CAFE PILAO 500G` + `2 UN x 7,95 15,90`
///  3. Rotulado:    `Qtde.:24 UN Vl. Unit.: 3,49 Vl. Total 83,76` (nome na linha de cima)
///  4. Quebrado:    NFC-e de SP: item em 2-3 linhas e ponto decimal
///                  (`100049219 AGUA 1.00 X` / `UN 6.990 6.99`). Só é tentado
///                  quando as passadas por linha não acham nada.
///
/// Linhas em que quantidade × unitário não bate com o total saem marcadas
/// como `suspeito`, para a conferência destacar.
class NotaTextParser {
  NotaTextParser._();

  // Dinheiro BR: 2,50 | 30,00 | 1.299,90
  static const _m = r'(?:\d{1,3}(?:\.\d{3})+|\d+),\d{2}';
  // Quantidade: 12 | 0,350 | 1.5
  static const _q = r'\d+(?:[.,]\d{1,3})?';
  // Unidades comuns de cupom
  static const _un = r'(?:UNID|UNI|UND|UN|PCT|PC|CX|KG|K9|LT|L|ML|G|GR|FD|PT|DZ)';

  static final RegExp _reUmaLinha = RegExp(
    r'^(?:\d{1,4}[\s.)-]+)?(?:(\d{8,14})\s+)?(.+?)\s+(' +
        _q +
        r')\s*(?:' +
        _un +
        r')?\s*[xX*]?\s*(?:R\$\s*)?(' +
        _m +
        r')\s+(?:R\$\s*)?(' +
        _m +
        r')$',
    caseSensitive: false,
  );

  static final RegExp _reQtdX = RegExp(
    r'^(?:Qtde?\.?:?\s*)?(' +
        _q +
        r')\s*(?:' +
        _un +
        r')?\s*[xX*]\s*(?:Vl\.?\s*Unit\.?:?\s*)?(?:R\$\s*)?(' +
        _m +
        r')\s+(?:\(\s*[\d.,]+\s*\)\s*)?(?:R\$\s*)?(' +
        _m +
        r')$',
    caseSensitive: false,
  );

  // "1 UN X 0,11 (0,04)": sem total na linha (total = qtd × unitário).
  static final RegExp _reQtdXSemTotal = RegExp(
    r'^(' +
        _q +
        r')\s*(?:' +
        _un +
        r')?\s*[xX*]\s*(?:R\$\s*)?(' +
        _m +
        r')\s*(?:\(\s*[\d.,]+\s*\))?$',
    caseSensitive: false,
  );

  static final RegExp _reDescontoItem = RegExp(
      r'^desconto\s+sobre\s+item\s*[-−–]?\s*(' + _m + r')$',
      caseSensitive: false);

  static final RegExp _reQtdRotulo = RegExp(
    r'Qtde?\.?:?\s*(' +
        _q +
        r')\s*(?:' +
        _un +
        r')?.*?Vl\.?\s*Unit\.?:?\s*(?:R\$\s*)?(' +
        _m +
        r').*?(' +
        _m +
        r')\s*$',
    caseSensitive: false,
  );

  // Layout quebrado (NFC-e de SP): "1.00 X UN 6.990 6.99" = qtd X un unit total,
  // com ponto ou vírgula decimal, unitário com 2-3 casas.
  static const _q4 = r'\d+(?:[.,]\d{1,4})?';
  static const _p = r'\d+[.,]\d{2,3}';
  static const _t = r'\d+[.,]\d{2}';
  // Total da nota: 64,97 | 1.299,90 | 64.97
  static const _mTotal = r'(?:(?:\d{1,3}(?:\.\d{3})+|\d+),\d{2}|\d+\.\d{2})';

  static final RegExp _reAncora = RegExp(
    r'(' +
        _q4 +
        r')\s*[xX*]\s*(?:' +
        _un +
        r')?\s*(' +
        _p +
        r')\s+(' +
        _t +
        r')',
    caseSensitive: false,
  );

  /// Linhas de cabeçalho/rodapé que nunca são nome de produto.
  static final RegExp _reRuido = RegExp(
    r'^(CNPJ|CPF|IE\b|IM\b|QTD|QTDE|FORMA|TROCO|CONSUMIDOR|VALOR|TOTAL|SUBTOTAL|'
    r'DESCONTO|ACR[EÉ]SCIMO|TRIBUTOS|DOCUMENTO|DANFE|NFC|CUPOM|SAT\b|EXTRATO|'
    r'CHAVE|PROTOCOLO|CONSULTE|VIA\b|WWW|HTTP|S[ÉE]RIE|N[º°O]\b|DATA|EMISS|'
    r'C[ÓO]D\b|DESCRI|ITEM\b|VL\b|DINHEIRO|CART[ÃA]O|PIX|CR[ÉE]DITO|D[ÉE]BITO|'
    r'PAGAMENTO)',
    caseSensitive: false,
  );

  // ---------------------------------------------------------------------------

  static NotaParseResult parsear(String texto, {String fonte = 'foto'}) {
    final linhas = texto
        .split(RegExp(r'[\r\n]+'))
        .map(_normalizar)
        .where((l) => l.isNotEmpty)
        .toList();
    final usada = List<bool>.filled(linhas.length, false);
    final itens = <NotaItem>[];

    for (var i = 0; i < linhas.length; i++) {
      if (usada[i]) continue;
      final l = linhas[i];

      // desconto do item: abate do total do item anterior
      final desc = _reDescontoItem.firstMatch(l);
      if (desc != null && itens.isNotEmpty) {
        final it = itens.last;
        final novo = ((it.valorTotal ?? 0) - numBr(desc.group(1)!)) * 100;
        it.valorTotal = novo.roundToDouble() / 100;
        it.suspeito = false;
        usada[i] = true;
        continue;
      }

      // (a) item em duas linhas: nome em cima, "qtd x unit total" embaixo
      final dois = _reQtdX.firstMatch(l) ?? _reQtdRotulo.firstMatch(l);
      if (dois != null &&
          i > 0 &&
          !usada[i - 1] &&
          !_reRuido.hasMatch(linhas[i - 1])) {
        final n = _limparNome(linhas[i - 1]);
        if (_nomeOk(n.nome)) {
          itens.add(_item(
              n.nome, n.codigo, dois.group(1)!, dois.group(2)!, dois.group(3)!));
          usada[i] = true;
          usada[i - 1] = true;
          continue;
        }
      }

      // (a2) qtd x unitário sem total na linha
      final semTotal = _reQtdXSemTotal.firstMatch(l);
      if (semTotal != null &&
          i > 0 &&
          !usada[i - 1] &&
          !_reRuido.hasMatch(linhas[i - 1])) {
        final n = _limparNome(linhas[i - 1]);
        if (_nomeOk(n.nome)) {
          final q = numBr(semTotal.group(1)!);
          final u = numBr(semTotal.group(2)!);
          final t = (q * u * 100).roundToDouble() / 100;
          itens.add(_item(n.nome, n.codigo, semTotal.group(1)!,
              semTotal.group(2)!, t.toStringAsFixed(2).replaceAll('.', ',')));
          usada[i] = true;
          usada[i - 1] = true;
          continue;
        }
      }

      // (b) item em uma linha
      final um = _reUmaLinha.firstMatch(l);
      if (um != null) {
        final n = _limparNome(um.group(2)!);
        if (_nomeOk(n.nome)) {
          itens.add(_item(n.nome, um.group(1) ?? n.codigo, um.group(3)!,
              um.group(4)!, um.group(5)!));
          usada[i] = true;
        }
      }
    }

    // Itens "NNN CÓDIGO NOME" + "qtd UN X unit": independe da ordem das linhas.
    final porCab = _itensPorCabecalho(linhas);
    if (porCab.length > itens.length) {
      itens
        ..clear()
        ..addAll(porCab);
    }

    // Tabela simples "Produto  Qtd  Total" (comprovante de entrega, orçamento):
    // linhas "NOME 1,00 20,86" sem valor unitário.
    final tabela = _itensTabelaQtdTotal(linhas);
    if (tabela.length > itens.length) {
      itens
        ..clear()
        ..addAll(tabela);
    }

    // Layout quebrado em várias linhas (ex.: NFC-e de SP): tenta o texto inteiro.
    if (itens.isEmpty) itens.addAll(_itensEmBloco(linhas));

    // Último recurso: qualquer linha "NOME [qtd] valor" vira item SUSPEITO,
    // para a conferência mostrar algo editável em vez de lista vazia.
    if (itens.isEmpty) itens.addAll(_itensGenericos(linhas, usada));

    CodigoBarras.normalizarItens(itens);
    return NotaParseResult(
      itens: itens,
      totalNota: _extrairTotal(linhas, usada),
      chaveAcesso: _extrairChave(texto),
      fonte: fonte,
      textoBruto: texto,
    );
  }

  /// Cupons com itens numerados ("001 250474 BANANA KG" + "1,164 KG X 9,99
  /// (3,65) 11,63"): corta o texto em um trecho por item e procura quantidade,
  /// unitário, total e "desconto sobre item" dentro do trecho, sem depender de
  /// o OCR ter mantido a ordem/linhas certas.
  static List<NotaItem> _itensPorCabecalho(List<String> linhas) {
    final todo = linhas.join(' ');
    final reCab =
        RegExp(r'(?<!\d)\d{3}\s+(\d{4,14})\s+(?=[A-Za-zÀ-ú])');
    final cabs = reCab.allMatches(todo).toList();
    if (cabs.isEmpty) return [];
    final reFim = RegExp(
        r'QTD\.?\s*TOTAL|VALOR\s+TOTAL|TOTAL\s+DE\s+ITENS|VALOR\s+A\s+PAGAR',
        caseSensitive: false);
    final reAnc = RegExp(
        r'^(.*?)\s*(' + _q + r')\s*(?:' + _un + r')?\s*[xX*]\s*(?:R\$\s*)?(' +
            _m + r')',
        caseSensitive: false);
    final reNeg = RegExp(r'[-−–]\s*(' + _m + r')');
    final reDin = RegExp(r'(?<![\d.,])(' + _m + r')(?![\d])');

    final out = <NotaItem>[];
    for (var k = 0; k < cabs.length; k++) {
      final fimSeg = k + 1 < cabs.length ? cabs[k + 1].start : todo.length;
      var seg = todo.substring(cabs[k].end, fimSeg);
      final fim = reFim.firstMatch(seg);
      if (fim != null) seg = seg.substring(0, fim.start);
      final m = reAnc.firstMatch(seg);
      if (m == null) continue;
      final nome = m.group(1)!.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
      if (!_nomeOk(nome)) continue;
      var resto = seg.substring(m.end).replaceAll(RegExp(r'\([\d.,\s]*\)'), ' ');
      double desconto = 0;
      final neg = reNeg.firstMatch(resto);
      if (neg != null) {
        desconto = numBr(neg.group(1)!);
        resto = resto.replaceAll(reNeg, ' ');
      }
      final q = numBr(m.group(2)!);
      final u = numBr(m.group(3)!);
      final tot = reDin.firstMatch(resto);
      final totalStr = tot != null
          ? tot.group(1)!
          : (q * u).toStringAsFixed(2).replaceAll('.', ',');
      final item =
          _item(nome, cabs[k].group(1), m.group(2)!, m.group(3)!, totalStr);
      if (desconto > 0) {
        item.valorTotal = (((item.valorTotal ?? 0) - desconto) * 100).roundToDouble() / 100;
        item.suspeito = false;
      }
      out.add(item);
    }
    return out;
  }

  /// Depois de um cabeçalho com "Qtd" e "Total", lê linhas "NOME qtd total"
  /// até chegar em pagamentos. Unitário = total ÷ quantidade.
  static List<NotaItem> _itensTabelaQtdTotal(List<String> linhas) {
    final reCab = RegExp(r'\bqtde?\b.*\btotal\b', caseSensitive: false);
    final reFim = RegExp(r'pagament|pgto|forma\s*p', caseSensitive: false);
    final reLinha = RegExp(
        r'^(.*?[A-Za-zÀ-ú].*?)\s+(\d+[.,]\d{1,3})\s+(\d+[.,]\d{2})$');
    final out = <NotaItem>[];
    var dentro = false;
    for (final l in linhas) {
      if (!dentro) {
        if (reCab.hasMatch(l)) dentro = true;
        continue;
      }
      if (reFim.hasMatch(l)) break;
      final m = reLinha.firstMatch(l);
      if (m == null) continue;
      final n = _limparNome(m.group(1)!);
      if (!_nomeOk(n.nome)) continue;
      final q = numBr(m.group(2)!);
      final t = numBr(m.group(3)!);
      if (q <= 0) continue;
      out.add(NotaItem(
        nome: n.nome,
        quantidade: q,
        valorUnitario: (t / q * 100).roundToDouble() / 100,
        valorTotal: t,
        codigo: n.codigo,
      ));
    }
    return out;
  }

  /// Qualquer linha "NOME [qtd] valor" fora do cabeçalho/rodapé. Sempre
  /// `suspeito`: é palpite para a equipe conferir.
  static List<NotaItem> _itensGenericos(List<String> linhas, List<bool> usada) {
    final re = RegExp(r'^(.*?[A-Za-zÀ-ú]{3}.*?)\s+(?:(\d+[.,]\d{1,3})\s+)?(' +
        _mTotal +
        r')$');
    final lixo = RegExp(
        r'total|troco|valor|pgto|forma|desconto|tributo|cnpj|cpf|data|cep|'
        r'pedido|n[uú]mero|protocolo|serie|s[ée]rie|dinheiro|cart[aã]o|pix|'
        r'cr[eé]dito|d[eé]bito|or[cç]amento|atendente|coo\b',
        caseSensitive: false);
    final out = <NotaItem>[];
    for (var i = 0; i < linhas.length; i++) {
      if (usada[i]) continue;
      final m = re.firstMatch(linhas[i]);
      if (m == null) continue;
      final n = _limparNome(m.group(1)!);
      if (!_nomeOk(n.nome) || lixo.hasMatch(n.nome)) continue;
      final q = m.group(2) != null ? numBr(m.group(2)!) : 1.0;
      final t = numBr(m.group(3)!);
      if (q <= 0 || t <= 0) continue;
      out.add(NotaItem(
        nome: n.nome,
        quantidade: q,
        valorUnitario: (t / q * 100).roundToDouble() / 100,
        valorTotal: t,
        codigo: n.codigo,
        suspeito: true,
      ));
    }
    return out;
  }

  /// Junta o resultado de várias fotos (cupom longo fotografado em partes).
  /// Não remove itens repetidos entre fotos: quem confere decide.
  static NotaParseResult juntar(List<NotaParseResult> partes,
      {String fonte = 'foto'}) {
    final itens = <NotaItem>[];
    double? total;
    String? chave;
    final textos = <String>[];
    for (var i = 0; i < partes.length; i++) {
      final p = partes[i];
      itens.addAll(p.itens);
      total = p.totalNota ?? total; // o total costuma estar na última foto
      chave ??= p.chaveAcesso;
      textos.add(partes.length > 1
          ? '--- foto ${i + 1} ---\n${p.textoBruto}'
          : p.textoBruto);
    }
    return NotaParseResult(
      itens: itens,
      totalNota: total,
      chaveAcesso: chave,
      fonte: fonte,
      textoBruto: textos.join('\n'),
    );
  }

  /// "1.299,90" | "7,59" | "2.5" → double. Retorna 0 se não der.
  static double numBr(String s) {
    final t = s.trim();
    if (t.contains(',')) {
      return double.tryParse(t.replaceAll('.', '').replaceAll(',', '.')) ?? 0;
    }
    return double.tryParse(t) ?? 0;
  }

  // ---------------------------------------------------------------------------

  static NotaItem _item(
      String nome, String? codigo, String q, String u, String t) {
    final qtd = numBr(q);
    final unit = numBr(u);
    final total = numBr(t);
    final tolerancia = total * 0.01 > 0.05 ? total * 0.01 : 0.05;
    return NotaItem(
      nome: nome,
      quantidade: qtd,
      valorUnitario: unit,
      valorTotal: total,
      codigo: codigo,
      suspeito: (qtd * unit - total).abs() > tolerancia,
    );
  }

  /// Espaços/tabs estranhos → um espaço. Corrige "2.50 30.00" (ponto
  /// decimal) para "2,50 30,00" quando a linha termina com dois valores assim.
  static String _normalizar(String linha) {
    final l = linha
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAllMapped(RegExp(r'(\d),\s+(\d)'), (m) => '${m[1]},${m[2]}')
        .trim();
    final m = RegExp(r'^(.*\s)(\d+)\.(\d{2})\s+(\d+)\.(\d{2})$').firstMatch(l);
    if (m != null && !RegExp(r',\d{2}').hasMatch(l)) {
      return '${m.group(1)}${m.group(2)},${m.group(3)} ${m.group(4)},${m.group(5)}';
    }
    return l;
  }

  /// Tira nº do item, "(Código: ...)", EAN e código interno curto do começo.
  static ({String nome, String? codigo}) _limparNome(String bruto) {
    var s = bruto.trim();
    String? codigo;
    s = s.replaceAll(
        RegExp(r'\(\s*C[oó]digo:?.*?\)', caseSensitive: false), '');
    s = s.replaceFirst(RegExp(r'^\d{1,4}[\s.)-]+(?=\S)'), '');
    final ean = RegExp(r'^(\d{8,14})\s+').firstMatch(s);
    if (ean != null) {
      codigo = ean.group(1);
      s = s.substring(ean.end);
    }
    s = s.replaceFirst(RegExp(r'^\d{3,7}\s+(?=\D)'), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return (nome: s, codigo: codigo);
  }

  static bool _nomeOk(String n) {
    if (n.length < 3) return false;
    if (RegExp(r'^\d+$').hasMatch(n)) return false;
    if (_reRuido.hasMatch(n)) return false;
    return RegExp(r'[A-Za-zÀ-ú]{2}').hasMatch(n);
  }

  /// Procura o total só em linhas que não viraram item (senão "Vl. Total"
  /// do item seria confundido com o total da nota).
  static double? _extrairTotal(List<String> linhas, List<bool> usada) {
    final prioridades = <RegExp>[
      RegExp(r'valor\s*a\s*pagar', caseSensitive: false),
      RegExp(r'valor\s*total', caseSensitive: false),
      RegExp(r'\btotal\b', caseSensitive: false),
    ];
    final descarta = RegExp(r'sub\s*total|qtd|tot\.?\s*itens|tributos|itens',
        caseSensitive: false);
    final valorLogoApos =
        RegExp(r'^\s*:?\s*(?:R\$)?\s*(' + _mTotal + r')');
    final soValor = RegExp(r'^(?:R\$\s*)?(' + _mTotal + r')$');

    for (final p in prioridades) {
      double? achado;
      for (var i = 0; i < linhas.length; i++) {
        if (usada[i]) continue;
        final l = linhas[i];
        if (descarta.hasMatch(l)) continue;
        final k = p.firstMatch(l);
        if (k == null) continue;
        var mm = valorLogoApos.firstMatch(l.substring(k.end));
        if (mm == null && i + 1 < linhas.length) {
          mm = soValor.firstMatch(linhas[i + 1]);
        }
        if (mm != null) achado = numBr(mm.group(1)!);
      }
      if (achado != null) return achado;
    }
    return null;
  }

  /// Texto inteiro: cada "qtd X un unit total" é uma âncora; o nome é o trecho
  /// entre a âncora anterior e esta, depois do último código numérico.
  static List<NotaItem> _itensEmBloco(List<String> linhas) {
    final texto = linhas.join(' ');
    final itens = <NotaItem>[];
    var inicio = 0;
    for (final m in _reAncora.allMatches(texto)) {
      final n = _nomeDoSegmento(texto.substring(inicio, m.start));
      inicio = m.end;
      if (!_nomeOk(n.nome)) continue;
      itens.add(
          _item(n.nome, n.codigo, m.group(1)!, m.group(2)!, m.group(3)!));
    }
    return itens;
  }

  static ({String nome, String? codigo}) _nomeDoSegmento(String segmento) {
    var s = segmento.trim();
    String? codigo;

    // o código do item (6-14 dígitos) abre a descrição; vale o último do trecho
    final codigos = RegExp(r'\b(\d{6,14})\b').allMatches(s).toList();
    if (codigos.isNotEmpty) {
      final ult = codigos.last;
      final c = ult.group(1)!;
      // só vira "código de barras" se tiver tamanho de EAN
      if (c.length == 8 || c.length == 12 || c.length == 13 || c.length == 14) {
        codigo = c;
      }
      s = s.substring(ult.end).trim();
    } else {
      // sem código: descarta o cabeçalho de colunas ("... VL TOTAL R$")
      final cab = RegExp(
        r'(?:VL\s*TOTAL\s*(?:R\$|RS)?|VL\s*UNIT\s*(?:R\$|RS)?|\bCOD\b|\bDESC\b)',
        caseSensitive: false,
      ).allMatches(s).toList();
      if (cab.isNotEmpty) s = s.substring(cab.last.end).trim();
    }

    // SKU da loja colado na descrição ("RQ103012 AGUA ...") e "0LEO" → "OLEO"
    s = s.replaceFirst(RegExp(r'^[A-Za-z]{1,3}\d{3,}\s+(?=\S)'), '');
    s = s
        .split(' ')
        .map((t) => RegExp(r'^0[A-Za-z]{2,}$').hasMatch(t) ? 'O${t.substring(1)}' : t)
        .join(' ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return (nome: s, codigo: codigo);
  }

  /// Chave de acesso (44 dígitos), mesmo quebrada em duas linhas ou com
  /// espaços. Só aceita sequência com dígito verificador (módulo 11) correto.
  static String? _extrairChave(String texto) {
    final plano = texto.replaceAll(RegExp(r'\s+'), ' ');
    for (final run in RegExp(r'(?:\d ?)+').allMatches(plano)) {
      final d = run.group(0)!.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i + 44 <= d.length; i++) {
        final w = d.substring(i, i + 44);
        if (_chaveValida(w)) return w;
      }
    }
    return null;
  }

  static bool _chaveValida(String d) {
    var soma = 0;
    var peso = 2;
    for (var i = 42; i >= 0; i--) {
      soma += int.parse(d[i]) * peso;
      peso = peso == 9 ? 2 : peso + 1;
    }
    final resto = soma % 11;
    final dv = (resto == 0 || resto == 1) ? 0 : 11 - resto;
    return dv == int.parse(d[43]);
  }
}
