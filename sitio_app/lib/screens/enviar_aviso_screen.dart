import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin escreve título e descrição; todos os aparelhos da equipe
/// (adm, staff, freelancer e cozinha) recebem na hora, com o app aberto ou não.
class EnviarAvisoScreen extends StatefulWidget {
  const EnviarAvisoScreen({super.key});

  @override
  State<EnviarAvisoScreen> createState() => _EnviarAvisoScreenState();
}

class _EnviarAvisoScreenState extends State<EnviarAvisoScreen> {
  final _titulo = TextEditingController();
  final _corpo = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _corpo.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final t = _titulo.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Escreva um título.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Enviar para todos?'),
        content: const Text(
            'O aviso chega agora em todos os aparelhos da equipe.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _enviando = true);
    try {
      await Supabase.instance.client.rpc('enviar_aviso_geral',
          params: {'p_titulo': t, 'p_corpo': _corpo.text.trim()});
      if (!mounted) return;
      _titulo.clear();
      _corpo.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Notificação enviada.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar: $e')));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titulo,
            maxLength: 80,
            decoration: const InputDecoration(
                labelText: 'Título', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _corpo,
            maxLength: 300,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
                labelText: 'Descrição', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _enviando ? null : _enviar,
            icon: const Icon(Icons.send),
            label: Text(_enviando ? 'Enviando...' : 'Enviar para todos'),
          ),
        ],
      ),
    );
  }
}
