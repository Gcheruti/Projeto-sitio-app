import 'package:flutter_test/flutter_test.dart';
import 'package:gruta_app/logic/regras.dart';
import 'package:gruta_app/models/plano.dart';

void main() {
  final hoje = DateTime(2026, 11, 21, 15);

  EstadoJornada e(int ordem, Set<int> feitas, DateTime? ultima,
          [Plano plano = Plano.aprendiz, DateTime? agora]) =>
      estadoJornada(
          ordem: ordem,
          concluidas: feitas,
          ultimaConclusao: ultima,
          agora: agora ?? hoje,
          plano: plano);

  test('aula piloto abre no primeiro dia', () {
    expect(e(0, {}, null), EstadoJornada.disponivel);
    expect(e(1, {}, null), EstadoJornada.bloqueada);
  });

  test('concluiu hoje: a próxima só abre depois da meia-noite', () {
    final ontem23h = DateTime(2026, 11, 20, 23, 50);
    final hoje0h10 = DateTime(2026, 11, 21, 0, 10);
    // concluiu às 23h50 de ontem: às 0h10 de hoje já abre (não espera 24h)
    expect(e(1, {0}, ontem23h, Plano.aprendiz, hoje0h10),
        EstadoJornada.disponivel);
    // concluiu hoje à tarde: a próxima fica para amanhã
    expect(e(1, {0}, DateTime(2026, 11, 21, 14)), EstadoJornada.amanha);
  });

  test('visitante vê só as três primeiras aulas', () {
    expect(e(2, {0, 1}, null, Plano.visitante), EstadoJornada.disponivel);
    expect(e(3, {0, 1, 2}, null, Plano.visitante), EstadoJornada.plano);
    expect(e(3, {0, 1, 2}, null, Plano.aprendiz), EstadoJornada.disponivel);
  });

  test('moedas nos marcos da Jornada', () {
    expect(moedasGanhas({0, 1, 2, 3, 4}), 0);
    expect(moedasGanhas({for (var i = 0; i <= 5; i++) i}), 1);
    expect(moedasGanhas({for (var i = 0; i <= 30; i++) i}), 3);
    expect(moedasGanhas({for (var i = 0; i < 60; i++) i}), 5);
    expect(ehMarco(15), isTrue);
    expect(ehMarco(16), isFalse);
  });

  test('limite de trilhas por plano', () {
    expect(moedasDisponiveis(ganhas: 3, gastas: 0, plano: Plano.visitante), 0);
    expect(moedasDisponiveis(ganhas: 3, gastas: 1, plano: Plano.aprendiz), 2);
    expect(moedasDisponiveis(ganhas: 5, gastas: 0, plano: Plano.aprendiz), 4);
    expect(moedasDisponiveis(ganhas: 5, gastas: 4, plano: Plano.aprendiz), 0);
    expect(trilhaAberta(trilhaId: 't1', liberadas: {}, plano: Plano.mestre),
        isTrue);
    expect(trilhaAberta(trilhaId: 't1', liberadas: {}, plano: Plano.aprendiz),
        isFalse);
  });

  test('quanto falta para a próxima moeda', () {
    expect(faltamParaMoeda({}), 6);
    expect(faltamParaMoeda({0, 1, 2, 3, 4, 5}), 10);
  });
}
