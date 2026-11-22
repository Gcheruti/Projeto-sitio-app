/* Portal Cosmoria · editor de produtos personalizados (usa Fabric.js, arquivo js/fabric.min.js) */
document.addEventListener('DOMContentLoaded', async function () {
  var K = Cosmoria, sb = K.sb, esc = K.esc, $ = function (id) { return document.getElementById(id); };
  var M = window.MOLDES, tom = MOLDES_util.tom, escuro = MOLDES_util.escuro;
  var LADOS = ['frente', 'verso'];
  // Preço da personalização: por cm² do espaço ocupado pela arte em cada lado (tabela Cosmoria.config_personalizacao)
  var TARIFA_PADRAO = { centavos_por_cm2: 10, minimo_por_lado_centavos: 500 };
  var NOME_TIPO = { texto: 'Texto', imagem: 'Imagem', emoji: 'Emoji', forma: 'Forma' };
  var FONTES = ['Manrope', 'Montserrat', 'Bebas Neue', 'Playfair Display', 'Cormorant Garamond', 'Cinzel', 'Uncial Antiqua', 'Pacifico', 'Lobster', 'Great Vibes', 'Caveat', 'Amatic SC', 'Permanent Marker', 'Righteous'];
  var FONTE_EMOJI = '"Apple Color Emoji","Segoe UI Emoji","Noto Color Emoji",sans-serif';
  var EMOJIS = '🌙 🌕 🌑 ✨ ⭐ 🌟 💫 ☀️ 🪐 🌈 🔮 🧿 🪬 👁️ 🃏 🕯️ 💎 🔥 💧 🌊 ⚡ ❄️ 🌿 🍃 🌱 🌸 🌺 🌻 🌼 🌹 🍄 🍀 🦋 🐈‍⬛ 🦉 🐍 🐺 🦊 🐝 🕊️ ♈ ♉ ♊ ♋ ♌ ♍ ♎ ♏ ♐ ♑ ♒ ♓ ☯️ ☮️ 🕉️ ❤️ 💜 🖤 💚 🤍 💛 🧡 😊 😍 🥰 😎 😂 🙏 👑 🎉 🎂 🎁'.split(' ');
  var CORES = ['#142219', '#F6F1E7', '#C9A45C', '#3F6B4A', '#7A5C24', '#B23A48', '#E07A5F', '#F2CC8F', '#5B4B8A', '#2E86AB', '#FFFFFF', '#000000'];
  var FORMAS = {
    retangulo: { nome: 'Retângulo', icone: '<rect x="3" y="6" width="18" height="12"/>', criar: function (o) { return new fabric.Rect(Object.assign({ width: 130, height: 84 }, o)); } },
    arredondado: { nome: 'Etiqueta', icone: '<rect x="3" y="6" width="18" height="12" rx="4"/>', criar: function (o) { return new fabric.Rect(Object.assign({ width: 130, height: 84, rx: 18, ry: 18 }, o)); } },
    circulo: { nome: 'Círculo', icone: '<circle cx="12" cy="12" r="9"/>', criar: function (o) { return new fabric.Circle(Object.assign({ radius: 50 }, o)); } },
    anel: { nome: 'Moldura redonda', contorno: true, icone: '<circle cx="12" cy="12" r="8" fill="none" stroke="currentColor" stroke-width="2.5"/>', criar: function (o) { return new fabric.Circle(Object.assign({ radius: 60, strokeWidth: 6 }, o)); } },
    moldura: { nome: 'Moldura', contorno: true, icone: '<rect x="4" y="5" width="16" height="14" fill="none" stroke="currentColor" stroke-width="2.5"/>', criar: function (o) { return new fabric.Rect(Object.assign({ width: 140, height: 110, strokeWidth: 6 }, o)); } },
    triangulo: { nome: 'Triângulo', icone: '<path d="M12 3l10 18H2z"/>', criar: function (o) { return new fabric.Triangle(Object.assign({ width: 110, height: 96 }, o)); } },
    estrela: { nome: 'Estrela', icone: '<path d="M12 2l3 7 7 .6-5.3 4.6 1.6 7.1L12 17.6 5.7 21.3l1.6-7.1L2 9.6 9 9z"/>', criar: function (o) { return new fabric.Polygon(estrela(5, 55, 24), Object.assign({}, o)); } },
    brilho: { nome: 'Brilho', icone: '<path d="M12 1q1.4 9.6 11 11-9.6 1.4-11 11-1.4-9.6-11-11 9.6-1.4 11-11z"/>', criar: function (o) { return new fabric.Path('M50 0 Q56 44 100 50 Q56 56 50 100 Q44 56 0 50 Q44 44 50 0Z', o); } },
    coracao: { nome: 'Coração', icone: '<path d="M12 21C6 16.5 2 13 2 8.5 2 5.4 4.4 3 7.4 3c1.9 0 3.6 1 4.6 2.6C13 4 14.7 3 16.6 3 19.6 3 22 5.4 22 8.5 22 13 18 16.5 12 21z"/>', criar: function (o) { return new fabric.Path('M50 88 C20 66 0 48 0 28 C0 12 12 0 27 0 C38 0 46 6 50 15 C54 6 62 0 73 0 C88 0 100 12 100 28 C100 48 80 66 50 88Z', o); } },
    lua: { nome: 'Lua crescente', icone: '<path d="M20 15A9 9 0 1 1 9 4a7 7 0 0 0 11 11z"/>', criar: function (o) { return new fabric.Path('M62 2 A50 50 0 1 0 100 72 A42 42 0 1 1 62 2Z', o); } },
    hexagono: { nome: 'Hexágono', icone: '<path d="M12 2l9 5v10l-9 5-9-5V7z"/>', criar: function (o) { return new fabric.Polygon(poligono(6, 55), o); } },
    losango: { nome: 'Losango', icone: '<path d="M12 2l9 10-9 10-9-10z"/>', criar: function (o) { return new fabric.Polygon([{ x: 50, y: 0 }, { x: 100, y: 65 }, { x: 50, y: 130 }, { x: 0, y: 65 }], o); } },
    linha: { nome: 'Linha', icone: '<rect x="2" y="11" width="20" height="2.5"/>', criar: function (o) { return new fabric.Rect(Object.assign({ width: 170, height: 5 }, o)); } }
  };
  function estrela(n, R, r) { var pts = []; for (var i = 0; i < n * 2; i++) { var a = Math.PI / n * i - Math.PI / 2, rr = i % 2 ? r : R; pts.push({ x: R + rr * Math.cos(a), y: R + rr * Math.sin(a) }); } return pts; }
  function poligono(n, R) { var pts = []; for (var i = 0; i < n; i++) { var a = 2 * Math.PI / n * i - Math.PI / 2; pts.push({ x: R + R * Math.cos(a), y: R + R * Math.sin(a) }); } return pts; }

  // ---------- estado ----------
  var produtos = [], tarifa = TARIFA_PADRAO, prod = null, cor = null, varSel = null, qtd = 1;
  var canvases = {}, ladoAtual = 'frente', historico = { frente: [], verso: [] }, refazer = { frente: [], verso: [] };
  var restaurando = false, uploads = [], salvo = true, enviando = false, enviado = false, exportando = false, previa = null, palco = null;
  var RASCUNHO = 'cosmoria_rascunho_personalizado';

  // ---------- carregar dados ----------
  var [rp, rpr, rmo] = await Promise.all([
    sb.from('produtos').select('id,slug,nome,descricao,preco_centavos,preco_promocional_centavos,icone,modelo_personalizado,variantes(id,nome,cor,cor_hex,tamanho,estoque,preco_centavos,ordem)').not('modelo_personalizado', 'is', null).order('preco_centavos'),
    sb.from('config_personalizacao').select('centavos_por_cm2,minimo_por_lado_centavos').limit(1),
    sb.from('moldes_personalizacao').select('*')
  ]);
  if (rp.error) { $('escolha').innerHTML = '<p class="aviso aviso-erro">' + esc(K.erroAmigavel(rp.error)) + '</p>'; return; }
  produtos = rp.data.filter(function (p) { return M[p.modelo_personalizado]; });
  produtos.forEach(function (p) { p.variantes.sort(function (a, b) { return a.ordem - b.ordem; }); });
  if (!rpr.error && rpr.data.length) tarifa = { centavos_por_cm2: +rpr.data[0].centavos_por_cm2, minimo_por_lado_centavos: +rpr.data[0].minimo_por_lado_centavos };
  if (!rmo.error) rmo.data.forEach(function (m) { if (M[m.modelo] && M[m.modelo].lados[m.lado]) { var L = M[m.modelo].lados[m.lado]; L.rotulo = m.rotulo; L.cm = [+m.largura_cm, +(m.largura_cm * L.area.h / L.area.w).toFixed(1)]; } });

  // ---------- passo 1: escolher produto ----------
  function renderEscolha() {
    if (!produtos.length) { $('escolha').innerHTML = '<div class="vazio"><span class="emoji">🎨</span><strong>Nenhum produto disponível para personalizar agora.</strong></div>'; return; }
    $('escolha').innerHTML = produtos.map(function (p) {
      var c = coresDe(p), est = p.variantes.reduce(function (s, v) { return s + v.estoque; }, 0);
      return '<button type="button" class="pers-prod" data-slug="' + esc(p.slug) + '"' + (prod && prod.id === p.id ? ' aria-pressed="true"' : '') + (est <= 0 ? ' disabled' : '') + '>' +
        '<span class="pers-prod-img" aria-hidden="true">' + miniMolde(p, c[0] && c[0].hex) + '</span>' +
        '<strong>' + esc(p.nome.replace(/ personalizad[ao]$/i, '')) + '</strong>' +
        '<span class="pers-prod-preco">a partir de ' + K.reais(K.precoFinal(p)) + '</span>' +
        '<span class="pers-cores">' + c.map(function (x) { return '<i style="background:' + x.hex + '"></i>'; }).join('') + '</span>' +
        (est <= 0 ? '<span class="pers-prod-preco">Esgotado</span>' : '') + '</button>';
    }).join('');
  }
  function miniMolde(p, hex) { var m = M[p.modelo_personalizado]; return (m.vitrine || m.desenho)(hex || '#F4F3EF', 'frente').replace('<svg ', '<svg preserveAspectRatio="xMidYMid meet" '); }
  function coresDe(p) {
    var vistas = {}, lista = [];
    p.variantes.forEach(function (v) {
      var k = v.cor || v.nome;
      if (!vistas[k]) { vistas[k] = { nome: k, hex: v.cor_hex || '#F4F3EF', estoque: 0 }; lista.push(vistas[k]); }
      vistas[k].estoque += v.estoque;
    });
    return lista;
  }
  $('escolha').addEventListener('click', function (e) {
    var b = e.target.closest('.pers-prod'); if (!b || b.disabled) return;
    selecionarProduto(produtos.find(function (p) { return p.slug === b.dataset.slug; }), true);
  });

  // ---------- canvas ----------
  fabric.Object.prototype.set({ transparentCorners: false, cornerColor: '#C9A45C', cornerStrokeColor: '#142219', borderColor: '#C9A45C', cornerStyle: 'circle', cornerSize: 14, touchCornerSize: 28, padding: 4, borderScaleFactor: 1.5 });
  // bolinhas na seleção: lixeira (apaga) e três pontinhos (abre "Editar")
  function bolha(desenho, fundo) {
    return function (ctx, left, top) {
      ctx.save(); ctx.translate(left, top);
      ctx.shadowColor = 'rgba(20,34,25,.3)'; ctx.shadowBlur = 6; ctx.beginPath(); ctx.arc(0, 0, 13, 0, 2 * Math.PI); ctx.fillStyle = fundo; ctx.fill();
      ctx.shadowBlur = 0; ctx.strokeStyle = ctx.fillStyle = '#F6F1E7'; ctx.lineWidth = 1.7; ctx.lineCap = ctx.lineJoin = 'round'; desenho(ctx); ctx.restore();
    };
  }
  fabric.Object.prototype.controls.lixo = new fabric.Control({
    x: 0.5, y: -0.5, offsetX: 20, offsetY: -20, sizeX: 28, sizeY: 28, touchSizeX: 40, touchSizeY: 40, cursorStyle: 'pointer',
    mouseUpHandler: function (e, t) { var o = t.target, c = o && o.canvas; if (c) { c.remove(o); c.discardActiveObject(); c.requestRenderAll(); } return true; },
    render: bolha(function (x) { x.beginPath(); x.moveTo(-5.5, -4); x.lineTo(5.5, -4); x.moveTo(-2, -4); x.lineTo(-2, -6); x.lineTo(2, -6); x.lineTo(2, -4); x.moveTo(-4, -4); x.lineTo(-3.2, 6); x.lineTo(3.2, 6); x.lineTo(4, -4); x.stroke(); }, '#B3412E')
  });
  fabric.Object.prototype.controls.opcoes = new fabric.Control({
    x: -0.5, y: -0.5, offsetX: -20, offsetY: -20, sizeX: 28, sizeY: 28, touchSizeX: 40, touchSizeY: 40, cursorStyle: 'pointer',
    mouseUpHandler: function () { abrirPainel('editar'); return true; },
    render: bolha(function (x) { [-4.5, 0, 4.5].forEach(function (y) { x.beginPath(); x.arc(0, y, 1.6, 0, 2 * Math.PI); x.fill(); }); }, '#142219')
  });
  var EXTRAS = ['tipo', 'nomeArquivo', 'imgId', 'forma', 'travado'];

  function criarCanvases() {
    LADOS.forEach(function (l) {
      var c = new fabric.Canvas('cv-' + l, { width: 520, height: 600, backgroundColor: '#EDEAE0', preserveObjectStacking: true, selection: false, enableRetinaScaling: true });
      c.lado = l; canvases[l] = c;
      c.on('object:added', function (e) { if (!e.target.guia) { recortar(e.target, l); aplicarTrava(e.target); if (!restaurando) mudou(l); } });
      c.on('after:render', function (e) { desenharOcupado(c, e.ctx); });
      c.on('object:removed', function () { if (!restaurando) mudou(l); });
      c.on('object:modified', function () { mudou(l); });
      c.on('object:moving', function () { checarArea(); atualizarPreco(); });
      c.on('object:scaling', function (e) { checarArea(); atualizarPreco(); var o = e.target; if (o && o.tipo === 'texto') $('p-tam-num').value = Math.round(o.fontSize * (o.scaleY || 1)); });
      c.on('text:changed', function (e) { if (e.target === ativo()) $('p-texto').value = e.target.text; mudou(l, true); });
      c.on('selection:created', mostrarProps); c.on('selection:updated', mostrarProps); c.on('selection:cleared', mostrarProps);
      c.on('selection:created', function (e) { if (e.e) abrirPainel('editar'); }); // tocar num item abre "Editar" embaixo do quadro
      c.on('selection:updated', function (e) { if (e.e && subAberto() !== 'editar') abrirPainel('editar'); });
      c.on('selection:cleared', function () { if (subAberto() === 'editar') trocarSub('ferr'); });
      ['selection:created', 'selection:updated', 'selection:cleared'].forEach(function (ev) { c.on(ev, renderCamadas); });
    });
    previa = window.Previa3D ? Previa3D($('cv-3d')) : null;
    palco = window.Palco3D ? Palco3D($('palco3d')) : null;
    if (!palco) $('app').classList.add('sem-webgl');
    else {
      palco.aoZoom(function (z) { $('zoom-3d').value = Math.round(z * 100); });
      $('palco3d').addEventListener('pointerdown', function () { $('est-dica').classList.add('some'); }, { once: true });
    }
    ajustarTamanho();
    trocarLado('frente');
  }
  function tela() { return (prod && M[prod.modelo_personalizado].tela) || { w: 520, h: 600 }; }
  function ladosAtivos() { return prod ? LADOS.filter(function (l) { return M[prod.modelo_personalizado].lados[l]; }) : ['frente']; }
  function ajustarTamanho() { // o quadro ocupa a largura toda, com zoom (sem perder nitidez)
    var t = tela(), q = $('quadro'), larg = (q.clientWidth || t.w) - 24, alt = (q.clientHeight || t.h) - 24;
    var k = Math.max(0.2, Math.min(larg / t.w, alt / t.h, 2.6));
    LADOS.forEach(function (l) {
      var c = canvases[l], w = Math.round(t.w * k), h = Math.round(t.h * k);
      if (c.width !== w || c.height !== h) c.setDimensions({ width: w, height: h });
      if (c.getZoom() !== k) c.setZoom(k);
      c.calcOffset();
    });
  }
  var tAjuste; function reajustar() { clearTimeout(tAjuste); tAjuste = setTimeout(function () { if (canvases.frente) ajustarTamanho(); }, 60); }
  window.addEventListener('resize', reajustar);
  if (window.ResizeObserver) new ResizeObserver(reajustar).observe($('quadro'));
  function cv() { return canvases[ladoAtual]; }
  function ativo() { return cv() && cv().getActiveObject(); }
  function lado(l) { return M[prod.modelo_personalizado].lados[l || ladoAtual]; }
  function temLado(l) { return !!(prod && M[prod.modelo_personalizado].lados[l]); }
  function areaDe(l) { return lado(l).area; }
  function pxPorCm(l) { var L = lado(l); return L.area.w / L.cm[0]; }

  function recortar(o, l) {
    if (!temLado(l)) return;
    var L = lado(l), a = L.area;
    o.clipPath = L.recorte ? new fabric.Path(L.recorte, { absolutePositioned: true }) : new fabric.Rect({ left: a.x, top: a.y, width: a.w, height: a.h, absolutePositioned: true });
  }

  function desenharMoldes() {
    var m = M[prod.modelo_personalizado], t = tela();
    LADOS.forEach(function (l) {
      var c = canvases[l];
      if (!m.lados[l]) { c.setBackgroundImage(null); c.overlayImage = null; c.requestRenderAll(); return; }
      var L = m.lados[l], a = L.area, claro = escuro(cor.hex), traco = claro ? 'rgba(255,255,255,.75)' : 'rgba(20,34,25,.55)', letra = claro ? 'rgba(255,255,255,.85)' : 'rgba(20,34,25,.7)';
      fabric.loadSVGFromString(m.desenho(cor.hex, l), function (objs, opts) {
        var g = fabric.util.groupSVGElements(objs, opts); g.set({ left: 0, top: 0, selectable: false, evented: false });
        c.setBackgroundImage(g, function () { c.renderAll(); agendarPrevia(); });
      });
      var borda = L.recorte ? new fabric.Path(L.recorte, { fill: 'transparent', stroke: traco, strokeWidth: 1.5, strokeDashArray: [6, 5] })
        : new fabric.Rect({ left: a.x, top: a.y, width: a.w, height: a.h, fill: 'transparent', stroke: traco, strokeWidth: 1.5, strokeDashArray: [6, 5] });
      var rotuloY = a.y + a.h + 20 < t.h ? a.y + a.h + 5 : a.y - 17;
      var partes = [borda, new fabric.Text('Área de impressão · ' + fmtCm(L.cm[0]) + ' × ' + fmtCm(L.cm[1]) + ' cm', { left: a.x + a.w / 2, originX: 'center', top: rotuloY, fontSize: 11, fontFamily: 'Manrope', fill: 'rgba(20,34,25,.7)' })];
      (L.marcas || []).forEach(function (mk) {
        partes.push(new fabric.Line([mk.x, a.y, mk.x, a.y + a.h], { stroke: traco, strokeWidth: 1, strokeDashArray: [3, 6] }));
        partes.push(new fabric.Text(mk.texto, { left: mk.x, top: a.y - 17, fontSize: 11, fontWeight: 'bold', fontFamily: 'Manrope', fill: 'rgba(20,34,25,.7)', originX: mk.alinhar === 'left' ? 'left' : mk.alinhar === 'right' ? 'right' : 'center' }));
      });
      var guia = new fabric.Group(partes, { selectable: false, evented: false });
      guia.guia = true; c.overlayImage = guia;
      c.getObjects().forEach(function (o) { recortar(o, l); });
      c.requestRenderAll();
    });
    var ativos = ladosAtivos();
    if (ativos.indexOf(ladoAtual) < 0 && canvases.frente) trocarLado('frente');
    $('lados').innerHTML = ativos.length > 1 ? ativos.map(function (l) { return '<button type="button" class="opcao" data-lado="' + l + '" aria-pressed="' + (l === ladoAtual) + '">' + esc(m.lados[l].rotulo) + '</button>'; }).join('')
      : '<span class="ed-rotulo" style="margin:0"' + (m.envolve ? ' title="A arte dá a volta na caneca"' : '') + '>' + esc(m.lados[ativos[0]].rotulo) + '</span>';
    ajustarTamanho(); agendarPrevia();
  }
  function fmtCm(n) { return String(+(+n).toFixed(1)).replace('.', ','); }

  function trocarLado(l) {
    if (canvases[ladoAtual]) canvases[ladoAtual].discardActiveObject().requestRenderAll();
    ladoAtual = l;
    LADOS.forEach(function (x) { canvases[x].wrapperEl.style.display = x === l ? '' : 'none'; });
    cv().calcOffset();
    document.querySelectorAll('#lados [data-lado]').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.lado === l); });
    if (palco) palco.lado(l);
    if (prod) $('arte-medida').textContent = fmtCm(lado(l).cm[0]) + ' × ' + fmtCm(lado(l).cm[1]) + ' cm';
    mostrarProps(); checarArea(); botoesHistorico(); renderCamadas(); atualizarPreco();
  }
  $('lados').addEventListener('click', function (e) { var b = e.target.closest('[data-lado]'); if (b) trocarLado(b.dataset.lado); });

  // ---------- produto, cor e tamanho ----------
  // Cada produto guarda a sua própria arte: trocar de produto não leva nem encolhe o desenho.
  var artes = {}; // slug -> { cor, variante, lados: { frente: json, verso: json }, historico, refazer }
  var carregandoArte = false;
  function guardarAtual() {
    if (!prod || !canvases.frente || carregandoArte) return;
    var g = { cor: cor && cor.nome, variante: varSel && varSel.id, lados: {}, historico: {}, refazer: {} };
    LADOS.forEach(function (l) { g.lados[l] = JSON.stringify(snapshot(l)); g.historico[l] = historico[l].slice(); g.refazer[l] = refazer[l].slice(); });
    artes[prod.slug] = g;
  }
  function carregarArte(g) {
    var fontes = {};
    LADOS.forEach(function (l) { JSON.parse((g && g.lados[l]) || '[]').forEach(function (o) { if (o.tipo === 'texto') fontes[o.fontFamily] = 1; }); });
    return Promise.all(Object.keys(fontes).map(carregarFonte)).then(function () {
      return Promise.all(LADOS.map(function (l) {
        var json = (g && g.lados[l]) || '[]';
        historico[l] = g && g.historico ? g.historico[l].slice() : (json === '[]' ? [] : [json]);
        refazer[l] = g && g.refazer ? g.refazer[l].slice() : [];
        return new Promise(function (ok) { restaurar(l, json, ok); });
      }));
    });
  }
  var trocando = Promise.resolve();
  function selecionarProduto(p, rolar) {
    if (!p) return trocando;
    if (prod && prod.id === p.id) return trocando;
    guardarAtual();
    prod = p;
    if (!canvases.frente) criarCanvases();
    var g = artes[p.slug], cs = coresDe(p);
    cor = (g && cs.find(function (c) { return c.nome === g.cor && c.estoque > 0; })) || cs.find(function (c) { return c.estoque > 0; }) || cs[0];
    varSel = (g && p.variantes.find(function (v) { return v.id === g.variante && v.estoque > 0; })) || null;
    escolherVariante(varSel && varSel.tamanho);
    $('prod-nome').textContent = p.nome; $('opcoes-prod').hidden = false; $('cores-vazio').hidden = true;
    renderEscolha(); desenharMoldes(); renderCores();
    LADOS.forEach(function (l) { canvases[l].discardActiveObject(); });
    carregandoArte = true;
    trocando = carregarArte(g).then(function () { carregandoArte = false; trocarLado(ladosAtivos()[0]); atualizarPreco(); agendarPrevia(); salvarRascunho(); });
    history.replaceState(null, '', 'personalizar.html?p=' + encodeURIComponent(p.slug));
    return trocando;
  }
  function variantesDaCor() { return prod.variantes.filter(function (v) { return (v.cor || v.nome) === cor.nome; }); }
  function escolherVariante(tam) {
    var vs = variantesDaCor();
    varSel = vs.find(function (v) { return v.tamanho === tam && v.estoque > 0; }) || vs.find(function (v) { return varSel && v.tamanho === varSel.tamanho && v.estoque > 0; }) || vs.find(function (v) { return v.estoque > 0; }) || vs[0];
    if (varSel && qtd > varSel.estoque) qtd = Math.max(1, varSel.estoque);
  }
  function renderCores() {
    var cs = coresDe(prod);
    $('cores').innerHTML = cs.map(function (c) {
      return '<button type="button" class="cor-btn" data-cor="' + esc(c.nome) + '" aria-pressed="' + (c.nome === cor.nome) + '" title="' + esc(c.nome) + (c.estoque <= 0 ? ' (esgotada)' : '') + '"' + (c.estoque <= 0 ? ' disabled' : '') + ' style="--c:' + c.hex + '"><span class="sr">' + esc(c.nome) + '</span></button>';
    }).join('');
    $('cor-nome').textContent = cor.nome;
    $('prod-nome').textContent = prod.nome.replace(/ personalizad[ao]$/i, '') + ' · ' + (varSel ? varSel.nome : cor.nome);
    var vs = variantesDaCor(), temTam = vs.some(function (v) { return v.tamanho; });
    $('bloco-tam').hidden = !temTam;
    if (temTam) $('tamanhos').innerHTML = vs.map(function (v) {
      return '<button type="button" class="opcao" data-id="' + v.id + '" aria-pressed="' + (varSel && v.id === varSel.id) + '"' + (v.estoque <= 0 ? ' disabled' : '') + '>' + esc(v.tamanho) + '</button>';
    }).join('');
    var e = varSel ? varSel.estoque : 0;
    $('estoque').textContent = e <= 0 ? 'Esgotado nesta cor' : (e <= 5 ? 'Últimas ' + e + ' unidades em estoque' : 'Em estoque');
  }
  $('cores').addEventListener('click', function (e) {
    var b = e.target.closest('.cor-btn'); if (!b || b.disabled) return;
    var antes = corPadrao();
    cor = coresDe(prod).find(function (c) { return c.nome === b.dataset.cor; });
    var depois = corPadrao();
    if (antes !== depois) LADOS.forEach(function (l) { canvases[l].getObjects().forEach(function (o) { if (o.tipo === 'texto' && String(o.fill).toUpperCase() === antes.toUpperCase()) o.set('fill', depois); }); canvases[l].requestRenderAll(); });
    escolherVariante(varSel && varSel.tamanho); desenharMoldes(); renderCores(); atualizarPreco(); salvarRascunho();
  });
  $('tamanhos').addEventListener('click', function (e) {
    var b = e.target.closest('.opcao'); if (!b || b.disabled) return;
    varSel = prod.variantes.find(function (v) { return String(v.id) === b.dataset.id; }); renderCores(); atualizarPreco(); salvarRascunho();
  });

  // ---------- gaveta (menu de baixo) e painéis da arte ----------
  var celular = window.matchMedia ? matchMedia('(max-width:900px)') : { matches: false };
  var SUB = { ferr: 1, img: 1, txt: 1, emo: 1, for: 1, cam: 1, editar: 1 };
  function marcarTrilho(k) { document.querySelectorAll('.nav-btn').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.abre === k); }); }
  function gavetaAberta() { var a = $('app').classList.contains('com-gaveta') && document.querySelector('.gaveta>.pn.ativo'); return a ? a.dataset.painel : null; }
  function subAberto() { var a = document.querySelector('.arte-sub>.pn.ativo'); return a ? a.dataset.painel : null; }
  function trocarSub(k) { document.querySelectorAll('.arte-sub>.pn').forEach(function (p) { p.classList.toggle('ativo', p.dataset.painel === k); }); }
  function painelAberto() { var g = gavetaAberta(); return g === 'arte' && subAberto() !== 'ferr' ? subAberto() : g; }
  function abrirPainel(k, alternar) {
    if (SUB[k]) {
      if (gavetaAberta() !== 'arte') abrirPainel('arte');
      trocarSub(k); return;
    }
    if (alternar && gavetaAberta() === k) return fecharPainel();
    document.querySelectorAll('.gaveta>.pn').forEach(function (p) { p.classList.toggle('ativo', p.dataset.painel === k); });
    $('gaveta').dataset.k = k;
    $('app').classList.add('com-gaveta');
    if (k === 'arte' && !subAberto()) trocarSub('ferr');
    marcarTrilho(k); reajustar();
  }
  function fecharPainel() {
    $('app').classList.remove('com-gaveta'); fecharMais();
    marcarTrilho(null);
  }
  document.addEventListener('click', function (e) {
    var a = e.target.closest('[data-abre]'); if (a) { abrirPainel(a.dataset.abre, a.classList.contains('nav-btn')); return; }
    var f = e.target.closest('[data-fecha]'); if (!f) return;
    if (f.closest('.arte-sub')) { if (f.closest('[data-painel="editar"]') && cv()) cv().discardActiveObject().requestRenderAll(); abrirPainel('ferr'); }
    else fecharPainel();
  });
  // alça da gaveta (celular): arraste para aumentar, diminuir ou fechar
  (function () {
    var alca = $('gaveta-alca'), gav = $('gaveta'), ini = null;
    alca.addEventListener('pointerdown', function (e) { ini = { y: e.clientY, h: gav.getBoundingClientRect().height }; alca.setPointerCapture(e.pointerId); });
    alca.addEventListener('pointermove', function (e) {
      if (!ini) return; var h = Math.max(120, ini.h - (e.clientY - ini.y));
      gav.style.setProperty('--gh', h + 'px'); if (gav.dataset.k !== 'arte') gav.style.maxHeight = h + 'px';
    });
    function soltar(e) {
      if (!ini) return; var h = gav.getBoundingClientRect().height, vh = window.innerHeight; ini = null;
      if (h < vh * 0.24) { fecharPainel(); gav.style.removeProperty('--gh'); gav.style.maxHeight = ''; }
      reajustar();
    }
    alca.addEventListener('pointerup', soltar); alca.addEventListener('pointercancel', soltar);
  })();
  // botão "+" (celular): abre as bolinhas de adicionar
  function fecharMais() { $('mais-add').setAttribute('aria-expanded', 'false'); $('mais-menu').hidden = true; }
  $('mais-add').onclick = function () { var abrir = this.getAttribute('aria-expanded') !== 'true'; this.setAttribute('aria-expanded', abrir); $('mais-menu').hidden = !abrir; };
  $('mais-menu').addEventListener('click', function (e) {
    var b = e.target.closest('[data-mais]'); if (!b) return; fecharMais();
    var k = b.dataset.mais;
    if (k === 'texto') document.querySelector('[data-add-texto="titulo"]').click();
    else if (k === 'imagem') $('arquivo').click();
    else abrirPainel(k);
  });
  // zoom e fundo do palco 3D
  function zoom3d(z) { if (palco) palco.zoom(z); }
  $('zoom-3d').addEventListener('input', function () { zoom3d(this.value / 100); });
  $('zoom-mais').onclick = function () { if (palco) zoom3d(palco.zoom() * 1.15); };
  $('zoom-menos').onclick = function () { if (palco) zoom3d(palco.zoom() / 1.15); };
  function aplicarFundo(f) {
    if (!document.querySelector('.fundo-btn[data-fundo="' + f + '"]')) f = 'estudio';
    $('app').dataset.fundo = f;
    document.querySelectorAll('.fundo-btn').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.fundo === f); });
    try { localStorage.setItem('cosmoria_fundo', f); } catch (e) {}
  }
  $('fundos').addEventListener('click', function (e) { var b = e.target.closest('[data-fundo]'); if (b) aplicarFundo(b.dataset.fundo); });
  try { aplicarFundo(localStorage.getItem('cosmoria_fundo') || 'estudio'); } catch (e) { aplicarFundo('estudio'); }


  function centroArea() { var a = areaDe(); return { x: a.x + a.w / 2, y: a.y + a.h / 2 }; }
  function corPadrao() { return escuro(cor.hex) ? '#F6F1E7' : '#142219'; }
  function adicionar(o, tipo) {
    var c = centroArea(), a = areaDe(), n = cv().getObjects().length % 6, desl = (n - 2.5) * 14; o.tipo = tipo;
    if (tipo === 'texto' && o.width > a.w * 0.6) o.set('fontSize', Math.max(10, Math.floor(o.fontSize * a.w * 0.6 / o.width)));
    o.setPositionByOrigin(new fabric.Point(c.x + (n ? desl : 0), c.y + (n ? desl : 0)), 'center', 'center');
    cv().add(o); cv().setActiveObject(o); o.setCoords(); cv().requestRenderAll();
    fecharMais(); abrirPainel('editar');
  }

  // imagem
  $('enviar-img').onclick = function () { $('arquivo').click(); };
  $('arte-vazia').onclick = function () { $('arquivo').click(); };
  $('arquivo').addEventListener('change', function () { var f = this.files[0]; this.value = ''; if (f) enviarArquivo(f); });
  var palcoArte = document.querySelector('.arte-palco');
  ['dragenter', 'dragover'].forEach(function (ev) { palcoArte.addEventListener(ev, function (e) { if (e.dataTransfer && [].indexOf.call(e.dataTransfer.types || [], 'Files') >= 0) { e.preventDefault(); palcoArte.classList.add('solta'); } }); });
  ['dragleave', 'drop'].forEach(function (ev) { palcoArte.addEventListener(ev, function () { palcoArte.classList.remove('solta'); }); });
  palcoArte.addEventListener('drop', function (e) { var f = e.dataTransfer && e.dataTransfer.files[0]; if (f) { e.preventDefault(); enviarArquivo(f); } });
  async function enviarArquivo(f) {
    if (!prod) return;
    var msg = $('msg-img'); msg.hidden = false; msg.className = 'aviso aviso-info';
    if (!/^image\//.test(f.type)) { msg.className = 'aviso aviso-erro'; msg.textContent = 'Esse arquivo não é uma imagem. Use JPG ou PNG.'; return; }
    if (f.size > 20 * 1024 * 1024) { msg.className = 'aviso aviso-erro'; msg.textContent = 'A imagem é muito grande (máximo 20 MB).'; return; }
    msg.textContent = 'Carregando imagem...';
    try {
      var url = await prepararImagem(f), id = 'img' + Date.now();
      uploads.push({ id: id, nome: f.name, dataUrl: url });
      fabric.Image.fromURL(url, function (img) {
        var a = areaDe(), cobre = M[prod.modelo_personalizado].envolve && Math.abs(img.width / img.height - a.w / a.h) < 0.6, s = cobre ? Math.max(a.w / img.width, a.h / img.height) : Math.min(a.w * 0.8 / img.width, a.h * 0.8 / img.height);
        img.set({ scaleX: s, scaleY: s }); img.imgId = id; img.nomeArquivo = f.name;
        adicionar(img, 'imagem'); msg.hidden = true;
      });
    } catch (err) { msg.className = 'aviso aviso-erro'; msg.textContent = 'Não consegui abrir essa imagem. Tente outra (JPG ou PNG).'; }
    if (!msg.hidden && msg.classList.contains('aviso-erro')) abrirPainel('img');
  }
  function prepararImagem(f) { // reduz para no máximo 2400 px, mantendo transparência dos PNG
    return new Promise(function (ok, erro) {
      var r = new FileReader();
      r.onerror = erro;
      r.onload = function () {
        var im = new Image();
        im.onerror = erro;
        im.onload = function () {
          var max = 2400, s = Math.min(1, max / Math.max(im.width, im.height));
          if (s === 1 && f.size < 3 * 1024 * 1024 && /png|jpe?g/.test(f.type)) return ok(r.result);
          var c = document.createElement('canvas'); c.width = Math.round(im.width * s); c.height = Math.round(im.height * s);
          c.getContext('2d').drawImage(im, 0, 0, c.width, c.height);
          ok(/png|webp|gif/.test(f.type) ? c.toDataURL('image/png') : c.toDataURL('image/jpeg', 0.9));
        };
        im.src = r.result;
      };
      r.readAsDataURL(f);
    });
  }

  // texto
  document.querySelectorAll('[data-add-texto]').forEach(function (b) {
    b.onclick = async function () {
      var t = b.dataset.addTexto === 'titulo' ? { text: 'Seu texto aqui', fontSize: 40, fontFamily: 'Cinzel', fontWeight: 'bold' } : { text: 'Escreva uma frase', fontSize: 24, fontFamily: 'Manrope' };
      await carregarFonte(t.fontFamily);
      adicionar(new fabric.IText(t.text, Object.assign({ fill: corPadrao(), textAlign: 'center', paintFirst: 'stroke', strokeUniform: true }, t)), 'texto');
      $('p-texto').focus(); $('p-texto').select();
    };
  });
  function carregarFonte(f) {
    if (!document.fonts || !document.fonts.load) return Promise.resolve();
    return Promise.all([document.fonts.load('400 40px "' + f + '"'), document.fonts.load('700 40px "' + f + '"')]).catch(function () {});
  }

  // emojis
  $('emojis').innerHTML = EMOJIS.map(function (e) { return '<button type="button" class="emoji-btn" data-emoji="' + e + '" aria-label="Adicionar ' + e + '">' + e + '</button>'; }).join('');
  $('emojis').addEventListener('click', function (e) {
    var b = e.target.closest('[data-emoji]'); if (!b) return;
    adicionar(new fabric.Text(b.dataset.emoji, { fontSize: 64, fontFamily: FONTE_EMOJI }), 'emoji');
  });

  // formas
  $('formas').innerHTML = Object.keys(FORMAS).map(function (k) {
    return '<button type="button" class="forma-btn" data-forma="' + k + '" title="' + FORMAS[k].nome + '"><svg viewBox="0 0 24 24" width="30" height="30" fill="currentColor" aria-hidden="true">' + FORMAS[k].icone + '</svg><span>' + FORMAS[k].nome + '</span></button>';
  }).join('');
  $('formas').addEventListener('click', function (e) {
    var b = e.target.closest('[data-forma]'); if (!b) return;
    var F = FORMAS[b.dataset.forma], c = escuro(cor.hex) ? '#C9A45C' : '#3F6B4A';
    var o = F.criar(F.contorno ? { fill: 'transparent', stroke: c, strokeUniform: true } : { fill: c, strokeUniform: true });
    o.forma = b.dataset.forma; adicionar(o, 'forma');
  });

  // ---------- painel de propriedades ----------
  $('p-fonte').innerHTML = FONTES.map(function (f) { return '<option value="' + f + '" style="font-family:\'' + f + '\'">' + f + '</option>'; }).join('');
  $('p-cores').innerHTML = CORES.map(function (c) { return '<button type="button" class="cor-mini" data-c="' + c + '" style="--c:' + c + '" aria-label="Cor ' + c + '"></button>'; }).join('');
  function eContorno(o) { return o.tipo === 'forma' && FORMAS[o.forma] && FORMAS[o.forma].contorno; }
  function mostrarProps() {
    var o = ativo(), p = $('props');
    p.hidden = !o; $('sem-selecao').hidden = !!o;
    if (o) {
      var texto = o.tipo === 'texto';
      $('p-titulo').textContent = NOME_TIPO[o.tipo] || 'Elemento';
      $('g-texto').hidden = !texto;
      $('g-cor').hidden = o.tipo === 'imagem' || o.tipo === 'emoji';
      $('g-contorno').hidden = !(texto || (o.tipo === 'forma' && !eContorno(o)));
      if (texto) {
        $('p-texto').value = o.text; $('p-fonte').value = o.fontFamily; $('p-tam').value = Math.round(o.fontSize); $('p-tam-num').value = Math.round(o.fontSize * (o.scaleY || 1));
        $('b-negrito').setAttribute('aria-pressed', o.fontWeight === 'bold'); $('b-italico').setAttribute('aria-pressed', o.fontStyle === 'italic');
        document.querySelectorAll('[data-alinhar]').forEach(function (b) { b.setAttribute('aria-pressed', b.dataset.alinhar === o.textAlign); });
      }
      var c = eContorno(o) ? o.stroke : o.fill;
      if (typeof c === 'string' && /^#/.test(c)) $('p-cor').value = c.length === 4 ? '#' + c[1] + c[1] + c[2] + c[2] + c[3] + c[3] : c;
      $('p-contorno').value = Math.round(o.strokeWidth && o.stroke && !eContorno(o) ? o.strokeWidth : 0);
      if (o.stroke && !eContorno(o) && /^#/.test(o.stroke)) $('p-contorno-cor').value = o.stroke;
      $('p-opac').value = Math.round((o.opacity == null ? 1 : o.opacity) * 100);
    }
    checarArea();
  }
  function mudarProp(fn) { var o = ativo(); if (!o) return; fn(o); o.setCoords(); cv().requestRenderAll(); mudou(ladoAtual, true); }
  $('p-texto').addEventListener('input', function () { var v = this.value; mudarProp(function (o) { var c0 = o.getCenterPoint(); o.set('text', v || ' '); o.initDimensions && o.initDimensions(); o.setPositionByOrigin(c0, 'center', 'center'); }); });
  $('p-fonte').addEventListener('change', async function () { var f = this.value; await carregarFonte(f); fabric.util.clearFabricFontCache(f); mudarProp(function (o) { o.set('fontFamily', f); o.initDimensions && o.initDimensions(); }); });
  $('p-tam').addEventListener('input', function () { var v = +this.value; $('p-tam-num').value = v; mudarProp(function (o) { var c0 = o.getCenterPoint(); o.set({ fontSize: v, scaleX: 1, scaleY: 1 }); o.initDimensions && o.initDimensions(); o.setPositionByOrigin(c0, 'center', 'center'); }); });
  $('p-tam-num').addEventListener('input', function () {
    var v = Math.round(+this.value); if (!v || v < 4 || v > 400) return;
    $('p-tam').value = Math.min(160, v); mudarProp(function (o) { var c0 = o.getCenterPoint(); o.set({ fontSize: v, scaleX: 1, scaleY: 1 }); o.initDimensions && o.initDimensions(); o.setPositionByOrigin(c0, 'center', 'center'); });
  });
  function aplicarCor(c) { mudarProp(function (o) { if (eContorno(o)) o.set('stroke', c); else o.set('fill', c); }); $('p-cor').value = c; }
  $('p-cor').addEventListener('input', function () { aplicarCor(this.value); });
  $('p-cores').addEventListener('click', function (e) { var b = e.target.closest('[data-c]'); if (b) aplicarCor(b.dataset.c); });
  $('b-negrito').onclick = function () { mudarProp(function (o) { o.set('fontWeight', o.fontWeight === 'bold' ? 'normal' : 'bold'); }); mostrarProps(); };
  $('b-italico').onclick = function () { mudarProp(function (o) { o.set('fontStyle', o.fontStyle === 'italic' ? 'normal' : 'italic'); }); mostrarProps(); };
  document.querySelectorAll('[data-alinhar]').forEach(function (b) { b.onclick = function () { mudarProp(function (o) { o.set('textAlign', b.dataset.alinhar); }); mostrarProps(); }; });
  function aplicarContorno() { var w = +$('p-contorno').value, c = $('p-contorno-cor').value; mudarProp(function (o) { o.set({ stroke: w ? c : null, strokeWidth: w, paintFirst: 'stroke', strokeUniform: true }); }); }
  $('p-contorno').addEventListener('input', aplicarContorno); $('p-contorno-cor').addEventListener('input', aplicarContorno);
  $('p-opac').addEventListener('input', function () { var v = +this.value / 100; mudarProp(function (o) { o.set('opacity', v); }); });

  $('a-apagar').onclick = apagar;
  $('a-duplicar').onclick = function () {
    var o = ativo(); if (!o) return;
    o.clone(function (c) { c.set({ left: o.left + 18, top: o.top + 18 }); EXTRAS.forEach(function (k) { c[k] = o[k]; }); cv().add(c); cv().setActiveObject(c); cv().requestRenderAll(); }, EXTRAS);
  };
  $('a-frente').onclick = function () { mudarProp(function (o) { cv().bringForward(o); }); };
  $('a-tras').onclick = function () { mudarProp(function (o) { cv().sendBackwards(o); }); };
  $('a-centro').onclick = function () { var c = centroArea(); mudarProp(function (o) { o.setPositionByOrigin(new fabric.Point(c.x, c.y), 'center', 'center'); }); };
  $('a-espelhar').onclick = function () { mudarProp(function (o) { o.set('flipX', !o.flipX); }); };
  function apagar() { var o = ativo(); if (!o || o.isEditing) return; cv().remove(o); cv().discardActiveObject(); cv().requestRenderAll(); }
  document.addEventListener('keydown', function (e) {
    if (!cv() || /INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) return;
    if ((e.key === 'Delete' || e.key === 'Backspace') && ativo() && !ativo().isEditing) { e.preventDefault(); apagar(); }
    if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z') { e.preventDefault(); e.shiftKey ? refazerAcao() : desfazer(); }
  });

  // ---------- camadas (como no Photoshop: a de cima fica na frente) ----------
  function aplicarTrava(o) { var t = !!o.travado; o.set({ selectable: !t, evented: !t }); }
  var ICONE = {
    lixo: '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/></svg>',
    olho: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>',
    olhoOff: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M3 3l18 18M10.6 5.1A10 10 0 0 1 12 5c6.5 0 10 7 10 7a17 17 0 0 1-3.1 4M6.6 6.6C3.9 8.3 2 12 2 12s3.5 7 10 7c1.8 0 3.4-.5 4.7-1.3"/></svg>',
    cadeado: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/></svg>',
    aberto: '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="5" y="11" width="14" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 7.5-2"/></svg>',
    sobe: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 15l6-6 6 6"/></svg>',
    desce: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"><path d="M6 9l6 6 6-6"/></svg>'
  };
  function miniCamada(o) {
    if (o.tipo === 'imagem' && o.getSrc) return '<img src="' + esc(o.getSrc()) + '" alt="">';
    if (o.tipo === 'texto') return '<span style="font-family:\'' + esc(o.fontFamily) + '\';color:' + esc(hexDe(o.fill) || '#142219') + '">Aa</span>';
    if (o.tipo === 'emoji') return '<span>' + esc(o.text) + '</span>';
    var F = FORMAS[o.forma], c = hexDe(eContorno(o) ? o.stroke : o.fill) || '#3F6B4A';
    return F ? '<svg viewBox="0 0 24 24" width="22" height="22" fill="' + esc(c) + '" style="color:' + esc(c) + '">' + F.icone + '</svg>' : '<span>◆</span>';
  }
  function renderCamadas() {
    var ul = $('camadas'); if (!ul || !cv()) return;
    $('arte-vazia').hidden = !prod || cv().getObjects().length > 0;
    $('cam-lado').textContent = '· ' + lado().rotulo;
    var obs = cv().getObjects(), at = ativo();
    if (!obs.length) { ul.innerHTML = '<li class="cam-vazia">Nenhuma camada ainda. Tudo o que você adicionar aparece aqui.</li>'; return; }
    ul.innerHTML = obs.map(function (o, i) { return { o: o, i: i }; }).reverse().map(function (x) {
      var o = x.o, i = x.i, oculto = o.visible === false;
      return '<li class="camada' + (o === at ? ' ativa' : '') + (oculto ? ' oculta' : '') + (o.travado ? ' travada' : '') + '" draggable="true" data-i="' + i + '">' +
        '<span class="cam-arrasta" aria-hidden="true">⋮⋮</span><span class="cam-mini" style="background:' + esc(cor.hex) + '">' + miniCamada(o) + '</span>' +
        '<button type="button" class="cam-nome" data-acao="sel" title="Selecionar">' + esc(descreve(o)) + '<small>' + esc(NOME_TIPO[o.tipo] || 'Forma') + '</small></button>' +
        '<button type="button" class="cam-btn" data-acao="ver" aria-label="' + (oculto ? 'Mostrar' : 'Esconder') + ' camada" title="' + (oculto ? 'Mostrar' : 'Esconder') + '">' + (oculto ? ICONE.olhoOff : ICONE.olho) + '</button>' +
        '<button type="button" class="cam-btn" data-acao="trava" aria-label="' + (o.travado ? 'Destravar' : 'Travar') + ' camada" title="' + (o.travado ? 'Destravar' : 'Travar') + '">' + (o.travado ? ICONE.cadeado : ICONE.aberto) + '</button>' +
        '<span class="cam-ordem"><button type="button" class="cam-btn" data-acao="sobe" aria-label="Subir camada"' + (i === obs.length - 1 ? ' disabled' : '') + '>' + ICONE.sobe + '</button>' +
        '<button type="button" class="cam-btn" data-acao="desce" aria-label="Descer camada"' + (i === 0 ? ' disabled' : '') + '>' + ICONE.desce + '</button></span>' +
        '<button type="button" class="cam-btn cam-apagar" data-acao="apagar" aria-label="Excluir camada" title="Excluir camada">' + ICONE.lixo + '</button></li>';
    }).join('');
  }
  $('camadas').addEventListener('click', function (e) {
    var b = e.target.closest('button'), li = e.target.closest('.camada'); if (!li) return;
    var c = cv(), o = c.getObjects()[+li.dataset.i]; if (!o) return;
    var acao = b ? b.dataset.acao : 'sel';
    if (acao === 'sel') { if (o.travado || o.visible === false) return; c.setActiveObject(o); c.requestRenderAll(); return; }
    if (acao === 'ver') { o.visible = o.visible === false; if (!o.visible && ativo() === o) c.discardActiveObject(); }
    if (acao === 'trava') { o.travado = !o.travado; aplicarTrava(o); if (o.travado && ativo() === o) c.discardActiveObject(); }
    if (acao === 'apagar') { if (ativo() === o) c.discardActiveObject(); c.remove(o); c.requestRenderAll(); mostrarProps(); return; }
    if (acao === 'sobe') c.bringForward(o);
    if (acao === 'desce') c.sendBackwards(o);
    c.requestRenderAll(); mudou(ladoAtual); mostrarProps();
  });
  var arrastando = null;
  $('camadas').addEventListener('dragstart', function (e) { var li = e.target.closest('.camada'); if (!li) return; arrastando = +li.dataset.i; li.classList.add('arrastando'); e.dataTransfer.effectAllowed = 'move'; try { e.dataTransfer.setData('text/plain', li.dataset.i); } catch (x) {} });
  $('camadas').addEventListener('dragover', function (e) { if (arrastando == null) return; e.preventDefault(); var li = e.target.closest('.camada'); document.querySelectorAll('.camada.alvo').forEach(function (x) { x.classList.remove('alvo'); }); if (li) li.classList.add('alvo'); });
  $('camadas').addEventListener('dragend', function () { arrastando = null; document.querySelectorAll('.camada.alvo,.camada.arrastando').forEach(function (x) { x.classList.remove('alvo', 'arrastando'); }); });
  $('camadas').addEventListener('drop', function (e) {
    e.preventDefault(); var li = e.target.closest('.camada'); if (arrastando == null || !li) return;
    var c = cv(), o = c.getObjects()[arrastando], alvo = +li.dataset.i; arrastando = null;
    if (o && alvo !== c.getObjects().indexOf(o)) { c.moveTo(o, alvo); c.requestRenderAll(); mudou(ladoAtual); }
    else renderCamadas();
  });

  // ---------- desfazer / refazer ----------
  function snapshot(l) { return canvases[l].getObjects().map(function (o) { var j = o.toObject(EXTRAS); delete j.clipPath; return j; }); }
  var tAgenda = {};
  function mudou(l, agrupar) {
    salvo = false;
    clearTimeout(tAgenda[l]);
    tAgenda[l] = setTimeout(function () {
      var s = JSON.stringify(snapshot(l)), h = historico[l];
      if (h[h.length - 1] !== s) { h.push(s); if (h.length > 40) h.shift(); refazer[l] = []; }
      botoesHistorico(); salvarRascunho();
    }, agrupar ? 400 : 0);
    atualizarPreco(); checarArea(); renderCamadas();
  }
  function restaurar(l, json, cb) {
    var c = canvases[l]; restaurando = true;
    fabric.util.enlivenObjects(JSON.parse(json), function (objs) {
      c.discardActiveObject(); c.getObjects().slice().forEach(function (o) { c.remove(o); });
      objs.forEach(function (o, i) { var src = JSON.parse(json)[i]; EXTRAS.forEach(function (k) { if (src[k] != null) o[k] = src[k]; }); c.add(o); });
      restaurando = false; c.requestRenderAll(); atualizarPreco(); checarArea(); botoesHistorico(); renderCamadas(); salvarRascunho(); if (cb) cb();
    });
  }
  function desfazer() { var h = historico[ladoAtual]; if (h.length < 2) { if (h.length === 1) { refazer[ladoAtual].push(h.pop()); restaurar(ladoAtual, '[]'); } return; } refazer[ladoAtual].push(h.pop()); restaurar(ladoAtual, h[h.length - 1]); }
  function refazerAcao() { var r = refazer[ladoAtual]; if (!r.length) return; var s = r.pop(); historico[ladoAtual].push(s); restaurar(ladoAtual, s); }
  function botoesHistorico() { $('b-desfazer').disabled = !historico[ladoAtual].length; $('b-refazer').disabled = !refazer[ladoAtual].length; }
  $('b-desfazer').onclick = desfazer; $('b-refazer').onclick = refazerAcao;
  $('b-limpar').onclick = function () {
    if (!cv().getObjects().length || !confirm('Apagar tudo deste lado (' + lado().rotulo + ')?')) return;
    cv().getObjects().slice().forEach(function (o) { cv().remove(o); }); cv().discardActiveObject(); cv().requestRenderAll();
  };

  // ---------- área de impressão ----------
  function checarArea() {
    if (!prod) return;
    var a = areaDe(), fora = visiveis(ladoAtual).some(function (o) {
      var b = o.getBoundingRect(true, true);
      return b.left < a.x - 2 || b.top < a.y - 2 || b.left + b.width > a.x + a.w + 2 || b.top + b.height > a.y + a.h + 2;
    });
    $('aviso-area').hidden = !fora;
  }

  // ---------- pré-valor: espaço ocupado ----------
  function visiveis(l) { return canvases[l].getObjects().filter(function (o) { return o.visible !== false; }); }
  function medir(o, l) { // tamanho real do elemento em cm (sem a rotação)
    var p = pxPorCm(l); return { w: o.getScaledWidth() / p, h: o.getScaledHeight() / p };
  }
  function caixaOcupada(l) { // retângulo que envolve toda a arte visível do lado, dentro da área de impressão
    var obs = visiveis(l); if (!obs.length) return null;
    var a = areaDe(l), x1 = Infinity, y1 = Infinity, x2 = -Infinity, y2 = -Infinity;
    obs.forEach(function (o) { var b = o.getBoundingRect(true, true); x1 = Math.min(x1, b.left); y1 = Math.min(y1, b.top); x2 = Math.max(x2, b.left + b.width); y2 = Math.max(y2, b.top + b.height); });
    x1 = Math.max(x1, a.x); y1 = Math.max(y1, a.y); x2 = Math.min(x2, a.x + a.w); y2 = Math.min(y2, a.y + a.h);
    return x2 > x1 && y2 > y1 ? { x: x1, y: y1, w: x2 - x1, h: y2 - y1, n: obs.length } : null;
  }
  // Roupas e ecobag: cada elemento tem o seu retângulo; os que se sobrepõem contam uma vez só (área útil).
  // Caneca: continua cobrando o retângulo que envolve toda a arte.
  function porItem() { return !(prod && M[prod.modelo_personalizado].envolve); }
  function retangulos(l) {
    var a = areaDe(l), r = [];
    visiveis(l).forEach(function (o) {
      var b = o.getBoundingRect(true, true), x1 = Math.max(b.left, a.x), y1 = Math.max(b.top, a.y), x2 = Math.min(b.left + b.width, a.x + a.w), y2 = Math.min(b.top + b.height, a.y + a.h);
      if (x2 > x1 && y2 > y1) r.push({ x1: x1, y1: y1, x2: x2, y2: y2 });
    });
    return r;
  }
  function areaUniao(r) { // área da união dos retângulos, em px²
    var xs = [], ys = [];
    r.forEach(function (q) { xs.push(q.x1, q.x2); ys.push(q.y1, q.y2); });
    xs = xs.sort(function (a, b) { return a - b; }); ys = ys.sort(function (a, b) { return a - b; });
    var t = 0;
    for (var i = 0; i < xs.length - 1; i++) for (var j = 0; j < ys.length - 1; j++) {
      var cx = (xs[i] + xs[i + 1]) / 2, cy = (ys[j] + ys[j + 1]) / 2;
      if ((xs[i + 1] - xs[i]) && (ys[j + 1] - ys[j]) && r.some(function (q) { return cx > q.x1 && cx < q.x2 && cy > q.y1 && cy < q.y2; })) t += (xs[i + 1] - xs[i]) * (ys[j + 1] - ys[j]);
    }
    return t;
  }
  function blocos(r) { // grupos de retângulos que se tocam
    var g = r.map(function (_, i) { return i; });
    function raiz(i) { while (g[i] !== i) i = g[i] = g[g[i]]; return i; }
    r.forEach(function (a, i) { r.forEach(function (b, j) { if (j > i && a.x1 < b.x2 && b.x1 < a.x2 && a.y1 < b.y2 && b.y1 < a.y2) g[raiz(i)] = raiz(j); }); });
    var n = {}; r.forEach(function (_, i) { n[raiz(i)] = 1; }); return Object.keys(n).length;
  }
  function orcamento() {
    var itens = [];
    ladosAtivos().forEach(function (l) {
      var c = caixaOcupada(l); if (!c) return;
      var p = pxPorCm(l), w = c.w / p, h = c.h / p, area, nb = 1;
      if (porItem()) { var r = retangulos(l); area = Math.max(1, Math.ceil(areaUniao(r) / (p * p))); nb = blocos(r); }
      else area = Math.max(1, Math.ceil(w * h));
      var valor = Math.max(tarifa.minimo_por_lado_centavos, Math.round(area * tarifa.centavos_por_cm2));
      itens.push({ lado: l, rotulo_lado: lado(l).rotulo, elementos: c.n, medicao: porItem() ? 'area_util' : 'retangulo', blocos: nb, largura_cm: +w.toFixed(1), altura_cm: +h.toFixed(1), area_cm2: area,
        centavos_por_cm2: tarifa.centavos_por_cm2, minimo_centavos: tarifa.minimo_por_lado_centavos, minimo_aplicado: valor === tarifa.minimo_por_lado_centavos && area * tarifa.centavos_por_cm2 < valor, centavos: valor });
    });
    return itens;
  }
  function etiqueta(ctx, t, x, y, yb) { // etiqueta dourada abaixo (ou acima) do retângulo
    ctx.setLineDash([]); ctx.font = '700 11px Manrope, sans-serif'; var tw = ctx.measureText(t).width;
    var ty = yb + 16 > tela().h - 2 ? y - 6 : yb + 16;
    ctx.fillStyle = '#C9A45C'; ctx.fillRect(x, ty - 12, tw + 10, 16); ctx.fillStyle = '#142219'; ctx.fillText(t, x + 5, ty);
  }
  function desenharOcupado(c, ctx) { // mostra no editor o espaço que está sendo cobrado
    if (exportando || !prod || c.lado !== ladoAtual) return;
    var b = caixaOcupada(c.lado); if (!b) return;
    var p = pxPorCm(c.lado);
    var v = c.viewportTransform;
    ctx.save(); ctx.transform(v[0], v[1], v[2], v[3], v[4], v[5]); ctx.strokeStyle = '#C9A45C'; ctx.lineWidth = 1.5; ctx.setLineDash([3, 3]); ctx.fillStyle = 'rgba(201,164,92,.1)';
    if (porItem()) {
      var r = retangulos(c.lado);
      ctx.beginPath(); r.forEach(function (q) { ctx.rect(q.x1, q.y1, q.x2 - q.x1, q.y2 - q.y1); }); ctx.fill('nonzero');
      r.forEach(function (q) { ctx.strokeRect(q.x1, q.y1, q.x2 - q.x1, q.y2 - q.y1); });
      var ult = r[r.length - 1];
      etiqueta(ctx, fmtCm(String(Math.ceil(areaUniao(r) / (p * p)))) + ' cm² de área útil', ult.x1, ult.y1, ult.y2);
    } else {
      ctx.fillRect(b.x, b.y, b.w, b.h); ctx.strokeRect(b.x, b.y, b.w, b.h);
      etiqueta(ctx, fmtCm((b.w / p).toFixed(1)) + ' × ' + fmtCm((b.h / p).toFixed(1)) + ' cm', b.x, b.y, b.y + b.h);
    }
    ctx.restore();
  }
  function descreve(o) {
    if (o.tipo === 'texto') return '"' + o.text.replace(/\s+/g, ' ').slice(0, 40) + (o.text.length > 40 ? '…' : '') + '"';
    if (o.tipo === 'emoji') return o.text;
    if (o.tipo === 'imagem') return o.nomeArquivo || 'Imagem';
    return (FORMAS[o.forma] && FORMAS[o.forma].nome) || 'Forma';
  }
  function precoBase() { return varSel && varSel.preco_centavos != null ? varSel.preco_centavos : K.precoFinal(prod); }
  var rafPreco;
  function atualizarPreco() {
    cancelAnimationFrame(rafPreco);
    rafPreco = requestAnimationFrame(function () {
      if (!prod) return;
      var it = orcamento(), extra = it.reduce(function (s, i) { return s + i.centavos; }, 0), base = precoBase(), un = base + extra;
      agendarPrevia();
      $('orc-base-nome').textContent = prod.nome.replace(/ personalizad[ao]$/i, '') + ' ' + (varSel ? varSel.nome : '');
      $('orc-base').textContent = K.reais(base);
      $('orc-itens').innerHTML = it.length ? it.map(function (i) {
        var med = i.medicao === 'area_util' ? i.area_cm2 + ' cm² úteis' + (i.blocos > 1 ? ' em ' + i.blocos + ' áreas' : '') : fmtCm(i.largura_cm) + ' × ' + fmtCm(i.altura_cm) + ' cm';
        return '<li><span><b>Estampa ' + esc(i.rotulo_lado.toLowerCase()) + '</b> ' + med + '<small>' + i.area_cm2 + ' cm² × ' + K.reais(i.centavos_por_cm2) + ' por cm²' + (i.minimo_aplicado ? ' · valor mínimo por lado' : '') + '</small></span><strong>' + K.reais(i.centavos) + '</strong></li>';
      }).join('') : '<li class="orc-vazio">Adicione imagens, textos, emojis ou formas. O valor é calculado pelo espaço que a arte ocupa no produto.</li>';
      $('orc-unit').textContent = K.reais(un);
      $('qtd').textContent = qtd;
      $('orc-total').textContent = K.reais(un * qtd); $('topo-preco').textContent = K.reais(un * qtd);
      $('orc-pix').textContent = K.reais(Math.round(un * qtd * (1 - K.config.descontoPix))) + ' no Pix · ' + K.parcela(un * qtd);
      var temArte = it.length > 0, est = varSel ? varSel.estoque : 0;
      $('confirmar').disabled = $('confirmar-2').disabled = !temArte || est <= 0;
      $('confirmar').textContent = est <= 0 ? 'Esgotado' : (temArte ? 'Enviar arte' : 'Adicione algo');
      $('confirmar-2').textContent = est <= 0 ? 'Esgotado nesta cor' : (temArte ? 'Confirmar valor e enviar arte' : 'Adicione algo ao produto');
    });
  }
  $('menos').onclick = function () { qtd = Math.max(1, qtd - 1); atualizarPreco(); };
  $('mais').onclick = function () { if (varSel && qtd < varSel.estoque) qtd++; atualizarPreco(); };
  $('tabela-precos').innerHTML = '<li>' + K.reais(tarifa.centavos_por_cm2) + ' por cm² da área ocupada pelos itens (itens sobrepostos contam uma vez só)</li><li>Valor mínimo de ' + K.reais(tarifa.minimo_por_lado_centavos) + ' por lado com arte</li>';

  // ---------- rascunho (fica salvo no navegador) ----------
  var tRasc;
  function gravarRascunho(semAtual) {
    var r = { versao: 2, atual: semAtual ? null : prod && prod.slug, artes: {}, uploads: uploads };
    Object.keys(artes).forEach(function (k) {
      if (semAtual && prod && k === prod.slug) return;
      var g = artes[k], vazio = LADOS.every(function (l) { return !g.lados[l] || g.lados[l] === '[]'; });
      if (!vazio || k === r.atual) r.artes[k] = { cor: g.cor, variante: g.variante, lados: g.lados };
    });
    try { localStorage.setItem(RASCUNHO, JSON.stringify(r)); }
    catch (e) { // sem espaço: guarda sem as fotos
      try {
        r.uploads = [];
        Object.keys(r.artes).forEach(function (k) { var L = {}; LADOS.forEach(function (l) { L[l] = JSON.stringify(JSON.parse(r.artes[k].lados[l] || '[]').filter(function (o) { return o.tipo !== 'imagem'; })); }); r.artes[k] = Object.assign({}, r.artes[k], { lados: L }); });
        localStorage.setItem(RASCUNHO, JSON.stringify(r));
      } catch (e2) {}
    }
  }
  var tRasc;
  function salvarRascunho() {
    clearTimeout(tRasc);
    tRasc = setTimeout(function () { if (!prod || enviado) return; if (carregandoArte) return salvarRascunho(); guardarAtual(); gravarRascunho(false); }, 600);
  }
  function lerRascunho() {
    try {
      var r = JSON.parse(localStorage.getItem(RASCUNHO)); if (!r) return null;
      if (r.versao === 2) return r;
      var L = {}; LADOS.forEach(function (l) { L[l] = JSON.stringify((r.lados && r.lados[l]) || []); }); // formato antigo
      var a = {}; a[r.slug] = { cor: r.cor, variante: r.variante, lados: L };
      return { versao: 2, atual: r.slug, artes: a, uploads: r.uploads || [] };
    } catch (e) { return null; }
  }
  function apagarRascunho() { try { localStorage.removeItem(RASCUNHO); } catch (e) {} }

  async function retomar(r, pedido) {
    artes = r.artes || {}; uploads = r.uploads || [];
    var n = Object.keys(artes).reduce(function (s, k) { return s + LADOS.reduce(function (t, l) { return t + JSON.parse(artes[k].lados[l] || '[]').length; }, 0); }, 0);
    var alvo = pedido || r.atual || Object.keys(artes)[0];
    var p = produtos.find(function (x) { return x.slug === alvo; });
    if (p) await selecionarProduto(p);
    salvo = true;
    return n > 0;
  }

  // arte que já está no carrinho (personalizar.html?arte=id): abre ela, com a cor, o tamanho e a quantidade
  var editandoId = null, editandoNome = '';
  async function abrirArteSalva(id, r) {
    if (r) { artes = r.artes || {}; uploads = r.uploads || []; }
    function avisar(t, erro) { var e = $('aviso-edicao'); e.className = 'aviso ' + (erro ? 'aviso-erro' : 'aviso-info') + ' palco-aviso'; e.textContent = t; e.hidden = false; setTimeout(function () { e.hidden = true; }, 9000); }
    var u = await K.usuarioAtual();
    if (!u) { avisar('Entre na sua conta para abrir a arte que está no carrinho.', true); return false; }
    var q = await sb.from('personalizacoes').select('id, produto_id, variante_id, dados, quantidade, imagens_enviadas').eq('id', id).maybeSingle();
    var a = q.data, p = a && produtos.find(function (x) { return x.id === a.produto_id; });
    if (q.error || !a || !p) { avisar('Não encontramos essa arte na sua conta.', true); return false; }
    var v = p.variantes.find(function (x) { return x.id === a.variante_id; }), lados = {};
    LADOS.forEach(function (l) { lados[l] = JSON.stringify((a.dados && a.dados[l]) || []); });
    artes[p.slug] = { cor: v ? (v.cor || v.nome) : null, variante: a.variante_id, lados: lados };
    (a.imagens_enviadas || []).forEach(function (im) { if (!uploads.some(function (x) { return x.id === im.id; })) uploads.push(im); });
    prod = null; await selecionarProduto(p);
    if (a.quantidade) { qtd = a.quantidade; atualizarPreco(); }
    editandoId = a.id; editandoNome = (a.dados && a.dados.nome_peca) || ''; salvo = true;
    avisar('Você está editando ' + (editandoNome ? '“' + editandoNome + '”' : 'a arte #' + String(a.id).slice(0, 8).toUpperCase()) + ' do carrinho. Ao enviar de novo, ela substitui a antiga.');
    return true;
  }

  // ---------- prévia 3D ----------
  var tPrevia;
  function agendarPrevia() { if (tPrevia) return; tPrevia = setTimeout(function () { tPrevia = 0; atualizarPrevia(); }, 140); } // ao vivo, no máximo ~7 vezes por segundo
  function renderSemGuia(c, fn) { // desenha sem a linha tracejada e sem a área dourada
    var ov = c.overlayImage, bg = c.backgroundImage, bgc = c.backgroundColor;
    exportando = true; c.overlayImage = null;
    try { return fn(c); } finally { c.overlayImage = ov; c.backgroundImage = bg; c.backgroundColor = bgc; exportando = false; }
  }
  function atualizarPrevia() {
    if ((!previa && !palco) || !prod || !canvases.frente) return Promise.resolve();
    var m = M[prod.modelo_personalizado];
    if (m.envolve) {
      var a = areaDe('frente');
      var tex = renderSemGuia(canvases.frente, function (c) { c.backgroundImage = null; c.backgroundColor = cor.hex; var k = c.getZoom(); return c.toCanvasElement((palco ? 1800 : 1000) / a.w / k, { left: a.x * k, top: a.y * k, width: a.w * k, height: a.h * k }); });
      if (palco) palco.caneca(tex, cor.hex);
      if (previa) previa.caneca(tex, cor.hex);
    } else {
      var img = {};
      ladosAtivos().forEach(function (l) { img[l] = renderSemGuia(canvases[l], function (c) { c.backgroundColor = null; return c.toCanvasElement((palco ? 2 : 0.9) / c.getZoom()); }); });
      var prof = prod.modelo_personalizado === 'ecobag' ? 0.13 : 0.36;
      if (palco) palco.roupa(img.frente, img.verso || img.frente, prof, prod.modelo_personalizado + ':' + tela().w + 'x' + tela().h);
      if (previa) previa.plano(img.frente, img.verso || img.frente, prof);
    }
    return Promise.resolve();
  }

  // ---------- exportar ----------
  function exportarLado(l) {
    var c = canvases[l], a = areaDe(l), bg = c.backgroundImage, bgc = c.backgroundColor, ov = c.overlayImage, k = c.getZoom();
    exportando = true; c.discardActiveObject(); c.overlayImage = null; c.renderAll();
    var previa = c.toDataURL({ format: 'jpeg', quality: 0.86, multiplier: 1.25 / k, enableRetinaScaling: false });
    c.backgroundImage = null; c.backgroundColor = null; c.renderAll();
    var mult = 2400 / Math.max(a.w, a.h);
    var arte = c.toDataURL({ format: 'png', left: a.x * k, top: a.y * k, width: a.w * k, height: a.h * k, multiplier: mult / k, enableRetinaScaling: false });
    exportando = false; c.backgroundImage = bg; c.backgroundColor = bgc; c.overlayImage = ov; c.renderAll();
    return { previa: previa, arte: arte };
  }
  function reduzir(dataUrl, largura) {
    return new Promise(function (ok) {
      var im = new Image(); im.onload = function () {
        var s = largura / im.width, c = document.createElement('canvas'); c.width = largura; c.height = Math.round(im.height * s);
        c.getContext('2d').drawImage(im, 0, 0, c.width, c.height); ok(c.toDataURL('image/jpeg', 0.8));
      }; im.src = dataUrl;
    });
  }
  function hexDe(c) { return typeof c === 'string' ? c : ''; }
  function elementos() {
    var lista = [], n = 0;
    ladosAtivos().forEach(function (l) {
      visiveis(l).forEach(function (o, camada) {
        var p = pxPorCm(l), a = areaDe(l), c = o.getCenterPoint(), m = medir(o, l), t = o.tipo || 'forma';
        var e = { numero: ++n, lado: lado(l).rotulo, camada: camada + 1, tipo: NOME_TIPO[t], descricao: descreve(o), largura_cm: +m.w.toFixed(1), altura_cm: +m.h.toFixed(1),
          centro_x_cm: +((c.x - a.x) / p).toFixed(1), centro_y_cm: +((c.y - a.y) / p).toFixed(1), rotacao_graus: Math.round(o.angle || 0),
          espelhado: !!o.flipX, opacidade: Math.round((o.opacity == null ? 1 : o.opacity) * 100) };
        if (t === 'texto') Object.assign(e, { texto: o.text, fonte: o.fontFamily, tamanho_fonte_px: Math.round(o.fontSize * o.scaleY), cor: hexDe(o.fill), negrito: o.fontWeight === 'bold', italico: o.fontStyle === 'italic', alinhamento: o.textAlign, contorno: o.strokeWidth && o.stroke ? hexDe(o.stroke) + ' (' + o.strokeWidth + ' px)' : null });
        if (t === 'emoji') e.emoji = o.text;
        if (t === 'imagem') { e.arquivo = o.nomeArquivo; e.imagem_id = o.imgId; }
        if (t === 'forma') Object.assign(e, { forma: FORMAS[o.forma] ? FORMAS[o.forma].nome : o.forma, cor: hexDe(eContorno(o) ? o.stroke : o.fill), contorno: !eContorno(o) && o.strokeWidth && o.stroke ? hexDe(o.stroke) : null });
        lista.push(e);
      });
    });
    return lista;
  }
  function uuid() {
    if (window.crypto && crypto.randomUUID) return crypto.randomUUID();
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (ch) { var r = Math.random() * 16 | 0; return (ch === 'x' ? r : (r & 3 | 8)).toString(16); });
  }

  // ---------- confirmar e enviar ----------
  var dlg = $('dlg-confirmar');
  $('confirmar-2').onclick = function () { $('confirmar').click(); };
  $('confirmar').onclick = async function () {
    var it = orcamento(); if (!it.length) return;
    var un = precoBase() + it.reduce(function (s, i) { return s + i.centavos; }, 0);
    $('conf-resumo').innerHTML = '<strong>' + esc(prod.nome) + '</strong> · ' + esc(varSel.nome) + ' · ' + qtd + (qtd > 1 ? ' unidades' : ' unidade') + '<br>Pré-valor: <strong>' + K.reais(un * qtd) + '</strong> (' + K.reais(un) + ' cada)';
    $('conf-msg').hidden = true; $('l-msg').hidden = true;
    var u = await K.usuarioAtual();
    if (u) await mostrarConfirmacao(u); else mostrarLogin();
    if (!dlg.open) { if (dlg.showModal) dlg.showModal(); else dlg.setAttribute('open', ''); }
  };
  function fecharDialogo() { dlg.close ? dlg.close() : dlg.removeAttribute('open'); }
  $('conf-cancelar').onclick = fecharDialogo; $('l-cancelar').onclick = fecharDialogo;

  // ---------- entrar ou criar conta antes de enviar ----------
  var modoLogin = 'entrar';
  function mostrarLogin() { $('form-confirmar').hidden = true; $('form-login').hidden = false; modoDeLogin(modoLogin); }
  function modoDeLogin(m) {
    modoLogin = m;
    $('l-aba-entrar').setAttribute('aria-selected', m === 'entrar'); $('l-aba-criar').setAttribute('aria-selected', m === 'criar');
    $('l-campo-nome').hidden = m !== 'criar'; $('l-nome').required = m === 'criar';
    $('l-dica').hidden = m !== 'criar'; $('l-esqueci').hidden = m === 'criar';
    $('l-senha').autocomplete = m === 'criar' ? 'new-password' : 'current-password';
    $('l-enviar').textContent = m === 'criar' ? 'Criar conta e continuar' : 'Entrar e continuar';
    $('l-msg').hidden = true;
  }
  $('l-aba-entrar').onclick = function () { modoDeLogin('entrar'); };
  $('l-aba-criar').onclick = function () { modoDeLogin('criar'); };
  async function mostrarConfirmacao(u) {
    $('form-login').hidden = true; $('form-confirmar').hidden = false;
    if (!$('c-peca').value && editandoNome) $('c-peca').value = editandoNome;
    setTimeout(function () { if (!$('c-peca').value) $('c-peca').focus(); }, 60);
    if (!$('c-nome').value || !$('c-contato').value) {
      var pf = await sb.from('perfis').select('nome,email,telefone').eq('id', u.id).maybeSingle();
      var d = pf.data || {};
      if (!$('c-nome').value) $('c-nome').value = d.nome || (u.user_metadata && u.user_metadata.nome) || '';
      if (!$('c-contato').value) $('c-contato').value = d.telefone || d.email || u.email || '';
    }
    $('conf-conta').textContent = 'Você entrou como ' + u.email + '. A peça vai para o carrinho e a arte fica salva na sua conta.';
  }
  async function registrarAcesso(u, nome) {
    var r = await sb.rpc('registrar_acesso', { p_nome: nome || (u.user_metadata && u.user_metadata.nome) || null, p_aceita_novidades: null });
    if (r.error) console.warn('Não foi possível registrar o acesso:', r.error.message);
  }
  $('form-login').addEventListener('submit', async function (e) {
    e.preventDefault();
    var msg = $('l-msg'), btn = $('l-enviar'), email = $('l-email').value.trim(), senha = $('l-senha').value, nome = $('l-nome').value.trim();
    function aviso(t, tipo) { msg.hidden = false; msg.className = 'aviso aviso-' + (tipo || 'erro'); msg.textContent = t; }
    btn.disabled = true; aviso(modoLogin === 'criar' ? 'Criando sua conta...' : 'Entrando...', 'info');
    try {
      if (modoLogin === 'criar') {
        var base = location.href.split('?')[0].split('#')[0].replace(/[^/]*$/, '');
        var rc = await sb.auth.signUp({ email: email, password: senha, options: { data: { nome: nome }, emailRedirectTo: base + 'entrar.html' } });
        if (rc.error) return aviso(K.erroAmigavel(rc.error));
        if (!rc.data.session) { guardarAtual(); gravarRascunho(false); return aviso('Conta criada! Enviamos um link de confirmação para ' + email + '. Depois de confirmar, volte para esta página: a sua arte fica guardada aqui neste navegador.', 'ok'); }
        await registrarAcesso(rc.data.user, nome);
        if (nome && !$('c-nome').value) $('c-nome').value = nome;
        await mostrarConfirmacao(rc.data.user);
      } else {
        var r = await sb.auth.signInWithPassword({ email: email, password: senha });
        if (r.error) return aviso(K.erroAmigavel(r.error));
        await registrarAcesso(r.data.user);
        await mostrarConfirmacao(r.data.user);
      }
    } catch (err) { aviso(K.erroAmigavel(err)); }
    finally { btn.disabled = false; }
  });
  $('form-confirmar').addEventListener('submit', async function (e) {
    e.preventDefault(); if (enviando) return;
    if (!(await K.usuarioAtual())) { mostrarLogin(); return; }
    var nome = $('c-nome').value.trim(), contato = $('c-contato').value.trim(), msg = $('conf-msg'), btn = $('conf-enviar');
    var nomePeca = $('c-peca').value.trim().replace(/\s+/g, ' ').slice(0, 40);
    if (!nomePeca) { msg.hidden = false; msg.className = 'aviso aviso-erro'; msg.textContent = 'Dê um nome para esta peça (ex.: Caneca da vovó). Assim você e o designer sabem qual é qual.'; $('c-peca').focus(); return; }
    if (!nome || !contato) { msg.hidden = false; msg.className = 'aviso aviso-erro'; msg.textContent = 'Preencha seu nome e um WhatsApp ou e-mail para o designer falar com você.'; return; }
    enviando = true; btn.disabled = true; msg.hidden = false; msg.className = 'aviso aviso-info'; msg.textContent = 'Preparando sua arte em alta qualidade...';
    try {
      await new Promise(function (r) { setTimeout(r, 30); });
      var it = orcamento(), extra = it.reduce(function (s, i) { return s + i.centavos; }, 0), base = precoBase();
      var usados = ladosAtivos().filter(function (l) { return visiveis(l).length; });
      var ex = {}; usados.forEach(function (l) { ex[l] = exportarLado(l); });
      if (M[prod.modelo_personalizado].envolve && previa) { // caneca: fotos da caneca 3D com a arte
        await atualizarPrevia();
        ex.frente.previa = previa.foto(Math.PI, 640);
        ex.verso = { previa: previa.foto(Math.PI / 2, 640), arte: null };
      }
      var mini = await reduzir((ex.frente || ex.verso).previa, 240);
      var dados = { modelo: prod.modelo_personalizado, versao: 1, nome_peca: nomePeca, cor: cor.hex, cor_nome: cor.nome, site: /^https?:/.test(location.protocol) ? location.href.split(/[?#]/)[0].replace(/[^/]*$/, '') : null }; LADOS.forEach(function (l) { dados[l] = snapshot(l); });
      var idsUsados = {}; ladosAtivos().forEach(function (l) { visiveis(l).forEach(function (o) { if (o.imgId) idsUsados[o.imgId] = 1; }); });
      var u = await K.usuarioAtual(), id = uuid();
      msg.textContent = 'Enviando para o nosso designer...';
      var r = await sb.from('personalizacoes').insert({
        id: id, cliente_id: u ? u.id : null, cliente_nome: nome, cliente_contato: contato, observacoes: $('c-obs').value.trim() || null,
        produto_id: prod.id, variante_id: varSel.id, produto_nome: prod.nome, variante_nome: varSel.nome, modelo: prod.modelo_personalizado, quantidade: qtd,
        dados: dados, lados_usados: usados, miniatura: mini,
        previa_frente: ex.frente ? ex.frente.previa : null, previa_verso: ex.verso ? ex.verso.previa : null,
        arte_frente: ex.frente ? ex.frente.arte : null, arte_verso: ex.verso ? ex.verso.arte : null,
        preco_base_centavos: base, preco_adicional_centavos: extra, preco_total_centavos: (base + extra) * qtd,
        orcamento: it,
        elementos: elementos(),
        imagens_enviadas: uploads.filter(function (x) { return idsUsados[x.id]; })
      });
      if (r.error) throw r.error;
      if (editandoId) { K.salvarCarrinho(K.carrinho().filter(function (i) { return i.personalizacao_id !== editandoId; })); editandoId = null; } // a arte editada substitui a antiga
      K.adicionarAoCarrinho({ nome_peca: nomePeca, variante_id: varSel.id, produto_id: prod.id, slug: prod.slug, nome: prod.nome, variante: varSel.nome, preco: base + extra, preco_base: base, adicional: extra,
        qtd: qtd, icone: prod.icone, estoque: varSel.estoque, personalizacao_id: id, miniatura: mini });
      salvo = true; enviado = true; clearTimeout(tRasc); delete artes[prod.slug]; gravarRascunho(true);
      dlg.close ? dlg.close() : dlg.removeAttribute('open');
      $('sucesso').hidden = false;
      $('suc-valor').textContent = K.reais((base + extra) * qtd);
      $('suc-img').src = mini;
    } catch (err) {
      msg.className = 'aviso aviso-erro';
      var m = K.erroAmigavel(err);
      msg.textContent = /too large|413|payload/i.test(m) ? 'Sua arte ficou muito pesada para enviar. Tente usar imagens menores.' : 'Não foi possível enviar: ' + m;
    } finally { enviando = false; btn.disabled = false; }
  });
  window.addEventListener('beforeunload', function (e) { if (!salvo && prod && LADOS.some(function (l) { return canvases[l] && canvases[l].getObjects().length; })) { e.preventDefault(); e.returnValue = ''; } });

  // ---------- início ----------
  renderEscolha();
  var r = lerRascunho(), pedido = K.param('p'), arteId = K.param('arte');
  if (arteId && await abrirArteSalva(arteId, r)) { /* veio do carrinho: abre exatamente essa arte */ }
  else if (r && await retomar(r, pedido)) { $('aviso-rascunho').hidden = false; }
  else {
    var inicial = produtos.find(function (p) { return p.slug === pedido; }) || produtos.find(function (p) { return p.variantes.some(function (v) { return v.estoque > 0; }); });
    if (inicial) selecionarProduto(inicial);
    if (celular.matches && !pedido) abrirPainel('produto');
  }
  if (!celular.matches) abrirPainel('arte');
  $('descartar-rascunho').onclick = function () {
    apagarRascunho(); uploads = []; artes = {};
    if (canvases.frente) LADOS.forEach(function (l) { historico[l] = []; refazer[l] = []; restaurar(l, '[]'); });
    $('aviso-rascunho').hidden = true;
  };
});
