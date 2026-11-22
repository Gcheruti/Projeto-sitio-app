import 'package:material_ui/material_ui.dart';

import '../logic/datas.dart';
import '../models/plano.dart';
import '../state/auth_state.dart';
import '../theme/gruta_tema.dart';
import '../widgets/fundo_gruta.dart';
import '../widgets/pecas.dart';
import '../widgets/vela.dart';
import 'planos_sheet.dart';

/// Entrar (usuário e senha) e criar conta (nome completo, nascimento,
/// usuário, senha e plano).
class EntrarScreen extends StatefulWidget {
  const EntrarScreen({super.key});

  @override
  State<EntrarScreen> createState() => _EntrarScreenState();
}

class _EntrarScreenState extends State<EntrarScreen> {
  bool _criando = true; // primeira vez no app: começa pelo cadastro
  int _passo = 0; // cadastro: 0 = dados, 1 = plano
  bool _ocupado = false;
  bool _verSenha = false;
  String? _mensagem;
  DateTime? _nascimento;
  Plano _plano = Plano.visitante;
  final _nomeCompleto = TextEditingController();
  final _login = TextEditingController();
  final _senha = TextEditingController();
  final _telefone = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _telefone.dispose();
    _email.dispose();
    _nomeCompleto.dispose();
    _login.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _erro(String? m) => setState(() => _mensagem = m);

  /// Confere o passo 1 do cadastro antes de mostrar os planos.
  void _avancar() {
    if (_nomeCompleto.text.trim().split(RegExp(r'\s+')).length < 2) {
      return _erro('Escreva seu nome completo (nome e sobrenome).');
    }
    if (_nascimento == null) return _erro('Informe sua data de nascimento.');
    final idade = DateTime.now().difference(_nascimento!).inDays ~/ 365;
    if (idade < 13) return _erro('A Gruta é para maiores de 13 anos.');
    final t = AuthState.validarTelefone(_telefone.text);
    if (t != null) return _erro(t);
    final e = AuthState.validarEmail(_email.text);
    if (e != null) return _erro(e);
    final l = AuthState.validarLogin(_login.text);
    if (l != null) return _erro(l);
    if (_senha.text.length < 6) {
      return _erro('A senha precisa ter 6 caracteres ou mais.');
    }
    setState(() {
      _mensagem = null;
      _passo = 1;
    });
  }

