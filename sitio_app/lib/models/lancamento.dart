const List<String> kCategoriasDespesa = [
  'Funcionários (salários)',
  'Contratações',
  'Freelancers (diárias)',
  'Encargos e impostos',
  'Água',
  'Luz',
  'Internet',
  'Aluguel',
  'Manutenção',
  'Compras e insumos',
  'Marketing',
  'Equipamentos',
  'Outros',
];

const List<String> kCategoriasReceita = [
  'Aporte',
  'Vendas',
  'Serviços',
  'Outros',
];

List<String> categoriasDoTipo(String tipo) =>
    tipo == 'receita' ? kCategoriasReceita : kCategoriasDespesa;

/// Receita ou despesa da Toca dos Coelhos.
class Lancamento {
  Lancamento({
    this.id = '',
    required this.tipo,
    required this.categoria,
    required this.descricao,
    required this.valor,
    required this.data,
    this.pago = false,
    this.recorrenteId,
    this.observacao,
  });

  String id;
  String tipo; // 'despesa' | 'receita'
  String categoria;
  String descricao;
  double valor;
  DateTime data;
  bool pago;
  String? recorrenteId;
  String? observacao;

  bool get despesa => tipo == 'despesa';

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  factory Lancamento.deMapa(Map<String, dynamic> m) => Lancamento(
        id: '${m['id']}',
        tipo: '${m['tipo']}',
        categoria: '${m['categoria']}',
        descricao: '${m['descricao']}',
        valor: _d(m['valor']),
        data: DateTime.tryParse('${m['data']}') ?? DateTime.now(),
        pago: m['pago'] == true,
        recorrenteId: m['recorrente_id']?.toString(),
        observacao: m['observacao']?.toString(),
      );
}

/// Conta fixa mensal (água, luz, salários...).
class Recorrente {
  Recorrente({
    this.id = '',
    this.tipo = 'despesa',
    required this.categoria,
    required this.descricao,
    required this.valor,
    required this.dia,
    this.ativo = true,
  });

  String id;
  String tipo;
  String categoria;
  String descricao;
  double valor;
  int dia;
  bool ativo;

  factory Recorrente.deMapa(Map<String, dynamic> m) => Recorrente(
        id: '${m['id']}',
        tipo: '${m['tipo']}',
        categoria: '${m['categoria']}',
        descricao: '${m['descricao']}',
        valor: Lancamento._d(m['valor']),
        dia: (m['dia_vencimento'] as num?)?.toInt() ?? 5,
        ativo: m['ativo'] != false,
      );
}
