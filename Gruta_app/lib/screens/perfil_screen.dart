import 'package:material_ui/material_ui.dart';

import '../logic/datas.dart';
import '../logic/ofensiva.dart';
import '../services/lembrete_service.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';
import 'configuracoes_screen.dart';
import 'planos_sheet.dart';

/// Aba Perfil: números, plano, ritual, sair e excluir conta. A engrenagem
/// abre as Configurações.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final p = appState.perfil;
        final o = appState.ofensiva;
        final nome = p.nome.isEmpty ? 'Visitante' : p.nome;
        return SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                GrutaMedidas.margem, 24, GrutaMedidas.margem, 40),
            children: [
              Row(children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [GrutaCores.brasa, GrutaCores.ouro]),
                    boxShadow: [
                      BoxShadow(
                          color: GrutaCores.chama.withValues(alpha: .3),
                          blurRadius: 24),
                    ],
                  ),
                  child: Center(
                    child: Text(nome.characters.first.toUpperCase(),
                        style: GrutaTema.titulo(36, cor: GrutaCores.noite)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nome, style: GrutaTema.titulo(30)),
                      Text(
                        'Grau: ${grauIniciatico(appState.totalDias)}',
                        style: TextStyle(
                            color: GrutaCores.chama,
                            fontWeight: FontWeight.w700),
                      ),
                      if (p.login.isNotEmpty)
                        Text('@${p.login}',
                            style: TextStyle(
                                color: GrutaCores.textoApagado,
                                fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Configurações',
                  icon: Icon(Icons.settings_outlined,
                      color: GrutaCores.textoSuave),
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const ConfiguracoesScreen())),
                ),
                const ReservaTopo(),
              ]),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  _Numero(Icons.local_fire_department, '${o.atual}',
                      'dias acesos', GrutaCores.chama),
                  _Numero(Icons.emoji_events_outlined, '${o.recorde}',
                      'recorde', GrutaCores.ouro),
                  _Numero(Icons.play_circle_outline,
                      '${appState.totalAulas}', 'aulas vistas',
                      GrutaCores.arenito),
                  _Numero(Icons.nightlight_round, '${appState.moedas}',
                      'moedas', GrutaCores.ouro),
                ],
              ),
              const SizedBox(height: 16),
              CartaoPedra(
                brilho: GrutaCores.ouro,
                onTap: () => mostrarPlanos(context),
                child: Row(children: [
                  Icon(Icons.auto_awesome,
                      color: GrutaCores.ouro, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Plano ${p.plano.nome}',
                              style: GrutaTema.titulo(24)),
                          Text(
                              p.plano.todasAsTrilhas
                                  ? 'Todas as trilhas abertas'
                                  : 'Ver planos e o que cada um libera',
                              style: TextStyle(
                                  color: GrutaCores.textoSuave, fontSize: 13)),
                        ]),
                  ),
                  Icon(Icons.chevron_right,
                      color: GrutaCores.textoApagado),
                ]),
              ),
              const SizedBox(height: 28),
              const Olho('Seu ritual'),
              const SizedBox(height: 10),
              CartaoPedra(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  ListTile(
                    leading: Icon(Icons.timer_outlined,
                        color: GrutaCores.chama),
                    title: const Text('Meta diária'),
                    trailing: SegmentedButton<int>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(
                          visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(value: 5, label: Text('5')),
                        ButtonSegment(value: 10, label: Text('10')),
                        ButtonSegment(value: 15, label: Text('15')),
                      ],
                      selected: {p.metaMinutos},
                      onSelectionChanged: (s) => appState
                          .salvarPerfil(p.copyWith(metaMinutos: s.first)),
                    ),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    secondary: Icon(Icons.notifications_outlined,
                        color: GrutaCores.chama),
                    title: const Text('Lembrete diário'),
                    subtitle: Text(
                      LembreteService.suportado
                          ? 'Só nos dias de vela apagada'
                          : 'Disponível no app de celular',
                      style: TextStyle(
                          color: GrutaCores.textoApagado, fontSize: 12.5),
                    ),
                    value: p.lembreteAtivo,
                    onChanged: (v) async {
                      if (v) await LembreteService.pedirPermissao();
                      await appState
                          .salvarPerfil(p.copyWith(lembreteAtivo: v));
                    },
                  ),
                  ListTile(
                    enabled: p.lembreteAtivo,
                    leading: Icon(Icons.schedule,
                        color: GrutaCores.chama),
                    title: const Text('Horário do lembrete'),
                    trailing: Text(hora(p.lembreteHora, p.lembreteMinuto),
                        style: GrutaTema.titulo(24, cor: GrutaCores.chama)),
                    onTap: () async {
                      final h = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                            hour: p.lembreteHora, minute: p.lembreteMinuto),
                      );
                      if (h != null) {
                        await appState.salvarPerfil(p.copyWith(
                            lembreteHora: h.hour, lembreteMinuto: h.minute));
                      }
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 28),
              const Olho('Conta'),
              const SizedBox(height: 10),
              CartaoPedra(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(children: [
                  if (authState.modoDemo)
                    ListTile(
                      leading: Icon(Icons.science_outlined,
                          color: GrutaCores.textoSuave),
                      title: const Text('Simular 12 dias da Jornada'),
                      subtitle: Text('Só na demonstração',
                          style: TextStyle(
                              color: GrutaCores.textoApagado, fontSize: 12.5)),
                      onTap: () => appState.simularDias(12),
                    ),
                  ListTile(
                    leading:
                        Icon(Icons.logout, color: GrutaCores.textoSuave),
                    title: const Text('Sair'),
                    onTap: authState.sair,
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_forever_outlined,
                        color: GrutaCores.erro),
                    title: Text('Excluir minha conta',
                        style: TextStyle(color: GrutaCores.erro)),
                    onTap: () => _excluir(context),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text('Gruta · versão 1.0.0',
                    style: TextStyle(
                        color: GrutaCores.textoApagado, fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _excluir(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GrutaCores.rocha,
        title: const Text('Excluir sua conta?'),
        content: const Text(
            'Apaga seu progresso, sua ofensiva e seu Grimório para sempre.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Excluir',
                  style: TextStyle(color: GrutaCores.erro))),
        ],
      ),
    );
    if (ok != true) return;
    await appState.excluirConta();
    await authState.sair();
  }
}

class _Numero extends StatelessWidget {
  const _Numero(this.icone, this.valor, this.rotulo, this.cor);
  final IconData icone;
  final String valor;
  final String rotulo;
  final Color cor;

  @override
  Widget build(BuildContext context) => CartaoPedra(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Icon(icone, color: cor, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(valor, style: GrutaTema.titulo(30)),
                Text(rotulo,
                    style: TextStyle(
                        color: GrutaCores.textoSuave, fontSize: 12.5)),
              ],
            ),
          ),
        ]),
      );
}
