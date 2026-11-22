import 'package:flutter/material.dart';

import '../models/notificacao.dart';
import '../services/auditoria.dart';
import '../state/auth_state.dart';

/// Tela cheia da notificação: ver, editar, ativar/desativar e excluir.
class NotificacaoDetalheScreen extends StatefulWidget {
  const NotificacaoDetalheScreen({
    super.key,
    required this.notificacao,
    required this.onChanged,
  });

  final Notificacao notificacao;
  final VoidCallback onChanged;

  @override
  State<NotificacaoDetalheScreen> createState() => _DetalheState();
}

class _DetalheState extends State<NotificacaoDetalheScreen> {
  late final TextEditingController _titulo;
  late final TextEditingController _desc;
  late String? _local;
  late bool _ativa;

  @override
  void initState() {
    super.initState();
    final n = widget.notificacao;
    _titulo = TextEditingController(text: n.titulo);
    _desc = TextEditingController(text: n.descricao);
    _local = n.local;
    _ativa = n.ativa;
  }

  @override
  void dispose() {
    _titulo.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _salvar() {
    final t = _titulo.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Informe um título.')));
      return;
    }
    final n = widget.notificacao;
    n
      ..titulo = t
      ..descricao = _desc.text.trim()
      ..local = _local
      ..ativa = _ativa
      ..editadoPor = authState.usuario?.nome;
    widget.onChanged();
    Auditoria.registrar('notificacao_editada', 'Editou "$t"',
        entidade: 'notificacao');
    Navigator.pop(context);
  }

  void _excluir() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir notificação?'),
        content: const Text(
            'Ela some do aplicativo, mas o registro continua guardado no Supabase.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final n = widget.notificacao;
              n
                ..excluida = true
                ..ativa = false
                ..editadoPor = authState.usuario?.nome;
              widget.onChanged();
              Auditoria.registrar('notificacao_excluida',
                  'Excluiu "${n.titulo}"',
                  entidade: 'notificacao');
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notificacao;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificação'),
        actions: [
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: _excluir,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titulo,
            decoration: const InputDecoration(
                labelText: 'Título', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 6,
            decoration: const InputDecoration(
                labelText: 'Descrição', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _local,
            decoration: const InputDecoration(
                labelText: 'Local', border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: null, child: Text('Geral')),
              ...kLocais.entries.map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value))),
            ],
            onChanged: (v) => setState(() => _local = v),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ativa'),
            value: _ativa,
            onChanged: (v) => setState(() => _ativa = v),
          ),
          const SizedBox(height: 8),
          if (n.criadoPor != null) Text('Criada por: ${n.criadoPor}'),
          if (n.editadoPor != null) Text('Última edição por: ${n.editadoPor}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _salvar,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
