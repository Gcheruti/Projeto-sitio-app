import 'dart:convert';

import '../services/auditoria.dart';
import '../services/freelancer_repository.dart';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';
import '../services/supabase_repository.dart';

/// Hash da senha (o mesmo usado no SQL de contas iniciais).
String hashSenha(String senha) =>
    sha256.convert(utf8.encode('sitio:$senha')).toString();

/// Sessão do usuário logado. Fica gravada no aparelho até o logout.
class AuthState extends ChangeNotifier {
  AuthState({SupabaseRepository? repository})
      : _repo = repository ?? SupabaseRepository();

  final SupabaseRepository _repo;
  static const _chave = 'sitio_sessao';

  Usuario? usuario;
  bool get logado => usuario != null;
  bool get isAdm => usuario?.isAdm ?? false;

  /// Chamado na abertura do app: reaproveita o login gravado.
  Future<void> restaurar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString(_chave);
      if (salvo == null) return;
      final cache =
          Usuario.fromMap(Map<String, dynamic>.from(jsonDecode(salvo) as Map));
      usuario = cache;
      // Confirma no servidor (conta apagada/desativada/papel mudou).
      try {
        final atual = await _repo.fetchUsuarioPorId(cache.id);
        if (atual == null || !atual.ativo) {
          await sair();
        } else {
          await _gravar(atual);
        }
      } catch (_) {
        // sem rede: segue com os dados gravados
      }
    } catch (_) {
      usuario = null;
    }
    notifyListeners();
  }

  /// Devolve null se entrou, ou a mensagem de erro.
  Future<String?> entrar(String login, String senha) async {
    final l = login.trim();
    if (l.isEmpty || senha.isEmpty) return 'Informe login e senha.';
    try {
      final u = await _repo.fetchUsuarioPorCredenciais(l, hashSenha(senha));
      if (u == null) return 'Login ou senha incorretos.';
      await _gravar(u);
      if (u.isFreelancer) await FreelancerRepository().registrarEntrada(u);
      Auditoria.registrar('login', 'Entrou no app', entidade: 'sessao');
      return null;
    } catch (e) {
      return 'Não foi possível entrar agora. Verifique a conexão.';
    }
  }

  /// Confere a senha digitada com a do login que está em uso agora
  /// (usada nas telas que pedem senha: fechar comanda, reposição, baixa...).
  Future<bool> senhaConfere(String senha) async {
    final u = usuario;
    if (u == null || senha.isEmpty) return false;
    try {
      final r = await _repo.fetchUsuarioPorCredenciais(u.login, hashSenha(senha));
      return r != null && r.id == u.id;
    } catch (_) {
      return false; // sem rede: não dá para conferir
    }
  }

  Future<void> sair() async {
    Auditoria.registrar('logout', 'Saiu do app', entidade: 'sessao');
    final saindo = usuario;
    if (saindo != null && saindo.isFreelancer) {
      await FreelancerRepository().registrarSaida(saindo);
    }
    usuario = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chave);
    } catch (_) {}
    notifyListeners();
  }

  /// Atualiza a sessão quando o próprio usuário edita seu cadastro.
  Future<void> atualizarSessao(Usuario u) => _gravar(u);

  Future<void> _gravar(Usuario u) async {
    usuario = u;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_chave, jsonEncode(u.toMap()));
    } catch (_) {}
    notifyListeners();
  }
}

final AuthState authState = AuthState();
