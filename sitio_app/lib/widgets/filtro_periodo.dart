import 'package:flutter/material.dart';

enum PeriodoTipo { hoje, ontem, dias7, dias30, mes, mesPassado, personalizado }

String fmtData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fmtMoeda(num v) => 'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',')}';

String fmtQtd(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Período escolhido. [fim] é exclusivo (dia seguinte ao último dia).
class PeriodoSel {
  const PeriodoSel(this.tipo, {this.ini, this.ultimoDia});

  final PeriodoTipo tipo;
  final DateTime? ini; // personalizado
  final DateTime? ultimoDia; // personalizado (inclusive)

  static DateTime _dia(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime get inicio {
    final hoje = _dia(DateTime.now());
    switch (tipo) {
      case PeriodoTipo.hoje:
        return hoje;
      case PeriodoTipo.ontem:
        return hoje.subtract(const Duration(days: 1));
      case PeriodoTipo.dias7:
        return hoje.subtract(const Duration(days: 6));
      case PeriodoTipo.dias30:
        return hoje.subtract(const Duration(days: 29));
      case PeriodoTipo.mes:
        return DateTime(hoje.year, hoje.month, 1);
      case PeriodoTipo.mesPassado:
        return DateTime(hoje.year, hoje.month - 1, 1);
      case PeriodoTipo.personalizado:
        return _dia(ini ?? hoje);
    }
  }

  DateTime get fim {
    final hoje = _dia(DateTime.now());
    switch (tipo) {
      case PeriodoTipo.ontem:
        return hoje;
      case PeriodoTipo.mesPassado:
        return DateTime(hoje.year, hoje.month, 1);
      case PeriodoTipo.personalizado:
        return _dia(ultimoDia ?? ini ?? hoje).add(const Duration(days: 1));
      default:
        return hoje.add(const Duration(days: 1));
    }
  }

  String get rotulo {
    final ultimo = fim.subtract(const Duration(days: 1));
    return inicio == ultimo
        ? fmtData(inicio)
        : '${fmtData(inicio)} a ${fmtData(ultimo)}';
  }
}

/// Chips de período: Hoje, Ontem, 7 dias, 30 dias, Este mês, Mês passado e
/// Personalizado (data inicial e data final).
class FiltroPeriodo extends StatelessWidget {
  const FiltroPeriodo({
    super.key,
    required this.selecionado,
    required this.onChanged,
  });

  final PeriodoSel selecionado;
  final ValueChanged<PeriodoSel> onChanged;

  static const _opcoes = <(PeriodoTipo, String)>[
    (PeriodoTipo.hoje, 'Hoje'),
    (PeriodoTipo.ontem, 'Ontem'),
    (PeriodoTipo.dias7, '7 dias'),
    (PeriodoTipo.dias30, '30 dias'),
    (PeriodoTipo.mes, 'Este mês'),
    (PeriodoTipo.mesPassado, 'Mês passado'),
    (PeriodoTipo.personalizado, 'Personalizado'),
  ];

  Future<void> _personalizado(BuildContext context) async {
    final agora = DateTime.now();
    final ini = await showDatePicker(
      context: context,
      initialDate: selecionado.tipo == PeriodoTipo.personalizado
          ? selecionado.inicio
          : agora,
      firstDate: DateTime(2020),
      lastDate: agora,
      helpText: 'Data inicial',
    );
    if (ini == null || !context.mounted) return;
    final fim = await showDatePicker(
      context: context,
      initialDate: ini,
      firstDate: ini,
      lastDate: agora,
      helpText: 'Data final',
    );
    if (fim == null) return;
    onChanged(PeriodoSel(PeriodoTipo.personalizado, ini: ini, ultimoDia: fim));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in _opcoes)
              FilterChip(
                label: Text(o.$2),
                selected: selecionado.tipo == o.$1,
                onSelected: (_) {
                  if (o.$1 == PeriodoTipo.personalizado) {
                    _personalizado(context);
                  } else {
                    onChanged(PeriodoSel(o.$1));
                  }
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Período: ${selecionado.rotulo}',
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
