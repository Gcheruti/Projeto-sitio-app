import 'package:flutter/material.dart';

import '../models/notificacao.dart';
import '../state/app_state.dart';
import '../state/permissoes_state.dart';
import 'agenda_screen.dart';

/// Posição de cada local no mapa (fração da largura/altura da imagem).
/// Ao trocar a imagem do mapa, ajuste só estes valores.
const Map<String, Offset> kPosicoesMapa = {
  'casa_bruxa': Offset(0.46, 0.295),
  'mercado': Offset(0.84, 0.33),
  'restaurante': Offset(0.64, 0.44),
  'gruta': Offset(0.165, 0.305),
  'spa': Offset(0.57, 0.235),
  'estacionamento': Offset(0.80, 0.15),
  'espaco_ritual': Offset(0.21, 0.45),
  'apiario': Offset(0.80, 0.645),
};

/// Proporção (largura / altura) da imagem do mapa.
const double kProporcaoMapa = 1500 / 2008;

class InicioScreen extends StatelessWidget {
  const InicioScreen({
    super.key,
    required this.qtdNotificacoes,
    required this.onNotificacoesTap,
    required this.notificacoes,
    required this.onLocalTap,
  });

  final int qtdNotificacoes;
  final VoidCallback onNotificacoesTap;
  final List<Notificacao> notificacoes;

  /// Toque na bolinha de um local (chave de [kLocais]).
  final void Function(String local) onLocalTap;

  int _qtdLocal(String local) =>
      notificacoes.where((n) => n.ativa && n.local == local).length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sítio'),
        leading: !permissoes.pode('inicio_agenda')
            ? null
            : IconButton(
          tooltip: 'Agenda',
          icon: const Icon(Icons.calendar_month_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AgendaScreen()),
          ),
        ),
        actions: [
          if (permissoes.pode('inicio_notificacoes'))
          IconButton(
            tooltip: 'Notificações',
            onPressed: onNotificacoesTap,
            icon: Badge(
              isLabelVisible: qtdNotificacoes > 0,
              label: Text('$qtdNotificacoes'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            ListenableBuilder(
              listenable: appState,
              builder: (context, _) => Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: const Text('Comandas ativas'),
                  trailing: Text(
                    '${appState.qtdComandasAtivas}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
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
                          const d = 30.0; // diâmetro da bolinha
                          return Stack(
                            children: [
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/mapa_sitio.webp',
                                  fit: BoxFit.fill,
                                ),
                              ),
                              for (final e in kPosicoesMapa.entries)
                                if (_qtdLocal(e.key) > 0)
                                  Positioned(
                                    left: e.value.dx * box.maxWidth - d / 2,
                                    top: e.value.dy * box.maxHeight - d / 2,
                                    child: _Bolinha(
                                      qtd: _qtdLocal(e.key),
                                      tamanho: d,
                                      onTap: () => onLocalTap(e.key),
                                    ),
                                  ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bolinha extends StatelessWidget {
  const _Bolinha({
    required this.qtd,
    required this.tamanho,
    required this.onTap,
  });

  final int qtd;
  final double tamanho;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: tamanho,
        height: tamanho,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary,
          border: Border.all(color: scheme.surface, width: 2),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2)),
          ],
        ),
        child: Text(
          '$qtd',
          style: TextStyle(
            color: scheme.onPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
