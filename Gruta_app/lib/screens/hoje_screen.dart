import 'package:material_ui/material_ui.dart';

import '../data/catalogo_demo.dart';
import '../logic/datas.dart';
import '../models/aula.dart';
import '../models/trilha.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';
import '../widgets/tutorial.dart';
import '../widgets/vela.dart';
import 'aula_screen.dart';
import 'avisos_sheet.dart';
import 'planos_sheet.dart';
import 'trilha_screen.dart';
import 'shell_screen.dart';

/// Aba Hoje: a vela (ofensiva), a semana e a aula do dia.
class HojeScreen extends StatelessWidget {
  const HojeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final agora = DateTime.now();
        final o = appState.ofensiva;
        final nome = appState.perfil.nome;
        return SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: GrutaCores.chama,
            onRefresh: appState.carregar,
            child: ListView(
              controller: TutorialAlvos.rolagemHoje,
              padding: const EdgeInsets.fromLTRB(
                  GrutaMedidas.margem, 12, GrutaMedidas.margem, 32),
              children: [
                Row(children: [
                  Text('Gruta', style: GrutaTema.titulo(30)),
                  const Spacer(),
                  KeyedSubtree(
                      key: TutorialAlvos.avisos,
                      child: BotaoAvisos(onTap: () => mostrarAvisos(context))),
                  const SizedBox(width: 4),
                  SeloOfensiva(ofensiva: o),
                  const ReservaTopo(),
                ]),
                const SizedBox(height: 22),
                Olho(dataPorExtenso(agora)),
                const SizedBox(height: 6),
                Text(
                  nome.isEmpty ? saudacao(agora) : '${saudacao(agora)}, $nome',
                  style: GrutaTema.titulo(34),
                ),
                const SizedBox(height: 20),
                KeyedSubtree(key: TutorialAlvos.vela, child: _CartaoVela()),
                const SizedBox(height: 28),
                KeyedSubtree(
                    key: TutorialAlvos.aula, child: const _AulaDoDia()),
                const SizedBox(height: 22),
                KeyedSubtree(
                    key: TutorialAlvos.moedas, child: const _CartaoMoedas()),
                const _SuasTrilhas(),
                const SizedBox(height: 26),
                _MetaDoDia(),
                const SizedBox(height: 28),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      '“${kFrasesDoDia[agora.day % kFrasesDoDia.length]}”',
                      textAlign: TextAlign.center,
                      style: GrutaTema.titulo(22,
                              cor: GrutaCores.arenito, peso: FontWeight.w500)
                          .copyWith(fontStyle: FontStyle.italic, height: 1.3),
                    ),
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

class _CartaoVela extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final o = appState.ofensiva;
    final String frase;
    if (o.feitoHoje) {
      frase = 'Vela acesa! Volte amanhã para manter a chama.';
    } else if (o.emRisco) {
      frase = 'Sua vela apaga em ${ateMeiaNoite(DateTime.now())}. '
          'Assista à aula de hoje para mantê-la acesa.';
    } else {
      frase = 'Acenda sua vela com a aula de hoje.';
    }
    return CartaoPedra(
      brilho: o.feitoHoje ? GrutaCores.chama : null,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Vela(acesa: o.feitoHoje, tamanho: 84),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${o.atual}',
                        style: GrutaTema.titulo(52,
                            cor: o.feitoHoje
                                ? GrutaCores.chama
                                : GrutaCores.pergaminho)),
                    const SizedBox(width: 8),
                    Text(o.atual == 1 ? 'dia aceso' : 'dias acesos',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: GrutaCores.textoSuave)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(frase,
                    style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: GrutaCores.textoSuave)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 18),
        SemanaVelas(
          diasComAula: appState.diasComAula,
          diasProtegidos: o.diasProtegidos,
        ),
        if (o.amuletos > 0 || o.recorde > 0) ...[
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.shield_moon_outlined,
                size: 18, color: GrutaCores.ouro),
            const SizedBox(width: 6),
            Text(
                o.amuletos == 1
                    ? '1 amuleto guardado'
                    : '${o.amuletos} amuletos guardados',
                style: TextStyle(
                    fontSize: 13, color: GrutaCores.textoSuave)),
            const Spacer(),
            Icon(Icons.emoji_events_outlined,
                size: 18, color: GrutaCores.ouro),
            const SizedBox(width: 6),
            Text('Recorde: ${o.recorde}',
                style: TextStyle(
                    fontSize: 13, color: GrutaCores.textoSuave)),
          ]),
        ],
      ]),
    );
  }
}

class _AulaDoDia extends StatelessWidget {
  const _AulaDoDia();

