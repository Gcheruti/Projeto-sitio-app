/* Portal Cosmoria · ver-arte.html: o designer abre o link do Telegram/e-mail e vê a peça em 3D,
   exatamente com a arte que o cliente montou. Só funciona com o link completo (id + chave). */
document.addEventListener('DOMContentLoaded', async function () {
  var K = window.Cosmoria, $ = function (id) { return document.getElementById(id); };
  function aviso(t) { $('va-msg').hidden = false; $('va-msg').textContent = t; $('va-dica').hidden = true; $('va-produto').textContent = ''; }
  var id = K.param('id'), chave = K.param('k');
  if (!id || !chave) return aviso('Link incompleto. Abra o link inteiro que chegou no Telegram ou no e-mail.');
  var r = await K.sb.rpc('arte_para_ver', { p_id: id, p_chave: chave });
  if (r.error || !r.data) return aviso('Não encontramos essa arte. Confira se o link está completo.');
  var a = r.data, M = window.MOLDES[a.modelo];
  $('va-codigo').textContent = a.nome_peca ? '“' + a.nome_peca + '” · #' + a.codigo : 'Arte #' + a.codigo;
  $('va-produto').textContent = [a.produto, a.variante, a.quantidade ? a.quantidade + ' un.' : ''].filter(Boolean).join(' · ');
  document.title = 'Arte #' + a.codigo + ' em 3D · Portal Cosmoria';
  if (!M) return aviso('Modelo de produto desconhecido: ' + a.modelo);
  var palco = window.Palco3D ? Palco3D($('palco')) : null;
  if (!palco) return aviso('Este aparelho não mostra 3D. Use os arquivos do pacote .zip.');
  var hex = /^#[0-9a-f]{6}$/i.test(a.cor || '') ? a.cor : '#F4F3EF';

  function imagem(src) { return new Promise(function (ok) { if (!src) return ok(null); var im = new Image(); im.onload = function () { ok(im); }; im.onerror = function () { ok(null); }; im.src = src; }); }
  function svg(txt) { return imagem('data:image/svg+xml;charset=utf-8,' + encodeURIComponent(txt)); }
  async function peca(l, arte) { // desenho da peça com a arte na área de impressão (como no editor)
    var t = M.tela || { w: 520, h: 600 }, k = 2, c = document.createElement('canvas'); c.width = t.w * k; c.height = t.h * k;
    var x = c.getContext('2d'), fundo = await svg(M.desenho(hex, l)), ar = M.lados[l].area;
    if (fundo) x.drawImage(fundo, 0, 0, c.width, c.height);
    if (arte) x.drawImage(arte, ar.x * k, ar.y * k, ar.w * k, ar.h * k);
    return c;
  }
  var artF = await imagem(a.arte_frente), artV = await imagem(a.arte_verso);
  if (M.envolve) palco.caneca(artF, hex);
  else palco.roupa(await peca('frente', artF), await peca(M.lados.verso ? 'verso' : 'frente', M.lados.verso ? artV : artF), a.modelo === 'ecobag' ? 0.13 : 0.36, a.modelo);

  $('va-botoes').hidden = false;
  if (M.envolve || !M.lados.verso) document.querySelectorAll('[data-lado]').forEach(function (b) { b.hidden = true; });
  document.querySelectorAll('[data-lado]').forEach(function (b) {
    b.onclick = function () { palco.lado(b.dataset.lado); document.querySelectorAll('[data-lado]').forEach(function (x) { x.setAttribute('aria-pressed', x === b); }); };
  });
  $('va-fundo').onclick = function () { var e = $('va').classList.toggle('escuro'); this.setAttribute('aria-pressed', e); };
  if (a.arte_frente) { $('va-baixar-f').href = a.arte_frente; $('va-baixar-f').download = 'arte-' + a.codigo + '-frente.png'; } else $('va-baixar-f').hidden = true;
  if (a.arte_verso) { $('va-baixar-v').hidden = false; $('va-baixar-v').href = a.arte_verso; $('va-baixar-v').download = 'arte-' + a.codigo + '-costas.png'; $('va-baixar-f').textContent = 'PNG frente'; }
  $('palco').addEventListener('pointerdown', function () { $('va-dica').hidden = true; }, { once: true });
});
