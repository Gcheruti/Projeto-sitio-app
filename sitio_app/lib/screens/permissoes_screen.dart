import 'package:flutter/material.dart';

import '../models/permissoes.dart';
import '../state/permissoes_state.dart';

/// Só Adm: liga/desliga o que cada perfil enxerga e pode fazer no app.
class PermissoesScreen extends StatefulWidget {
  const PermissoesScreen({super.key});

  @override
  State<PermissoesScreen> createState() => _PermissoesScreenState();
}

class _PermissoesScreenState extends State<PermissoesScreen> {
  late String _perfil = kPerfisAcesso.first.chave;

  Future<void> _alternar(String chave, bool v) async {
    try {
      await permissoes.definir(_perfil, chave, v);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Não foi possível salvar (rode supabase/permissoes.sql).'),
      ));
    }
  }

  Future<void> _restaurar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Voltar ao padrão?'),
        content: const Text('As escolhas deste perfil serão apagadas e valerá o padrão do app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Voltar ao padrão')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await permissoes.restaurarPadrao(_perfil);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Não foi possível restaurar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfis = kPerfisAcesso;
    final atual = perfis.firstWhere((p) => p.chave == _perfil, orElse: () => perfis.first);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissões de acesso'),
        actions: [
          IconButton(
            tooltip: 'Voltar ao padrão deste perfil',
            icon: const Icon(Icons.restart_alt),
            onPressed: _restaurar,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: permissoes,
        builder: (context, _) {
          final itens = kPermissoes.where((p) => permissaoAplica(_perfil, p.chave)).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _perfil,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Perfil que você está editando',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final p in perfis)
                    DropdownMenuItem(value: p.chave, child: Text(p.nome)),
                ],
                onChanged: (v) => setState(() => _perfil = v ?? _perfil),
              ),
              const SizedBox(height: 8),
              Text(
                'Adm sempre tem acesso a tudo. '
                '${atual.explicacao ?? 'Vale para todas as contas deste tipo.'} '
                'O que estiver desligado some para a pessoa; a mudança chega aos aparelhos em até 30 segundos.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (itens.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text('Este perfil não tem funções para ligar/desligar por enquanto.'),
                ),
              for (final g in kGruposPermissao)
                if (itens.any((p) => p.grupo == g)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 20, bottom: 4),
                    child: Text(g,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary)),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final p in itens.where((p) => p.grupo == g))
                          SwitchListTile(
                            title: Text(p.nome),
                            subtitle: p.detalhe == null ? null : Text(p.detalhe!),
                            value: permissoes.podePerfil(_perfil, p.chave),
                            onChanged: (v) => _alternar(p.chave, v),
                          ),
                      ],
                    ),
                  ),
                ],
            ],
          );
        },
      ),
    );
  }
}
