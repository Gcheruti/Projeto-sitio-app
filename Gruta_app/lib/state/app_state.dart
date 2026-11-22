import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../logic/ofensiva.dart';
import '../logic/regras.dart';
import '../models/aula.dart';
import '../models/plano.dart';
import '../models/progresso.dart';
import '../models/trilha.dart';
import '../services/lembrete_service.dart';
import '../services/repositorio.dart';
import '../services/repositorio_local.dart';
import '../services/repositorio_supabase.dart';

enum EstadoAula {
  concluida, // já assistiu (pode rever)
  disponivel, // a aula nova de hoje
  amanha, // próxima da fila, abre depois da meia-noite
  bloqueada, // mais à frente
  trancada, // o plano não inclui, ou a trilha ainda não foi liberada
}

/// O que mudou ao concluir uma aula (para a tela de comemoração).
class ResultadoConclusao {
  const ResultadoConclusao(this.antes, this.depois, {this.ganhouMoeda = false});
  final Ofensiva antes;
  final Ofensiva depois;
  final bool ganhouMoeda;
  bool get acendeuHoje => !antes.feitoHoje && depois.feitoHoje;
  bool get ganhouAmuleto => depois.amuletos > antes.amuletos;
}

/// Estado do app: catálogo, Jornada, moedas, progresso, Grimório e ofensiva.
/// Mesmo padrão dos outros apps: um ChangeNotifier global + ListenableBuilder.
class AppState extends ChangeNotifier {
  Repositorio _repo = RepositorioLocal();
  Repositorio get repo => _repo;

  bool carregando = true;
  String? erro;

  List<Trilha> trilhas = [];
  List<Aula> aulas = [];
  List<AulaConcluida> concluidas = [];
  List<NotaGrimorio> notas = [];
  Set<String> liberadas = {};
  List<Notificacao> avisos = [];
  Perfil perfil = const Perfil();
  Ofensiva ofensiva = Ofensiva.vazia;

  /// Último aviso que a pessoa abriu (para o pontinho no sino).
  String? _ultimoAvisoVisto;

  void usarRepositorio({required bool supabase}) {
    _repo = supabase ? RepositorioSupabase() : RepositorioLocal();
  }

