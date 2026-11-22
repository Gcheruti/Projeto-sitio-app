import 'package:material_ui/material_ui.dart';

/// Uma trilha de estudo (ex.: Tarô, Chás medicinais). Cada trilha tem uma
/// sequência de aulas em vídeo de ~5 minutos.
class Trilha {
  const Trilha({
    required this.id,
    required this.slug,
    required this.titulo,
    required this.subtitulo,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.ordem,
  });

  final String id;
  final String slug;
  final String titulo;
  final String subtitulo;
  final String descricao;
  final String icone; // chave em kIconesTrilha
  final Color cor;
  final int ordem;

  IconData get iconData => kIconesTrilha[icone] ?? Icons.auto_awesome;

  factory Trilha.fromMap(Map<String, dynamic> m) => Trilha(
        id: m['id'].toString(),
        slug: m['slug'] as String,
        titulo: m['titulo'] as String,
        subtitulo: (m['subtitulo'] ?? '') as String,
        descricao: (m['descricao'] ?? '') as String,
        icone: (m['icone'] ?? 'estrela') as String,
        cor: corDeHex(m['cor'] as String?),
        ordem: (m['ordem'] ?? 0) as int,
      );
}

/// A Jornada não é uma linha da tabela trilhas: é este registro fixo, usado
/// só para dar cor e ícone às aulas diárias.
const kTrilhaJornada = Trilha(
  id: 'jornada',
  slug: 'jornada',
  titulo: 'Jornada',
  subtitulo: '60 aulas diárias',
  descricao: 'Uma aula por dia, da aula piloto à 59.',
  icone: 'vela',
  cor: Color(0xFFF0A63A),
  ordem: 0,
);

/// Ícones dos avisos enviados pelo painel /adm.
const Map<String, IconData> kIconesAviso = {
  'vela': Icons.local_fire_department,
  'lua': Icons.nightlight_round,
  'estrela': Icons.auto_awesome,
  'live': Icons.live_tv,
  'presente': Icons.redeem,
  'aula': Icons.play_circle_outline,
  'calendario': Icons.event,
  'loja': Icons.storefront,
  'cristal': Icons.diamond_outlined,
  'folha': Icons.eco_outlined,
  'sino': Icons.notifications_active_outlined,
  'coracao': Icons.favorite_border,
};

/// Ícones disponíveis para as trilhas (o banco guarda só a chave).
const Map<String, IconData> kIconesTrilha = {
  'estrela': Icons.auto_awesome,
  'olho': Icons.visibility_outlined,
  'cartas': Icons.style_outlined,
  'asas': Icons.flare,
  'conchas': Icons.bubble_chart_outlined,
  'folha': Icons.eco_outlined,
  'cha': Icons.emoji_food_beverage_outlined,
  'planta': Icons.spa_outlined,
  'lua': Icons.nightlight_outlined,
  'cristal': Icons.diamond_outlined,
  'vela': Icons.local_fire_department_outlined,
  'livro': Icons.menu_book_outlined,
};

Color corDeHex(String? hex) {
  if (hex == null || hex.isEmpty) return const Color(0xFFC9A45C);
  final h = hex.replaceFirst('#', '');
  return Color(int.parse(h.length == 6 ? 'FF$h' : h, radix: 16));
}
