import 'package:flutter/material.dart';

import '../models/categorias.dart';

/// Dropdown de subcategoria, dependente do ambiente.
class CampoSubcategoria extends StatelessWidget {
  const CampoSubcategoria({
    super.key,
    required this.ambiente,
    required this.valor,
    required this.onChanged,
  });

  final String ambiente;
  final String? valor;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final lista = kSubcategorias[ambiente] ?? const <String>[];
    final v = (valor != null && lista.contains(valor)) ? valor : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey('sub_$ambiente'),
      initialValue: v,
      decoration: const InputDecoration(
        labelText: 'Subcategoria',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Sem subcategoria')),
        ...lista.map((s) => DropdownMenuItem<String?>(value: s, child: Text(s))),
      ],
      onChanged: onChanged,
    );
  }
}

/// Caixinha "voltado ao público" (só esses itens aparecem para a comanda).
class CheckPublico extends StatelessWidget {
  const CheckPublico({super.key, required this.valor, required this.onChanged});

  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Produto voltado ao público'),
      subtitle: const Text('Desmarque para insumos (ex.: farinha)'),
      value: valor,
      onChanged: (v) => onChanged(v ?? true),
    );
  }
}

/// Caixinha "preparado no dia": sem estoque mínimo nem alerta de estoque baixo.
class CheckPreparado extends StatelessWidget {
  const CheckPreparado({super.key, required this.valor, required this.onChanged});

  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('Preparado no dia (sem estoque mínimo)'),
      subtitle: const Text('Ex.: pudim. A equipe registra o que foi preparado'),
      value: valor,
      onChanged: (v) => onChanged(v ?? false),
    );
  }
}

/// Dias de antecedência do aviso de validade deste item.
class CampoDiasValidade extends StatelessWidget {
  const CampoDiasValidade({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: 'Avisar quantos dias antes de vencer',
        helperText: 'Ex.: 2 para pudim, 30 para enlatados',
        border: OutlineInputBorder(),
      ),
    );
  }
}
