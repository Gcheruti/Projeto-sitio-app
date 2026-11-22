import 'package:flutter/material.dart';

/// Barras verticais simples (rótulo embaixo de cada barra).
class GraficoBarras extends StatelessWidget {
  const GraficoBarras({
    super.key,
    required this.dados,
    this.altura = 150,
    this.mostrarValores = false,
    this.formato,
  });

  final List<(String, double)> dados;
  final double altura;
  final bool mostrarValores;
  final String Function(double)? formato;

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    final maximo = dados.fold<double>(0, (m, e) => e.$2 > m ? e.$2 : m);
    if (dados.isEmpty || maximo <= 0) {
      return SizedBox(
        height: altura,
        child: const Center(child: Text('Sem dados no período')),
      );
    }
    const reserva = 34.0; // espaço de rótulos
    return SizedBox(
      height: altura,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in dados)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (mostrarValores)
                      Text(
                        (formato ?? (v) => v.toStringAsFixed(0))(e.$2),
                        style: const TextStyle(fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                    Container(
                      height: e.$2 <= 0
                          ? 0
                          : ((altura - reserva) * (e.$2 / maximo))
                              .clamp(2.0, altura),
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(3)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.$1,
                      style: const TextStyle(fontSize: 9),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barras horizontais (rótulo à esquerda, valor à direita).
class GraficoHorizontal extends StatelessWidget {
  const GraficoHorizontal({
    super.key,
    required this.dados,
    this.cores,
    this.formato,
  });

  final List<(String, double)> dados;
  final List<Color>? cores;
  final String Function(double)? formato;

  @override
  Widget build(BuildContext context) {
    final padrao = Theme.of(context).colorScheme.primary;
    final maximo =
        dados.fold<double>(0, (m, e) => e.$2.abs() > m ? e.$2.abs() : m);
    if (dados.isEmpty || maximo <= 0) {
      return const SizedBox(
        height: 60,
        child: Center(child: Text('Sem dados no período')),
      );
    }
    final fmt = formato ?? (v) => v.toStringAsFixed(0);
    return Column(
      children: [
        for (var i = 0; i < dados.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    dados[i].$1,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 16,
                        width: (box.maxWidth * (dados[i].$2.abs() / maximo))
                            .clamp(2.0, box.maxWidth),
                        decoration: BoxDecoration(
                          color: (cores != null && i < cores!.length)
                              ? cores![i]
                              : padrao,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(fmt(dados[i].$2), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}
