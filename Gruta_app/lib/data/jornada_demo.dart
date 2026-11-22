import '../models/aula.dart';

/// A Jornada de EXEMPLO: 60 aulas diárias genéricas, da aula piloto (0) à 59.
/// São sugestões de pauta; o conteúdo real é cadastrado pelo painel /adm.
const kTitulosJornada = [
  'Aula piloto: bem-vindo à Gruta', // 0
  'O que é magia, afinal?',
  'Intenção: a semente de todo trabalho',
  'Seu primeiro altar, com o que tem em casa',
  'A vela e as cores',
  'Os quatro elementos', // 5 (moeda)
  'Fogo: transformação',
  'Água: emoção e limpeza',
  'Terra: corpo e prosperidade',
  'Ar: palavra e pensamento',
  'Ciclos da lua: nova e crescente',
  'Ciclos da lua: cheia e minguante',
  'O diário mágico (o seu Grimório)',
  'Limpeza energética da casa',
  'Banho de ervas: o básico',
  'Proteção do dia a dia', // 15 (moeda)
  'Incensos e defumação',
  'Cristais: como escolher e limpar',
  'Ervas de quintal: arruda, alecrim, manjericão',
  'Chá como ritual',
  'Tarô: o que as cartas contam',
  'Oráculos do Brasil: búzios e baralho cigano',
  'Os anjos e a angelologia',
  'Ocultismo: as grandes correntes',
  'Símbolos: pentagrama, olho, espiral',
  'A roda do ano',
  'Sabás de inverno: Yule e Imbolc',
  'Sabás de primavera: Ostara e Beltane',
  'Sabás de verão: Litha e Lammas',
  'Sabás de outono: Mabon e Samhain',
  'Ética e responsabilidade na magia', // 30 (moeda)
  'Meditação de enraizamento',
  'Visualização criativa',
  'Sonhos e seus recados',
  'Números e numerologia básica',
  'Os planetas e os dias da semana',
  'Signos e elementos',
  'Feitiço de prosperidade simples',
  'Feitiço de amor-próprio',
  'Saquinhos e patuás',
  'Óleos e unguentos caseiros',
  'Sal, água e fogo: limpezas rápidas',
  'Sincronicidades',
  'Ancestralidade e memória',
  'Guias, mentores e intuição',
  'Pêndulo: como usar', // 45 (moeda)
  'Runas: uma introdução',
  'Velas de sete dias',
  'Simpatias populares',
  'Plantas que curam (com segurança)',
  'O corpo como templo',
  'Respiração e energia',
  'Escrita mágica e sigilos',
  'Grimório: organizando seus saberes',
  'Montando sua rotina mágica',
  'Lua nova de intenções',
  'Lua cheia de agradecimento',
  'Revisando a Jornada',
  'O próximo passo: escolha sua trilha',
  'Encerramento: a vela que não apaga', // 59 (moeda)
];

const _videoA =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';
const _videoB =
    'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4';

final List<Aula> kJornadaDemo = [
  for (var i = 0; i < kTitulosJornada.length; i++)
    Aula(
      id: 'j$i',
      trilhaId: kJornadaId,
      ordem: i,
      titulo: kTitulosJornada[i],
      descricao: i == 0
          ? 'A aula piloto: como a Gruta funciona, a vela diária e a '
              'Jornada de 60 aulas.'
          : 'Aula $i da Jornada. Cerca de cinco minutos para assistir com '
              'calma.',
      videoUrl: i.isEven ? _videoA : _videoB,
      duracaoSeg: 240 + (i * 37) % 100,
      reflexao: 'O que desta aula você quer levar para a sua vida?',
    ),
];
