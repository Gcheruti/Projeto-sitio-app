import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/nota_importada.dart';
import '../services/nfce_sp_parser.dart';

/// Abre a página pública da NFC-e (SEFAZ-SP) num navegador embutido, lê os
/// itens da página já carregada e devolve um [NotaParseResult] (pop).
/// Se a SEFAZ pedir verificação (captcha), a pessoa resolve na própria tela.
class NfceWebViewScreen extends StatefulWidget {
  const NfceWebViewScreen({super.key, required this.chave, required this.url});

  final String chave;
  final String url;

  @override
  State<NfceWebViewScreen> createState() => _NfceWebViewScreenState();
}

class _NfceWebViewScreenState extends State<NfceWebViewScreen> {
  late final WebViewController _c;
  bool _carregando = true;
  bool _fim = false;
  String? _dica;

  @override
  void initState() {
    super.initState();
    _c = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _carregando = true);
        },
        onPageFinished: (_) async {
          if (mounted) setState(() => _carregando = false);
          await _ler(auto: true);
        },
        onWebResourceError: (e) {
          if ((e.isForMainFrame ?? true) && mounted) {
            setState(() => _dica = 'Erro ao carregar a página: ${e.description}');
          }
        },
      ))
      // Carrega o endereço EXATO do QR (loadRequest(Uri) trocaria "|" por "%7C"
      // e o firewall da SEFAZ recusa isso).
      ..loadHtmlString(
        '<html><body><script>location.replace(${jsonEncode(widget.url)});</script></body></html>',
      );
  }

  Future<String> _html() async {
    final r = await _c
        .runJavaScriptReturningResult('document.documentElement.outerHTML');
    var s = r.toString();
    if (s.startsWith('"')) s = jsonDecode(s) as String;
    return s;
  }

  Future<void> _ler({bool auto = false}) async {
    if (_fim) return;
    try {
      final res = NfceSpParser.parseHtml(await _html(),
          chave: widget.chave, urlQr: widget.url);
      if (res.itens.isNotEmpty) {
        _fim = true;
        if (mounted) Navigator.of(context).pop(res);
        return;
      }
      if (!mounted) return;
      if (auto) {
        setState(() => _dica =
            'Se a página pedir verificação, conclua-a: a leitura é automática. '
            'Ou toque em "Ler agora".');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Ainda não achei a lista de itens nesta página.')));
      }
    } catch (e) {
      if (mounted) setState(() => _dica = 'Falha ao ler a página: $e');
    }
  }

  Future<void> _copiarHtml() async {
    final h = await _html();
    await Clipboard.setData(ClipboardData(text: h));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Código da página copiado (${h.length} caracteres).')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultando a nota'),
        actions: [
          IconButton(
            tooltip: 'Copiar código da página (suporte)',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: _copiarHtml,
          ),
          TextButton(
            onPressed: () => _ler(),
            child: const Text('Ler agora'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_carregando) const LinearProgressIndicator(),
          if (_dica != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.secondaryContainer,
              padding: const EdgeInsets.all(8),
              child: Text(_dica!, style: const TextStyle(fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: SelectableText(widget.url, style: const TextStyle(fontSize: 10)),
          ),
          Expanded(child: WebViewWidget(controller: _c)),
        ],
      ),
    );
  }
}
