// Fotos dos espaços (copiadas de Ref/Sitio) em carrossel com transição suave.
const FOTOS = {
  "restaurante": [
    "img/fotos/restaurante/1.jpg",
    "img/fotos/restaurante/2.jpg",
    "img/fotos/restaurante/3.jpg",
    "img/fotos/restaurante/4.jpg"
  ],
  "espaco1": [
    "img/fotos/espaco1/1.jpg",
    "img/fotos/espaco1/2.jpg",
    "img/fotos/espaco1/3.jpg",
    "img/fotos/espaco1/4.jpg"
  ],
  "espaco2": [
    "img/fotos/espaco2/1.jpg",
    "img/fotos/espaco2/2.jpg",
    "img/fotos/espaco2/3.jpg"
  ],
  "espaco3": [
    "img/fotos/espaco3/1.jpg",
    "img/fotos/espaco3/2.jpg",
    "img/fotos/espaco3/3.jpg",
    "img/fotos/espaco3/4.jpg"
  ],
  "espaco4": [
    "img/fotos/espaco4/1.jpg",
    "img/fotos/espaco4/2.jpg",
    "img/fotos/espaco4/3.jpg",
    "img/fotos/espaco4/4.jpg"
  ],
  "espaco5": [
    "img/fotos/espaco5/1.jpg"
  ]
};

(function () {
  const reduz = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  document.querySelectorAll('[data-img]').forEach((el, n) => {
    const lista = FOTOS[el.dataset.img];
    if (!lista || el.classList.contains('tem-foto')) return; // foto trocada pelo painel tem prioridade
    el.classList.add('com-carrossel');
    const slides = lista.map((src, i) => {
      const s = document.createElement('div');
      s.className = 'slide' + (i === 0 ? ' ativo' : '');
      s.style.backgroundImage = `url(${src})`;
      el.prepend(s);
      return s;
    });
    if (slides.length < 2 || reduz) return;
    let atual = 0;
    setTimeout(() => setInterval(() => {
      slides[atual].classList.remove('ativo');
      atual = (atual + 1) % slides.length;
      slides[atual].classList.add('ativo');
    }, 7000), n * 1300); // cada carrossel começa em um momento diferente
  });
})();
