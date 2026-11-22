import 'package:flutter/foundation.dart';
import '../models/comanda.dart';
import '../models/lote.dart';
import '../models/nota_importada.dart';
import '../models/produto.dart';
import '../models/reposicao_linha.dart';
import '../services/auditoria.dart';
import '../services/avisos_admin.dart';
import '../services/fila_offline.dart';
import '../services/supabase_repository.dart';

class AppState extends ChangeNotifier {
  AppState({SupabaseRepository? repository})
      : _repo = repository ?? SupabaseRepository();

  final SupabaseRepository _repo;

  final List<Produto> produtos = [];
  final List<Comanda> comandas = [];
  final List<Lote> lotes = [];

  /// Lotes ainda em estoque, do mais antigo ao mais novo (por validade).
  /// Saída é FIFO (vence primeiro, sai primeiro): o estoque atual é composto
  /// pelos lotes de validade mais distante; o excedente dos mais próximos já saiu.
  List<({Lote lote, int restante})> lotesEmEstoque(Produto p) {
    final ls = lotes.where((l) => l.produtoId == p.id).toList()
      ..sort((a, b) => b.validade.compareTo(a.validade)); // mais distante 1º
    var sobra = p.quantidade;
    final out = <({Lote lote, int restante})>[];
    for (final l in ls) {
      if (sobra <= 0) break;
      final r = l.quantidade < sobra ? l.quantidade : sobra;
      out.add((lote: l, restante: r));
      sobra -= r;
    }
    return out.reversed.toList();
  }

  bool carregando = false;
  String? ultimoErro;

  int get qtdComandasAtivas =>
      comandas.where((c) => c.isAtiva).length;

  List<Produto> get produtosEstoqueBaixo =>
      produtos.where((p) => p.estoqueBaixo).toList();

  String get textoEstoqueBaixo {
    final list = produtosEstoqueBaixo;
    if (list.isEmpty) return '';
    return list.map((p) => '${p.nome}: ${p.quantidade}').join(' | ');
  }

  Future<void> carregarDoServidor() async {
    carregando = true;
    ultimoErro = null;
    notifyListeners();
    try {
      final prods = await _repo.fetchProdutos();
      final cmds = await _repo.fetchComandasComItens();
      final ls = await _repo.fetchLotes();
      lotes
        ..clear()
        ..addAll(ls);
      produtos
        ..clear()
        ..addAll(prods);
      comandas
        ..clear()
        ..addAll(cmds);
      debugPrint(
        'Carregados: ${produtos.length} produtos, ${comandas.length} comandas',
      );
    } catch (e) {
      ultimoErro = 'Falha ao carregar: $e';
      debugPrint(ultimoErro);
    } finally {
      carregando = false;
      notifyListeners();
    }
  }

  bool _atualizando = false;

  /// Atualização periódica em segundo plano (sem indicador de carregamento).
  Future<void> atualizarSilencioso() async {
    if (_atualizando || carregando) return;
    // Mudanças feitas sem rede: envia primeiro. Enquanto restar fila, NÃO
    // troca os dados locais pelos do servidor (apagaria o que ainda não subiu).
    if (!filaOffline.vazia) {
      await filaOffline.sincronizar();
      if (!filaOffline.vazia) return;
    }
    _atualizando = true;
    try {
      final prods = await _repo.fetchProdutos();
      final cmds = await _repo.fetchComandasComItens();
      final ls = await _repo.fetchLotes();
      lotes
        ..clear()
        ..addAll(ls);
      produtos
        ..clear()
        ..addAll(prods);
      comandas
        ..clear()
        ..addAll(cmds);
      notifyListeners();
    } catch (e) {
      debugPrint('Atualização automática falhou: $e');
    } finally {
      _atualizando = false;
    }
  }

  Comanda? buscarComandaPorCodigo(String codigo) {
    final c = codigo.trim().toUpperCase();
    try {
      return comandas.firstWhere((x) => x.codigo.toUpperCase() == c);
    } catch (_) {
      return null;
    }
  }

  Comanda? comandaPorId(String id) {
    try {
      return comandas.firstWhere((x) => x.id == id);
    } catch (_) {
      return null;
    }
  }

  Produto? produtoPorId(String id) {
    try {
      return produtos.firstWhere((x) => x.id == id);
    } catch (_) {
      return null;
    }
  }

