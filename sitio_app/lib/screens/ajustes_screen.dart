import 'package:flutter/material.dart';
import '../widgets/borda_papel.dart' show papelCom;
import 'baixa_estoque_screen.dart';
import '../state/auth_state.dart';
import '../state/permissoes_state.dart';
import 'enviar_aviso_screen.dart';
import 'equipe_screen.dart';
import 'nfc_config_screen.dart';
import 'relatorios_screen.dart';
import 'reposicao_screen.dart';
import 'tema_sheet.dart';

class AjustesScreen extends StatelessWidget {
  const AjustesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = authState.usuario;
    return ListenableBuilder(
      listenable: permissoes,
      builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        actions: [
          IconButton(
            tooltip: 'Tema do aplicativo',
            icon: const Icon(Icons.palette_outlined, size: 22),
            onPressed: () => abrirEscolhaDeTema(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Card(shape: papelCom(context, 'ajustes1'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(u?.nome ?? ''),
            subtitle: Text('${u?.login ?? ''} • ${u?.papelTexto ?? ''}'),
          )),
          if (permissoes.pode('ajustes_reposicao'))
          Card(shape: papelCom(context, 'ajustes2'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Reposição'),
            subtitle: const Text('Entrada de mercadoria'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StockInScreen()),
              );
            },
          )),
          if (permissoes.pode('ajustes_baixa'))
          Card(shape: papelCom(context, 'ajustes3'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.remove_circle_outline),
            title: const Text('Baixa de estoque'),
            subtitle: const Text('Validade, perda, consumo interno'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BaixaEstoqueScreen()),
              );
            },
          )),
          if (permissoes.pode('ajustes_relatorios'))
          Card(shape: papelCom(context, 'ajustes4'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.bar_chart_outlined),
            title: const Text('Relatórios'),
            subtitle: const Text('Vendas, reposição e baixas'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RelatoriosScreen()),
              );
            },
          )),
          if (permissoes.pode('ajustes_nfc'))
          Card(shape: papelCom(context, 'ajustes5'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.nfc),
            title: const Text('NFC'),
            subtitle: const Text('Ler, gravar e limpar tags'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NfcConfigScreen()),
              );
            },
          )),
          if (permissoes.pode('ajustes_equipe'))
            Card(shape: papelCom(context, 'ajustes6'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: const Text('Manutenção de equipe'),
              subtitle: const Text('Cadastros, senhas e tipo de conta'),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EquipeScreen()),
                );
              },
            )),
          if (permissoes.pode('ajustes_notificacoes'))
          Card(shape: papelCom(context, 'ajustes7'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.campaign_outlined),
            title: const Text('Notificações'),
            subtitle: const Text('Enviar um aviso agora para todos os aparelhos'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EnviarAvisoScreen()),
              );
            },
          )),
          if (permissoes.pode('ajustes_trocas'))
          Card(shape: papelCom(context, 'ajustes8'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Sistema de trocas'),
            subtitle: const Text('Em manutenção'),
            enabled: false,
          )),
          Card(shape: papelCom(context, 'ajustes9'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão do aplicativo'),
            subtitle: const Text('Sítio • equipe'),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Sítio',
                applicationVersion: '1.0.11',
                applicationLegalese: 'App da equipe — uso interno',
              );
            },
          )),
          Card(shape: papelCom(context, 'ajustes10'), margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sair (logout)'),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sair da conta?'),
                  content: const Text('Será preciso entrar de novo.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );
              if (ok == true) await authState.sair();
            },
          )),
        ],
      ),
    ));
  }
}
