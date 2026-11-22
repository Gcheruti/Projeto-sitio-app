import 'dart:async';

import 'package:flutter/material.dart';

import '../models/agenda_visual.dart';
import '../models/evento_agenda.dart';
import '../models/produto.dart';
import '../services/agenda_config_repository.dart';
import '../services/agenda_repository.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/permissoes_state.dart';
import '../widgets/agenda_config_dialog.dart';
import '../widgets/agenda_marcas.dart';
import '../widgets/calendario_mes.dart';

const int _primeiraHora = 7;
const int _ultimaHora = 23;
const double _alturaHora = 56;

/// Agenda da Casa da Bruxa: horários do dia dentro de um quadro rolável e,
/// logo abaixo, o calendário do mês com o ícone colorido de cada atendimento.
/// Segure um agendamento e arraste para outro horário para reagendar.
class AgendaBruxaScreen extends StatefulWidget {
  const AgendaBruxaScreen({super.key});

  @override
  State<AgendaBruxaScreen> createState() => _AgendaBruxaScreenState();
}

class _AgendaBruxaScreenState extends State<AgendaBruxaScreen> {
  final _repo = AgendaRepository();
  final _cfgRepo = AgendaConfigRepository();
  final _visual = AgendaVisualResolver(kIconesBruxa);
  final _rolagem = ScrollController();
  final List<EventoAgenda> _eventos = [];
  DateTime _dia = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Timer? _timer;
  bool _arrastando = false;
  bool _rolouParaAgora = false;
  String? _erro;

  bool get _edita => permissoes.pode('agenda_editar');

  /// Cada tipo de atendimento (produto) tem sua cor/ícone; sem produto, pelo título.
  String _chave(EventoAgenda e) => e.produtoId ?? e.titulo;

  @override
  void initState() {
    super.initState();
    _carregar();
    _carregarVisual();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_arrastando) _carregar();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregarVisual() async {
    final c = await _cfgRepo.carregar('casa_bruxa');
    if (!mounted) return;
    setState(() => _visual.config
      ..clear()
      ..addAll(c));
  }

