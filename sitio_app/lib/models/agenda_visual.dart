import 'package:flutter/material.dart';

/// Cores que os tipos de agendamento podem ter (a CHAVE é o que fica salvo).
const Map<String, Color> kCoresAgenda = {
  'vermelho': Color(0xFFE53935),
  'laranja': Color(0xFFFB8C00),
  'amarelo': Color(0xFFFDD835),
  'verde': Color(0xFF43A047),
  'turquesa': Color(0xFF00ACC1),
  'azul': Color(0xFF1E88E5),
  'roxo': Color(0xFF8E24AA),
  'rosa': Color(0xFFEC407A),
};

/// Ícones dos atendimentos da Casa da Bruxa (diferentes dos ícones de freelancer).
const Map<String, IconData> kIconesBruxa = {
  'cartas': Icons.style,
  'dados': Icons.casino,
  'livro': Icons.menu_book,
  'meditacao': Icons.self_improvement,
  'cha': Icons.local_cafe,
  'crepusculo': Icons.wb_twilight,
  'bola': Icons.blur_on,
  'noite': Icons.nights_stay,
  'estrelas': Icons.stars,
  'clarao': Icons.flare,
  'planta': Icons.filter_vintage,
  'chama': Icons.whatshot,
  'ideia': Icons.emoji_objects,
  'cura': Icons.healing,
  'voz': Icons.record_voice_over,
};

/// Ícones da agenda geral (alguns podem lembrar os de outras telas).
const Map<String, IconData> kIconesAgendaGeral = {
  'evento': Icons.event,
  'grupo': Icons.groups,
  'festa': Icons.celebration,
  'manutencao': Icons.handyman,
  'entrega': Icons.local_shipping,
  'ferramenta': Icons.build,
  'microfone': Icons.mic,
  'teatro': Icons.theater_comedy,
  'cinema': Icons.movie,
  'musica': Icons.queue_music,
  'bar': Icons.sports_bar,
  'vinho': Icons.wine_bar,
  'cardapio': Icons.restaurant_menu,
  'lanche': Icons.fastfood,
  'limpeza': Icons.cleaning_services,
  'encanamento': Icons.plumbing,
  'eletrica': Icons.electrical_services,
  'obra': Icons.construction,
  'estoque': Icons.inventory_2,
  'sacola': Icons.shopping_bag,
  'loja': Icons.storefront,
  'oferta': Icons.local_offer,
  'brinde': Icons.redeem,
  'presente': Icons.card_giftcard,
  'voluntario': Icons.volunteer_activism,
  'livro': Icons.menu_book,
  'foto': Icons.photo_camera,
  'video': Icons.videocam,
  'campanha': Icons.campaign,
  'suporte': Icons.support_agent,
  'cracha': Icons.badge,
  'pagamento': Icons.payments,
  'banco': Icons.account_balance,
  'recibo': Icons.receipt_long,
  'mapa': Icons.map,
  'trilha': Icons.hiking,
  'piscina': Icons.pool,
  'hospital': Icons.local_hospital,
  'saude': Icons.medical_services,
  'seguranca': Icons.security,
  'cadeado': Icons.lock,
  'viagem': Icons.flight_takeoff,
  'carro': Icons.directions_car,
  'estacionamento': Icons.local_parking,
  'padaria': Icons.bakery_dining,
  'macarrao': Icons.ramen_dining,
  'jardim': Icons.yard,
  'cabelo': Icons.content_cut,
  'lavanderia': Icons.local_laundry_service,
  'estrela': Icons.star,
  'coracao': Icons.favorite,
};

/// Cor + ícone escolhidos (por chave) para um tipo de agendamento.
class VisualAgenda {
  const VisualAgenda(this.corChave, this.iconeChave);
  final String corChave;
  final String iconeChave;
}

/// Descobre cor e ícone de um tipo: o que foi configurado, senão um padrão
/// estável (sempre o mesmo para o mesmo nome).
class AgendaVisualResolver {
  AgendaVisualResolver(this.icones, {Map<String, VisualAgenda>? padroes})
      : padroes = padroes ?? const {};

  final Map<String, IconData> icones;
  final Map<String, VisualAgenda> padroes;

  /// Configurações salvas (preenchido pela tela ao carregar).
  final Map<String, VisualAgenda> config = {};

  static int _hash(String s) =>
      s.codeUnits.fold<int>(7, (a, b) => (a * 31 + b) & 0x7fffffff);

  VisualAgenda de(String chave) {
    final c = config[chave] ?? padroes[chave];
    if (c != null &&
        kCoresAgenda.containsKey(c.corChave) &&
        icones.containsKey(c.iconeChave)) {
      return c;
    }
    final h = _hash(chave);
    return VisualAgenda(
      kCoresAgenda.keys.elementAt(h % kCoresAgenda.length),
      icones.keys.elementAt((h ~/ 7) % icones.length),
    );
  }

  Color cor(String chave) => kCoresAgenda[de(chave).corChave]!;
  IconData icone(String chave) => icones[de(chave).iconeChave]!;
}

/// Cores/ícones padrão dos tipos da agenda geral.
const Map<String, VisualAgenda> kPadroesAgendaGeral = {
  'Reunião': VisualAgenda('azul', 'grupo'),
  'Evento': VisualAgenda('roxo', 'festa'),
  'Manutenção': VisualAgenda('laranja', 'manutencao'),
  'Entrega': VisualAgenda('verde', 'entrega'),
  'Outro': VisualAgenda('rosa', 'evento'),
};
