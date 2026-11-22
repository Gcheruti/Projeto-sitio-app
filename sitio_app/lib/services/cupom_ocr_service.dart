import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/nota_importada.dart';
import 'nota_text_parser.dart';

/// Lê cupom/nota fiscal a partir de FOTOS (OCR no aparelho, sem custo de API).
/// A interpretação do texto fica em [NotaTextParser].
class CupomOcrService {
  CupomOcrService._();

  /// OCR (ML Kit) só roda em Android/iOS.
  static bool get suportado =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Lê 1..N fotos do mesmo cupom e junta tudo em um único resultado.
  /// Nunca lança: falhas voltam em [NotaParseResult.erro].
  static Future<NotaParseResult> lerArquivos(List<String> caminhos) async {
    if (!suportado) {
      return NotaParseResult.falha(
        'A leitura por foto só funciona no app Android. '
        'No navegador use a reposição manual.',
      );
    }
    if (caminhos.isEmpty) {
      return NotaParseResult.falha('Nenhuma foto selecionada.');
    }

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final partes = <NotaParseResult>[];
      for (final caminho in caminhos) {
        final reconhecido =
            await recognizer.processImage(InputImage.fromFilePath(caminho));
        final original = reconhecido.text;
        final linhas = _reconstruirLinhas(reconhecido);
        var r = NotaTextParser.parsear(linhas);
        if (linhas != original) {
          final r2 = NotaTextParser.parsear(original);
          if (r2.itens.length > r.itens.length) r = r2;
          r = NotaParseResult(
            itens: r.itens,
            totalNota: r.totalNota ?? r2.totalNota,
            chaveAcesso: r.chaveAcesso ?? r2.chaveAcesso,
            fonte: r.fonte,
            textoBruto: '$linhas\n--- OCR original ---\n$original',
          );
        }
        partes.add(r);
      }
      return NotaTextParser.juntar(partes);
    } catch (e) {
      return NotaParseResult.falha('Falha ao ler a foto: $e');
    } finally {
      await recognizer.close();
    }
  }

  /// Refaz as linhas do cupom pela POSIÇÃO do texto (o ML Kit agrupa em blocos
  /// por coluna e, em foto de lado, devolve ordem embaralhada). Compensa a
  /// rotação do papel. Se faltar geometria, devolve o texto original.
  static String _reconstruirLinhas(RecognizedText r) {
    final L = <({double x, double y, double h, double w, double a, double cx, double cy, String t})>[];
    for (final b in r.blocks) {
      for (final ln in b.lines) {
        final p = ln.cornerPoints;
        if (p.length < 4 || ln.text.trim().isEmpty) continue;
        final dx = (p[1].x - p[0].x).toDouble();
        final dy = (p[1].y - p[0].y).toDouble();
        final w = math.sqrt(dx * dx + dy * dy);
        final hx = (p[3].x - p[0].x).toDouble();
        final hy = (p[3].y - p[0].y).toDouble();
        final h = math.sqrt(hx * hx + hy * hy);
        if (w == 0 || h == 0) continue;
        final cx = (p[0].x + p[1].x + p[2].x + p[3].x) / 4.0;
        final cy = (p[0].y + p[1].y + p[2].y + p[3].y) / 4.0;
        L.add((x: 0, y: 0, h: h, w: w, a: math.atan2(dy, dx), cx: cx, cy: cy, t: ln.text.trim()));
      }
    }
    if (L.length < 2) return r.text;

    var sx = 0.0, sy = 0.0;
    for (final l in L) {
      sx += l.w * math.cos(l.a);
      sy += l.w * math.sin(l.a);
    }
    final a0 = math.atan2(sy, sx);
    final c = math.cos(a0), s = math.sin(a0);

    final pos = [
      for (final l in L)
        (x: l.cx * c + l.cy * s, y: -l.cx * s + l.cy * c, h: l.h, t: l.t)
    ]..sort((a, b) => a.y.compareTo(b.y));

    final hs = pos.map((e) => e.h).toList()..sort();
    final tol = hs[hs.length ~/ 2] * 0.6;

    final linhas = <List<({double x, double y, double h, String t})>>[];
    var yRef = 0.0;
    for (final e in pos) {
      if (linhas.isEmpty || (e.y - yRef).abs() > tol) {
        linhas.add([e]);
        yRef = e.y;
      } else {
        linhas.last.add(e);
        yRef = linhas.last.fold<double>(0, (a, b) => a + b.y) / linhas.last.length;
      }
    }
    return linhas
        .map((row) => (row..sort((a, b) => a.x.compareTo(b.x)))
            .map((e) => e.t)
            .join(' '))
        .join('\n');
  }
}
