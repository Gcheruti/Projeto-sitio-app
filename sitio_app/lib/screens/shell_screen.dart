import 'dart:async';
import 'package:flutter/material.dart';
import '../models/lote.dart';
import '../models/notificacao.dart';
import '../services/fila_offline.dart';
import '../theme/temas_mensais.dart' show ehSite;
import '../state/auth_state.dart';
import '../state/permissoes_state.dart';
import '../services/supabase_repository.dart';
import '../services/realtime_sync.dart';
import '../state/app_state.dart';
import 'ajustes_screen.dart';
import 'comandas_screen.dart';
import 'estoque_screen.dart';
import 'inicio_screen.dart';
import 'notificacoes_screen.dart';
import 'pedidos_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  static final GlobalKey<_ShellScreenState> navKey =
      GlobalKey<_ShellScreenState>();

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _aba = 0;

  /// Chaves das abas visíveis agora (muda com as permissões).
  List<String> _chavesAbas = const [];

  void irParaEstoque() {
    final i = _chavesAbas.indexOf('estoque');
    if (i >= 0) setState(() => _aba = i);
  }

  final _repo = SupabaseRepository();
  final List<Notificacao> _notificacoes = [];

  @override
  void initState() {
    super.initState();
    _carregarNotificacoes();
    RealtimeSync.instance.iniciar();
    RealtimeSync.instance.tick.addListener(_aoMudarNoServidor);
    // a cada 5 s confere se é hora de consultar: sem tempo real = toda vez;
    // com tempo real = só a cada 30 s (consulta de segurança)
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _rodada++;
      if (RealtimeSync.instance.devePuxar(_rodada)) _atualizarTudo();
    });
  }

  int _rodada = 0;

  void _aoMudarNoServidor() {
    _atualizarTudo();
  }

  Timer? _timer;
  bool _salvandoNotif = false;
  bool _jaCarregou = false;

  @override
  void dispose() {
    _timer?.cancel();
    RealtimeSync.instance.tick.removeListener(_aoMudarNoServidor);
    RealtimeSync.instance.parar();
    super.dispose();
  }

  /// A cada 5s: recarrega estoque/comandas e notificações do Supabase.
  Future<void> _atualizarTudo() async {
    await appState.atualizarSilencioso();
    if (_salvandoNotif) return;
    try {
      final l = await _repo.fetchNotificacoes();
      if (!mounted || _salvandoNotif) return;
      final conhecidas = _notificacoes.map((n) => n.id).toSet();
      if (_jaCarregou && authState.isAdm) {
        for (final n in l) {
          if (n.somenteAdm && n.ativa && !n.excluida && !conhecidas.contains(n.id)) {
            _avisar('${n.titulo}: ${n.descricao}');
          }
        }
      }
      _jaCarregou = true;
      // Reaproveita os objetos já existentes (atualizando os campos): uma tela
      // de edição aberta continua apontando para o mesmo objeto.
      final antigos = {for (final n in _notificacoes) n.id: n};
      final nova = <Notificacao>[];
      for (final n in l) {
        final a = antigos[n.id];
        if (a == null) {
          nova.add(n);
        } else {
          a
            ..titulo = n.titulo
            ..descricao = n.descricao
            ..ativa = n.ativa
            ..local = n.local
            ..criadoPor = n.criadoPor
            ..editadoPor = n.editadoPor
            ..excluida = n.excluida
            ..somenteAdm = n.somenteAdm;
          nova.add(a);
        }
      }
      setState(() {
        _notificacoes
          ..clear()
          ..addAll(nova);
      });
    } catch (e) {
      debugPrint('Atualização de notificações falhou: $e');
    }
  }

  Future<void> _carregarNotificacoes() async {
    try {
      final l = await _repo.fetchNotificacoes();
      if (!mounted) return;
      _jaCarregou = true;
      setState(() {
        _notificacoes
          ..clear()
          ..addAll(l);
      });
    } catch (e) {
      debugPrint('Notificações não carregadas: $e');
      _avisar('Não foi possível carregar as notificações do Supabase: $e');
    }
  }

  void _avisar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 8)),
    );
  }

  Future<void> _salvarNotificacoes() async {
    _salvandoNotif = true;
    try {
      await _repo.upsertNotificacoes(_notificacoes);
    } catch (e) {
      debugPrint('Notificações não salvas: $e');
      _avisar('Notificação NÃO foi salva no Supabase: $e');
    } finally {
      _salvandoNotif = false;
    }
  }

  /// Alertas "só Adm" não aparecem para staff/freelancer.
  List<Notificacao> get _visiveis => authState.isAdm
      ? _notificacoes
      : _notificacoes.where((n) => !n.somenteAdm).toList();

  int get _qtdAtivas => _visiveis.where((n) => n.ativa).length;

  /// Avisa, por local, itens em estoque que vencem dentro do prazo do próprio item (ou já venceram).
  void _garantirAvisoValidade() {
    var mudou = false;
    const mapa = {'Salão': 'restaurante', 'Loja': 'mercado', 'Tarô': 'casa_bruxa', 'Gruta': 'gruta'};
    for (final e in mapa.entries) {
      final id = 'validade_${e.key}';
      final partes = <String>[];
      for (final p in appState.produtos.where((p) => p.ambiente == e.key)) {
        for (final x in appState.lotesEmEstoque(p)) {
          if (x.lote.diasRestantes <= p.diasAvisoValidade) {
            partes.add('${p.nome} (${x.restante} un.) '
                '${x.lote.diasRestantes < 0 ? 'VENCIDO' : 'vence'} '
                '${formatarData(x.lote.validade)}');
          }
        }
      }
      final texto = partes.join(' | ');
      final idx = _notificacoes.indexWhere((n) => n.id == id);
      if (texto.isEmpty) {
        if (idx >= 0 && _notificacoes[idx].ativa) {
          _notificacoes[idx].ativa = false;
          mudou = true;
        }
        continue;
      }
      if (idx >= 0 && _notificacoes[idx].descricao == texto) continue;
      mudou = true;
      final nova = Notificacao(
        id: id,
        titulo: 'Validade próxima',
        descricao: texto,
        local: e.value,
      );
      if (idx >= 0) {
        _notificacoes[idx] = nova;
      } else {
        _notificacoes.insert(0, nova);
      }
    }
    if (mudou) _salvarNotificacoes();
  }

  void _garantirAvisoEstoqueBaixo() {
    _garantirAvisoValidade();
    // ambiente do estoque -> local do mapa
    var mudou = false;
    const mapa = {'Salão': 'restaurante', 'Loja': 'mercado', 'Tarô': 'casa_bruxa', 'Gruta': 'gruta'};
    for (final e in mapa.entries) {
      final id = 'estoque_baixo_${e.key}';
      final texto = appState.produtosEstoqueBaixo
          .where((p) => p.ambiente == e.key)
          .map((p) => '${p.nome}: ${p.quantidade}')
          .join(' | ');
      final idx = _notificacoes.indexWhere((n) => n.id == id);
      if (texto.isEmpty) {
        if (idx >= 0 && _notificacoes[idx].ativa) {
          _notificacoes[idx].ativa = false;
          mudou = true;
        }
        continue;
      }
      // mesmo texto = não reativa um aviso que a equipe já dispensou
      if (idx >= 0 && _notificacoes[idx].descricao == texto) continue;
      mudou = true;
      final nova = Notificacao(
        id: id,
        titulo: 'Estoque baixo',
        descricao: texto,
        local: e.value,
      );
      if (idx >= 0) {
        _notificacoes[idx] = nova;
      } else {
        _notificacoes.insert(0, nova);
      }
    }
    if (mudou) _salvarNotificacoes();
  }

  /// [local] = chave de kLocais (só daquele lugar) ou null (todas).
  void _abrirResumoNotificacoes([String? local]) {
    _garantirAvisoEstoqueBaixo();
    final ativas = _visiveis
        .where((n) => n.ativa && (local == null || n.local == local))
        .toList();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  local == null
                      ? 'Notificações'
                      : 'Notificações • ${kLocais[local]}',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (ativas.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('Nenhuma notificação ativa'),
                  )
                else
                  ...ativas.map(
                    (n) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(n.titulo),
                      dense: true,
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _abrirTelaNotificacoes();
                  },
                  child: const Text('Ver todas'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Abre direto a tela de notificações (ativas/inativas, por local, criar e editar).
  void _abrirTelaNotificacoes() {
    final lista = _visiveis;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificacoesScreen(
          notificacoes: lista,
          onChanged: () {
            // lista filtrada (staff): leva as novas para a lista completa
            for (final n in lista) {
              if (!_notificacoes.any((x) => x.id == n.id)) {
                _notificacoes.insert(0, n);
              }
            }
            setState(() {});
            _salvarNotificacoes();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _garantirAvisoEstoqueBaixo();

    return ListenableBuilder(
      listenable: permissoes,
      builder: (context, _) {
        final abas = <_AbaShell>[
          if (permissoes.pode('aba_inicio'))
            _AbaShell(
              'inicio',
              InicioScreen(
                qtdNotificacoes: _qtdAtivas,
                onNotificacoesTap: _abrirTelaNotificacoes,
                notificacoes: _visiveis,
                onLocalTap: (l) {
                  if (permissoes.pode('inicio_notificacoes')) {
                    _abrirResumoNotificacoes(l);
                  }
                },
              ),
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map),
                label: 'Início',
              ),
            ),
          if (permissoes.pode('aba_comandas'))
            const _AbaShell(
              'comandas',
              ComandasScreen(),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Comandas',
              ),
            ),
          if (permissoes.pode('aba_pedidos'))
            const _AbaShell(
              'pedidos',
              PedidosScreen(),
              NavigationDestination(
                icon: Icon(Icons.local_fire_department_outlined),
                selectedIcon: Icon(Icons.local_fire_department),
                label: 'Pedidos',
              ),
            ),
          if (permissoes.pode('aba_estoque'))
            const _AbaShell(
              'estoque',
              EstoqueScreen(),
              NavigationDestination(
                icon: Icon(Icons.science_outlined),
                selectedIcon: Icon(Icons.science),
                label: 'Estoque',
              ),
            ),
          // Ajustes fica sempre disponível (é onde está o "Sair").
          const _AbaShell(
            'ajustes',
            AjustesScreen(),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome),
              label: 'Ajustes',
            ),
          ),
        ];
        _chavesAbas = [for (final a in abas) a.chave];
        if (_aba >= abas.length) _aba = abas.length - 1;

        // Tela larga (computador/navegador): menu lateral em vez da barra
        // de baixo. As abas e a ordem são as mesmas.
        final larga = MediaQuery.of(context).size.width >= 800;
        if (larga && ehSite) {
          // Navegador/computador: cabeçalho de site com menu horizontal.
          return Scaffold(
            body: Column(
              children: [
                _CabecalhoSite(
                  abas: abas,
                  selecionada: _aba,
                  onSelecionar: (i) => setState(() => _aba = i),
                  qtdAvisos: _qtdAtivas,
                  onAvisos: permissoes.pode('inicio_notificacoes')
                      ? _abrirTelaNotificacoes
                      : null,
                ),
                Expanded(child: abas[_aba].tela),
                const _FaixaOffline(),
              ],
            ),
          );
        }
        if (larga && abas.length >= 2) {
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _aba,
                  onDestinationSelected: (i) => setState(() => _aba = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final a in abas)
                      NavigationRailDestination(
                        icon: a.destino.icon,
                        selectedIcon: a.destino.selectedIcon,
                        label: Text(a.destino.label),
                      ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: abas[_aba].tela),
                      const _FaixaOffline(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return Scaffold(
          body: abas[_aba].tela,
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _FaixaOffline(),
              if (abas.length >= 2)
                NavigationBar(
                  selectedIndex: _aba,
                  onDestinationSelected: (i) => setState(() => _aba = i),
                  destinations: [for (final a in abas) a.destino],
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Cabeçalho para navegador/computador: marca à esquerda, menu horizontal
/// com sublinhado na página atual, usuário e avisos à direita.
class _CabecalhoSite extends StatelessWidget {
  const _CabecalhoSite({
    required this.abas,
    required this.selecionada,
    required this.onSelecionar,
    required this.qtdAvisos,
    this.onAvisos,
  });
  final List<_AbaShell> abas;
  final int selecionada;
  final ValueChanged<int> onSelecionar;
  final int qtdAvisos;
  final VoidCallback? onAvisos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final u = authState.usuario;
    return Material(
      color: Theme.of(context).appBarTheme.backgroundColor ?? cs.surface,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: cs.primary, size: 22),
            const SizedBox(width: 8),
            Text('Sítio',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 1)),
            const SizedBox(width: 32),
            for (var i = 0; i < abas.length; i++)
              _ItemMenuSite(
                rotulo: abas[i].destino.label,
                icone: i == selecionada
                    ? (abas[i].destino.selectedIcon ?? abas[i].destino.icon)
                    : abas[i].destino.icon,
                ativo: i == selecionada,
                onTap: () => onSelecionar(i),
              ),
            const Spacer(),
            if (onAvisos != null)
              IconButton(
                tooltip: 'Notificações',
                onPressed: onAvisos,
                icon: Badge(
                  isLabelVisible: qtdAvisos > 0,
                  label: Text('$qtdAvisos'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              ),
            if (u != null) ...[
              const SizedBox(width: 8),
              Text(u.nome, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemMenuSite extends StatelessWidget {
  const _ItemMenuSite({
    required this.rotulo,
    required this.icone,
    required this.ativo,
    required this.onTap,
  });
  final String rotulo;
  final Widget icone;
  final bool ativo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      hoverColor: cs.primary.withValues(alpha: 0.08),
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: ativo ? cs.primary : Colors.transparent, width: 3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconTheme(
              data: IconThemeData(
                  size: 20, color: ativo ? cs.primary : cs.onSurfaceVariant),
              child: icone,
            ),
            const SizedBox(width: 6),
            Text(
              rotulo,
              style: TextStyle(
                fontWeight: ativo ? FontWeight.bold : FontWeight.normal,
                color: ativo ? cs.primary : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AbaShell {
  const _AbaShell(this.chave, this.tela, this.destino);
  final String chave;
  final Widget tela;
  final NavigationDestination destino;
}

/// Faixa discreta: mudanças guardadas esperando a rede, ou envio recusado.
class _FaixaOffline extends StatelessWidget {
  const _FaixaOffline();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: filaOffline,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        if (filaOffline.avisos.isNotEmpty) {
          return Material(
            color: scheme.errorContainer,
            child: ListTile(
              dense: true,
              leading: Icon(Icons.error_outline, color: scheme.error),
              title: Text(filaOffline.avisos.join('\n')),
              trailing: TextButton(
                onPressed: filaOffline.limparAvisos,
                child: const Text('OK'),
              ),
            ),
          );
        }
        if (filaOffline.pendentes == 0) return const SizedBox.shrink();
        final n = filaOffline.pendentes;
        return Material(
          color: scheme.tertiaryContainer,
          child: ListTile(
            dense: true,
            leading: const Icon(Icons.cloud_off),
            title: Text('Sem conexão: $n alteraç${n == 1 ? 'ão guardada' : 'ões guardadas'} '
                'neste aparelho. Envio automático quando a rede voltar.'),
          ),
        );
      },
    );
  }
}
