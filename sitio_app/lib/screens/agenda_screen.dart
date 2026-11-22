import 'package:flutter/material.dart';

import '../state/permissoes_state.dart';
import 'agenda_bruxa_screen.dart';
import 'agenda_geral_screen.dart';

/// Escolha entre a agenda Geral e a agenda da Casa da Bruxa.
class AgendaScreen extends StatelessWidget {
  const AgendaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendamentos')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (permissoes.pode('agenda_geral'))
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Geral'),
              subtitle: const Text('Calendário do mês e eventos futuros'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgendaGeralScreen()),
              ),
            ),
          ),
          if (permissoes.pode('agenda_bruxa'))
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Casa da Bruxa'),
              subtitle: const Text('Atendimentos do dia por horário'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AgendaBruxaScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