  Future<void> _enviar() async {
    setState(() {
      _ocupado = true;
      _mensagem = null;
    });
    final msg = _criando
        ? await authState.cadastrar(Cadastro(
            nomeCompleto: _nomeCompleto.text,
            nascimento: _nascimento!,
            login: _login.text,
            senha: _senha.text,
            plano: _plano,
            telefone: _telefone.text,
            email: _email.text,
          ))
        : await authState.entrar(_login.text, _senha.text);
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _mensagem = msg;
      if (msg != null && _criando && msg.contains('usuário')) _passo = 0;
    });
  }

  Future<void> _escolherNascimento() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _nascimento ?? DateTime(hoje.year - 25),
      firstDate: DateTime(1920),
      lastDate: hoje,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: 'Data de nascimento',
    );
    if (d != null) setState(() => _nascimento = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FundoGruta(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              const Center(child: Vela(acesa: true, tamanho: 84)),
              const SizedBox(height: 14),
              Center(child: Text('Gruta', style: GrutaTema.titulo(48))),
              const SizedBox(height: 2),
              Center(
                child: Text('Escola de saberes antigos',
                    style: TextStyle(color: GrutaCores.textoSuave)),
              ),
              const SizedBox(height: 28),
              if (authState.modoDemo) ...[
                CartaoPedra(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Modo demonstração: o app ainda não está ligado ao banco. '
                    'A conta e o progresso ficam só neste aparelho.',
                    style: TextStyle(
                        color: GrutaCores.textoSuave,
                        height: 1.45,
                        fontSize: 13),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Criar conta')),
                  ButtonSegment(value: false, label: Text('Entrar')),
                ],
                selected: {_criando},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _criando = s.first;
                  _mensagem = null;
                }),
              ),
              const SizedBox(height: 20),
              if (!_criando)
                ..._entrar()
              else if (_passo == 0)
                ..._dados()
              else
                ..._planos(),
              if (_mensagem != null) ...[
                const SizedBox(height: 14),
                Text(_mensagem!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: GrutaCores.erro, height: 1.4)),
              ],
              const SizedBox(height: 18),
              _botaoPrincipal(),
              if (_criando && _passo == 1)
                TextButton(
                    onPressed: () => setState(() => _passo = 0),
                    child: const Text('Voltar aos dados')),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.g_mobiledata, size: 28),
                label: const Text('Entrar com Google (em breve)'),
              ),
              if (authState.modoDemo)
                TextButton(
                  onPressed: authState.entrarDemo,
                  child: const Text('Explorar sem conta'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoPrincipal() {
    final texto = !_criando
        ? 'Entrar'
        : _passo == 0
            ? 'Continuar'
            : 'Criar conta';
    return FilledButton(
      onPressed: _ocupado ? null : (_criando && _passo == 0 ? _avancar : _enviar),
      child: _ocupado
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5))
          : Text(texto),
    );
  }

  Widget _campoLogin() => TextField(
        controller: _login,
        autocorrect: false,
        autofillHints: const [AutofillHints.username],
        decoration: const InputDecoration(
          labelText: 'Usuário',
          prefixIcon: Icon(Icons.alternate_email),
        ),
      );

  Widget _campoSenha() => TextField(
        controller: _senha,
        obscureText: !_verSenha,
        autofillHints: [
          _criando ? AutofillHints.newPassword : AutofillHints.password
        ],
        onSubmitted: (_) => _criando ? _avancar() : _enviar(),
        decoration: InputDecoration(
          labelText: 'Senha',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_verSenha ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _verSenha = !_verSenha),
          ),
        ),
      );

  List<Widget> _entrar() => [
        _campoLogin(),
        const SizedBox(height: 12),
        _campoSenha(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _erro(
                'Para trocar a senha, fale com a equipe da Gruta. Depois de '
                'entrar, você pode mudar a senha em Perfil > Configurações.'),
            child: const Text('Esqueci minha senha'),
          ),
        ),
      ];

  List<Widget> _dados() => [
        TextField(
          controller: _nomeCompleto,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
          decoration: const InputDecoration(
            labelText: 'Nome completo',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _escolherNascimento,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Data de nascimento',
              prefixIcon: Icon(Icons.cake_outlined),
            ),
            child: Text(
              _nascimento == null ? 'Toque para escolher' : dataCurta(_nascimento!),
              style: TextStyle(
                  color: _nascimento == null
                      ? GrutaCores.textoApagado
                      : GrutaCores.pergaminho),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _telefone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          decoration: const InputDecoration(
            labelText: 'Telefone (com DDD)',
            hintText: '(11) 91234-5678',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'E-mail',
            prefixIcon: Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 12),
        _campoLogin(),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text('É com ele que você entra. Letras, números, ponto ou _.',
              style: TextStyle(color: GrutaCores.textoApagado, fontSize: 12)),
        ),
        const SizedBox(height: 12),
        _campoSenha(),
      ];

  List<Widget> _planos() => [
        const Olho('Escolha seu plano'),
        const SizedBox(height: 10),
        for (final p in Plano.values) ...[
          CartaoPlano(
            plano: p,
            selecionado: _plano == p,
            onEscolher: p.disponivel ? () => setState(() => _plano = p) : null,
          ),
          const SizedBox(height: 10),
        ],
        Text('Dá para mudar de plano depois, no Perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: GrutaCores.textoApagado, fontSize: 12.5)),
      ];
}
