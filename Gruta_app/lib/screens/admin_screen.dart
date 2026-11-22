import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../logic/datas.dart';
import '../models/aula.dart';
import '../models/trilha.dart';
import '../state/app_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/fundo_gruta.dart';
import '../widgets/pecas.dart';

/// Painel do modo /adm: enviar avisos para todos e cuidar das aulas
/// (textos, vídeos e capas). Tudo passa pelo RLS do banco: só quem tem
/// perfis.papel = 'admin' consegue gravar.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Row(children: [
            Icon(Icons.construction, color: GrutaCores.musgo),
            const SizedBox(width: 10),
            Text('Administração', style: GrutaTema.titulo(26)),
          ]),
          bottom: TabBar(
            indicatorColor: GrutaCores.chama,
            labelColor: GrutaCores.chama,
            unselectedLabelColor: GrutaCores.textoSuave,
            tabs: const [
              Tab(icon: Icon(Icons.campaign_outlined), text: 'Avisos'),
              Tab(icon: Icon(Icons.video_library_outlined), text: 'Aulas'),
            ],
          ),
        ),
        body: const FundoGruta(
          poeira: false,
          child: TabBarView(children: [_AbaAvisos(), _AbaAulas()]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- avisos

class _AbaAvisos extends StatefulWidget {
  const _AbaAvisos();

  @override
  State<_AbaAvisos> createState() => _AbaAvisosState();
}

class _AbaAvisosState extends State<_AbaAvisos> {
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  String _icone = 'vela';
  bool _enviando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final titulo = _titulo.text.trim();
    if (titulo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escreva um título para o aviso.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GrutaCores.rocha,
        title: const Text('Enviar para todos?'),
        content: const Text(
            'O aviso aparece para todas as pessoas que usam a Gruta. '
            'Não dá para desfazer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _enviando = true);
    try {
      await appState.enviarAviso(
          titulo: titulo, descricao: _descricao.text.trim(), icone: _icone);
      _titulo.clear();
      _descricao.clear();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Aviso enviado.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Não foi possível enviar: $e')));
      }
    }
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(
            GrutaMedidas.margem, 20, GrutaMedidas.margem, 40),
        children: [
          const Olho('Novo aviso'),
          const SizedBox(height: 10),
          TextField(
            controller: _titulo,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _descricao,
            minLines: 2,
            maxLines: 4,
            maxLength: 240,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 8),
          Text('Ícone', style: TextStyle(color: GrutaCores.textoSuave)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kIconesAviso.entries)
              InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => setState(() => _icone = e.key),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _icone == e.key
                        ? GrutaCores.chama.withValues(alpha: .2)
                        : GrutaCores.rocha,
                    border: Border.all(
                        color: _icone == e.key
                            ? GrutaCores.chama
                            : GrutaCores.linha,
                        width: _icone == e.key ? 2 : 1),
                  ),
                  child: Icon(e.value,
                      color: _icone == e.key
                          ? GrutaCores.chama
                          : GrutaCores.textoSuave),
                ),
              ),
          ]),
          const SizedBox(height: 18),
          const Olho('Prévia'),
          const SizedBox(height: 8),
          CartaoPedra(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(kIconesAviso[_icone], color: GrutaCores.chama, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        _titulo.text.isEmpty ? 'Título do aviso' : _titulo.text,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (_descricao.text.isNotEmpty)
                      Text(_descricao.text,
                          style: TextStyle(color: GrutaCores.textoSuave)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: const Icon(Icons.send),
            label: const Text('Enviar para todos'),
          ),
          const SizedBox(height: 8),
          Text(
            'Aparece no sino da tela Hoje e como notificação quando o app '
            'abre. Notificação com o app fechado depende do Firebase '
            '(ver docs/ADMIN.md).',
            style: TextStyle(color: GrutaCores.textoApagado, fontSize: 12.5),
          ),
          const SizedBox(height: 28),
          const Olho('Enviados'),
          const SizedBox(height: 10),
          if (appState.avisos.isEmpty)
            Text('Nenhum aviso ainda.',
                style: TextStyle(color: GrutaCores.textoSuave)),
          for (final a in appState.avisos)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(kIconesAviso[a.icone] ?? Icons.notifications,
                  color: GrutaCores.chama),
              title: Text(a.titulo),
              subtitle: Text(
                  '${dataCurta(a.criadaEm)}'
                  '${a.descricao.isEmpty ? '' : ' · ${a.descricao}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: GrutaCores.textoSuave)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- aulas

class _AbaAulas extends StatefulWidget {
  const _AbaAulas();

  @override
  State<_AbaAulas> createState() => _AbaAulasState();
}

class _AbaAulasState extends State<_AbaAulas> {
  String _trilhaId = kJornadaId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final trilhas = [kTrilhaJornada, ...appState.trilhas];
        final aulas = appState.aulasDa(_trilhaId);
        final trilha = appState.trilhaPorId(_trilhaId) ?? kTrilhaJornada;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
              GrutaMedidas.margem, 20, GrutaMedidas.margem, 40),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _trilhaId,
              decoration: const InputDecoration(labelText: 'Onde'),
              dropdownColor: GrutaCores.rocha,
              items: [
                for (final t in trilhas)
                  DropdownMenuItem(
                    value: t.id,
                    child: Row(children: [
                      Icon(t.iconData, color: t.cor, size: 20),
                      const SizedBox(width: 10),
                      Text(t.id == kJornadaId
                          ? 'Jornada (aulas diárias)'
                          : t.titulo),
                    ]),
                  ),
              ],
              onChanged: (v) => setState(() => _trilhaId = v ?? kJornadaId),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: Text('${aulas.length} aulas',
                    style: TextStyle(color: GrutaCores.textoSuave)),
              ),
              TextButton.icon(
                onPressed: () => _editar(
                    context,
                    Aula(
                      id: 'nova-${DateTime.now().millisecondsSinceEpoch}',
                      trilhaId: _trilhaId,
                      ordem: aulas.isEmpty
                          ? (_trilhaId == kJornadaId ? 0 : 1)
                          : aulas.last.ordem + 1,
                      titulo: '',
                      descricao: '',
                      videoUrl: '',
                      duracaoSeg: 300,
                    ),
                    nova: true),
                icon: const Icon(Icons.add),
                label: const Text('Nova aula'),
              ),
            ]),
            const SizedBox(height: 6),
            for (final a in aulas)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CartaoPedra(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  onTap: () => _editar(context, a),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: trilha.cor.withValues(alpha: .15),
                      child: Text('${a.ordem}',
                          style: TextStyle(
                              color: trilha.cor,
                              fontWeight: FontWeight.w800)),
                    ),
                    title: Text(a.titulo.isEmpty ? '(sem título)' : a.titulo),
                    subtitle: Row(children: [
                      _Selinho(Icons.movie_outlined, a.videoUrl.isNotEmpty),
                      const SizedBox(width: 8),
                      _Selinho(Icons.image_outlined, a.capaUrl != null),
                      const SizedBox(width: 8),
                      Text(a.duracaoTexto,
                          style: TextStyle(
                              color: GrutaCores.textoApagado, fontSize: 12)),
                    ]),
                    trailing: Icon(Icons.edit_outlined,
                        color: GrutaCores.textoApagado),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _editar(BuildContext context, Aula aula, {bool nova = false}) =>
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => EditorAulaScreen(aula: aula, nova: nova)));
}

