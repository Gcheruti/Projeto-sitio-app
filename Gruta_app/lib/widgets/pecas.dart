import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../logic/ofensiva.dart';
import '../state/app_state.dart';
import '../models/aula.dart';
import '../models/trilha.dart';
import '../theme/gruta_tema.dart';
import 'vela.dart';

/// Cartão de pedra: a superfície padrão do app.
class CartaoPedra extends StatelessWidget {
  const CartaoPedra({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.brilho,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Cor da luz na borda (ex.: cor da trilha). null = sem brilho.
  final Color? brilho;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final raio = BorderRadius.circular(GrutaMedidas.raio);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: raio,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [GrutaCores.rochaClara, GrutaCores.rocha],
        ),
        border: Border.all(
            color: brilho?.withValues(alpha: .45) ?? GrutaCores.linha),
        boxShadow: [
          BoxShadow(
              color: GrutaCores.sombra, blurRadius: 18, offset: Offset(0, 8)),
          if (brilho != null)
            BoxShadow(
                color: brilho!.withValues(alpha: .18),
                blurRadius: 28,
                spreadRadius: -6),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: raio,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Rótulo pequeno em caixa alta (como o "olho" dos sites).
class Olho extends StatelessWidget {
  const Olho(this.texto, {super.key, this.cor});
  final String texto;
  final Color? cor;

  @override
  Widget build(BuildContext context) => Text(
        texto.toUpperCase(),
        style: GoogleFonts.manrope(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.2,
            color: cor ?? GrutaCores.ouro),
      );
}

/// Capa de uma aula. Sem imagem própria, desenha uma capa com a cor e o
/// símbolo da trilha (até as capas reais existirem).
class CapaAula extends StatelessWidget {
  const CapaAula({
    super.key,
    required this.aula,
    required this.trilha,
    this.altura = 180,
    this.mostrarPlay = true,
  });

  final Aula aula;
  final Trilha trilha;
  final double altura;
  final bool mostrarPlay;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: altura,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (aula.capaUrl != null)
              Image.network(aula.capaUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      ColoredBox(color: trilha.cor.withValues(alpha: .2)))
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(.6, -.4),
                    radius: 1.2,
                    colors: [
                      trilha.cor.withValues(alpha: .55),
                      Color(0xFF2A1E15),
                      GrutaCores.noite,
                    ],
                    stops: [0, .6, 1],
                  ),
                ),
                child: Align(
                  alignment: Alignment(.85, 0),
                  child: Icon(trilha.iconData,
                      size: altura * .62,
                      color: trilha.cor.withValues(alpha: .28)),
                ),
              ),
            // Escurece embaixo para o texto
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xCC0B0907)],
                  stops: [.35, 1],
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: _Selo(
                  icone: Icons.schedule, texto: aula.duracaoTexto),
            ),
            if (mostrarPlay)
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: GrutaCores.chama,
                    boxShadow: [
                      BoxShadow(
                          color: GrutaCores.chama.withValues(alpha: .5),
                          blurRadius: 30),
                    ],
                  ),
                  child: Icon(Icons.play_arrow_rounded,
                      size: 40, color: GrutaCores.noite),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Selo extends StatelessWidget {
  const _Selo({required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Color(0xAA0B0907),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: GrutaCores.linha),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 14, color: GrutaCores.pergaminho),
          SizedBox(width: 5),
          Text(texto,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Contador da ofensiva para o topo das telas: vela pequena + número.
class SeloOfensiva extends StatelessWidget {
  const SeloOfensiva({super.key, required this.ofensiva, this.onTap});
  final Ofensiva ofensiva;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final acesa = ofensiva.feitoHoje;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(8, 4, 14, 4),
        decoration: BoxDecoration(
          color: GrutaCores.rocha,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: acesa
                  ? GrutaCores.chama.withValues(alpha: .6)
                  : GrutaCores.linha),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Vela(acesa: acesa, tamanho: 30),
          SizedBox(width: 4),
          Text('${ofensiva.atual}',
              style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: acesa ? GrutaCores.chama : GrutaCores.textoSuave)),
        ]),
      ),
    );
  }
}

/// A semana de domingo a sábado, com uma chama em cada dia estudado.
class SemanaVelas extends StatelessWidget {
  const SemanaVelas({
    super.key,
    required this.diasComAula,
    required this.diasProtegidos,
  });

  final Set<DateTime> diasComAula;
  final Set<DateTime> diasProtegidos;

