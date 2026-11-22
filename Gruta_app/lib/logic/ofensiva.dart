import '../config/app_config.dart';

/// Só a data (sem hora), no fuso do aparelho.
DateTime soData(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _proximoDia(DateTime d) => DateTime(d.year, d.month, d.day + 1);

/// Resultado do cálculo da ofensiva ("a vela acesa").
class Ofensiva {
  const Ofensiva({
    required this.atual,
    required this.recorde,
    required this.feitoHoje,
    required this.amuletos,
    required this.diasProtegidos,
  });

  static const vazia = Ofensiva(
      atual: 0, recorde: 0, feitoHoje: false, amuletos: 0, diasProtegidos: {});

  /// Dias seguidos com pelo menos uma aula concluída.
  final int atual;
  final int recorde;

  /// Já assistiu a aula de hoje? Se não, a vela ainda pode apagar à meia-noite.
  final bool feitoHoje;

  /// Amuletos guardados: cada um protege um dia perdido sem zerar a ofensiva.
  final int amuletos;

  /// Dias que foram salvos por um amuleto (aparecem diferentes na semana).
  final Set<DateTime> diasProtegidos;

  /// A ofensiva corre risco hoje (existe e ainda não foi feita).
  bool get emRisco => atual > 0 && !feitoHoje;
}

/// Calcula a ofensiva a partir dos dias em que a pessoa concluiu aulas.
///
/// Regras (as mesmas da função minha_ofensiva() no Supabase):
/// - Cada dia com aula soma 1.
/// - A cada [AppConfig.diasPorAmuleto] dias seguidos ganha um amuleto
///   (até [AppConfig.maximoAmuletos]).
/// - Um dia sem aula gasta um amuleto, se houver; senão a ofensiva volta a 0.
/// - Hoje ainda não conta como perdido (dá tempo até a meia-noite).
Ofensiva calcularOfensiva(Iterable<DateTime> diasComAula, DateTime agora) {
  final dias = diasComAula.map(soData).toSet();
  final hoje = soData(agora);
  if (dias.isEmpty) return Ofensiva.vazia;

  final ordenados = dias.toList()..sort();
  var d = ordenados.first;
  var atual = 0, recorde = 0, amuletos = 0;
  final protegidos = <DateTime>{};

  while (!d.isAfter(hoje)) {
    if (dias.contains(d)) {
      atual++;
      if (atual % AppConfig.diasPorAmuleto == 0 &&
          amuletos < AppConfig.maximoAmuletos) {
        amuletos++;
      }
    } else if (d == hoje) {
      // hoje ainda está em aberto
    } else if (atual > 0 && amuletos > 0) {
      amuletos--;
      protegidos.add(d);
    } else {
      atual = 0;
    }
    if (atual > recorde) recorde = atual;
    d = _proximoDia(d);
  }

  return Ofensiva(
    atual: atual,
    recorde: recorde,
    feitoHoje: dias.contains(hoje),
    amuletos: amuletos,
    diasProtegidos: protegidos,
  );
}

/// Grau de quem estuda, pelo total de dias com aula (nomes neutros, de planta).
String grauIniciatico(int diasTotais) {
  if (diasTotais >= 365) return 'Bosque Sagrado';
  if (diasTotais >= 180) return 'Árvore';
  if (diasTotais >= 90) return 'Ramo';
  if (diasTotais >= 30) return 'Raiz';
  if (diasTotais >= 7) return 'Broto';
  return 'Semente';
}