  Future<void> _carregar() async {
    try {
      final l = await _repo.buscar('casa_bruxa');
      if (!mounted) return;
      setState(() {
        _erro = null;
        _eventos
          ..clear()
          ..addAll(l);
      });
      _rolarParaAgoraUmaVez();
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro =
          'Não foi possível carregar a agenda (rode supabase/agenda.sql): $e');
    }
  }

  /// Ao abrir no dia de hoje, deixa a hora atual visível no quadro.
  void _rolarParaAgoraUmaVez() {
    if (_rolouParaAgora) return;
    _rolouParaAgora = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_rolagem.hasClients) return;
      final h = DateTime.now().hour;
      final alvo = ((h - _primeiraHora - 1) * _alturaHora)
          .clamp(0.0, _rolagem.position.maxScrollExtent)
          .toDouble();
      _rolagem.jumpTo(alvo);
    });
  }

  void _avisar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _irPara(DateTime d) => setState(() {
        _dia = DateTime(d.year, d.month, d.day);
        _mes = DateTime(d.year, d.month, 1);
      });

  List<Produto> get _atendimentos => appState.produtos
      .where((p) => p.ambiente == 'Tarô')
      .toList()
    ..sort((a, b) => a.nome.compareTo(b.nome));

  Future<void> _configuracoes() async {
    await abrirConfigAgenda(
      context,
      titulo: 'Configurações da agenda',
      escopo: 'casa_bruxa',
      resolver: _visual,
      itens: [for (final p in _atendimentos) ItemConfigAgenda(p.id, p.nome)],
      vazio: 'Cadastre no Estoque itens da Casa da Bruxa (atendimentos) primeiro.',
    );
    if (mounted) setState(() {});
  }

  void _abrirDia(DateTime dia) {
    final doDia = _eventos.where((e) => e.ocorreEm(dia)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
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
              Text('${kDiasSemana[dia.weekday % 7]}, ${formatarDia(dia)}',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (doDia.isEmpty) const Text('Nenhum atendimento neste dia.'),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final e in doDia)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor:
                              _visual.cor(_chave(e)).withValues(alpha: 0.2),
                          child: Icon(_visual.icone(_chave(e)),
                              color: _visual.cor(_chave(e))),
                        ),
                        title: Text(e.titulo),
                        subtitle: Text('${formatarHora(e.inicio)} – ${formatarHora(e.fim)}'
                            '${e.descricao == null ? '' : ' • ${e.descricao}'}'),
                        onTap: () {
                          Navigator.pop(ctx);
                          _detalhe(e);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.schedule),
                label: const Text('Ver horários deste dia'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _irPara(dia);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _novo(int hora) async {
    final itens = _atendimentos;
    if (itens.isEmpty) {
      _avisar('Cadastre no Estoque itens da Casa da Bruxa (atendimentos) primeiro');
      return;
    }
    Produto escolhido = itens.first;
    var h = TimeOfDay(hour: hora, minute: 0);
    var duracao = 60;
    final obsCtrl = TextEditingController();

    final salvar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Agendar em ${formatarDia(_dia)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Produto>(
                  initialValue: escolhido,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Atendimento',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final p in itens)
                      DropdownMenuItem(value: p, child: Text(p.nome)),
                  ],
                  onChanged: (v) => setLocal(() => escolhido = v ?? escolhido),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule),
                  title: Text('${doisDigitos(h.hour)}:${doisDigitos(h.minute)}'),
                  onTap: () async {
                    final t = await showTimePicker(context: ctx, initialTime: h);
                    if (t != null) setLocal(() => h = t);
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: duracao,
                  decoration: const InputDecoration(
                    labelText: 'Duração',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 min')),
                    DropdownMenuItem(value: 45, child: Text('45 min')),
                    DropdownMenuItem(value: 60, child: Text('1 h')),
                    DropdownMenuItem(value: 90, child: Text('1 h 30')),
                    DropdownMenuItem(value: 120, child: Text('2 h')),
                  ],
                  onChanged: (v) => setLocal(() => duracao = v ?? duracao),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: obsCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Cliente / observação (opcional)',
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
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agendar'),
            ),
          ],
        ),
      ),
    );
    if (salvar != true) return;
    final inicio = DateTime(_dia.year, _dia.month, _dia.day, h.hour, h.minute);
    try {
      await _repo.inserir(
        agenda: 'casa_bruxa',
        titulo: escolhido.nome,
        produtoId: escolhido.id,
        descricao: obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
        inicio: inicio,
        fim: inicio.add(Duration(minutes: duracao)),
        criadoPor: authState.usuario?.nome,
      );
      await _carregar();
    } catch (e) {
      _avisar('Agendamento NÃO foi salvo: $e');
    }
  }

  Future<void> _detalhe(EventoAgenda e) async {
    final remover = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(e.titulo),
        content: Text('${formatarDia(e.inicio)}\n'
            '${formatarHora(e.inicio)} – ${formatarHora(e.fim)}'
            '${e.descricao == null ? '' : '\n${e.descricao}'}'
            '${e.criadoPor == null ? '' : '\nAgendado por: ${e.criadoPor}'}\n\n'
            '${_edita ? '\n\nDica: segure e arraste para mudar o horário.' : ''}'),
        actions: [
          if (_edita)
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remover'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
    if (remover != true) return;
    try {
      await _repo.remover(e.id);
      await _carregar();
    } catch (err) {
      _avisar('Não foi possível remover: $err');
    }
  }

  Future<void> _mover(EventoAgenda e, int hora) async {
    final dur = e.fim.difference(e.inicio);
    // Mantém os minutos (14:30 arrastado para as 15h vira 15:30).
    final novoInicio =
        DateTime(_dia.year, _dia.month, _dia.day, hora, e.inicio.minute);
    if (novoInicio == e.inicio) return;
    final antesI = e.inicio, antesF = e.fim;
    setState(() {
      e.inicio = novoInicio;
      e.fim = novoInicio.add(dur);
    });
    try {
      await _repo.atualizarHorario(e.id, e.inicio, e.fim);
    } catch (err) {
      setState(() {
        e.inicio = antesI;
        e.fim = antesF;
      });
      _avisar('Não foi possível reagendar: $err');
    }
  }

  /// Agendamento já terminado fica translúcido (como na agenda do Google).
  Widget _cartao(EventoAgenda e, {double? largura}) {
    final cor = _visual.cor(_chave(e));
    final passado = e.fim.isBefore(DateTime.now());
    return Opacity(
      opacity: passado ? 0.45 : 1,
      child: Card(
        color: cor.withValues(alpha: 0.22),
        margin: const EdgeInsets.symmetric(vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cor.withValues(alpha: 0.7)),
        ),
        child: SizedBox(
          width: largura,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(_visual.icone(_chave(e)), color: cor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.titulo,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${formatarHora(e.inicio)} – ${formatarHora(e.fim)}'
                          '${e.descricao == null ? '' : ' • ${e.descricao}'}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Linha vermelha do "agora", dentro da linha da hora atual.
  Widget _linhaAgora(DateTime agora) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment(-1, -1 + 2 * agora.minute / 60),
          child: Row(
            children: [
              const SizedBox(width: 48),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                    color: Color(0xFFE53935), shape: BoxShape.circle),
              ),
              Expanded(child: Container(height: 2, color: const Color(0xFFE53935))),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _linhasDeHora(List<EventoAgenda> doDia, bool ehHoje) {
    final agora = DateTime.now();
    int horaDe(EventoAgenda e) => e.inicio.hour.clamp(_primeiraHora, _ultimaHora);
    return [
      for (var h = _primeiraHora; h <= _ultimaHora; h++)
        DragTarget<EventoAgenda>(
          onAcceptWithDetails: (d) => _mover(d.data, h),
          builder: (ctx, candidatos, _) {
            final eventosHora = doDia.where((e) => horaDe(e) == h).toList();
            return InkWell(
              onTap: eventosHora.isEmpty && _edita ? () => _novo(h) : null,
              child: Container(
                constraints: const BoxConstraints(minHeight: _alturaHora),
                decoration: BoxDecoration(
                  color: candidatos.isNotEmpty
                      ? Theme.of(ctx).colorScheme.secondaryContainer
                      : null,
                  border: Border(
                    top: BorderSide(color: Theme.of(ctx).dividerColor),
                  ),
                ),
                child: Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 56,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12, top: 8),
                            child: Text('${doisDigitos(h)}:00'),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final e in eventosHora)
                                  !_edita
                                      ? GestureDetector(
                                          onTap: () => _detalhe(e),
                                          child: _cartao(e),
                                        )
                                      : LongPressDraggable<EventoAgenda>(
                                    data: e,
                                    onDragStarted: () => _arrastando = true,
                                    onDragEnd: (_) => _arrastando = false,
                                    feedback: Material(
                                      color: Colors.transparent,
                                      elevation: 6,
                                      child: _cartao(e, largura: 260),
                                    ),
                                    childWhenDragging: Opacity(
                                      opacity: 0.3,
                                      child: _cartao(e),
                                    ),
                                    child: GestureDetector(
                                      onTap: () => _detalhe(e),
                                      child: _cartao(e),
                                    ),
                                  ),
                                if (eventosHora.isNotEmpty && _edita)
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton.icon(
                                      onPressed: () => _novo(h),
                                      icon: const Icon(Icons.add, size: 16),
                                      label: const Text('Agendar'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ehHoje && agora.hour == h) _linhaAgora(agora),
                  ],
                ),
              ),
            );
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final doDia = _eventos.where((e) => e.ocorreEm(_dia)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    final hoje = DateTime.now();
    final ehHoje = _dia.year == hoje.year && _dia.month == hoje.month && _dia.day == hoje.day;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Casa da Bruxa'),
        actions: [
          if (permissoes.pode('agenda_config'))
          IconButton(
            tooltip: 'Configurações da agenda',
            icon: const Icon(Icons.more_vert),
            onPressed: _configuracoes,
          ),
        ],
      ),
      body: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _irPara(_dia.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => _irPara(DateTime.now()),
                  child: Center(
                    child: Text(
                      '${kDiasSemana[_dia.weekday % 7]}, ${formatarDia(_dia)}'
                      '${ehHoje ? ' (hoje)' : ''}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _irPara(_dia.add(const Duration(days: 1))),
              ),
            ],
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, box) => ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                children: [
                  // Quadro dos horários: ~60% da área, com rolagem própria.
                  SizedBox(
                    height: box.maxHeight * 0.6,
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView(
                        controller: _rolagem,
                        padding: EdgeInsets.zero,
                        children: _linhasDeHora(doDia, ehHoje),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: CalendarioMes(
                        mes: _mes,
                        eventos: _eventos,
                        selecionado: _dia,
                        proporcao: 0.9,
                        onMes: (m) => setState(() => _mes = m),
                        onDia: _abrirDia,
                        marcas: (ctx, lista) =>
                            marcasAgenda(ctx, lista, _visual, _chave),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
