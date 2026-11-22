import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../config/app_config.dart';
import '../models/aula.dart';
import '../services/registro.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/fundo_gruta.dart';
import '../widgets/pecas.dart';
import 'conclusao_screen.dart';

/// Tela da aula: o vídeo em cima, o texto embaixo e o botão de concluir.
/// A aula conta quando a pessoa assiste pelo menos 90% do vídeo.
class AulaScreen extends StatefulWidget {
  const AulaScreen({super.key, required this.aula});
  final Aula aula;

  @override
  State<AulaScreen> createState() => _AulaScreenState();
}

class _AulaScreenState extends State<AulaScreen> {
  late final VideoPlayerController _video;
  bool _pronto = false;
  String? _erro;
  Duration _maisLonge = Duration.zero; // ponto mais longe assistido
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    Registro.evento('aula_aberta',
        aulaId: widget.aula.id,
        trilhaId: widget.aula.daJornada ? null : widget.aula.trilhaId);
    _video = VideoPlayerController.networkUrl(Uri.parse(widget.aula.videoUrl))
      ..addListener(_acompanhar);
    _video.initialize().then((_) {
      if (!mounted) return;
      setState(() => _pronto = true);
      _video.play();
    }).catchError((Object e) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar o vídeo.');
    });
  }

  void _acompanhar() {
    final p = _video.value.position;
    if (p > _maisLonge) _maisLonge = p;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video.removeListener(_acompanhar);
    _video.dispose();
    super.dispose();
  }

  bool get _assistiuOSuficiente {
    final total = _video.value.duration;
    if (total == Duration.zero) return false;
    return _maisLonge.inMilliseconds >=
        total.inMilliseconds * AppConfig.fracaoParaConcluir;
  }

  Future<void> _concluir() async {
    setState(() => _salvando = true);
    try {
      final r = await appState.concluirAula(
          widget.aula, _maisLonge.inSeconds);
      if (!mounted) return;
      _video.pause();
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ConclusaoScreen(aula: widget.aula, resultado: r)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _salvando = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível salvar. Verifique a conexão.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final aula = widget.aula;
    final trilha = appState.trilhaPorId(aula.trilhaId)!;
    final total = appState.aulasDa(aula.trilhaId).length;
    final jaFeita = appState.foiConcluida(aula.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(trilha.titulo, style: GrutaTema.titulo(22)),
      ),
      body: FundoGruta(
        poeira: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            AspectRatio(
              aspectRatio: _pronto ? _video.value.aspectRatio : 16 / 9,
              child: ColoredBox(color: Colors.black, child: _player()),
            ),
            if (_pronto)
              VideoProgressIndicator(
                _video,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: VideoProgressColors(
                  playedColor: GrutaCores.chama,
                  bufferedColor: GrutaCores.linha,
                  backgroundColor: GrutaCores.rocha,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(GrutaMedidas.margem),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Olho('Aula ${aula.ordem} de $total · ${aula.duracaoTexto}',
                      cor: trilha.cor),
                  const SizedBox(height: 8),
                  Text(aula.titulo, style: GrutaTema.titulo(32)),
                  const SizedBox(height: 12),
                  Text(aula.descricao,
                      style: TextStyle(
                          color: GrutaCores.textoSuave, height: 1.55)),
                  const SizedBox(height: 26),
                  if (jaFeita)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.check, color: GrutaCores.musgo),
                      label: const Text('Aula já concluída · voltar'),
                    )
                  else ...[
                    FilledButton.icon(
                      onPressed: _assistiuOSuficiente && !_salvando
                          ? _concluir
                          : null,
                      icon: const Icon(Icons.local_fire_department),
                      label: const Text('Concluir e acender a vela'),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _assistiuOSuficiente
                            ? 'Pronto! Pode concluir.'
                            : 'Assista até o fim para concluir.',
                        style: TextStyle(
                            color: GrutaCores.textoApagado, fontSize: 13),
                      ),
                    ),
                    // Atalho só no modo demonstração, para testar o fluxo.
                    if (authState.modoDemo)
                      Center(
                        child: TextButton(
                          onPressed: _salvando ? null : _concluir,
                          child: const Text('Pular vídeo (só na demonstração)'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _player() {
    if (_erro != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.videocam_off_outlined,
              color: GrutaCores.textoSuave, size: 36),
          const SizedBox(height: 8),
          Text(_erro!, style: TextStyle(color: GrutaCores.textoSuave)),
        ]),
      );
    }
    if (!_pronto) {
      return Center(
          child: CircularProgressIndicator(color: GrutaCores.chama));
    }
    final tocando = _video.value.isPlaying;
    return GestureDetector(
      onTap: () {
        if (tocando) {
          _video.pause();
          return;
        }
        if (_video.value.position >= _video.value.duration) {
          _video.seekTo(Duration.zero);
        }
        _video.play();
      },
      child: Stack(fit: StackFit.expand, children: [
        VideoPlayer(_video),
        AnimatedOpacity(
          opacity: tocando ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          child: ColoredBox(
            color: Colors.black38,
            child: Center(
              child: Icon(
                  _video.value.position >= _video.value.duration
                      ? Icons.replay
                      : Icons.play_circle_fill,
                  size: 68,
                  color: GrutaCores.pergaminho),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 8,
          child: Text(
            '${_tempo(_video.value.position)} / ${_tempo(_video.value.duration)}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(blurRadius: 6)]),
          ),
        ),
      ]),
    );
  }

  String _tempo(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
