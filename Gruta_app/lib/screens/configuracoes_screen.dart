import 'package:material_ui/material_ui.dart';

import '../logic/datas.dart';
import '../state/app_state.dart';
import '../state/auth_state.dart';
import '../state/tema_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/fundo_gruta.dart';
import '../widgets/pecas.dart';
import '../widgets/tutorial.dart';
import 'abertura_screen.dart';
import 'shell_screen.dart';

/// Engrenagem do Perfil: nome de exibição, dados do cadastro e tema.
class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Configurações', style: GrutaTema.titulo(26)),
      ),
      extendBodyBehindAppBar: false,
      body: FundoGruta(
        poeira: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([appState, temaState]),
          builder: (context, _) {
            final p = appState.perfil;
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                  GrutaMedidas.margem, 12, GrutaMedidas.margem, 40),
              children: [
                const Olho('Você'),
                const SizedBox(height: 10),
                CartaoPedra(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    ListTile(
                      leading: Icon(Icons.badge_outlined,
                          color: GrutaCores.chama),
                      title: const Text('Nome de exibição'),
                      subtitle: Text(p.nome.isEmpty ? 'Não definido' : p.nome,
                          style: TextStyle(color: GrutaCores.textoSuave)),
                      trailing: Icon(Icons.chevron_right,
                          color: GrutaCores.textoApagado),
                      onTap: () => _editarNome(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.interests_outlined,
                          color: GrutaCores.chama),
                      title: const Text('Interesses e ritual diário'),
                      subtitle: Text(
                          '${p.trilhasInteresse.length} áreas · '
                          '${p.metaMinutos} min por dia',
                          style: TextStyle(color: GrutaCores.textoSuave)),
                      trailing: Icon(Icons.chevron_right,
                          color: GrutaCores.textoApagado),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const AberturaScreen(editar: true))),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.tips_and_updates_outlined,
                          color: GrutaCores.chama),
                      title: const Text('Rever tutorial do app'),
                      subtitle: Text('O passeio rápido por cada parte da Gruta',
                          style: TextStyle(color: GrutaCores.textoSuave)),
                      trailing: Icon(Icons.chevron_right,
                          color: GrutaCores.textoApagado),
                      onTap: () async {
                        final nav = Navigator.of(context);
                        nav.popUntil((r) => r.isFirst);
                        ShellScreen.aba.value = 0;
                        await Future<void>.delayed(
                            const Duration(milliseconds: 400));
                        await mostrarTutorial(nav);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.assignment_ind_outlined,
                          color: GrutaCores.chama),
                      title: const Text('Dados do cadastro'),
                      subtitle: Text('Nome completo, nascimento e senha',
                          style: TextStyle(color: GrutaCores.textoSuave)),
                      trailing: Icon(Icons.chevron_right,
                          color: GrutaCores.textoApagado),
                      onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const DadosCadastroScreen())),
                    ),
                  ]),
                ),
                const SizedBox(height: 28),
                const Olho('Aparência'),
                const SizedBox(height: 10),
                CartaoPedra(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(children: [
                    for (final (modo, icone, titulo, sub) in const [
                      (ThemeMode.dark, Icons.dark_mode_outlined, 'Escuro',
                          'A gruta à luz de velas'),
                      (ThemeMode.light, Icons.light_mode_outlined, 'Claro',
                          'Pergaminho à luz do dia'),
                      (ThemeMode.system, Icons.brightness_auto_outlined,
                          'Seguir o aparelho', 'Muda junto com o celular'),
                    ])
                      ListTile(
                        leading: Icon(icone, color: GrutaCores.chama),
                        title: Text(titulo),
                        subtitle: Text(sub,
                            style: TextStyle(color: GrutaCores.textoSuave)),
                        trailing: temaState.modo == modo
                            ? Icon(Icons.check_circle,
                                color: GrutaCores.chama)
                            : Icon(Icons.circle_outlined,
                                color: GrutaCores.linha),
                        onTap: () => temaState.escolher(modo),
                      ),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _editarNome(BuildContext context) async {
    final c = TextEditingController(text: appState.perfil.nome);
    final nome = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GrutaCores.rocha,
        title: const Text('Nome de exibição'),
        content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 30,
            textCapitalization: TextCapitalization.words,
            decoration:
                const InputDecoration(hintText: 'Como a Gruta chama você')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, c.text.trim()),
              child: const Text('Salvar')),
        ],
      ),
    );
    c.dispose();
    if (nome != null && nome.isNotEmpty) {
      await appState.salvarPerfil(appState.perfil.copyWith(nome: nome));
    }
  }
}

