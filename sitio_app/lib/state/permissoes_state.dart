import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/permissoes.dart';
import '../services/permissoes_repository.dart';
import 'auth_state.dart';

/// Quem pode fazer o quê. O Adm tem tudo; os outros perfis seguem o que foi
/// ligado/desligado em Manutenção de equipe > Permissões (ou o padrão).
/// Freelancer: o perfil vem da função dele no dia (agenda de freelancers).
class PermissoesState extends ChangeNotifier {
  final _repo = PermissoesRepository();
  final Map<String, Map<String, bool>> _ajustes = {};
  String? _cargoHoje;
  String? _ultimoUsuario;
  String _assinatura = '';
  Timer? _timer;
  bool _iniciado = false;

  /// Perfil em uso agora: adm, staff, totem, cozinha, freelancer_<cargo> ou freelancer.
  String get perfilAtual {
    final u = authState.usuario;
    if (u == null) return '';
    if (u.isAdm) return 'adm';
    if (u.isFreelancer) {
      return _cargoHoje == null ? 'freelancer' : 'freelancer_$_cargoHoje';
    }
    return u.papel;
  }

  bool pode(String chave) {
    if (authState.isAdm) return true;
    if (authState.usuario == null) return false;
    return podePerfil(perfilAtual, chave);
  }

  bool podePerfil(String perfil, String chave) {
    final m = _ajustes[perfil];
    if (m != null && m.containsKey(chave)) return m[chave]!;
    return permissaoPadrao(perfil, chave);
  }

  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    authState.addListener(_aoMudarLogin);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => atualizar());
    _aoMudarLogin();
  }

  void _aoMudarLogin() {
    final id = authState.usuario?.id;
    if (id == _ultimoUsuario) return;
    _ultimoUsuario = id;
    _cargoHoje = null;
    _assinatura = '';
    if (id != null) atualizar();
    notifyListeners();
  }

  Future<void> atualizar() async {
    final u = authState.usuario;
    if (u == null) return;
    final todos = await _repo.carregarTudo();
    final cargo = u.isFreelancer ? await _repo.cargoDeHoje(u.id) : null;
    final assinatura = '${jsonEncode(todos)}|$cargo|${u.id}';
    if (assinatura == _assinatura) return;
    _assinatura = assinatura;
    if (todos != null) {
      _ajustes
        ..clear()
        ..addAll(todos);
    }
    _cargoHoje = cargo;
    notifyListeners();
  }

  /// Liga/desliga uma função de um perfil (usado na tela de permissões).
  Future<void> definir(String perfil, String chave, bool valor) async {
    final antes = _ajustes[perfil]?[chave];
    (_ajustes[perfil] ??= {})[chave] = valor;
    _assinatura = '';
    notifyListeners();
    try {
      await _repo.salvar(perfil, chave, valor);
    } catch (e) {
      if (antes == null) {
        _ajustes[perfil]?.remove(chave);
      } else {
        _ajustes[perfil]![chave] = antes;
      }
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restaurarPadrao(String perfil) async {
    await _repo.restaurar(perfil);
    _ajustes.remove(perfil);
    _assinatura = '';
    notifyListeners();
  }
}

final PermissoesState permissoes = PermissoesState();
