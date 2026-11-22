import 'package:flutter/material.dart';

import '../models/evento_agenda.dart';
import '../models/freelancer.dart';
import '../models/icones_freelancer.dart';
import '../models/usuario.dart';
import '../services/freelancer_repository.dart';


/// Agenda de TODOS os freelancers: cada dia mostra o ícone de quem foi/vai,
/// na cor do cargo exercido.
class FreelancerAgendaGeralScreen extends StatefulWidget {
  const FreelancerAgendaGeralScreen({super.key});

  @override
  State<FreelancerAgendaGeralScreen> createState() =>
      _FreelancerAgendaGeralScreenState();
}

class _FreelancerAgendaGeralScreenState
    extends State<FreelancerAgendaGeralScreen> {
  final _repo = FreelancerRepository();
  List<Usuario> _pessoas = [];
  List<DiaFreelancer> _dias = [];
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final p = await _repo.listar();
      final d = await _repo.diasDoMes(_mes);
      if (!mounted) return;
      setState(() {
        _pessoas = p;
        _dias = d;
        _erro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível carregar a agenda: $e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  IconData _icone(String usuarioId) {
    final i = _pessoas.indexWhere((p) => p.id == usuarioId);
    if (i < 0) return Icons.person;
    return iconeFreela(_pessoas[i], i);
  }

  String _nome(String usuarioId) {
    for (final p in _pessoas) {
      if (p.id == usuarioId) return p.nome;
    }
    return 'Freelancer';
  }

  List<DiaFreelancer> _doDia(DateTime d) => _dias
      .where((x) =>
          x.dia.year == d.year && x.dia.month == d.month && x.dia.day == d.day)
      .toList();

  void _mudarMes(int delta) {
    setState(() => _mes = DateTime(_mes.year, _mes.month + delta, 1));
    _carregar();
  }

  void _abrirDia(DateTime dia) {
    final lista = _doDia(dia);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${kDiasSemana[dia.weekday % 7]}, ${dia.day} de ${kMeses[dia.month - 1]}',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              if (lista.isEmpty) const Text('Nenhum freelancer agendado.'),
              for (final x in lista)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_icone(x.usuarioId),
                      color: cargoPorChave(x.cargo)?.cor),
                  title: Text(_nome(x.usuarioId)),
                  subtitle: Text(
                      '${cargoPorChave(x.cargo)?.nome ?? x.cargo}${x.presente ? ' • presente' : ''}'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _calendario(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final primeiro = DateTime(_mes.year, _mes.month, 1);
    final diasNoMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final desloc = primeiro.weekday % 7;
    final hoje = DateTime.now();
    final celulas = <Widget>[
      for (var i = 0; i < desloc; i++) const SizedBox(),
      for (var d = 1; d <= diasNoMes; d++)
        Builder(builder: (_) {
          final dia = DateTime(_mes.year, _mes.month, d);
          final lista = _doDia(dia);
          final ehHoje = hoje.year == dia.year &&
              hoje.month == dia.month &&
              hoje.day == dia.day;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _abrirDia(dia),
            child: Container(
              margin: const EdgeInsets.all(2),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(
                    color: ehHoje ? scheme.primary : scheme.outlineVariant,
                    width: ehHoje ? 1.5 : 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('$d', style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 1,
                    runSpacing: 1,
                    children: [
                      for (final x in lista)
                        Icon(_icone(x.usuarioId),
                            size: 13, color: cargoPorChave(x.cargo)?.cor),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
    ];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _mudarMes(-1)),
            Expanded(
              child: Center(
                child: Text('${kMeses[_mes.month - 1]} ${_mes.year}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ),
            IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _mudarMes(1)),
          ],
        ),
        Row(
          children: [
            for (final s in kDiasSemana)
              Expanded(
                  child: Center(
                      child: Text(s,
                          style: Theme.of(context).textTheme.labelSmall))),
          ],
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.8,
          children: celulas,
        ),
      ],
    );
  }

  Widget _guia(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Guia', style: t.titleSmall),
            const SizedBox(height: 4),
            Text(
              'O ícone identifica a pessoa; a cor mostra a função exercida no dia.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 8),
            Text('Funções (cores)', style: t.labelLarge),
            for (final c in kCargosFreelancer)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 14, color: c.cor),
                    const SizedBox(width: 8),
                    Text(c.nome),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Text('Freelancers (ícones)', style: t.labelLarge),
            if (_pessoas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text('Nenhum freelancer cadastrado.'),
              ),
            for (var i = 0; i < _pessoas.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(iconeFreela(_pessoas[i], i), size: 16),
                    const SizedBox(width: 8),
                    Text(_pessoas[i].nome),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agenda dos freelancers')),
      body: _erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_erro!, textAlign: TextAlign.center)))
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_carregando) const LinearProgressIndicator(),
                  _calendario(context),
                  const SizedBox(height: 12),
                  _guia(context),
                ],
              ),
            ),
    );
  }
}
