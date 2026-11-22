import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/freelancer.dart';
import '../models/usuario.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

double _num(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

class FreelancerRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Usuario>> listar() async {
    final rows = await _db
        .from('usuarios')
        .select()
        .eq('papel', 'freelancer')
        .order('nome');
    return (rows as List)
        .map((r) => Usuario.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Valor da diária por cargo (chave -> valor).
  Future<Map<String, double>> valoresCargos() async {
    final out = {for (final c in kCargosFreelancer) c.chave: 100.0};
    try {
      final rows = await _db.from('freelancer_cargos').select();
      for (final r in rows as List) {
        final m = r as Map;
        out['${m['cargo']}'] = _num(m['valor']);
      }
    } catch (e) {
      debugPrint('freelancer_cargos indisponível: $e');
    }
    return out;
  }

  Future<void> salvarValorCargo(String cargo, double valor) async {
    await _db
        .from('freelancer_cargos')
        .upsert({'cargo': cargo, 'valor': valor});
  }

  Future<List<DiaFreelancer>> dias(String usuarioId) async {
    final rows = await _db
        .from('freelancer_dias')
        .select()
        .eq('usuario_id', usuarioId)
        .order('dia');
    return (rows as List).map((r) {
      final m = r as Map;
      final d = DateTime.parse('${m['dia']}');
      return DiaFreelancer(
        id: '${m['id']}',
        usuarioId: '${m['usuario_id']}',
        dia: DateTime(d.year, d.month, d.day),
        cargo: '${m['cargo']}',
        valor: _num(m['valor']),
        loginEm: m['login_em'] == null
            ? null
            : DateTime.parse('${m['login_em']}').toLocal(),
        logoutEm: m['logout_em'] == null
            ? null
            : DateTime.parse('${m['logout_em']}').toLocal(),
      );
    }).toList();
  }

  /// Todos os dias agendados de todos os freelancers em um mês.
  Future<List<DiaFreelancer>> diasDoMes(DateTime mes) async {
    final ini = DateTime(mes.year, mes.month, 1);
    final fim = DateTime(mes.year, mes.month + 1, 1);
    final rows = await _db
        .from('freelancer_dias')
        .select()
        .gte('dia', _iso(ini))
        .lt('dia', _iso(fim))
        .order('dia');
    return (rows as List).map((r) {
      final m = r as Map;
      final d = DateTime.parse('${m['dia']}');
      return DiaFreelancer(
        id: '${m['id']}',
        usuarioId: '${m['usuario_id']}',
        dia: DateTime(d.year, d.month, d.day),
        cargo: '${m['cargo']}',
        valor: _num(m['valor']),
        loginEm: m['login_em'] == null
            ? null
            : DateTime.parse('${m['login_em']}').toLocal(),
        logoutEm: m['logout_em'] == null
            ? null
            : DateTime.parse('${m['logout_em']}').toLocal(),
      );
    }).toList();
  }

  Future<void> definirDia({
    required String usuarioId,
    required DateTime dia,
    required String cargo,
    required double valor,
    String? criadoPor,
  }) async {
    await _db.from('freelancer_dias').upsert({
      'usuario_id': usuarioId,
      'dia': _iso(dia),
      'cargo': cargo,
      'valor': valor,
      'criado_por': criadoPor,
    }, onConflict: 'usuario_id,dia');
  }

  Future<void> removerDia(String id) async {
    await _db.from('freelancer_dias').delete().eq('id', id);
  }

  /// Chamado quando o freelancer entra no app. Se hoje é um dia agendado e
  /// ainda não houve login, registra a presença e lança o gasto no financeiro.
  Future<void> registrarEntrada(Usuario u) async {
    try {
      final hoje = DateTime.now();
      final rows = await _db
          .from('freelancer_dias')
          .select()
          .eq('usuario_id', u.id)
          .eq('dia', _iso(hoje));
      if ((rows as List).isEmpty) return;
      final m = rows.first as Map;
      if (m['login_em'] != null) return; // já contou hoje
      final valor = _num(m['valor']);
      final cargo = cargoPorChave('${m['cargo']}')?.nome ?? '${m['cargo']}';
      final lanc = await _db
          .from('fin_lancamentos')
          .insert({
            'tipo': 'despesa',
            'categoria': 'Freelancers (diárias)',
            'descricao': '${u.nome} — $cargo',
            'valor': valor,
            'data': _iso(hoje),
            'competencia':
                '${hoje.year.toString().padLeft(4, '0')}-${hoje.month.toString().padLeft(2, '0')}',
            'pago': true,
            'criado_por': 'Login do freelancer',
          })
          .select()
          .single();
      await _db.from('freelancer_dias').update({
        'login_em': DateTime.now().toUtc().toIso8601String(),
        'lancamento_id': '${lanc['id']}',
      }).eq('id', m['id']);
    } catch (e) {
      debugPrint('Presença do freelancer não registrada: $e');
    }
  }

  /// Chamado no logout do freelancer.
  Future<void> registrarSaida(Usuario u) async {
    try {
      await _db
          .from('freelancer_dias')
          .update({'logout_em': DateTime.now().toUtc().toIso8601String()})
          .eq('usuario_id', u.id)
          .eq('dia', _iso(DateTime.now()))
          .not('login_em', 'is', null);
    } catch (e) {
      debugPrint('Saída do freelancer não registrada: $e');
    }
  }
}
