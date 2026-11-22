import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_visual.dart';

/// Cor/ícone de cada tipo de agendamento, compartilhados por toda a equipe.
/// escopo: 'casa_bruxa' (chave = id do atendimento) ou 'geral' (chave = tipo).
class AgendaConfigRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<Map<String, VisualAgenda>> carregar(String escopo) async {
    try {
      final rows = await _db.from('agenda_config').select().eq('escopo', escopo);
      return {
        for (final r in rows as List)
          '${(r as Map)['chave']}': VisualAgenda('${r['cor']}', '${r['icone']}'),
      };
    } catch (_) {
      return {}; // tabela ainda não criada: usa os padrões
    }
  }

  Future<void> salvar(String escopo, String chave, VisualAgenda v) async {
    await _db.from('agenda_config').upsert({
      'escopo': escopo,
      'chave': chave,
      'cor': v.corChave,
      'icone': v.iconeChave,
    }, onConflict: 'escopo,chave');
  }
}
