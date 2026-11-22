// Agenda reutilizável: lê eventos públicos do Supabase (somente leitura) e monta calendário + lista.
window.Agenda = (function () {
  const LOCAIS = { gruta: 'Gruta', restaurante: 'Restaurante', mercado: 'Cosmória', labirinto: 'Labirinto de Hécate', espaco_ritual: 'Espaço de rituais', casa_bruxa: 'Casa da Bruxa' };
  const ICONES = {
    curso:  { nome: 'Curso / oficina', cor: '#8a6bbf', svg: '<path d="M3 6c3-1.5 6-1.5 9 0v13c-3-1.5-6-1.5-9 0zM21 6c-3-1.5-6-1.5-9 0v13c3-1.5 6-1.5 9 0z"/>' },
    ritual: { nome: 'Ritual / cerimônia', cor: '#3f7f8c', svg: '<path d="M15 3a9 9 0 1 0 6 15A7 7 0 0 1 15 3z"/>' },
    sabor:  { nome: 'Gastronomia', cor: '#c07a3a', svg: '<path d="M7 3v8a3 3 0 0 0 3 3v7M10 3v6M4 3v6a3 3 0 0 0 3 3M17 3c-2 2-2 7 0 9v9"/>' },
    loja:   { nome: 'Cosmória', cor: '#4f8a52', svg: '<path d="M12 2l3 7 7 3-7 3-3 7-3-7-7-3 7-3z"/>' },
    evento: { nome: 'Evento', cor: '#b0577a', svg: '<path d="M4 20l5-14 9 9zM14 4l1 2M19 5l-2 2M20 10l-2 0M12 7l1-1"/>' }
  };
  function categoria(e) {
    const t = `${e.titulo} ${e.descricao || ''}`.toLowerCase(), l = (e.local || '').toLowerCase();
    if (/ritual|cerim|lua|sab[áa]|celebra/.test(t)) return 'ritual';
    if (/aula|curso|oficina|workshop|turma/.test(t)) return 'curso';
    if (l === 'restaurante' || /degusta|jantar|almo[çc]o|vinho/.test(t)) return 'sabor';
    if (l === 'mercado' || /cosm[óo]ria|cristais|loja/.test(t)) return 'loja';
    return 'evento';
  }
  const icone = (c, cls = '') => `<span class="ag-icone ${cls}" style="--c:${ICONES[c].cor}" title="${ICONES[c].nome}"><svg viewBox="0 0 24 24"><g fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${ICONES[c].svg}</g></svg></span>`;
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const chaveDia = d => `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
  const fmtData = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit', year: 'numeric' });
  const fmtHora = new Intl.DateTimeFormat('pt-BR', { hour: '2-digit', minute: '2-digit' });
  const fmtMes = new Intl.DateTimeFormat('pt-BR', { month: 'long', year: 'numeric' });
  const hoje = () => { const d = new Date(); d.setHours(0, 0, 0, 0); return d; };

  let cache;
  const normaliza = t => String(t || '').toLowerCase().replace(/\(.*?\)/g, '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim();
  const cabecalhos = () => ({ apikey: SUPABASE_CHAVE, Authorization: `Bearer ${SUPABASE_CHAVE}` });

  // Vagas e valor vêm da tabela produtos (estoque), ligados pelo produto_id do evento ou pelo nome.
  async function carregarProdutos() {
    const r = await fetch(`${SUPABASE_URL}/rest/v1/produtos?select=id,nome,quantidade,preco&publico=is.true`, { headers: cabecalhos() });
    if (!r.ok) return [];
    return r.json();
  }
  function aplicarProdutos(eventos, produtos) {
    const porId = {}, porNome = {};
    produtos.forEach(p => { porId[p.id] = p; porNome[normaliza(p.nome)] = p; });
    eventos.forEach(e => {
      const p = (e.produto_id && porId[e.produto_id]) || porNome[normaliza(e.titulo)];
      e.vagas = p ? Math.max(0, Number(p.quantidade) || 0) : null;
      e.preco = p && p.preco != null ? Number(p.preco) : null;
    });
    return eventos;
  }
  function carregar() {
    if (!cache) cache = (async () => {
      const url = `${SUPABASE_URL}/rest/v1/agenda_eventos?select=id,titulo,descricao,inicio,fim,local,produto_id&tipo=eq.Evento&publico=is.true&order=inicio.asc&limit=500`;
      const [r, produtos] = await Promise.all([fetch(url, { headers: cabecalhos() }), carregarProdutos().catch(() => [])]);
      if (!r.ok) throw new Error(r.status);
      const eventos = (await r.json()).map(e => ({ ...e, i: new Date(e.inicio), f: e.fim ? new Date(e.fim) : null, cat: categoria(e) }));
      return aplicarProdutos(eventos, produtos);
    })();
    return cache;
  }
  // Atualiza vagas e valor em tempo real (sem recarregar a agenda)
  async function atualizarVagas() {
    const eventos = await carregar();
    aplicarProdutos(eventos, await carregarProdutos());
    document.querySelectorAll('.evento[data-id]').forEach(card => {
      const e = eventos.find(x => String(x.id) === card.dataset.id);
      const alvo = card.querySelector('.evento-vagas');
      if (e && alvo) alvo.outerHTML = vagasHTML(e);
    });
    return eventos;
  }
  const fmtPreco = new Intl.NumberFormat('pt-BR', { style: 'currency', currency: 'BRL' });
  function vagasHTML(e) {
    if (e.vagas == null && e.preco == null) return '<div class="evento-vagas vazio"></div>';
    const v = e.vagas == null ? '' : e.vagas === 0
      ? '<span class="vagas esgotado">✦ Vagas esgotadas</span>'
      : `<span class="vagas${e.vagas <= 3 ? ' poucas' : ''}">✦ ${e.vagas} ${e.vagas === 1 ? 'vaga aberta' : 'vagas abertas'}</span>`;
    const p = e.preco == null ? '' : `<span class="valor">${e.preco === 0 ? 'Gratuito' : fmtPreco.format(e.preco)}</span>`;
    return `<div class="evento-vagas">${v}${p}</div>`;
  }

  // Calendário mensal genérico
  function calendario(el, { eventos = [], aoClicar, habilitado, legenda = true } = {}) {
    el.classList.add('calendario');
    el.innerHTML = `<div class="cal-topo"><button type="button" class="cal-nav" data-d="-1" aria-label="Mês anterior">‹</button><h3></h3><button type="button" class="cal-nav" data-d="1" aria-label="Próximo mês">›</button></div>
      <div class="cal-semana"><span>Dom</span><span>Seg</span><span>Ter</span><span>Qua</span><span>Qui</span><span>Sex</span><span>Sáb</span></div>
      <div class="cal-dias"></div>${legenda ? '<div class="cal-legenda"></div>' : ''}`;
    const porDia = {};
    eventos.forEach(e => (porDia[chaveDia(e.i)] ||= []).push(e));
    const agora = new Date();
    let mes = new Date(agora.getFullYear(), agora.getMonth(), 1), sel = null;
    const dias = el.querySelector('.cal-dias');
    const pode = habilitado || (d => (porDia[chaveDia(d)] || []).length > 0);
    function desenhar() {
      const t = fmtMes.format(mes);
      el.querySelector('h3').textContent = t[0].toUpperCase() + t.slice(1);
      const total = new Date(mes.getFullYear(), mes.getMonth() + 1, 0).getDate();
      let html = '<span></span>'.repeat(mes.getDay());
      for (let d = 1; d <= total; d++) {
        const data = new Date(mes.getFullYear(), mes.getMonth(), d), k = chaveDia(data), evs = porDia[k] || [];
        const cont = {}; evs.forEach(e => cont[e.cat] = (cont[e.cat] || 0) + 1);
        const ic = Object.entries(cont).map(([c, n]) => `<span class="cal-mini">${icone(c)}${n > 1 ? `<b>${n}</b>` : ''}</span>`).join('');
        const ok = pode(data);
        const cls = ['cal-dia', k === chaveDia(agora) && 'hoje', ok && 'tem', k === sel && 'sel'].filter(Boolean).join(' ');
        html += `<button type="button" class="${cls}" data-k="${k}" data-t="${data.getTime()}" ${ok ? '' : 'disabled'}><span class="num">${d}</span><span class="cal-icones">${ic}</span></button>`;
      }
      dias.innerHTML = html;
    }
    dias.addEventListener('click', e => {
      const b = e.target.closest('.cal-dia.tem'); if (!b) return;
      sel = sel === b.dataset.k ? null : b.dataset.k; desenhar();
      aoClicar && aoClicar(sel ? new Date(+b.dataset.t) : null, sel ? porDia[sel] || [] : null);
    });
    el.querySelectorAll('.cal-nav').forEach(b => b.onclick = () => { mes = new Date(mes.getFullYear(), mes.getMonth() + +b.dataset.d, 1); desenhar(); });
    if (legenda) {
      const cats = [...new Set(eventos.map(e => e.cat))];
      el.querySelector('.cal-legenda').innerHTML = (cats.length ? cats : Object.keys(ICONES)).map(c => `<span>${icone(c)} ${ICONES[c].nome}</span>`).join('');
    }
    desenhar();
  }

  function cartao(e, botao) {
    const local = LOCAIS[(e.local || '').toLowerCase()] || e.local || '';
    return `<article class="evento" data-id="${esc(e.id)}">
      ${icone(e.cat, 'grande')}
      <div class="evento-info">
        <h4>${esc(e.titulo)}</h4>
        <p class="evento-meta">${fmtData.format(e.i)} às ${fmtHora.format(e.i)}${local ? ' • ' + esc(local) : ''}</p>
        ${e.descricao ? `<p class="evento-desc">${esc(e.descricao)}</p>` : ''}
        ${vagasHTML(e)}
        ${botao ? `<button type="button" class="botao botao-pequeno evento-botao" data-id="${esc(e.id)}">${botao}</button>` : ''}
      </div></article>`;
  }

  // Calendário + lista dos próximos, com filtro opcional
  async function montar({ cal, lista, filtro = () => true, botao, aoEscolher, vazio = 'Novos eventos em breve. Acompanhe!' }) {
    lista.innerHTML = '<p class="agenda-vazia">Consultando os astros…</p>';
    let eventos = [];
    try { eventos = (await carregar()).filter(filtro); }
    catch (err) { lista.innerHTML = '<p class="agenda-vazia">Não foi possível carregar a agenda agora.</p>'; calendario(cal); return; }
    const agora = new Date();
    function mostrar(doDia) {
      const itens = doDia || eventos.filter(e => (e.f || e.i) >= agora);
      lista.innerHTML = (doDia ? '<button type="button" class="ag-limpar">← Ver todos os próximos</button>' : '')
        + (itens.length ? itens.map(e => cartao(e, botao)).join('') : `<p class="agenda-vazia">${doDia ? 'Nada neste dia.' : vazio}</p>`);
    }
    lista.addEventListener('click', ev => {
      if (ev.target.closest('.ag-limpar')) { mostrar(); return; }
      const b = ev.target.closest('.evento-botao');
      if (b && aoEscolher) aoEscolher(eventos.find(e => String(e.id) === b.dataset.id));
    });
    calendario(cal, { eventos, aoClicar: (d, evs) => mostrar(evs) });
    mostrar();
  }

  setInterval(() => { if (cache && document.querySelector('.evento[data-id]')) atualizarVagas().catch(() => {}); }, 60000);

  return { carregar, atualizarVagas, fmtPreco, calendario, montar, categoria, icone, fmtData, fmtHora, hoje };
})();
