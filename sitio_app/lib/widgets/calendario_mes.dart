import 'package:flutter/material.dart';

import '../models/evento_agenda.dart';

/// Calendário mensal simples (domingo a sábado), com marca nos dias com evento.
class CalendarioMes extends StatelessWidget {
  const CalendarioMes({
    super.key,
    required this.mes,
    required this.eventos,
    required this.onDia,
    required this.onMes,
    this.selecionado,
    this.corDoDia,
    this.marcas,
    this.proporcao = 1.15,
  });

  final DateTime mes; // qualquer dia do mês exibido
  final List<EventoAgenda> eventos;
  final ValueChanged<DateTime> onDia;
  final ValueChanged<DateTime> onMes;
  final DateTime? selecionado;

  /// Cor de fundo opcional de cada dia (ex.: cargo do freelancer).
  final Color? Function(DateTime dia)? corDoDia;

  /// Marcas de cada dia (ex.: ícones coloridos). Sem isso, mostra uma bolinha.
  final Widget Function(BuildContext context, List<EventoAgenda> doDia)? marcas;

  /// Proporção largura/altura de cada dia (menor = dia mais alto).
  final double proporcao;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primeiro = DateTime(mes.year, mes.month, 1);
    final diasNoMes = DateTime(mes.year, mes.month + 1, 0).day;
    final deslocamento = primeiro.weekday % 7; // domingo = 0
    final hoje = DateTime.now();
    final celulas = <Widget>[];

    for (var i = 0; i < deslocamento; i++) {
      celulas.add(const SizedBox());
    }
    for (var d = 1; d <= diasNoMes; d++) {
      final dia = DateTime(mes.year, mes.month, d);
      final doDia = eventos.where((e) => e.ocorreEm(dia)).toList();
      final temEvento = doDia.isNotEmpty;
      final ehHoje =
          hoje.year == dia.year && hoje.month == dia.month && hoje.day == dia.day;
      final cor = corDoDia?.call(dia);
      final sel = selecionado != null &&
          selecionado!.year == dia.year &&
          selecionado!.month == dia.month &&
          selecionado!.day == dia.day;
      celulas.add(InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onDia(dia),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: cor?.withValues(alpha: 0.35) ??
                (sel ? scheme.primaryContainer : null),
            border: ehHoje ? Border.all(color: scheme.primary, width: 1.5) : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$d'),
                  const SizedBox(height: 2),
                  if (marcas != null)
                    marcas!(context, doDia)
                  else
                    Icon(Icons.circle,
                        size: 6,
                        color: temEvento ? scheme.primary : Colors.transparent),
                ],
              ),
            ),
          ),
        ),
      ));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onMes(DateTime(mes.year, mes.month - 1, 1)),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${kMeses[mes.month - 1]} ${mes.year}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onMes(DateTime(mes.year, mes.month + 1, 1)),
            ),
          ],
        ),
        Row(
          children: [
            for (final s in kDiasSemana)
              Expanded(child: Center(child: Text(s, style: Theme.of(context).textTheme.labelSmall))),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: proporcao,
          children: celulas,
        ),
      ],
    );
  }
}
