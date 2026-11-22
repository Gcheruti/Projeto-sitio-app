/* Portal Cosmoria · funções compartilhadas por todas as páginas */
(function () {
  var C = window.COSMORIA;
  var sb = window.supabase.createClient(C.supabaseUrl, C.supabaseKey, { db: { schema: C.esquema } });
  window.sb = sb;
  // Modo vitrine (js/config.js): produtos vêm da tabela vitrine_ml (anúncios do Mercado Livre) e a compra é no ML.
  // Carrinho, frete e checkout ficam desativados, mas o código deles continua aqui embaixo e volta com modoVitrine = false.
  var VITRINE = !!C.modoVitrine;

  // ---------- regras e textos que o administrador muda pelo painel (admin.html) ----------
  // Ficam guardados no navegador para a página abrir já com os valores certos; são atualizados a cada visita.
  var CHAVE_CFG = 'cosmoria_config_publica';
  C.textos = {};
  function aplicarConfig(cfg) {
    if (!cfg) return;
    if (cfg.parcelas_sem_juros != null) C.parcelasSemJuros = cfg.parcelas_sem_juros;
    if (cfg.desconto_pix_pct != null) C.descontoPix = Number(cfg.desconto_pix_pct) / 100;
    if (cfg.frete_gratis_acima_centavos != null) C.freteGratisAcima = cfg.frete_gratis_acima_centavos;
    C.textos = cfg.textos || {};
    if (C.textos.contato_whatsapp) C.whatsapp = C.textos.contato_whatsapp;
    if (C.textos.contato_email) C.email = C.textos.contato_email;
  }
  try { aplicarConfig(JSON.parse(localStorage.getItem(CHAVE_CFG))); } catch (e) {}
  function aplicarTextos(raiz) {
    (raiz || document).querySelectorAll('[data-texto]').forEach(function (el) {
      var v = C.textos[el.getAttribute('data-texto')];
      if (v) el.textContent = v;
    });
  }
  function atualizarConfig() {
    sb.rpc('config_publica').then(function (r) {
      if (r.error || !r.data) return;
      var novo = JSON.stringify(r.data), velho = null;
      try { velho = localStorage.getItem(CHAVE_CFG); localStorage.setItem(CHAVE_CFG, novo); } catch (e) {}
      if (novo !== velho) { aplicarConfig(r.data); var f = document.querySelector('.faixa'); if (f) f.textContent = textoFaixa(); aplicarTextos(); }
    });
  }
  function textoFaixa() {
    if (VITRINE) return C.textos.faixa_topo || 'Compra segura pelo Mercado Livre · pagamento e entrega garantidos pelo ML';
    return C.textos.faixa_topo || ('Frete grátis acima de ' + reais(C.freteGratisAcima) + ' · ' + (C.parcelasSemJuros > 1 ? C.parcelasSemJuros + 'x sem juros · ' : '') + Math.round(C.descontoPix * 100) + '% off no Pix');
  }

  // ---------- utilidades ----------
  function esc(s) { return String(s == null ? '' : s).replace(/[&<>"']/g, function (c) { return { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]; }); }
  function reais(c) { return (c / 100).toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' }); }
  function param(n) { return new URLSearchParams(location.search).get(n); }
  function precoFinal(p) { if (p.preco_original_centavos !== undefined) return p.preco_centavos; return p.preco_promocional_centavos != null ? p.preco_promocional_centavos : p.preco_centavos; }
  function parcela(c) { var n = C.parcelasSemJuros; return n > 1 ? 'ou ' + n + 'x de ' + reais(Math.ceil(c / n)) + ' sem juros' : ''; }
  function erroAmigavel(e) {
    var m = (e && (e.message || e.error_description)) || String(e);
    if (/Invalid login credentials/i.test(m)) return 'E-mail ou senha incorretos.';
    if (/Email not confirmed/i.test(m)) return 'Confirme seu e-mail pelo link que enviamos antes de entrar.';
    if (/User already registered/i.test(m)) return 'Já existe uma conta com esse e-mail. Tente entrar.';
    if (/Password should be at least/i.test(m)) return 'A senha precisa ter pelo menos 6 caracteres.';
    if (/rate limit/i.test(m)) return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
    if (/schema must be one of|Invalid schema/i.test(m)) return 'O esquema Cosmoria ainda não está exposto na API do Supabase (Project Settings › Data API › Exposed schemas).';
    if (/Failed to fetch|NetworkError/i.test(m)) return 'Sem conexão com o servidor. Verifique sua internet.';
    return m;
  }

  var RAMO = '<path d="M32 62V6"/><path d="M32 16c-6-2-10-6-11-12 6 1 10 5 11 12z"/><path d="M32 16c6-2 10-6 11-12-6 1-10 5-11 12z"/><path d="M32 30c-8-2-13-7-14-15 8 1 13 7 14 15z"/><path d="M32 30c8-2 13-7 14-15-8 1-13 7-14 15z"/><path d="M32 45c-9-2-15-8-16-17 9 1 15 8 16 17z"/><path d="M32 45c9-2 15-8 16-17-9 1-15 8-16 17z"/>';
  function ramo(tam, estilo) { return '<svg width="' + tam + '" height="' + tam + '" viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="' + (estilo || '') + '">' + RAMO + '</svg>'; }
  var LUA = '<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="#C9A45C" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z"/><path d="M17 3.5l.6 1.4 1.4.6-1.4.6-.6 1.4-.6-1.4-1.4-.6 1.4-.6z"/></svg>';

  // ---------- carrinho (fica no navegador) ----------
  var CHAVE = 'cosmoria_carrinho';
  function carrinho() { try { return JSON.parse(localStorage.getItem(CHAVE)) || []; } catch (e) { return []; } }
  function salvarCarrinho(c) { try { localStorage.setItem(CHAVE, JSON.stringify(c)); } catch (e) {} atualizarContador(); }
  function adicionarAoCarrinho(item) {
    var c = carrinho(), ex = !item.personalizacao_id && c.find(function (i) { return i.variante_id === item.variante_id && !i.personalizacao_id; });
    if (ex) ex.qtd += item.qtd; else c.push(item);
    salvarCarrinho(c);
  }
  function totalItens() { return carrinho().reduce(function (s, i) { return s + i.qtd; }, 0); }
  function atualizarContador() {
    var n = totalItens();
    document.querySelectorAll('[data-contador]').forEach(function (e) { e.textContent = n; e.hidden = n === 0; });
    var a = document.getElementById('link-carrinho'); if (a) a.setAttribute('aria-label', 'Carrinho, ' + n + ' itens');
  }

  // ---------- topo e rodapé ----------
  function topo(atual) {
    var marca = C.logo ? '<img src="' + esc(C.logo) + '" alt="">' : LUA;
    var links = [['loja.html', 'Ver tudo', 'loja'], ['personalizar.html', 'Personalizados ✨'], ['loja.html?categoria=camisetas', 'Camisetas'], ['loja.html?categoria=blusas', 'Blusas'],
      ['loja.html?categoria=velas-aromaticas', 'Velas'], ['loja.html?categoria=incensos', 'Incensos'], ['loja.html?categoria=cristais', 'Cristais'],
      ['loja.html?categoria=canecas', 'Canecas'], ['loja.html?categoria=estatuas', 'Estátuas'], ['loja.html?categoria=colares', 'Colares'], ['loja.html?ofertas=1', 'Ofertas']];
    var cat = param('categoria'), url = location.pathname.split('/').pop() + location.search;
    return '<div class="faixa">' + esc(textoFaixa()) + '</div>' +
      '<header class="topo"><div class="wrap topo-linha">' +
      '<a class="marca" href="index.html">' + marca + '<span>Portal Cosmoria</span></a>' +
      '<form class="busca" action="loja.html" role="search"><label class="sr" for="q">Buscar produtos</label>' +
      '<input id="q" name="q" type="search" placeholder="Buscar velas, cristais, camisetas..." value="' + esc(param('q') || '') + '">' +
      '<button class="icone-btn" type="submit" aria-label="Buscar"><svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" aria-hidden="true"><circle cx="11" cy="11" r="7"/><path d="M20 20l-3.5-3.5"/></svg></button></form>' +
      '<nav class="acoes" aria-label="Conta e carrinho"><span id="link-admin" hidden style="display:flex;gap:6px"><a class="adm-link-topo" href="admin.html">Painel admin</a><a class="adm-link-topo" href="admin.html#usuarios">👤 Perfis</a></span><span class="saudacao" id="saudacao"></span>' +
      '<a class="icone-btn" id="link-conta" href="entrar.html" aria-label="Entrar ou criar conta"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" aria-hidden="true"><circle cx="12" cy="8" r="4"/><path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6"/></svg></a>' +
      (VITRINE ? '' : // carrinho desativado no modo vitrine (pode voltar)
      '<a class="icone-btn" id="link-carrinho" href="carrinho.html" aria-label="Carrinho"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 8h14l-1 13H6z"/><path d="M9 8V6a3 3 0 0 1 6 0v2"/></svg><span class="contador" data-contador hidden>0</span></a>') +
      '</nav></div>' +
      '<nav class="menu" aria-label="Categorias"><div class="wrap">' + links.map(function (l) {
        var ativo = (l[0] === url) || (cat && l[0].indexOf('categoria=' + cat) > -1);
        return '<a href="' + l[0] + '"' + (ativo ? ' aria-current="page"' : '') + (l[0] === 'personalizar.html' ? ' style="color:var(--ouro)"' : '') + '>' + l[1] + '</a>';
      }).join('') + '</div></nav></header>';
  }
  function rodape() {
    return '<footer class="rodape"><div class="wrap rodape-grade">' +
      '<div><span style="font-family:var(--serifa);font-size:24px;font-weight:600;color:var(--creme)">Portal Cosmoria</span><span data-texto="rodape_slogan">Artigos místicos e naturais para todos os caminhos.</span><a href="https://www.instagram.com/Portalcosmoria/" style="color:var(--ouro)">@portalcosmoria</a></div>' +
      '<div><strong>Loja</strong><a href="loja.html">Todos os produtos</a><a href="loja.html?ofertas=1">Ofertas</a>' + (VITRINE ? '' : '<a href="carrinho.html">Carrinho</a>') + '<a href="conta.html">Minha conta</a></div>' +
      '<div><strong>Ajuda</strong><a href="#">Perguntas frequentes</a><a href="#">Trocas e devoluções</a><a href="#">Prazos e frete</a><a href="#">Privacidade</a></div>' +
      '<div><strong>Atendimento</strong><span>WhatsApp <span data-texto="contato_whatsapp">' + esc(C.whatsapp) + '</span></span><span data-texto="contato_email">' + esc(C.email) + '</span><span>' + (VITRINE ? 'Compras pelo Mercado Livre' : 'Pix · Cartão de crédito') + '</span></div>' +
      '</div><div class="wrap fim">© Portal Cosmoria · Loja de demonstração com produtos fictícios</div></footer>';
  }

  // ---------- sessão ----------
  async function usuarioAtual() { var r = await sb.auth.getSession(); return r.data.session ? r.data.session.user : null; }
  // Confere no banco se a conta é administradora (papel = 'admin' em perfis). Guarda a resposta durante a visita.
  async function ehAdmin(u) {
    u = u || await usuarioAtual(); if (!u) return false;
    var k = 'cosmoria_admin_' + u.id;
    try { var c = sessionStorage.getItem(k); if (c != null) return c === '1'; } catch (e) {}
    var r = await sb.rpc('eh_admin'), sim = !r.error && r.data === true;
    try { if (!r.error) sessionStorage.setItem(k, sim ? '1' : '0'); } catch (e) {}
    return sim;
  }
  async function atualizarTopoSessao() {
    var u = await usuarioAtual(), a = document.getElementById('link-conta'), s = document.getElementById('saudacao');
    if (!a) return;
    if (u) {
      a.href = 'conta.html'; a.setAttribute('aria-label', 'Minha conta');
      var nome = (u.user_metadata && u.user_metadata.nome) || u.email;
      s.textContent = 'Olá, ' + String(nome).split(' ')[0].split('@')[0];
      var la = document.getElementById('link-admin'); if (la) la.hidden = !(await ehAdmin(u));
    } else { a.href = 'entrar.html'; a.setAttribute('aria-label', 'Entrar ou criar conta'); s.textContent = ''; var lb = document.getElementById('link-admin'); if (lb) lb.hidden = true; }
  }

  // ---------- cartão de produto ----------
  // cartão de um produto da vitrine (anúncio do Mercado Livre)
  function cardVitrine(p) {
    var foto = (p.fotos && p.fotos[0]) || '', promo = p.preco_original_centavos != null;
    return '<a class="card" href="produto.html?p=' + encodeURIComponent(p.slug) + '">' +
      '<div class="card-img' + (foto ? ' com-foto' : '') + '" role="img" aria-label="' + esc(p.nome) + '">' + (foto ? '<img src="' + esc(foto) + '" alt="" loading="lazy" referrerpolicy="no-referrer">' : '✨') +
        (p.desconto_pct ? '<span class="selo">' + p.desconto_pct + '% OFF</span>' : '') + '</div>' +
      (p.categoria ? '<span class="card-cat">' + esc(p.categoria.nome) + '</span>' : '') +
      '<span class="card-nome">' + esc(p.nome) + '</span>' +
      (p.preco_centavos != null ? '<span class="preco">' + (promo ? '<s>' + reais(p.preco_original_centavos) + '</s>' : '') + reais(p.preco_centavos) + '</span>' : '<span class="preco" style="font-size:15px">Ver preço no Mercado Livre</span>') +
      '<span class="parcela">' + (p.frete_gratis ? 'Frete grátis pelo Mercado Livre' : 'Compra pelo Mercado Livre') + '</span></a>';
  }
  function cardProduto(p) {
    if (p.fotos !== undefined) return cardVitrine(p);
    var promo = p.preco_promocional_centavos != null;
    return '<a class="card" href="' + (p.modelo_personalizado ? 'personalizar.html' : 'produto.html') + '?p=' + encodeURIComponent(p.slug) + '">' +
      '<div class="card-img' + (p.imagem ? ' com-foto' : '') + '" role="img" aria-label="' + esc(p.nome) + '">' + (p.imagem ? '<img src="' + esc(p.imagem) + '" alt="" loading="lazy">' : esc(p.icone || '✨')) + (p.selo ? '<span class="selo">' + esc(p.selo) + '</span>' : '') + '</div>' +
      (p.categoria ? '<span class="card-cat">' + esc(p.categoria.nome) + '</span>' : '') +
      '<span class="card-nome">' + esc(p.nome) + '</span>' +
      '<span class="preco">' + (promo ? '<s>' + reais(p.preco_centavos) + '</s>' : '') + reais(precoFinal(p)) + '</span>' +
      '<span class="parcela">' + parcela(precoFinal(p)) + '</span></a>';
  }
  var CAMPOS_CARD_LOJA = 'id,slug,nome,preco_centavos,preco_promocional_centavos,icone,imagem,selo,destaque,criado_em,modelo_personalizado,categoria:categorias(nome,slug)';
  var CAMPOS_CARD_VITRINE = 'id,slug,nome,preco_centavos,preco_original_centavos,desconto_pct,fotos,destaque,frete_gratis,criado_em,categoria:categorias(nome,slug)';
  var CAMPOS_CARD = VITRINE ? CAMPOS_CARD_VITRINE : CAMPOS_CARD_LOJA;
  var TABELA_PRODUTOS = VITRINE ? 'vitrine_ml' : 'produtos'; // de onde a loja lê os produtos

  // ---------- banner de personalizados (usa js/moldes.js se a página carregar) ----------
  function bannerPersonalizados(compacto) {
    var arte = '';
    if (window.MOLDES) arte = [['camiseta', '#F4F3EF', 200], ['caneca', '#1C1C1E', 230], ['ecobag', '#EBE1CB', 200]].map(function (x) {
      var m = window.MOLDES[x[0]], a = m.vitrineArea || m.lados.frente.area, cx = a.x + a.w / 2, cy = a.y + a.h / 2, k = Math.min(a.w, a.h, 180) / 200, escuro = x[1] === '#1C1C1E';
      var motivo = '<g transform="translate(' + cx + ' ' + (cy - 12 * k) + ') scale(' + k + ')"><path d="M14 -62 A62 62 0 1 0 66 26 A50 50 0 1 1 14 -62Z" fill="#C9A45C"/><path d="M40 -40 l4 10 10 4 -10 4 -4 10 -4 -10 -10 -4 10 -4z" fill="' + (escuro ? '#F6F1E7' : '#3F6B4A') + '"/>' +
        '<text y="92" text-anchor="middle" font-family="Georgia,serif" font-size="30" font-weight="700" fill="' + (escuro ? '#F6F1E7' : '#142219') + '">SEU NOME</text></g>';
      var h = Math.round(x[2] * (compacto ? 0.62 : 1));
      return (m.vitrine || m.desenho)(x[1], 'frente').replace('<svg ', '<svg aria-hidden="true" style="width:' + Math.round(h * 520 / 600) + 'px;height:' + h + 'px" ').replace('width="520" height="600" ', '').replace('</svg>', motivo + '</svg>');
    }).join('');
    else arte = '<span style="font-size:' + (compacto ? 56 : 90) + 'px">👕☕👜</span>';
    var estrelas = compacto ? '' : '<span class="bp-estrelas" aria-hidden="true"><span style="left:6%;top:14%">✦</span><span style="left:46%;top:8%;animation-delay:.8s">✧</span><span style="right:8%;bottom:16%;animation-delay:1.6s">✦</span><span style="left:40%;bottom:10%;animation-delay:2.2s;font-size:14px">✦</span></span>';
    return '<a class="banner-pers' + (compacto ? ' compacto' : '') + '" href="personalizar.html">' + estrelas +
      '<div class="bp-txt"><span class="bp-olho">Novo · Ateliê Cosmoria</span><h2>' + (compacto ? 'Crie a sua peça personalizada' : 'Do seu jeito, com a sua energia') + '</h2>' +
      '<p>' + (compacto ? 'Camisetas, moletons, canecas e ecobags com a sua foto, frase ou símbolo. Valor na hora.' : 'Escolha camiseta, moletom, caneca ou ecobag e coloque suas fotos, frases, emojis e símbolos na frente e nas costas. Você vê o valor na hora, enquanto cria.') + '</p>' +
      '<span class="btn btn-verde">Personalizar agora ✨</span></div><div class="bp-arte">' + arte + '</div></a>';
  }

  window.Cosmoria = { sb: sb, esc: esc, reais: reais, param: param, precoFinal: precoFinal, parcela: parcela, erroAmigavel: erroAmigavel,
    ramo: ramo, carrinho: carrinho, salvarCarrinho: salvarCarrinho, adicionarAoCarrinho: adicionarAoCarrinho,
    usuarioAtual: usuarioAtual, ehAdmin: ehAdmin, aplicarTextos: aplicarTextos, cardProduto: cardProduto, CAMPOS_CARD: CAMPOS_CARD, TABELA_PRODUTOS: TABELA_PRODUTOS, VITRINE: VITRINE, bannerPersonalizados: bannerPersonalizados, config: C };

  document.addEventListener('DOMContentLoaded', function () {
    var t = document.getElementById('topo'), r = document.getElementById('rodape');
    if (t) t.innerHTML = topo();
    if (r) r.innerHTML = rodape();
    aplicarTextos(); atualizarConfig();
    atualizarContador(); atualizarTopoSessao();
    sb.auth.onAuthStateChange(function (ev) { if (ev === 'SIGNED_OUT') { try { Object.keys(sessionStorage).forEach(function (k) { if (k.indexOf('cosmoria_admin_') === 0) sessionStorage.removeItem(k); }); } catch (e) {} } atualizarTopoSessao(); });
  });
})();
