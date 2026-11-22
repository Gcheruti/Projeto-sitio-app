import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/nota_importada.dart';
import '../services/cupom_ocr_service.dart';
import '../services/dispositivo_service.dart';
import 'nota_conferencia_screen.dart';

/// Reposição → ler cupom/nota por FOTO (1 a 3 fotos).
///
/// Fluxo: fotos → OCR → itens → rascunho no Supabase → conferência editável.
/// Ao terminar, esta tela é SUBSTITUÍDA pela conferência (voltar leva à Reposição).
class CupomOcrScreen extends StatefulWidget {
  const CupomOcrScreen({super.key});

  @override
  State<CupomOcrScreen> createState() => _CupomOcrScreenState();
}

class _CupomOcrScreenState extends State<CupomOcrScreen> {
  static const _maxFotos = 3;

  final _picker = ImagePicker();
  final List<XFile> _fotos = [];
  bool _lendo = false;
  bool _semCamera = false; // o aparelho não tem câmera (Galeria continua)
  String? _erro;
  NotaParseResult? _semItens; // leitura que não achou itens (mostra texto cru)

  @override
  void initState() {
    super.initState();
    DispositivoService.temCamera().then((v) {
      if (mounted && v == false) setState(() => _semCamera = true);
    });
  }

  int get _restantes => _maxFotos - _fotos.length;

  Future<void> _adicionar(ImageSource origem) async {
    if (_restantes <= 0 || _lendo) return;
    try {
      if (origem == ImageSource.camera) {
        final f = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 90,
          maxWidth: 2400,
        );
        if (f != null) setState(() => _fotos.add(f));
      } else if (_restantes >= 2) {
        // pickMultiImage exige limit >= 2
        final fs = await _picker.pickMultiImage(
          imageQuality: 90,
          maxWidth: 2400,
          limit: _restantes,
        );
        if (fs.isNotEmpty) {
          setState(() => _fotos.addAll(fs.take(_restantes)));
        }
      } else {
        final f = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
          maxWidth: 2400,
        );
        if (f != null) setState(() => _fotos.add(f));
      }
      setState(() {
        _erro = null;
        _semItens = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Não consegui abrir a câmera/galeria: $e');
    }
  }

  Future<void> _ler() async {
    if (_fotos.isEmpty || _lendo) return;
    setState(() {
      _lendo = true;
      _erro = null;
      _semItens = null;
    });

    final r = await CupomOcrService.lerArquivos(
      _fotos.map((f) => f.path).toList(),
    );
    if (!mounted) return;

    if (r.erro != null) {
      setState(() {
        _lendo = false;
        _erro = r.erro;
      });
      return;
    }
    if (r.itens.isEmpty) {
      setState(() {
        _lendo = false;
        _semItens = r;
        _erro = 'Não encontrei itens com confiança. Tente uma foto mais nítida, '
            'reta e bem iluminada — ou preencha à mão na conferência.';
      });
      return;
    }

    await _abrirConferencia(r);
  }

  Future<void> _abrirConferencia(NotaParseResult r) async {
    // grava o rascunho e troca esta tela pela conferência
    await NotaConferenciaScreen.abrir(
      context,
      r,
      origem: 'foto',
      qtdFotos: _fotos.length,
      substituirTela: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Ler cupom (foto)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Fotografe o cupom/nota bem iluminado e reto, sem sombra. '
            'Se for comprido, tire até 3 fotos de cima para baixo, sem '
            'repetir trechos. Você poderá corrigir tudo antes de dar entrada '
            'no estoque.',
          ),
          const SizedBox(height: 12),
          if (kIsWeb)
            const Card(
              color: Color(0xFFFFF3E0),
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Leitura por foto só no Android'),
                subtitle: Text('No navegador use a reposição manual.'),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: (kIsWeb || _lendo || _restantes <= 0 || _semCamera)
                      ? null
                      : () => _adicionar(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: Text(_semCamera ? 'Sem câmera' : 'Câmera'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (kIsWeb || _lendo || _restantes <= 0)
                      ? null
                      : () => _adicionar(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galeria'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_fotos.length} de $_maxFotos fotos',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_fotos.isNotEmpty && !kIsWeb) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _fotos.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_fotos[i].path),
                          width: 90,
                          height: 110,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: IconButton.filledTonal(
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          tooltip: 'Remover foto',
                          onPressed: _lendo
                              ? null
                              : () => setState(() => _fotos.removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: (_fotos.isEmpty || _lendo || kIsWeb) ? null : _ler,
            child: Text(
              _fotos.length > 1
                  ? 'Ler ${_fotos.length} fotos'
                  : 'Ler foto',
            ),
          ),
          if (_lendo) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Lendo o cupom…')),
          ],
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!, style: TextStyle(color: scheme.error)),
          ],
          if (_semItens != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _abrirConferencia(_semItens!),
              child: const Text('Abrir conferência e preencher à mão'),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Texto lido (para conferir)'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    _semItens!.textoBruto.isEmpty
                        ? '(vazio)'
                        : _semItens!.textoBruto,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
