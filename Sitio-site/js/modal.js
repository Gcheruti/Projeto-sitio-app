// Pop-up temático (sucesso ou aviso).
window.Modal = function ({ tipo = 'sucesso', titulo, texto, botao = 'Fechar' }) {
  const antigo = document.querySelector('.modal-fundo'); if (antigo) antigo.remove();
  const f = document.createElement('div');
  f.className = 'modal-fundo';
  f.innerHTML = `<div class="modal modal-${tipo}" role="dialog" aria-modal="true" aria-labelledby="modal-titulo">
      <div class="modal-selo" aria-hidden="true">${tipo === 'sucesso'
        ? '<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="46" fill="none" stroke="currentColor" stroke-width="3"/><polygon points="50,6 76,86 8,36 92,36 24,86" fill="none" stroke="currentColor" stroke-width="3" stroke-linejoin="round"/></svg>'
        : '<svg viewBox="0 0 120 50"><circle cx="60" cy="25" r="18" fill="none" stroke="currentColor" stroke-width="3"/><path d="M30 7a18 18 0 1 0 0 36a22 22 0 0 1 0-36z" fill="currentColor"/><path d="M90 7a18 18 0 1 1 0 36a22 22 0 0 0 0-36z" fill="currentColor"/></svg>'}</div>
      <p class="modal-runas" aria-hidden="true">${tipo === 'sucesso' ? 'ᚷ ✦ ᛟ ✦ ᚹ' : 'ᛁ ✦ ᚾ ✦ ᛁ'}</p>
      <h3 id="modal-titulo">${titulo}</h3>
      <p class="modal-texto">${texto}</p>
      <button type="button" class="botao">${botao}</button>
    </div>`;
  const fechar = () => { f.classList.remove('aberto'); setTimeout(() => f.remove(), 300); document.removeEventListener('keydown', esc); };
  const esc = e => { if (e.key === 'Escape') fechar(); };
  f.addEventListener('click', e => { if (e.target === f || e.target.closest('.modal .botao')) fechar(); });
  document.addEventListener('keydown', esc);
  document.body.appendChild(f);
  requestAnimationFrame(() => f.classList.add('aberto'));
  f.querySelector('.botao').focus();
};
