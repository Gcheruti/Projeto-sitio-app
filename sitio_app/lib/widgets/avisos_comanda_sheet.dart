import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/evento_agenda.dart';
import '../services/auditoria.dart';
import '../services/avisos_admin.dart';
import '../state/auth_state.dart';

/// Caixa de avisos de uma comanda (ex.: troca de refrigerante X por Y).
/// Cada aviso de staff/freelancer também alerta os administradores.
class AvisosComandaSheet extends StatefulWidget {
  const AvisosComandaSheet({super.key, required this.codigo});

  final String codigo;

  @override
  State<AvisosComandaSheet> createState() => _AvisosComandaSheetState();
}

class _AvisosComandaSheetState extends State<AvisosComandaSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _avisos = [];
  String? _erro;
  bool _enviando = false;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final rows = await _db
          .from('comanda_avisos')
          .select()
          .eq('comanda_codigo', widget.codigo)
          .order('criado_em');
      if (!mounted) return;
      setState(() {
        _avisos = (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
        _erro = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Não foi possível carregar (rode supabase/comandas_v2.sql).');
    }
  }

  Future<void> _enviar() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      await _db.from('comanda_avisos').insert({
        'comanda_codigo': widget.codigo,
        'texto': t,
        'criado_por': authState.usuario?.nome,
      });
      Auditoria.registrar('comanda_aviso', 'Aviso na comanda ${widget.codigo}: $t',
          entidade: 'comanda', comanda: widget.codigo);
      AvisosAdmin.notificar('Aviso na comanda ${widget.codigo}', t);
      _ctrl.clear();
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aviso NÃO foi salvo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Avisos • comanda ${widget.codigo}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (_erro != null)
            Text(_erro!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (_avisos.isEmpty && _erro == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Nenhum aviso nesta comanda.'),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final a in _avisos)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${a['texto']}'),
                    subtitle: Text([
                      if (a['criado_por'] != null) '${a['criado_por']}',
                      if (a['criado_em'] != null)
                        formatarHora(DateTime.parse('${a['criado_em']}').toLocal()),
                    ].join(' • ')),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  decoration: const InputDecoration(
                    hintText: 'Ex.: trocou Coca por Guaraná',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _enviar(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _enviando ? null : _enviar,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
