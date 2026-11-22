import 'package:flutter/material.dart';

import 'relatorio_colaboradores_screen.dart';
import 'relatorio_compra_screen.dart';
import 'relatorio_estoque_screen.dart';
import 'financeiro_hub_screen.dart';

/// Menu dos relatórios (só Adm, via Ajustes).
class RelatoriosScreen extends StatelessWidget {
  const RelatoriosScreen({super.key});

  void _abrir(BuildContext context, Widget tela) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => tela));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.insights_outlined),
            title: const Text('Financeiro'),
            subtitle: const Text('Resumo, Sítio, Cosmória, Toca e Cursos e eventos'),
            onTap: () => _abrir(context, const FinanceiroHubScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Estoque'),
            subtitle: const Text('Entradas, saídas e itens mais procurados'),
            onTap: () => _abrir(context, const RelatorioEstoqueScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Compra'),
            subtitle: const Text('Estoque baixo e itens com alta saída'),
            onTap: () => _abrir(context, const RelatorioCompraScreen()),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.groups_2_outlined),
            title: const Text('Colaboradores'),
            subtitle: const Text('Tudo que cada pessoa da equipe fez no app'),
            onTap: () =>
                _abrir(context, const RelatorioColaboradoresScreen()),
          ),
        ],
      ),
    );
  }
}
