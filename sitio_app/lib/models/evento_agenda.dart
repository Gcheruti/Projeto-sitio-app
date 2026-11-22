const List<String> kTiposEvento = [
  'Reunião',
  'Evento',
  'Manutenção',
  'Entrega',
  'Outro',
];

/// Tipos que, por padrão, são internos (não aparecem no totem).
const Set<String> kTiposInternos = {'Reunião', 'Manutenção', 'Entrega'};

class EventoAgenda {
  EventoAgenda({
    required this.id,
    required this.agenda,
    required this.titulo,
    required this.inicio,
    required this.fim,
    this.tipo,
    this.descricao,
    this.produtoId,
    this.criadoPor,
    this.local,
    this.comandaCodigo,
    this.publico = true,
  });

  final String id;

  /// 'geral' ou 'casa_bruxa'.
  final String agenda;
  String titulo;
  String? tipo;
  String? descricao;
  DateTime inicio;
  DateTime fim;
  String? produtoId;
  String? criadoPor;

  /// Local do evento (chave de kLocais) e comanda de quem agendou (totem).
  String? local;
  String? comandaCodigo;

  /// Voltado ao público (aparece no totem). Internos: entrega, manutenção...
  bool publico;

  bool ocorreEm(DateTime dia) =>
      inicio.year == dia.year && inicio.month == dia.month && inicio.day == dia.day;
}

String doisDigitos(int n) => n.toString().padLeft(2, '0');
String formatarHora(DateTime d) => '${doisDigitos(d.hour)}:${doisDigitos(d.minute)}';
String formatarDia(DateTime d) =>
    '${doisDigitos(d.day)}/${doisDigitos(d.month)}/${d.year}';

const List<String> kMeses = [
  'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
];
const List<String> kDiasSemana = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
