/// Id usado no app para as aulas da Jornada (no banco, trilha_id é null).
const kJornadaId = 'jornada';

/// Uma aula: um vídeo curto (~5 min) dentro de uma trilha ou da Jornada.
class Aula {
  const Aula({
    required this.id,
    required this.trilhaId,
    required this.ordem,
    required this.titulo,
    required this.descricao,
    required this.videoUrl,
    required this.duracaoSeg,
    this.capaUrl,
    this.gratuita = true,
    this.reflexao,
  });

  final String id;
  final String trilhaId;
  final int ordem; // Jornada: 0 (piloto) a 59. Trilhas: 1, 2, 3...
  final String titulo;
  final String descricao;
  final String videoUrl;
  final int duracaoSeg;
  final String? capaUrl;

  /// Reservado (o acesso agora vem do plano e das trilhas liberadas).
  final bool gratuita;

  bool get daJornada => trilhaId == kJornadaId;

  /// Pergunta curta mostrada depois do vídeo, para anotar no Grimório.
  final String? reflexao;

  String get duracaoTexto {
    final m = (duracaoSeg / 60).round();
    return '$m min';
  }

  factory Aula.fromMap(Map<String, dynamic> m) => Aula(
        id: m['id'].toString(),
        trilhaId: m['trilha_id']?.toString() ?? kJornadaId,
        ordem: (m['ordem'] ?? 0) as int,
        titulo: m['titulo'] as String,
        descricao: (m['descricao'] ?? '') as String,
        videoUrl: (m['video_url'] ?? '') as String,
        duracaoSeg: (m['duracao_seg'] ?? 300) as int,
        capaUrl: m['capa_url'] as String?,
        gratuita: (m['gratuita'] ?? true) as bool,
        reflexao: m['reflexao'] as String?,
      );

  Aula copyWith({
    String? titulo,
    String? descricao,
    String? videoUrl,
    int? duracaoSeg,
    String? capaUrl,
    String? reflexao,
  }) =>
      Aula(
        id: id,
        trilhaId: trilhaId,
        ordem: ordem,
        titulo: titulo ?? this.titulo,
        descricao: descricao ?? this.descricao,
        videoUrl: videoUrl ?? this.videoUrl,
        duracaoSeg: duracaoSeg ?? this.duracaoSeg,
        capaUrl: capaUrl ?? this.capaUrl,
        gratuita: gratuita,
        reflexao: reflexao ?? this.reflexao,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'trilha_id': daJornada ? null : trilhaId,
        'ordem': ordem,
        'titulo': titulo,
        'descricao': descricao,
        'video_url': videoUrl,
        'duracao_seg': duracaoSeg,
        'capa_url': capaUrl,
        'reflexao': reflexao,
      };
}
