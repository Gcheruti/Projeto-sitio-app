import 'package:flutter/material.dart';

import '../models/lancamento.dart';
import '../services/auditoria.dart';
import '../services/financeiro_repository.dart';
import '../widgets/filtro_periodo.dart';
import '../widgets/graficos_simples.dart';
import 'contas_fixas_screen.dart';

/// Controle financeiro da Toca dos Coelhos (só Adm).
class FinanceiroScreen extends StatefulWidget {
  const FinanceiroScreen({super.key, this.embutido = false});

  /// true = dentro das abas do Financeiro (sem barra de título própria).
  final bool embutido;

  @override
  State<FinanceiroScreen> createState() => _FinanceiroState();
}

class _FinanceiroState extends State<FinanceiroScreen> {
  final _repo = FinanceiroRepository();
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month);
  List<Lancamento> _itens = [];
  bool _carregando = true;
  String? _erro;
  String _filtro = 'todos'; // todos | despesa | receita | pendente

  static const _nomesMes = [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho',
    'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final l = await _repo.lancamentosDoMes(_mes);
      if (!mounted) return;
      setState(() {
        _itens = l;
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erro = 'Não foi possível carregar. A tabela do financeiro foi criada '
            '(financeiro.sql)?\n$e';
        _carregando = false;
      });
    }
  }

  void _mudarMes(int d) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + d));
    _carregar();
  }

  double get _receitas => _itens
      .where((l) => !l.despesa && l.pago)
      .fold(0.0, (a, l) => a + l.valor);
  double get _despesasPagas => _itens
      .where((l) => l.despesa && l.pago)
      .fold(0.0, (a, l) => a + l.valor);
  double get _aPagar => _itens
      .where((l) => l.despesa && !l.pago)
      .fold(0.0, (a, l) => a + l.valor);

  List<Lancamento> get _filtrados => _itens.where((l) {
        switch (_filtro) {
          case 'despesa':
            return l.despesa;
          case 'receita':
            return !l.despesa;
          case 'pendente':
            return !l.pago;
          default:
            return true;
        }
      }).toList()
        ..sort((a, b) => b.data.compareTo(a.data));

  Future<void> _gerarFixas() async {
    try {
      final n = await _repo.gerarContasFixas(_mes);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 0
            ? 'Todas as contas fixas deste mês já foram geradas'
            : '$n conta(s) fixa(s) gerada(s) como "a pagar"'),
      ));
      if (n > 0) {
        Auditoria.registrar('fin_lancamento',
            'Gerou $n conta(s) fixa(s) de ${_nomesMes[_mes.month]}/${_mes.year}',
            entidade: 'financeiro');
      }
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro: $e')));
    }
  }

  Future<void> _abrirForm([Lancamento? existente]) async {
    final novo = existente == null;
    final l = existente ??
        Lancamento(
          tipo: 'despesa',
          categoria: kCategoriasDespesa.first,
          descricao: '',
          valor: 0,
          data: DateTime(_mes.year, _mes.month,
              DateTime.now().month == _mes.month ? DateTime.now().day : 1),
        );
    var tipo = l.tipo;
    var cat = l.categoria;
    var data = l.data;
    var pago = l.pago;
    final desc = TextEditingController(text: l.descricao);
    final valor = TextEditingController(
        text: l.valor == 0 ? '' : l.valor.toStringAsFixed(2));
    final obs = TextEditingController(text: l.observacao ?? '');

    final acao = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(novo ? 'Novo lançamento' : 'Editar lançamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'despesa', label: Text('Despesa')),
                    ButtonSegment(value: 'receita', label: Text('Receita')),
                  ],
                  selected: {tipo},
                  onSelectionChanged: (s) => setD(() {
                    tipo = s.first;
                    cat = categoriasDoTipo(tipo).first;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: categoriasDoTipo(tipo).contains(cat)
                      ? cat
                      : categoriasDoTipo(tipo).first,
                  key: ValueKey('cat_$tipo'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Categoria', border: OutlineInputBorder()),
                  items: [
                    for (final c in categoriasDoTipo(tipo))
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => cat = v ?? cat,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: desc,
                  decoration: const InputDecoration(
                      labelText: 'Descrição', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: valor,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Valor (R\$)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text('Data: ${fmtData(data)}'),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: data,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setD(() => data = d);
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(tipo == 'despesa' ? 'Já foi pago' : 'Já foi recebido'),
                  value: pago,
                  onChanged: (v) => setD(() => pago = v ?? false),
                ),
                TextField(
                  controller: obs,
                  maxLines: 2,
                  decoration: const InputDecoration(
                      labelText: 'Observação', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            if (!novo)
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'excluir'),
                child: const Text('Excluir'),
              ),
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, 'salvar'),
                child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (acao == null || !mounted) return;

    try {
      if (acao == 'excluir') {
        await _repo.excluir(l.id);
        Auditoria.registrar('fin_lancamento',
            'Excluiu lançamento "${l.descricao}" (${fmtMoeda(l.valor)})',
            entidade: 'financeiro');
      } else {
        final v = double.tryParse(valor.text.trim().replaceAll(',', '.')) ?? 0;
        if (desc.text.trim().isEmpty || v <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Informe descrição e um valor maior que zero.')));
          return;
        }
        l
          ..tipo = tipo
          ..categoria = cat
          ..descricao = desc.text.trim()
          ..valor = v
          ..data = data
          ..pago = pago
          ..observacao = obs.text.trim().isEmpty ? null : obs.text.trim();
        if (novo) {
          await _repo.inserir(l);
        } else {
          await _repo.atualizar(l);
        }
        Auditoria.registrar('fin_lancamento',
            '${novo ? 'Lançou' : 'Editou'} ${l.tipo} "${l.descricao}" (${fmtMoeda(v)})',
            entidade: 'financeiro');
      }
      _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
    }
  }

  Future<void> _alternarPago(Lancamento l) async {
    l.pago = !l.pago;
    setState(() {});
    try {
      await _repo.atualizar(l);
      Auditoria.registrar('fin_lancamento',
          '${l.pago ? 'Marcou como pago' : 'Desmarcou pagamento de'} "${l.descricao}"',
          entidade: 'financeiro');
    } catch (e) {
      l.pago = !l.pago;
      if (mounted) setState(() {});
    }
  }

  Widget _card(String t, double v, Color? cor) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(fmtMoeda(v),
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold, color: cor)),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final erro = Theme.of(context).colorScheme.error;
    final saldo = _receitas - _despesasPagas;

    final porCat = <String, double>{};
    for (final l in _itens.where((l) => l.despesa)) {
      porCat[l.categoria] = (porCat[l.categoria] ?? 0) + l.valor;
    }
    final grafico = porCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final acoes = <Widget>[
      IconButton(
        tooltip: 'Contas fixas',
        icon: const Icon(Icons.event_repeat),
        onPressed: () async {
          await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ContasFixasScreen()));
          _carregar();
        },
      ),
      IconButton(
        tooltip: 'Gerar contas fixas do mês',
        icon: const Icon(Icons.playlist_add_check),
        onPressed: _gerarFixas,
      ),
    ];
    return Scaffold(
      appBar: widget.embutido
          ? null
          : AppBar(title: const Text('Toca dos Coelhos'), actions: acoes),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _abrirForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Row(
            children: [
              // mês no centro (ocupa o espaço que sobra) e ações à direita:
              // não estoura em telas estreitas.
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _mudarMes(-1)),
                    Flexible(
                      child: Text('${_nomesMes[_mes.month]} ${_mes.year}',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                        icon: const Icon(Icons.chevron_right),
                        onPressed: () => _mudarMes(1)),
                  ],
                ),
              ),
              if (widget.embutido) ...acoes,
            ],
          ),
          if (_carregando)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_erro != null)
            Expanded(
                child: Center(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_erro!))))
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 90),
                children: [
                  Row(children: [
                    _card('Recebido', _receitas, null),
                    _card('Pago', _despesasPagas, null),
                  ]),
                  Row(children: [
                    _card('A pagar', _aPagar, _aPagar > 0 ? erro : null),
                    _card('Saldo', saldo, saldo < 0 ? erro : null),
                  ]),
                  if (grafico.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                      child: Text('Despesas por categoria',
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    GraficoHorizontal(
                      dados: [for (final e in grafico) (e.key, e.value)],
                      formato: (v) => fmtMoeda(v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final f in const [
                        ('todos', 'Todos'),
                        ('despesa', 'Despesas'),
                        ('receita', 'Receitas'),
                        ('pendente', 'Pendentes'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f.$2),
                            selected: _filtro == f.$1,
                            onSelected: (_) => setState(() => _filtro = f.$1),
                          ),
                        ),
                    ]),
                  ),
                  if (_filtrados.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('🕯️ Nenhum lançamento aqui.')),
                    ),
                  for (final l in _filtrados)
                    Card(
                      child: ListTile(
                        onTap: () => _abrirForm(l),
                        leading: IconButton(
                          tooltip: l.pago ? 'Desmarcar' : 'Marcar como pago',
                          icon: Icon(l.pago
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked),
                          onPressed: () => _alternarPago(l),
                        ),
                        title: Text(l.descricao),
                        subtitle: Text(
                            '${l.categoria} • ${fmtData(l.data)}${l.pago ? '' : ' • pendente'}'),
                        trailing: Text(
                          '${l.despesa ? '-' : '+'}${fmtMoeda(l.valor)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: l.despesa ? erro : null),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
