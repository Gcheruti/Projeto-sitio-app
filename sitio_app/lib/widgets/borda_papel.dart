import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'natureza_overlay.dart' show desenharGlifo;

/// Borda de cartão que lembra uma folha de papel envelhecida.
///
/// Todos os cartões compartilham a mesma base: contorno suavemente
/// irregular e arredondado (sem pontas), sombra de borda funda, amassado
/// com facetas e dobras e um botão dourado envelhecido com runa. Sobre essa
/// base cada cartão sorteia (a partir do próprio tamanho, sem piscar) uma
/// variação leve: liso, queimado, canto arredondado, canto dobrado, uma
/// mordida suave ou borda ondulada. Em algumas estações aparece também um
/// detalhe sazonal (neve, folha, flor, sol) num canto.
class BordaPapel extends OutlinedBorder {
  const BordaPapel({
    super.side = BorderSide.none,
    this.tinta = const Color(0xFF5A4630),
    this.estacao,
    this.semente,
  });

  /// Semente própria do cartão (ex.: id da comanda). Sem ela, a variação vem
  /// só do tamanho, e cartões do mesmo tamanho ficam parecidos.
  final int? semente;

  /// Mesma borda, mas com variação própria (ver [papelCom]).
  BordaPapel comSemente(int s) =>
      BordaPapel(side: side, tinta: tinta, estacao: estacao, semente: s);

  /// Cor do desgaste (sombras de borda, dobras, manchas, contorno).
  final Color tinta;

  /// 0 primavera, 1 verão, 2 outono, 3 inverno; null = sem detalhe sazonal.
  final int? estacao;

  static const int _estilos = 6;

  int _semente(Rect r) =>
      ((semente ?? 0) * 7919 + (r.width * 13 + r.height * 7).round()) & 0x7fffffff;

  /// 0 liso, 1 queimado, 2 canto arredondado, 3 canto dobrado, 4 mordida,
  /// 5 ondulado.
  int _estilo(Rect r) => math.Random(_semente(r) + 1).nextInt(_estilos);

  /// Canto afastado (0 TL, 1 TR, 2 BR, 3 BL) e tamanho; -1 = nenhum.
  /// O canto do botão (TR) nunca é cortado.
  (int, double) _corte(Rect r) {
    final e = _estilo(r);
    if (e != 2 && e != 3) return (-1, 0);
    final rnd = math.Random(_semente(r) + 2);
    const cantos = [0, 2, 3];
    final canto = e == 3 ? 3 : cantos[rnd.nextInt(3)];
    return (canto, 10 + rnd.nextDouble() * 6);
  }

  /// Queimados do cartão: (lado, posição 0..1, meia largura, profundidade).
  /// Lados: 0 topo, 1 direita, 2 embaixo, 3 esquerda. O canto do botão
  /// (topo-direita) fica livre.
  List<(int, double, double, double)> _queimas(Rect r) {
    final rnd = math.Random(_semente(r) + 4);
    final e = _estilo(r);
    final n = e == 1 ? 1 + rnd.nextInt(2) : (rnd.nextDouble() < 0.35 ? 1 : 0);
    return [
      for (var i = 0; i < n; i++)
        () {
          final lado = rnd.nextInt(4);
          var pos = 0.15 + rnd.nextDouble() * 0.7;
          if (lado == 0 && pos > 0.7) pos -= 0.4;
          if (lado == 1 && pos < 0.35) pos += 0.35;
          final larg = (lado.isEven ? 0.06 : 0.14) + rnd.nextDouble() * 0.06;
          return (lado, pos, larg, 3.0 + rnd.nextDouble() * 4.0);
        }()
    ];
  }

