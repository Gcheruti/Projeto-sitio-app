// Detalhes decorativos estáticos: moldura da abertura e faixas rúnicas entre seções.
(function () {
  const hero = document.querySelector('.hero');
  if (hero) {
    const m = document.createElement('div');
    m.className = 'moldura-hero'; m.setAttribute('aria-hidden', 'true');
    m.innerHTML = '<span>✦</span><span>✦</span><span>✦</span><span>✦</span>';
    hero.appendChild(m);
  }
  const conjuntos = [
    'ᚠ ᚢ ᚦ', 'ᚨ ᚱ ᚲ', 'ᚷ ᚹ ᚺ', 'ᚾ ᛁ ᛃ', 'ᛇ ᛈ ᛉ', 'ᛊ ᛏ ᛒ', 'ᛖ ᛗ ᛚ', 'ᛜ ᛞ ᛟ'
  ];
  const gemas = ['', 'pessego', 'azul', 'rosa'];
  // Uma faixa logo após a abertura e antes de cada seção escura
  const alvos = [...document.querySelectorAll('main > .hero, main > .secao-escura')];
  alvos.forEach((sec, i) => {
    const f = document.createElement('div');
    f.className = 'faixa-runica'; f.setAttribute('aria-hidden', 'true');
    const a = conjuntos[(i * 2) % conjuntos.length], b = conjuntos[(i * 2 + 1) % conjuntos.length];
    f.innerHTML = `<span>${a}</span><span class="gema ${gemas[i % 4]}"></span><span>ᛟ</span><span class="gema ${gemas[(i + 1) % 4]}"></span><span>${b}</span>`;
    if (sec.classList.contains('hero')) sec.after(f); else sec.before(f);
  });
})();
