import test from 'node:test';
import assert from 'node:assert/strict';
import { chaveValida, montarUrl, numBR, parseHtml, parseXml, consultarNfce } from './nfce.ts';

// Chave real de documento público (cota parlamentar, SP, modelo 65).
const CHAVE = '35260537866791000147650020000717961837664556';

// HTML SINTÉTICO no layout clássico da consulta pública; confirmar com nota real.
const HTML = `<table id="tabResult">
<tr id="Item + 1"><td valign="top"><span class="txtTit">AGUA MINERAL 500ML</span><span class="RCod">(Código: 100049219 )</span>
<span class="Rqtd"><strong>Qtde.:</strong>12,0000</span><span class="RUN"><strong>UN: </strong>UN</span>
<span class="RvlUnit"><strong>Vl. Unit.:</strong>&nbsp;2,5000</span></td><td class="txtTit noWrap">Vl. Total <span class="valor">30,00</span></td></tr>
<tr id="Item + 2"><td><span class="txtTit">CAFE PILAO 500G</span><span class="RCod">(Código: 77 )</span>
<span class="Rqtd"><strong>Qtde.:</strong>2</span><span class="RvlUnit"><strong>Vl. Unit.:</strong> 7,95</span></td>
<td class="txtTit noWrap">Vl. Total <span class="valor">15,90</span></td></tr></table>
Valor a pagar R$ <span class="totalNumb txtMax">45,90</span>`;

test('chave', () => {
  assert.equal(chaveValida(CHAVE), true);
  assert.equal(chaveValida(CHAVE.slice(0, 43) + '0'), false);
});
test('montarUrl', () => {
  assert.equal(montarUrl(CHAVE).url, `https://www.nfce.fazenda.sp.gov.br/qrcode?p=${CHAVE}|3|1`);
  const evil = `https://evil.com/x?p=${CHAVE}|3|1`;
  assert.ok(montarUrl(evil).url.startsWith('https://www.nfce.fazenda.sp.gov.br/'));
  assert.ok(montarUrl('35' + '1'.repeat(42)).erro);
});
test('numBR', () => {
  assert.equal(numBR('1.299,90'), 1299.9);
  assert.equal(numBR('Qtde.: 12,0000'), 12);
  assert.equal(numBR('1.5'), 1.5);
});
test('parseHtml', () => {
  const r = parseHtml(HTML);
  assert.equal(r.items.length, 2);
  assert.deepEqual(r.items[0], { name: 'AGUA MINERAL 500ML', qty: 12, unit_price: 2.5, total: 30, codigo: '100049219' });
  assert.equal(r.total, 45.9);
});
test('parseXml', () => {
  const r = parseXml('<nfeProc><det nItem="1"><prod><cProd>1</cProd><cEAN>SEM GTIN</cEAN><xProd>LEITE</xProd><qCom>3.0000</qCom><vUnCom>4.50</vUnCom><vProd>13.50</vProd></prod></det><vNF>13.50</vNF></nfeProc>');
  assert.equal(r.items[0].qty, 3);
  assert.equal(r.total, 13.5);
});
test('consultarNfce fim a fim com fetch falso', async () => {
  const f = async () => { const r = new Response(HTML); Object.defineProperty(r, 'url', { value: 'https://www.nfce.fazenda.sp.gov.br/qrcode' }); return r; };
  const r = await consultarNfce(`https://www.nfce.fazenda.sp.gov.br/qrcode?p=${CHAVE}|3|1`, f);
  assert.equal(r.ok, true);
  assert.equal(r.items.length, 2);
  const vazio = await consultarNfce(CHAVE, async () => new Response('<html>captcha</html>'));
  assert.equal(vazio.ok, false);
  assert.match(vazio.error, /captcha/);
});
