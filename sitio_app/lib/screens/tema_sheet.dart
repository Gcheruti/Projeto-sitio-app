import 'package:flutter/material.dart';

import '../theme/temas_mensais.dart';

/// Menu de tema: no topo os interruptores (efeitos e cartões); abaixo dois
/// mini menus, "Tema" (Base, Estações, Luas) e "Fundo" (texturas). Escolher
/// aplica na hora.
void abrirEscolhaDeTema(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _TemaSheet(),
  );
}

enum _Secao { menu, temas, fundo }

class _TemaSheet extends StatefulWidget {
  const _TemaSheet();

  @override
  State<_TemaSheet> createState() => _TemaSheetState();
}

class _TemaSheetState extends State<_TemaSheet> {
  _Secao _secao = _Secao.menu;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: temaState,
      builder: (ctx, _) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.8),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: ListView(
                key: ValueKey(_secao),
                shrinkWrap: true,
                children: switch (_secao) {
                  _Secao.menu => _menu(),
                  _Secao.temas => _temas(),
                  _Secao.fundo => _fundos(),
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _titulo(String texto, {bool voltar = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(voltar ? 4 : 16, 0, 16, 8),
      child: Row(
        children: [
          if (voltar)
            IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => setState(() => _secao = _Secao.menu),
            ),
          Text(texto,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ---- Menu principal -------------------------------------------------------

  String get _nomeTema {
    final m = temaState.mesEscolhido;
    if (temaState.base) return 'Base';
    if (m == null) {
      return 'Luas automáticas · ${kTemasMensais[DateTime.now().month - 1].nome}';
    }
    if (m == TemaState.estacoesAuto) {
      return 'Estações automáticas · ${temaState.atual.nome}';
    }
    if (temaState.estacao != null) return temaState.atual.nome;
    return '${temaState.atual.nomeMes} · ${temaState.atual.nome}';
  }

  String get _nomeFundo {
    if (temaState.texturaId == kTexturaDaEstacao) {
      return 'Da estação · ${temaState.textura?.nome ?? ''}';
    }
    return temaState.textura?.nome ?? 'Liso (sem textura)';
  }

  List<Widget> _menu() {
    return [
      _titulo('Tema do aplicativo'),
      SwitchListTile(
        value: temaState.efeitos,
        onChanged: temaState.definirEfeitos,
        secondary: const Icon(Icons.auto_awesome),
        title: const Text('Efeitos visuais'),
        subtitle: const Text('Folhas, runas, coelho e patinhas animados'),
      ),
      SwitchListTile(
        value: temaState.cartoesPapel,
        onChanged: temaState.definirCartoesPapel,
        secondary: const Icon(Icons.description_outlined),
        title: const Text('Cartões de pergaminho'),
        subtitle: const Text('Papel envelhecido com botão dourado e runa'),
      ),
      const Divider(height: 1),
      ListTile(
        leading: _Bolinha(temaState.atual, base: temaState.base),
        title: const Text('Tema'),
        subtitle: Text(_nomeTema),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _secao = _Secao.temas),
      ),
      ListTile(
        leading: _MiniTextura(temaState.textura),
        title: const Text('Fundo'),
        subtitle: Text(_nomeFundo),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => setState(() => _secao = _Secao.fundo),
      ),
    ];
  }

  // ---- Submenu: Tema --------------------------------------------------------

  List<Widget> _temas() {
    final hoje = kTemasMensais[DateTime.now().month - 1];
    final estHoje = kTemasEstacoes[estacaoDoDia(DateTime.now())];
    return [
      _titulo('Tema', voltar: true),
      RadioListTile<int?>(
        value: 0,
        groupValue: temaState.mesEscolhido,
        onChanged: (_) => temaState.escolher(0),
        secondary: _Bolinha(temaState.atual, base: true),
        title: const Text('Base'),
        subtitle: const Text('Pergaminho claro (visual original)'),
      ),
      const _Cabecalho('Estações'),
      RadioListTile<int?>(
        value: TemaState.estacoesAuto,
        groupValue: temaState.mesEscolhido,
        onChanged: (_) => temaState.escolher(TemaState.estacoesAuto),
        secondary: _Bolinha(estHoje),
        title: const Text('Estações automáticas'),
        subtitle: Text('Muda sozinho a cada estação · agora: ${estHoje.nome}'),
      ),
      for (var i = 0; i < kTemasEstacoes.length; i++)
        RadioListTile<int?>(
          value: 101 + i,
          groupValue: temaState.mesEscolhido,
          onChanged: (_) => temaState.escolher(101 + i),
          secondary: _Bolinha(kTemasEstacoes[i]),
          title: Text(kTemasEstacoes[i].nome),
          subtitle: Text(kTemasEstacoes[i].frase),
        ),
      const _Cabecalho('Luas'),
      RadioListTile<int?>(
        value: null,
        groupValue: temaState.mesEscolhido,
        onChanged: (_) => temaState.escolher(null),
        secondary: _Bolinha(hoje),
        title: const Text('Luas automáticas'),
        subtitle: Text('Muda a cada mês · agora: ${hoje.nome}'),
      ),
      for (final t in kTemasMensais)
        RadioListTile<int?>(
          value: t.mes,
          groupValue: temaState.mesEscolhido,
          onChanged: (_) => temaState.escolher(t.mes),
          secondary: _Bolinha(t),
          title: Text('${t.nomeMes} · ${t.nome}'),
          subtitle: Text(t.frase),
        ),
    ];
  }

  // ---- Submenu: Fundo -------------------------------------------------------

  List<Widget> _fundos() {
    final daEstacao =
        kTexturasEstacoes[temaState.estacao ?? estacaoDoDia(DateTime.now())];
    return [
      _titulo('Fundo', voltar: true),
      RadioListTile<String?>(
        value: null,
        groupValue: temaState.texturaId,
        onChanged: (_) => temaState.escolherTextura(null),
        secondary: const _MiniTextura(null),
        title: const Text('Liso'),
        subtitle: const Text('Sem textura, só a cor do tema'),
      ),
      const _Cabecalho('Estações'),
      RadioListTile<String?>(
        value: kTexturaDaEstacao,
        groupValue: temaState.texturaId,
        onChanged: (_) => temaState.escolherTextura(kTexturaDaEstacao),
        secondary: _MiniTextura(daEstacao),
        title: const Text('Da estação'),
        subtitle: Text('Acompanha a estação do tema · agora: ${daEstacao.nome}'),
      ),
      for (final t in kTexturasEstacoes)
        RadioListTile<String?>(
          value: t.id,
          groupValue: temaState.texturaId,
          onChanged: (_) => temaState.escolherTextura(t.id),
          secondary: _MiniTextura(t),
          title: Text(t.nome),
        ),
      const _Cabecalho('Texturas'),
      for (final t in kTexturas)
        RadioListTile<String?>(
          value: t.id,
          groupValue: temaState.texturaId,
          onChanged: (_) => temaState.escolherTextura(t.id),
          secondary: _MiniTextura(t),
          title: Text(t.nome),
        ),
    ];
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(texto.toUpperCase(),
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(letterSpacing: 1.5, fontWeight: FontWeight.bold)),
      );
}

class _Bolinha extends StatelessWidget {
  const _Bolinha(this.t, {this.base = false});
  final TemaMensal t;
  final bool base;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: base ? kBaseDetalhe : t.acento,
        shape: BoxShape.circle,
        border: Border.all(color: base ? kBaseAcento : t.detalhe, width: 3),
      ),
    );
  }
}

/// Miniatura da textura já na coloração atual (ou só a cor, no "Liso").
class _MiniTextura extends StatelessWidget {
  const _MiniTextura(this.textura);
  final TexturaTema? textura;

  @override
  Widget build(BuildContext context) {
    final cor = temaState.fundoAtual;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        image: textura == null
            ? null
            : DecorationImage(
                image: AssetImage(textura!.asset),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(cor, BlendMode.multiply),
              ),
      ),
    );
  }
}
