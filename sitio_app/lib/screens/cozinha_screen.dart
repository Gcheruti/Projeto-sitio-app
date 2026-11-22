import 'dart:async';

import 'package:flutter/material.dart';

import '../services/realtime_sync.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import 'pedidos_screen.dart';
import 'tema_sheet.dart';

/// Login "Cozinha": abre só em "Pedidos em processo", sem as outras abas.
class CozinhaShell extends StatefulWidget {
  const CozinhaShell({super.key});

  @override
  State<CozinhaShell> createState() => _CozinhaShellState();
}

class _CozinhaShellState extends State<CozinhaShell> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    appState.atualizarSilencioso();
    RealtimeSync.instance.iniciar();
    RealtimeSync.instance.tick.addListener(_recarregar);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _rodada++;
      if (RealtimeSync.instance.devePuxar(_rodada)) _recarregar();
    });
  }

  int _rodada = 0;

  void _recarregar() {
    appState.atualizarSilencioso();
  }

  @override
  void dispose() {
    _timer?.cancel();
    RealtimeSync.instance.tick.removeListener(_recarregar);
    RealtimeSync.instance.parar();
    super.dispose();
  }

  Future<void> _sair() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Será preciso entrar de novo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sair')),
        ],
      ),
    );
    if (ok == true) await authState.sair();
  }

  void _abrirAjustes() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tema do aplicativo'),
              onTap: () {
                Navigator.pop(ctx);
                abrirEscolhaDeTema(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair (logout)'),
              onTap: () {
                Navigator.pop(ctx);
                _sair();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PedidosScreen(
      leading: IconButton(
        tooltip: 'Ajustes',
        icon: const Icon(Icons.settings_outlined),
        onPressed: _abrirAjustes,
      ),
    );
  }
}
