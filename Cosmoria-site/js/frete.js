// DESATIVADO (modo vitrine, nov/2026): o site não calcula mais frete; entrega e frete são do Mercado Livre.
// O código fica guardado para poder voltar (js/config.js > modoVitrine: false e reativar o <script src="js/frete.js"> nas páginas).
// Cálculo de frete da Portal Cosmoria.
// Carregar depois de js/comum.js. Usa a função "calcular-frete" do Supabase.
(function () {
  var K = window.Cosmoria, C = K.config;
  var URL_FRETE = C.supabaseUrl + '/functions/v1/calcular-frete';
  var CHAVE_CEP = 'cosmoria_cep', CHAVE_ESCOLHA = 'cosmoria_frete';

  function ler(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }
  function gravar(k, v) { try { localStorage.setItem(k, v); } catch (e) {} }
  function mascara(v) { v = String(v || '').replace(/\D/g, '').slice(0, 8); return v.length > 5 ? v.slice(0, 5) + '-' + v.slice(5) : v; }
  function prazo(d) { return d === 1 ? '1 dia útil' : d + ' dias úteis'; }

  async function calcular(cep, itens) {
    var r = await fetch(URL_FRETE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', apikey: C.supabaseKey },
      body: JSON.stringify({ cep: cep, itens: itens })
    });
    var j = await r.json().catch(function () { return {}; });
    if (!r.ok) throw new Error(j.erro || 'Não foi possível calcular o frete agora.');
    return j;
  }

  // Monta a caixa "Calcular frete" dentro de `onde`.
  // obterItens(): devolve [{variante_id, quantidade}] (pode ser async).
  // aoEscolher(opcao, resposta): chamado quando a cliente escolhe uma opção (opcional).
  function montar(onde, obterItens, aoEscolher) {
    var box = document.createElement('div');
    box.className = 'frete-box';
    box.style.cssText = 'display:flex;flex-direction:column;gap:10px;padding:16px 0;border-top:1px solid var(--salvia-borda)';
    box.innerHTML =
      '<label for="frete-cep" style="font-size:14px;font-weight:700">Calcular frete e prazo</label>' +
      '<form class="frete-form" style="display:flex;gap:8px">' +
        '<input id="frete-cep" inputmode="numeric" autocomplete="postal-code" placeholder="00000-000" maxlength="9" ' +
          'style="flex:1;min-width:0;font:inherit;padding:12px 14px;border-radius:8px;border:1px solid var(--salvia-borda);background:#FFFDF8">' +
        '<button class="btn" type="submit" style="min-height:46px">Calcular</button>' +
      '</form>' +
      '<div class="frete-res" role="status" aria-live="polite"></div>';
    onde.appendChild(box);
    var input = box.querySelector('input'), res = box.querySelector('.frete-res');
    input.value = mascara(ler(CHAVE_CEP));
    input.addEventListener('input', function () { input.value = mascara(input.value); });

    var ultima = null;
    async function rodar() {
      var cep = input.value.replace(/\D/g, '');
      if (cep.length !== 8) { res.innerHTML = '<p class="aviso aviso-erro" style="margin:0">Digite um CEP com 8 números.</p>'; return; }
      gravar(CHAVE_CEP, cep);
      res.innerHTML = '<p style="margin:0;font-size:14px;color:var(--texto-suave)">Calculando...</p>';
      try {
        var itens = await obterItens();
        if (!itens || !itens.length) { res.innerHTML = ''; return; }
        var r = ultima = await calcular(cep, itens);
        if (!r.opcoes.length) { res.innerHTML = '<p class="aviso aviso-erro" style="margin:0">Ainda não entregamos nesse CEP.</p>'; return; }
        var escolhida = ler(CHAVE_ESCOLHA);
        if (!r.opcoes.some(function (o) { return o.modalidade === escolhida; })) escolhida = r.opcoes[0].modalidade;
        res.innerHTML = '<div style="display:flex;flex-direction:column;gap:8px">' + r.opcoes.map(function (o) {
          return '<label style="display:flex;align-items:center;gap:10px;padding:10px 12px;border:1px solid var(--salvia-borda);border-radius:8px;cursor:pointer">' +
            '<input type="radio" name="frete-op" value="' + o.modalidade + '"' + (o.modalidade === escolhida ? ' checked' : '') + '>' +
            '<span style="flex:1"><strong>' + K.esc(o.nome) + '</strong><br><span style="font-size:13px;color:var(--texto-suave)">' +
              'Chega em até ' + prazo(o.prazo_dias) + (o.distancia_km != null ? ' · ' + String(o.distancia_km).replace('.', ',') + ' km' : '') + '</span></span>' +
            '<strong>' + (o.preco_centavos === 0 ? 'Grátis' : K.reais(o.preco_centavos)) + '</strong></label>';
        }).join('') + '</div>' +
        (r.frete_gratis ? '<p style="margin:0;font-size:13px;color:var(--verde)">Frete grátis em compras acima de ' + K.reais(r.frete_gratis_acima_centavos) + '.</p>' : '') +
        '<p style="margin:0;font-size:12px;color:var(--texto-suave)">Valores de teste.</p>';
        avisar(escolhida);
      } catch (e) {
        res.innerHTML = '<p class="aviso aviso-erro" style="margin:0">' + K.esc(e.message) + '</p>';
      }
    }
    function avisar(mod) {
      gravar(CHAVE_ESCOLHA, mod);
      var o = ultima && ultima.opcoes.find(function (x) { return x.modalidade === mod; });
      if (o && aoEscolher) aoEscolher(o, ultima);
    }
    box.querySelector('form').addEventListener('submit', function (e) { e.preventDefault(); rodar(); });
    res.addEventListener('change', function (e) { if (e.target.name === 'frete-op') avisar(e.target.value); });
    if (input.value.replace(/\D/g, '').length === 8) rodar();
    return { recalcular: rodar };
  }

  K.frete = { calcular: calcular, montar: montar };

  document.addEventListener('DOMContentLoaded', function () {
    var pagina = location.pathname.split('/').pop() || 'index.html';

    // Página de produto: monta depois que o botão "Adicionar" aparece
    if (pagina === 'produto.html') {
      var slug = K.param('p'), varianteUnica = null;
      var obs = new MutationObserver(function () {
        var ok = document.getElementById('ok');
        if (!ok || document.querySelector('.frete-box')) return;
        obs.disconnect();
        var bloco = document.createElement('div');
        ok.insertAdjacentElement('afterend', bloco);
        montar(bloco, async function () {
          var b = document.querySelector('.opcao[aria-pressed="true"]');
          var id = b ? Number(b.dataset.id) : null;
          if (!id) {
            if (!varianteUnica) {
              var r = await K.sb.from('produtos').select('variantes(id,estoque)').eq('slug', slug).maybeSingle();
              var vs = (r.data && r.data.variantes) || [];
              varianteUnica = (vs.find(function (v) { return v.estoque > 0; }) || vs[0] || {}).id;
            }
            id = varianteUnica;
          }
          var q = Number((document.getElementById('qtd') || {}).textContent) || 1;
          return id ? [{ variante_id: id, quantidade: q }] : [];
        });
      });
      obs.observe(document.getElementById('conteudo'), { childList: true, subtree: true });
    }

    // Carrinho: monta no resumo, antes do "Total no Pix", e soma o frete aos totais
    if (pagina === 'carrinho.html') {
      var resumo = document.getElementById('resumo');
      var linhaTotal = document.getElementById('total-pix');
      if (!resumo || !linhaTotal) return;
      var bloco = document.createElement('div');
      linhaTotal.closest('.linha-resumo').insertAdjacentElement('beforebegin', bloco);
      function itensCarrinho() { return K.carrinho().map(function (i) { return { variante_id: i.variante_id, quantidade: i.qtd }; }); }
      var caixa = montar(bloco, itensCarrinho, function (o, r) {
        var sub = r.subtotal_centavos, f = o.preco_centavos;
        document.getElementById('frete').textContent = (f === 0 ? 'Grátis' : K.reais(f)) + ' · ' + o.nome;
        linhaTotal.textContent = K.reais(Math.round(sub * (1 - C.descontoPix)) + f);
        document.getElementById('total-cartao').textContent = 'ou ' + K.reais(sub + f) + ' no cartão, ' + K.parcela(sub + f).replace('ou ', '');
      });
      // o carrinho redesenha os totais quando carrega ou muda quantidades: recalcula o frete em seguida
      var espera = null;
      new MutationObserver(function () {
        clearTimeout(espera);
        espera = setTimeout(function () { if (K.carrinho().length && (ler(CHAVE_CEP) || '').length === 8) caixa.recalcular(); }, 150);
      }).observe(document.getElementById('subtotal'), { childList: true, characterData: true, subtree: true });
    }
  });
})();
