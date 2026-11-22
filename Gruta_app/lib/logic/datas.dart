/// Datas em português sem depender de pacote extra.
const _diasSemana = [
  'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
  'Sexta-feira', 'Sábado', 'Domingo'
];
const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro'
];

/// "Sábado, 21 de novembro"
String dataPorExtenso(DateTime d) =>
    '${_diasSemana[d.weekday - 1]}, ${d.day} de ${_meses[d.month - 1]}';

/// "21 nov 2026"
String dataCurta(DateTime d) =>
    '${d.day} ${_meses[d.month - 1].substring(0, 3)} ${d.year}';

String saudacao(DateTime d) {
  if (d.hour < 5) return 'Boa noite';
  if (d.hour < 12) return 'Bom dia';
  if (d.hour < 18) return 'Boa tarde';
  return 'Boa noite';
}

/// "08:30"
String hora(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Tempo até a meia-noite, ex.: "5 h 12 min".
String ateMeiaNoite(DateTime agora) {
  final fim = DateTime(agora.year, agora.month, agora.day + 1);
  final r = fim.difference(agora);
  final h = r.inHours, m = r.inMinutes % 60;
  return h > 0 ? '$h h $m min' : '$m min';
}
