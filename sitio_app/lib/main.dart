import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'screens/shell_screen.dart';
import 'screens/detalhe_comanda_screen.dart';
import 'screens/login_screen.dart';
import 'screens/totem_screen.dart';
import 'screens/cozinha_screen.dart';
import 'services/fila_offline.dart';
import 'services/icone_mensal.dart';
import 'services/nfc_service.dart';
import 'services/push_service.dart';
import 'state/app_state.dart';
import 'state/auth_state.dart';
import 'state/permissoes_state.dart';
import 'theme/temas_mensais.dart';
import 'widgets/natureza_overlay.dart';



final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Tag NFC de comanda encostada em qualquer tela: abre a comanda.
void _abrirComandaDaTag(String codigo) {
  if (!authState.logado) return;
  if (authState.usuario?.isCozinha ?? false) return;
  if (!(authState.usuario?.isTotem ?? false) && !permissoes.pode('aba_comandas')) return;
  if (authState.usuario?.isTotem ?? false) {
    TotemTags.disparar(codigo);
    return;
  }
  final c = appState.buscarComandaPorCodigo(codigo);
  if (c == null) {
    messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('Comanda não encontrada: $codigo')),
    );
    return;
  }
  navigatorKey.currentState?.push(
    MaterialPageRoute(builder: (_) => DetalheComandaScreen(comandaId: c.id)),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  await authState.restaurar();
  permissoes.iniciar();
  await temaState.restaurar();
  await filaOffline.restaurar(); // mudanças feitas sem rede na última vez
  unawaited(filaOffline.sincronizar());
  await appState.carregarDoServidor();

  runApp(const SitioApp());
  IconeMensal.iniciar();
  PushService.iniciar(); // sem await: se o Firebase falhar, o app segue normal
  NfcService.iniciarEscutaGlobal(_abrirComandaDaTag);
}

class SitioApp extends StatelessWidget {
  const SitioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, authState, temaState]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Sítio',
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          debugShowCheckedModeBanner: false,
          theme: temaState.tema,
          scrollBehavior: const RolagemTodosOsDispositivos(),
          builder: (context, child) {
            final fixo = (authState.usuario?.isTotem ?? false) ||
                (authState.usuario?.isCozinha ?? false);
            Widget corpo = child ?? const SizedBox.shrink();
            // Em tela larga (computador/navegador) o conteúdo não estica:
            // fica numa coluna central. Totem e cozinha usam a tela toda.
            if (!fixo && MediaQuery.of(context).size.width > (ehSite ? 1240 : 1100)) {
              corpo = FundoTextura(
                child: ColoredBox(
                  color: temaState.fundoAtual,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: ehSite ? 1240 : 1100),
                      child: DecoratedBox(
                        decoration: ehSite
                            ? BoxDecoration(
                                border: Border.symmetric(
                                  vertical: BorderSide(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outlineVariant),
                                ),
                              )
                            : const BoxDecoration(boxShadow: [
                                BoxShadow(
                                    color: Color(0x33000000), blurRadius: 24),
                              ]),
                        child: ClipRect(child: corpo),
                      ),
                    ),
                  ),
                ),
              );
            }
            // Camada de natureza animada por cima (não recebe toque); opcional.
            if (temaState.efeitos) {
              return NaturezaOverlay(
                  estacao: temaState.estacao, child: LuzAmbiente(child: corpo));
            }
            return LuzAmbiente(child: corpo);
          },
          home: authState.logado
              ? ((authState.usuario?.isTotem ?? false)
                  ? const TotemShell()
                  : (authState.usuario?.isCozinha ?? false)
                      ? const CozinhaShell()
                      : ShellScreen(key: ShellScreen.navKey))
              : const LoginScreen(),
          
        );
      },
    );
  }
}
