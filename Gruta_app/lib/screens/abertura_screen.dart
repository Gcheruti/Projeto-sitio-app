import 'package:material_ui/material_ui.dart';

import '../data/catalogo_demo.dart';
import '../logic/datas.dart';
import '../services/lembrete_service.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/fundo_gruta.dart';
import '../widgets/pecas.dart';
import '../widgets/vela.dart';

/// Primeiro acesso, logo depois do cadastro/login: boas-vindas, interesses
/// e ritual diário (meta e lembrete). Tudo fica salvo no perfil da conta;
/// quem já preencheu não vê esta tela de novo. Também abre pelas
/// Configurações para mudar as escolhas ([editar] = true, sem boas-vindas).
class AberturaScreen extends StatefulWidget {
  const AberturaScreen({super.key, this.editar = false});
  final bool editar;

  @override
  State<AberturaScreen> createState() => _AberturaScreenState();
}

class _AberturaScreenState extends State<AberturaScreen> {
  late final _paginas = PageController(initialPage: widget.editar ? 1 : 0);
  late int _pagina = widget.editar ? 1 : 0;
  late final Set<String> _interesses = {...appState.perfil.trilhasInteresse};
  late int _meta = appState.perfil.metaMinutos;
  late TimeOfDay _hora = TimeOfDay(
      hour: appState.perfil.lembreteHora,
      minute: appState.perfil.lembreteMinuto);
  bool _salvando = false;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _avancar() {
    if (_pagina < 2) {
      _paginas.nextPage(
          duration: const Duration(milliseconds: 380), curve: Curves.easeOut);
    } else {
      _concluir();
    }
  }

  Future<void> _concluir() async {
    setState(() => _salvando = true);
    // Pede a permissão de notificação agora, com contexto (a pessoa acabou de
    // escolher o horário do lembrete).
    if (!widget.editar) await LembreteService.pedirPermissao();
    await appState.salvarPerfil(appState.perfil.copyWith(
      metaMinutos: _meta,
      lembreteHora: _hora.hour,
      lembreteMinuto: _hora.minute,
      trilhasInteresse: _interesses.toList(),
    ));
    if (!mounted) return;
    if (widget.editar) {
      Navigator.of(context).pop();
    } else {
      setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FundoGruta(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    if (widget.editar)
                      IconButton(
                        tooltip: 'Fechar',
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ...List.generate(
                    3,
                    (i) => Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: i <= _pagina
                              ? GrutaCores.chama
                              : GrutaCores.linha,
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _paginas,
                  physics: widget.editar
                      ? const NeverScrollableScrollPhysics()
                      : null,
                  onPageChanged: (p) => setState(() => _pagina = p),
                  children: [
                    _boasVindas(context),
                    _escolherTrilhas(context),
                    _metaELembrete(context),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: FilledButton(
                  onPressed: _salvando || (_pagina == 1 && _interesses.isEmpty)
                      ? null
                      : _avancar,
                  child: Text([
                    'Começar',
                    'Continuar',
                    widget.editar ? 'Salvar' : 'Acender minha primeira vela',
                  ][_pagina]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _boasVindas(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Vela(acesa: true, tamanho: 150),
          const SizedBox(height: 28),
          Olho(appState.perfil.nome.isEmpty
              ? 'Bem-vinda, bem-vindo'
              : 'Boas-vindas, ${appState.perfil.nome}'),
          const SizedBox(height: 12),
          Text('Uma vela por dia.',
              textAlign: TextAlign.center,
              style: GrutaTema.titulo(42)),
          const SizedBox(height: 14),
          Text(
            'Na Gruta, todo dia tem uma aula nova em vídeo, de uns cinco '
            'minutos, sobre bruxaria, tarô, ervas e os saberes antigos. '
            'Assista e acenda sua vela. Quantos dias seguidos você consegue '
            'manter a chama?',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16, height: 1.6, color: GrutaCores.textoSuave),
          ),
        ],
      ),
    );
  }

  Widget _escolherTrilhas(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        const Olho('Passo 2 de 3'),
        const SizedBox(height: 10),
        Text('O que te chama?', style: GrutaTema.titulo(36)),
        const SizedBox(height: 8),
        Text('Escolha uma ou mais trilhas. Dá para mudar depois.',
            style: TextStyle(color: GrutaCores.textoSuave)),
        const SizedBox(height: 22),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            for (final t in appState.trilhas.isEmpty
                ? kTrilhasDemo
                : appState.trilhas)
              _OpcaoTrilha(
                titulo: t.titulo,
                icone: t.iconData,
                cor: t.cor,
                marcada: _interesses.contains(t.slug),
                onTap: () => setState(() => _interesses.contains(t.slug)
                    ? _interesses.remove(t.slug)
                    : _interesses.add(t.slug)),
              ),
          ],
        ),
      ],
    );
  }

  Widget _metaELembrete(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      children: [
        const Olho('Passo 3 de 3'),
        const SizedBox(height: 10),
        Text('Seu ritual diário', style: GrutaTema.titulo(36)),
        const SizedBox(height: 8),
        Text(
            'Quanto tempo por dia? A aula do dia tem uns 5 minutos; quem '
            'quiser pode rever aulas e seguir outras trilhas.',
            style: TextStyle(color: GrutaCores.textoSuave, height: 1.5)),
        const SizedBox(height: 18),
        for (final (min, nome, desc) in const [
          (5, 'Uma vela', '5 min por dia · leve'),
          (10, 'Duas velas', '10 min por dia · firme'),
          (15, 'Fogueira', '15 min por dia · intensa'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: CartaoPedra(
              brilho: _meta == min ? GrutaCores.chama : null,
              onTap: () => setState(() => _meta = min),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Row(children: [
                Icon(
                    _meta == min
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: _meta == min
                        ? GrutaCores.chama
                        : GrutaCores.textoApagado),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nome,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)),
                        Text(desc,
                            style: TextStyle(
                                color: GrutaCores.textoSuave, fontSize: 13)),
                      ]),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        CartaoPedra(
          onTap: () async {
            final h = await showTimePicker(context: context, initialTime: _hora);
            if (h != null) setState(() => _hora = h);
          },
          child: Row(children: [
            Icon(Icons.notifications_active_outlined,
                color: GrutaCores.ouro),
            const SizedBox(width: 14),
            const Expanded(
              child: Text('Lembrete diário',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Text(hora(_hora.hour, _hora.minute),
                style: GrutaTema.titulo(28, cor: GrutaCores.chama)),
          ]),
        ),
        const SizedBox(height: 10),
        Text(
          'Só avisamos nos dias em que a vela ainda estiver apagada.',
          style: TextStyle(color: GrutaCores.textoApagado, fontSize: 13),
        ),
      ],
    );
  }
}

class _OpcaoTrilha extends StatelessWidget {
  const _OpcaoTrilha({
    required this.titulo,
    required this.icone,
    required this.cor,
    required this.marcada,
    required this.onTap,
  });

  final String titulo;
  final IconData icone;
  final Color cor;
  final bool marcada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CartaoPedra(
      brilho: marcada ? cor : null,
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Stack(children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icone, color: cor, size: 30),
            Text(titulo,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15, height: 1.2)),
          ],
        ),
        if (marcada)
          Align(
            alignment: Alignment.topRight,
            child: Icon(Icons.check_circle, color: cor, size: 22),
          ),
      ]),
    );
  }
}