class _Selinho extends StatelessWidget {
  const _Selinho(this.icone, this.tem);
  final IconData icone;
  final bool tem;

  @override
  Widget build(BuildContext context) => Icon(
        tem ? icone : Icons.remove_circle_outline,
        size: 16,
        color: tem ? GrutaCores.musgo : GrutaCores.erro,
      );
}

/// Edita uma aula: textos, vídeo e capa (envio direto para o Storage).
class EditorAulaScreen extends StatefulWidget {
  const EditorAulaScreen({super.key, required this.aula, this.nova = false});
  final Aula aula;
  final bool nova;

  @override
  State<EditorAulaScreen> createState() => _EditorAulaScreenState();
}

class _EditorAulaScreenState extends State<EditorAulaScreen> {
  late final _titulo = TextEditingController(text: widget.aula.titulo);
  late final _descricao = TextEditingController(text: widget.aula.descricao);
  late final _reflexao =
      TextEditingController(text: widget.aula.reflexao ?? '');
  late final _video = TextEditingController(text: widget.aula.videoUrl);
  late final _capa = TextEditingController(text: widget.aula.capaUrl ?? '');
  late final _duracao =
      TextEditingController(text: '${widget.aula.duracaoSeg}');
  String? _enviando; // 'video' | 'capa'
  bool _salvando = false;

  /// Limite do plano gratuito do Supabase por arquivo.
  static const _limiteMb = 50;

  @override
  void dispose() {
    for (final c in [_titulo, _descricao, _reflexao, _video, _capa, _duracao]) {
      c.dispose();
    }
    super.dispose();
  }

