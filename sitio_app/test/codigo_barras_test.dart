import 'package:flutter_test/flutter_test.dart';
import 'package:sitio_app/services/codigo_barras.dart';

void main() {
  test('EAN-13 válido é mantido', () {
    expect(CodigoBarras.normalizar('7891000100103'), '7891000100103');
  });
  test('EAN com zero à esquerda (14 dígitos) vira EAN-13', () {
    expect(CodigoBarras.normalizar('07896090643776'), '7896090643776');
  });
  test('código interno da loja é descartado', () {
    expect(CodigoBarras.normalizar('0000000013024'), isNull);
  });
  test('dígito verificador inválido é descartado', () {
    expect(CodigoBarras.normalizar('7891000100104'), isNull);
  });
  test('vazio e null', () {
    expect(CodigoBarras.normalizar(null), isNull);
    expect(CodigoBarras.normalizar(' '), isNull);
  });
}
