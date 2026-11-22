import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/auth_state.dart';
import 'dispositivo_service.dart';

/// Push (FCM) do app da equipe. O Firebase só ENTREGA o aviso; os dados
/// continuam no Supabase. Este serviço apenas registra o "endereço" (token)
/// deste aparelho na tabela dispositivos_push, junto com o papel de quem
/// está logado, para o servidor saber a quem avisar.
/// Tudo é protegido por try/catch: se o push falhar, o app funciona igual.
class PushService {
  PushService._();

  static bool _ok = false;
  static String? _token;
  static String? _usuarioId; // usuário com token registrado agora

  static Future<void> iniciar() async {
    try {
      await Firebase.initializeApp();
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(); // Android 13+: pede permissão de avisos
      _token = await fm.getToken();
      _ok = _token != null;
      fm.onTokenRefresh.listen((t) {
        _token = t;
        _usuarioId = null;
        _sincronizar();
      });
      // App aberto: o Android não mostra o aviso sozinho, então mostramos.
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        DispositivoService.mostrarNotificacao(n.title ?? 'Sítio', n.body ?? '');
      });
      authState.addListener(_sincronizar);
      await _sincronizar();
    } catch (e) {
      debugPrint('Push desativado: $e');
    }
  }

  static Future<void> _sincronizar() async {
    if (!_ok || _token == null) return;
    final u = authState.usuario;
    try {
      final db = Supabase.instance.client;
      if (u == null) {
        // saiu: este aparelho deixa de receber avisos do usuário anterior
        if (_usuarioId != null) {
          await db.from('dispositivos_push').delete().eq('token', _token!);
          _usuarioId = null;
        }
        return;
      }
      if (_usuarioId == u.id) return;
      await db.from('dispositivos_push').upsert({
        'token': _token,
        'usuario_id': u.id,
        'papel': u.papel,
        'atualizado_em': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
      _usuarioId = u.id;
    } catch (e) {
      debugPrint('Push: falha ao registrar token: $e');
    }
  }
}
