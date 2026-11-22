import 'dart:typed_data';

import '../models/aula.dart';
import '../models/plano.dart';
import '../models/progresso.dart';
import '../models/trilha.dart';

/// Tudo o que o app lê e grava. Há duas versões:
/// - [RepositorioLocal]: modo demonstração (sem banco), salva no aparelho;
/// - [RepositorioSupabase]: o schema `gruta` no Supabase.
abstract class Repositorio {
  Future<List<Trilha>> trilhas();

  /// Aulas das trilhas e da Jornada (as da Jornada têm trilhaId = 'jornada').
  Future<List<Aula>> aulas();

  Future<Perfil> perfil();
  Future<void> salvarPerfil(Perfil p);

  Future<List<AulaConcluida>> concluidas();

  /// Registra a aula como concluída (e o dia de estudo, para a ofensiva).
  Future<void> concluirAula(Aula aula, int assistidoSeg);

  Future<List<NotaGrimorio>> notas();
  Future<NotaGrimorio> salvarNota(String texto,
      {String? aulaId, String? aulaTitulo});
  Future<void> apagarNota(String id);

  /// Trilhas que a pessoa já liberou com moedas (ou comprou).
  Future<Set<String>> trilhasLiberadas();

  /// Gasta uma moeda para abrir a trilha. O banco confere se há moeda.
  Future<void> liberarTrilha(String trilhaId);

  /// Troca de plano. Enquanto o pagamento não existe, só funciona com o
  /// modo de teste ligado no banco (gruta.config.planos_teste).
  Future<void> escolherPlano(Plano plano);

  Future<List<Notificacao>> notificacoes();

  /// Apaga todos os dados da pessoa (exigência da Apple e do Google para
  /// apps com cadastro: excluir a conta dentro do app).
  Future<void> excluirTudo();

  // ---------- painel /adm (o banco só aceita de quem é admin) ----------

  Future<void> enviarNotificacao(
      {required String titulo,
      required String descricao,
      required String icone});

  Future<Aula> salvarAula(Aula aula, {bool nova = false});

  /// Envia um vídeo ou imagem para a aula e devolve o endereço público.
  Future<String> enviarArquivo({
    required String aulaId,
    required String nome,
    required Uint8List bytes,
    required String tipo,
  });
}
