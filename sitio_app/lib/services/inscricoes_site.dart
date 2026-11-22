import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Inscrição em curso/evento feita pelo site (tabela public.inscricoes_cursos,
/// preenchida pelo banco a partir de site.cadastros — ver
/// supabase/cursos_site.sql). Sem dados pessoais.
class InscricaoSite {
  InscricaoSite({
    required this.criadoEm,
    required this.categoria,
    required this.eventoTitulo,
    required this.eventoInicio,
    required this.produtoId,
    required this.produtoNome,
    required this.quantidade,
    required this.valorTotal,
    required this.status,
  });

  final DateTime criadoEm;
  final String categoria; // curso | evento_presenca
  final String eventoTitulo;
  final DateTime? eventoInicio;
  final String? produtoId;
  final String? produtoNome;
  final int quantidade;
  final double valorTotal;

  /// baixado | registrado | sem_vaga | sem_produto | cancelado
  final String status;

  /// Conta como venda: vagas tiradas (ou produto sem controle de estoque).
  bool get valida => status == 'baixado' || status == 'registrado';

  String get statusTexto => switch (status) {
        'baixado' => 'Vagas descontadas',
        'registrado' => 'Registrada',
        'sem_vaga' => 'Sem vagas no estoque',
        'sem_produto' => 'Sem item no estoque',
        'cancelado' => 'Cancelada',
        _ => status,
      };

  String get nome => produtoNome ?? eventoTitulo;

  static double _d(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  factory InscricaoSite.deMapa(Map<String, dynamic> m) => InscricaoSite(
        criadoEm:
            DateTime.tryParse('${m['criado_em']}')?.toLocal() ?? DateTime.now(),
        categoria: '${m['categoria'] ?? ''}',
        eventoTitulo: '${m['evento_titulo'] ?? ''}',
        eventoInicio: DateTime.tryParse('${m['evento_inicio'] ?? ''}')?.toLocal(),
        produtoId: m['produto_id']?.toString(),
        produtoNome: m['produto_nome']?.toString(),
        quantidade: (m['quantidade'] as num?)?.toInt() ?? 1,
        valorTotal: _d(m['valor_total']),
        status: '${m['status'] ?? ''}',
      );
}

/// Resultado da busca: [erro] preenchido quando a tabela ainda não existe ou
/// a consulta falhou (o relatório continua funcionando sem esta parte).
class InscricoesResultado {
  InscricoesResultado(this.lista, [this.erro]);
  final List<InscricaoSite> lista;
  final String? erro;

  List<InscricaoSite> get validas => lista.where((i) => i.valida).toList();
  int get pessoas => validas.fold(0, (s, i) => s + i.quantidade);
  double get valor => validas.fold(0.0, (s, i) => s + i.valorTotal);
  int contar(String status) => lista.where((i) => i.status == status).length;

  /// Pessoas inscritas (válidas) por id de produto.
  Map<String, int> get pessoasPorProduto {
    final m = <String, int>{};
    for (final i in validas) {
      if (i.produtoId == null) continue;
      m[i.produtoId!] = (m[i.produtoId!] ?? 0) + i.quantidade;
    }
    return m;
  }
}

Future<InscricoesResultado> buscarInscricoesSite(
    DateTime inicio, DateTime fim) async {
  try {
    final r = await Supabase.instance.client
        .from('inscricoes_cursos')
        .select()
        .gte('criado_em', inicio.toUtc().toIso8601String())
        .lt('criado_em', fim.toUtc().toIso8601String())
        .order('criado_em', ascending: false);
    return InscricoesResultado([
      for (final m in (r as List)) InscricaoSite.deMapa(Map<String, dynamic>.from(m))
    ]);
  } catch (e) {
    debugPrint('Inscrições do site indisponíveis: $e');
    return InscricoesResultado(const [],
        'Inscrições do site indisponíveis (rode supabase/cursos_site.sql).');
  }
}
