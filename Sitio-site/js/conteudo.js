// Edições feitas pelo painel de administrador.
// Por enquanto ficam salvas no navegador (localStorage).
const CHAVE_EDICOES = 'sitioCoelhos.edicoes';
const PAGINA = (location.pathname.split('/').pop() || 'index.html');
const CHAVE_TEXTOS = PAGINA === 'index.html' ? 'textos' : 'textos:' + PAGINA;
const SELETOR_TEXTOS = 'main h1, main h2, main h3, main p, main li, .menu a, .rodape p:not(.runas), .formulario label > :first-child';

function lerEdicoes() {
  try { return JSON.parse(localStorage.getItem(CHAVE_EDICOES)) || {}; } catch (e) { return {}; }
}
function salvarEdicoes(ed) {
  try { localStorage.setItem(CHAVE_EDICOES, JSON.stringify(ed)); return true; }
  catch (e) { alert('Não foi possível salvar. As fotos podem estar grandes demais para o armazenamento do navegador.'); return false; }
}
function elementosDeTexto() {
  return [...document.querySelectorAll(SELETOR_TEXTOS)].filter(el => !el.closest('.natureza') && !el.classList.contains('aviso') && !el.closest('.agenda-lista, .calendario') && !el.classList.contains('runas'));
}
function aplicarEdicoes() {
  const ed = lerEdicoes();
  elementosDeTexto().forEach((el, i) => { const t = ed[CHAVE_TEXTOS]; if (t && t[i] != null) el.innerHTML = t[i]; });
  document.querySelectorAll('[data-img]').forEach(el => {
    const src = ed.imagens && ed.imagens[el.dataset.img];
    if (src) { el.style.backgroundImage = `url(${src})`; el.classList.add('tem-foto'); }
  });
  if (ed.cores) Object.entries(ed.cores).forEach(([k, v]) => document.documentElement.style.setProperty(k, v));
}
aplicarEdicoes();
