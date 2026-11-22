import 'package:material_ui/material_ui.dart';

/// "Conheça nossos outros serviços": sites, apps e lugares da família.
/// Para trocar um endereço, edite aqui. url null = aparece "em breve".
class Servico {
  const Servico({
    required this.nome,
    required this.descricao,
    required this.icone,
    required this.cor,
    this.url,
    this.destaques = const [],
  });
  final String nome;
  final String descricao;
  final IconData icone;
  final Color cor;
  final String? url;
  final List<String> destaques;
}

const kServicos = [
  Servico(
    nome: 'Cosmória',
    descricao: 'A loja mágica: tudo para os seus rituais chegar em casa.',
    icone: Icons.storefront_outlined,
    cor: Color(0xFFB88AD9),
    destaques: ['Velas', 'Incensos', 'Cristais', 'Ervas', 'Oráculos'],
  ),
  Servico(
    nome: 'Sítio dos Coelhos',
    descricao: 'Onde a magia acontece ao vivo: venha nos visitar.',
    icone: Icons.cottage_outlined,
    cor: Color(0xFF8FB573),
    destaques: [
      'Eventos e rituais',
      'Leitura de tarô',
      'Loja física',
      'Cursos presenciais',
    ],
  ),
  Servico(
    nome: 'Consultas',
    descricao: 'Tarô, búzios e orientação espiritual com a nossa equipe.',
    icone: Icons.style_outlined,
    cor: Color(0xFFF0A63A),
    destaques: ['Tarô', 'Búzios', 'Baralho cigano'],
  ),
];