  Future<void> carregar() async {
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      final r = await Future.wait([
        _repo.trilhas(),
        _repo.aulas(),
        _repo.concluidas(),
        _repo.notas(),
        _repo.perfil(),
        _repo.trilhasLiberadas(),
      ]);
      trilhas = r[0] as List<Trilha>;
      aulas = r[1] as List<Aula>;
      concluidas = r[2] as List<AulaConcluida>;
      notas = r[3] as List<NotaGrimorio>;
      perfil = r[4] as Perfil;
      liberadas = r[5] as Set<String>;
      _recalcular();
    } catch (e) {
      erro = 'Não foi possível carregar a Gruta. Verifique a conexão.';
      debugPrint('carregar: $e');
    }
    carregando = false;
    notifyListeners();
    LembreteService.reagendar(perfil, feitoHoje: ofensiva.feitoHoje);
    await carregarAvisos();
  }

  Future<void> carregarAvisos() async {
    try {
      final p = await SharedPreferences.getInstance();
      _ultimoAvisoVisto = p.getString('gruta_ultimo_aviso');
      avisos = await _repo.notificacoes();
      // Aviso novo desde a última vez: mostra também como notificação do
      // aparelho (no celular). Push com o app fechado precisa do Firebase.
      final novo = avisos.firstOrNull;
      final avisado = p.getString('gruta_aviso_notificado');
      if (novo != null && novo.id != avisado && novo.id != _ultimoAvisoVisto) {
        await p.setString('gruta_aviso_notificado', novo.id);
        await LembreteService.mostrarAgora(novo.titulo, novo.descricao);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('avisos: $e');
    }
  }

  bool get temAvisoNovo =>
      avisos.isNotEmpty && avisos.first.id != _ultimoAvisoVisto;

  Future<void> marcarAvisosVistos() async {
    if (avisos.isEmpty) return;
    _ultimoAvisoVisto = avisos.first.id;
    notifyListeners();
    (await SharedPreferences.getInstance())
        .setString('gruta_ultimo_aviso', _ultimoAvisoVisto!);
  }

  void _recalcular() {
    ofensiva = calcularOfensiva(concluidas.map((c) => c.em), DateTime.now());
  }

  // ---------- consultas ----------

  Plano get plano => perfil.plano;

  Trilha? trilhaPorId(String id) => id == kJornadaId
      ? kTrilhaJornada
      : trilhas.where((t) => t.id == id).firstOrNull;
  Aula? aulaPorId(String id) => aulas.where((a) => a.id == id).firstOrNull;

  List<Aula> aulasDa(String trilhaId) =>
      aulas.where((a) => a.trilhaId == trilhaId).toList()
        ..sort((a, b) => a.ordem.compareTo(b.ordem));

  List<Aula> get jornada => aulasDa(kJornadaId);

  AulaConcluida? _conclusao(String aulaId) =>
      concluidas.where((c) => c.aulaId == aulaId).firstOrNull;

  bool foiConcluida(String aulaId) => _conclusao(aulaId) != null;

  int concluidasNa(String trilhaId) =>
      aulasDa(trilhaId).where((a) => foiConcluida(a.id)).length;

  double progressoDa(String trilhaId) {
    final total = aulasDa(trilhaId).length;
    return total == 0 ? 0 : concluidasNa(trilhaId) / total;
  }

  /// Ordens da Jornada já concluídas.
  Set<int> get ordensJornada => {
        for (final a in jornada)
          if (foiConcluida(a.id)) a.ordem
      };

  DateTime? get _ultimaJornada {
    DateTime? u;
    for (final a in jornada) {
      final c = _conclusao(a.id);
      if (c != null && (u == null || c.em.isAfter(u))) u = c.em;
    }
    return u;
  }

  // Moedas
  int get moedasGanhasTotal => moedasGanhas(ordensJornada);
  int get moedas => moedasDisponiveis(
      ganhas: moedasGanhasTotal, gastas: liberadas.length, plano: plano);
  int? get faltamMoeda => faltamParaMoeda(ordensJornada);

  bool trilhaLiberada(String trilhaId) =>
      trilhaAberta(trilhaId: trilhaId, liberadas: liberadas, plano: plano);

  /// Ainda cabe mais uma trilha no plano?
  bool get cabeMaisTrilha =>
      !plano.todasAsTrilhas && liberadas.length < plano.limiteTrilhas;

  EstadoAula estadoDa(Aula aula) {
    if (aula.daJornada) {
      return switch (estadoJornada(
        ordem: aula.ordem,
        concluidas: ordensJornada,
        ultimaConclusao: _ultimaJornada,
        agora: DateTime.now(),
        plano: plano,
      )) {
        EstadoJornada.concluida => EstadoAula.concluida,
        EstadoJornada.disponivel => EstadoAula.disponivel,
        EstadoJornada.amanha => EstadoAula.amanha,
        EstadoJornada.bloqueada => EstadoAula.bloqueada,
        EstadoJornada.plano => EstadoAula.trancada,
      };
    }
    if (foiConcluida(aula.id)) return EstadoAula.concluida;
    if (!trilhaLiberada(aula.trilhaId)) return EstadoAula.trancada;
    final lista = aulasDa(aula.trilhaId);
    final proxima = lista.where((a) => !foiConcluida(a.id)).firstOrNull;
    if (proxima?.id != aula.id) return EstadoAula.bloqueada;
    if (AppConfig.umaAulaNovaPorDia) {
      final idx = lista.indexOf(aula);
      if (idx > 0) {
        final anterior = _conclusao(lista[idx - 1].id);
        if (anterior != null && soData(anterior.em) == soData(DateTime.now())) {
          return EstadoAula.amanha;
        }
      }
    }
    return EstadoAula.disponivel;
  }

  /// A próxima aula (a que não foi concluída ainda), seja qual for o estado.
  /// null = trilha (ou Jornada) completa.
  Aula? proximaDa(String trilhaId) =>
      aulasDa(trilhaId).where((a) => !foiConcluida(a.id)).firstOrNull;

  /// Aula concluída hoje nesta trilha ou na Jornada.
  Aula? concluidaHojeNa(String trilhaId) {
    final hoje = soData(DateTime.now());
    for (final a in aulasDa(trilhaId).reversed) {
      final c = _conclusao(a.id);
      if (c != null && soData(c.em) == hoje) return a;
    }
    return null;
  }

  int get minutosHoje {
    final hoje = soData(DateTime.now());
    final seg = concluidas
        .where((c) => soData(c.em) == hoje)
        .map((c) => aulaPorId(c.aulaId)?.duracaoSeg ?? 0)
        .fold<int>(0, (a, b) => a + b);
    return (seg / 60).round();
  }

  Set<DateTime> get diasComAula => concluidas.map((c) => soData(c.em)).toSet();

  int get totalDias => diasComAula.length;
  int get totalAulas => concluidas.length;

  // ---------- ações ----------

  Future<ResultadoConclusao> concluirAula(Aula aula, int assistidoSeg) async {
    final antes = ofensiva;
    final moedasAntes = moedasGanhasTotal;
    if (!foiConcluida(aula.id)) {
      await _repo.concluirAula(aula, assistidoSeg);
      concluidas = [...concluidas, AulaConcluida(aula.id, DateTime.now())];
      _recalcular();
      notifyListeners();
      LembreteService.reagendar(perfil, feitoHoje: true);
    }
    return ResultadoConclusao(antes, ofensiva,
        ganhouMoeda: moedasGanhasTotal > moedasAntes);
  }

  /// Gasta uma moeda e abre a trilha. Retorna a mensagem de erro, ou null.
  Future<String?> gastarMoeda(String trilhaId) async {
    if (trilhaLiberada(trilhaId)) return null;
    if (moedas <= 0) return 'Você ainda não tem moedas.';
    try {
      await _repo.liberarTrilha(trilhaId);
      liberadas = {...liberadas, trilhaId};
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('gastarMoeda: $e');
      return 'Não foi possível liberar agora. Tente de novo.';
    }
  }

  /// Troca de plano (por enquanto, modo de teste). Erro ou null.
  Future<String?> escolherPlano(Plano p) async {
    try {
      await _repo.escolherPlano(p);
      perfil = perfil.copyWith(plano: p);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('escolherPlano: $e');
      return 'O pagamento ainda não está disponível. Em breve!';
    }
  }

  Future<void> salvarPerfil(Perfil p) async {
    perfil = p;
    notifyListeners();
    await _repo.salvarPerfil(p);
    await LembreteService.reagendar(p, feitoHoje: ofensiva.feitoHoje);
  }

  Future<void> anotar(String texto, {Aula? aula}) async {
    final n = await _repo.salvarNota(texto,
        aulaId: aula?.id, aulaTitulo: aula?.titulo);
    notas = [n, ...notas];
    notifyListeners();
  }

  Future<void> apagarNota(String id) async {
    await _repo.apagarNota(id);
    notas = notas.where((n) => n.id != id).toList();
    notifyListeners();
  }

  Future<void> excluirConta() async {
    await _repo.excluirTudo();
    concluidas = [];
    notas = [];
    liberadas = {};
    perfil = const Perfil();
    _recalcular();
    notifyListeners();
  }

  // ---------- painel /adm ----------

  Future<void> enviarAviso(
      {required String titulo,
      required String descricao,
      required String icone}) async {
    await _repo.enviarNotificacao(
        titulo: titulo, descricao: descricao, icone: icone);
    avisos = await _repo.notificacoes();
    notifyListeners();
  }

  Future<Aula> salvarAula(Aula aula, {bool nova = false}) async {
    final salva = await _repo.salvarAula(aula, nova: nova);
    aulas = [
      for (final a in aulas)
        if (a.id != aula.id) a,
      salva,
    ];
    notifyListeners();
    return salva;
  }

  Future<String> enviarArquivo(
          {required String aulaId,
          required String nome,
          required Uint8List bytes,
          required String tipo}) =>
      _repo.enviarArquivo(
          aulaId: aulaId, nome: nome, bytes: bytes, tipo: tipo);

  /// Só para o modo demonstração: simula dias anteriores de estudo na
  /// Jornada, para ver a ofensiva, as moedas e a semana preenchidas.
  void simularDias(int dias) {
    final agora = DateTime.now();
    final pendentes = jornada.where((a) => !foiConcluida(a.id)).toList();
    final extras = <AulaConcluida>[];
    for (var i = 0; i < dias && i < pendentes.length; i++) {
      extras.add(AulaConcluida(
          pendentes[i].id, agora.subtract(Duration(days: dias - i))));
    }
    concluidas = [...extras, ...concluidas];
    _recalcular();
    notifyListeners();
  }
}

final appState = AppState();