  List<Offset> _contorno(Rect r) {
    final rnd = math.Random(_semente(r));
    final e = _estilo(r);
    final (cCanto, cTam) = _corte(r);
    double cut(int c) => cCanto == c ? cTam : 0;

    const jit = 1.7; // irregularidade máxima (px), igual para todos
    final onda = e == 5 ? 1.8 : 0.0;
    const passo = 9.0;

    double dentro() => rnd.nextDouble() * jit;
    double leve() => rnd.nextDouble() < 0.05 ? 1.5 + rnd.nextDouble() * 1.5 : 0;

    // uma mordida suave em um lado (estilo 4)
    final ladoMordida = e == 4 ? rnd.nextInt(4) : -1;
    final posMordida = 0.25 + rnd.nextDouble() * 0.5;
    final fundoMordida = 4.5 + rnd.nextDouble() * 2.5;
    double mordida(int lado, double frac) {
      if (lado != ladoMordida) return 0;
      final d = (frac - posMordida).abs();
      const larg = 0.12;
      return d < larg ? fundoMordida * 0.5 * (1 + math.cos(d / larg * math.pi)) : 0;
    }

    // queimados: mordidas irregulares na borda (mesmos pontos usados no paint)
    final queimas = _queimas(r);
    double queima(int lado, double frac, double coord) {
      var v = 0.0;
      for (final q in queimas) {
        if (q.$1 != lado) continue;
        final d = (frac - q.$2).abs();
        if (d < q.$3) {
          final k = 0.5 * (1 + math.cos(d / q.$3 * math.pi));
          // borda queimada é irregular: ondinha rápida por cima da mordida
          v += k * (q.$4 + math.sin(coord * 0.9 + q.$2 * 50) * 1.4);
        }
      }
      return v;
    }

    final p = <Offset>[];
    final w = r.width, h = r.height;
    for (var x = r.left + 6 + cut(0); x < r.right - 6 - cut(1); x += passo) {
      final f = (x - r.left) / w;
      p.add(Offset(x, r.top + dentro() + leve() + mordida(0, f) + queima(0, f, x) + math.sin(x / 9) * onda + onda));
    }
    if (cut(1) == 0) p.add(Offset(r.right - dentro(), r.top + dentro()));
    for (var y = r.top + 8 + cut(1); y < r.bottom - 6 - cut(2); y += passo) {
      final f = (y - r.top) / h;
      p.add(Offset(r.right - dentro() - leve() - mordida(1, f) - queima(1, f, y) - math.sin(y / 9) * onda - onda, y));
    }
    if (cut(2) == 0) p.add(Offset(r.right - dentro(), r.bottom - dentro()));
    for (var x = r.right - 8 - cut(2); x > r.left + 6 + cut(3); x -= passo) {
      final f = (x - r.left) / w;
      p.add(Offset(x, r.bottom - dentro() - leve() - mordida(2, f) - queima(2, f, x) - math.sin(x / 9) * onda - onda));
    }
    if (cut(3) == 0) p.add(Offset(r.left + dentro(), r.bottom - dentro()));
    for (var y = r.bottom - 8 - cut(3); y > r.top + 6 + cut(0); y -= passo) {
      final f = (y - r.top) / h;
      p.add(Offset(r.left + dentro() + leve() + mordida(3, f) + queima(3, f, y) + math.sin(y / 9) * onda + onda, y));
    }
    if (cut(0) == 0) p.add(Offset(r.left + dentro(), r.top + dentro()));
    return p;
  }

