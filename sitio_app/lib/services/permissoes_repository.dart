import 'package:supabase_flutter/supabase_flutter.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class PermissoesRepository {
  SupabaseClient get _db => Supabase.instance.client;

  /// perfil -> (permissão -> ligado). Null se não deu para ler (sem rede/tabela).
  Future<Map<String, Map<String, bool>>?> carregarTudo() async {
    try {
      final rows = await _db.from('permissoes_perfil').select();
      final out = <String, Map<String, bool>>{};
      for (final r in rows as List) {
        final m = r as Map;
        (out['${m['perfil']}'] ??= {})['${m['permissao']}'] = m['habilitado'] == true;
      }
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<void> salvar(String perfil, String permissao, bool habilitado) async {
    await _db.from('permissoes_perfil').upsert({
      'perfil': perfil,
      'permissao': permissao,
      'habilitado': habilitado,
    }, onConflict: 'perfil,permissao');
  }

  /// Apaga as escolhas do perfil (volta ao padrão).
  Future<void> restaurar(String perfil) async {
    await _db.from('permissoes_perfil').delete().eq('perfil', perfil);
  }

  /// Função (cargo) do freelancer hoje, ou null se não há diária agendada.
  Future<String?> cargoDeHoje(String usuarioId) async {
    try {
      final rows = await _db
          .from('freelancer_dias')
          .select('cargo')
          .eq('usuario_id', usuarioId)
          .eq('dia', _iso(DateTime.now()));
      if ((rows as List).isEmpty) return null;
      return '${(rows.first as Map)['cargo']}';
    } catch (_) {
      return null;
    }
  }
}
