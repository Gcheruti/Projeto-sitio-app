import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/aula.dart';
import '../models/plano.dart';
import '../models/progresso.dart';
import '../models/trilha.dart';
import 'repositorio.dart';

/// O schema `gruta` no Supabase (ver supabase/migrations). O cliente é
/// iniciado com schema 'gruta' (main.dart), então `from('perfis')` já é
/// `gruta.perfis`. Toda leitura e escrita passa pelo RLS.
class RepositorioSupabase implements Repositorio {
  SupabaseClient get _db => Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  /// Bucket do Storage com vídeos e capas das aulas.
  static const bucket = 'gruta';

  /// Fuso do aparelho (ex.: America/Sao_Paulo), preenchido pelo LembreteService.
  /// O banco usa para saber o "dia" de cada pessoa (ofensiva e Jornada).
  static String? fuso;

  @override
  Future<List<Trilha>> trilhas() async {
    final r = await _db
        .from('trilhas')
        .select()
        .eq('publicada', true)
        .order('ordem');
    return r.map(Trilha.fromMap).toList();
  }

  @override
  Future<List<Aula>> aulas() async {
    // A view aulas_app só entrega o vídeo das aulas que a pessoa pode ver.
    final r = await _db.from('aulas_app').select().order('ordem');
    return r.map(Aula.fromMap).toList();
  }

  @override
  Future<Perfil> perfil() async {
    final r =
        await _db.from('perfis').select().eq('id', _uid).maybeSingle();
    if (r == null) return const Perfil();
    return Perfil.fromJson(r);
  }

  @override
  Future<void> salvarPerfil(Perfil p) async {
    // login, plano e papel não vão: só o servidor muda.
    final dados = <String, dynamic>{
      'nome': p.nome,
      'nome_completo': p.nomeCompleto,
      'nascimento': p.nascimento?.toIso8601String().substring(0, 10),
      'meta_minutos': p.metaMinutos,
      'lembrete_hora': p.lembreteHora,
      'lembrete_minuto': p.lembreteMinuto,
      'lembrete_ativo': p.lembreteAtivo,
      'trilhas_interesse': p.trilhasInteresse,
      if (fuso != null) 'fuso': fuso,
    };
    try {
      await _db
          .from('perfis')
          .update({...dados, 'telefone': p.telefone, 'email': p.email})
          .eq('id', _uid);
    } on PostgrestException catch (e) {
      // Banco ainda sem as colunas de contato: salva o resto.
      if (e.code != '42703' && e.code != 'PGRST204') rethrow;
      await _db.from('perfis').update(dados).eq('id', _uid);
    }
  }

  @override
  Future<List<AulaConcluida>> concluidas() async {
    final r = await _db
        .from('progresso_aulas')
        .select('aula_id, concluida_em')
        .eq('usuario_id', _uid)
        .not('concluida_em', 'is', null);
    return r
        .map((m) => AulaConcluida(m['aula_id'].toString(),
            DateTime.parse(m['concluida_em'] as String).toLocal()))
        .toList();
  }

  @override
  Future<void> concluirAula(Aula aula, int assistidoSeg) async {
    // Função atômica no banco: confere a regra de uma aula por dia, grava o
    // progresso e o dia de estudo.
    await _db.rpc('concluir_aula', params: {
      'p_aula_id': aula.id,
      'p_assistido_seg': assistidoSeg,
      'p_dia_local': DateTime.now().toIso8601String().substring(0, 10),
    });
  }

  @override
  Future<List<NotaGrimorio>> notas() async {
    final r = await _db
        .from('grimorio_notas')
        .select('id, texto, criada_em, aula_id')
        .eq('usuario_id', _uid)
        .order('criada_em', ascending: false);
    return r
        .map((m) => NotaGrimorio(
              id: m['id'].toString(),
              texto: m['texto'] as String,
              criadaEm: DateTime.parse(m['criada_em'] as String).toLocal(),
              aulaId: m['aula_id']?.toString(),
            ))
        .toList();
  }

  @override
  Future<NotaGrimorio> salvarNota(String texto,
      {String? aulaId, String? aulaTitulo}) async {
    final m = await _db
        .from('grimorio_notas')
        .insert({'usuario_id': _uid, 'texto': texto, 'aula_id': aulaId})
        .select()
        .single();
    return NotaGrimorio(
      id: m['id'].toString(),
      texto: texto,
      criadaEm: DateTime.parse(m['criada_em'] as String).toLocal(),
      aulaId: aulaId,
      aulaTitulo: aulaTitulo,
    );
  }

  @override
  Future<void> apagarNota(String id) =>
      _db.from('grimorio_notas').delete().eq('id', id);

  @override
  Future<Set<String>> trilhasLiberadas() async {
    final r = await _db
        .from('trilhas_liberadas')
        .select('trilha_id')
        .eq('usuario_id', _uid);
    return r.map((m) => m['trilha_id'].toString()).toSet();
  }

  @override
  Future<void> liberarTrilha(String trilhaId) =>
      _db.rpc('gastar_moeda', params: {'p_trilha_id': trilhaId});

  @override
  Future<void> escolherPlano(Plano plano) =>
      _db.rpc('escolher_plano_teste', params: {'p_plano': plano.name});

  @override
  Future<List<Notificacao>> notificacoes() async {
    final r = await _db
        .from('notificacoes')
        .select()
        .order('criada_em', ascending: false)
        .limit(50);
    return r.map(Notificacao.fromJson).toList();
  }

  @override
  Future<void> excluirTudo() => _db.rpc('excluir_minha_conta');

  @override
  Future<void> enviarNotificacao(
      {required String titulo,
      required String descricao,
      required String icone}) async {
    await _db.from('notificacoes').insert(
        {'titulo': titulo, 'descricao': descricao, 'icone': icone});
    // Push de verdade (celular fechado) precisa do Firebase configurado.
    // Sem ele, a função não existe e o aviso aparece quando o app abre.
    try {
      await _db.functions.invoke('gruta-push',
          body: {'titulo': titulo, 'descricao': descricao, 'icone': icone});
    } catch (_) {}
  }

  @override
  Future<Aula> salvarAula(Aula aula, {bool nova = false}) async {
    final dados = aula.toJson()..remove('id');
    final r = nova
        ? await _db.from('aulas').insert(dados).select().single()
        : await _db
            .from('aulas')
            .update(dados)
            .eq('id', aula.id)
            .select()
            .single();
    return Aula.fromMap(r);
  }

  @override
  Future<String> enviarArquivo({
    required String aulaId,
    required String nome,
    required Uint8List bytes,
    required String tipo,
  }) async {
    final limpo = nome.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._-]'), '-');
    final caminho =
        'aulas/$aulaId/${DateTime.now().millisecondsSinceEpoch}-$limpo';
    await _db.storage.from(bucket).uploadBinary(caminho, bytes,
        fileOptions: FileOptions(contentType: tipo, upsert: true));
    return _db.storage.from(bucket).getPublicUrl(caminho);
  }
}
