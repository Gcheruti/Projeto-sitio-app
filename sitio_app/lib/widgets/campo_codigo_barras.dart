import 'package:flutter/material.dart';

import '../screens/barcode_scan_screen.dart';

/// Campo de código de barras com câmera ao lado: toque no ícone, aponte para o
/// código e o número entra no campo (continua editável).
class CampoCodigoBarras extends StatelessWidget {
  const CampoCodigoBarras({
    super.key,
    required this.controller,
    this.label = 'Código de barras (opcional)',
  });

  final TextEditingController controller;
  final String label;

  Future<void> _escanear(BuildContext context) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );
    final t = raw?.trim() ?? '';
    if (t.isNotEmpty) controller.text = t;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.photo_camera_outlined),
          tooltip: 'Ler com a câmera',
          onPressed: () => _escanear(context),
        ),
      ),
    );
  }
}
