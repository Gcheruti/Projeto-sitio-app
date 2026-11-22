import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Registro de acessos: grava em `gruta.eventos` quem fez o quê e quando
/// (login, logout, app aberto, aula aberta...). Ver a migração
/// 20261121000004_gruta_acessos.sql e as visões gruta.v_acessos etc.
///
/// Aula concluída, trilha liberada e troca de plano o próprio banco grava.
///
/// Nunca atrapalha o app: sem internet ou com erro, o evento é descartado.
/// No modo demonstração fica numa lista no aparelho (últimos 300).
class Registro {
  Registro._();

  static const _kLocal = 'gruta_eventos';
  static final _uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false);

  /// android, ios, web, macos, windows ou linux.
  static String get plataforma =>
      kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();

  static Future<void> evento(
    String tipo, {
    String? aulaId,
    String? trilhaId,
    Map<String, dynamic>? detalhes,
  }) async {
    try {
      if (!AppConfig.temSupabase) return await _local(tipo, aulaId, trilhaId);
      final db = Supabase.instance.client;
      if (db.auth.currentUser == null) return;
      await db.rpc('registrar_evento', params: {
        'p_tipo': tipo,
        'p_aula_id': _ehUuid(aulaId) ? aulaId : null,
        'p_trilha_id': _ehUuid(trilhaId) ? trilhaId : null,
        'p_plataforma': plataforma,
        'p_versao': AppConfig.versaoApp,
        'p_detalhes': detalhes ?? const <String, dynamic>{},
      }).timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Registro "$tipo" não gravado: $e');
    }
  }

  static bool _ehUuid(String? id) => id != null && _uuid.hasMatch(id);

  static Future<void> _local(
      String tipo, String? aulaId, String? trilhaId) async {
    final p = await SharedPreferences.getInstance();
    final lista = (jsonDecode(p.getString(_kLocal) ?? '[]') as List)
      ..add({
        'tipo': tipo,
        'aula_id': aulaId,
        'trilha_id': trilhaId,
        'plataforma': plataforma,
        'criado_em': DateTime.now().toIso8601String(),
      });
    final ultimos =
        lista.length > 300 ? lista.sublist(lista.length - 300) : lista;
    await p.setString(_kLocal, jsonEncode(ultimos));
  }
}