  static const _letras = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final hoje = soData(DateTime.now());
    final domingo = DateTime(hoje.year, hoje.month, hoje.day - hoje.weekday % 7);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dia = DateTime(domingo.year, domingo.month, domingo.day + i);
        final feito = diasComAula.contains(dia);
        final protegido = diasProtegidos.contains(dia);
        final ehHoje = dia == hoje;
        final futuro = dia.isAfter(hoje);
        return Column(children: [
          Text(_letras[i],
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: ehHoje ? GrutaCores.chama : GrutaCores.textoApagado)),
          SizedBox(height: 6),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: feito
                  ? GrutaCores.chama.withValues(alpha: .16)
                  : Colors.transparent,
              border: Border.all(
                color: feito
                    ? GrutaCores.chama
                    : ehHoje
                        ? GrutaCores.chama.withValues(alpha: .5)
                        : GrutaCores.linha,
                width: ehHoje ? 2 : 1,
              ),
            ),
            child: Center(
              child: feito
                  ? Icon(Icons.local_fire_department,
                      size: 20, color: GrutaCores.chama)
                  : protegido
                      ? Icon(Icons.shield_moon_outlined,
                          size: 18, color: GrutaCores.ouro)
                      : Text('${dia.day}',
                          style: TextStyle(
                              fontSize: 12,
                              color: futuro
                                  ? GrutaCores.textoApagado
                                      .withValues(alpha: .5)
                                  : GrutaCores.textoApagado)),
            ),
          ),
        ]);
      }),
    );
  }
}

/// Barra de progresso fina e arredondada.
class BarraProgresso extends StatelessWidget {
  const BarraProgresso({super.key, required this.valor, this.cor});
  final double valor;
  final Color? cor;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: valor.clamp(0, 1),
          minHeight: 6,
          backgroundColor: GrutaCores.linha,
          valueColor: AlwaysStoppedAnimation(cor ?? GrutaCores.chama),
        ),
      );
}

/// Uma moeda da Gruta: disco dourado com uma lua.
class Moeda extends StatelessWidget {
  const Moeda({super.key, this.tamanho = 22, this.apagada = false});
  final double tamanho;
  final bool apagada;

  @override
  Widget build(BuildContext context) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: apagada
                ? [GrutaCores.linha, GrutaCores.rochaClara]
                : const [Color(0xFFF7D98B), Color(0xFFC9973A)],
          ),
          border: Border.all(
              color: apagada ? GrutaCores.linha : const Color(0xFF9C7224),
              width: tamanho / 16),
          boxShadow: apagada
              ? null
              : [
                  BoxShadow(
                      color: const Color(0xFFF0C25A).withValues(alpha: .35),
                      blurRadius: tamanho / 2),
                ],
        ),
        child: Icon(Icons.nightlight_round,
            size: tamanho * .55,
            color: apagada
                ? GrutaCores.textoApagado
                : const Color(0xFF7A5414)),
      );
}

/// Contador de moedas para o topo das telas.
class ContadorMoedas extends StatelessWidget {
  const ContadorMoedas({super.key, required this.quantidade, this.onTap});
  final int quantidade;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          decoration: BoxDecoration(
            color: GrutaCores.rocha,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
                color: quantidade > 0
                    ? GrutaCores.ouro.withValues(alpha: .7)
                    : GrutaCores.linha),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Moeda(tamanho: 26, apagada: quantidade == 0),
            const SizedBox(width: 8),
            Text('$quantidade',
                style: GoogleFonts.manrope(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: quantidade > 0
                        ? GrutaCores.ouro
                        : GrutaCores.textoSuave)),
          ]),
        ),
      );
}

/// Sino dos avisos, com um ponto quando há novidade.
class BotaoAvisos extends StatelessWidget {
  const BotaoAvisos({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Avisos',
        onPressed: onTap,
        icon: Badge(
          isLabelVisible: appState.temAvisoNovo,
          backgroundColor: GrutaCores.chama,
          smallSize: 9,
          child: Icon(Icons.notifications_none_rounded,
              color: GrutaCores.textoSuave),
        ),
      );
}

/// Barrinha de arrastar no topo das folhas (bottom sheets).
class Puxador extends StatelessWidget {
  const Puxador({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
              color: GrutaCores.linha, borderRadius: BorderRadius.circular(9)),
        ),
      );
}

/// Abre uma folha (bottom sheet) com o visual da Gruta.
Future<T?> abrirFolha<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      backgroundColor: GrutaCores.rocha,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: builder,
    );

/// Espaço reservado no canto superior direito das abas, onde flutuam o
/// botão dos serviços (e, no modo /adm, o das ferramentas).
class ReservaTopo extends StatelessWidget {
  const ReservaTopo({super.key});

  static bool get comAdmin => AppConfig.modoAdm && appState.perfil.admin;

  @override
  Widget build(BuildContext context) => SizedBox(width: comAdmin ? 96 : 50);
}
