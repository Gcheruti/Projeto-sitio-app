import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/nfce_config.dart';
import '../config/supabase_config.dart';
import '../models/nota_importada.dart';
import 'nfce_sp_parser.dart';

/// Contrato da leitura de nota por QR Code.
///
/// Qualquer implementação (API própria, função do Supabase, mock) devolve o
/// MESMO [NotaParseResult] da leitura por foto, então o fluxo seguinte
/// (gravar rascunho → conferência editável) é idêntico.
abstract class NotaQrParser {
  /// [payload]: texto do QR (URL da NFC-e ou chave de 44 dígitos).
  /// Nunca lança: falhas voltam em [NotaParseResult.erro].
  Future<NotaParseResult> parseNotaPorQr(String payload);
}

/// Implementação atual: chama a API configurada em [NfceConfig.parseUrl].
///
/// Requisição:  POST {parseUrl}  body {"qr": "<payload>"}
/// Resposta OK: {"ok": true, "total": 45.9, "chave": "<44 dígitos>",
///               "items": [{"name": "...", "qty": 2, "unit_price": 7.95,
///                          "total": 15.9}]}
///              (também aceita nome/quantidade/valor_unitario/valor_total)
/// Resposta erro: {"ok": false, "error": "mensagem"}
///
/// Sem URL configurada devolve erro amigável ("não configurada").
/// Com [usarMock] devolve 2 itens fixos, para testar o fluxo sem API.
class NotaFiscalService implements NotaQrParser {
  NotaFiscalService({this.usarMock = false, http.Client? client})
      : _client = client;

  final bool usarMock;
  final http.Client? _client;

  /// Só números, 8 a 14 dígitos → código de barras de produto, não nota.
  static bool pareceEanProduto(String raw) {
    final t = raw.trim();
    return RegExp(r'^\d{8,14}$').hasMatch(t);
  }

  /// URL de NFC-e ou chave de 44 dígitos.
  static bool pareceQrNfce(String raw) {
    final t = raw.trim().toLowerCase();
    if (RegExp(r'\d{44}').hasMatch(t)) return true;
    if (t.contains('nfce') || t.contains('qrcode')) return true;
    if (t.startsWith('http') && t.contains('fazenda')) return true;
    return false;
  }

  static String? extrairChave(String raw) {
    return RegExp(r'\d{44}').firstMatch(raw.trim())?.group(0);
  }

  @override
  Future<NotaParseResult> parseNotaPorQr(String payload) async {
    final raw = payload.trim();
    final chave = extrairChave(raw);
    final urlQr = raw.startsWith('http') ? raw : null;

    if (usarMock) {
      return NotaParseResult(
        fonte: 'mock',
        chaveAcesso: chave,
        urlQr: urlQr,
        totalNota: 45.90,
        itens: [
          NotaItem(
              nome: 'Água 500ml',
              quantidade: 12,
              valorUnitario: 2.5,
              valorTotal: 30),
          NotaItem(
              nome: 'Café 500g',
              quantidade: 2,
              valorUnitario: 7.95,
              valorTotal: 15.90),
        ],
      );
    }

    if (!NfceConfig.usarApi) return _consultarNoAparelho(chave, urlQr, raw);

    final client = _client ?? http.Client();
    try {
      final res = await client
          .post(
            Uri.parse(NfceConfig.parseUrl.trim()),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${SupabaseConfig.anonKey}',
              'apikey': SupabaseConfig.anonKey,
            },
            body: jsonEncode({'qr': raw}),
          )
          .timeout(const Duration(seconds: 25));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return NotaParseResult.falha(
          'A consulta da nota respondeu ${res.statusCode}. '
          'Tente de novo ou use a foto do cupom.',
          fonte: 'qr',
          chaveAcesso: chave,
          urlQr: urlQr,
        );
      }

      final map = jsonDecode(res.body) as Map<String, dynamic>;
      if (map['ok'] != true) {
        return NotaParseResult.falha(
          '${map['error'] ?? 'Não foi possível ler a nota.'}',
          fonte: 'qr',
          chaveAcesso: chave,
          urlQr: urlQr,
        );
      }

      final itens = <NotaItem>[];
      for (final e in (map['items'] as List? ?? [])) {
        final m = Map<String, dynamic>.from(e as Map);
        final nome = '${m['name'] ?? m['nome'] ?? ''}'.trim();
        if (nome.isEmpty) continue;
        itens.add(
          NotaItem(
            nome: nome,
            quantidade: _num(m['qty'] ?? m['quantidade']) ?? 1,
            valorUnitario: _num(m['unit_price'] ?? m['valor_unitario']),
            valorTotal: _num(m['total'] ?? m['valor_total']),
          ),
        );
      }

      if (itens.isEmpty) {
        return NotaParseResult.falha(
          'A consulta não retornou itens da nota.',
          fonte: 'qr',
          chaveAcesso: chave,
          urlQr: urlQr,
        );
      }

      final chaveApi = '${map['chave'] ?? ''}'.trim();
      return NotaParseResult(
        itens: itens,
        totalNota: _num(map['total']),
        chaveAcesso: chave ?? (chaveApi.isEmpty ? null : chaveApi),
        urlQr: urlQr,
        fonte: 'qr',
      );
    } catch (e) {
      return NotaParseResult.falha(
        'Falha ao consultar a nota: $e',
        fonte: 'qr',
        chaveAcesso: chave,
        urlQr: urlQr,
      );
    } finally {
      if (_client == null) client.close();
    }
  }

  /// Consulta a página pública da SEFAZ-SP direto do celular (IP brasileiro;
  /// a SEFAZ bloqueia o IP dos servidores do Supabase).
  Future<NotaParseResult> _consultarNoAparelho(
      String? chave, String? urlQr, String raw) async {
    final alvo = NfceSpParser.montarAlvo(raw);
    if (alvo.erro != null) {
      return NotaParseResult.falha(alvo.erro!,
          fonte: 'qr', chaveAcesso: chave, urlQr: urlQr);
    }
    final client = _client ?? http.Client();
    try {
      final res = await client.get(Uri.parse(alvo.url!), headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'pt-BR,pt;q=0.9',
      }).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        return NotaParseResult.falha(
            'A SEFAZ-SP respondeu ${res.statusCode}. Tente de novo ou use a foto do cupom.',
            fonte: 'qr', chaveAcesso: alvo.chave, urlQr: urlQr);
      }
      final body = utf8.decode(res.bodyBytes, allowMalformed: true);
      if (body.contains('Request Rejected')) {
        return NotaParseResult.falha(
            'A SEFAZ-SP recusou a consulta do aplicativo. Use a foto do cupom.',
            fonte: 'qr', chaveAcesso: alvo.chave, urlQr: urlQr,
            textoBruto: body);
      }
      final r = NfceSpParser.parseHtml(body, chave: alvo.chave, urlQr: urlQr);
      if (r.itens.isEmpty) {
        final amostra = body.length > 1500 ? body.substring(0, 1500) : body;
        return NotaParseResult.falha(
            'Não consegui ler os itens da página da SEFAZ-SP. Use a foto do cupom.',
            fonte: 'qr', chaveAcesso: alvo.chave, urlQr: urlQr,
            textoBruto: amostra);
      }
      return r;
    } catch (e) {
      return NotaParseResult.falha('Falha ao consultar a nota: $e',
          fonte: 'qr', chaveAcesso: alvo.chave, urlQr: urlQr);
    } finally {
      if (_client == null) client.close();
    }
  }

  static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }
}