  Produto? buscarProdutoPorNome(String nome) {
    final n = nome.trim().toLowerCase();
    try {
      return produtos.firstWhere((p) => p.nome.toLowerCase() == n);
    } catch (_) {
      return null;
    }
  }

  Produto? buscarProdutoPorBarras(String codigo) {
    final c = codigo.trim();
    if (c.isEmpty) return null;
    try {
      return produtos.firstWhere((p) => p.codigoBarras == c);
    } catch (_) {
      return null;
    }
  }

  List<Produto> sugerirProdutos(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];
    return produtos
        .where((p) => p.nome.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  Future<bool> atualizarProduto(Produto p) async {
    final i = produtos.indexWhere((x) => x.id == p.id);
    if (i < 0) return false;
    final anterior = produtos[i];
    produtos[i] = p;
    notifyListeners();
    try {
      await _repo.updateProduto(p);
      Auditoria.registrar('produto_editado',
          'Editou "${p.nome}" (estoque ${p.quantidade}, mínimo ${p.minimo}, preço ${p.preco.toStringAsFixed(2)})',
          entidade: 'produto');
      return true;
    } catch (e) {
      produtos[i] = anterior;
      ultimoErro = 'Erro ao salvar produto: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> adicionarProduto(Produto p) async {
    try {
      final salvo = await _repo.insertProduto(
        Produto(
          id: '',
          nome: p.nome.trim(),
          quantidade: p.quantidade,
          minimo: p.minimo,
          preco: p.preco,
          ambiente: p.ambiente,
          codigoBarras: p.codigoBarras?.trim().isEmpty == true
              ? null
              : p.codigoBarras?.trim(),
          processual: p.processual,
          subcategoria: p.subcategoria,
          publico: p.publico,
          controlaEstoque: p.controlaEstoque,
          diasAvisoValidade: p.diasAvisoValidade,
        ),
      );
      produtos.add(salvo);
      notifyListeners();
      Auditoria.registrar('produto_criado', 'Cadastrou "${salvo.nome}"',
          entidade: 'produto');
      return true;
    } catch (e) {
      ultimoErro = 'Erro ao criar produto: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmarRepos(
    List<LinhaRepos> linhas, {
    required double valorInvestido,
    String? notaId, // nota importada (foto/QR) que originou esta reposição
  }) async {
    final validas = linhas
        .where((l) => !l.pendente && l.qtdEntrada > 0 && l.produtoId != null)
        .toList();
    if (validas.isEmpty) {
      ultimoErro = 'Nenhum item válido para reposição';
      return false;
    }
    try {
      final List<Map<String, dynamic>> payload = [];
      for (final l in validas) {
        final p = produtoPorId(l.produtoId!);
        final int antes = p?.quantidade ?? l.estoqueAtual;
        payload.add({
          'produto_id': l.produtoId,
          'nome': l.nome,
          'quantidade_entrada': l.qtdEntrada,
          'estoque_antes': antes,
        });
      }

      final reposicaoId = await _repo.confirmarRepos(
        itens: payload,
        valorInvestido: valorInvestido,
      );

      // O estoque já foi atualizado: falha ao marcar a nota não derruba a reposição.
      if (notaId != null) {
        try {
          await _repo.marcarNotaConfirmada(
            notaId: notaId,
            valorInvestido: valorInvestido,
            reposicaoId: reposicaoId,
          );
        } catch (e) {
          debugPrint('Nota $notaId não marcada como confirmada: $e');
        }
      }

      for (final l in validas) {
        final p = produtoPorId(l.produtoId!);
        if (p != null) {
          p.quantidade = p.quantidade + l.qtdEntrada;
        }
        if (l.validade != null) {
          try {
            await _repo.inserirLote(
              produtoId: l.produtoId!,
              quantidade: l.qtdEntrada,
              validade: l.validade!,
            );
          } catch (e) {
            debugPrint('Lote não salvo (rode lotes_validade.sql): $e');
          }
        }
      }
      lotes
        ..clear()
        ..addAll(await _repo.fetchLotes());
      notifyListeners();
      Auditoria.registrar('reposicao',
          'Reposição de ${validas.length} item(ns), investido R\$ ${valorInvestido.toStringAsFixed(2)}',
          entidade: 'reposicao');
      return true;
    } catch (e) {
      ultimoErro = 'Erro na reposição: $e';
      notifyListeners();
      return false;
    }
  }

  // ---------- NOTAS IMPORTADAS (foto / QR) ----------

  /// Grava a nota lida como rascunho. Se o servidor falhar, devolve a nota
  /// SEM id (o usuário ainda pode conferir e confirmar; só não fica salva).
  Future<NotaImportada> salvarNotaRascunho(
    NotaParseResult r, {
    required String origem,
    int qtdFotos = 0,
  }) async {
    final nota = NotaImportada(
      origem: origem,
      chaveAcesso: r.chaveAcesso,
      urlQr: r.urlQr,
      totalNota: r.totalNota,
      textoBruto: r.textoBruto,
      qtdFotos: qtdFotos,
      itens: r.itens.map((i) => i.copy()).toList(),
    );
    try {
      nota.id = await _repo.insertNotaRascunho(nota);
    } catch (e) {
      ultimoErro = 'Erro ao salvar rascunho da nota: $e';
      debugPrint(ultimoErro);
    }
    return nota;
  }

  /// Registra leitura x correção final (melhor esforço; nunca bloqueia).
  Future<void> registrarCorrecaoNota({
    String? notaId,
    required String origem,
    required String textoBruto,
    required List<Map<String, dynamic>> itensLidos,
    required List<Map<String, dynamic>> itensFinais,
    double? totalLido,
    double? totalFinal,
  }) async {
    try {
      await _repo.insertNotaCorrecao(
        notaId: notaId,
        origem: origem,
        textoBruto: textoBruto,
        itensLidos: itensLidos,
        itensFinais: itensFinais,
        totalLido: totalLido,
        totalFinal: totalFinal,
      );
    } catch (e) {
      debugPrint('Correção da nota não registrada: $e');
    }
  }

  /// Grava as edições da conferência no rascunho (melhor esforço).
  Future<bool> atualizarNotaRascunho(NotaImportada nota) async {
    final id = nota.id;
    if (id == null) return false;
    try {
      await _repo.salvarEdicaoNota(
        notaId: id,
        itens: nota.itens,
        totalNota: nota.totalNota,
      );
      return true;
    } catch (e) {
      ultimoErro = 'Erro ao atualizar rascunho da nota: $e';
      debugPrint(ultimoErro);
      return false;
    }
  }

  /// Nota já lida/salva com esta chave (com itens), ou null. Evita consultar
  /// a SEFAZ de novo: ela recusa consultas repetidas da mesma nota.
  Future<NotaImportada?> notaPorChave(String chave) async {
    try {
      final id = await _repo.fetchIdNotaPorChave(chave);
      if (id == null) return null;
      return await _repo.fetchNotaComItens(id);
    } catch (e) {
      debugPrint('Erro ao buscar nota por chave: $e');
      return null;
    }
  }

  Future<List<NotaImportada>> notasPendentes() async {
    try {
      return await _repo.fetchNotasPendentes();
    } catch (e) {
      ultimoErro = 'Erro ao listar notas pendentes: $e';
      debugPrint(ultimoErro);
      return [];
    }
  }

  Future<NotaImportada?> abrirNota(String id) async {
    try {
      return await _repo.fetchNotaComItens(id);
    } catch (e) {
      ultimoErro = 'Erro ao abrir a nota: $e';
      debugPrint(ultimoErro);
      return null;
    }
  }

  Future<bool> descartarNota(String id) async {
    try {
      await _repo.cancelarNota(id);
      return true;
    } catch (e) {
      ultimoErro = 'Erro ao descartar a nota: $e';
      debugPrint(ultimoErro);
      return false;
    }
  }

  /// Grava a mudança de um item da comanda e do estoque (juntos, no
  /// servidor). Sem conexão, guarda na fila e segue: o envio acontece quando a
  /// rede voltar. [delta] = quanto a quantidade do ITEM mudou.
  Future<void> _gravarMudancaItem({
    required Comanda comanda,
    required ItemComanda item,
    required Produto produto,
    required int delta,
  }) async {
    final dados = <String, dynamic>{
      'op': FilaOffline.novoId(),
      'codigo': comanda.codigo,
      'produto_id': produto.id,
      'nome': produto.nome,
      'preco': item.precoUnitario,
      'processual': item.processual,
      'delta': delta,
    };
    try {
      produto.quantidade = await _repo.registrarItemComanda(
        op: dados['op'] as String,
        codigo: comanda.codigo,
        produtoId: produto.id,
        nome: produto.nome,
        preco: item.precoUnitario,
        processual: item.processual,
        delta: delta,
      );
    } on FuncaoAusenteException {
      // Plano B (antes de rodar atomicidade.sql): dois passos.
      produto.quantidade = await _repo.ajustarEstoque(produto.id, -delta,
          minimo: delta > 0 ? 0 : null);
      try {
        await _repo.upsertItemComanda(
            comandaCodigo: comanda.codigo, item: item, delta: delta);
      } catch (e) {
        try {
          await _repo.ajustarEstoque(produto.id, delta);
        } catch (_) {}
        rethrow;
      }
    } catch (e) {
      if (!FilaOffline.ehErroDeRede(e)) rethrow;
      await filaOffline.enfileirar(dados);
    }
  }

  Future<bool> tentarAdicionarItem(String comandaId, Produto produto) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null || !comanda.isAtiva) return false;

    final estoqueAtual = produtoPorId(produto.id);
    if (estoqueAtual == null || estoqueAtual.quantidade < 1) return false;

    final qtdAntes = estoqueAtual.quantidade;
    estoqueAtual.quantidade -= 1;

    ItemComanda? existente;
    for (final i in comanda.itens) {
      if (i.produtoId == produto.id) {
        existente = i;
        break;
      }
    }
    final qtdItemAntes = existente?.quantidade ?? 0;
    final statusAntes = existente?.statusPreparo;

    if (existente != null) {
      existente.quantidade += 1;
      // novo pedido de item processual volta para "aberto"
      if (existente.processual) existente.statusPreparo = 'aberto';
    } else {
      existente = ItemComanda(
        produtoId: produto.id,
        nome: produto.nome,
        quantidade: 1,
        precoUnitario: produto.preco,
        processual: estoqueAtual.processual,
        statusPreparo: estoqueAtual.processual ? 'aberto' : null,
      );
      comanda.itens.add(existente);
    }
    notifyListeners();

    try {
      await _gravarMudancaItem(
        comanda: comanda,
        item: existente,
        produto: estoqueAtual,
        delta: 1,
      );
      Auditoria.registrar('comanda_item_add',
          'Adicionou 1x ${produto.nome} na comanda ${comanda.codigo}',
          entidade: 'comanda', comanda: comanda.codigo);
      return true;
    } catch (e) {
      estoqueAtual.quantidade = qtdAntes;
      if (qtdItemAntes == 0) {
        comanda.itens.remove(existente);
      } else {
        existente.quantidade = qtdItemAntes;
        existente.statusPreparo = statusAntes;
      }
      ultimoErro = 'Erro ao adicionar item: $e';
      notifyListeners();
      return false;
    }
  }

  /// Pedidos (aba Pedidos): comandas ativas com itens processuais.
  int get qtdItensEmAndamento => comandas
      .where((c) => c.isAtiva)
      .fold(0, (s, c) => s + c.itensEmAndamento.length);

  /// Muda a etapa de preparo ('aberto' | 'preparo' | 'finalizado').
  Future<bool> alterarStatusPreparo(
    String comandaId,
    String produtoId,
    String status,
  ) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null) return false;
    ItemComanda? item;
    for (final i in comanda.itens) {
      if (i.produtoId == produtoId && i.processual) {
        item = i;
        break;
      }
    }
    if (item == null) return false;
    final antes = item.statusPreparo;
    item.statusPreparo = status;
    notifyListeners();
    try {
      await _repo.updateStatusPreparo(
        comandaCodigo: comanda.codigo,
        produtoId: produtoId,
        status: status,
      );
      Auditoria.registrar('pedido_status',
          '${item.nome} (comanda ${comanda.codigo}) -> $status',
          entidade: 'comanda', comanda: comanda.codigo);
      return true;
    } catch (e) {
      item.statusPreparo = antes;
      ultimoErro = 'Erro ao atualizar o pedido: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> criarComanda(String codigo) async {
    final c = codigo.trim().toUpperCase();
    if (c.isEmpty) {
      ultimoErro = 'Informe o código da comanda';
      return false;
    }
    try {
      if (await _repo.codigoComandaExiste(c)) {
        ultimoErro = 'Já existe comanda com este código';
        return false;
      }
      final criada = await _repo.insertComanda(codigo: c);
      comandas.insert(0, criada);
      notifyListeners();
      Auditoria.registrar('comanda_criada', 'Criou a comanda $c',
          entidade: 'comanda', comanda: c);
      return true;
    } catch (e) {
      ultimoErro = 'Erro ao criar comanda: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> alterarQtdItem(
    String comandaId,
    String produtoId,
    int delta,
  ) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null || !comanda.isAtiva) return false;

