import 'package:flutter/material.dart';

import '../models/agenda_visual.dart';
import '../models/evento_agenda.dart';

/// Marcas de um dia no calendário: um ícone colorido por tipo (com o número
/// quando há mais de um do mesmo tipo). Com mais de 3 tipos diferentes no dia,
/// mostra só o total.
Widget marcasAgenda(
  BuildContext context,
  List<EventoAgenda> doDia,
  AgendaVisualResolver r,
  String Function(EventoAgenda) chaveDe,
) {
  if (doDia.isEmpty) return const SizedBox(height: 14);
  final grupos = <String, int>{};
  for (final e in doDia) {
    final k = chaveDe(e);
    grupos[k] = (grupos[k] ?? 0) + 1;
  }
  final scheme = Theme.of(context).colorScheme;
  if (grupos.length > 3) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('${doDia.length}',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.bold, color: scheme.onPrimary)),
    );
  }
  return FittedBox(
    fit: BoxFit.scaleDown,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final g in grupos.entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(r.icone(g.key), size: 14, color: r.cor(g.key)),
                if (g.value > 1)
                  Text('${g.value}',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: r.cor(g.key))),
              ],
            ),
          ),
      ],
    ),
  );
}
