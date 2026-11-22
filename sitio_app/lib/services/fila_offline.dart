import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_repository.dart';

/// Guarda no aparelho as mudanças de itens de comanda feitas SEM conexão e as
/// envia, na mesma ordem, quando a rede volta. Cada operação leva um
/// identificador: se o envio for repetido, o servidor não duplica.
///
/// Só cobre adicionar/remover itens da comanda (a venda em si). Fechar
/// comanda, reposição, baixa etc. continuam exigindo conexão.
class FilaOffline extends ChangeNotifier {
  FilaOffline._();

  static const _chave = 'fila_offline_v1';
  final SupabaseRepository _repo = SupabaseRepository();

  final List<Map<String, dynamic>> _ops = [];
  bool _rodando = false;

  /// Mensagens de operações que o servidor recusou (ex.: estoque acabou).
  final List<String> avisos = [];

  int get pendentes => _ops.length;
  bool get vazia => _ops.isEmpty;

  static String novoId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 30)}';

  /// Erro de conexão (sem rede, timeout) — diferente de recusa do servidor.
  static bool ehErroDeRede(Object e) {
    if (e is TimeoutException) return true;
    final s = e.toString();
    return s.contains('SocketException') ||
        s.contains('ClientException') ||
        s.contains('Failed host lookup') ||
        s.contains('Connection') ||
        s.contains('Network is unreachable') ||
        s.contains('XMLHttpRequest');
  }

  Future<void> restaurar() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_chave);
      if (raw == null || raw.isEmpty) return;
      final lista = jsonDecode(raw) as List;
      _ops
        ..clear()
        ..addAll(lista.map((e) => Map<String, dynamic>.from(e as Map)));
      notifyListeners();
    } catch (e) {
      debugPrint('Fila offline não restaurada: $e');
    }
  }

  Future<void> _salvar() async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_chave, jsonEncode(_ops));
    } catch (e) {
      debugPrint('Fila offline não salva: $e');
    }
  }

  void limparAvisos() {
    avisos.clear();
    notifyListeners();
  }

  /// Guarda uma mudança de item para enviar depois.
  Future<void> enfileirar(Map<String, dynamic> dados) async {
    _ops.add(dados);
    notifyListeners();
    await _salvar();
  }

  /// Tenta enviar tudo, em ordem. Para na primeira falha de conexão.
  Future<void> sincronizar() async {
    if (_rodando || _ops.isEmpty) return;
    _rodando = true;
    try {
      while (_ops.isNotEmpty) {
        final op = _ops.first;
        try {
          await _repo.registrarItemComanda(
            op: op['op'] as String,
            codigo: op['codigo'] as String,
            produtoId: op['produto_id'] as String,
            nome: op['nome'] as String,
            preco: (op['preco'] as num).toDouble(),
            processual: op['processual'] as bool,
            delta: (op['delta'] as num).toInt(),
          );
        } catch (e) {
          if (ehErroDeRede(e)) break; // segue guardada; tenta de novo depois
          // O servidor recusou (ex.: estoque acabou): não adianta repetir.
          avisos.add('Não foi possível enviar ${op['nome']} da comanda '
              '${op['codigo']}: $e');
        }
        _ops.removeAt(0);
        await _salvar();
        notifyListeners();
      }
    } finally {
      _rodando = false;
      notifyListeners();
    }
  }
}

final FilaOffline filaOffline = FilaOffline._();