    ItemComanda? item;
    for (final i in comanda.itens) {
      if (i.produtoId == produtoId) {
        item = i;
        break;
      }
    }
    if (item == null) return false;

    final produto = produtoPorId(produtoId);
    if (produto == null) return false;

    final qtdItemAntes = item.quantidade;
    final qtdEstoqueAntes = produto.quantidade;
    final statusAntes = item.statusPreparo;
    var itemDelta = 0; // quanto o ITEM da comanda muda

    if (delta > 0) {
      if (produto.quantidade < delta) return false;
      produto.quantidade -= delta;
      item.quantidade += delta;
      itemDelta = delta;
      if (item.processual) item.statusPreparo = 'aberto';
    } else if (delta < 0) {
      if (item.quantidade <= 0) return false;
      final remover = (-delta) > item.quantidade ? item.quantidade : -delta;
      item.quantidade -= remover;
      produto.quantidade += remover;
      itemDelta = -remover;
      if (item.quantidade <= 0) item.desconto = 0;
    } else {
      return true;
    }
    notifyListeners();

    try {
      await _gravarMudancaItem(
        comanda: comanda,
        item: item,
        produto: produto,
        delta: itemDelta,
      );
      Auditoria.registrar(
          delta > 0 ? 'comanda_item_add' : 'comanda_item_remove',
          '${delta > 0 ? 'Adicionou' : 'Removeu'} ${delta.abs()}x ${item.nome} ${delta > 0 ? 'na' : 'da'} comanda ${comanda.codigo}',
          entidade: 'comanda', comanda: comanda.codigo);
      if (delta < 0) {
        AvisosAdmin.notificar('Item removido da comanda ${comanda.codigo}',
            'tirou ${delta.abs()}x ${item.nome}');
      }
      return true;
    } catch (e) {
      item.quantidade = qtdItemAntes;
      item.statusPreparo = statusAntes;
      produto.quantidade = qtdEstoqueAntes;
      ultimoErro = 'Erro ao atualizar item: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> fecharComanda(
    String comandaId,
    String formaPagamento, {
    double? valorCobrado,
    List<PagamentoParte>? partes,
  }) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null || !comanda.isAtiva) return false;

    final statusAntes = comanda.status;
    final pagAntes = comanda.formaPagamento;
    final totalItens = comanda.total;
    final cobrado = valorCobrado ?? totalItens;

    try {
      await _repo.salvarHistoricoFechamento(
        comanda: comanda,
        pagamento: formaPagamento,
        totalItens: totalItens,
        valorCobrado: cobrado,
        partes: partes,
      );
      await _repo.fecharComandaRemoto(
        comandaId: comandaId,
        pagamento: formaPagamento,
      );
      comanda.status = 'inativa';
      comanda.formaPagamento = formaPagamento;
      notifyListeners();
      Auditoria.registrar('comanda_fechada',
          'Fechou a comanda ${comanda.codigo} (${formaPagamento}, R\$ ${cobrado.toStringAsFixed(2)})',
          entidade: 'comanda', comanda: comanda.codigo);
      if (cobrado < totalItens - 0.005) {
        AvisosAdmin.notificar('Comanda ${comanda.codigo} fechada com valor menor',
            'itens R\$ ${totalItens.toStringAsFixed(2)}, cobrado R\$ ${cobrado.toStringAsFixed(2)}');
      } else {
        AvisosAdmin.notificar('Comanda ${comanda.codigo} fechada',
            'R\$ ${cobrado.toStringAsFixed(2)} ($formaPagamento)');
      }
      return true;
    } catch (e) {
      comanda.status = statusAntes;
      comanda.formaPagamento = pagAntes;
      ultimoErro = 'Erro ao fechar comanda: $e';
      notifyListeners();
      return false;
    }
  }

  /// Exclui a comanda da listagem. Em comanda ativa com itens, pode devolver
  /// as unidades ao estoque (nada foi vendido ainda).
  Future<bool> excluirComanda(
    String comandaId, {
    bool devolverEstoque = false,
  }) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null) return false;
    try {
      await _repo.excluirComandaRemoto(
        comandaId: comanda.id,
        comandaCodigo: comanda.codigo,
      );
      var devolvidos = 0;
      if (devolverEstoque && comanda.isAtiva) {
        for (final i in comanda.itens) {
          final p = produtoPorId(i.produtoId);
          if (p == null || i.quantidade <= 0) continue;
          devolvidos += i.quantidade;
          try {
            p.quantidade = await _repo.ajustarEstoque(p.id, i.quantidade);
          } catch (_) {
            p.quantidade += i.quantidade;
          }
        }
      }
      comandas.removeWhere((c) => c.id == comandaId);
      notifyListeners();
      Auditoria.registrar(
        'comanda_excluida',
        'Excluiu a comanda ${comanda.codigo}'
        '${devolvidos > 0 ? ' (devolveu $devolvidos un. ao estoque)' : ''}',
        entidade: 'comanda',
        comanda: comanda.codigo,
      );
      AvisosAdmin.notificar('Comanda ${comanda.codigo} excluída',
          'itens R\$ ${comanda.total.toStringAsFixed(2)}');
      return true;
    } catch (e) {
      ultimoErro = 'Erro ao excluir comanda: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reabre a comanda do jeito que está (itens mantidos).
  Future<bool> reabrirComanda(String comandaId) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null || comanda.isAtiva) return false;
    try {
      await _repo.reabrirMantendoItensRemoto(comanda: comanda);
      comanda.status = 'ativa';
      comanda.formaPagamento = null;
      notifyListeners();
      Auditoria.registrar('comanda_reaberta',
          'Reabriu a comanda ${comanda.codigo} mantendo os itens',
          entidade: 'comanda', comanda: comanda.codigo);
      AvisosAdmin.notificar('Comanda ${comanda.codigo} reaberta',
          'reaberta com os itens (R\$ ${comanda.total.toStringAsFixed(2)})');
      return true;
    } catch (e) {
      ultimoErro = 'Erro ao reabrir comanda: $e';
      notifyListeners();
      return false;
    }
  }

  /// Define o desconto (R$) de um item da comanda.
  Future<bool> alterarDesconto(
      String comandaId, String produtoId, double valor) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null || !comanda.isAtiva) return false;
    ItemComanda? item;
    for (final i in comanda.itens) {
      if (i.produtoId == produtoId) item = i;
    }
    if (item == null) return false;
    final antes = item.desconto;
    final v = valor < 0 ? 0.0 : (valor > item.bruto ? item.bruto : valor);
    item.desconto = v;
    notifyListeners();
    try {
      await _repo.upsertItemComanda(comandaCodigo: comanda.codigo, item: item);
      Auditoria.registrar('comanda_desconto',
          'Desconto de R\$ ${v.toStringAsFixed(2)} em ${item.nome} (comanda ${comanda.codigo})',
          entidade: 'comanda', comanda: comanda.codigo);
      if (v > 0) {
        AvisosAdmin.notificar('Desconto na comanda ${comanda.codigo}',
            'R\$ ${v.toStringAsFixed(2)} em ${item.quantidade}x ${item.nome}');
      }
      return true;
    } catch (e) {
      item.desconto = antes;
      ultimoErro = 'Erro ao salvar desconto: $e';
      notifyListeners();
      return false;
    }
  }

  /// Soma um atendimento/serviço à comanda (sem mexer no estoque).
  Future<bool> adicionarServicoNaComanda(String comandaId, Produto p) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null || !comanda.isAtiva) {
      ultimoErro = 'Comanda fechada ou não encontrada';
      return false;
    }
    ItemComanda? item;
    for (final i in comanda.itens) {
      if (i.produtoId == p.id) item = i;
    }
    final qtdAntes = item?.quantidade ?? 0;
    final novo = item == null;
    item ??= ItemComanda(
      produtoId: p.id,
      nome: p.nome,
      quantidade: 0,
      precoUnitario: p.preco,
    );
    item.quantidade += 1;
    if (novo) comanda.itens.add(item);
    notifyListeners();
    try {
      await _repo.upsertItemComanda(comandaCodigo: comanda.codigo, item: item);
      Auditoria.registrar('comanda_item_add',
          'Totem: ${item.nome} somado na comanda ${comanda.codigo}',
          entidade: 'comanda', comanda: comanda.codigo);
      return true;
    } catch (e) {
      if (novo) {
        comanda.itens.remove(item);
      } else {
        item.quantidade = qtdAntes;
      }
      ultimoErro = 'Erro ao somar na comanda: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> resetarComanda(String comandaId) async {
    final comanda = comandaPorId(comandaId);
    if (comanda == null || comanda.isAtiva) return false;

    try {
      await _repo.resetarComandaRemoto(
        comandaId: comanda.id,
        comandaCodigo: comanda.codigo,
      );
      comanda.itens.clear();
      comanda.status = 'ativa';
      comanda.formaPagamento = null;
      notifyListeners();
      Auditoria.registrar('comanda_resetada',
          'Reabriu a comanda ${comanda.codigo}',
          entidade: 'comanda', comanda: comanda.codigo);
      AvisosAdmin.notificar('Comanda ${comanda.codigo} zerada',
          'itens apagados e comanda reaberta vazia');
      return true;
    } catch (e) {
      ultimoErro = 'Erro ao resetar comanda: $e';
      notifyListeners();
      return false;
    }
  }

  /// Registra o preparo de um item (ex.: pudim): soma as porções preparadas
  /// ao item e dá baixa nos ingredientes informados.
  Future<bool> registrarPreparo({
    required String produtoId,
    required int quantidade,
    required Map<String, int> ingredientes, // produtoId -> qtd usada
  }) async {
    final prato = produtoPorId(produtoId);
    if (prato == null) return false;
    if (quantidade <= 0) {
      ultimoErro = 'Informe quantas unidades foram preparadas';
      return false;
    }
    for (final e in ingredientes.entries) {
      final ing = produtoPorId(e.key);
      if (ing == null || e.value <= 0) continue;
      if (ing.quantidade < e.value) {
        ultimoErro = 'Estoque insuficiente de ${ing.nome}';
        return false;
      }
    }
    try {
      final usados = <String>[];
      for (final e in ingredientes.entries) {
        final ing = produtoPorId(e.key);
        if (ing == null || e.value <= 0) continue;
        final ok = await baixaManual(
          produtoId: ing.id,
          quantidade: e.value,
          motivo: 'Preparo de ${prato.nome}',
        );
        if (!ok) return false;
        usados.add('${e.value}x ${ing.nome}');
      }
      prato.quantidade = await _repo.ajustarEstoque(prato.id, quantidade);
      notifyListeners();
      Auditoria.registrar(
        'preparo',
        'Preparou $quantidade x ${prato.nome}'
        '${usados.isEmpty ? '' : ' (usou ${usados.join(', ')})'}',
        entidade: 'produto',
      );
      return true;
    } catch (e) {
      ultimoErro = 'Erro ao registrar preparo: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> baixaManual({
    required String produtoId,
    required int quantidade,
    required String motivo,
  }) async {
    final p = produtoPorId(produtoId);
    if (p == null) return false;
    if (quantidade <= 0) {
      ultimoErro = 'Quantidade inválida';
      return false;
    }
    if (p.quantidade < quantidade) {
      ultimoErro = 'Estoque insuficiente';
      return false;
    }
    final antes = p.quantidade;
    final novo = antes - quantidade;
    p.quantidade = novo;
    notifyListeners();
    try {
      p.quantidade = await _repo.registrarBaixa(
        produtoId: p.id,
        nome: p.nome,
        quantidade: quantidade,
        motivo: motivo,
      );
      Auditoria.registrar('baixa_estoque',
          'Baixa de $quantidade x ${p.nome} ($motivo)',
          entidade: 'produto');
      return true;
    } catch (e) {
      p.quantidade = antes;
      ultimoErro = 'Erro na baixa: $e';
      notifyListeners();
      return false;
    }
  }
}

final appState = AppState();