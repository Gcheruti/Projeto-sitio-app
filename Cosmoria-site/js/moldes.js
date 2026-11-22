/* Portal Cosmoria · moldes (desenhos em branco) dos produtos personalizáveis.
   Cada molde tem um ou dois lados. "area" é o retângulo de impressão no desenho (pixels do editor),
   "recorte" é o formato exato que pode ser impresso (ex.: o corpo da camiseta sem as mangas)
   e cm[0] é a largura real dessa área no produto (a altura sai da proporção).
   A tabela Cosmoria.moldes_personalizacao pode trocar o rótulo e a largura em cm. */
(function () {
  function tom(hex, f) { // f > 0 clareia, f < 0 escurece
    var n = parseInt(hex.slice(1), 16), r = n >> 16, g = (n >> 8) & 255, b = n & 255;
    function c(x) { return Math.max(0, Math.min(255, Math.round(f < 0 ? x * (1 + f) : x + (255 - x) * f))); }
    return '#' + ((1 << 24) + (c(r) << 16) + (c(g) << 8) + c(b)).toString(16).slice(1);
  }
  function escuro(hex) { var n = parseInt(hex.slice(1), 16); return ((n >> 16) * 299 + ((n >> 8) & 255) * 587 + (n & 255) * 114) / 1000 < 110; }
  function svg(corpo, w, h) { w = w || 520; h = h || 600; return '<svg xmlns="http://www.w3.org/2000/svg" width="' + w + '" height="' + h + '" viewBox="0 0 ' + w + ' ' + h + '"><rect x="0" y="0" width="' + w + '" height="' + h + '" fill="none"/>' + corpo + '</svg>'; }
  function p(d, fill, stroke, sw, extra) { return '<path d="' + d + '" fill="' + (fill || 'none') + '"' + (stroke ? ' stroke="' + stroke + '" stroke-width="' + (sw || 2) + '" stroke-linejoin="round" stroke-linecap="round"' : '') + (extra || '') + '/>'; }
  // achata a roupa na vertical para ficar com a proporção real (largura x comprimento)
  function achatar(txt, y0, k, topo) { return txt.replace(/(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/g, function (m, x, y) { return x + ',' + (topo + (y - y0) * k).toFixed(1); }); }
  function caixa(d) {
    var xs = [], ys = []; d.replace(/(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/g, function (m, x, y) { xs.push(+x); ys.push(+y); });
    var x = Math.min.apply(null, xs), y = Math.min.apply(null, ys);
    return { x: x, y: y, w: Math.max.apply(null, xs) - x, h: Math.max.apply(null, ys) - y };
  }

  // ---------- camiseta ----------
  var CAM = { y0: 62, k: 0.8, topo: 95 };
  function camiseta(cor, lado) {
    var l = tom(cor, -0.22), s = tom(cor, -0.1);
    var gola = lado === 'frente' ? 'M196,62 Q260,128 324,62' : 'M196,62 Q260,86 324,62';
    return svg(achatar(
      p('M196,62 Q260,128 324,62 L404,88 L482,186 L424,232 L396,204 L396,566 Q260,574 124,566 L124,204 L96,232 L38,186 L116,88 Z', cor, l, 2.5) +
      p(lado === 'frente' ? 'M196,62 Q260,128 324,62 Q260,80 196,62 Z' : 'M196,62 Q260,86 324,62 Q260,70 196,62 Z', tom(cor, -0.3)) +
      p(gola, 'none', s, 9) + p(gola, 'none', l, 1.5) +
      p('M124,204 Q132,150 116,88', 'none', l, 1.5) + p('M396,204 Q388,150 404,88', 'none', l, 1.5) +
      p('M102,226 L44,182', 'none', s, 1.5, ' stroke-dasharray="4 4"') + p('M418,226 L476,182', 'none', s, 1.5, ' stroke-dasharray="4 4"') +
      p('M128,552 Q260,560 392,552', 'none', s, 1.5, ' stroke-dasharray="4 4"') +
      p('M150,250 Q160,400 140,540', 'none', '#000', 10, ' opacity="0.035"') + p('M370,250 Q360,400 380,540', 'none', '#000', 10, ' opacity="0.035"'), CAM.y0, CAM.k, CAM.topo));
  }
  // ---------- baby look ----------
  var BABY = { y0: 70, k: 0.72, topo: 118 };
  function babylook(cor, lado) {
    var l = tom(cor, -0.22), s = tom(cor, -0.1);
    var gola = lado === 'frente' ? 'M204,70 Q260,126 316,70' : 'M204,70 Q260,92 316,70';
    return svg(achatar(
      p('M204,70 Q260,126 316,70 L388,92 L446,176 L398,212 L378,194 Q362,300 384,566 Q260,574 136,566 Q158,300 142,194 L122,212 L74,176 L132,92 Z', cor, l, 2.5) +
      p(lado === 'frente' ? 'M204,70 Q260,126 316,70 Q260,86 204,70 Z' : 'M204,70 Q260,92 316,70 Q260,78 204,70 Z', tom(cor, -0.3)) +
      p(gola, 'none', s, 8) + p(gola, 'none', l, 1.5) +
      p('M142,194 Q146,140 132,92', 'none', l, 1.5) + p('M378,194 Q374,140 388,92', 'none', l, 1.5) +
      p('M140,552 Q260,560 380,552', 'none', s, 1.5, ' stroke-dasharray="4 4"') +
      p('M160,250 Q150,330 160,420', 'none', '#000', 10, ' opacity="0.04"') + p('M360,250 Q370,330 360,420', 'none', '#000', 10, ' opacity="0.04"'), BABY.y0, BABY.k, BABY.topo));
  }
  // ---------- moletom ----------
  var MOL = { y0: 14, k: 0.78, topo: 72 };
  function moletom(cor, lado) {
    var l = tom(cor, -0.22), s = tom(cor, -0.1), d = tom(cor, -0.3);
    var base = p('M446,524 L494,512 L498,548 L450,558 Z', s, l, 2) + p('M74,524 L26,512 L22,548 L70,558 Z', s, l, 2) +
      p('M192,74 Q260,118 328,74 L408,98 Q452,140 466,250 L494,512 L446,524 L414,290 L400,262 L400,540 L120,540 L120,262 L106,290 L74,524 L26,512 L54,250 Q68,140 112,98 Z', cor, l, 2.5) +
      p('M120,540 L400,540 L400,574 L120,574 Z', s, l, 2) +
      p('M120,262 Q124,170 112,98', 'none', l, 1.5) + p('M400,262 Q396,170 408,98', 'none', l, 1.5);
    if (lado === 'frente') return svg(achatar(
      p('M178,82 Q172,20 260,14 Q348,20 342,82 Q300,62 260,62 Q220,62 178,82 Z', s, l, 2) + base +
      p('M192,74 Q260,118 328,74 Q260,92 192,74 Z', d) + p('M192,74 Q260,118 328,74', 'none', l, 2) +
      p('M238,104 L234,172', 'none', tom(cor, escuro(cor) ? 0.5 : -0.4), 3) + p('M282,104 L286,172', 'none', tom(cor, escuro(cor) ? 0.5 : -0.4), 3) +
      p('M176,420 L344,420 L372,514 L148,514 Z', 'none', l, 2) + p('M182,428 L338,428', 'none', s, 1.5, ' stroke-dasharray="4 4"'), MOL.y0, MOL.k, MOL.topo));
    return svg(achatar(base + p('M186,78 Q260,44 334,78 L322,176 Q260,206 198,176 Z', s, l, 2) + p('M206,90 Q260,66 314,90 L304,168 Q260,190 216,168 Z', 'none', l, 1.2, ' stroke-dasharray="4 4"'), MOL.y0, MOL.k, MOL.topo));
  }
  // ---------- caneca: vitrine (desenho da caneca) e folha que dá a volta ----------
  function canecaVitrine(cor) {
    var l = tom(cor, -0.22), alca = 'M370,236 Q452,236 452,322 Q452,408 370,408';
    return svg(
      p(alca, 'none', l, 30) + p(alca, 'none', cor, 24) +
      p('M150,170 L370,170 L370,474 Q370,502 340,502 L180,502 Q150,502 150,474 Z', cor, l, 2.5) +
      '<ellipse cx="260" cy="170" rx="110" ry="22" fill="' + tom(cor, -0.35) + '" stroke="' + l + '" stroke-width="2.5"/>' +
      '<ellipse cx="260" cy="175" rx="98" ry="15" fill="' + tom(cor, -0.5) + '" opacity="0.5"/>' +
      p('M168,200 L168,470', 'none', '#fff', 14, ' opacity="0.18"') + p('M352,200 L352,470', 'none', '#000', 12, ' opacity="0.06"'));
  }
  var FOLHA = { x: 20, y: 30, w: 600, h: 258 }; // 20 x 8,6 cm (mesma proporção das artes de caneca)
  function canecaFolha(cor) {
    var a = FOLHA, l = tom(cor, -0.18);
    return svg('<rect x="' + a.x + '" y="' + a.y + '" width="' + a.w + '" height="' + a.h + '" rx="4" fill="' + cor + '" stroke="' + l + '" stroke-width="1.5"/>', 640, 310);
  }
  // ---------- ecobag ----------
  function ecobag(cor) {
    var l = tom(cor, -0.22), s = tom(cor, -0.1);
    return svg(
      p('M184,196 Q184,40 260,40 Q336,40 336,196', 'none', l, 22) + p('M184,196 Q184,40 260,40 Q336,40 336,196', 'none', s, 16) +
      p('M120,190 L400,190 L412,572 L108,572 Z', cor, l, 2.5) +
      p('M122,210 L398,210', 'none', l, 1.5, ' stroke-dasharray="5 4"') + p('M112,556 L408,556', 'none', l, 1.5, ' stroke-dasharray="5 4"') +
      p('M140,230 Q132,400 136,540', 'none', '#000', 10, ' opacity="0.035"'));
  }

  // área de impressão = corpo da roupa, sem as mangas
  function corpo(d, A, larguraCm) { var r = achatar(d, A.y0, A.k, A.topo), a = caixa(r); return { recorte: r, area: a, cm: [larguraCm, +(larguraCm * a.h / a.w).toFixed(1)] }; }
  function lado(rotulo, o) { o.rotulo = rotulo; return o; }

  window.MOLDES = {
    camiseta: { desenho: camiseta, lados: {
      frente: lado('Frente', corpo('M124,204 Q132,150 116,88 L196,62 Q260,128 324,62 L404,88 Q388,150 396,204 L396,566 Q260,574 124,566 Z', CAM, 52)),
      verso:  lado('Costas', corpo('M124,204 Q132,150 116,88 L196,62 Q260,86 324,62 L404,88 Q388,150 396,204 L396,566 Q260,574 124,566 Z', CAM, 52)) } },
    babylook: { desenho: babylook, lados: {
      frente: lado('Frente', corpo('M142,194 Q146,140 132,92 L204,70 Q260,126 316,70 L388,92 Q374,140 378,194 Q362,300 384,566 Q260,574 136,566 Q158,300 142,194 Z', BABY, 46)),
      verso:  lado('Costas', corpo('M142,194 Q146,140 132,92 L204,70 Q260,92 316,70 L388,92 Q374,140 378,194 Q362,300 384,566 Q260,574 136,566 Q158,300 142,194 Z', BABY, 46)) } },
    moletom: { desenho: moletom, lados: {
      frente: lado('Frente', corpo('M120,262 Q124,170 112,98 L192,74 Q260,118 328,74 L408,98 Q396,170 400,262 L400,574 L120,574 Z', MOL, 58)),
      verso:  lado('Costas', corpo('M120,262 Q124,170 112,98 L186,78 L200,180 Q260,208 320,180 L334,78 L408,98 Q396,170 400,262 L400,574 L120,574 Z', MOL, 58)) } },
    caneca: { desenho: canecaFolha, vitrine: canecaVitrine, vitrineArea: { x: 172, y: 210, w: 176, h: 209 }, tela: { w: 640, h: 310 }, envolve: true, lados: {
      frente: { rotulo: 'Volta inteira', area: FOLHA, cm: [20, 8.6],
        marcas: [{ x: FOLHA.x, texto: 'alça', alinhar: 'left' }, { x: FOLHA.x + FOLHA.w / 2, texto: 'frente da caneca' }, { x: FOLHA.x + FOLHA.w, texto: 'alça', alinhar: 'right' }] } } },
    ecobag: { desenho: ecobag, lados: {
      frente: { rotulo: 'Frente', area: { x: 150, y: 236, w: 220, h: 279 }, cm: [30, 38] },
      verso:  { rotulo: 'Verso',  area: { x: 150, y: 236, w: 220, h: 279 }, cm: [30, 38] } } }
  };
  window.MOLDES_util = { tom: tom, escuro: escuro };
})();
