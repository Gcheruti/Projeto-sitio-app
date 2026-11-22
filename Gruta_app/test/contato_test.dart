import 'package:flutter_test/flutter_test.dart';
import 'package:gruta_app/state/auth_state.dart';

void main() {
  test('telefone com DDD', () {
    expect(AuthState.validarTelefone('(11) 91234-5678'), isNull);
    expect(AuthState.validarTelefone('+55 11 91234-5678'), isNull);
    expect(AuthState.validarTelefone('1234-5678'), isNotNull);
    expect(AuthState.validarTelefone('telefone'), isNotNull);
  });

  test('e-mail', () {
    expect(AuthState.validarEmail('ana@exemplo.com.br'), isNull);
    expect(AuthState.validarEmail('ana@exemplo'), isNotNull);
    expect(AuthState.validarEmail('ana exemplo.com'), isNotNull);
  });
}
