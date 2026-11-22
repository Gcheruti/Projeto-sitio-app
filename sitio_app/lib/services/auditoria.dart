import 'dart:async';

import 'package:flutter/foundation.dart';

import '../state/auth_state.dart';
import 'supabase_repository.dart';

/// Nome amigável de cada ação registrada.
const Map<String, String> kAcoes = {
  'login': 'Entrou no app',
  'logout': 'Saiu do app',
  'comanda_criada': 'Criou comanda',
  'comanda_excluida': 'Excluiu comanda',
  'comanda_fechada': 'Fechou comanda',
  'comanda_resetada': 'Reabriu comanda',
  'comanda_reaberta': 'Reabriu comanda mantendo itens',
  'comanda_desconto': 'Desconto em item da comanda',
  'comanda_aviso': 'Aviso na comanda',
  'comanda_item_add': 'Adicionou item na comanda',
  'comanda_item_remove': 'Removeu item da comanda',
  'pedido_status': 'Mudou etapa do pedido',
  'reposicao': 'Reposição de estoque',
  'fin_lancamento': 'Financeiro (Toca dos Coelhos)',
  'preparo': 'Registrou preparo',
  'baixa_estoque': 'Baixa de estoque',
  'produto_criado': 'Cadastrou produto',
  'produto_editado': 'Editou produto',
  'notificacao_criada': 'Criou notificação',
  'notificacao_editada': 'Editou notificação',
  'notificacao_excluida': 'Excluiu notificação',
  'equipe_criada': 'Criou cadastro de equipe',
  'equipe_editada': 'Editou cadastro de equipe',
};

/// Grava cada movimentação no Supabase (tabela "atividades") com o nome de
/// quem fez. Nunca bloqueia nem derruba a operação principal.
class Auditoria {
  Auditoria._();

  static final SupabaseRepository _repo = SupabaseRepository();

  static void registrar(
    String acao,
    String detalhe, {
    String? entidade,
    String? comanda,
  }) {
    final u = authState.usuario;
    unawaited(() async {
      try {
        await _repo.insertAtividade({
          'usuario_id': u?.id,
          'usuario_nome': u?.nome ?? 'Sistema',
          'usuario_login': u?.login,
          'acao': acao,
          'entidade': entidade,
          'detalhe': detalhe,
          'comanda_codigo': comanda,
        });
      } catch (e) {
        debugPrint('Atividade não registrada: $e');
      }
    }());
  }
}
