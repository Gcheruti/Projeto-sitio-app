import 'package:flutter/material.dart';
import '../widgets/borda_papel.dart' show papelCom;
import '../state/auth_state.dart';
import '../models/categorias.dart';
import '../models/comanda.dart';
import '../services/dispositivo_service.dart';
import '../services/nfc_service.dart';
import '../widgets/avisos_comanda_sheet.dart';
import 'fechamento_comanda_screen.dart';
import '../state/app_state.dart';
import '../state/permissoes_state.dart';

class DetalheComandaScreen extends StatelessWidget {
  const DetalheComandaScreen({super.key, required this.comandaId});

  final String comandaId;

  void _abrirSeletor(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: _SeletorProdutos(comandaId: comandaId),
        );
      },
    );
  }

  void _iniciarFechamento(BuildContext context) {
    final senhaCtrl = TextEditingController();
    var erro = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (_, setLocal) {
            return AlertDialog(
              title: const Text('Senha'),
              content: TextField(
                controller: senhaCtrl,
                obscureText: true,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: 'Sua senha (do login atual)',
                  border: const OutlineInputBorder(),
                  errorText: erro ? 'Senha incorreta' : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!await authState.senhaConfere(senhaCtrl.text)) {
                      setLocal(() => erro = true);
                      return;
                    }
                    Navigator.pop(ctx);
                    _escolherPagamento(context);
                  },
                  child: const Text('Continuar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _escolherPagamento(BuildContext context) async {
    final comanda = appState.comandaPorId(comandaId);
    if (comanda == null) return;
    final cobrado = comanda.total;
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FechamentoComandaScreen(comandaId: comandaId),
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comanda fechada — R\$ ${cobrado.toStringAsFixed(2)}')),
      );
      Navigator.of(context).pop();
    }
  }

  void _confirmarReabrir(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir comanda?'),
        content: const Text(
          'A comanda volta a ficar ativa com os itens como estão, para adicionar '
          'mais itens ou corrigir. O fechamento anterior é anulado e a venda '
          'será contada de novo quando você fechar outra vez.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await appState.reabrirComanda(comandaId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? 'Comanda reaberta com os itens'
                      : (appState.ultimoErro ?? 'Erro ao reabrir')),
                ),
              );
            },
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );
  }

  void _descontoItem(BuildContext context, ItemComanda item) {
    final ctrl = TextEditingController(
        text: item.desconto > 0 ? item.desconto.toStringAsFixed(2) : '');
    var porcento = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Desconto em ${item.nome}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Valor do item: R\$ ${item.bruto.toStringAsFixed(2)}'),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('R\$')),
                  ButtonSegment(value: true, label: Text('%')),
                ],
                selected: {porcento},
                onSelectionChanged: (s) => setLocal(() => porcento = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: porcento ? 'Desconto (%)' : 'Desconto (R\$)',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            if (item.desconto > 0)
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  appState.alterarDesconto(comandaId, item.produtoId, 0);
                },
                child: const Text('Remover desconto'),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                final v = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0;
                final valor = porcento ? item.bruto * v / 100 : v;
                Navigator.pop(ctx);
                final ok = await appState.alterarDesconto(comandaId, item.produtoId, valor);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(appState.ultimoErro ?? 'Erro ao aplicar desconto')),
                  );
                }
              },
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarExcluir(BuildContext context, Comanda comanda) {
    final comItens = comanda.isAtiva && comanda.itens.any((i) => i.quantidade > 0);
    var devolver = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Excluir comanda ${comanda.codigo}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A comanda sai da listagem. O histórico de fechamentos '
                'anteriores permanece nos relatórios.',
              ),
              if (comItens)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Devolver os itens ao estoque'),
                  value: devolver,
                  onChanged: (v) => setD(() => devolver = v ?? false),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await appState.excluirComanda(
                  comandaId,
                  devolverEstoque: comItens && devolver,
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Comanda excluída'
                        : (appState.ultimoErro ?? 'Erro ao excluir')),
                  ),
                );
                if (ok) Navigator.of(context).pop();
              },
              child: const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetar comanda?'),
        content: const Text(
          'Os itens atuais serão apagados e a comanda voltará a ficar ativa e vazia. '
          'O histórico de fechamentos anteriores permanece.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await appState.resetarComanda(comandaId);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Comanda resetada'
                        : (appState.ultimoErro ?? 'Erro ao resetar'),
                  ),
                ),
              );
              if (ok) Navigator.of(context).pop();
            },
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
  }

  Future<void> _vincularNfc(BuildContext context, String codigo) async {
      final estadoNfc = await DispositivoService.estadoNfc();
      if (estadoNfc != EstadoNfc.ligado) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(DispositivoService.mensagemNfc(estadoNfc)),
            action: estadoNfc == EstadoNfc.desligado
                ? SnackBarAction(
                    label: 'Ligar NFC',
                    onPressed: DispositivoService.abrirConfigNfc,
                  )
                : null,
          ),
        );
        return;
      }

      final conf = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Vincular NFC'),
          content: Text(
            'Gravar o código "$codigo" na tag?\n'
            'Se a tag já tiver dados, eles serão sobrescritos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      if (conf != true || !context.mounted) return;

      // Senha
      final senhaCtrl = TextEditingController();
      var erro = false;
      final okSenha = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setLocal) {
              return AlertDialog(
                title: const Text('Senha'),
                content: TextField(
                  controller: senhaCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: erro ? 'Senha incorreta' : null,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (!await authState.senhaConfere(senhaCtrl.text)) {
                        setLocal(() => erro = true);
                        return;
                      }
                      Navigator.pop(ctx, true);
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        },
      );
      if (okSenha != true || !context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aproxime a tag para gravar…')),
      );

      await NfcService.gravarTexto(
        texto: codigo,
        onOk: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Tag vinculada: $codigo')),
            );
          }
        },
        onErro: (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
          }
        },
      );
    }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([appState, permissoes]),
      builder: (context, _) {
        final comanda = appState.comandaPorId(comandaId);
        if (comanda == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Comanda')),
            body: const Center(child: Text('Comanda não encontrada')),
          );
        }

        final podeEditar = comanda.isAtiva;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Detalhe da comanda'),
            actions: [
              if (podeEditar && permissoes.pode('comanda_itens'))
                IconButton(
                  icon: const Icon(Icons.nfc),
                  tooltip: 'Vincular NFC',
                  onPressed: () => _vincularNfc(context, comanda.codigo),
                ),
              IconButton(
                icon: const Icon(Icons.campaign_outlined),
                tooltip: 'Avisos da comanda',
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => AvisosComandaSheet(codigo: comanda.codigo),
                ),
              ),
              if (permissoes.pode('comanda_excluir'))
              PopupMenuButton<String>(
                tooltip: 'Mais opções',
                onSelected: (v) {
                  if (v == 'excluir') _confirmarExcluir(context, comanda);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'excluir',
                    child: ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Excluir comanda'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: podeEditar && permissoes.pode('comanda_itens')
              ? FloatingActionButton(
                  onPressed: () => _abrirSeletor(context),
                  child: const Icon(Icons.add),
                )
              : null,
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: podeEditar
                  ? (!permissoes.pode('comanda_fechar')
                      ? const SizedBox.shrink()
                      : FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () => _iniciarFechamento(context),
                      child: const Text('Fechar comanda'),
                    ))
                  : (!permissoes.pode('comanda_reabrir')
                      ? const SizedBox.shrink()
                      : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () => _confirmarReabrir(context),
                          child: const Text('Reabrir comanda (manter itens)'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                          ),
                          onPressed: () => _confirmarReset(context),
                          child: const Text('Resetar comanda (zerar itens)'),
                        ),
                      ],
                    )),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comanda.codigo,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text('Status: ${comanda.status}'),
                if (comanda.formaPagamento != null)
                  Text('Pagamento: ${comanda.formaPagamento}'),
                const SizedBox(height: 8),
                Text(
                  'Total: R\$ ${comanda.total.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Text('Itens', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Expanded(
                  child: comanda.itens.isEmpty
                      ? const Text('Nenhum item')
                      : ListView.builder(
                          itemCount: comanda.itens.length,
                          itemBuilder: (context, i) {
                            final item = comanda.itens[i];
                            return Card(
                              shape: papelCom(context, '${comanda.id}-$i'),
                              child: ListTile(
                                title: Text(item.nome),
                                subtitle: Text(
                                  'R\$ ${item.precoUnitario.toStringAsFixed(2)} un. • subtotal R\$ ${item.subtotal.toStringAsFixed(2)}'
                                  '${item.desconto > 0 ? ' (desc. R\$ ${item.desconto.toStringAsFixed(2)})' : ''}',
                                ),
                                trailing: podeEditar
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: Icon(
                                              Icons.attach_money,
                                              color: item.desconto > 0
                                                  ? Theme.of(context).colorScheme.primary
                                                  : null,
                                            ),
                                            tooltip: 'Desconto no item',
                                            onPressed: item.quantidade > 0
                                                ? () => _descontoItem(context, item)
                                                : null,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.remove),
                                            onPressed: item.quantidade > 0
                                                ? () async {
                                                    await appState
                                                        .alterarQtdItem(
                                                      comandaId,
                                                      item.produtoId,
                                                      -1,
                                                    );
                                                  }
                                                : null,
                                          ),
                                          Text(
                                            '${item.quantidade}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add),
                                            onPressed: () async {
                                              final ok = await appState
                                                  .alterarQtdItem(
                                                comandaId,
                                                item.produtoId,
                                                1,
                                              );
                                              if (!ok && context.mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      appState.ultimoErro ??
                                                          'Estoque insuficiente',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      )
                                    : Text('x${item.quantidade}'),
                              ),
                            );
                          },
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

class _SeletorProdutos extends StatefulWidget {
  const _SeletorProdutos({required this.comandaId});

  final String comandaId;

  @override
  State<_SeletorProdutos> createState() => _SeletorProdutosState();
}

class _SeletorProdutosState extends State<_SeletorProdutos> {
  String _ambiente = 'Todos';
  String? _sub; // null = todas as subcategorias
  bool _incluirInternos = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final lista = appState.produtos.where((p) {
          if (!p.publico && !_incluirInternos) return false;
          if (_ambiente != 'Todos' && p.ambiente != _ambiente) return false;
          if (_sub != null && p.subcategoria != _sub) return false;
          return true;
        }).toList()
          ..sort((a, b) => a.nome.toLowerCase().compareTo(b.nome.toLowerCase()));
        final subs = kSubcategorias[_ambiente] ?? const <String>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Adicionar item',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Todos', ...kAmbientes].map((a) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(a == 'Todos' ? a : nomeAmbiente(a)),
                        selected: _ambiente == a,
                        onSelected: (_) => setState(() {
                          _ambiente = a;
                          _sub = null;
                        }),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            if (subs.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [null, ...subs].map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(s ?? 'Todas'),
                          selected: _sub == s,
                          onSelected: (_) => setState(() => _sub = s),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Incluir itens internos (não públicos)'),
                value: _incluirInternos,
                onChanged: (v) =>
                    setState(() => _incluirInternos = v ?? false),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                itemBuilder: (context, i) {
                  final p = lista[i];
                  return ListTile(
                    title: Text(p.nome),
                    subtitle: Text(
                      'R\$ ${p.preco.toStringAsFixed(2)} • ${nomeAmbiente(p.ambiente)}'
                      '${p.subcategoria == null ? '' : ' / ${p.subcategoria}'}'
                      ' • estoque: ${p.quantidade}'
                      '${p.publico ? '' : ' • interno'}',
                    ),
                    trailing: const Icon(Icons.add_circle_outline),
                    onTap: () async {
                      final ok = await appState.tentarAdicionarItem(
                        widget.comandaId,
                        p,
                      );
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              appState.ultimoErro ?? 'Estoque insuficiente',
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('${p.nome} adicionado')),
                        );
                      }
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}