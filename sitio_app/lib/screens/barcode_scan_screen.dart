import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/dispositivo_service.dart';

class BarcodeScanScreen extends StatefulWidget {
  const BarcodeScanScreen({super.key});

  @override
  State<BarcodeScanScreen> createState() => _BarcodeScanScreenState();
}

class _BarcodeScanScreenState extends State<BarcodeScanScreen> {
  // onDetect dispara várias vezes por segundo; sem esta trava o pop repetido
  // fechava também a tela de baixo.
  bool _lido = false;

  /// null = ainda verificando; false = o aparelho não tem câmera.
  bool? _temCamera;
  bool _verificado = false;

  @override
  void initState() {
    super.initState();
    DispositivoService.temCamera().then((v) {
      if (mounted) {
        setState(() {
          _temCamera = v;
          _verificado = true;
        });
      }
    });
  }

  Widget _aviso(IconData icone, String texto) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 48),
              const SizedBox(height: 12),
              Text(texto, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Você pode digitar o código à mão.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Voltar'),
              ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final appBar = AppBar(title: const Text('Ler código de barras / QR'));
    if (!_verificado) {
      return Scaffold(
          appBar: appBar, body: const Center(child: CircularProgressIndicator()));
    }
    if (_temCamera == false) {
      return Scaffold(
        appBar: appBar,
        body: _aviso(Icons.no_photography_outlined, 'Este aparelho não tem câmera.'),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: MobileScanner(
        // Computador/navegador: a câmera só é descoberta ao tentar abrir.
        errorBuilder: (context, error, child) {
          switch (error.errorCode) {
            case MobileScannerErrorCode.permissionDenied:
              return _aviso(Icons.lock_outline,
                  'Permissão da câmera negada. Libere o acesso nas configurações.');
            case MobileScannerErrorCode.unsupported:
              return _aviso(Icons.no_photography_outlined,
                  'Leitura por câmera não é suportada neste sistema.');
            default:
              return _aviso(Icons.no_photography_outlined,
                  'Não encontrei uma câmera disponível neste dispositivo.');
          }
        },
        onDetect: (capture) {
          if (_lido) return;
          final bars = capture.barcodes;
          if (bars.isEmpty) return;
          final raw = bars.first.rawValue;
          if (raw == null || raw.isEmpty) return;
          _lido = true;
          Navigator.of(context).pop(raw);
        },
      ),
    );
  }
}
