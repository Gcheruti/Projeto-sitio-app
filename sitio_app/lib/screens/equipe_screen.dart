import '../models/icones_freelancer.dart';
import '../services/auditoria.dart';
import 'package:flutter/material.dart';

import '../models/usuario.dart';
import '../services/supabase_repository.dart';
import '../state/auth_state.dart';
import 'freelancer_agenda_screen.dart';
import 'permissoes_screen.dart';
import 'freelancer_agenda_geral_screen.dart';

/// Manutenção de equipe (só Adm): lista e edita cadastros de acesso.
class EquipeScreen extends StatefulWidget {
  const EquipeScreen({super.key});

  @override
  State<EquipeScreen> createState() => _EquipeScreenState();
}

class _EquipeScreenState extends State<EquipeScreen> {
  final _repo = SupabaseRepository();
  List<Usuario> _lista = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final l = await _repo.fetchUsuarios();
      if (!mounted) return;
      setState(() => _lista = l);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro =
          'Não foi possível carregar. A tabela "usuarios" existe no Supabase?');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _editar([Usuario? u, String? papelNovo]) async {
    final nome = TextEditingController(text: u?.nome ?? '');
    final login = TextEditingController(text: u?.login ?? '');
    final senha = TextEditingController();
    var papel = u?.papel ?? papelNovo ?? 'staff';
    final souEu = u != null && u.id == authState.usuario?.id;
    String? erro;
    var ver = false;
    var salvando = false;

    // Ícone do freelancer (agenda geral). Os já usados por outros ficam bloqueados.
    final freelas = _lista.where((x) => x.isFreelancer).toList();
    final usadosPorOutros = <String>{
      for (var i = 0; i < freelas.length; i++)
        if (u == null || freelas[i].id != u.id) chaveIconeFreela(freelas[i], i),
    };
    final idxU = u == null ? -1 : freelas.indexWhere((x) => x.id == u.id);
    String iconeSel = u != null && idxU >= 0
        ? chaveIconeFreela(u, idxU)
        : kIconesFreela.keys.firstWhere((k) => !usadosPorOutros.contains(k),
            orElse: () => kIconesFreela.keys.first);

    final salvou = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(papel == 'freelancer'
              ? (u == null ? 'Novo freelancer' : 'Editar freelancer')
              : (u == null ? 'Novo cadastro' : 'Editar cadastro')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                TextField(
                  controller: login,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: 'Login'),
                ),
                TextField(
                  controller: senha,
                  obscureText: !ver,
                  decoration: InputDecoration(
                    labelText: u == null ? 'Senha' : 'Nova senha (vazio = manter)',
                    suffixIcon: IconButton(
                      icon: Icon(ver ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setD(() => ver = !ver),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (papel == 'freelancer') ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Ícone na agenda',
                        style: Theme.of(ctx).textTheme.labelLarge),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 280,
                    height: 190,
                    child: GridView.count(
                      crossAxisCount: 6,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                      children: [
                        for (final e in kIconesFreela.entries)
                          Builder(builder: (_) {
                            final sel = iconeSel == e.key;
                            final ocupado = usadosPorOutros.contains(e.key);
                            final cor = Theme.of(ctx).colorScheme;
                            return InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: ocupado
                                  ? null
                                  : () => setD(() => iconeSel = e.key),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: sel ? cor.primaryContainer : null,
                                  border: Border.all(
                                      color: sel ? cor.primary : cor.outlineVariant),
                                ),
                                child: Icon(e.value,
                                    size: 22,
                                    color: ocupado
                                        ? cor.onSurface.withOpacity(0.2)
                                        : (sel ? cor.primary : cor.onSurface)),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Ícones apagados já são de outro freelancer.',
                        style: TextStyle(fontSize: 11)),
                  ),
                ],
                if (papel != 'freelancer')
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'staff', label: Text('Staff')),
                    ButtonSegment(value: 'adm', label: Text('Adm')),
                    ButtonSegment(value: 'totem', label: Text('Totem')),
                    ButtonSegment(value: 'cozinha', label: Text('Cozinha')),
                  ],
                  selected: {papel},
                  onSelectionChanged:
                      souEu ? null : (s) => setD(() => papel = s.first),
                ),
                if (souEu)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Você não pode mudar o próprio tipo de conta.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (erro != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(erro!,
                        style:
                            TextStyle(color: Theme.of(ctx).colorScheme.error)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: salvando
                  ? null
                  : () async {
                      final n = nome.text.trim();
                      final l = login.text.trim();
                      if (n.isEmpty || l.isEmpty) {
                        setD(() => erro = 'Preencha nome e login.');
                        return;
                      }
                      if (u == null && senha.text.isEmpty) {
                        setD(() => erro = 'Defina uma senha.');
                        return;
                      }
                      // Não deixar o app sem nenhum Adm.
                      if (u != null && u.isAdm && papel != 'adm') {
                        final adms =
                            _lista.where((x) => x.isAdm && x.ativo).length;
                        if (adms <= 1) {
                          setD(() => erro = 'Precisa existir ao menos 1 Adm.');
                          return;
                        }
                      }
                      setD(() {
                        salvando = true;
                        erro = null;
                      });
                      try {
                        final hash =
                            senha.text.isEmpty ? null : hashSenha(senha.text);
                        if (u == null) {
                          await _repo.inserirUsuario(
                            nome: n,
                            login: l,
                            senhaHash: hash!,
                            papel: papel,
                            icone: papel == 'freelancer' ? iconeSel : null,
                          );
                          Auditoria.registrar('equipe_criada',
                              'Criou o cadastro de $n ($papel)',
                              entidade: 'equipe');
                        } else {
                          await _repo.atualizarUsuario(
                            u.id,
                            nome: n,
                            login: l,
                            papel: papel,
                            senhaHash: hash,
                            icone: papel == 'freelancer' ? iconeSel : null,
                          );
                          Auditoria.registrar('equipe_editada',
                              'Editou o cadastro de $n ($papel)',
                              entidade: 'equipe');
                          if (souEu) {
                            await authState.atualizarSessao(Usuario(
                              id: u.id,
                              nome: n,
                              login: l,
                              papel: papel,
                              icone: u.icone,
                            ));
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        final dup = e.toString().contains('usuarios_login_unico') ||
                            e.toString().contains('duplicate');
                        setD(() {
                          salvando = false;
                          erro = dup
                              ? 'Esse login já existe.'
                              : 'Não foi possível salvar.';
                        });
                      }
                    },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (salvou == true) _carregar();
  }

  List<Usuario> get _admins => _lista.where((u) => !u.isFreelancer).toList();
  List<Usuario> get _freelancers => _lista.where((u) => u.isFreelancer).toList();

  Widget _corpo(List<Usuario> itens, Widget Function(Usuario) tile, String vazio) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_erro!, textAlign: TextAlign.center),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: itens.isEmpty
          ? ListView(children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(vazio, textAlign: TextAlign.center),
              ),
            ])
          : ListView.separated(
              itemCount: itens.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => tile(itens[i]),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manutenção de equipe'),
          actions: [
            IconButton(
              tooltip: 'Permissões de acesso',
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PermissoesScreen()),
              ),
            ),
          ],
          bottom: const TabBar(tabs: [Tab(text: 'ADM'), Tab(text: 'Freelancer')]),
        ),
        body: TabBarView(
          children: [
            Scaffold(
              floatingActionButton: FloatingActionButton(
                heroTag: 'novo_adm',
                onPressed: () => _editar(),
                tooltip: 'Novo cadastro',
                child: const Icon(Icons.person_add_alt),
              ),
              body: _corpo(
                _admins,
                (u) => ListTile(
                  leading: CircleAvatar(
                    child: Icon(u.isAdm
                        ? Icons.admin_panel_settings_outlined
                        : Icons.person_outline),
                  ),
                  title: Text(u.nome),
                  subtitle: Text('Login: ${u.login}'),
                  trailing: Chip(label: Text(u.papelTexto)),
                  onTap: () => _editar(u),
                ),
                'Nenhum cadastro.',
              ),
            ),
            Scaffold(
              floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
              floatingActionButton: SizedBox(
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 32),
                      child: FloatingActionButton(
                        heroTag: 'agenda_freela',
                        tooltip: 'Agenda dos freelancers',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FreelancerAgendaGeralScreen()),
                        ),
                        child: const Icon(Icons.calendar_month),
                      ),
                    ),
                    FloatingActionButton(
                      heroTag: 'novo_freela',
                      onPressed: () => _editar(null, 'freelancer'),
                      tooltip: 'Novo freelancer',
                      child: const Icon(Icons.person_add_alt),
                    ),
                  ],
                ),
              ),
              body: _corpo(
                _freelancers,
                (u) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.badge_outlined)),
                  title: Text(u.nome),
                  subtitle: Text('Login: ${u.login}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar cadastro',
                    onPressed: () => _editar(u),
                  ),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => FreelancerAgendaScreen(freelancer: u),
                    ));
                  },
                ),
                'Nenhum freelancer cadastrado. Use o botão + para adicionar.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
