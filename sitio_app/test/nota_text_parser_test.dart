import 'package:flutter_test/flutter_test.dart';
import 'package:sitio_app/models/nota_importada.dart';
import 'package:sitio_app/models/produto.dart';
import 'package:sitio_app/services/nota_text_parser.dart';
import 'package:sitio_app/services/produto_matcher.dart';

void main() {
  group('NotaTextParser', () {
    test('uma linha, com vírgula e com ponto decimal', () {
      final r = NotaTextParser.parsear(
        'LEITE ITALAC 1l 8 UN 7,59 60,72\n'
        'AGUA 12 UN 2.50 30.00\n'
        'VALOR A PAGAR R\$ 90,72',
      );
      expect(r.itens.length, 2);
      expect(r.itens[0].nome, 'LEITE ITALAC 1l');
      expect(r.itens[0].quantidade, 8);
      expect(r.itens[0].valorUnitario, 7.59);
      expect(r.itens[0].valorTotal, 60.72);
      expect(r.itens[1].nome, 'AGUA');
      expect(r.itens[1].valorUnitario, 2.5);
      expect(r.totalNota, 90.72);
    });

    test('item com nº, EAN e "x"; ignora cabeçalho, troco e pagamento', () {
      final r = NotaTextParser.parsear(
        'CNPJ: 12.345.678/0001-90\n'
        'ITEM CODIGO DESCRICAO QTD UN VL UNIT VL TOTAL\n'
        '001 7891000100103 AGUA MINERAL 500ML 12 UN x 2,50 30,00\n'
        '002 123 CAFE PILAO 500G 2 UN x 7,95 15,90\n'
        'QTD. TOTAL DE ITENS 2\n'
        'VALOR TOTAL R\$ 45,90\n'
        'Dinheiro 50,00\n'
        'TROCO R\$ 4,10\n'
        'Chave de acesso 3526 1114 3101 7000 0420 6500 1000 3263 7313 4785 5361',
      );
      expect(r.itens.length, 2);
      expect(r.itens[0].nome, 'AGUA MINERAL 500ML');
      expect(r.itens[0].codigo, '7891000100103');
      expect(r.itens[0].quantidade, 12);
      expect(r.itens[1].nome, 'CAFE PILAO 500G');
      expect(r.totalNota, 45.90);
      expect(r.chaveAcesso, '35261114310170000420650010003263731347855361');
    });

    test('nome em uma linha, quantidade/valores na seguinte', () {
      final r = NotaTextParser.parsear(
        '002 7891234567895 CAFE PILAO 500G\n'
        '2 UN x 7,95 15,90\n'
        'CERVEJA SKOL LATA 350ML (Código: 123)\n'
        'Qtde.:24 UN Vl. Unit.: 3,49 Vl. Total 83,76\n'
        'Subtotal 99,66\n'
        'Total R\$ 99,66',
      );
      expect(r.itens.length, 2);
      expect(r.itens[0].nome, 'CAFE PILAO 500G');
      expect(r.itens[0].codigo, '7891234567895');
      expect(r.itens[1].nome, 'CERVEJA SKOL LATA 350ML');
      expect(r.itens[1].quantidade, 24);
      expect(r.itens[1].valorTotal, 83.76);
      // "Vl. Total" do item e "Subtotal" não podem virar o total da nota
      expect(r.totalNota, 99.66);
    });

    test('peso em KG e milhar', () {
      final r = NotaTextParser.parsear(
        'QUEIJO MUSSARELA 0,350 KG x 39,90 13,97\n'
        'WHISKY JOHNNIE 1 UN 1.299,90 1.299,90\n'
        'TOTAL\n'
        '1.313,87',
      );
      expect(r.itens.length, 2);
      expect(r.itens[0].quantidade, 0.35);
      expect(r.itens[1].valorUnitario, 1299.90);
      expect(r.totalNota, 1313.87);
    });

    test('marca como suspeito quando qtd × unitário não bate com o total', () {
      final r = NotaTextParser.parsear(
        'REFRI 2 L 3 UN 5,00 16,00\n'
        '1 AGUA 2 UN 2,50 5,00',
      );
      expect(r.itens.length, 2);
      expect(r.itens[0].nome, 'REFRI 2 L');
      expect(r.itens[0].suspeito, isTrue);
      expect(r.itens[1].nome, 'AGUA');
      expect(r.itens[1].suspeito, isFalse);
    });

    test('não inventa itens em linhas que não são produto', () {
      final r = NotaTextParser.parsear(
        'CNPJ 12.345.678/0001-90 IE 123.456.789.110\n'
        'CPF 123.456.789-00\n'
        'Dinheiro 50,00 4,10\n'
        'TROCO R\$ 4,10\n'
        'FORMA PAGAMENTO VALOR PAGO\n'
        'Cartão de crédito 45,90 45,90\n'
        'Tributos totais incluídos 5,20 3,10\n'
        'NFC-e nº 000123 Série 001 14/11/2026 18:20:11\n'
        'Consulte pela chave em www.fazenda.gov.br',
      );
      expect(r.itens, isEmpty);
      expect(r.totalNota, isNull);
    });

    test('NFC-e de SP (texto real do OCR): item em várias linhas e ponto decimal', () {
      // Saída real do ML Kit para um cupom fotografado: itens quebrados em 2-3
      // linhas, valores com ponto, chave de acesso partida em duas linhas e
      // erros de leitura ("0LEO", "RADNAG").
      final r = NotaTextParser.parsear(r'''
CNPJ: 14.310.170/0004-20
AUTOZONE BRASIL LUNERC IO DE AUTOPECAs LTDA
Rua Joaquina Ranalho, 987,
São Paulo, VILA GUILHERME, SP
Docuaento Auxiliar da Note Fiscal de Consunidor
Eletrani
I DESC QTDE UN VL Unit R$ 1 VL TOTAL RS
COD
100049219 RQ103012 AGUA DESMINERAL 1.00 X
UN 6.990 6.99
100091383
MO0224 0LEO RADNAG 1504 2.00 X UN 28.990
57.98
2
Qtde. Total de Itens
64.97
Valor TOTAL R$
0
64.97
DescontD total RS
17
Valor a Pagar R$
64.97
FORMA PAGAMENTO
Valor Pago
Consulte pela Chave de Acesso en
https://uww.nfce.fazenda. sp.gov.br/consulta
3526 1114 3101 7000 0420 6500 1000 3263 7313
4785 5361
31347855361
3526111431017
CONSUWIDOR NAO IDENTIFICADO
NFC-e ng 326373 Série 1 2026-1-04T15:00:54
Protocolo de Butorização: 13526007592518224
''');
      expect(r.itens.length, 2);
      expect(r.itens[0].nome, 'AGUA DESMINERAL');
      expect(r.itens[0].quantidade, 1);
      expect(r.itens[0].valorUnitario, 6.99);
      expect(r.itens[0].valorTotal, 6.99);
      expect(r.itens[1].nome, 'OLEO RADNAG 1504');
      expect(r.itens[1].quantidade, 2);
      expect(r.itens[1].valorUnitario, 28.99);
      expect(r.itens[1].valorTotal, 57.98);
      expect(r.itens.any((i) => i.suspeito), isFalse);
      expect(r.totalNota, 64.97);
      expect(r.chaveAcesso, '35261114310170000420650010003263731347855361');
    });

    test('Extra/CBD: qtd com (tributos), k9, "9, 79" e desconto sobre item', () {
      final r = NotaTextParser.parsear(r'''
001 250474 BANANA PRATA GNEL KG
1, 164 k9 X 9,99 (3,65) 11,63
002 357593 TOMATE ITALIANO KG
0,746 kg X 22,99 (4,86) 17,15
desconto sobre item -1,72
003 1008315 ADOCYL STEVIA 80ML
1 UN X 9, 79 (3, 08) 9,79
004 1008315 ADOCYL STEVIA 80ML
1 UN X 9,79 (3,08) 9,79
005 1017343 ADOC LIQ SUCRALOSE 2
1 UN X 13, 99 (4,40) 13,99
006 1017343 ADOC LIQ SUCRALOSE 2
1 UN X 13,99 (4.40) 13,99
007 1469349 SACOLA VERDE SP 48X5
1 UN X 0,11 (0,04)
QTD. TOTAL DE ITENS 7
VALOR TOTAL R$ 76,45
DESCONTO R$ 1,72
VALOR A PAGAR R$ 74,73
''');
      expect(r.itens.length, 7);
      expect(r.itens[0].nome, 'BANANA PRATA GNEL KG');
      expect(r.itens[0].quantidade, 1.164);
      expect(r.itens[1].valorTotal, 15.43);
      expect(r.itens[1].suspeito, isFalse);
      expect(r.itens[6].valorTotal, 0.11);
      expect(r.totalNota, 74.73);
    });

    test('Extra/CBD com linhas fora de ordem (valor da direita separado)', () {
      final r = NotaTextParser.parsear(r'''
001 250474 BANANA PRATA GNEL KG
11,63
1,164 kg X 9,99 (3,65)
002 357593 TOMATE ITALIANO KG
0,746 kg X 22,99 (4,86)
17,15
desconto sobre item
-1,72
003 1008315 ADOCYL STEVIA 80ML 1 UN X 9,79 (3,08)
004 1008315 ADOCYL STEVIA 80ML
9,79
1 UN X 9,79 (3,08)
005 1017343 ADOC LIQ SUCRALOSE Z
1 UN X 13,99 (4,40) 13,99
006 1017343 ADOC LIQ SUCRALOSE Z
1 UN X 13,99 (4,40)
13,99
007 1469349 SACOLA VERDE SP 48X5
1 UN X 0,11 (0,04)
0,11
QTD. TOTAL DE ITENS 7
VALOR A PAGAR R$ 74,73
''');
      expect(r.itens.length, 7);
      expect(r.itens[1].valorTotal, 15.43);
      expect(r.itens[2].valorTotal, 9.79);
      expect(r.itens[4].nome, 'ADOC LIQ SUCRALOSE Z');
      expect(r.totalNota, 74.73);
    });

    test('comprovante de entrega: tabela Produto / Qtd / Total', () {
      final r = NotaTextParser.parsear(r'''
VENDA
COO: 007835 Orçamento: 617560
Total: 97,51 Atendente: sistema
ITENS A ENTREGAR
Praduto Qtd Total
OMEPRAZOL. 20MG 568 TEUTO 1,00 20,86
ENALAPRIL 20WG 30'S CIHED 2,00 21,74
CIPROF IBRATO 100HG 30'S MEDLEY 1,00 54.91
PRGAHENTOS REAL IZAD0S
Forna Pgto. Valor
IFO0D 97.51
Total 97.51
''');
      expect(r.itens.length, 3);
      expect(r.itens[0].nome, 'OMEPRAZOL. 20MG 568 TEUTO');
      expect(r.itens[1].quantidade, 2);
      expect(r.itens[1].valorUnitario, 10.87);
      expect(r.itens[1].valorTotal, 21.74);
      expect(r.itens[2].valorTotal, 54.91);
      expect(r.totalNota, 97.51);
    });

    test('chave com dígito verificador errado é ignorada', () {
      final r = NotaTextParser.parsear(
        'AGUA 1 UN 2,00 2,00\n3526 1114 3101 7000 0420 6500 1000 3263 7313 4785 5362',
      );
      expect(r.chaveAcesso, isNull);
    });

    test('juntar: várias fotos somam itens; total vem da última que o tem', () {
      final a = NotaTextParser.parsear('AGUA 12 UN 2,50 30,00');
      final b = NotaTextParser.parsear('CAFE 2 UN 7,95 15,90\nTotal R\$ 45,90');
      final r = NotaTextParser.juntar([a, b]);
      expect(r.itens.length, 2);
      expect(r.totalNota, 45.90);
      expect(r.textoBruto, contains('--- foto 2 ---'));
    });
  });

  group('NotaItem', () {
    test('totalCalculado usa o total lido ou qtd × unitário', () {
      expect(NotaItem(nome: 'x', quantidade: 3, valorUnitario: 2).totalCalculado, 6);
      expect(
        NotaItem(nome: 'x', quantidade: 3, valorUnitario: 2, valorTotal: 7)
            .totalCalculado,
        7,
      );
      expect(NotaItem(nome: 'x').totalCalculado, isNull);
    });
  });

  group('ProdutoMatcher', () {
    final produtos = [
      Produto(id: '1', nome: 'Água 500ml', quantidade: 5, minimo: 2, preco: 4, ambiente: 'Salão', codigoBarras: '7891000100103'),
      Produto(id: '2', nome: 'Café Pilão 500g', quantidade: 5, minimo: 2, preco: 20, ambiente: 'Loja'),
      Produto(id: '3', nome: 'Coca-Cola 350ml', quantidade: 5, minimo: 2, preco: 6, ambiente: 'Salão'),
    ];

    test('acha por nome parecido, ignorando acento e caixa', () {
      expect(ProdutoMatcher.sugerir(produtos, 'AGUA MINERAL 500ML')?.id, '1');
      expect(ProdutoMatcher.sugerir(produtos, 'CAFE PILAO 500G')?.id, '2');
    });

    test('código de barras tem prioridade', () {
      expect(
        ProdutoMatcher.sugerir(produtos, 'qualquer nome', codigoBarras: '7891000100103')?.id,
        '1',
      );
    });

    test('não confunde tamanhos diferentes', () {
      expect(ProdutoMatcher.sugerir(produtos, 'COCA COLA 2L'), isNull);
    });
  });
}
