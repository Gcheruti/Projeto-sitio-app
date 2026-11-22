import '../models/lote.dart';
import '../models/notificacao.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/comanda.dart';
import '../models/nota_importada.dart';
import '../models/produto.dart';
import '../models/usuario.dart';

/// O servidor recusou porque o estoque não cobre a saída.
class EstoqueInsuficienteException implements Exception {
  @override
  String toString() => 'Estoque insuficiente (outro aparelho pode ter acabado de vender)';
}

/// O script supabase/atomicidade.sql ainda não foi rodado.
class FuncaoAusenteException implements Exception {
  @override
  String toString() => 'Função do servidor ausente (rode supabase/atomicidade.sql)';
}

class SupabaseRepository {
  SupabaseClient get _db => Supabase.instance.client;

  String _asString(dynamic v) => v?.toString() ?? '';

  int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
  }

  // ---------- LOAD ----------

  Future<List<Produto>> fetchProdutos() async {
    final rows = await _db.from('produtos').select();
    return (rows as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return Produto(
        id: _asString(m['id']),
        nome: _asString(m['nome']),
        quantidade: _asInt(m['quantidade']),
        minimo: _asInt(m['minimo']),
        preco: _asDouble(m['preco']),
        ambiente: _asString(m['ambiente']).isEmpty
            ? 'Salão'
            : _asString(m['ambiente']),
        codigoBarras: (m['codigo_barras'] == null ||
                _asString(m['codigo_barras']).isEmpty)
            ? null
            : _asString(m['codigo_barras']),
        processual: m['processual'] == true,
        subcategoria: _asString(m['subcategoria']).isEmpty
            ? null
            : _asString(m['subcategoria']),
        publico: m['publico'] != false,
        controlaEstoque: m['controla_estoque'] != false,
        diasAvisoValidade: m['dias_aviso_validade'] == null ? 3 : _asInt(m['dias_aviso_validade']),
      );
    }).toList();
  }

  Future<List<Comanda>> fetchComandasComItens() async {
    final rowsComandas = await _db.from('comandas').select();
    final rowsItens = await _db.from('itens_comanda').select();

    final itensPorCodigo = <String, List<ItemComanda>>{};
    for (final raw in rowsItens as List) {
      final m = Map<String, dynamic>.from(raw as Map);
      final codigo = _asString(m['comanda_codigo']).toUpperCase();
      if (codigo.isEmpty) continue;
      itensPorCodigo.putIfAbsent(codigo, () => []);
      itensPorCodigo[codigo]!.add(
        ItemComanda(
          produtoId: _asString(m['produto_id']),
          nome: _asString(m['nome']),
          quantidade: _asInt(m['quantidade']),
          precoUnitario: _asDouble(m['preco']),
          processual: m['processual'] == true,
          statusPreparo: m['status_preparo']?.toString(),
          desconto: _asDouble(m['desconto']),
        ),
      );
    }

    return (rowsComandas as List)
        .where((raw) => !_asString((raw as Map)['status'])
            .toLowerCase()
            .contains('exclu'))
        .map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      final codigo = _asString(m['codigo']).toUpperCase();
      final statusRaw = _asString(m['status']).toLowerCase();
      final status = (statusRaw.contains('inativa') ||
              statusRaw.contains('fechada') ||
              statusRaw == 'inactive')
          ? 'inativa'
          : 'ativa';

      return Comanda(
        id: _asString(m['id']),
        codigo: codigo,
        status: status,
        formaPagamento:
            m['pagamento'] == null ? null : _asString(m['pagamento']),
        itens: List<ItemComanda>.from(itensPorCodigo[codigo] ?? []),
      );
    }).toList();
  }

  // ---------- PRODUTOS ----------

  Future<Produto> insertProduto(Produto p) async {
    final payload = <String, dynamic>{
      'nome': p.nome,
      'quantidade': p.quantidade,
      'minimo': p.minimo,
      'preco': p.preco,
      'ambiente': p.ambiente,
      'codigo_barras': p.codigoBarras,
    };

    final novas = {
      'processual': p.processual,
      'subcategoria': p.subcategoria,
      'publico': p.publico,
      'controla_estoque': p.controlaEstoque,
    };
    Map<String, dynamic> row;
    try {
      row = await _db
          .from('produtos')
          .insert({
            ...payload,
            ...novas,
            'dias_aviso_validade': p.diasAvisoValidade,
          })
          .select()
          .single();
    } catch (_) {
      // colunas novas ainda não criadas no Supabase
      try {
        row = await _db
            .from('produtos')
            .insert({...payload, ...novas})
            .select()
            .single();
      } catch (_) {
       try {
        row = await _db
            .from('produtos')
            .insert({...payload, 'processual': p.processual})
            .select()
            .single();
       } catch (_) {
        row = await _db.from('produtos').insert(payload).select().single();
       }
      }
    }
    final m = Map<String, dynamic>.from(row);
    return Produto(
      id: _asString(m['id']),
      nome: _asString(m['nome']),
      quantidade: _asInt(m['quantidade']),
      minimo: _asInt(m['minimo']),
      preco: _asDouble(m['preco']),
      processual: m['processual'] == true,
      subcategoria: _asString(m['subcategoria']).isEmpty
          ? null
          : _asString(m['subcategoria']),
      publico: m['publico'] != false,
      controlaEstoque: m['controla_estoque'] != false,
      diasAvisoValidade: m['dias_aviso_validade'] == null ? 3 : _asInt(m['dias_aviso_validade']),
      ambiente: _asString(m['ambiente']),
      codigoBarras: (m['codigo_barras'] == null ||
              _asString(m['codigo_barras']).isEmpty)
          ? null
          : _asString(m['codigo_barras']),
    );
  }

  Future<void> updateProduto(Produto p) async {
    final payload = {
      'nome': p.nome,
      'quantidade': p.quantidade,
      'minimo': p.minimo,
      'preco': p.preco,
      'ambiente': p.ambiente,
      'codigo_barras': p.codigoBarras,
    };
    final novas = {
      'processual': p.processual,
      'subcategoria': p.subcategoria,
      'publico': p.publico,
      'controla_estoque': p.controlaEstoque,
    };
    try {
      await _db.from('produtos').update({
        ...payload,
        ...novas,
        'dias_aviso_validade': p.diasAvisoValidade,
      }).eq('id', p.id);
    } catch (_) {
      // colunas novas ainda não criadas no Supabase
      try {
        await _db.from('produtos').update({...payload, ...novas}).eq('id', p.id);
        return;
      } catch (_) {}
      try {
        await _db
            .from('produtos')
            .update({...payload, 'processual': p.processual}).eq('id', p.id);
      } catch (_) {
        await _db.from('produtos').update(payload).eq('id', p.id);
      }
    }
  }

  /// A função do servidor ainda não existe (supabase/atomicidade.sql não rodou).
  bool _funcaoAusente(PostgrestException e) =>
      e.code == 'PGRST202' ||
      e.code == '42883' ||
      e.message.contains('Could not find the function');

  /// Soma [delta] ao estoque DENTRO do servidor (atômico): aparelhos
  /// diferentes não se sobrescrevem. Devolve a quantidade nova. Com [minimo]
  /// (ex.: 0) o servidor recusa saídas que deixariam o estoque abaixo dele.
  Future<int> ajustarEstoque(String produtoId, int delta,
      {int? minimo, String? op}) async {
    try {
      final r = await _db.rpc('ajustar_estoque', params: {
        'p_id': produtoId,
        'p_delta': delta,
        'p_minimo': minimo,
        'p_op': op,
      });
      return _asInt(r);
    } on PostgrestException catch (e) {
      if (e.message.contains('estoque_insuficiente')) {
        throw EstoqueInsuficienteException();
      }
      if (_funcaoAusente(e)) {
        // Plano B (menos seguro): lê, soma e grava.
        final row = await _db
            .from('produtos')
            .select('quantidade')
            .eq('id', produtoId)
            .single();
        final nova = _asInt(row['quantidade']) + delta;
        if (minimo != null && nova < minimo) throw EstoqueInsuficienteException();
        await updateEstoque(produtoId, nova);
        return nova;
      }
      rethrow;
    }
  }

  /// Muda UM item da comanda e o estoque juntos, numa transação do servidor.
  /// [delta] > 0 = entrou na comanda (estoque sai); < 0 = voltou. [op] torna a
  /// chamada repetível sem duplicar. Devolve o estoque novo.
  Future<int> registrarItemComanda({
    required String op,
    required String codigo,
    required String produtoId,
    required String nome,
    required double preco,
    required bool processual,
    required int delta,
  }) async {
    try {
      final r = await _db.rpc('registrar_item_comanda', params: {
        'p_op': op,
        'p_codigo': codigo,
        'p_produto_id': produtoId,
        'p_nome': nome,
        'p_preco': preco,
        'p_processual': processual,
        'p_delta': delta,
      }).timeout(const Duration(seconds: 8));
      return _asInt(r);
    } on PostgrestException catch (e) {
      if (e.message.contains('estoque_insuficiente')) {
        throw EstoqueInsuficienteException();
      }
      if (_funcaoAusente(e)) throw FuncaoAusenteException();
      rethrow;
    }
  }

  Future<void> updateEstoque(String produtoId, int quantidade) async {
    await _db
        .from('produtos')
        .update({'quantidade': quantidade}).eq('id', produtoId);
  }

  // ---------- COMANDAS ----------

  Future<Comanda> insertComanda({required String codigo}) async {
    final row = await _db.from('comandas').insert({
      'codigo': codigo.toUpperCase(),
      'status': 'ativa',
      'pagamento': null,
    }).select().single();

    final m = Map<String, dynamic>.from(row);
    return Comanda(
      id: _asString(m['id']),
      codigo: _asString(m['codigo']).toUpperCase(),
      status: 'ativa',
      itens: [],
    );
  }

  /// Apaga a comanda e seus itens. Se o banco impedir (histórico ligado),
  /// marca como "excluida" e ela some das listagens.
  Future<void> excluirComandaRemoto({
    required String comandaId,
    required String comandaCodigo,
  }) async {
    await _db
        .from('itens_comanda')
        .delete()
        .eq('comanda_codigo', comandaCodigo.toUpperCase());
    try {
      await _db.from('comandas').delete().eq('id', comandaId);
    } catch (_) {
      await _db
          .from('comandas')
          .update({'status': 'excluida'}).eq('id', comandaId);
    }
  }

  Future<bool> codigoComandaExiste(String codigo) async {
    final row = await _db
        .from('comandas')
        .select('id')
        .eq('codigo', codigo.toUpperCase())
        .maybeSingle();
    return row != null;
  }

  Future<void> fecharComandaRemoto({
    required String comandaId,
    required String pagamento,
  }) async {
    await _db.from('comandas').update({
      'status': 'inativa',
      'pagamento': pagamento,
    }).eq('id', comandaId);
  }

  Future<void> resetarComandaRemoto({
    required String comandaId,
    required String comandaCodigo,
  }) async {
    await _db
        .from('itens_comanda')
        .delete()
        .eq('comanda_codigo', comandaCodigo.toUpperCase());
    await _db.from('comandas').update({
      'status': 'ativa',
      'pagamento': null,
    }).eq('id', comandaId);
  }

  /// Reabre mantendo os itens e anula o último fechamento no histórico
  /// (senão a venda seria contada duas vezes quando fechar de novo).
  Future<void> reabrirMantendoItensRemoto({required Comanda comanda}) async {
    await _db.from('comandas').update({
      'status': 'ativa',
      'pagamento': null,
    }).eq('id', comanda.id);
    try {
      final rows = await _db
          .from('comandas_historico')
          .select('id')
          .eq('comanda_id', comanda.id)
          .order('fechado_em', ascending: false)
          .limit(1);
      if ((rows as List).isNotEmpty) {
        await _db
            .from('comandas_historico')
            .delete()
            .eq('id', (rows.first as Map)['id']);
      }
    } catch (_) {}
  }

  Future<void> salvarHistoricoFechamento({
    required Comanda comanda,
    required String pagamento,
    required double totalItens,
    required double valorCobrado,
    List<PagamentoParte>? partes,
  }) async {
    final itensJson = comanda.itens
        .map((i) => {
              'nome': i.nome,
              'quantidade': i.quantidade,
              'preco_unitario': i.precoUnitario,
              'subtotal': i.subtotal,
              'desconto': i.desconto,
              'produto_id': i.produtoId,
            })
        .toList();

    final dados = {
      'comanda_id': comanda.id,
      'comanda_codigo': comanda.codigo,
      'codigo': comanda.codigo,
      'pagamento': pagamento,
      'total': valorCobrado,
      'total_itens': totalItens,
      'valor_cobrado': valorCobrado,
      'itens_json': itensJson,
    };
    if (partes != null && partes.isNotEmpty) {
      try {
        await _db.from('comandas_historico').insert({
          ...dados,
          'pagamentos_json': partes.map((p) => p.toMap()).toList(),
        });
        return;
      } catch (_) {
        // coluna pagamentos_json ainda não criada (comandas_v2.sql)
      }
    }
    await _db.from('comandas_historico').insert(dados);
  }

  // ---------- ITENS ----------

  /// [delta]: quanto a quantidade MUDOU nesta operação. Com ele, a soma é
  /// feita no servidor (dois aparelhos na mesma comanda não se sobrescrevem).
  Future<void> upsertItemComanda({
    required String comandaCodigo,
    required ItemComanda item,
    int? delta,
  }) async {
    final codigo = comandaCodigo.toUpperCase();

    dynamic existing;
    if (item.produtoId.isNotEmpty) {
      existing = await _db
          .from('itens_comanda')
          .select('id')
          .eq('comanda_codigo', codigo)
          .eq('produto_id', item.produtoId)
          .maybeSingle();
    } else {
      existing = await _db
          .from('itens_comanda')
          .select('id')
          .eq('comanda_codigo', codigo)
          .eq('nome', item.nome)
          .maybeSingle();
    }

    final payload = {
      'comanda_codigo': codigo,
      'produto_id': item.produtoId.isEmpty ? null : item.produtoId,
      'nome': item.nome,
      'quantidade': item.quantidade,
      'preco': item.precoUnitario,
    };

    final comPreparo = {
      ...payload,
      'processual': item.processual,
      'status_preparo': item.statusPreparo,
    };

    if (delta != null && existing != null && existing['id'] != null) {
      try {
        await _db.rpc('somar_item_comanda', params: {
          'p_id': existing['id'].toString(),
          'p_delta': delta,
        });
        // a quantidade já foi somada no servidor: não regrava por cima
        payload.remove('quantidade');
        comPreparo.remove('quantidade');
      } on PostgrestException catch (e) {
        if (!_funcaoAusente(e)) rethrow;
      }
    }

    Future<void> grava(Map<String, dynamic> dados) async {
      if (existing != null && existing['id'] != null) {
        await _db.from('itens_comanda').update(dados).eq('id', existing['id']);
      } else {
        await _db.from('itens_comanda').insert(dados);
      }
    }

    try {
      await grava({...comPreparo, 'desconto': item.desconto});
    } catch (_) {
      // coluna de desconto / preparo ainda não criada no Supabase
      try {
        await grava(comPreparo);
      } catch (_) {
        await grava(payload);
      }
    }
  }

  /// Muda a etapa de preparo de um item da comanda.
  Future<void> updateStatusPreparo({
    required String comandaCodigo,
    required String produtoId,
    required String status,
  }) async {
    await _db
        .from('itens_comanda')
        .update({'status_preparo': status})
        .eq('comanda_codigo', comandaCodigo.toUpperCase())
        .eq('produto_id', produtoId);
  }

  // ---------- REPOSIÇÃO ----------

  /// Devolve o id da reposição criada (para vincular à nota importada).
  Future<String> confirmarRepos({
    required List<Map<String, dynamic>> itens,
    required double valorInvestido,
    String? observacao,
  }) async {
    final repo = await _db
        .from('reposicoes')
        .insert({
          'observacao': observacao,
          'valor_investido': valorInvestido,
        })
        .select()
        .single();
    final reposicaoId = repo['id'];

    for (final it in itens) {
      final produtoId = it['produto_id'] as String;
      final qtd = it['quantidade_entrada'] as int;
      // soma no servidor; o "antes" real vem do resultado
      final depois = await ajustarEstoque(produtoId, qtd);
      final antes = depois - qtd;

      await _db.from('reposicoes_itens').insert({
        'reposicao_id': reposicaoId,
        'produto_id': produtoId,
        'nome': it['nome'],
        'quantidade_entrada': qtd,
        'estoque_antes': antes,
        'estoque_depois': depois,
      });
    }
    return _asString(reposicaoId);
  }

  // ---------- BAIXA MANUAL ----------

  /// Devolve o estoque novo (calculado no servidor).
  Future<int> registrarBaixa({
    required String produtoId,
    required String nome,
    required int quantidade,
    required String motivo,
  }) async {
    final novo = await ajustarEstoque(produtoId, -quantidade, minimo: 0);

    await _db.from('baixas_estoque').insert({
      'produto_id': produtoId,
      'nome': nome,
      'quantidade': quantidade,
      'motivo': motivo,
    });
    return novo;
  }
  // ---------- ATIVIDADES (auditoria) ----------

  Future<void> insertAtividade(Map<String, dynamic> dados) async {
    await _db.from('atividades').insert(dados);
  }

  Future<List<Map<String, dynamic>>> fetchAtividades({
    required String usuarioId,
    required DateTime inicio,
    required DateTime fim,
    int limite = 1000,
  }) async {
    final rows = await _db
        .from('atividades')
        .select()
        .eq('usuario_id', usuarioId)
        .gte('criado_em', inicio.toUtc().toIso8601String())
        .lt('criado_em', fim.toUtc().toIso8601String())
        .order('criado_em', ascending: false)
        .limit(limite);
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  // ---------- USUÁRIOS (login) ----------

  Future<Usuario?> fetchUsuarioPorCredenciais(String login, String hash) async {
    final rows = await _db
        .from('usuarios')
        .select()
        .ilike('login', login.replaceAll('%', r'\%').replaceAll('_', r'\_'))
        .eq('senha_hash', hash)
        .eq('ativo', true)
        .limit(1);
    final l = rows as List;
    if (l.isEmpty) return null;
    return Usuario.fromMap(Map<String, dynamic>.from(l.first as Map));
  }

  Future<Usuario?> fetchUsuarioPorId(String id) async {
    final row = await _db.from('usuarios').select().eq('id', id).maybeSingle();
    return row == null ? null : Usuario.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<Notificacao>> fetchNotificacoes() async {
    final rows = await _db
        .from('notificacoes')
        .select()
        .order('criado_em', ascending: false);
    return (rows as List).map((r) {
      final m = r as Map;
      return Notificacao(
        id: m['id'].toString(),
        titulo: (m['titulo'] ?? '').toString(),
        descricao: (m['descricao'] ?? '').toString(),
        ativa: m['ativa'] != false,
        local: m['local']?.toString(),
        criadoPor: m['criado_por']?.toString(),
        editadoPor: m['editado_por']?.toString(),
        excluida: m['excluida'] == true,
        somenteAdm: m['somente_adm'] == true,
      );
    }).toList();
  }

  Future<void> upsertNotificacoes(List<Notificacao> lista) async {
    if (lista.isEmpty) return;
    try {
      await _db.from('notificacoes').upsert([
        for (final n in lista)
          {
            'id': n.id,
            'titulo': n.titulo,
            'descricao': n.descricao,
            'ativa': n.ativa,
            'local': n.local,
            'criado_por': n.criadoPor,
            'editado_por': n.editadoPor,
            'editado_em': DateTime.now().toUtc().toIso8601String(),
            'excluida': n.excluida,
            'somente_adm': n.somenteAdm,
          }
      ]);
    } on PostgrestException catch (e) {
      // Colunas novas ainda não criadas (notificacoes_editor.sql): salva o básico.
      if (e.code != 'PGRST204' && e.code != '42703') rethrow;
      await _db.from('notificacoes').upsert([
        for (final n in lista)
          {
            'id': n.id,
            'titulo': n.titulo,
            'descricao': n.descricao,
            'ativa': n.ativa && !n.excluida,
            'local': n.local,
          }
      ]);
    }
  }

  Future<List<Usuario>> fetchUsuarios() async {
    final rows = await _db.from('usuarios').select().order('nome');
    return (rows as List)
        .map((r) => Usuario.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> inserirUsuario({
    required String nome,
    required String login,
    required String senhaHash,
    required String papel,
    String? icone,
  }) async {
    await _db.from('usuarios').insert({
      'nome': nome,
      'login': login,
      'senha_hash': senhaHash,
      'papel': papel,
      if (icone != null) 'icone': icone,
    });
  }

  Future<void> atualizarUsuario(
    String id, {
    required String nome,
    required String login,
    required String papel,
    String? senhaHash,
    String? icone,
  }) async {
    await _db.from('usuarios').update({
      'nome': nome,
      'login': login,
      'papel': papel,
      if (icone != null) 'icone': icone,
      if (senhaHash != null) 'senha_hash': senhaHash,
    }).eq('id', id);
  }

  // ---------- NOTAS IMPORTADAS (foto / QR) ----------

  /// Guarda o que o OCR leu x o que a equipe corrigiu (melhoria do leitor).
  Future<void> insertNotaCorrecao({
    String? notaId,
    required String origem,
    required String textoBruto,
    required List<Map<String, dynamic>> itensLidos,
    required List<Map<String, dynamic>> itensFinais,
    double? totalLido,
    double? totalFinal,
  }) async {
    await _db.from('notas_correcoes').insert({
      'nota_id': notaId,
      'origem': origem,
      'texto_bruto': textoBruto.isEmpty ? null : textoBruto,
      'itens_lidos': itensLidos,
      'itens_finais': itensFinais,
      'total_lido': totalLido,
      'total_final': totalFinal,
    });
  }

  /// Grava cabeçalho + itens com status 'rascunho'. Devolve o id da nota.
  Future<String> insertNotaRascunho(NotaImportada nota) async {
    final row = await _db
        .from('notas_importadas')
        .insert({
          'origem': nota.origem,
          'status': 'rascunho',
          'chave_acesso': nota.chaveAcesso,
          'url_qr': nota.urlQr,
          'total_nota': nota.totalNota,
          'texto_bruto': nota.textoBruto.isEmpty ? null : nota.textoBruto,
          'qtd_fotos': nota.qtdFotos,
        })
        .select()
        .single();
    final id = _asString(row['id']);
    try {
      await _inserirItensNota(id, nota.itens);
    } catch (e) {
      // não deixa cabeçalho órfão
      await _db.from('notas_importadas').delete().eq('id', id);
      rethrow;
    }
    return id;
  }

  Future<void> _inserirItensNota(String notaId, List<NotaItem> itens) async {
    if (itens.isEmpty) return;
    await _db.from('notas_importadas_itens').insert([
      for (var i = 0; i < itens.length; i++)
        {
          'nota_id': notaId,
          'ordem': i,
          'nome': itens[i].nome,
          'quantidade': itens[i].quantidade,
          'valor_unitario': itens[i].valorUnitario,
          'valor_total': itens[i].valorTotal,
          'codigo': itens[i].codigo,
        },
    ]);
  }

  /// Regrava os itens editados na conferência (insere os novos e só então
  /// apaga os antigos, para não perder o rascunho se algo falhar no meio).
  Future<void> salvarEdicaoNota({
    required String notaId,
    required List<NotaItem> itens,
    double? totalNota,
  }) async {
    final antigos = await _db
        .from('notas_importadas_itens')
        .select('id')
        .eq('nota_id', notaId);
    final idsAntigos = (antigos as List).map((r) => r['id']).toList();

    await _inserirItensNota(notaId, itens);
    if (idsAntigos.isNotEmpty) {
      await _db
          .from('notas_importadas_itens')
          .delete()
          .inFilter('id', idsAntigos);
    }
    await _db.from('notas_importadas').update({
      'total_nota': totalNota,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', notaId);
  }

  Future<void> marcarNotaConfirmada({
    required String notaId,
    required double valorInvestido,
    String? reposicaoId,
  }) async {
    final agora = DateTime.now().toUtc().toIso8601String();
    await _db.from('notas_importadas').update({
      'status': 'confirmada',
      'valor_investido': valorInvestido,
      'reposicao_id': reposicaoId,
      'confirmado_em': agora,
      'atualizado_em': agora,
    }).eq('id', notaId);
  }

  Future<void> cancelarNota(String notaId) async {
    await _db.from('notas_importadas').update({
      'status': 'cancelada',
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', notaId);
  }

  /// Rascunhos pendentes de conferência (sem itens; mais recentes primeiro).
  Future<List<NotaImportada>> fetchNotasPendentes() async {
    final rows = await _db
        .from('notas_importadas')
        .select()
        .eq('status', 'rascunho')
        .order('criado_em', ascending: false)
        .limit(30);
    return (rows as List)
        .map((r) => _notaDeRow(Map<String, dynamic>.from(r as Map), <NotaItem>[]))
        .toList();
  }

  /// Id da nota já salva com esta chave de acesso, ou null.
  Future<String?> fetchIdNotaPorChave(String chave) async {
    final rows = await _db
        .from('notas_importadas')
        .select('id')
        .eq('chave_acesso', chave)
        .order('criado_em', ascending: false)
        .limit(1);
    final l = rows as List;
    if (l.isEmpty) return null;
    return (l.first as Map)['id'].toString();
  }

  Future<NotaImportada> fetchNotaComItens(String notaId) async {
    final row =
        await _db.from('notas_importadas').select().eq('id', notaId).single();
    final rowsItens = await _db
        .from('notas_importadas_itens')
        .select()
        .eq('nota_id', notaId)
        .order('ordem', ascending: true);
    final itens = (rowsItens as List).map((raw) {
      final m = Map<String, dynamic>.from(raw as Map);
      return NotaItem(
        nome: _asString(m['nome']),
        quantidade: _asDouble(m['quantidade']),
        valorUnitario:
            m['valor_unitario'] == null ? null : _asDouble(m['valor_unitario']),
        valorTotal:
            m['valor_total'] == null ? null : _asDouble(m['valor_total']),
        codigo: (m['codigo'] == null || _asString(m['codigo']).isEmpty)
            ? null
            : _asString(m['codigo']),
      );
    }).toList();
    return _notaDeRow(Map<String, dynamic>.from(row), itens);
  }

  NotaImportada _notaDeRow(Map<String, dynamic> m, List<NotaItem> itens) {
    return NotaImportada(
      id: _asString(m['id']),
      origem: _asString(m['origem']).isEmpty ? 'foto' : _asString(m['origem']),
      status: _asString(m['status']),
      chaveAcesso: m['chave_acesso'] == null ? null : _asString(m['chave_acesso']),
      urlQr: m['url_qr'] == null ? null : _asString(m['url_qr']),
      totalNota: m['total_nota'] == null ? null : _asDouble(m['total_nota']),
      textoBruto: _asString(m['texto_bruto']),
      qtdFotos: _asInt(m['qtd_fotos']),
      itens: itens,
      criadoEm: DateTime.tryParse(_asString(m['criado_em']))?.toLocal(),
    );
  }

  // ---------- RELATÓRIOS ----------

  Future<List<Map<String, dynamic>>> fetchFechamentos({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    final rows = await _db
        .from('comandas_historico')
        .select()
        .gte('fechado_em', inicio.toUtc().toIso8601String())
        .lt('fechado_em', fim.toUtc().toIso8601String())
        .order('fechado_em', ascending: false);

    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchReposicoes({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    try {
      final rows = await _db
          .from('reposicoes')
          .select()
          .gte('criado_em', inicio.toUtc().toIso8601String())
          .lt('criado_em', fim.toUtc().toIso8601String())
          .order('criado_em', ascending: false);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchReposicoesItens(
      List<String> reposicaoIds) async {
    if (reposicaoIds.isEmpty) return [];
    try {
      final out = <Map<String, dynamic>>[];
      for (var i = 0; i < reposicaoIds.length; i += 80) {
        final lote = reposicaoIds.sublist(
            i, i + 80 > reposicaoIds.length ? reposicaoIds.length : i + 80);
        final rows = await _db
            .from('reposicoes_itens')
            .select()
            .inFilter('reposicao_id', lote);
        out.addAll((rows as List)
            .map((r) => Map<String, dynamic>.from(r as Map)));
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchBaixas({
    required DateTime inicio,
    required DateTime fim,
  }) async {
    try {
      final rows = await _db
          .from('baixas_estoque')
          .select()
          .gte('criado_em', inicio.toUtc().toIso8601String())
          .lt('criado_em', fim.toUtc().toIso8601String())
          .order('criado_em', ascending: false);
      return (rows as List)
          .map((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---------- LOTES (validade) ----------

  Future<List<Lote>> fetchLotes() async {
    try {
      final rows = await _db.from('lotes').select().order('validade');
      return (rows as List).map((r) {
        final m = r as Map;
        final d = DateTime.parse(m['validade'].toString());
        return Lote(
          id: m['id'].toString(),
          produtoId: m['produto_id'].toString(),
          quantidade: _asInt(m['quantidade']),
          validade: DateTime(d.year, d.month, d.day),
        );
      }).toList();
    } catch (e) {
      // tabela ainda não criada: segue sem controle de validade
      return [];
    }
  }

  Future<void> inserirLote({
    required String produtoId,
    required int quantidade,
    required DateTime validade,
  }) async {
    final v = '${validade.year.toString().padLeft(4, '0')}-'
        '${validade.month.toString().padLeft(2, '0')}-'
        '${validade.day.toString().padLeft(2, '0')}';
    await _db.from('lotes').insert({
      'produto_id': produtoId,
      'quantidade': quantidade,
      'validade': v,
    });
  }
}