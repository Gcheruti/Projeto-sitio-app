import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/auditoria.dart';
import '../services/supabase_repository.dart';
import '../widgets/filtro_periodo.dart';

/// Lista de colaboradores; ao tocar, mostra tudo que a pessoa fez no app.
class RelatorioColaboradoresScreen extends StatefulWidget {
  const RelatorioColaboradoresScreen({super.key});

  @override
  State<RelatorioColaboradoresScreen> createState() => _ColabState();
}

class _ColabState extends State<RelatorioColaboradoresScreen> {
  final _repo = SupabaseRepository();
  List<Usuario>? _lista;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final l = await _repo.fetchUsuarios();
      if (mounted) setState(() => _lista = l);
    } catch (_) {
      if (mounted) setState(() => _erro = 'Não foi possível carregar a equipe.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = _lista;
    return Scaffold(
      appBar: AppBar(title: const Text('Colaboradores')),
      body: _erro != null
          ? Center(child: Text(_erro!))
          : l == null
              ? const Center(child: CircularProgressIndicator())
              : l.isEmpty
                  ? const Center(child: Text('🕯️ Nenhum colaborador cadastrado.'))
                  : ListView.separated(
                      itemCount: l.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final u = l[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(u.nome.isEmpty
                                ? '?'
                                : u.nome[0].toUpperCase()),
                          ),
                          title: Text(u.nome),
                          subtitle: Text(
                              '${u.login} · ${u.isAdm ? 'Adm' : 'Staff'}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => ColaboradorMovimentosScreen(u)),
                          ),
                        );
                      },
                    ),
    );
  }
}

class ColaboradorMovimentosScreen extends StatefulWidget {
  const ColaboradorMovimentosScreen(this.usuario, {super.key});
  final Usuario usuario;

  @override
  State<ColaboradorMovimentosScreen> createState() => _MovState();
}

class _MovState extends State<ColaboradorMovimentosScreen> {
  final _repo = SupabaseRepository();
  PeriodoSel _periodo = const PeriodoSel(PeriodoTipo.dias7);
  List<Map<String, dynamic>>? _itens;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _itens = null;
      _erro = null;
    });
    try {
      final r = await _repo.fetchAtividades(
        usuarioId: widget.usuario.id,
        inicio: _periodo.inicio,
        fim: _periodo.fim,
      );
      if (mounted) setState(() => _itens = r);
    } catch (_) {
      if (mounted) {
        setState(() => _erro =
            'Não foi possível carregar. A tabela "atividades" foi criada no Supabase?');
      }
    }
  }

  String _hora(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    return '${fmtData(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final itens = _itens;
    return Scaffold(
      appBar: AppBar(title: Text(widget.usuario.nome)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: FiltroPeriodo(
              selecionado: _periodo,
              onChanged: (p) {
                _periodo = p;
                _carregar();
              },
            ),
          ),
          Expanded(
            child: _erro != null
                ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_erro!)))
                : itens == null
                    ? const Center(child: CircularProgressIndicator())
                    : itens.isEmpty
                        ? const Center(
                            child: Text('🕯️ Nenhuma movimentação no período.'))
                        : ListView.separated(
                            itemCount: itens.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final a = itens[i];
                              final acao = a['acao']?.toString() ?? '';
                              return ListTile(
                                dense: true,
                                title: Text(kAcoes[acao] ?? acao),
                                subtitle: Text(a['detalhe']?.toString() ?? ''),
                                trailing: Text(_hora(a['criado_em']?.toString()),
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
