import 'package:flutter_test/flutter_test.dart';
import 'package:gruta_app/logic/ofensiva.dart';

DateTime d(int dia) => DateTime(2026, 11, dia, 10);

void main() {
  test('sem aulas: ofensiva zerada', () {
    final o = calcularOfensiva([], d(21));
    expect(o.atual, 0);
    expect(o.feitoHoje, isFalse);
  });

  test('dias seguidos até hoje', () {
    final o = calcularOfensiva([d(18), d(19), d(20), d(21)], d(21));
    expect(o.atual, 4);
    expect(o.feitoHoje, isTrue);
    expect(o.recorde, 4);
  });

  test('hoje ainda não feito não zera (vela em risco)', () {
    final o = calcularOfensiva([d(19), d(20)], d(21));
    expect(o.atual, 2);
    expect(o.feitoHoje, isFalse);
    expect(o.emRisco, isTrue);
  });

  test('um dia perdido sem amuleto zera', () {
    final o = calcularOfensiva([d(17), d(18), d(20)], d(21));
    expect(o.atual, 1);
    expect(o.recorde, 2);
  });

  test('amuleto ganho em 7 dias protege um dia perdido', () {
    final dias = [for (var i = 1; i <= 7; i++) d(i), d(9), d(10)];
    final o = calcularOfensiva(dias, d(10));
    expect(o.atual, 9);
    expect(o.amuletos, 0);
    expect(o.diasProtegidos, {DateTime(2026, 11, 8)});
  });

  test('várias aulas no mesmo dia contam um dia só', () {
    final o = calcularOfensiva([d(21), DateTime(2026, 11, 21, 22)], d(21));
    expect(o.atual, 1);
  });

  test('graus', () {
    expect(grauIniciatico(0), 'Semente');
    expect(grauIniciatico(30), 'Raiz');
  });
}
