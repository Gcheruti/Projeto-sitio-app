import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/plano.dart';
import '../models/progresso.dart';
import '../services/registro.dart';
import '../services/repositorio_local.dart';

/// Dados do formulário de cadastro.
class Cadastro {
  const Cadastro({
    required this.nomeCompleto,
    required this.nascimento,
    required this.login,
    required this.senha,
    required this.plano,
    this.telefone = '',
    this.email = '',
  });
  final String nomeCompleto;
  final DateTime nascimento;
  final String login;
  final String telefone;
  final String email;
  final String senha;
  final Plano plano;

  /// Primeiro nome, usado como nome de exibição.
  String get primeiroNome => nomeCompleto.trim().split(RegExp(r'\s+')).first;
}

/// Login por USUÁRIO e senha.
///
/// Com Supabase: o usuário vira um e-mail interno (`login@usuarios.gruta.app`)
/// só para o Supabase Auth; ninguém recebe e-mail. A conta é criada pela
/// função `gruta-cadastro` (já confirmada), porque o projeto Supabase é
/// compartilhado e exige confirmação de e-mail para os outros apps.
///
/// No modo demonstração: as contas ficam só neste aparelho.
class AuthState extends ChangeNotifier {
  static const _kAberturaVista = 'gruta_abertura_vista';
  static const _kDemoLogado = 'gruta_demo_logado';
  static const _kDemoContas = 'gruta_demo_contas';

  static const dominioInterno = 'usuarios.gruta.app';

  bool aberturaVista = false;

  /// true logo depois de um login feito agora (e não de uma sessão que já
  /// estava salva). Serve para o registro separar "login" de "app aberto".
  bool acabouDeEntrar = false;
  bool _demoLogado = false;

  bool get modoDemo => !AppConfig.temSupabase;

  bool get logado => modoDemo
      ? _demoLogado
      : Supabase.instance.client.auth.currentSession != null;

  /// O usuário de quem está logado.
  String? get login {
    if (modoDemo) return null;
    final e = Supabase.instance.client.auth.currentUser?.email;
    return e?.split('@').first;
  }

  static String normalizar(String login) => login.trim().toLowerCase();

  /// Regra do usuário: 3 a 20 letras minúsculas, números, ponto ou _.
  static String? validarLogin(String login) {
    final l = normalizar(login);
    if (l.length < 3) return 'O usuário precisa ter 3 caracteres ou mais.';
    if (l.length > 20) return 'O usuário pode ter até 20 caracteres.';
    if (!RegExp(r'^[a-z0-9._]+$').hasMatch(l)) {
      return 'Use só letras sem acento, números, ponto ou _.';
    }
    return null;
  }

