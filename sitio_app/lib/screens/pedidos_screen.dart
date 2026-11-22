import 'package:flutter/material.dart';
import '../widgets/borda_papel.dart' show papelCom;

import '../models/comanda.dart';
import '../state/app_state.dart';
import '../state/permissoes_state.dart';
import '../theme/temas_mensais.dart' show temaState;

const _etapas = <String, String>{
  'aberto': 'Pedido aberto',
  'preparo': 'Em preparo',
  'finalizado': 'Finalizado',
};

Color _corEtapa(BuildContext context, String? s) {
  final c = Theme.of(context).colorScheme;
  switch (s) {
    case 'preparo':
      return c.tertiary;
    case 'finalizado':
      return c.primary;
    default:
      return c.error;
  }
}

/// Acompanhamento do preparo: um card por comanda com itens processuais.
/// Visível para todos os usuários.
class PedidosScreen extends StatefulWidget {
  const PedidosScreen({super.key, this.leading});

  /// Widget opcional no canto esquerdo da barra (ex.: engrenagem da cozinha).
  final Widget? leading;

  @override
  State<PedidosScreen> createState() => _PedidosScreenState();
}

class _PedidosScreenState extends State<PedidosScreen> {
  bool _comFinalizados = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final comandas = appState.comandas.where((c) {
          if (!c.isAtiva) return false;
          return _comFinalizados
              ? c.itensProcessuais.isNotEmpty
              : c.itensEmAndamento.isNotEmpty;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            leading: widget.leading,
            title: Text(widget.leading == null ? 'Pedidos' : 'Pedidos em processo'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('Incluir finalizados'),
                    selected: _comFinalizados,
                    onSelected: (v) => setState(() => _comFinalizados = v),
                  ),
                ),
              ),
              Expanded(
                child: comandas.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Nenhum pedido em andamento.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: comandas.length,
                        itemBuilder: (_, i) => _CardComanda(
                          comanda: comandas[i],
                          comFinalizados: _comFinalizados,
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CardComanda extends StatelessWidget {
  const _CardComanda({required this.comanda, required this.comFinalizados});

  final Comanda comanda;
  final bool comFinalizados;

  @override
  Widget build(BuildContext context) {
    final papel = temaState.cartoesPapel;
    final itens =
        comFinalizados ? comanda.itensProcessuais : comanda.itensEmAndamento;
    final cartao = Card(
      shape: papelCom(context, comanda.id),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDetalhe(context, comanda.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Comanda ${comanda.codigo}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: papel ? 14 : 0),
                    child: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...itens.map(
                (i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text('${i.quantidade}x ${i.nome}')),
                      _ChipEtapa(status: i.statusPreparo),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!papel) return cartao;
    // Folhas presas de leve, cada uma um pouquinho torta.
    final graus = ((comanda.codigo.hashCode % 9) - 4) * 0.0045;
    return Transform.rotate(angle: graus, child: cartao);
  }
}

class _ChipEtapa extends StatelessWidget {
  const _ChipEtapa({required this.status});
  final String? status;

  @override
  Widget build(BuildContext context) {
    final cor = _corEtapa(context, status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _etapas[status] ?? _etapas['aberto']!,
        style: TextStyle(fontSize: 12, color: cor),
      ),
    );
  }
}

void _abrirDetalhe(BuildContext context, String comandaId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _DetalhePedidos(comandaId: comandaId),
  );
}

/// Folha da comanda: muda a etapa de cada item (aberto / em preparo / finalizado).
class _DetalhePedidos extends StatelessWidget {
  const _DetalhePedidos({required this.comandaId});
  final String comandaId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final c = appState.comandaPorId(comandaId);
        final itens = c?.itensProcessuais ?? const <ItemComanda>[];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Comanda ${c?.codigo ?? ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (itens.isEmpty) const Text('Sem itens para preparo.'),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final i in itens)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${i.quantidade}x ${i.nome}',
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                showSelectedIcon: false,
                                segments: const [
                                  ButtonSegment(
                                      value: 'aberto', label: Text('Aberto')),
                                  ButtonSegment(
                                      value: 'preparo',
                                      label: Text('Em preparo')),
                                  ButtonSegment(
                                      value: 'finalizado',
                                      label: Text('Finalizado')),
                                ],
                                selected: {i.statusPreparo ?? 'aberto'},
                                onSelectionChanged: !permissoes.pode('pedidos_status')
                                    ? null
                                    : (s) async {
                                  final ok =
                                      await appState.alterarStatusPreparo(
                                    comandaId,
                                    i.produtoId,
                                    s.first,
                                  );
                                  if (!ok && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(appState.ultimoErro ??
                                            'Não foi possível atualizar.'),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
