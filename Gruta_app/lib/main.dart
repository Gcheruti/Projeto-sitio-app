import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'screens/entrar_screen.dart';
import 'screens/shell_screen.dart';
import 'services/lembrete_service.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'state/tema_state.dart';
import 'theme/gruta_tema.dart';
import 'widgets/fundo_gruta.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppConfig.temSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      // Tudo da Gruta mora no schema "gruta" do projeto Supabase.
      postgrestOptions: const PostgrestClientOptions(schema: 'gruta'),
    );
  }
  appState.usarRepositorio(supabase: AppConfig.temSupabase);
  await temaState.restaurar();
  await authState.restaurar();
  unawaited(LembreteService.iniciar()); // sem await: se falhar, o app segue

  runApp(const GrutaApp());
}

class GrutaApp extends StatefulWidget {
  const GrutaApp({super.key});

  @override
  State<GrutaApp> createState() => _GrutaAppState();
}

class _GrutaAppState extends State<GrutaApp> with WidgetsBindingObserver {
  int _geracao = 0; // muda quando o tema muda: reconstrói o app inteiro

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    temaState.addListener(_reaplicar);
    temaState.aplicar(_brilhoDoAparelho);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    temaState.removeListener(_reaplicar);
    super.dispose();
  }

  Brightness get _brilhoDoAparelho =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  @override
  void didChangePlatformBrightness() => _reaplicar();

  void _reaplicar() {
    if (temaState.aplicar(_brilhoDoAparelho)) setState(() => _geracao++);
  }

  @override
  Widget build(BuildContext context) {
    final tema = GrutaTema.construir();
    return MaterialApp(
      key: ValueKey(_geracao),
      title: AppConfig.modoAdm ? 'Gruta · Administração' : 'Gruta',
      debugShowCheckedModeBanner: false,
      theme: tema,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      // Mesmo layout em todos os dispositivos: coluna central de até 480 px.
      builder: (context, child) =>
          MolduraApp(child: child ?? const SizedBox.shrink()),
      home: const _Portao(),
    );
  }
}

/// Decide a primeira tela: entrar (cadastro/login) -> app. A escolha de
/// interesses e do ritual aparece dentro do app, no primeiro acesso da conta.
class _Portao extends StatelessWidget {
  const _Portao();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: authState,
      builder: (context, _) {
        if (!authState.logado) return const EntrarScreen();
        return const ShellScreen();
      },
    );
  }
}