  /// Caminho suavizado: curvas pelos pontos médios, então nenhuma ponta.
  Path _caminho(Rect r) {
    final pts = _contorno(r);
    final n = pts.length;
    Offset m(int i) => (pts[i % n] + pts[(i + 1) % n]) / 2;
    final path = Path()..moveTo(m(n - 1).dx, m(n - 1).dy);
    for (var i = 0; i < n; i++) {
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, m(i).dx, m(i).dy);
    }
    return path..close();
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _caminho(rect.deflate(3));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _caminho(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final path = _caminho(rect);
    final e = _estilo(rect);
    final rnd = math.Random(_semente(rect) + 3);
    final menor = math.min(rect.width, rect.height);
    final (cCanto, cTam) = _corte(rect);

    Offset ponto(double fx, double fy) =>
        Offset(rect.left + rect.width * fx, rect.top + rect.height * fy);
    Paint traco(double larg, double a, [Color? cor]) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = larg
      ..color = (cor ?? tinta).withValues(alpha: a);

    canvas.save();
    canvas.clipPath(path);

    // Sombra de borda funda: faixas cada vez mais fortes rumo à borda.
    for (final f in const [(26.0, 0.045), (16.0, 0.07), (9.0, 0.10), (4.0, 0.16)]) {
      canvas.drawPath(path, traco(f.$1, f.$2));
    }

    // manchas de umidade suaves
    for (var i = 0; i < 2; i++) {
      final c = ponto(0.15 + rnd.nextDouble() * 0.7, 0.15 + rnd.nextDouble() * 0.7);
      final raio = menor * (0.3 + rnd.nextDouble() * 0.3);
      canvas.drawCircle(
        c,
        raio,
        Paint()
          ..shader = RadialGradient(colors: [
            tinta.withValues(alpha: 0.06),
            tinta.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: c, radius: raio)),
      );
    }

    // Amassado: grade irregular de facetas, com vincos em zigue-zague.
    // Mesmo tom e transparência para todos; só mais detalhe.
    const cols = 4, linhas = 3;
    final grade = <List<Offset>>[
      for (var j = 0; j <= linhas; j++)
        [
          for (var i = 0; i <= cols; i++)
            ponto(
              (i + (i == 0 || i == cols ? 0 : (rnd.nextDouble() - .5) * .7)) / cols,
              (j + (j == 0 || j == linhas ? 0 : (rnd.nextDouble() - .5) * .7)) / linhas,
            )
        ]
    ];
    // facetas com luz/sombra
    for (var j = 0; j < linhas; j++) {
      for (var i = 0; i < cols; i++) {
        final q = Path()
          ..moveTo(grade[j][i].dx, grade[j][i].dy)
          ..lineTo(grade[j][i + 1].dx, grade[j][i + 1].dy)
          ..lineTo(grade[j + 1][i + 1].dx, grade[j + 1][i + 1].dy)
          ..lineTo(grade[j + 1][i].dx, grade[j + 1][i].dy)
          ..close();
        final claro = rnd.nextBool();
        canvas.drawPath(
          q,
          Paint()
            ..color = claro
                ? Colors.white.withValues(alpha: 0.05)
                : tinta.withValues(alpha: 0.035),
        );
      }
    }
    // vincos entre os nós da grade (zigue-zague curto)
    Path vinco(Offset a, Offset b) {
      final mid1 = Offset.lerp(a, b, 0.33)! +
          Offset((rnd.nextDouble() - .5) * 5, (rnd.nextDouble() - .5) * 5);
      final mid2 = Offset.lerp(a, b, 0.66)! +
          Offset((rnd.nextDouble() - .5) * 5, (rnd.nextDouble() - .5) * 5);
      return Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(mid1.dx, mid1.dy)
        ..lineTo(mid2.dx, mid2.dy)
        ..lineTo(b.dx, b.dy);
    }

    for (var j = 0; j <= linhas; j++) {
      for (var i = 0; i <= cols; i++) {
        if (i < cols && j > 0 && j < linhas && rnd.nextDouble() < 0.8) {
          final v = vinco(grade[j][i], grade[j][i + 1]);
          canvas.drawPath(v, traco(1, 0.08));
          canvas.drawPath(v.shift(const Offset(1.2, 1.2)),
              traco(1, 0.12, Colors.white));
        }
        if (j < linhas && i > 0 && i < cols && rnd.nextDouble() < 0.8) {
          final v = vinco(grade[j][i], grade[j + 1][i]);
          canvas.drawPath(v, traco(1, 0.08));
          canvas.drawPath(v.shift(const Offset(1.2, 1.2)),
              traco(1, 0.12, Colors.white));
        }
        if (i < cols && j < linhas && rnd.nextDouble() < 0.35) {
          final v = vinco(grade[j][i], grade[j + 1][i + 1]);
          canvas.drawPath(v, traco(0.9, 0.06));
          canvas.drawPath(v.shift(const Offset(1, 1)),
              traco(0.9, 0.09, Colors.white));
        }
      }
    }

    // Queimado: escurecimento que nasce na borda mordida e se espalha num
    // degradê (marrom-ferrugem -> transparente), com um filete quase preto
    // acompanhando a borda e cinzas miúdas. Tudo em degradê: sem "barra".
    for (final q in _queimas(rect)) {
      final lado = q.$1, pos = q.$2;
      final centro = switch (lado) {
        0 => Offset(rect.left + rect.width * pos, rect.top),
        1 => Offset(rect.right, rect.top + rect.height * pos),
        2 => Offset(rect.left + rect.width * pos, rect.bottom),
        _ => Offset(rect.left, rect.top + rect.height * pos),
      };
      final alcance = (lado.isEven ? rect.width : rect.height) * q.$3 * 1.6 + 10;
      final area = Rect.fromCircle(center: centro, radius: alcance);
      canvas.drawCircle(
        centro,
        alcance,
        Paint()
          ..shader = const RadialGradient(colors: [
            Color(0x8C24150A),
            Color(0x5C5A3214),
            Color(0x228A5A2A),
            Color(0x00000000),
          ], stops: [0.0, 0.35, 0.65, 1.0]).createShader(area),
      );
      // filete escuro na borda, sumindo para os lados
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..shader = const RadialGradient(colors: [
            Color(0xD9140A04),
            Color(0x80140A04),
            Color(0x00140A04),
          ], stops: [0.0, 0.55, 1.0]).createShader(area),
      );
      // cinzas
      for (var f = 0; f < 5; f++) {
        final a = rnd.nextDouble() * math.pi * 2;
        final o = centro + Offset(math.cos(a), math.sin(a)) * (alcance * (0.25 + rnd.nextDouble() * 0.45));
        canvas.drawCircle(o, 0.6 + rnd.nextDouble() * 0.9,
            Paint()..color = const Color(0xFF1C1006).withValues(alpha: 0.28));
      }
    }