  /// Telefone com DDD: 10 a 13 dígitos (aceita +55, espaços, parênteses e -).
  static String? validarTelefone(String t) {
    final digitos = t.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[0-9+()\s.-]*$').hasMatch(t.trim()) ||
        digitos.length < 10 ||
        digitos.length > 13) {
      return 'Informe um telefone com DDD, ex.: (11) 91234-5678.';
    }
    return null;
  }

  static String? validarEmail(String e) {
    final v = e.trim();
    if (v.length > 160 ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Informe um e-mail válido.';
    }
    return null;
  }

  static String emailDe(String login) => '${normalizar(login)}@$dominioInterno';

  Future<void> restaurar() async {
    final p = await SharedPreferences.getInstance();
    aberturaVista = p.getBool(_kAberturaVista) ?? false;
    _demoLogado = p.getBool(_kDemoLogado) ?? false;
    if (!modoDemo) {
      Supabase.instance.client.auth.onAuthStateChange
          .listen((_) => notifyListeners());
    }
  }

  // ---------- tutorial da primeira entrada ----------

  static const _kTutorial = 'gruta_tutorial_visto_';
  static const _metaTutorial = 'gruta_tutorial_visto';

  String get _chaveTutorial => '$_kTutorial${login ?? 'demo'}';

  /// true se esta conta ainda não viu o tutorial. Com Supabase, a marca fica
  /// na própria conta (metadados do usuário), então vale em qualquer aparelho.
  Future<bool> precisaTutorial() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_chaveTutorial) ?? false) return false;
    if (!modoDemo) {
      final meta = Supabase.instance.client.auth.currentUser?.userMetadata;
      if (meta?[_metaTutorial] == true) {
        await p.setBool(_chaveTutorial, true);
        return false;
      }
    }
    return true;
  }

  Future<void> marcarTutorialVisto() async {
    await (await SharedPreferences.getInstance()).setBool(_chaveTutorial, true);
    if (!modoDemo) {
      try {
        await Supabase.instance.client.auth
            .updateUser(UserAttributes(data: {_metaTutorial: true}));
      } catch (_) {
        // Sem internet: fica marcado neste aparelho e tudo bem.
      }
    }
  }

  Future<void> concluirAbertura() async {
    aberturaVista = true;
    (await SharedPreferences.getInstance()).setBool(_kAberturaVista, true);
    notifyListeners();
  }

  // ---------- contas da demonstração ----------

  Future<Map<String, dynamic>> _contasDemo() async {
    final s = (await SharedPreferences.getInstance()).getString(_kDemoContas);
    return s == null ? {} : jsonDecode(s) as Map<String, dynamic>;
  }

  Future<void> _logarDemo(bool v) async {
    _demoLogado = v;
    (await SharedPreferences.getInstance()).setBool(_kDemoLogado, v);
    notifyListeners();
  }

  /// Entra na demonstração sem conta.
  Future<void> entrarDemo() => _logarDemo(true);

  // ---------- entrar / cadastrar ----------

  /// Retorna null se deu certo, ou a mensagem de erro para mostrar.
  Future<String?> entrar(String login, String senha) async {
    if (login.trim().isEmpty || senha.isEmpty) {
      return 'Preencha usuário e senha.';
    }
    if (modoDemo) {
      final conta = (await _contasDemo())[normalizar(login)];
      if (conta == null || conta['senha'] != senha) {
        return 'Usuário ou senha incorretos.';
      }
      acabouDeEntrar = true;
      await _logarDemo(true);
      unawaited(Registro.evento('login'));
      return null;
    }
    try {
      await Supabase.instance.client.auth
          .signInWithPassword(email: emailDe(login), password: senha);
      acabouDeEntrar = true;
      unawaited(Registro.evento('login'));
      return null;
    } on AuthException catch (e) {
      return _traduzir(e.message);
    } catch (_) {
      return 'Sem conexão. Tente de novo.';
    }
  }

  /// Cria a conta e já entra. Retorna null se deu certo.
  Future<String?> cadastrar(Cadastro c) async {
    final erroLogin = validarLogin(c.login);
    if (erroLogin != null) return erroLogin;
    if (c.senha.length < 6) return 'A senha precisa ter 6 caracteres ou mais.';
    final perfil = Perfil(
      nome: c.primeiroNome,
      nomeCompleto: c.nomeCompleto.trim(),
      nascimento: c.nascimento,
      login: normalizar(c.login),
      telefone: c.telefone.trim(),
      email: c.email.trim().toLowerCase(),
      plano: c.plano,
    );

    if (modoDemo) {
      final contas = await _contasDemo();
      if (contas.containsKey(perfil.login)) {
        return 'Esse usuário já existe. Escolha outro.';
      }
      contas[perfil.login] = {'senha': c.senha};
      await (await SharedPreferences.getInstance())
          .setString(_kDemoContas, jsonEncode(contas));
      await RepositorioLocal().salvarPerfil(perfil);
      acabouDeEntrar = true;
      await _logarDemo(true);
      unawaited(Registro.evento('cadastro'));
      return null;
    }

    try {
      final r = await Supabase.instance.client.functions.invoke(
        'gruta-cadastro',
        body: {
          'nome_completo': perfil.nomeCompleto,
          'nome': perfil.nome,
          'nascimento': perfil.nascimento!.toIso8601String().substring(0, 10),
          'login': perfil.login,
          'senha': c.senha,
          'plano': c.plano.name,
        },
      );
      final dados = r.data;
      if (dados is Map && dados['erro'] != null) return dados['erro'] as String;
    } on FunctionException catch (e) {
      final d = e.details;
      if (d is Map && d['erro'] != null) return d['erro'] as String;
      return 'Não foi possível criar a conta agora. Tente de novo.';
    } catch (_) {
      return 'Sem conexão. Tente de novo.';
    }
    final erro = await entrar(perfil.login, c.senha);
    if (erro == null) {
      await _salvarContato(perfil.telefone, perfil.email);
      unawaited(Registro.evento('cadastro', detalhes: {'plano': c.plano.name}));
    }
    return erro;
  }

  /// Grava telefone e e-mail no perfil recém-criado. Se as colunas ainda
  /// não existirem no banco, segue sem elas (a conta já foi criada).
  Future<void> _salvarContato(String telefone, String email) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('perfis')
          .update({'telefone': telefone, 'email': email}).eq('id', uid);
    } catch (e) {
      debugPrint('Contato não salvo: $e');
    }
  }

  /// Troca a senha de quem está logado.
  Future<String?> alterarSenha(String nova) async {
    if (nova.length < 6) return 'A senha precisa ter 6 caracteres ou mais.';
    if (modoDemo) return null;
    try {
      await Supabase.instance.client.auth
          .updateUser(UserAttributes(password: nova));
      return null;
    } on AuthException catch (e) {
      return _traduzir(e.message);
    } catch (_) {
      return 'Sem conexão. Tente de novo.';
    }
  }

  Future<void> sair() async {
    // Antes de sair: depois do signOut o banco não sabe mais quem é.
    await Registro.evento('logout');
    if (modoDemo) {
      await _logarDemo(false);
    } else {
      await Supabase.instance.client.auth.signOut();
    }
    notifyListeners();
  }

  String _traduzir(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) return 'Usuário ou senha incorretos.';
    if (m.contains('same password')) {
      return 'A nova senha precisa ser diferente da atual.';
    }
    if (m.contains('password')) {
      return 'A senha precisa ter 6 caracteres ou mais.';
    }
    return msg;
  }
}

final authState = AuthState();
