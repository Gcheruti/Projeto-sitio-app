import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import '../services/registro.dart';
import '../state/auth_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/fundo_gruta.dart';
import '../widgets/pecas.dart';
import '../widgets/tutorial.dart';
import 'grimorio_screen.dart';
import 'abertura_screen.dart';
import 'admin_screen.dart';
import 'hoje_screen.dart';
import 'lives_screen.dart';
import 'perfil_screen.dart';
import 'servicos_sheet.dart';
import 'trilhas_screen.dart';

/// Estrutura principal: cinco abas na barra de baixo, o botão flutuante
/// dos serviços e, no modo /adm, o ícone de ferramentas.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  /// Permite que outras telas troquem de aba (ex.: "Ver trilhas").
  static final aba = ValueNotifier<int>(0);

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen>
    with WidgetsBindingObserver {
  bool _tutorialChecado = false;
  DateTime? _saiuEm;

  @override
  void initState() {
    super.initState();
    appState.carregar();
    WidgetsBinding.instance.addObserver(this);
    // Sessão que já estava salva = abriu o app (o login já foi registrado).
    if (authState.acabouDeEntrar) {
      authState.acabouDeEntrar = false;
    } else {
      Registro.evento('app_aberto');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Voltou ao app depois de 30 min ou mais em segundo plano.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.paused) {
      _saiuEm = DateTime.now();
    } else if (estado == AppLifecycleState.resumed && _saiuEm != null) {
      if (DateTime.now().difference(_saiuEm!).inMinutes >= 30) {
        Registro.evento('app_retomado');
      }
      _saiuEm = null;
    }
  }

  /// Na primeira vez que a conta chega às abas, mostra o tutorial.
  void _talvezTutorial() {
    if (_tutorialChecado) return;
    _tutorialChecado = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await authState.precisaTutorial() || !mounted) return;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      ShellScreen.aba.value = 0;
      await mostrarTutorial(Navigator.of(context));
      await authState.marcarTutorialVisto();
      Registro.evento('tutorial_concluido');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, ShellScreen.aba]),
      builder: (context, _) {
        if (appState.carregando && appState.trilhas.isEmpty) {
          return Scaffold(
            body: FundoGruta(
              child: Center(
                  child: CircularProgressIndicator(color: GrutaCores.chama)),
            ),
          );
        }
        if (appState.erro != null && appState.trilhas.isEmpty) {
          return Scaffold(
            body: FundoGruta(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(appState.erro!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    OutlinedButton(
                        onPressed: appState.carregar,
                        child: const Text('Tentar de novo')),
                  ]),
                ),
              ),
            ),
          );
        }
        // Primeiro acesso da conta: escolher interesses e ritual diário.
        // Fica salvo no perfil, então não aparece de novo nos próximos logins.
        if (!appState.carregando && appState.perfil.trilhasInteresse.isEmpty) {
          return const AberturaScreen();
        }
        final aba = ShellScreen.aba.value;
        if (!appState.carregando) _talvezTutorial();
        return Scaffold(
          body: FundoGruta(
            child: Stack(children: [
              IndexedStack(
                index: aba,
                children: const [
                  HojeScreen(),
                  TrilhasScreen(),
                  GrimorioScreen(),
                  LivesScreen(),
                  PerfilScreen(),
                ],
              ),
              const _BotoesDoTopo(),
            ]),
          ),
          bottomNavigationBar: NavigationBar(
            key: TutorialAlvos.abas,
            selectedIndex: aba,
            onDestinationSelected: (i) => ShellScreen.aba.value = i,
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.local_fire_department_outlined),
                  selectedIcon: Icon(Icons.local_fire_department),
                  label: 'Hoje'),
              NavigationDestination(
                  icon: Icon(Icons.auto_stories_outlined),
                  selectedIcon: Icon(Icons.auto_stories),
                  label: 'Trilhas'),
              NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book),
                  label: 'Grimório'),
              NavigationDestination(
                  icon: Icon(Icons.live_tv_outlined),
                  selectedIcon: Icon(Icons.live_tv),
                  label: 'Lives'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: 'Perfil'),
            ],
          ),
        );
      },
    );
  }
}

/// Botões flutuantes do canto superior direito: "Conheça nossos outros
/// serviços" e, no modo /adm, as ferramentas. As abas deixam esse canto
/// livre (ReservaTopo), então eles não cobrem títulos nem números.
class _BotoesDoTopo extends StatelessWidget {
  const _BotoesDoTopo();

  @override
  Widget build(BuildContext context) {
    final topo = MediaQuery.of(context).padding.top;
    return Positioned(
      right: GrutaMedidas.margem - 4,
      top: topo + 14,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (ReservaTopo.comAdmin) ...[
          _Redondo(
            icone: Icons.construction,
            cor: GrutaCores.musgo,
            dica: 'Painel de administração',
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminScreen())),
          ),
          const SizedBox(width: 8),
        ],
        _Redondo(
          key: TutorialAlvos.servicos,
          icone: Icons.storefront_outlined,
          cor: GrutaCores.ouro,
          dica: 'Conheça nossos outros serviços',
          onTap: () => mostrarServicos(context),
        ),
      ]),
    );
  }
}

class _Redondo extends StatelessWidget {
  const _Redondo(
      {super.key,
      required this.icone,
      required this.cor,
      required this.dica,
      required this.onTap});
  final IconData icone;
  final Color cor;
  final String dica;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: dica,
        child: Material(
          color: GrutaCores.rochaClara.withValues(alpha: .95),
          shape: CircleBorder(side: BorderSide(color: cor.withValues(alpha: .6))),
          elevation: 3,
          shadowColor: Colors.black54,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
                width: 40, height: 40, child: Icon(icone, size: 20, color: cor)),
          ),
        ),
      );
}