  void _avisar(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _enviarArquivo(String qual) async {
    final f = await FilePicker.pickFile(
        type: qual == 'video' ? FileType.video : FileType.image);
    if (f == null) return;
    final tamanho = await f.length() ?? 0;
    if (tamanho > _limiteMb * 1024 * 1024) {
      _avisar('Arquivo com ${(tamanho / 1048576).toStringAsFixed(0)} MB. '
          'O limite atual é $_limiteMb MB por arquivo.');
      return;
    }
    setState(() => _enviando = qual);
    try {
      final bytes = await f.readAsBytes();
      final ext = (f.extension ?? '').toLowerCase();
      final tipo = qual == 'video'
          ? (ext == 'mov' ? 'video/quicktime' : 'video/$ext')
          : (ext == 'jpg' ? 'image/jpeg' : 'image/$ext');
      final url = await appState.enviarArquivo(
          aulaId: widget.aula.id, nome: f.name, bytes: bytes, tipo: tipo);
      (qual == 'video' ? _video : _capa).text = url;
      _avisar(qual == 'video' ? 'Vídeo enviado.' : 'Capa enviada.');
    } catch (e) {
      _avisar(e is UnsupportedError ? '${e.message}' : 'Falhou: $e');
    }
    if (mounted) setState(() => _enviando = null);
  }

  Future<void> _salvar() async {
    if (_titulo.text.trim().isEmpty) return _avisar('A aula precisa de título.');
    setState(() => _salvando = true);
    final a = widget.aula;
    final nova = Aula(
      id: a.id,
      trilhaId: a.trilhaId,
      ordem: a.ordem,
      titulo: _titulo.text.trim(),
      descricao: _descricao.text.trim(),
      videoUrl: _video.text.trim(),
      duracaoSeg: int.tryParse(_duracao.text.trim()) ?? a.duracaoSeg,
      capaUrl: _capa.text.trim().isEmpty ? null : _capa.text.trim(),
      reflexao: _reflexao.text.trim().isEmpty ? null : _reflexao.text.trim(),
    );
    try {
      await appState.salvarAula(nova, nova: widget.nova);
      if (!mounted) return;
      _avisar('Aula salva.');
      Navigator.pop(context);
    } catch (e) {
      _avisar('Não foi possível salvar: $e');
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.aula;
    final trilha = appState.trilhaPorId(a.trilhaId) ?? kTrilhaJornada;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
            '${trilha.titulo} · ${a.ordem == 0 && a.daJornada ? 'Aula piloto' : 'Aula ${a.ordem}'}',
            style: GrutaTema.titulo(24)),
      ),
      body: FundoGruta(
        poeira: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              GrutaMedidas.margem, 12, GrutaMedidas.margem, 40),
          children: [
            TextField(
                controller: _titulo,
                decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 12),
            TextField(
                controller: _descricao,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Descrição')),
            const SizedBox(height: 12),
            TextField(
                controller: _reflexao,
                decoration: const InputDecoration(
                    labelText: 'Pergunta para o Grimório (opcional)')),
            const SizedBox(height: 12),
            TextField(
                controller: _duracao,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Duração (segundos)')),
            const SizedBox(height: 24),
            const Olho('Vídeo'),
            const SizedBox(height: 8),
            TextField(
                controller: _video,
                decoration: const InputDecoration(
                    labelText: 'Endereço do vídeo (.mp4)')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _enviando != null ? null : () => _enviarArquivo('video'),
              icon: _enviando == 'video'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              label: Text(_enviando == 'video'
                  ? 'Enviando...'
                  : 'Enviar vídeo do computador'),
            ),
            const SizedBox(height: 24),
            const Olho('Capa'),
            const SizedBox(height: 8),
            TextField(
                controller: _capa,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Endereço da imagem')),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _enviando != null ? null : () => _enviarArquivo('capa'),
              icon: _enviando == 'capa'
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                  _enviando == 'capa' ? 'Enviando...' : 'Enviar imagem de capa'),
            ),
            const SizedBox(height: 12),
            CapaAula(
              aula: a.copyWith(
                  titulo: _titulo.text,
                  capaUrl: _capa.text.trim().isEmpty ? null : _capa.text.trim()),
              trilha: trilha,
              altura: 160,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _salvando || _enviando != null ? null : _salvar,
              child: Text(widget.nova ? 'Criar aula' : 'Salvar aula'),
            ),
          ],
        ),
      ),
    );
  }
}
