import 'dart:convert' show utf8;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

/// Uma tabela do relatório (vira bloco no CSV e tabela no PDF).
class SecaoRel {
  SecaoRel(this.titulo, this.cabecalhos, this.linhas);
  final String titulo;
  final List<String> cabecalhos;
  final List<List<String>> linhas;
}

/// Conteúdo de um relatório, exportável em CSV e PDF.
class DocRel {
  DocRel({required this.titulo, required this.periodo, required this.secoes});

  final String titulo;
  final String periodo;
  final List<SecaoRel> secoes;

  static String _csvCel(String v) {
    final t = v.replaceAll('\n', ' ');
    return t.contains(';') || t.contains('"')
        ? '"${t.replaceAll('"', '""')}"'
        : t;
  }

  String toCsv() {
    final b = StringBuffer('﻿'); // BOM: Excel lê acentos corretamente
    b.writeln(_csvCel(titulo));
    b.writeln(_csvCel(periodo));
    for (final s in secoes) {
      b.writeln();
      b.writeln('=== ${s.titulo} ===');
      b.writeln(s.cabecalhos.map(_csvCel).join(';'));
      for (final l in s.linhas) {
        b.writeln(l.map(_csvCel).join(';'));
      }
    }
    return b.toString();
  }

  // A fonte padrão do PDF só tem caracteres Latin-1: troca o que sair disso.
  static String _limpa(String t) => t
      .replaceAll('•', '-')
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('→', '->');

  Future<Uint8List> toPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Text(
            _limpa(titulo),
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(_limpa(periodo)),
          pw.SizedBox(height: 14),
          for (final s in secoes) ...[
            pw.Text(_limpa(s.titulo),
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            if (s.linhas.isEmpty)
              pw.Text('Sem dados no período.')
            else
              pw.TableHelper.fromTextArray(
                headers: s.cabecalhos.map(_limpa).toList(),
                data: s.linhas.map((l) => l.map(_limpa).toList()).toList(),
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );
    return pdf.save();
  }
}

/// Pergunta CSV ou PDF e compartilha o arquivo.
Future<void> exportarRelatorio(
  BuildContext context,
  DocRel doc,
  String nomeBase,
) async {
  final formato = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Exportar em PDF'),
            onTap: () => Navigator.pop(ctx, 'pdf'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Exportar em CSV'),
            onTap: () => Navigator.pop(ctx, 'csv'),
          ),
        ],
      ),
    ),
  );
  if (formato == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  try {
    final hoje = DateTime.now();
    final stamp = '${hoje.year}${hoje.month.toString().padLeft(2, '0')}'
        '${hoje.day.toString().padLeft(2, '0')}';
    final nome = '${nomeBase}_$stamp.$formato';
    final Uint8List bytes = formato == 'pdf'
        ? await doc.toPdf()
        : Uint8List.fromList(utf8.encode(doc.toCsv()));
    final mime = formato == 'pdf' ? 'application/pdf' : 'text/csv';

    if (kIsWeb) {
      await Share.shareXFiles([XFile.fromData(bytes, mimeType: mime, name: nome)]);
    } else {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$nome');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path, mimeType: mime)],
          text: doc.titulo);
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
  }
}