  @override
  Widget build(BuildContext context) {
    const trilha = kTrilhaJornada;
    final proxima = appState.proximaDa(kJornadaId);
    final total = appState.jornada.length;
    final feitaHoje = appState.concluidaHojeNa(kJornadaId);

    if (proxima == null) {
      return CartaoPedra(
        brilho: trilha.cor,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Olho('Jornada concluída', cor: trilha.cor),
          const SizedBox(height: 10),
          Text('Você completou as $total aulas da Jornada!',
              style: GrutaTema.titulo(26)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () => ShellScreen.aba.value = 1,
            child: const Text('Seguir pelas trilhas'),
          ),
        ]),
      );
    }

    final estado = appState.estadoDa(proxima);
    final aula = estado == EstadoAula.amanha && feitaHoje != null
        ? feitaHoje
        : proxima;
    final rotulo = aula.ordem == 0
        ? 'Aula piloto'
        : 'Aula ${aula.ordem} de ${total - 1}';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Olho(estado == EstadoAula.amanha ? 'Aula de hoje · feita' : 'Aula do dia',
          cor: trilha.cor),
      const SizedBox(height: 10),
      CartaoPedra(
        brilho: trilha.cor,
        padding: const EdgeInsets.all(12),
        onTap: () => _abrir(context, aula, estado),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CapaAula(
            aula: aula,
            trilha: trilha,
            mostrarPlay: estado != EstadoAula.trancada,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Jornada · $rotulo',
                    style: TextStyle(
                        color: trilha.cor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(aula.titulo, style: GrutaTema.titulo(26)),
                const SizedBox(height: 10),
                BarraProgresso(
                    valor: total == 0
                        ? 0
                        : appState.concluidasNa(kJornadaId) / total),
                const SizedBox(height: 14),
                if (estado == EstadoAula.amanha)
                  _ProximaAmanha(proxima: proxima)
                else if (estado == EstadoAula.trancada)
                  FilledButton.icon(
                    onPressed: () => mostrarPlanos(context),
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text('Continuar a Jornada como Aprendiz'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => _abrir(context, aula, estado),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Assistir agora'),
                  ),
              ],
            ),
          ),
        ]),
      ),
    ]);
  }

  void _abrir(BuildContext context, Aula aula, EstadoAula estado) {
    if (estado == EstadoAula.trancada) {
      mostrarPlanos(context);
      return;
    }
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => AulaScreen(aula: aula)));
  }
}

class _ProximaAmanha extends StatelessWidget {
  const _ProximaAmanha({required this.proxima});
  final Aula proxima;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: GrutaCores.noite.withValues(alpha: .5),
        border: Border.all(color: GrutaCores.linha),
      ),
      child: Row(children: [
        Icon(Icons.nightlight_round, color: GrutaCores.ouro),
        const SizedBox(width: 12),
        Expanded(
          child: Text.rich(TextSpan(children: [
            const TextSpan(
                text: 'Amanhã: ',
                style: TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: proxima.titulo),
            TextSpan(
                text: '\nabre em ${ateMeiaNoite(DateTime.now())}',
                style: TextStyle(
                    color: GrutaCores.textoApagado, fontSize: 12.5)),
          ])),
        ),
      ]),
    );
  }
}

/// Moedas: quantas tem e quanto falta para a próxima.
class _CartaoMoedas extends StatelessWidget {
  const _CartaoMoedas();

  @override
  Widget build(BuildContext context) {
    if (appState.plano.todasAsTrilhas) return const SizedBox.shrink();
    final moedas = appState.moedas;
    final faltam = appState.faltamMoeda;
    final String texto;
    if (moedas > 0) {
      texto = moedas == 1
          ? 'Você tem 1 moeda para abrir uma trilha.'
          : 'Você tem $moedas moedas para abrir trilhas.';
    } else if (faltam != null) {
      texto = 'Faltam $faltam ${faltam == 1 ? 'aula' : 'aulas'} da Jornada '
          'para a próxima moeda.';
    } else {
      texto = 'Você já ganhou todas as moedas da Jornada.';
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: CartaoPedra(
        brilho: moedas > 0 ? GrutaCores.ouro : null,
        onTap: () => ShellScreen.aba.value = 1,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Moeda(tamanho: 40, apagada: moedas == 0),
          const SizedBox(width: 14),
          Expanded(
            child: Text(texto,
                style: TextStyle(color: GrutaCores.textoSuave, height: 1.4)),
          ),
          Icon(Icons.chevron_right, color: GrutaCores.textoApagado),
        ]),
      ),
    );
  }
}

/// Atalhos para as trilhas já liberadas.
class _SuasTrilhas extends StatelessWidget {
  const _SuasTrilhas();

  @override
  Widget build(BuildContext context) {
    final lista =
        appState.trilhas.where((t) => appState.trilhaLiberada(t.id)).toList();
    if (lista.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Olho('Suas trilhas'),
        const SizedBox(height: 10),
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: lista.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final t = lista[i];
              return ActionChip(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => TrilhaScreen(trilhaId: t.id))),
                avatar: Icon(t.iconData, size: 18, color: t.cor),
                label: Text(t.titulo),
                backgroundColor: GrutaCores.rocha,
                side: BorderSide(color: t.cor.withValues(alpha: .6)),
                labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: GrutaCores.pergaminho),
                shape: const StadiumBorder(),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _MetaDoDia extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final meta = appState.perfil.metaMinutos;
    final feito = appState.minutosHoje;
    final ok = feito >= meta;
    return CartaoPedra(
      child: Row(children: [
        SizedBox(
          width: 54,
          height: 54,
          child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(
              value: (feito / meta).clamp(0, 1),
              strokeWidth: 5,
              backgroundColor: GrutaCores.linha,
              color: ok ? GrutaCores.musgo : GrutaCores.chama,
            ),
            Center(
              child: Icon(ok ? Icons.check : Icons.hourglass_bottom,
                  color: ok ? GrutaCores.musgo : GrutaCores.textoSuave),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Meta do dia',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              ok ? 'Cumprida: $feito de $meta min' : '$feito de $meta min',
              style: TextStyle(color: GrutaCores.textoSuave),
            ),
          ]),
        ),
      ]),
    );
  }
}
