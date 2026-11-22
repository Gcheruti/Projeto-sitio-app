import 'package:flutter/material.dart';

import 'usuario.dart';

/// Ícones que cada freelancer pode ter (aparecem na agenda geral, na cor do cargo).
/// A CHAVE (texto) é o que fica salvo no cadastro: pode reordenar/ampliar a lista
/// sem trocar o ícone de quem já escolheu. Não renomeie chaves já usadas.
const Map<String, IconData> kIconesFreela = {
  'estrela': Icons.star,
  'coracao': Icons.favorite,
  'pegada': Icons.pets,
  'folha': Icons.eco,
  'lua': Icons.nightlight_round,
  'fogo': Icons.local_fire_department,
  'raio': Icons.bolt,
  'diamante': Icons.diamond,
  'coelho': Icons.cruelty_free,
  'spa': Icons.spa,
  'gota': Icons.water_drop,
  'brilho': Icons.auto_awesome,
  'floco': Icons.ac_unit,
  'vento': Icons.air,
  'ancora': Icons.anchor,
  'bolo': Icons.cake,
  'camera': Icons.camera_alt,
  'cafe': Icons.coffee,
  'nuvem': Icons.cloud,
  'peca': Icons.extension,
  'bandeira': Icons.flag,
  'aviao': Icons.flight,
  'floresta': Icons.forest,
  'fone': Icons.headphones,
  'chave': Icons.key,
  'lampada': Icons.lightbulb,
  'flor': Icons.local_florist,
  'musica': Icons.music_note,
  'arvore': Icons.park,
  'foguete': Icons.rocket_launch,
  'veleiro': Icons.sailing,
  'escola': Icons.school,
  'jogo': Icons.sports_esports,
  'sol': Icons.sunny,
  'guarda_chuva': Icons.umbrella,
  'pincel': Icons.brush,
  'castelo': Icons.castle,
  'hexagono': Icons.hexagon,
  'pizza': Icons.local_pizza,
  'bar': Icons.local_bar,
  'restaurante': Icons.restaurant,
  'paleta': Icons.palette,
  'mente': Icons.psychology,
  'mundo': Icons.public,
  'escudo': Icons.shield,
  'olho': Icons.visibility,
  'trofeu': Icons.emoji_events,
  'camera2': Icons.photo_camera_back,
  'sorvete': Icons.icecream,
};

/// Chave do ícone de um freelancer. Sem escolha salva, usa a posição dele na
/// lista (ordem por nome), como antes.
String chaveIconeFreela(Usuario u, int indice) {
  final k = kIconesFreela.keys.toList();
  if (u.icone != null && kIconesFreela.containsKey(u.icone)) return u.icone!;
  return k[(indice < 0 ? 0 : indice) % k.length];
}

IconData iconeFreela(Usuario u, int indice) =>
    kIconesFreela[chaveIconeFreela(u, indice)]!;
