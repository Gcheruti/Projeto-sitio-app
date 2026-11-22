import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Atualização em tempo real: o Supabase avisa o app assim que algo muda
/// numa das tabelas abaixo (precisa do script supabase/realtime.sql).
///
/// Quando o aviso chega, [tick] muda e as telas recarregam os dados.
/// Se o tempo real não estiver ativo (script não rodado, sem rede), [conectado]
/// fica false e as telas continuam consultando a cada 5 s, como antes.
/// Com o tempo real ativo, a consulta de segurança cai para a cada 30 s.
class RealtimeSync {
  RealtimeSync._();
  static final RealtimeSync instance = RealtimeSync._();

  static const List<String> tabelas = [
    'produtos',
    'comandas',
    'itens_comanda',
    'notificacoes',
    'lotes',
    'agenda_eventos',
    'comanda_avisos',
  ];

  /// Sobe a cada mudança detectada (já agrupada em ~0,4 s).
  final ValueNotifier<int> tick = ValueNotifier(0);

  bool conectado = false;
  RealtimeChannel? _canal;
  Timer? _agrupar;
  int _usos = 0;

  /// Quantas rodadas de 5 s esperar entre consultas de segurança.
  static const int _rodadasComTempoReal = 6; // 6 x 5 s = 30 s

  /// Use dentro do timer de 5 s: true quando é hora de consultar.
  bool devePuxar(int rodada) => !conectado || rodada % _rodadasComTempoReal == 0;

  void _avisar() {
    _agrupar?.cancel();
    _agrupar = Timer(const Duration(milliseconds: 400), () => tick.value++);
  }

  void iniciar() {
    _usos++;
    if (_canal != null) return;
    try {
      var canal = Supabase.instance.client.channel('sitio-sync');
      for (final t in tabelas) {
        canal = canal.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: t,
          callback: (_) => _avisar(),
        );
      }
      _canal = canal.subscribe((status, [erro]) {
        final ok = status == RealtimeSubscribeStatus.subscribed;
        if (ok != conectado) {
          conectado = ok;
          debugPrint('Tempo real: ${ok ? 'conectado' : 'desconectado'} ${erro ?? ''}');
        }
        // ao (re)conectar, busca tudo para não perder o que mudou fora do ar
        if (ok) _avisar();
      });
    } catch (e) {
      conectado = false;
      debugPrint('Tempo real indisponível: $e');
    }
  }

  void parar() {
    if (_usos > 0) _usos--;
    if (_usos > 0) return;
    final c = _canal;
    _canal = null;
    conectado = false;
    _agrupar?.cancel();
    if (c != null) {
      try {
        Supabase.instance.client.removeChannel(c);
      } catch (_) {}
    }
  }
}
