/// Locais do Sítio (cada um tem um marcador no mapa da tela inicial).
const Map<String, String> kLocais = {
  'restaurante': 'Restaurante',
  'mercado': 'Cosmória',
  'casa_bruxa': 'Casa da Bruxa',
  'gruta': 'Gruta',
  // Espaços só de eventos (sem produtos):
  'spa': 'Spa',
  'estacionamento': 'Estacionamento',
  'espaco_ritual': 'Espaço Ritualístico',
  'apiario': 'Apiário',
};

class Notificacao {
  Notificacao({
    required this.id,
    required this.titulo,
    required this.descricao,
    this.ativa = true,
    this.local,
    this.criadoPor,
    this.editadoPor,
    this.excluida = false,
    this.somenteAdm = false,
  });

  final String id;
  String titulo;
  String descricao;
  bool ativa;

  /// Chave de [kLocais]; null = aviso geral (sem local).
  String? local;

  String? criadoPor;
  String? editadoPor;

  /// Excluída = escondida no app, mas mantida no Supabase.
  bool excluida;

  /// Alerta visível só para o Adm (ações de staff/freelancer).
  bool somenteAdm;

  String? get localNome => local == null ? null : kLocais[local];
}
