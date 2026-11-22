import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lancamento.dart';
import '../state/auth_state.dart';

String _iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String competenciaDe(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

/// Acesso às tabelas fin_lancamentos / fin_recorrentes.
class FinanceiroRepository {
  final SupabaseClient _db = Supabase.instance.client;

  Future<List<Lancamento>> lancamentosDoMes(DateTime mes) async {
    final rows = await _db
        .from('fin_lancamentos')
        .select()
        .eq('competencia', competenciaDe(mes))
        .eq('excluido', false)
        .order('data', ascending: false);
    return (rows as List)
        .map((r) => Lancamento.deMapa(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Lançamentos com data entre [inicio] e [fim] (fim exclusivo).
  Future<List<Lancamento>> lancamentosPeriodo(
      DateTime inicio, DateTime fim) async {
    final rows = await _db
        .from('fin_lancamentos')
        .select()
        .gte('data', _iso(inicio))
        .lt('data', _iso(fim))
        .eq('excluido', false)
        .order('data', ascending: false);
    return (rows as List)
        .map((r) => Lancamento.deMapa(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Map<String, dynamic> _payload(Lancamento l) => {
        'tipo': l.tipo,
        'categoria': l.categoria,
        'descricao': l.descricao,
        'valor': l.valor,
        'data': _iso(l.data),
        'competencia': competenciaDe(l.data),
        'pago': l.pago,
        'observacao': l.observacao,
      };

  Future<void> inserir(Lancamento l) async {
    await _db.from('fin_lancamentos').insert({
      ..._payload(l),
      'recorrente_id': l.recorrenteId,
      'criado_por': authState.usuario?.nome,
    });
  }

  Future<void> atualizar(Lancamento l) async {
    await _db.from('fin_lancamentos').update({
      ..._payload(l),
      'editado_por': authState.usuario?.nome,
    }).eq('id', l.id);
  }

  /// "Excluir" só esconde: o registro continua guardado.
  Future<void> excluir(String id) async {
    await _db.from('fin_lancamentos').update({
      'excluido': true,
      'editado_por': authState.usuario?.nome,
    }).eq('id', id);
  }

  // ---- contas fixas ----

  Future<List<Recorrente>> recorrentes() async {
    final rows = await _db
        .from('fin_recorrentes')
        .select()
        .order('descricao', ascending: true);
    return (rows as List)
        .map((r) => Recorrente.deMapa(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> salvarRecorrente(Recorrente r) async {
    final dados = {
      'tipo': r.tipo,
      'categoria': r.categoria,
      'descricao': r.descricao,
      'valor': r.valor,
      'dia_vencimento': r.dia,
      'ativo': r.ativo,
    };
    if (r.id.isEmpty) {
      await _db.from('fin_recorrentes').insert(dados);
    } else {
      await _db.from('fin_recorrentes').update(dados).eq('id', r.id);
    }
  }

  /// Cria (como "a pagar") as contas fixas ativas que ainda não existem no
  /// mês. Pode ser chamado várias vezes: não duplica. Devolve quantas criou.
  Future<int> gerarContasFixas(DateTime mes) async {
    final fixas = (await recorrentes()).where((r) => r.ativo).toList();
    final comp = competenciaDe(mes);
    final existentes = await _db
        .from('fin_lancamentos')
        .select('recorrente_id')
        .eq('competencia', comp)
        .not('recorrente_id', 'is', null);
    final jaTem = {
      for (final e in existentes as List) '${(e as Map)['recorrente_id']}'
    };
    final ultimo = DateTime(mes.year, mes.month + 1, 0).day;
    var criadas = 0;
    for (final r in fixas) {
      if (jaTem.contains(r.id)) continue;
      await inserir(Lancamento(
        tipo: r.tipo,
        categoria: r.categoria,
        descricao: r.descricao,
        valor: r.valor,
        data: DateTime(mes.year, mes.month, r.dia > ultimo ? ultimo : r.dia),
        recorrenteId: r.id,
      ));
      criadas++;
    }
    return criadas;
  }
}
