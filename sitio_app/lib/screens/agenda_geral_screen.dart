import 'dart:async';

import 'package:flutter/material.dart';

import '../models/agenda_visual.dart';
import '../models/evento_agenda.dart';
import '../models/notificacao.dart';
import '../models/produto.dart';
import '../state/app_state.dart';
import '../services/agenda_config_repository.dart';
import '../services/agenda_repository.dart';
import '../state/auth_state.dart';
import '../state/permissoes_state.dart';
import '../widgets/agenda_config_dialog.dart';
import '../widgets/agenda_marcas.dart';
import '../widgets/calendario_mes.dart';

/// Local do mapa -> ambiente do estoque.
const Map<String, String> _ambienteDoLocal = {
  'restaurante': 'Salão',
  'mercado': 'Loja',
  'casa_bruxa': 'Tarô',
  'gruta': 'Gruta',
};

class AgendaGeralScreen extends StatefulWidget {
  const AgendaGeralScreen({super.key});

  @override
  State<AgendaGeralScreen> createState() => _AgendaGeralScreenState();
}

class _AgendaGeralScreenState extends State<AgendaGeralScreen> {
  final _repo = AgendaRepository();
  final _cfgRepo = AgendaConfigRepository();
  final _visual = AgendaVisualResolver(kIconesAgendaGeral,
      padroes: kPadroesAgendaGeral);
  final List<EventoAgenda> _eventos = [];
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Timer? _timer;
  String? _erro;

  /// Cada tipo de evento tem sua cor/ícone.
  String _chave(EventoAgenda e) => e.tipo ?? 'Outro';

  Future<void> _carregarVisual() async {
    final c = await _cfgRepo.carregar('geral');
    if (!mounted) return;
    setState(() => _visual.config
      ..clear()
      ..addAll(c));
  }

  Future<void> _configuracoes() async {
    await abrirConfigAgenda(
      context,
      titulo: 'Configurações de agendamentos',
      escopo: 'geral',
      resolver: _visual,
      itens: [for (final t in kTiposEvento) ItemConfigAgenda(t, t)],
    );
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarVisual();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _carregar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final l = await _repo.buscar('geral');
      if (!mounted) return;
      setState(() {
        _erro = null;
        _eventos
          ..clear()
          ..addAll(l);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro =
          'Não foi possível carregar a agenda (rode supabase/agenda.sql): $e');
    }
  }

