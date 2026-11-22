/* Portal Cosmoria · tema: logo e vitrine de fotos do card inicial.
   Para usar, coloque os arquivos na pasta img/ do site:
     img/logo.png (ou logo.jpg)           -> substitui a lua no topo
     img/vitrine-1.jpg ... vitrine-8.jpg  -> fotos que passam no card inicial (também aceita .png)  */
(function () {
  function carregar(urls, ok, falhou) {
    var i = 0;
    (function tentar() {
      if (i >= urls.length) { if (falhou) falhou(); return; }
      var img = new Image(), u = urls[i++];
      img.onload = function () { ok(u, img); };
      img.onerror = tentar;
      img.src = u;
    })();
  }

  function logo() {
    var C = window.COSMORIA || {};
    if (C.logo) return;
    carregar(['img/logo.png', 'img/logo.jpg', 'img/logo.webp'], function (u) {
      document.querySelectorAll('.marca').forEach(function (m) {
        var svg = m.querySelector('svg'); if (!svg) return;
        var img = document.createElement('img'); img.src = u; img.alt = '';
        svg.replaceWith(img);
      });
    });
  }

  function vitrine() {
    var arco = document.querySelector('.arco'); if (!arco) return;
    var fotos = [], pendentes = 8;
    for (var n = 1; n <= 8; n++) (function (n) {
      carregar(['img/vitrine-' + n + '.jpg', 'img/vitrine-' + n + '.png', 'img/vitrine-' + n + '.webp'],
        function (u) { fotos[n] = u; fim(); }, fim);
    })(n);
    function fim() {
      if (--pendentes > 0) return;
      var lista = fotos.filter(Boolean); if (!lista.length) return;
      var box = document.createElement('div'); box.className = 'vitrine';
      lista.forEach(function (u, i) { var im = document.createElement('img'); im.src = u; im.alt = ''; if (!i) im.className = 'ativa'; box.appendChild(im); });
      arco.appendChild(box);
      arco.setAttribute('aria-label', 'Fotos da Portal Cosmoria');
      if (lista.length < 2) return;
      var pontos = document.createElement('div'); pontos.className = 'vitrine-pontos';
      lista.forEach(function (_, i) {
        var b = document.createElement('button'); b.type = 'button'; b.setAttribute('aria-label', 'Foto ' + (i + 1));
        b.setAttribute('aria-pressed', i === 0); b.onclick = function () { ir(i); reiniciar(); }; pontos.appendChild(b);
      });
      arco.appendChild(pontos);
      var atual = 0, timer;
      function ir(i) {
        var ims = box.children, bs = pontos.children;
        ims[atual].className = ''; bs[atual].setAttribute('aria-pressed', 'false');
        atual = i; ims[atual].className = 'ativa'; bs[atual].setAttribute('aria-pressed', 'true');
      }
      function reiniciar() { clearInterval(timer); timer = setInterval(function () { ir((atual + 1) % lista.length); }, 5000); }
      if (!window.matchMedia || !matchMedia('(prefers-reduced-motion: reduce)').matches) reiniciar();
    }
  }

  document.addEventListener('DOMContentLoaded', function () { setTimeout(function () { logo(); vitrine(); }, 0); });
})();
