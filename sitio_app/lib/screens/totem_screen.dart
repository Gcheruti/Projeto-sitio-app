import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/agenda_visual.dart';
import '../models/comanda.dart';
import '../models/evento_agenda.dart';
import '../models/notificacao.dart';
import '../models/produto.dart';
import '../services/agenda_config_repository.dart';
import '../services/agenda_repository.dart';
import '../services/avisos_admin.dart';
import '../services/realtime_sync.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../widgets/agenda_marcas.dart';
import '../widgets/calendario_mes.dart';
import 'inicio_screen.dart' show kPosicoesMapa, kProporcaoMapa;
import 'tema_sheet.dart';

// ---------------------------------------------------------------------------
// Infra do totem: tags NFC, dados do dia e aviso de inatividade
// ---------------------------------------------------------------------------

/// Pilha de ouvintes de tag NFC: quem está na frente da tela recebe a leitura.
class TotemTags {
  TotemTags._();
  static final List<void Function(String)> _pilha = [];

  static void entrar(void Function(String) f) => _pilha.add(f);
  static void sair(void Function(String) f) => _pilha.remove(f);
  static void disparar(String codigo) {
    if (_pilha.isNotEmpty) _pilha.last(codigo);
  }
}

/// Eventos de hoje, atualizados a cada 5 s pelo totem.
class TotemDados {
  TotemDados._();
  static final ValueNotifier<List<EventoAgenda>> eventos = ValueNotifier([]);
  static final AgendaRepository _repo = AgendaRepository();

  static Future<void> recarregar() async {
    try {
      // O totem só mostra o que é voltado ao público.
      eventos.value =
          (await _repo.doDia(DateTime.now())).where((e) => e.publico).toList();
    } catch (e) {
      debugPrint('Eventos do dia não carregados: $e');
    }
  }

  static List<EventoAgenda> doLocal(String local) => eventos.value
      .where((e) => e.local == local || (local == 'casa_bruxa' && e.agenda == 'casa_bruxa'))
      .toList()
    ..sort((a, b) => a.inicio.compareTo(b.inicio));
}

/// Avisa o mapa de que a volta foi por inatividade.
final ValueNotifier<int> totemInatividade = ValueNotifier(0);

const Map<String, Color> _corLocal = {
  'restaurante': Colors.orange,
  'mercado': Colors.purple,
  'casa_bruxa': Colors.teal,
  'gruta': Colors.brown,
  'spa': Colors.pink,
  'estacionamento': Colors.blueGrey,
  'espaco_ritual': Colors.deepPurple,
  'apiario': Colors.amber,
};

const Map<String, String> _ambienteDoLocal = {
  'restaurante': 'Salão',
  'mercado': 'Loja',
  'casa_bruxa': 'Tarô',
  'gruta': 'Gruta',
};

String _reais(double v) => 'R\$ ${v.toStringAsFixed(2)}';

/// Volta ao mapa depois de [segundos] sem toque/rolagem na tela.
class InatividadeGuard extends StatefulWidget {
  const InatividadeGuard({super.key, required this.segundos, required this.child});

  final int segundos;
  final Widget child;

  @override
  State<InatividadeGuard> createState() => _InatividadeGuardState();
}

