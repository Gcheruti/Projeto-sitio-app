/// Os planos da Gruta. Os nomes seguem o tema: quem chega é Visitante, quem
/// assina vira Aprendiz e, mais adiante, Mestre.
enum Plano {
  visitante(
    nome: 'Visitante',
    preco: 'Gratuito',
    resumo: 'A aula piloto e mais duas aulas da Jornada para conhecer.',
    aulasJornada: 3,
    limiteTrilhas: 0,
    disponivel: true,
  ),
  aprendiz(
    nome: 'Aprendiz',
    preco: r'R$ 19,90/mês',
    resumo: 'A Jornada completa de 60 aulas e até 4 trilhas liberadas '
        'com moedas.',
    aulasJornada: 60,
    limiteTrilhas: 4,
    disponivel: true,
  ),
  mestre(
    nome: 'Mestre',
    preco: 'Em breve',
    resumo: 'Tudo do Aprendiz e todas as trilhas abertas, sem moedas.',
    aulasJornada: 60,
    limiteTrilhas: 99,
    disponivel: false,
  );

  const Plano({
    required this.nome,
    required this.preco,
    required this.resumo,
    required this.aulasJornada,
    required this.limiteTrilhas,
    required this.disponivel,
  });

  final String nome;
  final String preco;
  final String resumo;

  /// Quantas aulas da Jornada o plano abre (contando a aula piloto, a 0).
  final int aulasJornada;

  /// Quantas trilhas dá para liberar com moedas.
  final int limiteTrilhas;

  /// false = ainda não dá para escolher ("em desenvolvimento").
  final bool disponivel;

  /// Mestre abre todas as trilhas sem gastar moeda.
  bool get todasAsTrilhas => this == Plano.mestre;

  static Plano porNome(String? s) =>
      Plano.values.where((p) => p.name == s).firstOrNull ?? Plano.visitante;
}
