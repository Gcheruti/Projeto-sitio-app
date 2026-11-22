import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/servicos.dart';
import '../theme/gruta_tema.dart';
import '../widgets/pecas.dart';

/// Pop-up "Conheça nossos outros serviços".
Future<void> mostrarServicos(BuildContext context) => abrirFolha(
      context,
      (context) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          const Puxador(),
          const SizedBox(height: 20),
          const Olho('Além da Gruta'),
          const SizedBox(height: 6),
          Text('Conheça nossos outros serviços', style: GrutaTema.titulo(30)),
          const SizedBox(height: 6),
          Text('O que você aprende aqui, encontra também lá fora.',
              style: TextStyle(color: GrutaCores.textoSuave)),
          const SizedBox(height: 16),
          for (final s in kServicos) ...[
            _CartaoServico(servico: s),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );

class _CartaoServico extends StatelessWidget {
  const _CartaoServico({required this.servico});
  final Servico servico;

  @override
  Widget build(BuildContext context) {
    final s = servico;
    return CartaoPedra(
      brilho: s.cor,
      onTap: () => _abrir(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: s.cor.withValues(alpha: .15),
              border: Border.all(color: s.cor.withValues(alpha: .5)),
            ),
            child: Icon(s.icone, color: s.cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.nome, style: GrutaTema.titulo(25)),
                Text(s.descricao,
                    style: TextStyle(
                        color: GrutaCores.textoSuave,
                        fontSize: 13.5,
                        height: 1.35)),
              ],
            ),
          ),
        ]),
        if (s.destaques.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final d in s.destaques)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(99),
                  color: s.cor.withValues(alpha: .1),
                ),
                child: Text(d,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: s.cor)),
              ),
          ]),
        ],
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(s.url == null ? 'Endereço em breve' : 'Visitar  →',
              style: TextStyle(
                  color: s.url == null ? GrutaCores.textoApagado : s.cor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
        ),
      ]),
    );
  }

  Future<void> _abrir(BuildContext context) async {
    final url = servico.url;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('O endereço de ${servico.nome} chega em breve.')));
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
