/* Portal Cosmoria · página do produto no MODO VITRINE (produto.html?p=<slug>)
   Mostra, no visual Cosmoria, as mesmas informações do anúncio do Mercado Livre:
   nome, preço, preço original e desconto, fotos, descrição, características (atributos) e variações.
   O botão "Comprar no Mercado Livre" abre o anúncio oficial; pagamento e entrega acontecem lá.
   Os dados ficam na tabela "Cosmoria".vitrine_ml e são atualizados pela função vitrine-ml (painel e todo dia às 6h). */
(function () {
  if (!window.COSMORIA || !window.COSMORIA.modoVitrine) return;
  document.addEventListener('DOMContentLoaded', async function () {
    var K = Cosmoria, sb = K.sb, esc = K.esc, el = document.getElementById('conteudo');
    var slug = K.param('p');
    if (!slug) { location.href = 'loja.html'; return; }
    var r = await sb.from('vitrine_ml').select('*,categoria:categorias(id,nome,slug)').eq('slug', slug).maybeSingle();
    if (r.error) { el.innerHTML = '<p class="aviso aviso-erro">' + esc(K.erroAmigavel(r.error)) + '</p>'; return; }
    var p = r.data;
    if (!p) { el.innerHTML = '<div class="vazio"><span class="emoji" aria-hidden="true">🔮</span><strong>Produto não encontrado</strong><a href="loja.html">Voltar para a loja</a></div>'; return; }
    document.title = p.nome + ' · Portal Cosmoria';
    if (p.categoria) document.getElementById('trilha').insertAdjacentHTML('beforeend', '<span aria-hidden="true">/</span><a href="loja.html?categoria=' + encodeURIComponent(p.categoria.slug) + '">' + esc(p.categoria.nome) + '</a>');

    var fotos = Array.isArray(p.fotos) ? p.fotos : [], atrs = Array.isArray(p.atributos) ? p.atributos : [], vars = Array.isArray(p.variacoes) ? p.variacoes : [];
    var linkML = p.permalink || p.link;
    var disponivel = !p.ml_status || p.ml_status === 'active';
    var linhaInfo = [p.condicao, p.vendidos ? (p.vendidos >= 1000 ? '+' + Math.floor(p.vendidos / 1000) + ' mil vendidos' : p.vendidos + ' vendidos') : ''].filter(Boolean).join(' · ');

    function paragrafos(t) { return esc(t).split(/\n{2,}/).map(function (b) { return '<p>' + b.replace(/\n/g, '<br>') + '</p>'; }).join(''); }

    el.innerHTML = '<div class="prod">' +
      '<div class="prod-galeria">' +
        '<div class="prod-img ml-foto">' + (fotos.length ? '<img id="foto-principal" src="' + esc(fotos[0]) + '" alt="' + esc(p.nome) + '" referrerpolicy="no-referrer">' : '✨') +
          (p.desconto_pct ? '<span class="selo">' + p.desconto_pct + '% OFF</span>' : '') + '</div>' +
        (fotos.length > 1 ? '<div class="prod-miniaturas ml-miniaturas" id="miniaturas">' + fotos.map(function (f, i) { return '<button type="button" data-foto="' + i + '" aria-pressed="' + (i === 0) + '" aria-label="Foto ' + (i + 1) + '"><img src="' + esc(f) + '" alt="" loading="lazy" referrerpolicy="no-referrer"></button>'; }).join('') + '</div>' : '') +
      '</div>' +
      '<div class="prod-info">' +
        (p.categoria ? '<span class="card-cat">' + esc(p.categoria.nome) + '</span>' : '') +
        (linhaInfo ? '<span class="ml-linha">' + esc(linhaInfo) + '</span>' : '') +
        '<h1>' + esc(p.nome) + '</h1>' +
        '<div class="ml-preco">' +
          (p.preco_original_centavos != null ? '<s>' + K.reais(p.preco_original_centavos) + '</s>' : '') +
          (p.preco_centavos != null ? '<span class="preco">' + K.reais(p.preco_centavos) + (p.desconto_pct ? ' <em class="ml-off">' + p.desconto_pct + '% OFF</em>' : '') + '</span>'
            : '<span class="preco" style="font-size:22px">Veja o preço no Mercado Livre</span>') +
          (p.frete_gratis ? '<span class="ml-frete">🚚 Frete grátis pelo Mercado Livre</span>' : '') +
        '</div>' +
        (vars.length ? vars.map(function (g, gi) {
          return '<fieldset class="ml-var"><legend>' + esc(g.nome) + ': <span data-var-nome="' + gi + '">' + esc(((g.opcoes || []).find(function (o) { return o.atual; }) || {}).valor || '') + '</span></legend><div class="opcoes">' +
            (g.opcoes || []).map(function (o, oi) {
              return '<button type="button" class="opcao" data-g="' + gi + '" data-o="' + oi + '" aria-pressed="' + (!!o.atual) + '"' + (o.estoque === 0 ? ' disabled' : '') + '>' + esc(o.valor) + '</button>';
            }).join('') + '</div></fieldset>';
        }).join('') + '<p class="ml-nota">Escolha a opção final no Mercado Livre, na hora da compra.</p>' : '') +
        (disponivel ? '<a class="btn btn-ml" id="comprar" href="' + esc(linkML) + '" target="_blank" rel="noopener nofollow">Comprar no Mercado Livre <span aria-hidden="true">↗</span></a>'
          : '<p class="aviso aviso-erro" style="margin:0">Este anúncio está pausado no Mercado Livre no momento.</p><a class="btn btn-linha" href="' + esc(linkML) + '" target="_blank" rel="noopener nofollow">Ver anúncio no Mercado Livre ↗</a>') +
        '<div class="ml-seguro"><b>🛡️ Compra protegida</b><span>Você vai para o anúncio oficial no Mercado Livre. Pagamento, entrega, garantia e devolução são feitos por lá.</span></div>' +
        (p.atualizado_ml_em ? '<small class="ml-conferido">Preço conferido no Mercado Livre em ' + new Date(p.atualizado_ml_em).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) + '. O valor final é o do anúncio.</small>' : '') +
      '</div></div>' +
      (p.descricao ? '<section class="ml-bloco"><h2>Descrição</h2><div class="ml-desc">' + paragrafos(p.descricao) + '</div></section>' : '') +
      (atrs.length ? '<section class="ml-bloco"><h2>Características</h2><table class="ml-tabela"><tbody>' + atrs.map(function (a) { return '<tr><th scope="row">' + esc(a.nome) + '</th><td>' + esc(a.valor) + '</td></tr>'; }).join('') + '</tbody></table></section>' : '');

    var principal = document.getElementById('foto-principal');
    var mini = document.getElementById('miniaturas');
    function mostrarFoto(url) {
      if (!principal || !url) return; principal.src = url;
      if (mini) mini.querySelectorAll('[data-foto]').forEach(function (x) { x.setAttribute('aria-pressed', fotos[+x.dataset.foto] === url); });
    }
    if (mini) mini.addEventListener('click', function (e) { var b = e.target.closest('[data-foto]'); if (b) mostrarFoto(fotos[+b.dataset.foto]); });
    el.addEventListener('click', function (e) {
      var b = e.target.closest('.opcao[data-g]'); if (!b || b.disabled) return;
      var g = vars[+b.dataset.g], o = g.opcoes[+b.dataset.o];
      el.querySelectorAll('.opcao[data-g="' + b.dataset.g + '"]').forEach(function (x) { x.setAttribute('aria-pressed', x === b); });
      var n = el.querySelector('[data-var-nome="' + b.dataset.g + '"]'); if (n) n.textContent = o.valor;
      if (o.foto) mostrarFoto(o.foto);
    });

    // outros produtos da vitrine (mesma categoria primeiro)
    var lista = [];
    if (p.categoria_id) { var rel = await sb.from('vitrine_ml').select(K.CAMPOS_CARD).eq('categoria_id', p.categoria_id).eq('ativo', true).neq('id', p.id).limit(4); lista = rel.data || []; }
    if (lista.length < 4) {
      var mais = await sb.from('vitrine_ml').select(K.CAMPOS_CARD).eq('ativo', true).neq('id', p.id).order('destaque', { ascending: false }).limit(8);
      (mais.data || []).forEach(function (x) { if (lista.length < 4 && !lista.some(function (y) { return y.id === x.id; })) lista.push(x); });
    }
    if (lista.length) {
      var tit = document.querySelector('#relacionados-box h2'); if (tit) tit.lastChild.textContent = 'Você também pode gostar';
      document.getElementById('ramo-rel').innerHTML = K.ramo(34);
      document.getElementById('relacionados').innerHTML = lista.map(K.cardProduto).join('');
      document.getElementById('relacionados-box').hidden = false;
    }
  });
})();