class _InatividadeGuardState extends State<InatividadeGuard> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _reiniciar();
  }

  void _reiniciar() {
    _t?.cancel();
    _t = Timer(Duration(seconds: widget.segundos), () {
      if (!mounted) return;
      totemInatividade.value++;
      Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reiniciar(),
      onPointerMove: (_) => _reiniciar(),
      onPointerSignal: (_) => _reiniciar(),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Mapa (tela inicial do totem)
// ---------------------------------------------------------------------------

class TotemShell extends StatefulWidget {
  const TotemShell({super.key});

  @override
  State<TotemShell> createState() => _TotemShellState();
}

class _TotemShellState extends State<TotemShell> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    TotemTags.entrar(_aoLerTag);
    totemInatividade.addListener(_avisarInatividade);
    TotemDados.recarregar();
    RealtimeSync.instance.iniciar();
    RealtimeSync.instance.tick.addListener(_recarregarTudo);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _rodada++;
      if (RealtimeSync.instance.devePuxar(_rodada)) _recarregarTudo();
    });
  }

  int _rodada = 0;

  void _recarregarTudo() {
    TotemDados.recarregar();
    appState.atualizarSilencioso();
  }

  @override
  void dispose() {
    _timer?.cancel();
    RealtimeSync.instance.tick.removeListener(_recarregarTudo);
    RealtimeSync.instance.parar();
    TotemTags.sair(_aoLerTag);
    totemInatividade.removeListener(_avisarInatividade);
    super.dispose();
  }

  void _avisarInatividade() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(
        duration: Duration(seconds: 10),
        content: Text(
          'As brumas se fecharam sobre a tela: ninguém a tocou por um tempo, '
          'e o mapa do Sítio voltou a se mostrar. Toque num local ou aproxime '
          'sua tag para continuar a jornada.',
        ),
      ));
  }

  Future<void> _aoLerTag(String codigo) async {
    await appState.atualizarSilencioso();
    if (!mounted) return;
    final c = appState.buscarComandaPorCodigo(codigo);
    if (c == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comanda não encontrada: $codigo')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TotemComandaScreen(comandaId: c.id)),
    );
  }

  Future<void> _digitarCodigo() async {
    final c = await pedirCodigoManual(context);
    if (c != null) _aoLerTag(c);
  }

  Future<void> _sair() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair do modo totem'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          keyboardType: TextInputType.visiblePassword,
          decoration: const InputDecoration(labelText: 'Senha do login do totem', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              final ok = await authState.senhaConfere(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx, ok);
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok == true) await authState.sair();
  }

  void _abrirAjustes() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Tema do aplicativo'),
              onTap: () {
                Navigator.pop(ctx);
                abrirEscolhaDeTema(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair (logout)'),
              subtitle: const Text('Pede a senha'),
              onTap: () {
                Navigator.pop(ctx);
                _sair();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirLocal(String local) {
    showDialog<void>(
      context: context,
      builder: (_) => _LocalDialog(local: local),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Ajustes',
          icon: const Icon(Icons.settings_outlined),
          onPressed: _abrirAjustes,
        ),
        title: GestureDetector(
          onLongPress: _sair,
          child: const Text('Sítio'),
        ),
        actions: [
          IconButton(
            tooltip: 'Digitar código da comanda',
            icon: const Icon(Icons.keyboard_alt_outlined),
            onPressed: _digitarCodigo,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            icon: const Icon(Icons.event_note),
            label: const Text('Eventos do dia'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TotemEventosDiaScreen()),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Center(
          child: AspectRatio(
            aspectRatio: kProporcaoMapa,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline),
                borderRadius: BorderRadius.circular(6),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LayoutBuilder(
                  builder: (context, box) {
                    const d = 38.0;
                    return ValueListenableBuilder<List<EventoAgenda>>(
                      valueListenable: TotemDados.eventos,
                      builder: (context, _, __) => Stack(
                        children: [
                          Positioned.fill(
                            child: Image.asset('assets/images/mapa_sitio.webp', fit: BoxFit.fill),
                          ),
                          for (final e in kPosicoesMapa.entries)
                            Positioned(
                              left: e.value.dx * box.maxWidth - d / 2,
                              top: e.value.dy * box.maxHeight - d / 2,
                              child: GestureDetector(
                                onTap: () => _abrirLocal(e.key),
                                child: Tooltip(
                                  message: kLocais[e.key] ?? e.key,
                                  child: Container(
                                    width: d,
                                    height: d,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _corLocal[e.key] ?? scheme.primary,
                                      border: Border.all(color: Colors.white, width: 2),
                                      boxShadow: const [
                                        BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
                                      ],
                                    ),
                                    child: Text(
                                      '${TotemDados.doLocal(e.key).length}',
                                      style: const TextStyle(
                                          color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> pedirCodigoManual(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Código da comanda'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Abrir'),
        ),
      ],
    ),
  ).then((v) => (v == null || v.isEmpty) ? null : v);
}

// ---------------------------------------------------------------------------
// Pop-up de um local: eventos do dia, presença e agendamento
// ---------------------------------------------------------------------------

class _LocalDialog extends StatelessWidget {
  const _LocalDialog({required this.local});

  final String local;

  @override
  Widget build(BuildContext context) {
    return InatividadeGuard(
      segundos: 30,
      child: AlertDialog(
        title: Text('${kLocais[local] ?? local} • hoje'),
        content: SizedBox(
          width: 420,
          child: ValueListenableBuilder<List<EventoAgenda>>(
            valueListenable: TotemDados.eventos,
            builder: (context, _, __) {
              final lista = TotemDados.doLocal(local);
              if (lista.isEmpty) {
                return const Text('Nada marcado para hoje neste lugar.');
              }
              return ListView(
                shrinkWrap: true,
                children: [
                  for (final e in lista)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.agenda == 'casa_bruxa' ? 'Horário reservado' : e.titulo),
                      subtitle: Text('${formatarHora(e.inicio)} – ${formatarHora(e.fim)}'),
                      trailing: e.agenda == 'casa_bruxa'
                          ? null
                          : TextButton(
                              onPressed: () {
                                final nav = Navigator.of(context);
                                nav.pop();
                                _marcarPresenca(nav, e);
                              },
                              child: const Text('Marcar presença'),
                            ),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          if (local == 'casa_bruxa')
            FilledButton(
              onPressed: () {
                final nav = Navigator.of(context);
                nav.pop();
                nav.push(
                  MaterialPageRoute(builder: (_) => TotemAgendarScreen(local: local)),
                );
              },
              child: const Text('Agendar atendimento'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  void _marcarPresenca(NavigatorState nav, EventoAgenda e) {
    nav.push(
      MaterialPageRoute(
        builder: (_) => TotemTagScreen(
          titulo: e.titulo,
          instrucao: 'Aproxime a tag NFC para marcar sua presença em "${e.titulo}".',
          aoLer: (c) async {
            if (e.produtoId != null) {
              final p = appState.produtoPorId(e.produtoId!);
              if (p != null) {
                final ok = await appState.adicionarServicoNaComanda(c.id, p);
                if (!ok) return appState.ultimoErro ?? 'Não foi possível somar na comanda';
              }
            }
            await _registrarAviso(c.codigo,
                'Presença marcada: ${e.titulo} (${formatarHora(e.inicio)}) — totem');
            AvisosAdmin.notificar('Presença marcada no totem',
                '${e.titulo} • comanda ${c.codigo}');
            return null;
          },
        ),
      ),
    );
  }
}

Future<void> _registrarAviso(String codigo, String texto) async {
  try {
    await Supabase.instance.client.from('comanda_avisos').insert({
      'comanda_codigo': codigo,
      'texto': texto,
      'criado_por': 'Totem',
    });
  } catch (e) {
    debugPrint('Aviso da comanda não gravado: $e');
  }
}

// ---------------------------------------------------------------------------
// Eventos do dia (lista)
// ---------------------------------------------------------------------------

/// Cor e ícone de cada evento no totem (mesma configuração da agenda da equipe).
class _VisualTotem extends AgendaVisualResolver {
  _VisualTotem() : super(const {});
  final _geral = AgendaVisualResolver(kIconesAgendaGeral, padroes: kPadroesAgendaGeral);
  final _bruxa = AgendaVisualResolver(kIconesBruxa);

  static String chave(EventoAgenda e) => e.agenda == 'casa_bruxa'
      ? 'c|${e.produtoId ?? e.titulo}'
      : 'g|${e.tipo ?? 'Outro'}';

  Future<void> carregar() async {
    final repo = AgendaConfigRepository();
    final g = await repo.carregar('geral');
    final b = await repo.carregar('casa_bruxa');
    _geral.config..clear()..addAll(g);
    _bruxa.config..clear()..addAll(b);
  }

  AgendaVisualResolver _de(String k) => k.startsWith('c|') ? _bruxa : _geral;
  @override
  Color cor(String k) => _de(k).cor(k.substring(2));
  @override
  IconData icone(String k) => _de(k).icone(k.substring(2));
}

const int _horaIni = 9;
const int _horaFim = 21;

class TotemEventosDiaScreen extends StatefulWidget {
  const TotemEventosDiaScreen({super.key});

  @override
  State<TotemEventosDiaScreen> createState() => _TotemEventosDiaScreenState();
}

class _TotemEventosDiaScreenState extends State<TotemEventosDiaScreen> {
  final _visual = _VisualTotem();

  @override
  void initState() {
    super.initState();
    _visual.carregar().then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _cartao(EventoAgenda e) {
    final k = _VisualTotem.chave(e);
    final cor = _visual.cor(k);
    final passado = e.fim.isBefore(DateTime.now());
    return Opacity(
      opacity: passado ? 0.45 : 1,
      child: Card(
        color: cor.withValues(alpha: 0.22),
        margin: const EdgeInsets.all(2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: cor.withValues(alpha: 0.7)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(_visual.icone(k), color: cor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(e.agenda == 'casa_bruxa' ? 'Horário reservado' : e.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${formatarHora(e.inicio)} – ${formatarHora(e.fim)}'
                        '${(e.local ?? (e.agenda == 'casa_bruxa' ? 'casa_bruxa' : null)) == null ? '' : ' • ${kLocais[e.local ?? 'casa_bruxa'] ?? ''}'}',
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InatividadeGuard(
      segundos: 30,
      child: Scaffold(
        appBar: AppBar(title: const Text('Eventos do dia')),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.calendar_month),
              label: const Text('Agenda mensal'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TotemAgendaMensalScreen()),
              ),
            ),
          ),
        ),
        body: ValueListenableBuilder<List<EventoAgenda>>(
          valueListenable: TotemDados.eventos,
          builder: (context, lista, _) {
            // Antes das 9h cai na linha das 9h; depois das 21h, na das 21h.
            int linha(EventoAgenda e) => e.inicio.hour.clamp(_horaIni, _horaFim);
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (lista.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text('Nenhum evento marcado para hoje.'),
                  ),
                for (var h = _horaIni; h <= _horaFim; h++)
                  Builder(builder: (context) {
                    final naHora = lista.where((e) => linha(e) == h).toList()
                      ..sort((a, b) => a.inicio.compareTo(b.inicio));
                    return Container(
                      constraints: const BoxConstraints(minHeight: 60),
                      decoration: BoxDecoration(
                        border: Border(
                            top: BorderSide(color: scheme.outlineVariant)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 52,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('${doisDigitos(h)}:00',
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                          Expanded(
                            child: naHora.isEmpty
                                ? const SizedBox(height: 56)
                                : IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        for (final e in naHora)
                                          Expanded(child: _cartao(e)),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Agenda mensal (somente eventos públicos)
// ---------------------------------------------------------------------------

class TotemAgendaMensalScreen extends StatefulWidget {
  const TotemAgendaMensalScreen({super.key});

  @override
  State<TotemAgendaMensalScreen> createState() => _TotemAgendaMensalScreenState();
}

class _TotemAgendaMensalScreenState extends State<TotemAgendaMensalScreen> {
  final _repo = AgendaRepository();
  final _visual = _VisualTotem();
  List<EventoAgenda> _eventos = [];
  DateTime _mes = DateTime(DateTime.now().year, DateTime.now().month, 1);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _visual.carregar().then((_) {
      if (mounted) setState(() {});
    });
    _carregar();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _carregar());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final g = await _repo.buscar('geral');
      final b = await _repo.buscar('casa_bruxa');
      if (!mounted) return;
      setState(() => _eventos = [...g, ...b].where((e) => e.publico).toList());
    } catch (e) {
      debugPrint('Agenda mensal não carregada: $e');
    }
  }

  void _abrirDia(DateTime dia) {
    final lista = _eventos.where((e) => e.ocorreEm(dia)).toList()
      ..sort((a, b) => a.inicio.compareTo(b.inicio));
    showDialog(
      context: context,
      builder: (ctx) => InatividadeGuard(
        segundos: 30,
        child: AlertDialog(
          title: Text(formatarDia(dia)),
          content: SizedBox(
            width: 420,
            child: lista.isEmpty
                ? const Text('Nada marcado neste dia.')
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final e in lista)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: _visual
                                .cor(_VisualTotem.chave(e))
                                .withValues(alpha: 0.2),
                            child: Icon(_visual.icone(_VisualTotem.chave(e)),
                                color: _visual.cor(_VisualTotem.chave(e))),
                          ),
                          title: Text(
                              e.agenda == 'casa_bruxa' ? 'Horário reservado' : e.titulo),
                          subtitle: Text(
                              '${formatarHora(e.inicio)} – ${formatarHora(e.fim)}'),
                        ),
                    ],
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fechar')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InatividadeGuard(
      segundos: 30,
      child: Scaffold(
        appBar: AppBar(title: const Text('Agenda mensal')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            CalendarioMes(
              mes: _mes,
              eventos: _eventos,
              onDia: _abrirDia,
              onMes: (m) => setState(() => _mes = m),
              proporcao: 0.9,
              marcas: (ctx, lista) =>
                  marcasAgenda(ctx, lista, _visual, _VisualTotem.chave),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Visualização da comanda (somente leitura)
// ---------------------------------------------------------------------------

class TotemComandaScreen extends StatefulWidget {
  const TotemComandaScreen({super.key, required this.comandaId});

  final String comandaId;

  @override
  State<TotemComandaScreen> createState() => _TotemComandaScreenState();
}

class _TotemComandaScreenState extends State<TotemComandaScreen> {
  List<EventoAgenda> _agendamentos = [];

  @override
  void initState() {
    super.initState();
    TotemTags.entrar(_aoLerTag);
    final c = appState.comandaPorId(widget.comandaId);
    if (c != null) {
      AgendaRepository().daComanda(c.codigo).then((l) {
        if (mounted) setState(() => _agendamentos = l);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    TotemTags.sair(_aoLerTag);
    super.dispose();
  }

  void _aoLerTag(String codigo) {
    final c = appState.buscarComandaPorCodigo(codigo);
    if (c == null || c.id == widget.comandaId || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TotemComandaScreen(comandaId: c.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InatividadeGuard(
      segundos: 15,
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final c = appState.comandaPorId(widget.comandaId);
          return Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(c == null ? 'Comanda' : 'Comanda ${c.codigo}'),
              actions: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Voltar ao mapa'),
                ),
              ],
            ),
            body: c == null
                ? const Center(child: Text('Comanda não encontrada'))
                : _corpo(context, c),
          );
        },
      ),
    );
  }

  Widget _corpo(BuildContext context, Comanda c) {
    final itens = c.itens.where((i) => i.quantidade > 0).toList();
    final descontos = itens.fold<double>(0, (s, i) => s + i.desconto);
    final tema = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(c.isAtiva ? 'Comanda aberta' : 'Comanda encerrada', style: tema.titleMedium),
        const SizedBox(height: 8),
        if (itens.isEmpty) const Text('Nenhum item ainda.'),
        for (final i in itens)
          Card(
            child: ListTile(
              title: Text('${i.quantidade}x ${i.nome}'),
              subtitle: Text(
                '${_reais(i.precoUnitario)} cada'
                '${i.desconto > 0 ? ' • desconto ${_reais(i.desconto)}' : ''}',
              ),
              trailing: Text(_reais(i.subtotal), style: tema.titleMedium),
            ),
          ),
        const SizedBox(height: 8),
        if (descontos > 0) Text('Descontos aplicados: ${_reais(descontos)}'),
        const SizedBox(height: 4),
        Text('Total: ${_reais(c.total)}', style: tema.headlineSmall),
        if (_agendamentos.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Seus agendamentos', style: tema.titleMedium),
          for (final e in _agendamentos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_available),
              title: Text(e.titulo),
              subtitle: Text('${formatarDia(e.inicio)} • ${formatarHora(e.inicio)} – ${formatarHora(e.fim)}'),
            ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Agendar atendimento: item -> horário -> tag NFC
// ---------------------------------------------------------------------------

class TotemAgendarScreen extends StatefulWidget {
  const TotemAgendarScreen({super.key, required this.local});

  final String local;

  @override
  State<TotemAgendarScreen> createState() => _TotemAgendarScreenState();
}

class _TotemAgendarScreenState extends State<TotemAgendarScreen> {
  static const int _primeira = 7, _ultima = 22;
  Produto? _item;

  List<Produto> get _servicos => appState.produtos
      .where((p) =>
          p.ambiente == _ambienteDoLocal[widget.local] && p.subcategoria != 'Chás')
      .toList()
    ..sort((a, b) => a.nome.compareTo(b.nome));

  bool _livre(int h) {
    final hoje = DateTime.now();
    final ini = DateTime(hoje.year, hoje.month, hoje.day, h);
    final fim = ini.add(const Duration(hours: 1));
    if (!ini.isAfter(hoje)) return false;
    return !TotemDados.doLocal(widget.local)
        .any((e) => e.inicio.isBefore(fim) && e.fim.isAfter(ini));
  }

  void _escolherHora(int h) {
    final item = _item!;
    final hoje = DateTime.now();
    final ini = DateTime(hoje.year, hoje.month, hoje.day, h);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => TotemTagScreen(
          titulo: item.nome,
          instrucao: '${item.nome} às ${doisDigitos(h)}:00 (${_reais(item.preco)}).\n'
              'Aproxime a tag NFC para confirmar o agendamento.',
          aoLer: (c) async {
            await TotemDados.recarregar();
            // revalida: outra pessoa pode ter reservado agora há pouco
            final fim = ini.add(const Duration(hours: 1));
            final ocupado = TotemDados.doLocal(widget.local)
                .any((e) => e.inicio.isBefore(fim) && e.fim.isAfter(ini));
            if (ocupado) return 'Esse horário acabou de ser reservado. Volte e escolha outro.';
            final ok = await appState.adicionarServicoNaComanda(c.id, item);
            if (!ok) return appState.ultimoErro ?? 'Não foi possível somar na comanda';
            await AgendaRepository().inserir(
              agenda: 'casa_bruxa',
              titulo: item.nome,
              produtoId: item.id,
              inicio: ini,
              fim: fim,
              descricao: 'Comanda ${c.codigo} (totem)',
              criadoPor: 'Totem',
              local: widget.local,
              comandaCodigo: c.codigo,
            );
            await TotemDados.recarregar();
            await _registrarAviso(c.codigo,
                'Atendimento agendado: ${item.nome} às ${doisDigitos(h)}:00 — totem');
            AvisosAdmin.notificar('Atendimento agendado no totem',
                '${item.nome} às ${doisDigitos(h)}:00 • comanda ${c.codigo}');
            return null;
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InatividadeGuard(
      segundos: 30,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_item == null ? 'Escolha o atendimento' : 'Escolha o horário'),
          leading: BackButton(onPressed: () {
            if (_item != null) {
              setState(() => _item = null);
            } else {
              Navigator.of(context).pop();
            }
          }),
        ),
        body: _item == null ? _listaServicos() : _listaHorarios(),
      ),
    );
  }

  Widget _listaServicos() {
    final l = _servicos;
    if (l.isEmpty) {
      return const Center(child: Text('Nenhum atendimento disponível no momento.'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final p in l)
          Card(
            child: ListTile(
              title: Text(p.nome),
              trailing: Text(_reais(p.preco)),
              onTap: () => setState(() => _item = p),
            ),
          ),
      ],
    );
  }

  Widget _listaHorarios() {
    return ValueListenableBuilder<List<EventoAgenda>>(
      valueListenable: TotemDados.eventos,
      builder: (context, _, __) {
        final livres = [for (var h = _primeira; h <= _ultima; h++) if (_livre(h)) h];
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Horários livres hoje para ${_item!.nome}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (livres.isEmpty) const Text('Não há mais horários livres hoje.'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final h in livres)
                  ActionChip(
                    label: Text('${doisDigitos(h)}:00'),
                    onPressed: () => _escolherHora(h),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Aguardando tag NFC + mensagem final
// ---------------------------------------------------------------------------

class TotemTagScreen extends StatefulWidget {
  const TotemTagScreen({
    super.key,
    required this.titulo,
    required this.instrucao,
    required this.aoLer,
  });

  final String titulo;
  final String instrucao;

  /// Recebe a comanda lida; devolve null se deu certo ou a mensagem de erro.
  final Future<String?> Function(Comanda c) aoLer;

  @override
  State<TotemTagScreen> createState() => _TotemTagScreenState();
}

class _TotemTagScreenState extends State<TotemTagScreen> {
  String? _erro;
  bool _processando = false;

  @override
  void initState() {
    super.initState();
    TotemTags.entrar(_aoLerTag);
  }

  @override
  void dispose() {
    TotemTags.sair(_aoLerTag);
    super.dispose();
  }

  Future<void> _aoLerTag(String codigo) async {
    if (_processando) return;
    setState(() {
      _processando = true;
      _erro = null;
    });
    await appState.atualizarSilencioso();
    final c = appState.buscarComandaPorCodigo(codigo);
    String? erro;
    if (c == null) {
      erro = 'Comanda não encontrada: $codigo';
    } else if (!c.isAtiva) {
      erro = 'Esta comanda já foi encerrada. Procure um staff.';
    } else {
      erro = await widget.aoLer(c);
    }
    if (!mounted) return;
    if (erro == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const _TotemFinalScreen()),
      );
    } else {
      setState(() {
        _processando = false;
        _erro = erro;
      });
    }
  }

  Future<void> _digitar() async {
    final c = await pedirCodigoManual(context);
    if (c != null) _aoLerTag(c);
  }

  @override
  Widget build(BuildContext context) {
    return InatividadeGuard(
      segundos: 30,
      child: Scaffold(
        appBar: AppBar(title: Text(widget.titulo)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nfc, size: 96),
                const SizedBox(height: 16),
                Text(widget.instrucao,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                if (_processando) const CircularProgressIndicator(),
                if (_erro != null)
                  Text(_erro!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _processando ? null : _digitar,
                  icon: const Icon(Icons.keyboard_alt_outlined),
                  label: const Text('Digitar código da comanda'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TotemFinalScreen extends StatefulWidget {
  const _TotemFinalScreen();

  @override
  State<_TotemFinalScreen> createState() => _TotemFinalScreenState();
}

class _TotemFinalScreenState extends State<_TotemFinalScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer(const Duration(seconds: 15), _voltar);
  }

  void _voltar() {
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).popUntil((r) => r.isFirst);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 80),
              const SizedBox(height: 16),
              Text(
                'O destino foi selado e somado à sua comanda.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Procure um administrador ou um staff para mais informações.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _voltar, child: const Text('OK')),
            ],
          ),
        ),
      ),
    );
  }
}