/// Dados do cadastro: nome completo, nascimento, usuário (só leitura) e senha.
class DadosCadastroScreen extends StatefulWidget {
  const DadosCadastroScreen({super.key});

  @override
  State<DadosCadastroScreen> createState() => _DadosCadastroScreenState();
}

class _DadosCadastroScreenState extends State<DadosCadastroScreen> {
  late final _nome =
      TextEditingController(text: appState.perfil.nomeCompleto);
  final _senha = TextEditingController();
  late final _telefone = TextEditingController(text: appState.perfil.telefone);
  late final _email = TextEditingController(text: appState.perfil.email);
  late DateTime? _nascimento = appState.perfil.nascimento;
  bool _ocupado = false;

  @override
  void dispose() {
    _nome.dispose();
    _senha.dispose();
    _telefone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _avisar(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _salvar() async {
    // Contas antigas podem estar sem contato: só confere o que foi preenchido.
    if (_telefone.text.trim().isNotEmpty) {
      final erroTel = AuthState.validarTelefone(_telefone.text);
      if (erroTel != null) return _avisar(erroTel);
    }
    if (_email.text.trim().isNotEmpty) {
      final erroEmail = AuthState.validarEmail(_email.text);
      if (erroEmail != null) return _avisar(erroEmail);
    }
    setState(() => _ocupado = true);
    await appState.salvarPerfil(appState.perfil.copyWith(
        nomeCompleto: _nome.text.trim(),
        nascimento: _nascimento,
        telefone: _telefone.text.trim(),
        email: _email.text.trim().toLowerCase()));
    String? erro;
    if (_senha.text.isNotEmpty) erro = await authState.alterarSenha(_senha.text);
    if (!mounted) return;
    setState(() => _ocupado = false);
    if (erro != null) return _avisar(erro);
    _avisar('Dados salvos.');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final login = appState.perfil.login.isNotEmpty
        ? appState.perfil.login
        : (authState.login ?? '—');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Dados do cadastro', style: GrutaTema.titulo(26)),
      ),
      body: FundoGruta(
        poeira: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              GrutaMedidas.margem, 12, GrutaMedidas.margem, 40),
          children: [
            TextField(
              controller: _nome,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                  labelText: 'Nome completo',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _nascimento ?? DateTime(2000),
                  firstDate: DateTime(1920),
                  lastDate: DateTime.now(),
                  initialEntryMode: DatePickerEntryMode.input,
                );
                if (d != null) setState(() => _nascimento = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Data de nascimento',
                    prefixIcon: Icon(Icons.cake_outlined)),
                child: Text(_nascimento == null
                    ? 'Toque para escolher'
                    : dataCurta(_nascimento!)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                  labelText: 'Telefone (com DDD)',
                  prefixIcon: Icon(Icons.phone_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: Icon(Icons.mail_outline)),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Usuário (não muda)',
                  prefixIcon: Icon(Icons.alternate_email)),
              child: Text(login,
                  style: TextStyle(color: GrutaCores.textoSuave)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _senha,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                  labelText: 'Nova senha (deixe em branco para manter)',
                  prefixIcon: Icon(Icons.lock_outline)),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _ocupado ? null : _salvar,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