    // canto dobrado (orelha): triângulo no canto inferior esquerdo
    if (e == 3 && cCanto == 3) {
      final a = Offset(rect.left, rect.bottom - cTam - 4);
      final b = Offset(rect.left + cTam + 4, rect.bottom);
      final v = Offset(rect.left + cTam * 0.9, rect.bottom - cTam * 0.9);
      final tri = Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(v.dx, v.dy)
        ..lineTo(b.dx, b.dy)
        ..close();
      canvas.drawPath(tri, Paint()..color = tinta.withValues(alpha: 0.16));
      canvas.drawPath(tri, traco(1, 0.45));
    }
    canvas.restore();

    // contorno fino, cor de tinta velha
    canvas.drawPath(path, traco(1.2, 0.65));

    if (rect.shortestSide < 44) return;
    _botao(canvas, Offset(rect.right - 15, rect.top + 15), rect);
    if (estacao != null) _sazonal(canvas, rect);
  }

  /// Detalhe sazonal pequeno em um canto de parte dos cartões.
  void _sazonal(Canvas canvas, Rect rect) {
    final r = math.Random(_semente(rect) + 9);
    if (r.nextDouble() > 0.4) return;
    final p = Paint();
    switch (estacao) {
      case 3: { // neve acumulada na borda de cima
        final len = rect.width * (0.22 + r.nextDouble() * 0.25);
        final x0 = rect.left + 14 + (rect.width - len - 60) * r.nextDouble();
        if (x0 + len > rect.right - 36) return;
        final topo = rect.top + 1.5;
        final cap = Path()..moveTo(x0, topo);
        var x = x0;
        while (x < x0 + len) {
          final prof = 4 + r.nextDouble() * 4;
          cap.quadraticBezierTo(x + 5, topo + prof * 1.6, x + 10, topo);
          x += 10;
        }
        cap.close();
        canvas.drawPath(cap.shift(const Offset(0, 1.2)),
            Paint()..color = const Color(0xFF7F9BB5).withValues(alpha: 0.3));
        canvas.drawPath(cap, p..color = Colors.white.withValues(alpha: 0.95));
        break;
      }
      case 2: { // folha de outono caída no canto
        final c = Offset(r.nextBool() ? rect.left + 16 : rect.right - 38,
            rect.bottom - 13);
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-0.7 + r.nextDouble() * 1.4);
        final f = Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(8, -4, 0, -15)
          ..quadraticBezierTo(-8, -4, 0, 0);
        canvas.drawPath(
            f,
            p..color = (r.nextBool()
                    ? const Color(0xFFC8641E)
                    : const Color(0xFF9A3412))
                .withValues(alpha: 0.9));
        canvas.drawLine(
            const Offset(0, 0),
            const Offset(0, -13),
            Paint()
              ..strokeWidth = 0.8
              ..color = const Color(0xFF4A1A08).withValues(alpha: 0.6));
        canvas.restore();
        break;
      }
      case 0: { // florzinha
        final c = Offset(r.nextBool() ? rect.left + 16 : rect.right - 38,
            rect.bottom - 13);
        for (var i = 0; i < 5; i++) {
          final a = i * math.pi * 2 / 5;
          canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * 4, 3.3,
              p..color = const Color(0xFFEFA6BC).withValues(alpha: 0.95));
        }
        canvas.drawCircle(c, 2.4,
            p..color = const Color(0xFFF2C94C).withValues(alpha: 0.95));
        break;
      }
      case 1: { // solzinho
        final c = Offset(r.nextBool() ? rect.left + 16 : rect.right - 38,
            rect.bottom - 13);
        final raio = Paint()
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFE0A21A).withValues(alpha: 0.9);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * 6.5,
              c + Offset(math.cos(a), math.sin(a)) * 9.5, raio);
        }
        canvas.drawCircle(c, 4.6,
            p..color = const Color(0xFFF2B72E).withValues(alpha: 0.95));
        break;
      }
    }
  }

  /// Botão metálico dourado envelhecido com runa gravada.
  void _botao(Canvas canvas, Offset c, Rect rect) {
    const r = 8.5;
    canvas.drawCircle(c + const Offset(1.6, 2.2), r,
        Paint()..color = Colors.black.withValues(alpha: 0.3));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.4),
          colors: [Color(0xFFF3D98A), Color(0xFFC9A55A), Color(0xFF7A5A1E)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF5A4012),
    );
    canvas.drawCircle(
      c,
      r - 2.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = const Color(0xFF5A4012).withValues(alpha: 0.5),
    );
    final g = ((rect.left + rect.top).abs() ~/ 7) % 14;
    desenharGlifo(canvas, g, c, 9.5, const Color(0xFF4A3410).withValues(alpha: 0.9),
        traco: 1.3);
    canvas.drawCircle(c + const Offset(-3.2, -3.2), 1.5,
        Paint()..color = Colors.white.withValues(alpha: 0.55));
    canvas.drawLine(
      c + const Offset(2, 5),
      c + const Offset(5, 2.5),
      Paint()
        ..strokeWidth = 0.7
        ..color = const Color(0xFF3A2A0C).withValues(alpha: 0.5),
    );
  }

  @override
  ShapeBorder scale(double t) =>
      BordaPapel(
          side: side.scale(t), tinta: tinta, estacao: estacao, semente: semente);

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      BordaPapel(
          side: side ?? this.side,
          tinta: tinta,
          estacao: estacao,
          semente: semente);

  @override
  bool operator ==(Object other) =>
      other is BordaPapel &&
      other.side == side &&
      other.tinta == tinta &&
      other.estacao == estacao &&
      other.semente == semente;

  @override
  int get hashCode => Object.hash(side, tinta, estacao, semente);
}

/// Borda de papel com variação própria para um cartão ([chave] = id do item).
/// Retorna null quando os cartões de pergaminho estão desligados, então o
/// Card usa a borda do tema normalmente.
ShapeBorder? papelCom(BuildContext context, Object chave) {
  final f = Theme.of(context).cardTheme.shape;
  return f is BordaPapel ? f.comSemente(chave.hashCode) : null;
}
