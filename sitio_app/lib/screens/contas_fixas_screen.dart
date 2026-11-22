import 'package:flutter/material.dart';

import '../models/lancamento.dart';
import '../services/auditoria.dart';
import '../services/financeiro_repository.dart';
import '../widgets/filtro_periodo.dart';

/// Contas que se repetem todo mês (água, luz, salários...).
class ContasFixasScreen extends StatefulWidget {
  const ContasFixasScreen({super.key});

  @override
  State<ContasFixasScreen> createState() => _ContasFixasState();
}

class _ContasFixasState extends State<ContasFixasScreen> {
  final _repo = FinanceiroRepository();
  List<Recorrente>? _lista;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final l = await _repo.recorrentes();
      if (mounted) setState(() => _lista = l);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar: $e');
    }
  }

  Future<void> _editar([Recorrente? r]) async {
    final novo = r == null;
    final rec = r ??
        Recorrente(
            categoria: kCategoriasDespesa.first,
            descricao: '',
            valor: 0,
            dia: 5);
    var cat = rec.categoria;
    var ativo = rec.ativo;
    final desc = TextEditingController(text: rec.descricao);
    final valor = TextEditingController(
        text: rec.valor == 0 ? '' : rec.valor.toStringAsFixed(2));
    final dia = TextEditingController(text: '${rec.dia}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(novo ? 'Nova conta fixa' : 'Editar conta fixa'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                initialValue: kCategoriasDespesa.contains(cat)
                    ? cat
                    : kCategoriasDespesa.first,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Categoria', border: OutlineInputBorder()),
                items: [
                  for (final c in kCategoriasDespesa)
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
                    labelText: 'Valor estimado (R\$)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dia,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Dia do vencimento (1–31)',
                    border: OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ativa'),
                value: ativo,
                onChanged: (v) => setD(() => ativo = v),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Salvar')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;

    final v = double.tryParse(valor.text.trim().replaceAll(',', '.')) ?? 0;
    final d = (int.tryParse(dia.text.trim()) ?? 5).clamp(1, 31);
    if (desc.text.trim().isEmpty) return;
    rec
      ..categoria = cat
      ..descricao = desc.text.trim()
      ..valor = v
      ..dia = d
      ..ativo = ativo;
    try {
      await _repo.salvarRecorrente(rec);
      Auditoria.registrar('fin_lancamento',
          '${novo ? 'Criou' : 'Editou'} conta fixa "${rec.descricao}"',
          entidade: 'financeiro');
      _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _lista;
    return Scaffold(
      appBar: AppBar(title: const Text('Contas fixas')),
      floatingActionButton: FloatingActionButton(
          onPressed: () => _editar(), child: const Icon(Icons.add)),
      body: _erro != null
          ? Center(child: Text(_erro!))
          : l == null
              ? const Center(child: CircularProgressIndicator())
              : l.isEmpty
                  ? const Center(
                      child: Text('🕯️ Nenhuma conta fixa cadastrada.'))
                  : ListView.separated(
                      itemCount: l.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final r = l[i];
                        return ListTile(
                          onTap: () => _editar(r),
                          title: Text(r.descricao),
                          subtitle: Text(
                              '${r.categoria} • todo dia ${r.dia}${r.ativo ? '' : ' • inativa'}'),
                          trailing: Text(fmtMoeda(r.valor)),
                        );
                      },
                    ),
    );
  }
}
