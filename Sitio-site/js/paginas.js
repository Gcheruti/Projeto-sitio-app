// Funções compartilhadas pelas subpáginas.
window.Paginas = {
  // Agenda filtrada + botão que preenche o formulário de inscrição
  async agendaComInscricao({ cal, lista, select, destino, filtro, botao, vazio }) {
    const sel = document.getElementById(select);
    await Agenda.montar({
      cal: document.getElementById(cal), lista: document.getElementById(lista), filtro, botao, vazio,
      aoEscolher: e => {
        sel.value = e.id;
        document.getElementById(destino).scrollIntoView({ behavior: 'smooth' });
      }
    });
    try {
      const agora = new Date();
      const futuros = (await Agenda.carregar()).filter(filtro).filter(e => (e.f || e.i) >= agora);
      futuros.forEach(e => sel.add(new Option(`${e.titulo} · ${Agenda.fmtData.format(e.i)} ${Agenda.fmtHora.format(e.i)}`, e.id)));
    } catch (err) {}
    // Vindo da página inicial: já escolhe o evento e leva ao formulário
    const pedido = new URLSearchParams(location.search).get('evento');
    if (pedido && [...sel.options].some(o => o.value === pedido)) {
      sel.value = pedido;
      const alvo = document.getElementById(destino);
      setTimeout(() => window.scrollTo({ top: alvo.getBoundingClientRect().top + window.scrollY - 70, behavior: 'instant' }), 400);
    }
  }
};