  Future<void> _novo([DateTime? dia]) async {
    final base = dia ?? DateTime.now();
    var data = DateTime(base.year, base.month, base.day);
    var hora = const TimeOfDay(hour: 9, minute: 0);
    final tituloCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    var tipo = kTiposEvento.first;
    String? local;
    Produto? item;
    var publico = true;
    var publicoMexido = false; // se a pessoa mexeu, o tipo não muda mais o padrão

    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Novo agendamento'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: tituloCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Título',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: tipo,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final t in kTiposEvento)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (v) => setLocal(() {
                    tipo = v ?? tipo;
                    if (!publicoMexido) publico = !kTiposInternos.contains(tipo);
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: local,
                  decoration: const InputDecoration(
                    labelText: 'Local (aparece no mapa do totem)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Sem local')),
                    for (final e in kLocais.entries)
                      DropdownMenuItem<String?>(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setLocal(() {
                    local = v;
                    item = null;
                  }),
                ),
                if (local != null) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Produto?>(
                    key: ValueKey('item_$local'),
                    initialValue: item,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Item cobrado na presença (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<Produto?>(value: null, child: Text('Nenhum')),
                      for (final p in appState.produtos
                          .where((p) => p.ambiente == _ambienteDoLocal[local])
                          .toList()
                        ..sort((a, b) => a.nome.compareTo(b.nome)))
                        DropdownMenuItem<Produto?>(value: p, child: Text(p.nome)),
                    ],
                    onChanged: (v) => setLocal(() => item = v),
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Evento voltado ao público'),
                  subtitle: Text(publico
                      ? 'Aparece no totem e na lista de eventos do dia.'
                      : 'Interno da equipe: não aparece no totem.'),
                  value: publico,
                  onChanged: (v) => setLocal(() {
                    publico = v;
                    publicoMexido = true;
                  }),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event),
                  title: Text(formatarDia(data)),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: data,
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 5),
                    );
                    if (d != null) setLocal(() => data = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text(
                      '${doisDigitos(hora.hour)}:${doisDigitos(hora.minute)}'),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: hora);
                    if (t != null) setLocal(() => hora = t);
                  },
                ),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (tituloCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (salvar != true) return;
    final inicio = DateTime(data.year, data.month, data.day, hora.hour, hora.minute);
    try {
      await _repo.inserir(
        agenda: 'geral',
        titulo: tituloCtrl.text.trim(),
        tipo: tipo,
        descricao: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
        inicio: inicio,
        fim: inicio.add(const Duration(hours: 1)),
        criadoPor: authState.usuario?.nome,
        local: local,
        produtoId: item?.id,
        publico: publico,
      );
      await _carregar();
    } catch (e) {
      _avisar('Agendamento NÃO foi salvo: $e');
    }
  }

  void _avisar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmarRemocao(EventoAgenda e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover agendamento?'),
        content: Text('${e.titulo} — ${formatarDia(e.inicio)} ${formatarHora(e.inicio)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remover')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.remover(e.id);
      await _carregar();
    } catch (err) {
      _avisar('Não foi possível remover: $err');
    }
  }

  Future<void> _removerLista() async {
    final lista = [..._eventos]..sort((a, b) => b.inicio.compareTo(a.inicio));
    if (lista.isEmpty) {
      _avisar('Nenhum agendamento para remover');
      return;
    }
    final e = await showDialog<EventoAgenda>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Remover qual agendamento?'),
        children: [
          SizedBox(
            width: double.maxFinite,
            height: 360,
            child: ListView(
              children: [
                for (final x in lista)
                  ListTile(
                    title: Text(x.titulo),
                    subtitle: Text('${formatarDia(x.inicio)} ${formatarHora(x.inicio)}'
                        '${x.tipo == null ? '' : ' • ${x.tipo}'}'),
                    onTap: () => Navigator.pop(ctx, x),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (e != null) await _confirmarRemocao(e);
  }

  void _abrirDia(DateTime dia) {
    final doDia = _eventos.where((e) => e.ocorreEm(dia)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(formatarDia(dia), style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              // A lista rola; o botão de adicionar fica sempre visível embaixo.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (doDia.isEmpty) const Text('Nenhum agendamento neste dia.'),
                    for (final e in doDia)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              _visual.cor(_chave(e)).withValues(alpha: 0.2),
                          child: Icon(_visual.icone(_chave(e)),
                              color: _visual.cor(_chave(e))),
                        ),
                        title: Text('${formatarHora(e.inicio)}  ${e.titulo}'),
                        subtitle: Text([
                          if (e.tipo != null) e.tipo!,
                          if (e.descricao != null) e.descricao!,
                        ].join(' • ')),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (permissoes.pode('agenda_editar'))
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar agendamento'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _novo(dia);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final agora = DateTime.now();
    final futuros = _eventos.where((e) => e.fim.isAfter(agora)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda geral'),
        actions: [
          if (permissoes.pode('agenda_editar') || permissoes.pode('agenda_config'))
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'novo') _novo();
              if (v == 'remover') _removerLista();
              if (v == 'config') _configuracoes();
            },
            itemBuilder: (_) => [
              if (permissoes.pode('agenda_editar'))
                const PopupMenuItem(value: 'novo', child: Text('Novo agendamento')),
              if (permissoes.pode('agenda_editar'))
                const PopupMenuItem(value: 'remover', child: Text('Remover agendamento')),
              if (permissoes.pode('agenda_config'))
                const PopupMenuItem(
                    value: 'config', child: Text('Configurações de agendamentos')),
            ],
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
                eventos: _eventos,
                onDia: _abrirDia,
                onMes: (m) => setState(() => _mes = m),
                proporcao: 0.9,
                marcas: (ctx, lista) => marcasAgenda(ctx, lista, _visual, _chave),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('Próximos eventos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (futuros.isEmpty) const Text('Nenhum evento futuro.'),
          for (final e in futuros)
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _visual.cor(_chave(e)).withValues(alpha: 0.2),
                  child: Icon(_visual.icone(_chave(e)), color: _visual.cor(_chave(e))),
                ),
                title: Text(e.titulo),
                subtitle: Text('${formatarDia(e.inicio)} às ${formatarHora(e.inicio)}'
                    '${e.tipo == null ? '' : ' • ${e.tipo}'}'),
                onTap: () => _abrirDia(DateTime(e.inicio.year, e.inicio.month, e.inicio.day)),
              ),
            ),
        ],
      ),
    );
  }
}
