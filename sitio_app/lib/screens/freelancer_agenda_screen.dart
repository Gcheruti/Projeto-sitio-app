import 'package:flutter/material.dart';

import '../models/evento_agenda.dart';
import '../models/freelancer.dart';
import '../models/usuario.dart';
import '../services/freelancer_repository.dart';
import '../state/auth_state.dart';
import '../widgets/calendario_mes.dart';

/// Calendário de diárias de um freelancer. Cada dia recebe a cor do cargo.
/// O gasto só entra no financeiro quando o freelancer faz login naquele dia.
class FreelancerAgendaScreen extends StatefulWidget {
  const FreelancerAgendaScreen({super.key, required this.freelancer});

  final Usuario freelancer;

  @override
  State<FreelancerAgendaScreen> createState() => _FreelancerAgendaScreenState();
}

class _FreelancerAgendaScreenState extends State<FreelancerAgendaScreen> {
  final _repo = FreelancerRepository();
  List<DiaFreelancer> _dias = [];
  Map<String, double> _valores = {};
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final d = await _repo.dias(widget.freelancer.id);
      final v = await _repo.valoresCargos();
      if (!mounted) return;
      setState(() {
        _dias = d;
        _valores = v;
        _erro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro =
          'Não foi possível carregar (rode supabase/freelancers.sql): $e');
    }
  }

  void _avisar(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  DiaFreelancer? _doDia(DateTime d) {
    for (final x in _dias) {
      if (x.dia.year == d.year && x.dia.month == d.month && x.dia.day == d.day) {
        return x;
      }
    }
    return null;
  }

  Future<void> _escolherCargo(DateTime dia) async {
    final atual = _doDia(dia);
    final bloqueado = atual != null && atual.presente;
    final escolha = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Cargo em ${formatarDia(dia)}'),
        children: [
          if (bloqueado)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text('Este dia já teve login: o gasto já foi lançado e não pode ser alterado aqui.'),
            )
          else ...[
            for (final c in kCargosFreelancer)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, c.chave),
                child: Row(children: [
                  Icon(Icons.circle, color: c.cor, size: 16),
                  const SizedBox(width: 12),
                  Expanded(child: Text(c.nome)),
                  Text('R\$ ${(_valores[c.chave] ?? 0).toStringAsFixed(2)}'),
                ]),
              ),
            if (atual != null)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, '_remover'),
                child: const Row(children: [
                  Icon(Icons.close, size: 16),
                  SizedBox(width: 12),
                  Text('Remover dia'),
                ]),
              ),
          ],
        ],
      ),
    );
    if (escolha == null) return;
    try {
      if (escolha == '_remover') {
        await _repo.removerDia(atual!.id);
      } else {
        await _repo.definirDia(
          usuarioId: widget.freelancer.id,
          dia: dia,
          cargo: escolha,
          valor: _valores[escolha] ?? 0,
          criadoPor: authState.usuario?.nome,
        );
      }
      await _carregar();
    } catch (e) {
      _avisar('Não foi possível salvar: $e');
    }
  }

  Future<void> _editarValores() async {
    final ctrls = {
      for (final c in kCargosFreelancer)
        c.chave: TextEditingController(
            text: (_valores[c.chave] ?? 0).toStringAsFixed(2)),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Valor da diária por cargo'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final c in kCargosFreelancer)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: ctrls[c.chave],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: c.nome,
                    prefixText: 'R\$ ',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            const Text('Vale para dias agendados daqui em diante.',
                style: TextStyle(fontSize: 12)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      for (final c in kCargosFreelancer) {
        final v = double.tryParse(ctrls[c.chave]!.text.replaceAll(',', '.'));
        if (v != null) await _repo.salvarValorCargo(c.chave, v);
      }
      await _carregar();
    } catch (e) {
      _avisar('Não foi possível salvar os valores: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final doMes = _dias
        .where((d) => d.dia.year == _mes.year && d.dia.month == _mes.month)
        .toList()
      ..sort((a, b) => a.dia.compareTo(b.dia));
    final total = doMes.fold<double>(0, (s, d) => s + d.valor);
    final recebido =
        doMes.where((d) => d.presente).fold<double>(0, (s, d) => s + d.valor);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.freelancer.nome),
        actions: [
          IconButton(
            tooltip: 'Valor por cargo',
            icon: const Icon(Icons.payments_outlined),
            onPressed: _editarValores,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: CalendarioMes(
                mes: _mes,
                eventos: const [],
                onDia: _escolherCargo,
                onMes: (m) => setState(() => _mes = m),
                corDoDia: (d) {
                  final x = _doDia(d);
                  return x == null ? null : cargoPorChave(x.cargo)?.cor;
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, children: [
            for (final c in kCargosFreelancer)
              Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, color: c.cor, size: 12),
                const SizedBox(width: 4),
                Text(c.nome, style: Theme.of(context).textTheme.bodySmall),
              ]),
          ]),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              title: Text('${kMeses[_mes.month - 1]}: ${doMes.length} dia(s) agendado(s)'),
              subtitle: Text('Já lançado no financeiro (com login): R\$ ${recebido.toStringAsFixed(2)}'),
              trailing: Text('R\$ ${total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
          for (final d in doMes)
            Card(
              child: ListTile(
                leading: Icon(Icons.circle, color: cargoPorChave(d.cargo)?.cor),
                title: Text('${formatarDia(d.dia)} — ${cargoPorChave(d.cargo)?.nome ?? d.cargo}'),
                subtitle: Text(d.presente
                    ? 'Entrou ${formatarHora(d.loginEm!)}'
                        '${d.logoutEm == null ? '' : ' • saiu ${formatarHora(d.logoutEm!)}'}'
                    : 'Aguardando login'),
                trailing: Text('R\$ ${d.valor.toStringAsFixed(2)}'),
                onTap: () => _escolherCargo(d.dia),
              ),
            ),
        ],
      ),
    );
  }
}
