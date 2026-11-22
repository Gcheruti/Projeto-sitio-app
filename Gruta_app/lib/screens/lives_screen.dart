import 'package:material_ui/material_ui.dart';

import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';

/// Aba Lives: por enquanto, só o aviso de que está sendo preparada.
/// Depois: calendário das lives e o player ao vivo dentro do app.
class LivesScreen extends StatelessWidget {
  const LivesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
            GrutaMedidas.margem, 20, GrutaMedidas.margem, 40),
        children: [
          const Olho('Ao vivo'),
          const SizedBox(height: 6),
          Text('Lives', style: GrutaTema.titulo(40)),
          const SizedBox(height: 6),
          Text('Encontros ao vivo com a equipe da Gruta.',
              style: TextStyle(color: GrutaCores.textoSuave)),
          const SizedBox(height: 22),
          CartaoPedra(
            brilho: GrutaCores.chama,
            child: Column(children: [
              const SizedBox(height: 8),
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GrutaCores.chama.withValues(alpha: .12),
                  border: Border.all(
                      color: GrutaCores.chama.withValues(alpha: .5)),
                ),
                child: Icon(Icons.live_tv_rounded,
                    size: 44, color: GrutaCores.chama),
              ),
              const SizedBox(height: 16),
              Text('Em desenvolvimento',
                  textAlign: TextAlign.center, style: GrutaTema.titulo(30)),
              const SizedBox(height: 8),
              Text(
                'Em breve, aqui você vai ver o calendário das lives e '
                'assistir sem sair do app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GrutaCores.textoSuave, height: 1.5),
              ),
              const SizedBox(height: 8),
            ]),
          ),
          const SizedBox(height: 22),
          const Olho('O que vem por aí'),
          const SizedBox(height: 10),
          for (final (icone, texto) in const [
            (Icons.calendar_month_outlined, 'Calendário das próximas lives'),
            (Icons.notifications_active_outlined,
                'Aviso quando uma live começar'),
            (Icons.play_circle_outline, 'Assistir ao vivo e rever depois'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Icon(icone, color: GrutaCores.ouro),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(texto,
                        style: TextStyle(color: GrutaCores.textoSuave))),
              ]),
            ),
        ],
      ),
    );
  }
}
