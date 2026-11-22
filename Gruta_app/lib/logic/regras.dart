import '../models/plano.dart';
import 'ofensiva.dart';

/// Regras da Jornada, das moedas e dos planos. Funções puras, testadas em
/// test/regras_test.dart. O banco repete as mesmas regras (concluir_aula e
/// gastar_moeda), então mudar aqui exige mudar lá também.

/// A Jornada: aulas diárias genéricas, da 0 (aula piloto) à 59.
const kTotalJornada = 60;

/// Aulas da Jornada que dão uma moeda ao serem concluídas.
/// Métrica provisória, fácil de trocar.
const kMarcosMoeda = [5, 15, 30, 45, 59];

enum EstadoJornada {
  concluida, // já assistiu (pode rever)
  disponivel, // é a aula de hoje
  amanha, // a próxima, abre depois da meia-noite
  bloqueada, // mais à frente
  plano, // o plano atual não inclui esta aula
}

/// Estado de uma aula da Jornada.
///
/// [concluidas] são as ordens já feitas, [ultimaConclusao] a data/hora da
/// última aula da Jornada concluída. A regra é uma aula nova por DIA de
/// calendário: concluiu hoje, a próxima só abre depois da meia-noite.
EstadoJornada estadoJornada({
  required int ordem,
  required Set<int> concluidas,
  required DateTime? ultimaConclusao,
  required DateTime agora,
  required Plano plano,
}) {
  if (concluidas.contains(ordem)) return EstadoJornada.concluida;
  final proxima = proximaJornada(concluidas);
  if (proxima != ordem) return EstadoJornada.bloqueada;
  if (ordem >= plano.aulasJornada) return EstadoJornada.plano;
  if (ultimaConclusao != null && soData(ultimaConclusao) == soData(agora)) {
    return EstadoJornada.amanha;
  }
  return EstadoJornada.disponivel;
}

/// A próxima aula da Jornada (a menor ordem ainda não feita), ou null se a
/// Jornada terminou.
int? proximaJornada(Set<int> concluidas) {
  for (var i = 0; i < kTotalJornada; i++) {
    if (!concluidas.contains(i)) return i;
  }
  return null;
}

/// Moedas ganhas com as aulas da Jornada já concluídas.
int moedasGanhas(Set<int> concluidas) =>
    kMarcosMoeda.where(concluidas.contains).length;

/// true se concluir a aula [ordem] dá uma moeda.
bool ehMarco(int ordem) => kMarcosMoeda.contains(ordem);

/// Moedas que ainda dá para gastar: as ganhas, até o limite do plano, menos
/// as já gastas. Visitante nunca tem moeda para gastar.
int moedasDisponiveis({
  required int ganhas,
  required int gastas,
  required Plano plano,
}) {
  if (plano.todasAsTrilhas) return 0;
  final teto = ganhas < plano.limiteTrilhas ? ganhas : plano.limiteTrilhas;
  final r = teto - gastas;
  return r < 0 ? 0 : r;
}

/// A trilha está aberta para esta pessoa?
bool trilhaAberta({
  required String trilhaId,
  required Set<String> liberadas,
  required Plano plano,
}) =>
    plano.todasAsTrilhas || liberadas.contains(trilhaId);

/// Quantas aulas da Jornada faltam para a próxima moeda (null = acabaram).
int? faltamParaMoeda(Set<int> concluidas) {
  for (final m in kMarcosMoeda) {
    if (!concluidas.contains(m)) {
      final feitas = concluidas.where((o) => o < m).length;
      return (m + 1) - feitas;
    }
  }
  return null;
}
