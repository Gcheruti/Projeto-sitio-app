/* Portal Cosmoria · painel do administrador (admin.html)
   Quem pode mexer é decidido no banco (RLS + papel = 'admin' na tabela perfis).
   Esta tela só organiza os formulários. */
(function () {
  const K = window.Cosmoria, sb = K.sb, esc = K.esc;
  const $ = (id) => document.getElementById(id);
  const principal = $('conteudo');
  let conteudo = principal;

  // ---------------- utilidades ----------------
  function toast(msg, tipo) {
    const t = $('toast'); t.textContent = msg; t.className = 'adm-toast ' + (tipo === 'erro' ? 'erro' : 'ok'); t.hidden = false;
    clearTimeout(toast._t); toast._t = setTimeout(() => { t.hidden = true; }, tipo === 'erro' ? 7000 : 3000);
  }
  function erro(e) {
    const m = (e && (e.message || e.details)) || String(e);
    if (e && e.code === '23505') return 'Já existe um cadastro com esse mesmo valor (por exemplo, o mesmo endereço/slug ou SKU). Troque e tente de novo.';
    if (e && e.code === '23503') return 'Não dá para apagar: este item está ligado a outros cadastros (pedidos, produtos ou subcategorias).';
    if (e && e.code === '23514') return 'Algum valor não é aceito pelo banco (fora do limite permitido). Confira os campos.';
    if (e && (e.code === '42501' || /row-level security|permission denied/i.test(m))) return 'Sem permissão. Sua conta precisa ser administradora e o arquivo sql/admin.sql precisa ter sido rodado no Supabase.';
    if (e && e.code === '42P01') return 'Tabela não encontrada no banco. Rode os arquivos .sql da pasta no Supabase.';
    return K.erroAmigavel(e);
  }
  function reaisTxt(c, casas) {
    if (c == null || c === '') return '';
    return (Number(c) / 100).toLocaleString('pt-BR', { minimumFractionDigits: 2, maximumFractionDigits: casas || 2 });
  }
  function lerNumero(s) {
    s = String(s == null ? '' : s).trim().replace(/^R\$\s*/, '').replace(/\s/g, '');
    if (!s) return null;
    if (s.indexOf(',') > -1) s = s.replace(/\./g, '').replace(',', '.');
    else if (!/^-?\d+\.\d{1,4}$/.test(s)) s = s.replace(/\./g, '');
    const n = Number(s);
    return isNaN(n) ? NaN : n;
  }
  function slugify(s) {
    return String(s || '').normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '').slice(0, 80);
  }
  function data(d) { return d ? new Date(d).toLocaleString('pt-BR', { dateStyle: 'short', timeStyle: 'short' }) : ''; }
  function carregando() { conteudo.innerHTML = '<p class="carregando">Carregando...</p>'; }
  function falha(e, area) { (area || conteudo).innerHTML = '<p class="aviso aviso-erro">' + esc(erro(e)) + '</p>'; }
  function cabecalho(titulo, texto, botoes) {
    return '<div class="adm-cab"><div><h1>' + esc(titulo) + '</h1>' + (texto ? '<p>' + texto + '</p>' : '') + '</div>' + (botoes || '') + '</div>';
  }

  // ---------------- campos de formulário ----------------
  // tipos: texto, area, slug, inteiro, decimal, dinheiro, dinheiro4, bool, ref, opcoes, cor, fixo
  let seq = 0;
  function campo(f, v) {
    const id = 'c' + (++seq), req = f.obrig ? ' required' : '', ajuda = f.ajuda ? '<small>' + f.ajuda + '</small>' : '';
    const lab = '<label for="' + id + '">' + esc(f.r) + (f.obrig ? ' *' : '') + '</label>';
    const dk = ' data-k="' + f.k + '" id="' + id + '"';
    let inp;
    switch (f.tipo) {
      case 'area': inp = '<textarea' + dk + ' rows="' + (f.linhas || 4) + '"' + req + '>' + esc(v == null ? '' : v) + '</textarea>'; break;
      case 'inteiro': inp = '<input' + dk + ' type="number" step="1"' + (f.min != null ? ' min="' + f.min + '"' : '') + ' value="' + esc(v == null ? '' : v) + '"' + req + '>'; break;
      case 'decimal': inp = '<input' + dk + ' inputmode="decimal" value="' + esc(v == null ? '' : String(v).replace('.', ',')) + '"' + req + '>'; break;
      case 'dinheiro': case 'dinheiro4':
        inp = '<span class="adm-rs"><span>R$</span><input' + dk + ' inputmode="decimal" placeholder="0,00" value="' + esc(reaisTxt(v, f.tipo === 'dinheiro4' ? 4 : 2)) + '"' + req + '></span>'; break;
      case 'bool': return '<label class="adm-check"><input type="checkbox"' + dk + (v ? ' checked' : '') + '> <span>' + esc(f.r) + (f.ajuda ? '<small>' + f.ajuda + '</small>' : '') + '</span></label>';
      case 'ref': case 'opcoes': {
        const ops = (f.tipo === 'ref' ? f.opcoesFn() : f.opcoes);
        inp = '<select' + dk + req + '>' + (f.vazio != null ? '<option value="">' + esc(f.vazio) + '</option>' : '') +
          ops.map((o) => '<option value="' + esc(o[0]) + '"' + (String(o[0]) === String(v == null ? '' : v) ? ' selected' : '') + '>' + esc(o[1]) + '</option>').join('') + '</select>'; break;
      }
      case 'cor': inp = '<span class="adm-cor"><input type="color" value="' + esc(/^#[0-9a-f]{6}$/i.test(v || '') ? v : '#ffffff') + '" data-espelho="' + id + '"><input' + dk + ' value="' + esc(v || '') + '" placeholder="#RRGGBB"></span>'; break;
      case 'fixo': inp = '<input' + dk + ' value="' + esc(v == null ? '' : v) + '" readonly>'; break;
      default: inp = '<input' + dk + (f.tipo === 'slug' ? ' data-slug-de="' + (f.de || '') + '" pattern="[a-z0-9-]+"' : '') + ' value="' + esc(v == null ? '' : v) + '"' + req + (f.max ? ' maxlength="' + f.max + '"' : '') + '>';
    }
    return '<div class="campo' + (f.largo ? ' largo' : '') + '">' + lab + inp + ajuda + '</div>';
  }
  function ligarCampos(raiz, novo) {
    raiz.querySelectorAll('[data-espelho]').forEach((c) => {
      const t = $(c.dataset.espelho);
      c.addEventListener('input', () => { t.value = c.value.toUpperCase(); });
      t.addEventListener('input', () => { if (/^#[0-9a-f]{6}$/i.test(t.value)) c.value = t.value; });
    });
    raiz.querySelectorAll('[data-slug-de]').forEach((s) => {
      const origem = raiz.querySelector('[data-k="' + s.dataset.slugDe + '"]');
      if (!origem) return;
      let manual = !novo && !!s.value;
      s.addEventListener('input', () => { manual = true; });
      origem.addEventListener('input', () => { if (!manual) s.value = slugify(origem.value); });
      s.addEventListener('blur', () => { s.value = slugify(s.value); });
    });
  }
  function lerCampos(raiz, campos) {
    const out = {};
    for (const f of campos) {
      if (f.tipo === 'fixo' || f.soLista) continue;
      const el = raiz.querySelector('[data-k="' + f.k + '"]'); if (!el) continue;
      let v;
      if (f.tipo === 'bool') v = el.checked;
      else if (f.tipo === 'dinheiro' || f.tipo === 'dinheiro4') {
        v = lerNumero(el.value);
        if (v != null) { if (isNaN(v) || v < 0) throw f.r + ': valor inválido.'; v = f.tipo === 'dinheiro' ? Math.round(v * 100) : Math.round(v * 10000) / 100; }
      } else if (f.tipo === 'inteiro') { v = el.value === '' ? null : parseInt(el.value, 10); if (v != null && isNaN(v)) throw f.r + ': use um número inteiro.'; }
      else if (f.tipo === 'decimal') { v = lerNumero(el.value); if (v != null && isNaN(v)) throw f.r + ': número inválido.'; }
      else if (f.tipo === 'ref') v = el.value === '' ? null : (isNaN(el.value) ? el.value : Number(el.value));
      else { v = el.value.trim(); if (v === '' && !f.vazioTexto) v = null; }
      if (f.tipo === 'cor' && v && !/^#[0-9a-f]{6}$/i.test(v)) throw f.r + ': use o formato #RRGGBB.';
      if (f.obrig && (v == null || v === '')) throw 'Preencha: ' + f.r + '.';
      out[f.k] = v;
    }
    return out;
  }
  function chaveDe(def, linha) {
    const ks = [].concat(def.chave), m = {};
    ks.forEach((k) => { m[k] = linha[k]; });
    return m;
  }
  function mostrarValor(f, v, linha) {
    if (f.mostrar) return f.mostrar(v, linha);
    if (v == null || v === '') return '<span class="adm-cinza">—</span>';
    if (f.tipo === 'dinheiro' || f.tipo === 'dinheiro4') return 'R$ ' + reaisTxt(v, f.tipo === 'dinheiro4' ? 4 : 2);
    if (f.tipo === 'bool') return v ? 'Sim' : 'Não';
    if (f.tipo === 'ref') { const o = f.opcoesFn().find((x) => String(x[0]) === String(v)); return esc(o ? o[1] : v); }
    if (f.tipo === 'decimal') return esc(String(v).replace('.', ','));
    return esc(v);
  }

  // ---------------- janela (dialog) ----------------
  function abrirJanela(titulo, html, aoSalvar, extra) {
    const d = $('dialogo');
    d.innerHTML = '<form method="dialog" class="adm-janela" novalidate><div class="adm-janela-cab"><h2>' + esc(titulo) + '</h2><button type="button" class="adm-x" data-fechar aria-label="Fechar">×</button></div>' +
      '<div class="adm-janela-corpo">' + html + '</div><p class="aviso aviso-erro" data-msg hidden></p>' +
      '<div class="adm-janela-pe">' + (extra || '') + '<span style="flex:1"></span><button type="button" class="btn btn-linha" data-fechar>Cancelar</button><button type="submit" class="btn btn-verde">Salvar</button></div></form>';
    const form = d.querySelector('form'), msg = d.querySelector('[data-msg]');
    d.querySelectorAll('[data-fechar]').forEach((b) => { b.onclick = () => d.close(); });
    form.onsubmit = async (ev) => {
      ev.preventDefault(); msg.hidden = true;
      const btns = form.querySelectorAll('button'); btns.forEach((b) => { b.disabled = true; });
      try { await aoSalvar(form); d.close(); }
      catch (e) { msg.textContent = typeof e === 'string' ? e : erro(e); msg.hidden = false; }
      btns.forEach((b) => { b.disabled = false; });
    };
    if (typeof d.showModal === 'function') d.showModal(); else d.setAttribute('open', '');
    return { dialogo: d, form: form, msg: msg };
  }
  function confirmar(texto) { return window.confirm(texto); }

  // ---------------- dados de apoio ----------------
  let CATS = [], COLS = [];
  async function carregarApoio() {
    const [c, l] = await Promise.all([
      sb.from('categorias').select('id,slug,nome,categoria_pai_id,ordem').order('ordem'),
      sb.from('colecoes').select('id,slug,nome,ordem').order('ordem')]);
    CATS = c.data || []; COLS = l.data || [];
  }
  function nomeCat(id) {
    const c = CATS.find((x) => x.id === id); if (!c) return '';
    const p = c.categoria_pai_id && CATS.find((x) => x.id === c.categoria_pai_id);
    return (p ? p.nome + ' › ' : '') + c.nome;
  }
  function listaCats(semId) {
    const out = [];
    CATS.filter((c) => !c.categoria_pai_id).forEach((p) => {
      if (p.id !== semId) out.push([p.id, p.nome]);
      CATS.filter((f) => f.categoria_pai_id === p.id && f.id !== semId).forEach((f) => out.push([f.id, '   ' + p.nome + ' › ' + f.nome]));
    });
    return out;
  }

  // ---------------- tela genérica: lista de registros ----------------
  async function blocoTabela(def, alvo) {
    let q = sb.from(def.tabela).select(def.select || '*');
    [].concat(def.ordem || []).forEach((o) => { q = q.order(o); });
    const r = await q;
    if (r.error) { alvo.innerHTML = '<p class="aviso aviso-erro">' + esc(erro(r.error)) + '</p>'; return; }
    const linhas = r.data, cols = def.campos.filter((f) => f.lista);
    alvo.innerHTML = '<div class="adm-bloco-cab"><div>' + (def.subtitulo ? '<h2>' + esc(def.subtitulo) + '</h2>' : '') + (def.ajuda ? '<p>' + def.ajuda + '</p>' : '') + '</div>' +
      (def.podeCriar ? '<button class="btn btn-verde" type="button" data-novo>+ Adicionar</button>' : '') + '</div>' +
      (linhas.length ? '<div class="adm-rolagem"><table class="adm-tabela"><thead><tr>' + cols.map((f) => '<th>' + esc(f.rLista || f.r) + '</th>').join('') + '<th></th></tr></thead><tbody>' +
        linhas.map((l, i) => '<tr>' + cols.map((f) => '<td>' + mostrarValor(f, l[f.k], l) + '</td>').join('') + '<td class="adm-acoes"><button type="button" class="btn btn-linha adm-btn-p" data-editar="' + i + '">Editar</button></td></tr>').join('') +
        '</tbody></table></div>' : '<div class="vazio"><span>Nada cadastrado ainda.</span></div>');
    const abrir = (linha) => {
      const novo = !linha;
      const html = '<div class="adm-grade">' + def.campos.filter((f) => !f.soLista).map((f) => campo(novo || !f.fixoAoEditar ? f : Object.assign({}, f, { tipo: 'fixo' }), linha ? linha[f.k] : f.padrao)).join('') + '</div>';
      const j = abrirJanela((novo ? 'Adicionar · ' : 'Editar · ') + def.nomeItem, html, async (form) => {
        const dados = lerCampos(form, def.campos.filter((f) => !(f.fixoAoEditar && !novo)));
        if (def.validar) def.validar(dados, linha);
        const rr = novo ? await sb.from(def.tabela).insert(dados) : await sb.from(def.tabela).update(dados).match(chaveDe(def, linha));
        if (rr.error) throw rr.error;
        toast(def.nomeItem + ' salvo ✓');
        if (def.depois) await def.depois();
        blocoTabela(def, alvo);
      }, !novo && def.podeApagar ? '<button type="button" class="btn adm-btn-perigo" data-apagar>Apagar</button>' : '');
      ligarCampos(j.form, novo);
      const ap = j.form.querySelector('[data-apagar]');
      if (ap) ap.onclick = async () => {
        if (!confirmar('Apagar "' + (linha.nome || linha[[].concat(def.chave)[0]]) + '"? Isso não pode ser desfeito.')) return;
        const rr = await sb.from(def.tabela).delete().match(chaveDe(def, linha));
        if (rr.error) { j.msg.textContent = erro(rr.error); j.msg.hidden = false; return; }
        j.dialogo.close(); toast(def.nomeItem + ' apagado'); if (def.depois) await def.depois(); blocoTabela(def, alvo);
      };
    };
    const bn = alvo.querySelector('[data-novo]'); if (bn) bn.onclick = () => abrir(null);
    alvo.querySelectorAll('[data-editar]').forEach((b) => { b.onclick = () => abrir(linhas[+b.dataset.editar]); });
  }

  // ---------------- tela genérica: configuração de uma linha só ----------------
  async function blocoUnico(def, alvo) {
    const r = await sb.from(def.tabela).select('*').limit(1).maybeSingle();
    if (r.error || !r.data) { alvo.innerHTML = '<p class="aviso aviso-erro">' + esc(r.error ? erro(r.error) : 'Configuração não encontrada. Rode o arquivo ' + (def.sql || 'sql/admin.sql') + ' no Supabase.') + '</p>'; return; }
    const linha = r.data;
    alvo.innerHTML = '<form class="adm-cartao" novalidate>' + (def.subtitulo ? '<h2>' + esc(def.subtitulo) + '</h2>' : '') + (def.ajuda ? '<p class="adm-ajuda">' + def.ajuda + '</p>' : '') +
      '<div class="adm-grade">' + def.campos.map((f) => campo(f, linha[f.k])).join('') + '</div>' +
      '<div class="adm-linha-botoes"><button class="btn btn-verde" type="submit">Salvar</button><span class="adm-msg" data-msg></span>' +
      (linha.atualizado_em ? '<small class="adm-cinza">Última alteração: ' + data(linha.atualizado_em) + '</small>' : '') + '</div></form>';
    const form = alvo.querySelector('form'), msg = form.querySelector('[data-msg]');
    ligarCampos(form, false);
    form.onsubmit = async (ev) => {
      ev.preventDefault(); msg.textContent = 'Salvando...'; msg.className = 'adm-msg';
      try {
        const dados = lerCampos(form, def.campos);
        if (def.validar) def.validar(dados);
        const rr = await sb.from(def.tabela).update(dados).match(chaveDe(def, linha));
        if (rr.error) throw rr.error;
        msg.textContent = 'Salvo ✓'; msg.className = 'adm-msg ok'; toast('Salvo ✓');
        if (def.depois) def.depois();
      } catch (e) { msg.textContent = typeof e === 'string' ? e : erro(e); msg.className = 'adm-msg erro'; }
    };
  }
  async function telaBlocos(titulo, texto, defs, tipoDe) {
    const conteudo = principal.firstElementChild || principal; // área desta tela
    conteudo.innerHTML = cabecalho(titulo, texto) + defs.map((_, i) => '<section class="adm-bloco" id="bloco' + i + '"><p class="carregando">Carregando...</p></section>').join('');
    await Promise.all(defs.map((d, i) => (tipoDe[i] === 'unico' ? blocoUnico : blocoTabela)(d, $('bloco' + i))));
  }

  // ---------------- definições das tabelas ----------------
  const DEF = {
    categorias: { tabela: 'categorias', chave: 'id', ordem: ['ordem', 'nome'], nomeItem: 'Categoria', podeCriar: true, podeApagar: true,
      ajuda: 'Categorias principais aparecem no menu da loja e na página inicial. Subcategorias ficam "dentro" de uma principal.',
      depois: carregarApoio,
      campos: [
        { k: 'icone', r: 'Ícone (emoji)', lista: true, max: 8, ajuda: 'Ex.: 🕯️ 💎 👕' },
        { k: 'nome', r: 'Nome', obrig: true, lista: true },
        { k: 'slug', r: 'Endereço (slug)', tipo: 'slug', de: 'nome', obrig: true, lista: true, ajuda: 'Só letras minúsculas, números e hífen. Vai no link: loja.html?categoria=...' },
        { k: 'categoria_pai_id', r: 'Fica dentro de', rLista: 'Dentro de', tipo: 'ref', vazio: '— É uma categoria principal —', lista: true,
          opcoesFn: () => listaCats(), mostrar: (v) => v ? esc(nomeCat(v)) : '<span class="adm-cinza">principal</span>' },
        { k: 'descricao', r: 'Descrição', tipo: 'area', largo: true },
        { k: 'ordem', r: 'Ordem', tipo: 'inteiro', lista: true, padrao: 0, ajuda: 'Menor número aparece primeiro.' }
      ] },
    colecoes: { tabela: 'colecoes', chave: 'id', ordem: ['ordem', 'nome'], nomeItem: 'Coleção', podeCriar: true, podeApagar: true,
      ajuda: 'Coleções agrupam produtos por tema (Lua, Tarô, Ervas...). Aparecem em "Escolha a sua energia" na página inicial. Para colocar um produto numa coleção, abra o produto.',
      depois: carregarApoio,
      campos: [
        { k: 'nome', r: 'Nome', obrig: true, lista: true },
        { k: 'slug', r: 'Endereço (slug)', tipo: 'slug', de: 'nome', obrig: true, lista: true, ajuda: 'Vai no link: loja.html?colecao=...' },
        { k: 'descricao', r: 'Descrição curta', tipo: 'area', largo: true, lista: true },
        { k: 'ordem', r: 'Ordem', tipo: 'inteiro', lista: true, padrao: 0 }
      ] },
    loja: { tabela: 'config_loja', chave: 'id', subtitulo: 'Parcelas e desconto no Pix',
      ajuda: 'Aparecem na faixa do topo, nos produtos e no carrinho. O site pega os valores novos na próxima vez que a página abrir.',
      campos: [
        { k: 'parcelas_sem_juros', r: 'Parcelas sem juros', tipo: 'inteiro', min: 1, obrig: true, ajuda: '1 = não mostra parcelamento.' },
        { k: 'desconto_pix_pct', r: 'Desconto no Pix (%)', tipo: 'decimal', obrig: true, ajuda: 'Ex.: 5 = 5% de desconto.' }
      ] },
    freteConfig: { tabela: 'frete_config', chave: 'id', subtitulo: 'Regras do frete', sql: 'sql/frete.sql',
      ajuda: 'Valores usados pela calculadora de frete. O frete grátis também aparece na faixa do topo e no carrinho.',
      campos: [
        { k: 'frete_gratis_acima_centavos', r: 'Frete grátis acima de', tipo: 'dinheiro', obrig: true },
        { k: 'cep_origem', r: 'CEP de onde sai a entrega', obrig: true },
        { k: 'origem_lat', r: 'Latitude da origem', tipo: 'decimal', obrig: true, ajuda: 'No Google Maps, clique com o botão direito no endereço para copiar latitude e longitude.' },
        { k: 'origem_lng', r: 'Longitude da origem', tipo: 'decimal', obrig: true },
        { k: 'preco_km_centavos', r: 'Motoboy: preço por km', tipo: 'dinheiro', obrig: true },
        { k: 'km_gratis', r: 'Motoboy: km grátis', tipo: 'decimal', obrig: true },
        { k: 'km_maximo', r: 'Motoboy: distância máxima (km)', tipo: 'decimal', obrig: true },
        { k: 'fator_rota', r: 'Fator de rota', tipo: 'decimal', obrig: true, ajuda: 'Linha reta × este número ≈ distância real. Ex.: 1,3' },
        { k: 'motoboy_prazo_dias', r: 'Motoboy: prazo (dias)', tipo: 'inteiro', obrig: true },
        { k: 'manuseio_dias', r: 'Dias de preparo (somados aos Correios)', tipo: 'inteiro', obrig: true },
        { k: 'pac_adicional_kg_centavos', r: 'PAC: adicional por kg acima de 1 kg', tipo: 'dinheiro', obrig: true },
        { k: 'sedex_adicional_kg_centavos', r: 'SEDEX: adicional por kg acima de 1 kg', tipo: 'dinheiro', obrig: true }
      ] },
    freteEstados: { tabela: 'frete_tabela_estados', chave: 'uf', ordem: ['uf'], nomeItem: 'Estado', subtitulo: 'Correios por estado (até 1 kg)',
      ajuda: 'Preço e prazo de PAC e SEDEX para cada estado.',
      campos: [
        { k: 'uf', r: 'Estado', tipo: 'texto', lista: true, fixoAoEditar: true },
        { k: 'pac_centavos', r: 'PAC: preço', rLista: 'PAC', tipo: 'dinheiro', obrig: true, lista: true },
        { k: 'pac_prazo_dias', r: 'PAC: prazo (dias)', rLista: 'Prazo PAC', tipo: 'inteiro', obrig: true, lista: true },
        { k: 'sedex_centavos', r: 'SEDEX: preço', rLista: 'SEDEX', tipo: 'dinheiro', obrig: true, lista: true },
        { k: 'sedex_prazo_dias', r: 'SEDEX: prazo (dias)', rLista: 'Prazo SEDEX', tipo: 'inteiro', obrig: true, lista: true }
      ] },
    persConfig: { tabela: 'config_personalizacao', chave: 'id', subtitulo: 'Preço da personalização', sql: 'supabase/personalizados.sql',
      ajuda: 'Pré-valor = preço do produto + (área ocupada pela arte em cm² × preço por cm²), com um mínimo por lado que tem arte.',
      campos: [
        { k: 'centavos_por_cm2', r: 'Preço por cm²', tipo: 'dinheiro4', obrig: true, ajuda: 'Ex.: 0,10 = dez centavos por cm².' },
        { k: 'minimo_por_lado_centavos', r: 'Mínimo por lado com arte', tipo: 'dinheiro', obrig: true }
      ] },
    moldes: { tabela: 'moldes_personalizacao', chave: ['modelo', 'lado'], ordem: ['modelo', 'lado'], nomeItem: 'Área de impressão', subtitulo: 'Tamanho real das áreas de impressão',
      ajuda: 'Largura em cm da área onde a arte é impressa. O editor usa a largura para medir a arte.',
      campos: [
        { k: 'modelo', r: 'Produto', tipo: 'texto', lista: true, fixoAoEditar: true },
        { k: 'lado', r: 'Lado', tipo: 'texto', lista: true, fixoAoEditar: true },
        { k: 'rotulo', r: 'Nome do lado', obrig: true, lista: true },
        { k: 'largura_cm', r: 'Largura (cm)', tipo: 'decimal', obrig: true, lista: true },
        { k: 'altura_cm', r: 'Altura (cm)', tipo: 'decimal', obrig: true, lista: true }
      ] }
  };

  // ---------------- PRODUTOS ----------------
  const MODELOS = [['camiseta', 'Camiseta'], ['babylook', 'Baby look'], ['moletom', 'Moletom'], ['caneca', 'Caneca'], ['ecobag', 'Ecobag']];
  const filtroProd = { q: '', cat: '', sit: '' };

  async function telaProdutos() {
    const conteudo = principal.firstElementChild || principal; // área desta tela
    carregando();
    const r = await sb.from('produtos').select('id,slug,nome,preco_centavos,preco_promocional_centavos,icone,imagem,ativo,destaque,categoria_id,exemplo,modelo_personalizado,variantes(estoque)').order('nome');
    if (r.error) return falha(r.error, conteudo);
    const todos = r.data;
    conteudo.innerHTML = cabecalho('Produtos', 'Cadastre, edite preços, fotos, descrições e estoque. Clique no produto para editar.', '<a class="btn btn-verde" href="#produto/novo">+ Novo produto</a>') +
      '<div class="adm-filtros"><input type="search" id="f-q" placeholder="Buscar por nome..." value="' + esc(filtroProd.q) + '">' +
      '<select id="f-cat"><option value="">Todas as categorias</option>' + listaCats().map((c) => '<option value="' + c[0] + '"' + (String(c[0]) === filtroProd.cat ? ' selected' : '') + '>' + esc(c[1]) + '</option>').join('') + '</select>' +
      '<select id="f-sit"><option value="">Ativos e escondidos</option><option value="ativo">Só os que aparecem na loja</option><option value="inativo">Só os escondidos</option><option value="sem">Sem estoque</option><option value="exemplo">Produtos de teste</option></select></div>' +
      '<p class="adm-cinza" id="f-cont"></p><div id="lista-prod"></div>';
    $('f-sit').value = filtroProd.sit;
    function desenhar() {
      const q = slugify(filtroProd.q).replace(/-/g, ' ');
      const lista = todos.filter((p) => {
        const est = (p.variantes || []).reduce((s, v) => s + (v.estoque || 0), 0); p._est = est;
        if (q && slugify(p.nome).replace(/-/g, ' ').indexOf(q) < 0) return false;
        if (filtroProd.cat) { const c = CATS.find((x) => x.id === p.categoria_id); if (!c || (String(c.id) !== filtroProd.cat && String(c.categoria_pai_id) !== filtroProd.cat)) return false; }
        if (filtroProd.sit === 'ativo' && !p.ativo) return false;
        if (filtroProd.sit === 'inativo' && p.ativo) return false;
        if (filtroProd.sit === 'sem' && est > 0) return false;
        if (filtroProd.sit === 'exemplo' && !p.exemplo) return false;
        return true;
      });
      $('f-cont').textContent = lista.length + (lista.length === 1 ? ' produto' : ' produtos');
      $('lista-prod').innerHTML = lista.length ? '<div class="adm-rolagem"><table class="adm-tabela adm-prods"><thead><tr><th></th><th>Produto</th><th>Categoria</th><th>Preço</th><th>Estoque</th><th>Na loja</th><th>Destaque</th></tr></thead><tbody>' +
        lista.map((p) => '<tr><td><a href="#produto/' + p.id + '" class="adm-mini">' + (p.imagem ? '<img src="' + esc(p.imagem) + '" alt="">' : esc(p.icone || '✨')) + '</a></td>' +
          '<td><a href="#produto/' + p.id + '" class="adm-nome">' + esc(p.nome) + '</a>' + (p.exemplo ? ' <span class="adm-tag">teste</span>' : '') + (p.modelo_personalizado ? ' <span class="adm-tag ouro">personalizável</span>' : '') + '</td>' +
          '<td>' + esc(nomeCat(p.categoria_id)) + '</td>' +
          '<td style="white-space:nowrap">' + (p.preco_promocional_centavos != null ? '<s class="adm-cinza">' + K.reais(p.preco_centavos) + '</s><br><strong>' + K.reais(p.preco_promocional_centavos) + '</strong>' : K.reais(p.preco_centavos)) + '</td>' +
          '<td>' + (p._est > 0 ? p._est : '<span class="adm-tag erro">esgotado</span>') + '</td>' +
          '<td><label class="adm-chave"><input type="checkbox" data-campo="ativo" data-id="' + p.id + '"' + (p.ativo ? ' checked' : '') + '><span class="sr">Mostrar na loja</span></label></td>' +
          '<td><label class="adm-chave"><input type="checkbox" data-campo="destaque" data-id="' + p.id + '"' + (p.destaque ? ' checked' : '') + '><span class="sr">Destaque</span></label></td></tr>').join('') +
        '</tbody></table></div>' : '<div class="vazio"><span class="emoji">🔮</span><span>Nenhum produto encontrado.</span></div>';
    }
    $('f-q').oninput = (e) => { filtroProd.q = e.target.value; desenhar(); };
    $('f-cat').onchange = (e) => { filtroProd.cat = e.target.value; desenhar(); };
    $('f-sit').onchange = (e) => { filtroProd.sit = e.target.value; desenhar(); };
    $('lista-prod').addEventListener('change', async (e) => {
      const c = e.target.closest('[data-campo]'); if (!c) return;
      const p = todos.find((x) => String(x.id) === c.dataset.id), up = {}; up[c.dataset.campo] = c.checked;
      const rr = await sb.from('produtos').update(up).eq('id', p.id);
      if (rr.error) { c.checked = !c.checked; toast(erro(rr.error), 'erro'); return; }
      p[c.dataset.campo] = c.checked;
      toast(c.dataset.campo === 'ativo' ? (c.checked ? 'Produto aparece na loja' : 'Produto escondido da loja') : (c.checked ? 'Produto em destaque na página inicial' : 'Produto saiu dos destaques'));
    });
    desenhar();
  }

  // reduz a foto no navegador antes de salvar (para o site continuar leve)
  function reduzirImagem(arquivo, maxLado, qualidade) {
    return new Promise((ok, nao) => {
      const leitor = new FileReader();
      leitor.onerror = () => nao('Não foi possível ler a imagem.');
      leitor.onload = () => {
        const img = new Image();
        img.onerror = () => nao('Esse arquivo não parece ser uma imagem.');
        img.onload = () => {
          const k = Math.min(1, maxLado / Math.max(img.width, img.height));
          const cv = document.createElement('canvas'); cv.width = Math.round(img.width * k); cv.height = Math.round(img.height * k);
          const cx = cv.getContext('2d'); cx.fillStyle = '#ffffff'; cx.fillRect(0, 0, cv.width, cv.height); cx.drawImage(img, 0, 0, cv.width, cv.height);
          ok(cv.toDataURL('image/jpeg', qualidade));
        };
        img.src = leitor.result;
      };
      leitor.readAsDataURL(arquivo);
    });
  }
  function miniaturaDeUrl(url) {
    return new Promise((ok) => {
      const img = new Image(); img.crossOrigin = 'anonymous';
      img.onload = () => {
        try {
          const k = Math.min(1, 600 / Math.max(img.width, img.height)), cv = document.createElement('canvas');
          cv.width = Math.round(img.width * k); cv.height = Math.round(img.height * k);
          const cx = cv.getContext('2d'); cx.fillStyle = '#fff'; cx.fillRect(0, 0, cv.width, cv.height); cx.drawImage(img, 0, 0, cv.width, cv.height);
          ok(cv.toDataURL('image/jpeg', 0.82));
        } catch (e) { ok(null); }
      };
      img.onerror = () => ok(null);
      img.src = url;
    });
  }

  async function telaProduto(id) {
    const conteudo = principal.firstElementChild || principal; // área desta tela
    carregando();
    const novo = id === 'novo';
    const [rp, rv, rc, ri, amostraP, amostraV] = await Promise.all([
      novo ? Promise.resolve({ data: null }) : sb.from('produtos').select('*').eq('id', id).maybeSingle(),
      novo ? Promise.resolve({ data: [] }) : sb.from('variantes').select('*').eq('produto_id', id).order('ordem'),
      novo ? Promise.resolve({ data: [] }) : sb.from('produto_colecoes').select('colecao_id').eq('produto_id', id),
      novo ? Promise.resolve({ data: [] }) : sb.from('produto_imagens').select('id,ordem,imagem,miniatura').eq('produto_id', id).order('ordem'),
      sb.from('produtos').select('*').limit(1),
      sb.from('variantes').select('*').limit(1)]);
    const e1 = rp.error || rv.error || rc.error || ri.error || amostraP.error;
    if (e1) return falha(e1, conteudo);
    if (!novo && !rp.data) { conteudo.innerHTML = '<p class="aviso aviso-erro">Produto não encontrado.</p><p><a href="#produtos">← Voltar</a></p>'; return; }
    const p = rp.data || { ativo: true, destaque: false, icone: '✨' };
    const colsP = new Set(Object.keys((amostraP.data && amostraP.data[0]) || p));
    const colsV = new Set(Object.keys((amostraV.data && amostraV.data[0]) || (rv.data[0] || {})).concat(['produto_id', 'nome', 'estoque', 'ordem', 'preco_centavos', 'sku']));
    const tem = (k) => novo ? colsP.has(k) || colsP.size === 0 : k in p;
    let vars = (rv.data || []).map((v) => Object.assign({}, v));
    if (novo) vars = [{ nome: 'Único', estoque: 0 }];
    const varsOriginais = vars.filter((v) => v.id).map((v) => v.id);
    let fotos = (ri.data || []).map((f) => Object.assign({}, f));
    const fotosOriginais = fotos.map((f) => f.id);
    const colSel = new Set((rc.data || []).map((x) => x.colecao_id));
    const personalizavel = !!p.modelo_personalizado;

    const camposInfo = [
      { k: 'nome', r: 'Nome do produto', obrig: true, largo: true },
      { k: 'slug', r: 'Endereço (slug)', tipo: 'slug', de: 'nome', obrig: true, ajuda: 'Vai no link: produto.html?p=...' },
      { k: 'categoria_id', r: 'Categoria', tipo: 'ref', vazio: '— Escolha —', opcoesFn: () => listaCats() },
      tem('sku') && { k: 'sku', r: 'Código (SKU)', ajuda: 'Opcional. Seu código interno.' },
      { k: 'descricao', r: 'Descrição', tipo: 'area', largo: true, linhas: 5 },
      tem('como_usar') && { k: 'como_usar', r: 'Como usar', tipo: 'area', largo: true, linhas: 3, ajuda: 'Opcional. Aparece num "abre e fecha" na página do produto.' },
      tem('composicao') && { k: 'composicao', r: 'Composição', tipo: 'area', largo: true, linhas: 3, ajuda: 'Opcional.' }
    ].filter(Boolean);
    const camposPreco = [
      { k: 'preco_centavos', r: 'Preço', tipo: 'dinheiro', obrig: true },
      { k: 'preco_promocional_centavos', r: 'Preço promocional', tipo: 'dinheiro', ajuda: 'Deixe vazio se não estiver em oferta. Preenchido, o produto aparece em "Ofertas".' },
      tem('selo') && { k: 'selo', r: 'Selo no cartão', ajuda: 'Opcional. Ex.: Novo, Oferta, Últimas unidades' },
      { k: 'icone', r: 'Ícone (quando não há foto)', max: 8 }
    ].filter(Boolean);
    const camposVitrine = [
      { k: 'ativo', r: 'Mostrar na loja', tipo: 'bool', ajuda: 'Desmarque para esconder o produto sem apagar.' },
      { k: 'destaque', r: 'Destacar na página inicial', tipo: 'bool' }
    ];
    const camposEnvio = ['peso_gramas', 'altura_cm', 'largura_cm', 'comprimento_cm'].filter(tem).map((k) => ({
      k: k, r: { peso_gramas: 'Peso (gramas)', altura_cm: 'Altura (cm)', largura_cm: 'Largura (cm)', comprimento_cm: 'Comprimento (cm)' }[k], tipo: k === 'peso_gramas' ? 'inteiro' : 'decimal', ajuda: k === 'peso_gramas' ? 'Com a embalagem. Usado no frete.' : '' }));
    const camposPers = tem('modelo_personalizado') ? [{ k: 'modelo_personalizado', r: 'Abrir no editor de personalizados como', tipo: 'opcoes', vazio: 'Não é personalizável', opcoes: MODELOS,
      ajuda: 'Se escolher um molde, o cliente monta a arte no editor. Use cor e tamanho nas opções abaixo.' }] : [];
    const todosCampos = camposInfo.concat(camposPreco, camposVitrine, camposEnvio, camposPers);

    conteudo.innerHTML = '<p class="adm-volta"><a href="#produtos">← Todos os produtos</a></p>' +
      cabecalho(novo ? 'Novo produto' : p.nome, novo ? '' : (p.ativo ? 'Aparece na loja' : 'Escondido da loja') + (p.exemplo ? ' · produto de teste' : ''),
        novo ? '' : '<a class="btn btn-linha" target="_blank" rel="noopener" href="' + (p.modelo_personalizado ? 'personalizar.html' : 'produto.html') + '?p=' + encodeURIComponent(p.slug) + '">Ver na loja ↗</a>') +
      '<form id="form-prod" class="adm-prod" novalidate>' +
      '<section class="adm-cartao"><h2>Informações</h2><div class="adm-grade">' + camposInfo.map((f) => campo(f, p[f.k])).join('') + '</div></section>' +
      '<section class="adm-cartao"><h2>Preço</h2><div class="adm-grade">' + camposPreco.map((f) => campo(f, p[f.k])).join('') + '</div></section>' +
      '<section class="adm-cartao"><h2>Fotos</h2><p class="adm-ajuda">A primeira foto é a capa (aparece na vitrine). Use as setas para mudar a ordem. As fotos são reduzidas automaticamente para o site ficar leve.</p>' +
        '<div class="adm-fotos" id="fotos"></div><div class="adm-linha-botoes"><label class="btn btn-linha adm-arquivo">+ Adicionar fotos<input type="file" id="arq-fotos" accept="image/*" multiple></label>' +
        '<button type="button" class="btn btn-linha" id="foto-link">+ Foto por link (https://...)</button><span class="adm-msg" id="fotos-msg"></span></div></section>' +
      '<section class="adm-cartao"><h2>Opções e estoque</h2><p class="adm-ajuda">Cada opção é um tamanho, cor ou modelo com estoque próprio. Se o produto não tem opções, deixe uma só chamada "Único". O preço da opção é opcional: vazio = usa o preço do produto.</p>' +
        '<div class="adm-rolagem"><table class="adm-tabela adm-vars"><thead><tr><th>Nome da opção</th>' + (colsV.has('tamanho') ? '<th>Tamanho</th>' : '') + (colsV.has('cor') ? '<th>Cor</th><th>Cor (código)</th>' : '') +
        '<th>Estoque</th><th>Preço próprio</th><th>SKU</th><th></th></tr></thead><tbody id="vars"></tbody></table></div>' +
        '<div class="adm-linha-botoes"><button type="button" class="btn btn-linha" id="add-var">+ Adicionar opção</button></div></section>' +
      '<section class="adm-cartao"><h2>Coleções</h2>' + (COLS.length ? '<div class="adm-checks">' + COLS.map((c) => '<label class="adm-check"><input type="checkbox" name="col" value="' + c.id + '"' + (colSel.has(c.id) ? ' checked' : '') + '> <span>' + esc(c.nome) + '</span></label>').join('') + '</div>' : '<p class="adm-cinza">Nenhuma coleção cadastrada.</p>') + '</section>' +
      '<section class="adm-cartao"><h2>Vitrine</h2><div class="adm-checks">' + camposVitrine.map((f) => campo(f, p[f.k])).join('') + '</div></section>' +
      (camposEnvio.length ? '<section class="adm-cartao"><h2>Peso e medidas (para o frete)</h2><div class="adm-grade">' + camposEnvio.map((f) => campo(f, p[f.k])).join('') + '</div></section>' : '') +
      (camposPers.length ? '<section class="adm-cartao"><h2>Personalizados</h2><div class="adm-grade">' + camposPers.map((f) => campo(f, p[f.k])).join('') + '</div></section>' : '') +
      '<div class="adm-barra-salvar"><button type="submit" class="btn btn-verde" id="salvar-prod">Salvar produto</button><span class="adm-msg" id="prod-msg"></span><span style="flex:1"></span>' +
        (novo ? '' : '<button type="button" class="btn adm-btn-perigo" id="apagar-prod">Apagar produto</button>') + '</div></form>';
    const form = $('form-prod');
    ligarCampos(form, novo);

    // ----- fotos -----
    function desenharFotos() {
      $('fotos').innerHTML = fotos.length ? fotos.map((f, i) => '<figure class="adm-foto"><img src="' + esc(f.miniatura || f.imagem) + '" alt="Foto ' + (i + 1) + '">' + (i === 0 ? '<span class="adm-tag ouro">capa</span>' : '') +
        '<div><button type="button" data-f="esq" data-i="' + i + '" aria-label="Mover para a esquerda"' + (i === 0 ? ' disabled' : '') + '>←</button><button type="button" data-f="dir" data-i="' + i + '" aria-label="Mover para a direita"' + (i === fotos.length - 1 ? ' disabled' : '') + '>→</button>' +
        '<button type="button" data-f="del" data-i="' + i + '" aria-label="Remover foto">✕</button></div></figure>').join('') :
        '<div class="adm-sem-foto"><span>' + esc(p.icone || '✨') + '</span><small>Sem fotos: a loja mostra o ícone.</small></div>';
    }
    $('fotos').onclick = (e) => {
      const b = e.target.closest('[data-f]'); if (!b) return;
      const i = +b.dataset.i;
      if (b.dataset.f === 'del') fotos.splice(i, 1);
      else { const j = b.dataset.f === 'esq' ? i - 1 : i + 1; const t = fotos[i]; fotos[i] = fotos[j]; fotos[j] = t; }
      desenharFotos();
    };
    $('arq-fotos').onchange = async (e) => {
      const arqs = Array.from(e.target.files || []), m = $('fotos-msg');
      for (let n = 0; n < arqs.length; n++) {
        m.textContent = 'Preparando foto ' + (n + 1) + ' de ' + arqs.length + '...'; m.className = 'adm-msg';
        try { fotos.push({ imagem: await reduzirImagem(arqs[n], 1400, 0.85), miniatura: await reduzirImagem(arqs[n], 600, 0.82) }); }
        catch (er) { m.textContent = arqs[n].name + ': ' + er; m.className = 'adm-msg erro'; continue; }
      }
      if (m.className !== 'adm-msg erro') m.textContent = arqs.length ? 'Fotos adicionadas. Clique em "Salvar produto" para gravar.' : '';
      e.target.value = ''; desenharFotos();
    };
    $('foto-link').onclick = () => {
      const j = abrirJanela('Foto por link', campo({ k: 'url', r: 'Endereço da imagem', obrig: true, ajuda: 'Precisa começar com https:// e abrir direto a imagem (.jpg, .png, .webp).' }, ''), async (f) => {
        const url = f.querySelector('[data-k="url"]').value.trim();
        if (!/^https:\/\/\S+$/.test(url)) throw 'O link precisa começar com https://';
        const mini = await miniaturaDeUrl(url);
        fotos.push({ imagem: url, miniatura: mini });
        desenharFotos(); $('fotos-msg').textContent = 'Foto adicionada. Clique em "Salvar produto" para gravar.';
      });
      j.form.querySelector('input').focus();
    };
    desenharFotos();

    // ----- variantes -----
    function linhaVar(v, i) {
      const inp = (k, extra) => '<input data-v="' + k + '" data-i="' + i + '" value="' + esc(v[k] == null ? '' : v[k]) + '"' + (extra || '') + '>';
      return '<tr><td>' + inp('nome', ' aria-label="Nome da opção" required') + '</td>' +
        (colsV.has('tamanho') ? '<td>' + inp('tamanho', ' aria-label="Tamanho" style="width:70px"') + '</td>' : '') +
        (colsV.has('cor') ? '<td>' + inp('cor', ' aria-label="Cor" style="width:120px"') + '</td><td><span class="adm-cor"><input type="color" data-vc="' + i + '" value="' + esc(/^#[0-9a-f]{6}$/i.test(v.cor_hex || '') ? v.cor_hex : '#ffffff') + '" aria-label="Escolher cor">' + inp('cor_hex', ' aria-label="Código da cor" placeholder="#RRGGBB" style="width:96px"') + '</span></td>' : '') +
        '<td><input data-v="estoque" data-i="' + i + '" type="number" min="0" step="1" value="' + esc(v.estoque == null ? 0 : v.estoque) + '" aria-label="Estoque" style="width:84px"></td>' +
        '<td><span class="adm-rs"><span>R$</span><input data-v="preco_centavos" data-i="' + i + '" inputmode="decimal" value="' + esc(reaisTxt(v.preco_centavos)) + '" aria-label="Preço próprio" style="width:90px"></span></td>' +
        '<td>' + inp('sku', ' aria-label="SKU" style="width:130px"') + '</td>' +
        '<td><button type="button" class="adm-x" data-del-var="' + i + '" aria-label="Remover opção">✕</button></td></tr>';
    }
    function lerVarsDaTela() {
      form.querySelectorAll('[data-v]').forEach((el) => { vars[+el.dataset.i][el.dataset.v] = el.value; });
    }
    function desenharVars() { $('vars').innerHTML = vars.map(linhaVar).join(''); }
    $('vars').addEventListener('input', (e) => {
      if (e.target.dataset.vc != null) { const t = $('vars').querySelector('[data-v="cor_hex"][data-i="' + e.target.dataset.vc + '"]'); t.value = e.target.value.toUpperCase(); }
    });
    $('vars').onclick = (e) => {
      const b = e.target.closest('[data-del-var]'); if (!b) return;
      lerVarsDaTela(); vars.splice(+b.dataset.delVar, 1); desenharVars();
    };
    $('add-var').onclick = () => { lerVarsDaTela(); vars.push({ nome: '', estoque: 0 }); desenharVars(); const ns = $('vars').querySelectorAll('[data-v="nome"]'); ns[ns.length - 1].focus(); };
    desenharVars();

    // ----- salvar -----
    const msg = $('prod-msg');
    form.onsubmit = async (ev) => {
      ev.preventDefault(); lerVarsDaTela();
      msg.className = 'adm-msg'; msg.textContent = 'Salvando...'; $('salvar-prod').disabled = true;
      try {
        const dados = lerCampos(form, todosCampos);
        dados.slug = slugify(dados.slug || dados.nome);
        if (!dados.slug) throw 'Preencha o endereço (slug).';
        if (!dados.categoria_id) throw 'Escolha a categoria.';
        if (!(dados.preco_centavos > 0)) throw 'O preço precisa ser maior que zero.';
        if (dados.preco_promocional_centavos != null && dados.preco_promocional_centavos >= dados.preco_centavos) throw 'O preço promocional precisa ser menor que o preço normal.';
        if (!vars.length) throw 'Cadastre pelo menos uma opção (pode ser "Único").';
        const varsDados = vars.map((v, i) => {
          if (!String(v.nome || '').trim()) throw 'Dê um nome para cada opção (linha ' + (i + 1) + ').';
          const est = parseInt(v.estoque, 10); if (isNaN(est) || est < 0) throw 'Estoque inválido na opção "' + v.nome + '".';
          let pc = lerNumero(v.preco_centavos === '' || v.preco_centavos == null ? '' : (typeof v.preco_centavos === 'number' ? reaisTxt(v.preco_centavos) : v.preco_centavos));
          if (pc != null) { if (isNaN(pc) || pc <= 0) throw 'Preço inválido na opção "' + v.nome + '".'; pc = Math.round(pc * 100); }
          const d = { nome: String(v.nome).trim(), estoque: est, preco_centavos: pc, ordem: i + 1 };
          if (colsV.has('sku')) d.sku = String(v.sku || '').trim() || ((dados.sku || dados.slug).toUpperCase().slice(0, 30) + '-' + (i + 1) + '-' + Math.random().toString(36).slice(2, 6).toUpperCase());
          ['tamanho', 'cor', 'cor_hex'].forEach((k) => { if (colsV.has(k)) d[k] = String(v[k] || '').trim() || null; });
          if (d.cor_hex && !/^#[0-9a-f]{6}$/i.test(d.cor_hex)) throw 'Código de cor inválido na opção "' + v.nome + '" (use #RRGGBB).';
          if (v.id) d.id = v.id;
          return d;
        });
        if (tem('imagem')) dados.imagem = fotos.length ? (fotos[0].miniatura || fotos[0].imagem) : null;

        // 1) produto
        let pid = novo ? null : p.id;
        if (novo) { const r1 = await sb.from('produtos').insert(dados).select('id').single(); if (r1.error) throw r1.error; pid = r1.data.id; }
        else { const r1 = await sb.from('produtos').update(dados).eq('id', pid); if (r1.error) throw r1.error; }

        // 2) opções (variantes)
        const ficam = varsDados.filter((v) => v.id).map((v) => v.id);
        const sair = varsOriginais.filter((x) => ficam.indexOf(x) < 0);
        if (sair.length) { const r2 = await sb.from('variantes').delete().in('id', sair); if (r2.error) throw Object.assign(r2.error, { etapa: 'opções' }); }
        for (const v of varsDados) {
          const r3 = v.id ? await sb.from('variantes').update(v).eq('id', v.id) : await sb.from('variantes').insert(Object.assign({ produto_id: pid }, v));
          if (r3.error) throw r3.error;
        }

        // 3) coleções
        const marcadas = Array.from(form.querySelectorAll('[name="col"]:checked')).map((c) => Number(c.value));
        const r4 = await sb.from('produto_colecoes').delete().eq('produto_id', pid); if (r4.error) throw r4.error;
        if (marcadas.length) { const r5 = await sb.from('produto_colecoes').insert(marcadas.map((c) => ({ produto_id: pid, colecao_id: c }))); if (r5.error) throw r5.error; }

        // 4) fotos
        const fotosFicam = fotos.filter((f) => f.id).map((f) => f.id);
        const fotosSair = fotosOriginais.filter((x) => fotosFicam.indexOf(x) < 0);
        if (fotosSair.length) { const r6 = await sb.from('produto_imagens').delete().in('id', fotosSair); if (r6.error) throw r6.error; }
        for (let i = 0; i < fotos.length; i++) {
          const f = fotos[i];
          const r7 = f.id ? (f.ordem === i ? { error: null } : await sb.from('produto_imagens').update({ ordem: i }).eq('id', f.id))
            : await sb.from('produto_imagens').insert({ produto_id: pid, ordem: i, imagem: f.imagem, miniatura: f.miniatura || null });
          if (r7.error) throw r7.error;
        }

        toast('Produto salvo ✓');
        if (novo) location.hash = '#produto/' + pid; else telaProduto(pid);
      } catch (e) {
        msg.className = 'adm-msg erro'; msg.textContent = typeof e === 'string' ? e : erro(e);
        if (e && e.code === '23503' && e.etapa === 'opções') msg.textContent = 'Uma opção removida já aparece em pedidos e não pode ser apagada. Coloque o estoque dela em 0.';
      }
      if ($('salvar-prod')) $('salvar-prod').disabled = false;
    };
    const ap = $('apagar-prod');
    if (ap) ap.onclick = async () => {
      if (!confirmar('Apagar o produto "' + p.nome + '" com todas as fotos e opções? Isso não pode ser desfeito.\n\nDica: para só esconder da loja, desmarque "Mostrar na loja".')) return;
      msg.className = 'adm-msg'; msg.textContent = 'Apagando...';
      const passos = [
        () => sb.from('produto_colecoes').delete().eq('produto_id', p.id),
        () => sb.from('produto_imagens').delete().eq('produto_id', p.id),
        () => sb.from('variantes').delete().eq('produto_id', p.id),
        () => sb.from('produtos').delete().eq('id', p.id)];
      for (const passo of passos) {
        const r = await passo();
        if (r.error) { msg.className = 'adm-msg erro'; msg.textContent = r.error.code === '23503' ? 'Este produto já aparece em pedidos e não pode ser apagado. Desmarque "Mostrar na loja" para escondê-lo.' : erro(r.error); return; }
      }
      toast('Produto apagado'); location.hash = '#produtos';
    };
  }

  // ---------------- TEXTOS DO SITE ----------------
  async function telaTextos() {
    const conteudo = principal.firstElementChild || principal; // área desta tela
    carregando();
    const r = await sb.from('textos_site').select('*').order('ordem');
    if (r.error) return falha(r.error, conteudo);
    const grupos = [];
    r.data.forEach((t) => { let g = grupos.find((x) => x.nome === t.grupo); if (!g) grupos.push(g = { nome: t.grupo, itens: [] }); g.itens.push(t); });
    conteudo.innerHTML = cabecalho('Textos do site', 'Mude os textos que aparecem nas páginas. Um campo vazio volta ao texto padrão. As mudanças aparecem para os visitantes na próxima vez que abrirem a página.') +
      '<form id="form-textos" novalidate>' + grupos.map((g) => '<section class="adm-cartao"><h2>' + esc(g.nome) + '</h2><div class="adm-grade">' +
        g.itens.map((t) => campo({ k: t.chave, r: t.rotulo, tipo: t.multilinha ? 'area' : 'texto', linhas: 3, largo: t.multilinha, ajuda: t.ajuda ? esc(t.ajuda) : '' }, t.valor)).join('') + '</div></section>').join('') +
      '<div class="adm-barra-salvar"><button class="btn btn-verde" type="submit">Salvar textos</button><span class="adm-msg" id="tx-msg"></span></div></form>';
    $('form-textos').onsubmit = async (ev) => {
      ev.preventDefault();
      const m = $('tx-msg'); m.className = 'adm-msg'; m.textContent = 'Salvando...';
      const mudou = r.data.filter((t) => { const el = ev.target.querySelector('[data-k="' + t.chave + '"]'); return el && el.value.trim() !== t.valor; });
      for (const t of mudou) {
        const v = ev.target.querySelector('[data-k="' + t.chave + '"]').value.trim();
        const rr = await sb.from('textos_site').update({ valor: v }).eq('chave', t.chave);
        if (rr.error) { m.className = 'adm-msg erro'; m.textContent = erro(rr.error); return; }
        t.valor = v;
      }
      try { localStorage.removeItem('cosmoria_config_publica'); } catch (e) {}
      m.className = 'adm-msg ok'; m.textContent = mudou.length ? mudou.length + (mudou.length === 1 ? ' texto salvo ✓' : ' textos salvos ✓') : 'Nada mudou.';
    };
  }

  // ---------------- PEDIDOS ----------------
  const STATUS_PED = { aguardando_pagamento: 'Aguardando pagamento', pago: 'Pago', em_separacao: 'Em separação', enviado: 'Enviado', entregue: 'Entregue', cancelado: 'Cancelado' };
  async function telaPedidos() {
    const conteudo = principal.firstElementChild || principal; // área desta tela
    carregando();
    const r = await sb.from('pedidos').select('*,itens_pedido(*)').order('criado_em', { ascending: false }).limit(200);
    if (r.error) return falha(r.error, conteudo);
    conteudo.innerHTML = cabecalho('Pedidos', 'Mude a situação e informe o código de rastreio. O cliente vê essas informações em "Minha conta".') +
      (r.data.length ? '<div class="adm-rolagem"><table class="adm-tabela"><thead><tr><th>Pedido</th><th>Data</th><th>Itens</th><th>Total</th><th>Situação</th><th>Rastreio</th><th></th></tr></thead><tbody>' +
        r.data.map((o, i) => '<tr><td><strong>#' + esc(String(o.id).slice(0, 8).toUpperCase()) + '</strong></td><td>' + data(o.criado_em) + '</td>' +
          '<td style="font-size:13px">' + (o.itens_pedido || []).map((it) => esc(it.quantidade + '× ' + (it.nome_produto || it.produto_nome || it.nome || ('item ' + (it.variante_id || ''))))).join('<br>') + '</td>' +
          '<td>' + K.reais(o.total_centavos || 0) + '</td>' +
          '<td><select data-st="' + i + '">' + Object.keys(STATUS_PED).map((k) => '<option value="' + k + '"' + (k === o.status ? ' selected' : '') + '>' + STATUS_PED[k] + '</option>').join('') + '</select></td>' +
          '<td><input data-ras="' + i + '" value="' + esc(o.codigo_rastreio || '') + '" style="width:150px" aria-label="Código de rastreio"></td>' +
          '<td><button class="btn btn-linha adm-btn-p" type="button" data-salvar-ped="' + i + '">Salvar</button></td></tr>').join('') + '</tbody></table></div>'
        : '<div class="vazio"><span class="emoji">🧾</span><span>Nenhum pedido ainda. Eles aparecem aqui quando o checkout estiver funcionando.</span></div>');
    conteudo.onclick = async (e) => {
      const b = e.target.closest('[data-salvar-ped]'); if (!b) return;
      const i = b.dataset.salvarPed, o = r.data[i];
      const rr = await sb.from('pedidos').update({ status: conteudo.querySelector('[data-st="' + i + '"]').value, codigo_rastreio: conteudo.querySelector('[data-ras="' + i + '"]').value.trim() || null }).eq('id', o.id);
      toast(rr.error ? erro(rr.error) : 'Pedido atualizado ✓', rr.error ? 'erro' : 'ok');
    };
  }

  // ---------------- PERFIS (USUÁRIOS) ----------------
  let meuId = null;
  const CAMPOS_PERFIL = [
    { k: 'nome', r: 'Nome' },
    { k: 'email', r: 'E-mail', tipo: 'fixo', ajuda: 'É o e-mail de login. Para trocar, a pessoa muda pela conta dela.' },
    { k: 'telefone', r: 'Telefone / WhatsApp' },
    { k: 'cpf', r: 'CPF' },
    { k: 'data_nascimento', r: 'Data de nascimento', tipo: 'data' },
    { k: 'aceita_novidades', r: 'Aceita receber novidades por e-mail', tipo: 'bool', largo: true }
  ];
  const CAMPOS_END = [['cep', 'CEP'], ['rua', 'Rua'], ['numero', 'Número'], ['complemento', 'Complemento'], ['bairro', 'Bairro'], ['cidade', 'Cidade'], ['uf', 'UF']];
  async function telaUsuarios() {
    const conteudo = principal.firstElementChild || principal; // área desta tela
    carregando();
    const r = await sb.from('perfis').select('*').order('criado_em', { ascending: false });
    if (r.error) return falha(r.error, conteudo);
    conteudo.innerHTML = cabecalho('Perfis', 'Todas as contas que já entraram no site. Clique em "Editar" para mudar os dados de um perfil. Administradores veem este painel e as artes dos clientes. A pessoa precisa ter entrado no site pelo menos uma vez para aparecer aqui.') +
      '<div class="adm-filtros"><input type="search" id="u-q" placeholder="Buscar por nome, e-mail ou telefone..."><select id="u-f"><option value="">Todos os perfis</option><option value="admin">Só administradores</option><option value="cliente">Só clientes</option></select></div><p class="adm-cinza" id="u-cont"></p><div id="u-lista"></div>';
    function desenhar() {
      const q = $('u-q').value.trim().toLowerCase(), so = $('u-f').value;
      const l = r.data.filter((u) => (!so || (so === 'admin') === (u.papel === 'admin')) && (!q || [u.nome, u.email, u.telefone].join(' ').toLowerCase().indexOf(q) > -1));
      $('u-cont').textContent = l.length + (l.length === 1 ? ' perfil' : ' perfis');
      $('u-lista').innerHTML = '<div class="adm-rolagem"><table class="adm-tabela"><thead><tr><th>Nome</th><th>E-mail</th><th>Telefone</th><th>Último acesso</th><th>Acessos</th><th>Papel</th><th></th></tr></thead><tbody>' +
        l.map((u) => '<tr><td><strong>' + esc(u.nome || '—') + '</strong>' + (u.id === meuId ? ' <span class="adm-tag">você</span>' : '') + '</td><td>' + esc(u.email || '') + '</td><td>' + esc(u.telefone || '') + '</td><td>' + data(u.ultimo_acesso) + '</td><td>' + esc(u.total_acessos == null ? '' : u.total_acessos) + '</td>' +
          '<td>' + (u.papel === 'admin' ? '<span class="adm-tag ouro">administrador</span>' : 'cliente') + '</td>' +
          '<td class="adm-acoes"><button type="button" class="btn btn-verde adm-btn-p" data-editar-perfil="' + u.id + '">Editar</button> ' +
          '<button type="button" class="btn ' + (u.papel === 'admin' ? 'adm-btn-perigo' : 'btn-linha') + ' adm-btn-p" data-papel="' + u.id + '">' + (u.papel === 'admin' ? 'Tirar admin' : 'Tornar admin') + '</button></td></tr>').join('') + '</tbody></table></div>';
    }
    async function mudarPapel(u) {
      const virar = u.papel !== 'admin';
      if (!confirmar(virar ? 'Dar acesso de administrador para ' + (u.nome || u.email) + '? Essa pessoa vai poder mudar produtos, preços, textos e perfis da loja.' : 'Tirar o acesso de administrador de ' + (u.nome || u.email) + '?')) return false;
      const rr = await sb.rpc('definir_admin', { p_perfil: u.id, p_admin: virar });
      if (rr.error) { toast(erro(rr.error), 'erro'); return false; }
      toast(virar ? 'Agora é administrador ✓' : 'Acesso de administrador removido');
      if (!virar && u.id === meuId) { try { sessionStorage.clear(); } catch (e) {} location.reload(); return true; }
      telaUsuarios(); return true;
    }
    function editar(u) {
      const campos = CAMPOS_PERFIL.filter((f) => f.k in u), end = (u.endereco && typeof u.endereco === 'object') ? u.endereco : {};
      const html = '<div class="adm-grade">' + campos.map((f) => f.tipo === 'data'
          ? '<div class="campo"><label for="pf-' + f.k + '">' + esc(f.r) + '</label><input type="date" id="pf-' + f.k + '" data-k="' + f.k + '" value="' + esc(u[f.k] || '') + '"></div>'
          : campo(f, u[f.k])).join('') + '</div>' +
        ('endereco' in u ? '<h3 class="adm-sub">Endereço de entrega</h3><div class="adm-grade">' + CAMPOS_END.map((c) => campo({ k: 'end_' + c[0], r: c[1] }, end[c[0]])).join('') + '</div>' : '') +
        '<h3 class="adm-sub">Conta</h3><p class="adm-cinza" style="margin:0">Papel: <b>' + (u.papel === 'admin' ? 'administrador' : 'cliente') + '</b> · Cliente desde ' + data(u.criado_em) + ' · Último acesso ' + (data(u.ultimo_acesso) || '—') + ' · ' + esc(u.total_acessos == null ? 0 : u.total_acessos) + ' acessos</p>';
      const j = abrirJanela('Editar perfil · ' + (u.nome || u.email), html, async (form) => {
        const dados = {};
        campos.forEach((f) => {
          if (f.tipo === 'fixo') return;
          const el = form.querySelector('[data-k="' + f.k + '"]');
          dados[f.k] = f.tipo === 'bool' ? el.checked : (el.value.trim() || null);
        });
        if ('endereco' in u) {
          const e = Object.assign({}, end);
          CAMPOS_END.forEach((c) => { e[c[0]] = form.querySelector('[data-k="end_' + c[0] + '"]').value.trim(); });
          e.uf = (e.uf || '').toUpperCase();
          dados.endereco = e;
        }
        const rr = await sb.from('perfis').update(dados).eq('id', u.id);
        if (rr.error) throw rr.error;
        toast('Perfil salvo ✓'); telaUsuarios();
      }, '<button type="button" class="btn ' + (u.papel === 'admin' ? 'adm-btn-perigo' : 'btn-linha') + '" data-papel-j>' + (u.papel === 'admin' ? 'Tirar acesso de admin' : 'Tornar administrador') + '</button>');
      j.form.querySelector('[data-papel-j]').onclick = async () => { if (await mudarPapel(u)) j.dialogo.close(); };
      const cep = j.form.querySelector('[data-k="end_cep"]');
      if (cep) cep.addEventListener('blur', async () => {
        const c = cep.value.replace(/\D/g, ''); if (c.length !== 8) return;
        try {
          const x = await (await fetch('https://viacep.com.br/ws/' + c + '/json/')).json(); if (x.erro) return;
          [['rua', x.logradouro], ['bairro', x.bairro], ['cidade', x.localidade], ['uf', x.uf]].forEach((p) => { const el = j.form.querySelector('[data-k="end_' + p[0] + '"]'); if (el && p[1]) el.value = p[1]; });
        } catch (e) {}
      });
    }
    $('u-q').oninput = desenhar; $('u-f').onchange = desenhar;
    $('u-lista').onclick = async (e) => {
      const b = e.target.closest('[data-papel]'), ed = e.target.closest('[data-editar-perfil]');
      if (ed) return editar(r.data.find((x) => x.id === ed.dataset.editarPerfil));
      if (b) return mudarPapel(r.data.find((x) => x.id === b.dataset.papel));
    };
    desenhar();
  }

  // ---------------- NEWSLETTER ----------------
  async function telaNewsletter() {
    const conteudo = principal.firstElementChild || principal; // área desta tela
    carregando();
    const r = await sb.from('newsletter').select('*');
    if (r.error) return falha(r.error, conteudo);
    const l = r.data.slice().sort((a, b) => String(b.criado_em || '').localeCompare(String(a.criado_em || '')));
    conteudo.innerHTML = cabecalho('Newsletter', l.length + (l.length === 1 ? ' e-mail inscrito.' : ' e-mails inscritos.'), l.length ? '<button class="btn btn-verde" type="button" id="copiar">Copiar todos os e-mails</button>' : '') +
      (l.length ? '<div class="adm-rolagem"><table class="adm-tabela"><thead><tr><th>E-mail</th><th>Inscrito em</th><th></th></tr></thead><tbody>' +
        l.map((n, i) => '<tr><td>' + esc(n.email) + '</td><td>' + data(n.criado_em) + '</td><td><button type="button" class="adm-x" data-del-news="' + i + '" aria-label="Remover ' + esc(n.email) + '">✕</button></td></tr>').join('') + '</tbody></table></div>'
        : '<div class="vazio"><span class="emoji">✉️</span><span>Ninguém se inscreveu ainda.</span></div>');
    const c = $('copiar');
    if (c) c.onclick = async () => {
      const txt = l.map((n) => n.email).join(', ');
      try { await navigator.clipboard.writeText(txt); toast('E-mails copiados ✓'); } catch (e) { abrirJanela('E-mails', '<textarea rows="8" style="width:100%">' + esc(txt) + '</textarea>', async () => {}); }
    };
    conteudo.onclick = async (e) => {
      const b = e.target.closest('[data-del-news]'); if (!b) return;
      const n = l[+b.dataset.delNews];
      if (!confirmar('Remover ' + n.email + ' da newsletter?')) return;
      const rr = await sb.from('newsletter').delete().eq('email', n.email);
      if (rr.error) toast(erro(rr.error), 'erro'); else telaNewsletter();
    };
  }

  // ---------------- VITRINE DO MERCADO LIVRE ----------------
  // Substitui o cadastro antigo de produtos (telaProdutos/telaProduto, que continuam acima e voltam com modoVitrine: false).
  // O cadastro começa pelo link do anúncio: a função "vitrine-ml" do Supabase lê os dados e preenche o formulário para revisar.
  const URL_VITRINE = K.config.supabaseUrl + '/functions/v1/vitrine-ml';
  async function chamarVitrine(corpo) {
    const s = await sb.auth.getSession(), tk = s.data.session && s.data.session.access_token;
    if (!tk) throw 'Sua sessão expirou. Entre de novo.';
    let r;
    try { r = await fetch(URL_VITRINE, { method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: 'Bearer ' + tk, apikey: K.config.supabaseKey }, body: JSON.stringify(corpo) }); }
    catch (e) { throw 'Não consegui falar com a função vitrine-ml do Supabase. Confira a internet.'; }
    const j = await r.json().catch(() => ({}));
    if (r.status === 404 && !j.erro) throw 'A função vitrine-ml ainda não foi publicada no Supabase.';
    if (!r.ok || j.ok === false) throw j.erro || ('Erro ' + r.status);
    return j;
  }
  function quandoTxt(d) { if (!d) return 'nunca'; const min = Math.round((Date.now() - new Date(d)) / 60000); return min < 1 ? 'agora' : min < 60 ? 'há ' + min + ' min' : min < 1440 ? 'há ' + Math.round(min / 60) + ' h' : data(d); }

  async function cartaoConexaoML(alvo) {
    const st = await sb.rpc('status_ml');
    if (st.error) { alvo.innerHTML = '<p class="aviso aviso-erro">' + esc(erro(st.error)) + ' (rode sql/vitrine-ml.sql no Supabase)</p>'; return; }
    const s = st.data || {}; let ult = null; try { ult = s.ultima_rodada ? JSON.parse(s.ultima_rodada) : null; } catch (e) {}
    alvo.innerHTML = '<section class="adm-cartao"><h2>Conexão com o Mercado Livre ' + (s.tem_chaves ? '<span class="adm-tag ouro">chaves cadastradas</span>' : '<span class="adm-tag erro">falta conectar</span>') + '</h2>' +
      (s.tem_chaves ? '<p class="adm-ajuda">App do Mercado Livre: <b>' + esc(s.client_id || '') + '</b>' + (s.autorizado ? ' · conta autorizada' : '') + '. ' +
          (ult ? 'Última atualização geral: ' + quandoTxt(ult.em) + ' (' + ult.atualizados + ' de ' + ult.total + ' atualizados' + (ult.falhas ? ', ' + ult.falhas + ' com erro' : '') + ').' : 'A atualização automática roda todo dia às 6h.') + '</p>'
        : '<p class="adm-ajuda">Para ler os anúncios pela API oficial, crie um app (grátis) em <a href="https://developers.mercadolivre.com.br/devcenter" target="_blank" rel="noopener">developers.mercadolivre.com.br › Minhas aplicações</a>, com a sua conta do Mercado Livre. ' +
          'No campo "URI de redirect", use <code>' + esc(URL_VITRINE) + '</code>. Depois copie o <b>Client ID</b> e a <b>Secret Key</b> para cá. Elas ficam guardadas só no servidor (ninguém consegue ler de volta).</p>') +
      '<div class="adm-linha-botoes"><button type="button" class="btn ' + (s.tem_chaves ? 'btn-linha' : 'btn-verde') + '" id="ml-chaves">' + (s.tem_chaves ? 'Trocar chaves' : 'Colar Client ID e Secret Key') + '</button>' +
      (s.tem_chaves ? '<button type="button" class="btn btn-linha" id="ml-testar">Testar conexão</button><button type="button" class="btn btn-linha" id="ml-autorizar">Autorizar minha conta</button>' : '') +
      '<span class="adm-msg" id="ml-msg"></span></div></section>';
    const m = $('ml-msg');
    $('ml-chaves').onclick = () => {
      abrirJanela('Chaves do app do Mercado Livre', '<div class="adm-grade">' + campo({ k: 'id', r: 'Client ID', obrig: true, largo: true }, '') + campo({ k: 'segredo', r: 'Secret Key', obrig: true, largo: true }, '') + '</div>', async (f) => {
        const id = f.querySelector('[data-k="id"]').value.trim(), seg = f.querySelector('[data-k="segredo"]').value.trim();
        const r = await sb.rpc('salvar_chaves_ml', { p_client_id: id, p_client_secret: seg }); if (r.error) throw r.error;
        toast('Chaves salvas ✓'); cartaoConexaoML(alvo);
      });
    };
    if ($('ml-testar')) $('ml-testar').onclick = async () => {
      m.className = 'adm-msg'; m.textContent = 'Testando...';
      try { const j = await chamarVitrine({ acao: 'testar' }); m.className = 'adm-msg ok'; m.textContent = j.api ? 'Conectado à API do Mercado Livre ✓' : 'Sem API: vai tentar ler as páginas.'; }
      catch (e) { m.className = 'adm-msg erro'; m.textContent = String(e) + ' Se o Mercado Livre pedir autorização, clique em "Autorizar minha conta".'; }
    };
    if ($('ml-autorizar')) $('ml-autorizar').onclick = async () => {
      try { const j = await chamarVitrine({ acao: 'link_autorizacao' }); window.open(j.url, '_blank', 'noopener'); m.className = 'adm-msg'; m.textContent = 'Abri o Mercado Livre em outra aba. Depois de autorizar, clique em "Testar conexão".'; }
      catch (e) { m.className = 'adm-msg erro'; m.textContent = String(e); }
    };
  }

  const filtroVit = { q: '', sit: '' };
  async function telaVitrine() {
    const conteudo = principal.firstElementChild || principal;
    carregando();
    const r = await sb.from('vitrine_ml').select('id,slug,nome,link,permalink,preco_centavos,preco_original_centavos,desconto_pct,fotos,ativo,destaque,auto_atualizar,ml_status,atualizado_ml_em,ultimo_erro,exemplo,categoria_id').order('criado_em', { ascending: false });
    if (r.error) return falha(r.error, conteudo);
    const todos = r.data;
    conteudo.innerHTML = cabecalho('Vitrine · Mercado Livre', 'Cada produto é um anúncio do Mercado Livre. A compra acontece lá. Os preços e dados são atualizados todo dia às 6h, ou na hora pelos botões abaixo.',
      '<div style="display:flex;gap:8px;flex-wrap:wrap"><button type="button" class="btn btn-linha" id="atualizar-todos">↻ Atualizar todos</button><a class="btn btn-verde" href="#vitrine-item/novo">+ Cadastrar pelo link</a></div>') +
      '<div id="ml-conexao"><p class="carregando">Carregando...</p></div>' +
      '<div class="adm-filtros"><input type="search" id="v-q" placeholder="Buscar por nome..." value="' + esc(filtroVit.q) + '">' +
      '<select id="v-sit"><option value="">Todos</option><option value="ativo">Só os que aparecem na vitrine</option><option value="inativo">Só os escondidos</option><option value="erro">Com erro na última atualização</option><option value="exemplo">Produtos de teste</option></select></div>' +
      '<p class="adm-cinza" id="v-cont"></p><div id="lista-vit"></div>';
    $('v-sit').value = filtroVit.sit;
    cartaoConexaoML($('ml-conexao'));
    function desenhar() {
      const q = slugify(filtroVit.q).replace(/-/g, ' ');
      const lista = todos.filter((p) => {
        if (q && slugify(p.nome).replace(/-/g, ' ').indexOf(q) < 0) return false;
        if (filtroVit.sit === 'ativo' && !p.ativo) return false;
        if (filtroVit.sit === 'inativo' && p.ativo) return false;
        if (filtroVit.sit === 'erro' && !p.ultimo_erro) return false;
        if (filtroVit.sit === 'exemplo' && !p.exemplo) return false;
        return true;
      });
      $('v-cont').textContent = lista.length + (lista.length === 1 ? ' produto' : ' produtos');
      $('lista-vit').innerHTML = lista.length ? '<div class="adm-rolagem"><table class="adm-tabela adm-prods"><thead><tr><th></th><th>Produto</th><th>Preço</th><th>Atualizado</th><th>Na vitrine</th><th>Destaque</th><th></th></tr></thead><tbody>' +
        lista.map((p) => '<tr data-linha="' + p.id + '"><td><a href="#vitrine-item/' + p.id + '" class="adm-mini">' + (p.fotos && p.fotos[0] ? '<img src="' + esc(p.fotos[0]) + '" alt="" referrerpolicy="no-referrer" style="object-fit:contain;background:#fff">' : '🛒') + '</a></td>' +
          '<td><a href="#vitrine-item/' + p.id + '" class="adm-nome">' + esc(p.nome) + '</a>' + (p.exemplo ? ' <span class="adm-tag">teste</span>' : '') + (p.ml_status && p.ml_status !== 'active' ? ' <span class="adm-tag erro">' + esc(p.ml_status === 'paused' ? 'pausado no ML' : p.ml_status) + '</span>' : '') +
            (p.categoria_id ? '<br><small class="adm-cinza">' + esc(nomeCat(p.categoria_id)) + '</small>' : '') + '</td>' +
          '<td style="white-space:nowrap">' + (p.preco_centavos == null ? '<span class="adm-cinza">—</span>' : (p.preco_original_centavos != null ? '<s class="adm-cinza">' + K.reais(p.preco_original_centavos) + '</s><br>' : '') + '<strong>' + K.reais(p.preco_centavos) + '</strong>' + (p.desconto_pct ? ' <span class="adm-tag ouro">' + p.desconto_pct + '% OFF</span>' : '')) + '</td>' +
          '<td style="min-width:130px">' + (p.ultimo_erro ? '<span class="adm-tag erro" title="' + esc(p.ultimo_erro) + '">erro</span> <small class="adm-cinza">' + esc(p.ultimo_erro.slice(0, 90)) + '</small>' : '<small>' + esc(quandoTxt(p.atualizado_ml_em)) + '</small>') + (p.auto_atualizar ? '' : '<br><small class="adm-cinza">fora da diária</small>') + '</td>' +
          '<td><label class="adm-chave"><input type="checkbox" data-campo="ativo" data-id="' + p.id + '"' + (p.ativo ? ' checked' : '') + '><span class="sr">Mostrar na vitrine</span></label></td>' +
          '<td><label class="adm-chave"><input type="checkbox" data-campo="destaque" data-id="' + p.id + '"' + (p.destaque ? ' checked' : '') + '><span class="sr">Destaque</span></label></td>' +
          '<td class="adm-acoes" style="white-space:nowrap"><button type="button" class="btn btn-linha adm-btn-p" data-atualizar="' + p.id + '">↻ Atualizar</button> <a class="btn btn-linha adm-btn-p" href="' + esc(p.permalink || p.link) + '" target="_blank" rel="noopener">ML ↗</a></td></tr>').join('') +
        '</tbody></table></div>' : '<div class="vazio"><span class="emoji">🛒</span><span>Nenhum produto na vitrine ainda. Clique em "Cadastrar pelo link".</span></div>';
    }
    $('v-q').oninput = (e) => { filtroVit.q = e.target.value; desenhar(); };
    $('v-sit').onchange = (e) => { filtroVit.sit = e.target.value; desenhar(); };
    $('lista-vit').addEventListener('change', async (e) => {
      const c = e.target.closest('[data-campo]'); if (!c) return;
      const p = todos.find((x) => String(x.id) === c.dataset.id), up = {}; up[c.dataset.campo] = c.checked;
      const rr = await sb.from('vitrine_ml').update(up).eq('id', p.id);
      if (rr.error) { c.checked = !c.checked; toast(erro(rr.error), 'erro'); return; }
      p[c.dataset.campo] = c.checked;
      toast(c.dataset.campo === 'ativo' ? (c.checked ? 'Produto aparece na vitrine' : 'Produto escondido da vitrine') : (c.checked ? 'Produto em destaque na página inicial' : 'Produto saiu dos destaques'));
    });
    $('lista-vit').addEventListener('click', async (e) => {
      const b = e.target.closest('[data-atualizar]'); if (!b) return;
      b.disabled = true; b.textContent = 'Atualizando...';
      try {
        const j = await chamarVitrine({ acao: 'atualizar', id: Number(b.dataset.atualizar) });
        const i = todos.findIndex((x) => x.id === j.produto.id); if (i > -1) todos[i] = Object.assign(todos[i], j.produto);
        toast('Atualizado com o Mercado Livre ✓'); desenhar();
      } catch (er) {
        const p = todos.find((x) => String(x.id) === b.dataset.atualizar); if (p) p.ultimo_erro = String(er);
        toast(String(er), 'erro'); desenhar();
      }
    });
    $('atualizar-todos').onclick = async (e) => {
      const b = e.currentTarget; b.disabled = true; b.textContent = 'Atualizando ' + todos.length + ' produtos...';
      try {
        const j = await chamarVitrine({ acao: 'atualizar_todos' });
        toast(j.atualizados + ' de ' + j.total + ' atualizados' + (j.falhas.length ? ' · ' + j.falhas.length + ' com erro' : '') + (j.faltaram ? ' · ' + j.faltaram + ' ficaram para a próxima' : ''), j.falhas.length ? 'erro' : 'ok');
      } catch (er) { toast(String(er), 'erro'); }
      telaVitrine();
    };
    desenhar();
  }

  // atributos e variações em texto simples para revisar: "Nome: valor" (uma por linha) e "Cor: Preto | Branco"
  const atrsParaTexto = (l) => (l || []).map((a) => a.nome + ': ' + a.valor).join('\n');
  const textoParaAtrs = (t) => String(t || '').split('\n').map((l) => { const i = l.indexOf(':'); return i > 0 ? { nome: l.slice(0, i).trim(), valor: l.slice(i + 1).trim() } : null; }).filter((a) => a && a.nome && a.valor);
  const varsParaTexto = (l) => (l || []).map((g) => g.nome + ': ' + (g.opcoes || []).map((o) => o.valor).join(' | ')).join('\n');
  function textoParaVars(t, originais) {
    return String(t || '').split('\n').map((l) => {
      const i = l.indexOf(':'); if (i <= 0) return null;
      const nome = l.slice(0, i).trim(), orig = (originais || []).find((g) => g.nome === nome);
      const opcoes = l.slice(i + 1).split('|').map((v) => v.trim()).filter(Boolean).map((v) => (orig && orig.opcoes.find((o) => o.valor === v)) || { valor: v });
      return nome && opcoes.length ? { nome: nome, opcoes: opcoes } : null;
    }).filter(Boolean);
  }

  async function telaVitrineItem(id) {
    const conteudo = principal.firstElementChild || principal;
    carregando();
    const novo = id === 'novo';
    const rp = novo ? { data: null } : await sb.from('vitrine_ml').select('*').eq('id', id).maybeSingle();
    if (rp.error) return falha(rp.error, conteudo);
    if (!novo && !rp.data) { conteudo.innerHTML = '<p class="aviso aviso-erro">Produto não encontrado.</p><p><a href="#vitrine">← Voltar</a></p>'; return; }
    let p = rp.data || { ativo: true, destaque: false, auto_atualizar: true, fotos: [], atributos: [], variacoes: [] };
    let lidos = null; // dados que vieram do ML (campos que não aparecem no formulário)

    const campos = [
      { k: 'nome', r: 'Nome', obrig: true, largo: true },
      { k: 'slug', r: 'Endereço na vitrine (slug)', tipo: 'slug', de: 'nome', obrig: true, ajuda: 'Vai no link: produto.html?p=...' },
      { k: 'categoria_id', r: 'Categoria na vitrine', tipo: 'ref', vazio: '— Sem categoria —', opcoesFn: () => listaCats() },
      { k: 'preco_centavos', r: 'Preço (atual)', tipo: 'dinheiro' },
      { k: 'preco_original_centavos', r: 'Preço original (riscado)', tipo: 'dinheiro', ajuda: 'Vazio = sem desconto.' },
      { k: 'descricao', r: 'Descrição', tipo: 'area', largo: true, linhas: 8 },
      { k: 'ativo', r: 'Mostrar na vitrine', tipo: 'bool' },
      { k: 'destaque', r: 'Destacar na página inicial', tipo: 'bool' },
      { k: 'auto_atualizar', r: 'Atualizar todo dia com o Mercado Livre', tipo: 'bool', ajuda: 'Preço, desconto, fotos, estoque e características.' },
      { k: 'travar_textos', r: 'Manter o meu nome e a minha descrição', tipo: 'bool', ajuda: 'Marque se você reescreveu o nome ou a descrição no estilo Cosmoria: a atualização não troca esses dois.' },
      { k: 'exemplo', r: 'Produto de teste', tipo: 'bool' }
    ];
    const linkAtual = p.link || '';
    conteudo.innerHTML = '<p class="adm-volta"><a href="#vitrine">← Vitrine</a></p>' +
      cabecalho(novo ? 'Cadastrar pelo link do Mercado Livre' : p.nome, novo ? 'Cole o link do anúncio. O site busca nome, preço, fotos, descrição, características e variações. Você revisa e salva.' :
        (p.ativo ? 'Aparece na vitrine' : 'Escondido da vitrine') + ' · atualizado ' + quandoTxt(p.atualizado_ml_em) + (p.ultimo_erro ? ' · último erro: ' + esc(p.ultimo_erro) : ''),
        novo ? '' : '<div style="display:flex;gap:8px;flex-wrap:wrap"><a class="btn btn-linha" target="_blank" rel="noopener" href="produto.html?p=' + encodeURIComponent(p.slug) + '">Ver na vitrine ↗</a><a class="btn btn-linha" target="_blank" rel="noopener" href="' + esc(p.permalink || p.link) + '">Ver no ML ↗</a></div>') +
      '<section class="adm-cartao"><h2>1. Link do anúncio</h2><div class="adm-grade">' +
        campo({ k: 'link', r: 'Link do Mercado Livre', obrig: true, largo: true, ajuda: 'Pode colar o link inteiro, do jeito que copiou do navegador (com /p/MLB... e wid=MLB...).' }, linkAtual) + '</div>' +
        '<div class="adm-linha-botoes"><button type="button" class="btn btn-verde" id="buscar-ml">' + (novo ? 'Buscar dados do anúncio' : '↻ Buscar de novo no Mercado Livre') + '</button><span class="adm-msg" id="buscar-msg"></span></div></section>' +
      '<form id="form-vit" class="adm-prod" novalidate' + (novo ? ' hidden' : '') + '>' +
        '<section class="adm-cartao"><h2>2. Confira as informações</h2><div class="adm-grade" id="vit-campos"></div></section>' +
        '<section class="adm-cartao"><h2>Fotos</h2><p class="adm-ajuda">Vêm do anúncio. A primeira é a capa. Um link por linha (pode tirar ou mudar a ordem).</p><div class="adm-fotos" id="vit-fotos"></div><div class="campo largo"><label for="vit-fotos-txt">Links das fotos</label><textarea id="vit-fotos-txt" rows="4"></textarea></div></section>' +
        '<section class="adm-cartao"><h2>Características</h2><p class="adm-ajuda">Uma por linha, no formato <b>Nome: valor</b> (ex.: Peso: 1,2 kg).</p><div class="campo largo"><textarea id="vit-atrs" rows="8"></textarea></div></section>' +
        '<section class="adm-cartao"><h2>Variações</h2><p class="adm-ajuda">Uma por linha, no formato <b>Nome: opção 1 | opção 2</b> (ex.: Voltagem: 127V | 220V). Na vitrine aparecem como botões; a escolha final é feita no Mercado Livre.</p><div class="campo largo"><textarea id="vit-vars" rows="3"></textarea></div></section>' +
        '<div class="adm-barra-salvar"><button type="submit" class="btn btn-verde" id="salvar-vit">Salvar na vitrine</button><span class="adm-msg" id="vit-msg"></span><span style="flex:1"></span>' +
          (novo ? '' : '<button type="button" class="btn adm-btn-perigo" id="apagar-vit">Tirar da vitrine (apagar)</button>') + '</div></form>';
    const form = $('form-vit');

    function preencher(d) {
      $('vit-campos').innerHTML = campos.map((f) => campo(f, d[f.k])).join('');
      ligarCampos(form, novo);
      $('vit-fotos-txt').value = (d.fotos || []).join('\n');
      $('vit-atrs').value = atrsParaTexto(d.atributos);
      $('vit-vars').value = varsParaTexto(d.variacoes);
      desenharFotos();
    }
    function desenharFotos() {
      const l = $('vit-fotos-txt').value.split('\n').map((x) => x.trim()).filter(Boolean);
      $('vit-fotos').innerHTML = l.length ? l.map((u, i) => '<figure class="adm-foto"><img src="' + esc(u) + '" alt="Foto ' + (i + 1) + '" referrerpolicy="no-referrer" style="object-fit:contain;background:#fff">' + (i === 0 ? '<span class="adm-tag ouro">capa</span>' : '') + '</figure>').join('') : '<div class="adm-sem-foto"><span>🛒</span><small>Sem fotos.</small></div>';
    }
    $('vit-fotos-txt') && form.addEventListener('input', (e) => { if (e.target.id === 'vit-fotos-txt') desenharFotos(); });
    if (!novo) preencher(p);

    $('buscar-ml').onclick = async () => {
      const link = conteudo.querySelector('[data-k="link"]').value.trim(), m = $('buscar-msg'), b = $('buscar-ml');
      if (!/mercadoli(vre|bre)|MLB/i.test(link)) { m.className = 'adm-msg erro'; m.textContent = 'Cole um link de anúncio do Mercado Livre.'; return; }
      b.disabled = true; m.className = 'adm-msg'; m.textContent = 'Lendo o anúncio no Mercado Livre...';
      try {
        const j = await chamarVitrine({ acao: 'ler', link: link });
        if (j.ja_cadastrado && (novo || j.ja_cadastrado.id !== p.id)) { m.className = 'adm-msg erro'; m.innerHTML = 'Esse anúncio já está na vitrine: <a href="#vitrine-item/' + j.ja_cadastrado.id + '">' + esc(j.ja_cadastrado.nome) + '</a>.'; b.disabled = false; return; }
        lidos = j.dados;
        const d = Object.assign({}, p, lidos);
        if (!novo && p.travar_textos) { d.nome = p.nome; d.descricao = p.descricao; }
        if (novo) d.slug = slugify(lidos.nome).slice(0, 70) + '-' + String(lidos.ml_item_id || lidos.ml_produto_id || '').replace(/\D/g, '').slice(-5);
        preencher(d); form.hidden = false;
        m.className = 'adm-msg ok'; m.textContent = 'Dados lidos ' + (lidos.fonte === 'api' ? 'pela API do Mercado Livre' : 'da página do anúncio') + ' ✓ Confira abaixo e clique em "Salvar na vitrine".';
        form.scrollIntoView({ behavior: 'smooth', block: 'start' });
      } catch (e) {
        m.className = 'adm-msg erro'; m.textContent = String(e);
        if (novo) { m.textContent += ' Você também pode preencher à mão.'; preencher(Object.assign({}, p, { link: link })); form.hidden = false; }
      }
      b.disabled = false;
    };

    const msg = $('vit-msg');
    form.onsubmit = async (ev) => {
      ev.preventDefault(); msg.className = 'adm-msg'; msg.textContent = 'Salvando...'; $('salvar-vit').disabled = true;
      try {
        const dados = lerCampos(form, campos);
        dados.link = conteudo.querySelector('[data-k="link"]').value.trim();
        if (!dados.link) throw 'Cole o link do anúncio.';
        dados.slug = slugify(dados.slug || dados.nome); if (!dados.slug) throw 'Preencha o endereço (slug).';
        if (dados.preco_original_centavos != null && (dados.preco_centavos == null || dados.preco_original_centavos <= dados.preco_centavos)) dados.preco_original_centavos = null;
        dados.desconto_pct = dados.preco_original_centavos ? Math.round((1 - dados.preco_centavos / dados.preco_original_centavos) * 100) : null;
        dados.fotos = $('vit-fotos-txt').value.split('\n').map((x) => x.trim()).filter((x) => /^https:\/\//.test(x));
        dados.atributos = textoParaAtrs($('vit-atrs').value);
        dados.variacoes = textoParaVars($('vit-vars').value, (lidos && lidos.variacoes) || p.variacoes);
        if (lidos) {
          ['ml_item_id', 'ml_produto_id', 'permalink', 'condicao', 'estoque', 'vendidos', 'frete_gratis', 'ml_status', 'fonte'].forEach((k) => { dados[k] = lidos[k]; });
          dados.atualizado_ml_em = new Date().toISOString(); dados.ultimo_erro = null;
        } else if (novo) dados.fonte = 'manual';
        const r = novo ? await sb.from('vitrine_ml').insert(dados).select('id').single() : await sb.from('vitrine_ml').update(dados).eq('id', p.id).select('id').single();
        if (r.error) throw r.error;
        toast('Salvo na vitrine ✓');
        if (novo) location.hash = '#vitrine-item/' + r.data.id; else telaVitrineItem(p.id);
      } catch (e) { msg.className = 'adm-msg erro'; msg.textContent = typeof e === 'string' ? e : erro(e); }
      if ($('salvar-vit')) $('salvar-vit').disabled = false;
    };
    const ap = $('apagar-vit');
    if (ap) ap.onclick = async () => {
      if (!confirmar('Tirar "' + p.nome + '" da vitrine e apagar o cadastro? O anúncio no Mercado Livre não muda.\n\nDica: para só esconder, desmarque "Mostrar na vitrine".')) return;
      const r = await sb.from('vitrine_ml').delete().eq('id', p.id);
      if (r.error) { msg.className = 'adm-msg erro'; msg.textContent = erro(r.error); return; }
      toast('Produto apagado da vitrine'); location.hash = '#vitrine';
    };
  }

  // ---------------- INÍCIO ----------------
  async function telaInicioVitrine(conta) {
    const conteudo = principal.firstElementChild || principal;
    const [ativos, escondidos, comErro, artes] = await Promise.all([
      conta(sb.from('vitrine_ml').select('id', { count: 'exact', head: true }).eq('ativo', true)),
      conta(sb.from('vitrine_ml').select('id', { count: 'exact', head: true }).eq('ativo', false)),
      conta(sb.from('vitrine_ml').select('id', { count: 'exact', head: true }).not('ultimo_erro', 'is', null)),
      conta(sb.from('personalizacoes').select('id', { count: 'exact', head: true }).eq('status', 'no_carrinho'))]);
    const card = (n, t, href) => '<a class="adm-num" href="' + href + '"><strong>' + n + '</strong><span>' + t + '</span></a>';
    conteudo.innerHTML = cabecalho('Olá! O que vamos mudar hoje?', 'O site é uma vitrine: cada produto leva para o anúncio no Mercado Livre, onde a compra acontece.') +
      '<div class="adm-nums">' + card(ativos, 'produtos na vitrine', '#vitrine') + card(escondidos, 'produtos escondidos', '#vitrine') + card(comErro, 'com erro na atualização', '#vitrine') + card(artes, 'artes personalizadas novas', 'personalizacoes.html') + '</div>' +
      '<div class="adm-atalhos">' +
        '<a href="#vitrine-item/novo"><b>+ Cadastrar pelo link</b><span>Cole o link do anúncio do Mercado Livre</span></a>' +
        '<a href="#vitrine"><b>↻ Atualizar preços</b><span>Um produto ou todos de uma vez</span></a>' +
        '<a href="#textos"><b>Mudar textos do site</b><span>Página inicial, rodapé, contatos</span></a>' +
        '<a href="#categorias"><b>Categorias</b><span>Organização do menu e da vitrine</span></a>' +
        '<a href="#usuarios"><b>Perfis dos clientes</b><span>Ver, editar e dar acesso de administrador</span></a></div>';
  }

  async function telaInicio() {
    const conteudo = principal.firstElementChild || principal; // área desta tela
    carregando();
    const conta = (q) => q.then((r) => (r.error ? '—' : r.count));
    if (K.config.modoVitrine) return telaInicioVitrine(conta);
    const [ativos, escondidos, semEst, artes, pedidos] = await Promise.all([
      conta(sb.from('produtos').select('id', { count: 'exact', head: true }).eq('ativo', true)),
      conta(sb.from('produtos').select('id', { count: 'exact', head: true }).eq('ativo', false)),
      conta(sb.from('variantes').select('id', { count: 'exact', head: true }).lte('estoque', 0)),
      conta(sb.from('personalizacoes').select('id', { count: 'exact', head: true }).eq('status', 'no_carrinho')),
      conta(sb.from('pedidos').select('id', { count: 'exact', head: true }).in('status', ['aguardando_pagamento', 'pago', 'em_separacao']))]);
    const card = (n, t, href) => '<a class="adm-num" href="' + href + '"><strong>' + n + '</strong><span>' + t + '</span></a>';
    conteudo.innerHTML = cabecalho('Olá! O que vamos mudar hoje?', 'Tudo o que você salva aqui muda o site na hora. Só contas de administrador conseguem abrir esta página e gravar alterações.') +
      '<div class="adm-nums">' + card(ativos, 'produtos na loja', '#produtos') + card(escondidos, 'produtos escondidos', '#produtos') + card(semEst, 'opções sem estoque', '#produtos') +
        card(artes, 'artes personalizadas novas', 'personalizacoes.html') + card(pedidos, 'pedidos em andamento', '#pedidos') + '</div>' +
      '<div class="adm-atalhos">' +
        '<a href="#produto/novo"><b>+ Cadastrar produto</b><span>Nome, preço, fotos, opções e estoque</span></a>' +
        '<a href="#textos"><b>Mudar textos do site</b><span>Página inicial, rodapé, contatos, trocas</span></a>' +
        '<a href="#categorias"><b>Categorias e coleções</b><span>Organização do menu e da loja</span></a>' +
        '<a href="#frete"><b>Tabelas de frete</b><span>Motoboy, PAC e SEDEX</span></a>' +
        '<a href="#personalizacao"><b>Preço dos personalizados</b><span>Valor por cm² e áreas de impressão</span></a>' +
        '<a href="#usuarios"><b>Perfis dos clientes</b><span>Ver, editar e dar acesso de administrador</span></a></div>';
  }

  // ---------------- rotas ----------------
  const ROTAS = {
    inicio: telaInicio,
    vitrine: telaVitrine,
    'vitrine-item': (id) => telaVitrineItem(id),
    produtos: telaProdutos,
    produto: (id) => telaProduto(id),
    categorias: () => telaBlocos('Categorias', '', [DEF.categorias], ['tabela']),
    colecoes: () => telaBlocos('Coleções', '', [DEF.colecoes], ['tabela']),
    textos: telaTextos,
    loja: () => telaBlocos('Parcelas e Pix', '', [DEF.loja], ['unico']),
    frete: () => telaBlocos('Frete', 'Regras da entrega por motoboy e tabela dos Correios.', [DEF.freteConfig, DEF.freteEstados], ['unico', 'tabela']),
    personalizacao: () => telaBlocos('Preço dos personalizados', 'Valores usados no editor de produtos personalizados.', [DEF.persConfig, DEF.moldes], ['unico', 'tabela']),
    pedidos: telaPedidos,
    usuarios: telaUsuarios,
    newsletter: telaNewsletter
  };
  function rotear() {
    const h = (location.hash || '#inicio').slice(1).split('/'), nome = ROTAS[h[0]] ? h[0] : 'inicio';
    $('btn-perfis').toggleAttribute('aria-current', nome === 'usuarios');
    document.querySelectorAll('#menu [data-r]').forEach((a) => { if ((a.dataset.r === nome) || (nome === 'produto' && a.dataset.r === 'produtos') || (nome === 'vitrine-item' && a.dataset.r === 'vitrine')) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current'); });
    // cada tela desenha numa área nova; se a pessoa trocar de tela antes de terminar de carregar, a tela antiga não atrapalha
    const area = document.createElement('div'); principal.replaceChildren(area); conteudo = area;
    window.scrollTo(0, 0);
    Promise.resolve().then(() => ROTAS[nome](h[1])).catch((e) => { if (conteudo === area) falha(e); });
  }

  // ---------------- entrada: só administradores ----------------
  document.addEventListener('DOMContentLoaded', async () => {
    $('sair').onclick = async () => { await sb.auth.signOut(); location.replace('index.html'); };
    const u = await K.usuarioAtual();
    if (!u) { location.replace('entrar.html?voltar=admin.html'); return; }
    meuId = u.id;
    $('quem').textContent = u.email;
    const a = await sb.rpc('eh_admin');
    if (a.error) {
      conteudo.innerHTML = '<div class="adm-cartao"><h2>Falta preparar o banco</h2><p>O painel ainda não foi ativado no Supabase. Abra o Supabase › SQL Editor, cole o conteúdo do arquivo <b>sql/admin.sql</b> e clique em Run.</p><p class="adm-cinza">' + esc(erro(a.error)) + '</p></div>';
      return;
    }
    if (a.data !== true) {
      conteudo.innerHTML = '<div class="adm-cartao"><h2>🔒 Esta conta não é administradora</h2><p>Você entrou como <b>' + esc(u.email) + '</b>, que é uma conta de cliente.</p>' +
        '<p>Peça para um administrador liberar seu acesso em "Usuários e administradores". Se você é a dona da loja e ainda não existe nenhum administrador, rode no Supabase › SQL Editor:</p>' +
        '<pre class="adm-codigo">update "Cosmoria".perfis set papel = \'admin\' where email = \'' + esc(u.email) + '\';</pre><p><a class="btn btn-verde" href="index.html">Voltar para a loja</a></p></div>';
      return;
    }
    // modo vitrine: esconde do menu o que foi desativado (cadastro antigo, coleções, frete, parcelas/Pix). As telas continuam no código.
    if (K.config.modoVitrine) document.querySelectorAll('#menu [data-loja-antiga]').forEach((a) => { a.hidden = true; });
    else document.querySelectorAll('#menu [data-vitrine]').forEach((a) => { a.hidden = true; });
    $('menu').hidden = false; $('btn-perfis').hidden = false;
    await carregarApoio();
    window.addEventListener('hashchange', rotear);
    rotear();
  });
})();
