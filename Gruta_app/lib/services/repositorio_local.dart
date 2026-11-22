import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/catalogo_demo.dart';
import '../data/jornada_demo.dart';
import '../models/aula.dart';
import '../models/plano.dart';
import '../models/progresso.dart';
import '../models/trilha.dart';
import 'repositorio.dart';

/// Modo demonstração: catálogo de exemplo e progresso guardado no aparelho.
class RepositorioLocal implements Repositorio {
  static const _kPerfil = 'gruta_perfil';
  static const _kConcluidas = 'gruta_concluidas';
  static const _kNotas = 'gruta_notas';
  static const _kLiberadas = 'gruta_trilhas_liberadas';
  static const _kAvisos = 'gruta_avisos';
  static const _kAulasEditadas = 'gruta_aulas_editadas';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  List<dynamic> _lista(SharedPreferences p, String chave) {
    final s = p.getString(chave);
    if (s == null) return const [];
    try {
      return jsonDecode(s) as List<dynamic>;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<Trilha>> trilhas() async => kTrilhasDemo;

  @override
  Future<List<Aula>> aulas() async {
    // Edições feitas no painel /adm da demonstração ficam no aparelho.
    final editadas = {
      for (final e in _lista(await _prefs, _kAulasEditadas))
        (e as Map<String, dynamic>)['id'].toString(): Aula.fromMap(e),
    };
    final base = [...kJornadaDemo, ...kAulasDemo];
    final ids = base.map((a) => a.id).toSet();
    return [
      for (final a in base) editadas[a.id] ?? a,
      ...editadas.values.where((a) => !ids.contains(a.id)),
    ];
  }

  @override
  Future<Perfil> perfil() async {
    final s = (await _prefs).getString(_kPerfil);
    if (s == null) return const Perfil(admin: true);
    // Na demonstração todo mundo pode abrir o painel /adm.
    return Perfil.fromJson(jsonDecode(s) as Map<String, dynamic>)
        .copyWith(admin: true);
  }

  @override
  Future<void> salvarPerfil(Perfil p) async =>
      (await _prefs).setString(_kPerfil, jsonEncode(p.toJson()));

  @override
  Future<List<AulaConcluida>> concluidas() async => _lista(
          await _prefs, _kConcluidas)
      .map((e) => AulaConcluida.fromJson(e as Map<String, dynamic>))
      .toList();

  @override
  Future<void> concluirAula(Aula aula, int assistidoSeg) async {
    final p = await _prefs;
    final atuais = await concluidas();
    if (atuais.any((c) => c.aulaId == aula.id)) return; // já contava
    atuais.add(AulaConcluida(aula.id, DateTime.now()));
    await p.setString(
        _kConcluidas, jsonEncode(atuais.map((c) => c.toJson()).toList()));
  }

  @override
  Future<List<NotaGrimorio>> notas() async => _lista(await _prefs, _kNotas)
      .map((e) => NotaGrimorio.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => b.criadaEm.compareTo(a.criadaEm));

  @override
  Future<NotaGrimorio> salvarNota(String texto,
      {String? aulaId, String? aulaTitulo}) async {
    final nota = NotaGrimorio(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      texto: texto,
      criadaEm: DateTime.now(),
      aulaId: aulaId,
      aulaTitulo: aulaTitulo,
    );
    final todas = [nota, ...await notas()];
    await (await _prefs)
        .setString(_kNotas, jsonEncode(todas.map((n) => n.toJson()).toList()));
    return nota;
  }

  @override
  Future<void> apagarNota(String id) async {
    final todas = (await notas()).where((n) => n.id != id).toList();
    await (await _prefs)
        .setString(_kNotas, jsonEncode(todas.map((n) => n.toJson()).toList()));
  }

  @override
  Future<Set<String>> trilhasLiberadas() async =>
      ((await _prefs).getStringList(_kLiberadas) ?? const []).toSet();

  @override
  Future<void> liberarTrilha(String trilhaId) async {
    final atuais = await trilhasLiberadas();
    await (await _prefs)
        .setStringList(_kLiberadas, {...atuais, trilhaId}.toList());
  }

  @override
  Future<void> escolherPlano(Plano plano) async =>
      salvarPerfil((await perfil()).copyWith(plano: plano));

  @override
  Future<List<Notificacao>> notificacoes() async => _lista(
          await _prefs, _kAvisos)
      .map((e) => Notificacao.fromJson(e as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => b.criadaEm.compareTo(a.criadaEm));

  @override
  Future<void> excluirTudo() async {
    final p = await _prefs;
    for (final k in [_kPerfil, _kConcluidas, _kNotas, _kLiberadas]) {
      await p.remove(k);
    }
  }

  @override
  Future<void> enviarNotificacao(
      {required String titulo,
      required String descricao,
      required String icone}) async {
    final nova = Notificacao(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      titulo: titulo,
      descricao: descricao,
      icone: icone,
      criadaEm: DateTime.now(),
    );
    final todas = [nova, ...await notificacoes()];
    await (await _prefs).setString(
        _kAvisos, jsonEncode(todas.map((n) => n.toJson()).toList()));
  }

  @override
  Future<Aula> salvarAula(Aula aula, {bool nova = false}) async {
    final p = await _prefs;
    final lista = _lista(p, _kAulasEditadas)
        .cast<Map<String, dynamic>>()
        .where((e) => e['id'].toString() != aula.id)
        .toList()
      ..add(aula.toJson()..['id'] = aula.id);
    await p.setString(_kAulasEditadas, jsonEncode(lista));
    return aula;
  }

  @override
  Future<String> enviarArquivo({
    required String aulaId,
    required String nome,
    required Uint8List bytes,
    required String tipo,
  }) async =>
      throw UnsupportedError(
          'Envio de arquivos só funciona com o banco conectado. '
          'Na demonstração, cole o endereço do vídeo ou da imagem.');
}
