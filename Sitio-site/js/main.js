// Menu no celular
const botaoMenu = document.querySelector('.menu-botao');
const menu = document.querySelector('.menu');
botaoMenu.addEventListener('click', () => {
  const aberto = menu.classList.toggle('aberto');
  botaoMenu.setAttribute('aria-expanded', aberto);
});
menu.querySelectorAll('a').forEach(a => a.addEventListener('click', () => menu.classList.remove('aberto')));

// Formulário de agendamento (apenas visual por enquanto)
// Envio dos formulários: ver js/envio.js

const reduzMovimento = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

// Vaga-lumes na abertura
const vagalumes = document.querySelector('.vagalumes');
if (vagalumes) for (let i = 0; i < 14; i++) {
  const v = document.createElement('span');
  v.className = 'vagalume';
  v.style.left = Math.random() * 100 + '%';
  v.style.top = 30 + Math.random() * 60 + '%';
  v.style.animationDelay = -Math.random() * 6 + 's';
  v.style.animationDuration = 4 + Math.random() * 4 + 's';
  vagalumes.appendChild(v);
}

// Folhas caindo de vez em quando
const camadaFolhas = document.querySelector('.folhas-caindo');
function soltarFolha() {
  const f = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  f.setAttribute('class', 'folha-cai');
  f.innerHTML = '<use href="#folha"/>';
  f.style.left = Math.random() * 100 + 'vw';
  const dur = 10 + Math.random() * 8;
  f.style.animationDuration = dur + 's';
  camadaFolhas.appendChild(f);
  setTimeout(() => f.remove(), dur * 1000);
}
if (!reduzMovimento) setInterval(soltarFolha, 2500);

// Elementos aparecem ao rolar
const observador = new IntersectionObserver(entradas => {
  entradas.forEach(e => { if (e.isIntersecting) { e.target.classList.add('visivel'); observador.unobserve(e.target); } });
}, { threshold: .15 });
document.querySelectorAll('.titulo-secao, .cartao, .duas-colunas, .largo, .formulario').forEach(el => {
  el.classList.add('revelar'); observador.observe(el);
});

// Leve parallax das árvores da abertura
if (!reduzMovimento && document.querySelector('.natureza')) {
  const natureza = document.querySelector('.natureza');
  window.addEventListener('scroll', () => {
    natureza.style.transform = `translateY(${window.scrollY * 0.25}px)`;
  }, { passive: true });
}

// Modo de edição (aberto pelo painel admin)
if (new URLSearchParams(location.search).has('editar') && window.parent !== window) {
  document.documentElement.classList.add('modo-edicao');
  document.querySelectorAll('.revelar').forEach(el => el.classList.add('visivel'));
  const textos = elementosDeTexto();
  textos.forEach((el, i) => {
    el.contentEditable = 'true';
    el.addEventListener('click', e => e.preventDefault());
    el.addEventListener('blur', () => {
      const ed = lerEdicoes(); ed[CHAVE_TEXTOS] = ed[CHAVE_TEXTOS] || {};
      ed[CHAVE_TEXTOS][i] = el.innerHTML; salvarEdicoes(ed);
      window.parent.postMessage('salvo', '*');
    });
  });
  document.querySelectorAll('[data-img]').forEach(el => {
    el.title = 'Clique para trocar a foto';
    el.addEventListener('click', () => {
      const input = document.createElement('input');
      input.type = 'file'; input.accept = 'image/*';
      input.onchange = () => {
        const arq = input.files[0]; if (!arq) return;
        const img = new Image();
        img.onload = () => {
          const max = 1200, esc = Math.min(1, max / Math.max(img.width, img.height));
          const c = document.createElement('canvas');
          c.width = img.width * esc; c.height = img.height * esc;
          c.getContext('2d').drawImage(img, 0, 0, c.width, c.height);
          const dados = c.toDataURL('image/jpeg', .8);
          const ed = lerEdicoes(); ed.imagens = ed.imagens || {};
          ed.imagens[el.dataset.img] = dados;
          if (salvarEdicoes(ed)) { el.style.backgroundImage = `url(${dados})`; el.classList.add('tem-foto'); window.parent.postMessage('salvo', '*'); }
        };
        img.src = URL.createObjectURL(arq);
      };
      input.click();
    });
  });
  const estilo = document.createElement('style');
  estilo.textContent = `.modo-edicao [contenteditable]:hover{outline:2px dashed #c9a55a;outline-offset:3px;cursor:text}
  .modo-edicao [contenteditable]:focus{outline:2px solid #c9a55a;outline-offset:3px}
  .modo-edicao [data-img]{cursor:pointer;outline:2px dashed rgba(201,165,90,.8);outline-offset:-6px}`;
  document.head.appendChild(estilo);
}

// Cabeçalho muda ao rolar
const topo = document.querySelector('.topo');
const marcarTopo = () => topo.classList.toggle('rolado', window.scrollY > 40);
window.addEventListener('scroll', marcarTopo, { passive: true }); marcarTopo();
