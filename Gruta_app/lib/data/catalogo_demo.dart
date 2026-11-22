import 'package:material_ui/material_ui.dart';

import '../models/aula.dart';
import '../models/trilha.dart';

/// Catálogo de EXEMPLO, usado no modo demonstração (sem Supabase).
/// Os títulos são sugestões; os vídeos são amostras públicas do Flutter só
/// para testar o player. O catálogo real vem das tabelas trilhas e aulas.

const _videoA =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
const _videoB =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

const _avisoSaude =
    'Conteúdo educativo e tradicional: não substitui orientação médica. '
    'Gestantes, lactantes e quem usa remédios contínuos devem consultar '
    'um profissional antes de usar qualquer planta.';

const List<Trilha> kTrilhasDemo = [
  Trilha(
    id: 't1', slug: 'taro', ordem: 1, icone: 'cartas', cor: Color(0xFFB88AD9),
    titulo: 'Tarô',
    subtitulo: 'Os 22 arcanos maiores, um por dia',
    descricao: 'Aprenda a ler o tarô carta a carta: símbolos, '
        'significados, tiragens simples e como interpretar com intuição.',
  ),
  Trilha(
    id: 't2', slug: 'bruxaria', ordem: 2, icone: 'vela', cor: Color(0xFFE08A4F),
    titulo: 'Bruxaria',
    subtitulo: 'Fundamentos, ética e rituais',
    descricao: 'O caminho da bruxa moderna: altar, intenção, ciclos lunares, '
        'proteção e os primeiros rituais.',
  ),
  Trilha(
    id: 't3', slug: 'bruxaria-natural', ordem: 3, icone: 'folha',
    cor: Color(0xFF8FB573),
    titulo: 'Bruxaria natural',
    subtitulo: 'A magia do quintal e das estações',
    descricao: 'Ervas, pedras, água e fogo: a bruxaria que nasce da terra, '
        'da roda do ano e do que cresce perto de você.',
  ),
  Trilha(
    id: 't4', slug: 'chas', ordem: 4, icone: 'cha', cor: Color(0xFFD9B26B),
    titulo: 'Chás medicinais',
    subtitulo: 'Preparos, combinações e cuidados',
    descricao: 'Infusão, decocção e maceração. Quais plantas, quanto e '
        'quando. $_avisoSaude',
  ),
  Trilha(
    id: 't5', slug: 'cura-plantas', ordem: 5, icone: 'planta',
    cor: Color(0xFF6FAF8F),
    titulo: 'Cura pelas plantas',
    subtitulo: 'Saberes populares e segurança',
    descricao: 'Banhos, compressas, tinturas e unguentos da tradição '
        'popular brasileira. $_avisoSaude',
  ),
  Trilha(
    id: 't6', slug: 'ocultismo', ordem: 6, icone: 'olho',
    cor: Color(0xFF8C9AD1),
    titulo: 'Ocultismo',
    subtitulo: 'Símbolos, tradições e história',
    descricao: 'Hermetismo, alquimia, cabala e os grandes símbolos do '
        'conhecimento oculto, explicados sem mistério desnecessário.',
  ),
  Trilha(
    id: 't7', slug: 'angelologia', ordem: 7, icone: 'asas',
    cor: Color(0xFFE9D58A),
    titulo: 'Angelologia',
    subtitulo: 'Hierarquias, nomes e orações',
    descricao: 'Os coros angélicos, os anjos da guarda, os arcanjos e '
        'como cada tradição se relaciona com eles.',
  ),
  Trilha(
    id: 't8', slug: 'buzios', ordem: 8, icone: 'conchas',
    cor: Color(0xFFE3B7A0),
    titulo: 'Búzios',
    subtitulo: 'O jogo, as caídas e os odus',
    descricao: 'A história e o respeito ao jogo de búzios: como as conchas '
        'caem, o que dizem e o papel de quem joga.',
  ),
];

const Map<String, List<String>> _titulos = {
  't1': [
    'O Louco: o primeiro passo',
    'O Mago: as ferramentas na mesa',
    'A Sacerdotisa: o que não é dito',
    'A Imperatriz: tudo o que floresce',
    'O Imperador: estrutura e limite',
    'Sua primeira tiragem de três cartas',
  ],
  't2': [
    'O que é bruxaria (e o que não é)',
    'Montando um altar simples',
    'Intenção: a base de todo ritual',
    'As fases da lua na prática',
    'Proteção do lar com sal e ervas',
    'Seu primeiro ritual de lua nova',
  ],
  't3': [
    'A roda do ano no hemisfério sul',
    'Sete ervas que toda bruxa conhece',
    'Água de chuva, de rio e de mar',
    'Pedras do quintal e cristais comuns',
    'Colheita consciente',
    'Um sachê de proteção',
  ],
  't4': [
    'Infusão, decocção e maceração',
    'Camomila, erva-cidreira e melissa',
    'Gengibre e canela: os aquecedores',
    'Chás para a digestão',
    'Quando NÃO tomar um chá',
    'Montando sua caixa de chás',
  ],
  't5': [
    'Como a tradição popular cura',
    'Banhos de ervas: preparo e uso',
    'Compressas e cataplasmas',
    'Tinturas caseiras com segurança',
    'Unguento de calêndula',
    'Plantas que exigem cuidado',
  ],
  't6': [
    'O Caibalion em cinco minutos',
    'Os quatro elementos',
    'Alquimia: muito além do ouro',
    'A árvore da vida',
    'Símbolos que você já viu',
    'Como estudar sem cair em armadilhas',
  ],
  't7': [
    'Os nove coros angélicos',
    'Seu anjo da guarda',
    'Os sete arcanjos',
    'Anjos e os dias da semana',
    'Orações e invocações',
    'Diário angélico',
  ],
  't8': [
    'Origem e respeito ao jogo',
    'A concha aberta e a fechada',
    'O que é um odu',
    'Caídas e combinações básicas',
    'O papel de quem joga',
    'Perguntas e ética da consulta',
  ],
};

const _reflexoes = [
  'O que mais chamou sua atenção nesta aula?',
  'Como você pode levar isso para o seu dia hoje?',
  'Que pergunta ficou na sua cabeça?',
];

final List<Aula> kAulasDemo = [
  for (final t in kTrilhasDemo)
    for (var i = 0; i < _titulos[t.id]!.length; i++)
      Aula(
        id: '${t.id}-a${i + 1}',
        trilhaId: t.id,
        ordem: i + 1,
        titulo: _titulos[t.id]![i],
        descricao: 'Aula ${i + 1} da trilha ${t.titulo}. '
            'Cerca de cinco minutos para assistir com calma.',
        videoUrl: i.isEven ? _videoA : _videoB,
        duracaoSeg: 240 + (i * 23) % 90,
        reflexao: _reflexoes[i % _reflexoes.length],
      ),
];

/// Frases para o topo da tela Hoje (uma por dia).
const List<String> kFrasesDoDia = [
  'Quem acende uma vela por dia nunca fica no escuro.',
  'A erva certa, na hora certa, na dose certa.',
  'Cinco minutos de estudo valem mais que uma noite de pressa.',
  'Toda gruta começa com uma fresta de luz.',
  'O que se planta com intenção, floresce com raiz.',
  'Os símbolos falam com quem volta para ouvir.',
  'A lua muda todo dia, e mesmo assim é a mesma lua.',
];
