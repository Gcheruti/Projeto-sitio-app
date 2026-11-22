import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/evento_agenda.dart';

class AgendaRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<EventoAgenda>> buscar(String agenda) async {
    final rows = await _db
        .from('agenda_eventos')
        .select()
        .eq('agenda', agenda)
        .order('inicio');
    return _mapear(rows as List);
  }

  /// Todos os eventos (qualquer agenda) do dia informado.
  Future<List<EventoAgenda>> doDia(DateTime dia) async {
    final ini = DateTime(dia.year, dia.month, dia.day);
    final rows = await _db
        .from('agenda_eventos')
        .select()
        .gte('inicio', ini.toUtc().toIso8601String())
        .lt('inicio', ini.add(const Duration(days: 1)).toUtc().toIso8601String())
        .order('inicio');
    return _mapear(rows as List);
  }

  /// Eventos agendados por uma comanda.
  Future<List<EventoAgenda>> daComanda(String codigo) async {
    final rows = await _db
        .from('agenda_eventos')
        .select()
        .eq('comanda_codigo', codigo)
        .order('inicio');
    return _mapear(rows as List);
  }

  List<EventoAgenda> _mapear(List rows) {
    return rows.map((r) {
      final m = r as Map;
      return EventoAgenda(
        id: m['id'].toString(),
        agenda: (m['agenda'] ?? 'geral').toString(),
        local: m['local']?.toString(),
        comandaCodigo: m['comanda_codigo']?.toString(),
        publico: m['publico'] != false,
        titulo: (m['titulo'] ?? '').toString(),
        tipo: m['tipo']?.toString(),
        descricao: m['descricao']?.toString(),
        inicio: DateTime.parse(m['inicio'].toString()).toLocal(),
        fim: DateTime.parse(m['fim'].toString()).toLocal(),
        produtoId: m['produto_id']?.toString(),
        criadoPor: m['criado_por']?.toString(),
      );
    }).toList();
  }

  Future<void> inserir({
    required String agenda,
    required String titulo,
    required DateTime inicio,
    required DateTime fim,
    String? tipo,
    String? descricao,
    String? produtoId,
    String? criadoPor,
    String? local,
    String? comandaCodigo,
    bool publico = true,
  }) async {
    final dados = {
      'agenda': agenda,
      'titulo': titulo,
      'tipo': tipo,
      'descricao': descricao,
      'inicio': inicio.toUtc().toIso8601String(),
      'fim': fim.toUtc().toIso8601String(),
      'produto_id': produtoId,
      'criado_por': criadoPor,
    };
    try {
      await _db.from('agenda_eventos').insert({
        ...dados,
        'local': local,
        'comanda_codigo': comandaCodigo,
        'publico': publico,
      });
    } catch (_) {
      // colunas novas ainda não criadas (totem.sql / agenda_publico.sql)
      try {
        await _db.from('agenda_eventos').insert({
          ...dados,
          'local': local,
          'comanda_codigo': comandaCodigo,
        });
      } catch (_) {
        await _db.from('agenda_eventos').insert(dados);
      }
    }
  }

  Future<void> atualizarHorario(String id, DateTime inicio, DateTime fim) async {
    await _db.from('agenda_eventos').update({
      'inicio': inicio.toUtc().toIso8601String(),
      'fim': fim.toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> remover(String id) async {
    await _db.from('agenda_eventos').delete().eq('id', id);
  }
}
