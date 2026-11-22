import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../state/auth_state.dart';

/// Alertas para administradores quando staff/freelancer mexe em comandas
/// (desconto, item removido, comanda zerada/reaberta/excluída/fechada, aviso).
/// Quando quem faz a ação já é Adm, não gera alerta.
/// Aparecem na central de avisos dos Adm (e como faixa no app aberto).
class AvisosAdmin {
  AvisosAdmin._();

  static void notificar(String titulo, String descricao) {
    final u = authState.usuario;
    if (u == null || u.isAdm) return;
    unawaited(() async {
      final db = Supabase.instance.client;
      final id = 'adm_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
      try {
        await db.from('notificacoes').insert({
          'id': id,
          'titulo': titulo,
          'descricao': '${u.nome} (${u.papelTexto}): $descricao',
          'ativa': true,
          'local': null,
          'criado_por': u.nome,
          'somente_adm': true,
        });
      } catch (e) {
        // Sem plano B: gravar sem a marca "somente_adm" mostraria o alerta
        // para toda a equipe. Se falhar (rede, coluna ausente), só registra.
        debugPrint('Alerta para Adm não enviado: $e');
      }
    }());
  }
}
