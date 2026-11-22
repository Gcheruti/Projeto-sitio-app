// Envia os formulários para site.cadastros (somente inserção) e mostra pop-ups temáticos.
(function () {
  const CAMPOS_FIXOS = ['nome', 'telefone', 'email'];
  const CAMPOS_PESSOAS = ['pessoas', 'convidados'];
  const CAMPOS_MENSAGEM = ['mensagem', 'obs'];
  const CAMPOS_AGENDA = ['evento', 'curso']; // valor = id do evento na agenda

  const SUCESSO = {
    visita:           ['Sua visita foi semeada', 'Recebemos seu pedido de visita. Em breve entraremos em contato para combinar os detalhes. O sítio já aguarda seus passos entre as árvores.'],
    restaurante:      ['Sua mesa está a caminho', 'Recebemos seu pedido de reserva. Logo confirmaremos tudo com você. Que a terra prepare um banquete à altura da sua visita.'],
    evento_presenca:  ['Sua presença foi registrada', 'Sua pré-inscrição foi realizada com sucesso. Muito obrigado pelo interesse! Em breve você receberá a confirmação. Que a roda gire a seu favor até nos encontrarmos.'],
    evento_orcamento: ['Seu pedido chegou até nós', 'Recebemos as informações do seu evento e vamos preparar uma proposta com carinho. Grandes celebrações começam com uma intenção, e a sua já foi lançada.'],
    curso:            ['Sua inscrição foi realizada', 'Muito obrigado pelo interesse! Sua pré-inscrição foi recebida e em breve entraremos em contato com os próximos passos. A Gruta já guarda um lugar para você.'],
    espaco:           ['Seu pedido foi recebido', 'Recebemos sua solicitação de reserva. Em breve confirmaremos a disponibilidade. Que este espaço acolha a sua intenção.']
  };

  function montar(form) {
    const fd = new FormData(form), dados = {};
    const reg = { categoria: form.dataset.categoria, pagina: location.pathname.split('/').pop() || 'index.html' };
    for (const [k, v0] of fd.entries()) {
      const v = String(v0).trim(); if (!v) continue;
      const el = form.elements[k];
      if (CAMPOS_FIXOS.includes(k)) reg[k] = v;
      else if (CAMPOS_PESSOAS.includes(k)) reg.pessoas = parseInt(v, 10) || null;
      else if (CAMPOS_MENSAGEM.includes(k)) reg.mensagem = v;
      else if (k === 'data') reg.data_desejada = v;
      else if (CAMPOS_AGENDA.includes(k)) { reg.referencia_id = v; reg.referencia_titulo = el.selectedOptions[0].text; }
      else if (k === 'espaco' && reg.categoria === 'espaco') reg.referencia_titulo = v;
      else dados[k] = v;
    }
    reg.dados = dados;
    return reg;
  }

  // Confere as vagas em tempo real antes de enviar
  async function semVagas(reg) {
    if (!reg.referencia_id || !window.Agenda) return null;
    try {
      const eventos = await Agenda.atualizarVagas();
      const e = eventos.find(x => String(x.id) === reg.referencia_id);
      const pedidas = reg.pessoas || 1;
      if (e && e.vagas != null && pedidas > e.vagas) return { e, pedidas };
    } catch (err) {}
    return null;
  }

  document.querySelectorAll('form[data-categoria]').forEach(form => {
    const aviso = form.querySelector('.aviso');
    const botao = form.querySelector('button[type=submit]');
    form.addEventListener('submit', async ev => {
      ev.preventDefault();
      if (new URLSearchParams(location.search).has('editar')) return; // modo de edição do admin
      if (aviso) aviso.hidden = true;
      botao.disabled = true; const txt = botao.textContent; botao.textContent = 'Consultando os astros…';
      const reg = montar(form);
      try {
        const falta = await semVagas(reg);
        if (falta) {
          const { e, pedidas } = falta;
          Modal({
            tipo: 'aviso',
            titulo: e.vagas === 0 ? 'O círculo está completo' : 'Não há lugares para todos',
            texto: e.vagas === 0
              ? `Todas as vagas de <strong>${e.titulo.replace(/</g, '&lt;')}</strong> já foram preenchidas. Fique de olho na agenda: a lua sempre traz novos encontros.`
              : `Você pediu <strong>${pedidas}</strong> ${pedidas === 1 ? 'lugar' : 'lugares'}, mas restam apenas <strong>${e.vagas}</strong> ${e.vagas === 1 ? 'vaga' : 'vagas'} em <strong>${e.titulo.replace(/</g, '&lt;')}</strong>. Ajuste o número de pessoas e tente novamente.`,
            botao: 'Entendi'
          });
          return;
        }
        const r = await fetch(`${SUPABASE_URL}/rest/v1/cadastros`, {
          method: 'POST',
          headers: {
            apikey: SUPABASE_CHAVE, Authorization: `Bearer ${SUPABASE_CHAVE}`,
            'Content-Type': 'application/json', 'Content-Profile': 'site', Prefer: 'return=minimal'
          },
          body: JSON.stringify(reg)
        });
        if (!r.ok) throw new Error(await r.text());
        const [t, m] = SUCESSO[reg.categoria] || SUCESSO.visita;
        Modal({ tipo: 'sucesso', titulo: t, texto: m, botao: 'Que assim seja' });
        form.reset();
      } catch (err) {
        console.error('Falha ao enviar cadastro:', err);
        Modal({ tipo: 'aviso', titulo: 'Os ventos não ajudaram', texto: 'Não conseguimos enviar seu pedido agora. Tente novamente em alguns instantes ou fale conosco pelo WhatsApp.', botao: 'Tentar de novo' });
      } finally {
        botao.disabled = false; botao.textContent = txt;
      }
    });
  });
})();
