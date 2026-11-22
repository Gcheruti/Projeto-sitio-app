/* Portal Cosmoria · palco 3D do personalizador (usa three.js, em js/three.min.js).
   O produto ocupa a tela toda: arraste para girar, pince ou use a barra para aproximar.
   Caneca: cilindro de cerâmica com alça, a arte enrolada em volta (sobram ~5 cm livres na alça).
   Roupas e ecobag: o desenho da peça (com a arte) ganha volume, com frente e costas.
   Se o aparelho não tiver WebGL, devolve null e a página usa a prévia simples (previa3d.js). */
(function () {
  if (!window.THREE) return;
  var T = THREE;
  var R = 4.1, ALT = 9.6, PAREDE = 0.3, IMP = 8.6; // caneca em cm: raio, altura, parede, altura impressa
  var VOLTA = 20 / (2 * Math.PI * R); // fração da volta coberta pela arte de 20 cm

  function temWebGL() { try { var c = document.createElement('canvas'); return !!(c.getContext('webgl2') || c.getContext('webgl')); } catch (e) { return false; } }

  function estudio() { // ambiente para os reflexos: sala neutra com três softboxes
    var s = new T.Scene();
    s.add(new T.Mesh(new T.BoxGeometry(40, 40, 40), new T.MeshBasicMaterial({ color: 0x77736b, side: T.BackSide })));
    function luz(w, h, x, y, z, k) {
      var m = new T.Mesh(new T.PlaneGeometry(w, h), new T.MeshBasicMaterial({ color: new T.Color(k, k, k), side: T.DoubleSide }));
      m.position.set(x, y, z); m.lookAt(0, 0, 0); s.add(m);
    }
    luz(10, 12, -10, 6, 9, 6); luz(6, 16, 12, 3, 2, 3.2); luz(16, 16, 0, 16, 0, 2.6); luz(10, 6, 4, 2, -14, 1.4);
    var chao = new T.Mesh(new T.PlaneGeometry(40, 40), new T.MeshBasicMaterial({ color: 0xa9a59b })); chao.rotation.x = -Math.PI / 2; chao.position.y = -8; s.add(chao);
    return s;
  }

  function sombraTextura() {
    var c = document.createElement('canvas'); c.width = c.height = 256; var x = c.getContext('2d');
    var g = x.createRadialGradient(128, 128, 0, 128, 128, 128);
    g.addColorStop(0, 'rgba(0,0,0,.55)'); g.addColorStop(0.45, 'rgba(0,0,0,.28)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    x.fillStyle = g; x.fillRect(0, 0, 256, 256);
    var t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; return t;
  }

  // altura (volume) da peça a partir da silhueta: distância até a borda, perfil arredondado
  function relevo(img, N, prof) {
    var w = img.width, h = img.height, M = Math.max(2, Math.round(N * h / w));
    var c = document.createElement('canvas'); c.width = N; c.height = M; var x = c.getContext('2d');
    x.drawImage(img, 0, 0, N, M);
    var a = x.getImageData(0, 0, N, M).data, d = new Float32Array(N * M), INF = 1e6, i, j, k;
    var x0 = N, x1 = -1;
    for (j = 0; j < M; j++) for (i = 0; i < N; i++) { k = j * N + i; var dentro = a[k * 4 + 3] > 127; d[k] = dentro ? INF : 0; if (dentro) { if (i < x0) x0 = i; if (i > x1) x1 = i; } }
    var D = Math.SQRT2;
    for (j = 0; j < M; j++) for (i = 0; i < N; i++) { k = j * N + i; if (!d[k]) continue; var v = d[k];
      v = Math.min(v, i > 0 ? d[k - 1] + 1 : 1, j > 0 ? d[k - N] + 1 : 1, i > 0 && j > 0 ? d[k - N - 1] + D : D, i < N - 1 && j > 0 ? d[k - N + 1] + D : D); d[k] = v; }
    for (j = M - 1; j >= 0; j--) for (i = N - 1; i >= 0; i--) { k = j * N + i; if (!d[k]) continue; var u = d[k];
      u = Math.min(u, i < N - 1 ? d[k + 1] + 1 : 1, j < M - 1 ? d[k + N] + 1 : 1, i < N - 1 && j < M - 1 ? d[k + N + 1] + D : D, i > 0 && j < M - 1 ? d[k + N - 1] + D : D); d[k] = u; }
    var Lg = Math.max(8, x1 - x0 + 1), sat = 0.32 * Lg, hmax = prof * 0.38 * Lg, z = new Float32Array(N * M);
    for (k = 0; k < N * M; k++) { if (!d[k]) continue; var t = Math.min(1, d[k] / sat); z[k] = hmax * Math.sqrt(1 - (1 - t) * (1 - t)); }
    // suaviza por dentro (as bordas continuam caindo até zero)
    for (var pass = 0; pass < 2; pass++) {
      var z2 = new Float32Array(z);
      for (j = 1; j < M - 1; j++) for (i = 1; i < N - 1; i++) { k = j * N + i; if (!d[k] || d[k] < 2) continue; z2[k] = (z[k] * 4 + z[k - 1] + z[k + 1] + z[k - N] + z[k + N]) / 8; }
      z = z2;
    }
    return { N: N, M: M, z: z };
  }

  function dilatar(img, r) { // estende a borda da peça uns pixels: forma a lateral do volume
    var c = document.createElement('canvas'); c.width = img.width; c.height = img.height; var x = c.getContext('2d');
    for (var s = 1; s <= 2; s++) for (var n = 0; n < 16; n++) { var an = n / 16 * 2 * Math.PI; x.drawImage(img, Math.cos(an) * r * s / 2, Math.sin(an) * r * s / 2); }
    x.drawImage(img, 0, 0);
    return c;
  }

  function Palco3D(box) {
    if (!temWebGL()) return null;
    var renderer;
    try { renderer = new T.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true }); } catch (e) { return null; }
    renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1));
    renderer.outputColorSpace = T.SRGBColorSpace;
    renderer.toneMapping = T.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.05;
    renderer.domElement.className = 'palco3d-canvas';
    renderer.domElement.setAttribute('aria-label', 'Seu produto em 3D. Arraste para girar.');
    box.appendChild(renderer.domElement);
    var aniso = renderer.capabilities.getMaxAnisotropy();

    var cena = new T.Scene(), cam = new T.PerspectiveCamera(26, 1, 0.5, 400);
    var pm = new T.PMREMGenerator(renderer); cena.environment = pm.fromScene(estudio(), 0.035).texture; pm.dispose();
    cena.add(new T.HemisphereLight(0xffffff, 0x8f8a80, 0.35));
    var sol = new T.DirectionalLight(0xffffff, 0.9); sol.position.set(-6, 9, 10); cena.add(sol);

    var peca = new T.Group(); cena.add(peca);
    var sombra = new T.Mesh(new T.PlaneGeometry(1, 1), new T.MeshBasicMaterial({ map: sombraTextura(), transparent: true, depthWrite: false }));
    sombra.rotation.x = -Math.PI / 2; cena.add(sombra);

    var modo = null, raio = 6, centro = new T.Vector3();
    var yaw = 0, pitch = 0.1, alvoYaw = null, vel = 0, zoom = 1, aoZoom = null, raf = 0, W = 0, H = 0;

    function limpar() {
      while (peca.children.length) {
        var o = peca.children.pop();
        o.traverse(function (m) { if (m.geometry) m.geometry.dispose(); if (m.material) [].concat(m.material).forEach(function (mt) { if (mt.map) mt.map.dispose(); mt.dispose(); }); });
      }
    }

    // ---------- caneca ----------
    var caneca = null, canecaCor = null, canecaTex = null, texCaneca = null;
    function montarCaneca() {
      limpar();
      var g = new T.Group(), corM = new T.Color(1, 1, 1);
      var ceramica = function (extra) { return new T.MeshPhysicalMaterial(Object.assign({ color: corM, roughness: 0.28, metalness: 0, clearcoat: 1, clearcoatRoughness: 0.06 }, extra || {})); };
      var corpoMat = ceramica({ color: new T.Color(1, 1, 1) });
      var corpo = new T.Mesh(new T.CylinderGeometry(R, R, ALT, 180, 1, true, -Math.PI, 2 * Math.PI), corpoMat); g.add(corpo);
      var liso = ceramica();
      var dentro = new T.Mesh(new T.CylinderGeometry(R - PAREDE, R - PAREDE, ALT - 0.4, 120, 1, true), ceramica({ side: T.BackSide })); dentro.position.y = 0.2; g.add(dentro);
      var fundoDentro = new T.Mesh(new T.CircleGeometry(R - PAREDE, 96), liso); fundoDentro.rotation.x = -Math.PI / 2; fundoDentro.position.y = -ALT / 2 + 0.4; g.add(fundoDentro);
      var borda = new T.Mesh(new T.TorusGeometry(R - PAREDE / 2, PAREDE / 2, 20, 180), liso); borda.rotation.x = Math.PI / 2; borda.position.y = ALT / 2; g.add(borda);
      var base = new T.Mesh(new T.CircleGeometry(R, 96), liso); base.rotation.x = Math.PI / 2; base.position.y = -ALT / 2; g.add(base);
      var p = function (y, z) { return new T.Vector3(0, y, -R - z); };
      var curva = new T.CatmullRomCurve3([p(3.05, -0.35), p(3.25, 1.1), p(2.7, 2.6), p(1.0, 3.25), p(-1.0, 3.1), p(-2.5, 2.1), p(-3.0, 0.8), p(-2.9, -0.35)]);
      var alca = new T.Mesh(new T.TubeGeometry(curva, 120, 0.52, 28), liso); alca.scale.x = 1.15; g.add(alca);
      peca.add(g);
      caneca = { corpo: corpoMat, liso: liso };
      raio = 7.4; centro.set(0, 0, 0);
      sombra.visible = true; sombra.scale.set(R * 3.6, R * 3.6, 1); sombra.position.set(0, -ALT / 2 - 0.01, -0.8);
    }
    function texturaCaneca(tex, hex) {
      var Wt = 2048, Ht = Math.round(Wt * ALT / (2 * Math.PI * R));
      var c = document.createElement('canvas'); c.width = Wt; c.height = Ht; var x = c.getContext('2d');
      x.fillStyle = hex; x.fillRect(0, 0, Wt, Ht);
      if (tex) { var aw = Wt * VOLTA, ah = Ht * IMP / ALT; x.drawImage(tex, (Wt - aw) / 2, (Ht - ah) / 2, aw, ah); }
      var t = new T.CanvasTexture(c); t.colorSpace = T.SRGBColorSpace; t.anisotropy = aniso;
      return t;
    }

    // ---------- roupas e ecobag ----------
    var roupaChave = null, malhas = null;
    function malha(img, prof, costas) {
      var N = 200, rel = relevo(img, N, prof), S = 10 / N; // 10 unidades = largura do desenho
      var geo = new T.PlaneGeometry(10, 10 * img.height / img.width, N, rel.M), pos = geo.attributes.position;
      for (var j = 0; j <= rel.M; j++) for (var i = 0; i <= N; i++) {
        var soma = 0, n = 0;
        for (var dj = -1; dj <= 0; dj++) for (var di = -1; di <= 0; di++) { var ci = i + di, cj = j + dj; if (ci >= 0 && cj >= 0 && ci < N && cj < rel.M) { soma += rel.z[cj * N + ci]; n++; } }
        pos.setZ(j * (N + 1) + i, (n ? soma / n : 0) * S);
      }
      geo.computeVertexNormals();
      var mat = new T.MeshPhysicalMaterial({ alphaTest: 0.5, roughness: 0.9, metalness: 0, sheen: 0.35, sheenRoughness: 0.8, sheenColor: new T.Color(0.8, 0.8, 0.8) });
      var m = new T.Mesh(geo, mat); if (costas) m.rotation.y = Math.PI;
      return m;
    }
    function texturaRoupa(img) {
      var t = new T.CanvasTexture(dilatar(img, Math.max(4, img.width / 200 * 2.5))); t.colorSpace = T.SRGBColorSpace; t.anisotropy = aniso; return t;
    }
    function montarRoupa(imgF, imgV, prof, chave) {
      limpar();
      var f = malha(imgF, prof, false), v = malha(imgV, prof, true);
      peca.add(f); peca.add(v); malhas = { f: f, v: v };
      var caixa = new T.Box3().setFromObject(peca), tam = caixa.getSize(new T.Vector3());
      raio = Math.max(tam.x * 0.56, tam.y * 0.48); centro.set(0, 0, 0);
      sombra.visible = false; roupaChave = chave;
    }

    // ---------- câmera, gestos e desenho ----------
    function enquadrar() {
      var a = W / Math.max(1, H), vf = cam.fov * Math.PI / 180, hf = 2 * Math.atan(Math.tan(vf / 2) * a);
      var r = modo === 'caneca' ? (a < 0.8 ? 7 : 9.6) : raio; // caneca: mais folga na tela larga
      var dist = r / Math.sin(Math.min(vf, hf) / 2) / zoom;
      var dir = new T.Vector3(0, Math.sin(pitch), Math.cos(pitch));
      cam.position.copy(dir.multiplyScalar(dist)); cam.lookAt(0, 0, 0);
      cam.near = Math.max(0.1, dist - r * 3); cam.far = dist + r * 4; cam.updateProjectionMatrix();
      peca.rotation.y = yaw; peca.position.set(-centro.x, -centro.y, 0);
      sombra.rotation.z = -yaw;
    }
    function desenhar() { if (!W) return; enquadrar(); renderer.render(cena, cam); }
    function quadro() {
      raf = 0; var segue = false;
      if (alvoYaw !== null) { var dif = alvoYaw - yaw; yaw += dif * 0.14; if (Math.abs(dif) < 0.002) { yaw = alvoYaw; alvoYaw = null; } else segue = true; }
      else if (!arr && Math.abs(vel) > 0.0004) { yaw += vel; vel *= 0.93; segue = true; }
      desenhar(); if (segue) pedir();
    }
    function pedir() { if (!raf) raf = requestAnimationFrame(quadro); }
    function medir() {
      var r = box.getBoundingClientRect(); W = Math.round(r.width); H = Math.round(r.height);
      if (!W || !H) return; renderer.setSize(W, H); cam.aspect = W / H; pedir();
    }
    if (window.ResizeObserver) new ResizeObserver(medir).observe(box); else window.addEventListener('resize', medir);

    var cv = renderer.domElement, toques = {}, arr = null, pinca = null;
    cv.style.touchAction = 'none';
    cv.addEventListener('pointerdown', function (e) {
      toques[e.pointerId] = { x: e.clientX, y: e.clientY }; cv.setPointerCapture(e.pointerId);
      var ids = Object.keys(toques);
      if (ids.length === 1) { arr = { x: e.clientX, y: e.clientY, t: performance.now() }; alvoYaw = null; vel = 0; }
      else if (ids.length === 2) { var a = toques[ids[0]], b = toques[ids[1]]; pinca = { d: Math.hypot(a.x - b.x, a.y - b.y), z: zoom }; arr = null; }
    });
    cv.addEventListener('pointermove', function (e) {
      if (!toques[e.pointerId]) return; toques[e.pointerId] = { x: e.clientX, y: e.clientY };
      if (pinca) { var ids = Object.keys(toques), a = toques[ids[0]], b = toques[ids[1]]; if (a && b) definirZoom(pinca.z * Math.hypot(a.x - b.x, a.y - b.y) / pinca.d); return; }
      if (!arr) return;
      var dx = e.clientX - arr.x, dy = e.clientY - arr.y, agora = performance.now();
      yaw += dx * 0.0105; pitch = Math.max(-0.35, Math.min(0.75, pitch + dy * 0.006));
      vel = dx * 0.0105 / Math.max(1, (agora - arr.t) / 16); arr.x = e.clientX; arr.y = e.clientY; arr.t = agora; pedir();
    });
    function soltar(e) { delete toques[e.pointerId]; if (!Object.keys(toques).length) { arr = null; pinca = null; pedir(); } }
    cv.addEventListener('pointerup', soltar); cv.addEventListener('pointercancel', soltar);
    cv.addEventListener('wheel', function (e) { e.preventDefault(); definirZoom(zoom * Math.exp(-e.deltaY * 0.0012)); }, { passive: false });
    function definirZoom(z) { zoom = Math.max(0.6, Math.min(2.6, z)); if (aoZoom) aoZoom(zoom); pedir(); }

    var reduzido = window.matchMedia && matchMedia('(prefers-reduced-motion: reduce)').matches;
    medir();
    return {
      caneca: function (tex, hex) {
        if (modo !== 'caneca' || !caneca) { montarCaneca(); modo = 'caneca'; yaw = reduzido ? -0.75 : 0.25; alvoYaw = -0.75; pitch = 0.3; }
        var t = texturaCaneca(tex, hex);
        if (caneca.corpo.map) caneca.corpo.map.dispose();
        caneca.corpo.map = t; caneca.corpo.needsUpdate = true;
        caneca.liso.color.set(hex);
        pedir();
      },
      roupa: function (imgF, imgV, prof, chave) {
        var nova = modo !== 'roupa' || roupaChave !== chave || !malhas;
        if (nova) { montarRoupa(imgF, imgV, prof, chave); if (modo !== 'roupa') { yaw = reduzido ? 0 : 0.7; alvoYaw = 0; pitch = 0.06; } modo = 'roupa'; }
        [['f', imgF], ['v', imgV]].forEach(function (p) { var m = malhas[p[0]].material; if (m.map) m.map.dispose(); m.map = texturaRoupa(p[1]); m.needsUpdate = true; });
        pedir();
      },
      lado: function (l) { // gira para mostrar a frente ou as costas
        if (modo === 'caneca') return;
        var base = l === 'verso' ? Math.PI : 0, volta = Math.round((yaw - base) / (2 * Math.PI)) * 2 * Math.PI;
        alvoYaw = base + volta; pedir();
      },
      zoom: function (z) { if (z === undefined) return zoom; definirZoom(z); },
      aoZoom: function (fn) { aoZoom = fn; },
      foto: function (largura, ang) { // imagem parada (para o designer)
        var y0 = yaw, p0 = pitch, z0 = zoom, w0 = W, h0 = H;
        if (ang !== undefined) yaw = ang; pitch = 0.1; zoom = 1;
        var w = largura || 640, h = Math.round(w * 0.8); W = w; H = h; renderer.setPixelRatio(1); renderer.setSize(w, h, false); cam.aspect = w / h;
        desenhar(); var url = renderer.domElement.toDataURL('image/png');
        yaw = y0; pitch = p0; zoom = z0; W = w0; H = h0; renderer.setPixelRatio(Math.min(2, window.devicePixelRatio || 1)); renderer.setSize(W, H); cam.aspect = W / H; desenhar();
        return url;
      },
      redesenhar: pedir,
      _estado: function () { return { yaw: yaw, pitch: pitch, zoom: zoom }; }
    };
  }
  window.Palco3D = Palco3D;
})();
