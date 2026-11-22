import 'package:material_ui/material_ui.dart';

import '../logic/datas.dart';
import '../models/trilha.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';

/// Caixa de avisos: as notificações enviadas pela equipe no painel /adm.
Future<void> mostrarAvisos(BuildContext context) {
  appState.marcarAvisosVistos();
  return abrirFolha(
    context,
    (context) => ListenableBuilder(
      listenable: appState,
      builder: (context, _) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Puxador(),
          const SizedBox(height: 20),
          const Olho('Da Gruta para você'),
          const SizedBox(height: 6),
          Text('Avisos', style: GrutaTema.titulo(32)),
          const SizedBox(height: 14),
          if (appState.avisos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text('Nenhum aviso por enquanto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GrutaCores.textoSuave)),
            ),
          for (final a in appState.avisos) ...[
            CartaoPedra(
              padding: const EdgeInsets.all(14),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GrutaCores.chama.withValues(alpha: .14),
                  ),
                  child: Icon(kIconesAviso[a.icone] ?? Icons.notifications,
                      color: GrutaCores.chama),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.titulo,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15.5)),
                      if (a.descricao.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(a.descricao,
                            style: TextStyle(
                                color: GrutaCores.textoSuave, height: 1.4)),
                      ],
                      const SizedBox(height: 6),
                      Text(dataCurta(a.criadaEm),
                          style: TextStyle(
                              color: GrutaCores.textoApagado, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    ),
  );
}
