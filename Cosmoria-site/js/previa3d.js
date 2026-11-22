/* Portal Cosmoria · prévia 3D girando do produto personalizado (sem bibliotecas externas).
   Caneca: a arte é enrolada num cilindro, com alça, borda e sombra.
   Roupas e ecobag: a peça vira um corpo oval girando, com a frente e as costas. */
(function () {
  var tom = window.MOLDES_util.tom;
  var VOLTA = 20 / 25; // a arte tem 20 cm numa volta de ~25 cm: sobram ~5 cm livres em volta da alça
  function Previa3D(cv) {
    var ctx = cv.getContext('2d'), modo = 'caneca', tex = null, cor = '#F7F7F5', frente = null, verso = null, prof = 0.34;
    var rot = Math.PI, auto = !(window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches), visivel = true, raf = 0, ultimo = 0, retomar = 0;
    var W, H, dpr;
    function medir() {
      dpr = Math.min(2, window.devicePixelRatio || 1);
      var r = cv.getBoundingClientRect(); W = Math.max(200, r.width || 360); H = Math.round(W * 0.78);
      cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr); cv.style.height = H + 'px';
    }

    // ---------- caneca ----------
    function caneca(c, w, h, ang) {
      var R = w * 0.2, AL = R * 2.35, cx = w * 0.5, topo = (h - AL) / 2 - R * 0.05, e = R * 0.24, sa = Math.sin(-ang), ca = Math.cos(-ang);
      var f0 = 0.05, f1 = 0.955; // faixa impressa dentro da altura da caneca
      c.fillStyle = 'rgba(20,34,25,.14)'; c.beginPath(); c.ellipse(cx + R * 0.15, topo + AL + e * 0.9, R * 1.35, e * 1.25, 0, 0, 2 * Math.PI); c.fill();
      if (ca < 0) alca(c, cx, topo, R, AL, e, sa, ca);
      // corpo, coluna por coluna
      c.save(); silhueta(c, cx, topo, R, AL, e); c.clip();
      c.fillStyle = cor; c.fillRect(cx - R - 1, topo - e, 2 * R + 2, AL + 2 * e);
      if (tex) for (var x = -R; x < R; x += 1) {
        var th = Math.asin(Math.max(-1, Math.min(1, (x + 0.5) / R))), z = Math.cos(th);
        var phi = (th + ang) % (2 * Math.PI); if (phi < 0) phi += 2 * Math.PI;
        var u = (phi - Math.PI * (1 - VOLTA)) / (2 * Math.PI * VOLTA); if (u < 0 || u >= 1) continue; // vão sem estampa perto da alça
        var sw = Math.max(1, tex.width / (2 * Math.PI * R * VOLTA) / Math.max(z, 0.15));
        var sx = Math.min(tex.width - sw, u * tex.width), y0 = topo + e * z;
        c.drawImage(tex, sx, 0, sw, tex.height, cx + x, y0 + AL * f0, 1.6, AL * (f1 - f0));
      }
      var g = c.createLinearGradient(cx - R, 0, cx + R, 0);
      g.addColorStop(0, 'rgba(0,0,0,.38)'); g.addColorStop(0.18, 'rgba(0,0,0,.08)'); g.addColorStop(0.32, 'rgba(255,255,255,.28)');
      g.addColorStop(0.45, 'rgba(255,255,255,0)'); g.addColorStop(0.8, 'rgba(0,0,0,.12)'); g.addColorStop(1, 'rgba(0,0,0,.42)');
      c.fillStyle = g; c.fillRect(cx - R - 1, topo - e, 2 * R + 2, AL + 2 * e);
      c.restore();
      // borda de cima
      c.beginPath(); c.ellipse(cx, topo, R, e, 0, 0, 2 * Math.PI); c.fillStyle = tom(cor, -0.42); c.fill();
      c.beginPath(); c.ellipse(cx, topo + e * 0.18, R * 0.9, e * 0.78, 0, Math.PI, 2 * Math.PI); c.fillStyle = 'rgba(0,0,0,.18)'; c.fill();
      c.lineWidth = Math.max(1.5, R * 0.05); c.strokeStyle = tom(cor, 0.25); c.beginPath(); c.ellipse(cx, topo, R, e, 0, 0, 2 * Math.PI); c.stroke();
      c.lineWidth = 1; c.strokeStyle = tom(cor, -0.3); c.beginPath(); silhueta(c, cx, topo, R, AL, e); c.stroke();
      if (ca >= 0) alca(c, cx, topo, R, AL, e, sa, ca);
    }
    function silhueta(c, cx, topo, R, AL, e) {
      c.beginPath(); c.moveTo(cx - R, topo); c.lineTo(cx - R, topo + AL);
      c.ellipse(cx, topo + AL, R, e, 0, Math.PI, 0, true); c.lineTo(cx + R, topo);
      c.ellipse(cx, topo, R, e, 0, 0, Math.PI, false); c.closePath();
    }
    function alca(c, cx, topo, R, AL, e, sa, ca) {
      var D = R * 0.62, h = AL * 0.3, yc = topo + AL * 0.47;
      c.beginPath();
      for (var i = 0; i <= 28; i++) {
        var t = Math.PI * i / 28, r = R * 0.97 + D * Math.sin(t), y = yc - h * Math.cos(t) + e * ca * 0.15;
        if (i) c.lineTo(cx + r * sa, y); else c.moveTo(cx + r * sa, y);
      }
      c.lineCap = 'round'; c.lineJoin = 'round';
      c.lineWidth = R * 0.24; c.strokeStyle = tom(cor, -0.3); c.stroke();
      c.lineWidth = R * 0.17; c.strokeStyle = ca >= 0 ? tom(cor, 0.05) : tom(cor, -0.12); c.stroke();
    }

    // ---------- roupas e ecobag: a peça vira um corpo oval, com frente e costas ----------
    // A frente cobre metade da volta e as costas a outra metade, como um tronco visto de cima (elipse).
    function plano(c, w, h, ang) {
      var fr = frente || verso, vs = verso || frente; if (!fr) return;
      var esc = Math.min(w * 0.78 / fr.width, h * 0.9 / fr.height), PW = fr.width * esc, PH = fr.height * esc, cx = w / 2, cy = h / 2;
      var a = PW / 2, b = a * prof, f = PW * 3, ca = Math.cos(ang), sa = Math.sin(ang);
      var N = Math.max(60, Math.min(220, Math.round(PW / 2)));
      function ponto(t) { var px = a * Math.sin(t), pz = b * Math.cos(t), z = -px * sa + pz * ca; return { x: px * ca + pz * sa, s: f / (f - z) }; }
      var luzes = [];
      // A imagem é projetada de frente sobre o oval: de frente a peça aparece igual ao editor, e ao girar ganha volume.
      [[fr, false], [vs, true]].forEach(function (lado) {
        var img = lado[0], costas = lado[1], sw = img.width / N;
        function tDe(u) { var k = Math.max(-1, Math.min(1, 2 * u - 1)); return costas ? Math.PI - Math.asin(-k) : Math.asin(k); }
        for (var i = 0; i < N; i++) {
          var ta = tDe(i / N), tb = tDe((i + 1) / N), tm = tDe((i + 0.5) / N);
          var nx = Math.sin(tm) / a, nz = Math.cos(tm) / b, nzr = (-nx * sa + nz * ca) / Math.hypot(nx, nz);
          if (nzr <= 0.005) continue; // virada para trás
          var A = ponto(ta), B = ponto(tb), X0 = cx + A.x * A.s, X1 = cx + B.x * B.s, hh = PH * (A.s + B.s) / 2;
          var x = Math.min(X0, X1), cw = Math.abs(X1 - X0);
          if (cw < 0.05) continue;
          c.drawImage(img, i * sw, 0, sw, img.height, x, cy - hh / 2, cw + 0.6, hh);
          luzes.push({ x: x + cw / 2, s: (1 - nzr) * 0.5 + Math.max(0, -Math.sin(tm - ang)) * 0.06 });
        }
      });
      if (luzes.length > 1) { // sombreado suave de um lado ao outro, numa passada só
        luzes.sort(function (p, q) { return p.x - q.x; });
        var x0 = luzes[0].x - 2, x1 = luzes[luzes.length - 1].x + 2, g = c.createLinearGradient(x0, 0, x1, 0), passo = Math.max(1, Math.floor(luzes.length / 40));
        for (var j = 0; j < luzes.length; j += passo) g.addColorStop(Math.max(0, Math.min(1, (luzes[j].x - x0) / (x1 - x0))), 'rgba(0,0,0,' + Math.min(0.6, luzes[j].s).toFixed(3) + ')');
        g.addColorStop(1, 'rgba(0,0,0,' + Math.min(0.6, luzes[luzes.length - 1].s).toFixed(3) + ')');
        c.globalCompositeOperation = 'source-atop'; c.fillStyle = g; c.fillRect(x0 - 4, 0, x1 - x0 + 8, h); c.globalCompositeOperation = 'source-over';
      }
      // sombra no chão, desenhada por baixo da peça
      var rx = Math.sqrt(Math.pow(a * ca, 2) + Math.pow(b * sa, 2));
      c.globalCompositeOperation = 'destination-over';
      c.fillStyle = 'rgba(20,34,25,.13)'; c.beginPath(); c.ellipse(cx, cy + PH * 0.47, rx * 0.8 + PW * 0.04, PH * 0.035 + b * 0.08, 0, 0, 2 * Math.PI); c.fill();
      c.globalCompositeOperation = 'source-over';
    }

    function desenhar(c, w, h, ang) { c.clearRect(0, 0, w, h); if (modo === 'caneca') caneca(c, w, h, ang); else plano(c, w, h, ang); }
    function quadro(t) {
      raf = requestAnimationFrame(quadro);
      if (!visivel) return;
      var dt = ultimo ? Math.min(50, t - ultimo) : 16; ultimo = t;
      if (auto && !arrasto && t > retomar) rot = (rot + dt * 0.0009) % (2 * Math.PI);
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0); desenhar(ctx, W, H, rot);
    }
    // arrastar para girar
    var arrasto = null;
    cv.addEventListener('pointerdown', function (e) { arrasto = { x: e.clientX, r: rot }; cv.setPointerCapture(e.pointerId); });
    cv.addEventListener('pointermove', function (e) { if (arrasto) rot = arrasto.r - (e.clientX - arrasto.x) * 0.012; });
    function soltar() { if (arrasto) { arrasto = null; retomar = performance.now() + 2500; } }
    cv.addEventListener('pointerup', soltar); cv.addEventListener('pointercancel', soltar);
    if ('IntersectionObserver' in window) new IntersectionObserver(function (es) { visivel = es[0].isIntersecting; }).observe(cv);
    medir(); window.addEventListener('resize', medir);
    if (window.ResizeObserver) new ResizeObserver(function () { var r = cv.getBoundingClientRect(); if (r.width && Math.abs(r.width - W) > 1) medir(); }).observe(cv);
    raf = requestAnimationFrame(quadro);

    return {
      caneca: function (textura, hex) { modo = 'caneca'; tex = textura; cor = hex; },
      plano: function (imgF, imgV, profundidade) { modo = 'plano'; frente = imgF; verso = imgV; prof = profundidade || 0.34; },
      girarPara: function (a) { rot = a; retomar = performance.now() + 2500; },
      foto: function (ang, largura) { // imagem parada num ângulo, para o designer
        var w = largura || 520, h = Math.round(w * 0.78), c = document.createElement('canvas'); c.width = w; c.height = h;
        var x = c.getContext('2d'); desenhar(x, w, h, ang); x.globalCompositeOperation = 'destination-over'; x.fillStyle = '#EDEAE0'; x.fillRect(0, 0, w, h);
        return c.toDataURL('image/jpeg', 0.88);
      }
    };
  }
  window.Previa3D = Previa3D;
})();
