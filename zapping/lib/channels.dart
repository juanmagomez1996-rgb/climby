import 'dart:math' as math;
import 'dart:ui';

import 'boss_data.dart';
import 'game.dart';
import 'gfx.dart';
import 'sfx.dart';

/// Un canal = un microjuego de ~4,5 s.
abstract class Channel {
  final ZappingGame g;
  Channel(this.g);

  String get name;
  String get sub;
  String get ins;
  String get hint;
  String get bg;
  bool get survive => false;
  bool get boss => false;
  double get dur => 4.5;

  /// Tiempo de juego (escalado por la velocidad) y tiempo visual (siempre avanza).
  double t = 0, vt = 0;
  int res = 0;
  String why = '';
  double resAt = 0;

  // Atajos de la pantalla de la tele.
  Rect get S => ZappingGame.screen;
  double get cx => S.center.dx;
  double get cy => S.center.dy;
  double get sb => S.bottom;
  double get st => S.top;
  double get sl => S.left;
  double get sr => S.right;
  Pointer get p => g.ptr;
  bool get tap => p.pressed && S.contains(Offset(p.x, p.y));

  void win() {
    if (res != 0) return;
    res = 1;
    resAt = vt;
  }

  void lose(String w) {
    if (res != 0) return;
    res = -1;
    why = w;
    resAt = vt;
  }

  /// Segundos desde que se resolvió el canal (para animaciones de cierre).
  double get since => res == 0 ? 0 : vt - resAt;

  void init(int level);
  void update(double dt);
  void render(Canvas c);

  void drawBg(Canvas c) => Gfx.cover(c, bg, ZappingGame.bleed);

  /// Convierte una fracción del fondo (imagen 4:5 recortada para cubrir la tele) a coordenadas de pantalla.
  /// Sirve para apoyar personajes justo en el suelo o la mesa que se ve en el decorado.
  // El decorado (720x900) cubre `ZappingGame.bleed` (449x488): escala 0,6236, recorte vertical de 36,6.
  double bx(double f) => sl - 14 + f * 449;
  double by(double f) => st - 50.62 + f * 561.25;

  /// Deslizamiento terminado en este frame (vector desde donde empezó), o null.
  Offset? swipe({double min = 40}) {
    if (!p.released) return null;
    final d = Offset(p.x - p.sx, p.y - p.sy);
    return d.distance >= min ? d : null;
  }

  bool get pointerIn => S.contains(Offset(p.x, p.y));
}

typedef ChannelFactory = Channel Function(ZappingGame g);

final List<ChannelFactory> channelFactories = [
  Screw.new,
  FakeArms.new,
  Gazpacho.new,
  Kitchen.new,
  Quiz.new,
  Chairs.new,
  Forbidden.new,
  Soda.new,
  EyeFishing.new,
  Glutton.new,
  Bugs.new,
  Sleepy.new,
];

// ───────────────────────── 1. CANAL TORNILLO ─────────────────────────
class Screw extends Channel {
  Screw(super.g);
  @override
  String get name => 'CANAL TORNILLO';
  @override
  String get sub => 'Atornilla la cabeza del presentador';
  @override
  String get ins => '¡ATORNILLA!';
  @override
  String get hint => 'Gira el dedo en círculos';
  @override
  String get bg => 'bg_screw';

  double a = 0, need = 0, acc = 0;
  double? pa;

  double get f => clamp01(a / need);
  // Cuerpo de 230 px apoyado en sb+12: el cuello (fin del tornillo) está al 21 % de su altura.
  // La base de la cabeza está al 93 % de su fotograma: así la cabeza tapa el tornillo y apoya en el cuello.
  static double seatY(double sb) => sb + 12 - 230 + 230 * .21 + 4 - 150 * (.93 - .5);
  double get bodyTop => sb - 205;
  double get headY => lerp(st + 105, seatY(sb), f);
  double winA = 0;
  double get shownRot {
    if (res != 1) return a;
    // al ganar gira suavemente hasta quedar derecho (vuelta completa más cercana)
    final target = (winA / tau).roundToDouble() * tau;
    final k = clamp01(since / .3);
    return lerp(winA, target, 1 - (1 - k) * (1 - k));
  }

  @override
  void init(int l) => need = tau * (1.8 + l * .3);

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.down) {
      final ang = math.atan2(p.y - headY, p.x - cx);
      if (pa != null) {
        var d = ang - pa!;
        if (d > math.pi) d -= tau;
        if (d < -math.pi) d += tau;
        final add = math.min(d.abs(), .6);
        a += add;
        acc += add;
        if (acc > .7) {
          acc = 0;
          Sfx.play('ratchet', volume: .6, minGapMs: 60);
        }
      }
      pa = ang;
    } else {
      pa = null;
    }
    if (tap) a += .3;
    if (a >= need) {
      winA = a;
      win();
      g.fx.burst(cx, headY, Pal.gold, 22);
      Sfx.play('pop');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, cx, sb - 4, 150);
    Gfx.sprite(c, 'host_body', cx, sb + 12, 230, ay: 1, sx: 1 + boil(vt, 1) * .01);
    final hy = headY;
    // al terminar, fotograma de reposo (cara de frente)
    Gfx.anim(c, 'host_head', res == 1 ? 0 : vt, cx, hy, 150, rot: shownRot);
    // guía giratoria
    if (res == 0) {
      final pnt = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xAAFFB23E);
      for (var i = 0; i < 10; i++) {
        final s0 = vt * 3 + i * tau / 12;
        c.drawArc(Rect.fromCircle(center: Offset(cx, hy), radius: 118), s0, .28, false, pnt);
      }
      final ar = vt * 3 + tau * 10 / 12;
      Gfx.clayBall(c, cx + math.cos(ar) * 118, hy + math.sin(ar) * 118, 12, Pal.gold);
    }
    Gfx.clayBar(c, Rect.fromLTWH(sl + 36, sb - 30, S.width - 72, 16), f, Pal.gold);
  }
}

// ───────────────────────── 2. BRAZOS FALSOS S.L. ─────────────────────────
class FakeArms extends Channel {
  FakeArms(super.g);
  @override
  String get name => 'BRAZOS FALSOS S.L.';
  @override
  String get sub => 'Pulsa cuando el brazo encaje';
  @override
  String get ins => '¡ENCAJA!';
  @override
  String get hint => 'Toca en el momento justo';
  @override
  String get bg => 'bg_arms';

  double spd = 0, ph = 0, ax = 0;
  static const custH = 290.0;
  double get custX => cx + 70;
  double get sockX => custX - custH * Gfx.aspect('customer') * (.5 - .077);
  double get sockY => sb - 8 - custH * (1 - .388);

  @override
  void init(int l) {
    spd = 2.4 + l * .5 + rnd(0, .6);
    ph = rnd(0, tau);
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    ax = sockX + math.sin(t * spd + ph) * 140;
    if (tap) {
      if ((ax - sockX).abs() < 24) {
        ax = sockX;
        win();
        g.fx.burst(sockX, sockY, Pal.teal, 20);
        Sfx.play('pop');
      } else {
        lose('Brazo en la oreja');
        Sfx.play('boing');
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final ok = res == 1;
    Gfx.shadow(c, custX, sb - 8, 190);
    Gfx.sprite(c, 'customer', custX, sb - 8, custH,
        ay: 1, sy: 1 + boil(vt, 2) * .012 + (ok ? math.sin(since * 20) * .03 * clamp01(1 - since) : 0));
    // diana
    if (res == 0) {
      final pulse = 1 + math.sin(vt * 8) * .12;
      c.drawCircle(
          Offset(sockX, sockY),
          24 * pulse,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = Pal.gold);
      Gfx.text(c, 'AQUÍ', sockX - 40, sockY - 44, 18, color: Pal.gold);
    }
    // brazo colgando de un cable
    const armH = 175.0;
    final drop = res == 0 ? 0.0 : clamp01(since / .22);
    final topY = res == 1
        ? lerp(st + 24, sockY - 12, drop)
        : res == -1
            ? lerp(st + 24, sb - armH - 4, drop)
            : st + 24 + boil(vt, 3) * 2;
    final rot = res == -1 ? drop * .5 : math.sin(vt * spd * 2) * .05;
    c.drawLine(Offset(ax, st - 10), Offset(ax, topY + 4),
        Paint()
          ..strokeWidth = 4
          ..color = const Color(0xFF999999));
    Gfx.sprite(c, 'arm', ax, topY, armH, ay: 0, rot: rot);
    Gfx.text(c, '¡SOLO 3,99 GALAXICRÉDITOS!', cx, sb - 26, 18, color: Pal.gold);
  }
}

// ───────────────────── 3. NOTICIAS DE PLANETA GAZPACHO ─────────────────────
class _Tomato {
  double x, y, r, rot, vr;
  _Tomato(this.x, this.y, this.r) : rot = rnd(0, tau), vr = rnd(-5, 5);
}

class Gazpacho extends Channel {
  Gazpacho(super.g);
  @override
  String get name => 'NOTICIAS DE PLANETA GAZPACHO';
  @override
  String get sub => 'Esquiva los tomates';
  @override
  String get ins => '¡ESQUIVA!';
  @override
  String get hint => 'Arrastra a izquierda y derecha';
  @override
  String get bg => 'bg_gazpacho';
  @override
  bool get survive => true;

  double px = 0, cd = .3, rate = 0, vy = 0;
  final tom = <_Tomato>[];
  final splats = <Offset>[];
  double get py => sb - 62;

  @override
  void init(int l) {
    px = cx;
    rate = .36 / (1 + l * .25);
    vy = 300 + l * 50;
  }

  @override
  void update(double dt) {
    if (p.down && S.contains(Offset(p.x, p.y))) {
      px = lerp(px, p.x, 1 - math.exp(-dt * 14));
    }
    px = px.clamp(sl + 40, sr - 40);
    if ((cd -= dt) <= 0) {
      cd = rate;
      tom.add(_Tomato(rnd(sl + 28, sr - 28), st - 20, rnd(18, 25)));
      if (rng.nextDouble() < .4) tom.add(_Tomato(px + rnd(-20, 20), st - 60, 22));
    }
    for (final o in tom) {
      o.y += vy * dt;
      o.rot += o.vr * dt;
      if (res == 0 && dist(o.x, o.y, px, py) < o.r + 30) {
        lose('¡Tomatazo!');
        g.fx.burst(o.x, o.y, Pal.tomato, 26);
        g.fx.shake(8);
        Sfx.play('splat');
        splats.add(Offset(o.x, o.y));
        o.y = 9999;
      }
    }
    tom.removeWhere((o) => o.y > sb + 40);
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final hit = res == -1;
    Gfx.shadow(c, px, sb - 10, 80);
    Gfx.anim(c, 'reporter', vt, px, sb - 10, 118,
        ay: 1, rot: hit ? math.sin(since * 30) * .15 : (px - cx) * .0006);
    for (final s in splats) {
      Gfx.sprite(c, 'splat', s.dx, s.dy, 96, rot: .3);
    }
    for (final o in tom) {
      final near = clamp01((o.y - st) / (sb - st));
      Gfx.shadow(c, o.x, sb - 10, o.r * 2 * (.4 + .6 * near), alpha: .1 + .3 * near);
      Gfx.sprite(c, 'tomato', o.x, o.y, o.r * 2.3, rot: o.rot);
    }
    // rótulo de noticias
    final band = Rect.fromLTWH(sl, st + 16, S.width, 36);
    c.drawRect(band, Paint()..color = const Color(0xCC120D1A));
    c.drawRect(Rect.fromLTWH(sl, st + 16, 92, 36), Paint()..color = Pal.pink);
    Gfx.text(c, 'EN VIVO', sl + 46, st + 34, 15, outline: false, color: Pal.ink);
    c.save();
    c.clipRect(Rect.fromLTWH(sl + 92, st + 16, S.width - 92, 36));
    final off = (vt * 90) % 520;
    for (var k = 0; k < 2; k++) {
      Gfx.text(c, 'ÚLTIMA HORA: LLUEVEN TOMATES OTRA VEZ ·', sl + 100 - off + k * 520, st + 34, 15,
          font: kBody, color: Pal.gold, align: 0, outline: false);
    }
    c.restore();
  }
}

// ───────────────────────── 4. COCINA CON BLORP ─────────────────────────
class _Item {
  double x;
  final bool finger;
  final String spr;
  bool cut = false;
  _Item(this.x, this.finger, this.spr);
}

class Kitchen extends Channel {
  Kitchen(super.g);
  @override
  String get name => 'COCINA CON BLORP';
  @override
  String get sub => 'Corta verduras, no dedos';
  @override
  String get ins => '¡CORTA!';
  @override
  String get hint => 'Toca cuando pasen bajo el cuchillo';
  @override
  String get bg => 'bg_kitchen';

  double spd = 0, chop = 0;
  int cut = 0;
  final items = <_Item>[];
  double get iy => st + 262;

  @override
  void init(int l) {
    spd = 240 + l * 35;
    for (var i = 0; i < 12; i++) {
      final f = i > 0 && rng.nextDouble() < .35 && i % 3 != 1;
      items.add(_Item(sl - 60 - i * 135, f,
          f ? 'finger' : pick(['veg_carrot', 'veg_eggplant', 'veg_cucumber', 'veg_radish'])));
    }
  }

  @override
  void update(double dt) {
    for (final it in items) {
      it.x += spd * dt * (it.cut ? .6 : 1);
    }
    chop = math.max(0, chop - dt * 5);
    if (tap && res == 0) {
      chop = 1;
      Sfx.play('chop');
      _Item? hit;
      for (final it in items) {
        if (!it.cut && (it.x - cx).abs() < 50) {
          hit = it;
          break;
        }
      }
      if (hit != null) {
        hit.cut = true;
        if (hit.finger) {
          lose('¡Ese era un dedo!');
          g.fx.burst(hit.x, iy, Pal.pink, 24);
          g.fx.shake(6);
          Sfx.play('splat');
        } else {
          cut++;
          g.fx.burst(hit.x, iy, Pal.lime, 14, size: 5);
          if (cut >= 3) win();
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'chef', vt, sl + 62, st + 150, 160, ay: 1);
    for (final it in items) {
      if (it.x < sl - 70 || it.x > sr + 70) continue;
      final h = it.finger ? 36.0 : 42.0;
      if (!it.cut) {
        Gfx.shadow(c, it.x, iy + h * .42, h * Gfx.aspect(it.spr) * .85, ratio: .22);
        Gfx.sprite(c, it.spr, it.x, iy + boil(vt, it.x) * 1.5, h);
      } else {
        // dos mitades separadas
        final w = h * Gfx.aspect(it.spr);
        for (final side in [-1, 1]) {
          c.save();
          c.clipRect(side < 0
              ? Rect.fromLTWH(it.x - w, iy - 60, w, 120)
              : Rect.fromLTWH(it.x, iy - 60, w, 120));
          c.translate(side * 10.0, 0);
          Gfx.sprite(c, it.spr, it.x, iy, h, rot: side * .12);
          c.restore();
        }
        if (it.finger) Gfx.sprite(c, 'splat', it.x, iy, 60);
      }
    }
    final ky = lerp(st + 105, iy - 20, chop);
    Gfx.sprite(c, 'knife', cx, ky, 150, ay: .9);
    Gfx.text(c, '$cut/3', sr - 20, st + 36, 32, color: Pal.gold, align: 1);
  }
}

// ───────────────────────── 5. CONCURSO SÍ O NO ─────────────────────────
const _questions = [
  ('¿Un gato cabe dentro de un planeta?', 1), ('¿Las sillas pueden votar?', 0),
  ('¿2 + 2 son 4?', 1), ('¿El agua está seca?', 0), ('¿Tienes dedos en los pies?', 1),
  ('¿Un lunes es un tipo de queso?', 0), ('¿Esto es la tele?', 1), ('¿Los tomates conducen?', 0),
  ('¿El fuego quema?', 1), ('¿Una hora tiene 7 minutos?', 0),
  ('¿La luna es más grande que una uva?', 1), ('¿Los peces respiran por las orejas?', 0),
  ('¿La plastilina se puede moldear?', 1), ('¿Los calcetines tienen hambre?', 0),
];

class Quiz extends Channel {
  Quiz(super.g);
  @override
  String get name => 'CONCURSO SÍ O NO';
  @override
  String get sub => 'Responde rápido';
  @override
  String get ins => '¡RESPONDE!';
  @override
  String get hint => 'Toca SÍ o NO';
  @override
  String get bg => 'bg_quiz';

  String q = '';
  int ans = 0, picked = -1;
  double get bw => S.width / 2 - 24;
  Rect get yes => Rect.fromLTWH(sl + 16, sb - 24 - bw * kButtonAspect, bw, bw * kButtonAspect);
  Rect get no => Rect.fromLTWH(cx + 8, sb - 24 - bw * kButtonAspect, bw, bw * kButtonAspect);

  @override
  void init(int l) {
    final pq = pick(_questions);
    q = pq.$1;
    ans = pq.$2;
  }

  @override
  void update(double dt) {
    if (res != 0 || !p.pressed) return;
    var ch = -1;
    if (yes.contains(Offset(p.x, p.y))) ch = 1;
    if (no.contains(Offset(p.x, p.y))) ch = 0;
    if (ch < 0) return;
    picked = ch;
    if (ch == ans) {
      win();
      g.fx.burst((ch == 1 ? yes : no).center.dx, sb - 86, Pal.gold, 20);
    } else {
      lose('¡Respuesta incorrecta!');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'quizhost', vt, cx, st + 118, 118, ay: 1);
    final card = Rect.fromLTWH(sl + 26, st + 128, S.width - 52, 116);
    Gfx.clayPanel(c, card, const Color(0xFFF7F1E3));
    Gfx.text(c, q, cx, card.center.dy, 30,
        color: const Color(0xFF6A3FA0), maxW: card.width - 40, fitH: card.height - 30);
    void btn(Rect r, String img, String label, int v) {
      final sel = picked == v;
      final s = sel ? 1.08 : 1 + math.sin(vt * 6 + v) * .015;
      Gfx.button(c, img, label, r, scale: s, size: 56);
    }

    btn(yes, 'btn_teal', 'SÍ', 1);
    btn(no, 'btn_pink', 'NO', 0);
  }
}

// ───────────────────────── 6. LUCHA DE SILLAS ─────────────────────────
class Chairs extends Channel {
  Chairs(super.g);
  @override
  String get name => 'LUCHA DE SILLAS';
  @override
  String get sub => 'Siéntate cuando pare la música';
  @override
  String get ins => '¡ESPERA Y SIÉNTATE!';
  @override
  String get hint => 'Toca cuando pare la música';
  @override
  String get bg => 'bg_chairs';

  double stop = 0, window = 0, noteCd = 0;
  bool me = false;
  bool get on => t < stop;
  double get seatY => cy + 92;

  @override
  void init(int l) {
    stop = rnd(1.1, 2.8);
    window = .75 / (1 + l * .2);
  }

  @override
  void update(double dt) {
    if (on && (noteCd -= dt) <= 0) {
      noteCd = .22;
      Sfx.play('note${rng.nextInt(4)}', volume: .7);
    }
    if (tap && res == 0) {
      if (on) {
        lose('¡La música seguía!');
      } else {
        me = true;
        win();
        g.fx.burst(cx, seatY, Pal.gold, 20);
        Sfx.play('squish');
      }
    }
    if (!on && t > stop + window) lose('Te han quitado la silla');
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // Los dos corren en círculo alrededor de la silla: cuando pasan por detrás (más arriba en el suelo)
    // se dibujan antes que la silla y algo más pequeños; cuando pasan por delante, encima y más grandes.
    final floorY = cy + 150;
    final rv = on ? 0.0 : clamp01((t - stop) / window);
    final a = t * 3;
    double hop(double s) => -(math.sin(vt * 14 + s).abs()) * 10;
    final items = <(double, void Function())>[];
    void runner(String spr, double x, double depth, double h, double seed, {double? yOverride, bool bounce = true}) {
      final y = yOverride ?? floorY + depth * 34;
      final k = 1 + depth * .1;
      items.add((depth, () {
        Gfx.shadow(c, x, y, h * .7 * k);
        Gfx.sprite(c, spr, x, y + (bounce ? hop(seed) : 0), h * k, ay: 1);
      }));
    }

    items.add((0, () {
      Gfx.shadow(c, cx, floorY, 130);
      Gfx.sprite(c, 'chair', cx, floorY, 165, ay: 1);
    }));
    if (me) {
      items.add((.5, () => Gfx.sprite(c, 'player', cx, seatY + 6, 92, ay: 1, sy: 1 - clamp01(since * 5) * .08)));
    } else if (on) {
      runner('player', cx + math.cos(a) * 140, math.sin(a), 88, 0);
    } else {
      runner('player', lerp(cx + math.cos(stop * 3) * 140, cx + 120, rv), lerp(math.sin(stop * 3), .6, rv), 88, 0, bounce: false);
    }
    if (!me) {
      if (on) {
        runner('rival', cx - math.cos(a) * 140, -math.sin(a), 94, 1);
      } else {
        final x0 = cx - math.cos(stop * 3) * 140, d0 = -math.sin(stop * 3);
        final y = lerp(floorY + d0 * 34, seatY + 6, rv);
        runner('rival', lerp(x0, cx, rv), rv > .5 ? .5 : d0, 94, 1, yOverride: y, bounce: false);
      }
    }
    items.sort((p, q) => p.$1.compareTo(q.$1));
    for (final it in items) {
      it.$2();
    }
    if (on) {
      for (var i = 0; i < 4; i++) {
        Gfx.note(c, sl + 60 + i * 100, st + 80 + math.sin(vt * 6 + i) * 18, 38,
            [Pal.gold, Pal.teal, Pal.pink, Pal.lime][i]);
      }
    } else {
      Gfx.text(c, '¡YA!', cx, st + 90, 72, color: Pal.lime, scale: 1 + math.max(0.0, .3 - (t - stop)) * 2);
    }
    Gfx.text(c, 'TÚ ERES EL AZUL', cx, sb - 22, 18, color: Pal.teal);
  }
}

// ───────────────────────── 7. TELETIENDA PROHIBIDA ─────────────────────────
class Forbidden extends Channel {
  Forbidden(super.g);
  @override
  String get name => 'TELETIENDA PROHIBIDA';
  @override
  String get sub => 'Ni se te ocurra';
  @override
  String get ins => '¡NO TOQUES!';
  @override
  String get hint => 'No hagas nada';
  @override
  String get bg => 'bg_forbidden';
  @override
  bool get survive => true;

  String msg = '';

  @override
  void init(int l) => msg = pick(['TÓCAME', 'GRATIS', 'PORFA', 'SOLO UNA VEZ', 'NADIE MIRA', 'ES BLANDITO']);

  @override
  void update(double dt) {
    if (tap && res == 0) {
      lose('¡Lo has tocado!');
      g.fx.burst(cx, cy + 40, Pal.pink, 30);
      g.fx.shake(10);
      Sfx.play('boing');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final pulse = 1 + math.sin(vt * 5) * .05;
    final squash = res == -1 ? 1 - clamp01(since * 6) * .35 : 1.0;
    Gfx.shadow(c, cx, sb - 72, 230 * pulse, alpha: .45);
    Gfx.anim(c, 'redbutton', vt, cx + math.sin(vt * 30) * 3, sb - 70, 220 * pulse,
        ay: 1, sy: squash, sx: 2 - squash);
    Gfx.text(c, msg, cx, st + 70, 44, color: Pal.gold, rot: math.sin(vt * 4) * .05);
    Gfx.text(c, 'pulsa pulsa pulsa', cx + math.sin(vt * 9) * 18, st + 122, 22, font: kBody);
  }
}

// ───────────────────────── 8. REFRESCO PLASMA ─────────────────────────
class Soda extends Channel {
  Soda(super.g);
  @override
  String get name => 'REFRESCO PLASMA';
  @override
  String get sub => 'Agítalo hasta que explote';
  @override
  String get ins => '¡AGITA!';
  @override
  String get hint => 'Arrastra muy rápido';
  @override
  String get bg => 'bg_soda';

  double v = 0, need = 0, off = 0, fizz = 0;
  double get f => clamp01(v / need);

  @override
  void init(int l) => need = 2300 + l * 350;

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.down) {
      final d = p.dx.abs() + p.dy.abs();
      v += d;
      off = (off + p.dx * .5).clamp(-60, 60);
      if (d > 20) Sfx.play('shake', volume: .6, minGapMs: 90);
    }
    if (tap) v += 60;
    off *= math.pow(.002, dt).toDouble();
    if ((fizz -= dt) <= 0 && f > .1) {
      fizz = .12 / (f + .2);
      g.fx.blobs.add(Blob(cx + off + rnd(-30, 30), cy - 110, rnd(-40, 40), rnd(-260, -120),
          rnd(3, 7), .6, const Color(0xFFDFFFB0)));
    }
    if (v >= need) {
      win();
      g.fx.burst(cx, cy - 100, Pal.lime, 46, speed: 560, size: 9);
      g.fx.shake(12);
      Sfx.play('boom');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final j = rnd(-f, f) * 8;
    final fly = res == 1 ? -since * since * 1800 : 0.0;
    if (res != 1) Gfx.shadow(c, cx + off, cy + 150, 110);
    Gfx.sprite(c, 'soda', cx + off + j, cy + 150 + fly, 270,
        ay: 1, rot: off * .004 + j * .01, sy: 1 + f * .06, sx: 1 - f * .03);
    Gfx.clayBar(c, Rect.fromLTWH(sl + 36, sb - 34, S.width - 72, 20), f, Pal.lime);
  }
}

// ───────────────────────── 9. PESCA DE OJOS ─────────────────────────
class EyeFishing extends Channel {
  EyeFishing(super.g);
  @override
  String get name => 'PESCA DE OJOS';
  @override
  String get sub => 'Atrapa el ojo fugitivo';
  @override
  String get ins => '¡ATRAPA!';
  @override
  String get hint => 'Toca el ojo';
  @override
  String get bg => 'bg_fishing';

  double x = 0, y = 0, vx = 0, vy = 0;

  @override
  void init(int l) {
    final a = rnd(0, tau), s = 290 + l * 50.0;
    x = cx;
    y = cy;
    vx = math.cos(a) * s;
    vy = math.sin(a) * s;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    x += vx * dt;
    y += vy * dt;
    if (x < sl + 40 || x > sr - 40) {
      vx = -vx;
      x = x.clamp(sl + 40, sr - 40);
    }
    if (y < st + 40 || y > sb - 40) {
      vy = -vy;
      y = y.clamp(st + 40, sb - 40);
    }
    if (rng.nextDouble() < .02) {
      final a = rnd(0, tau), s = math.sqrt(vx * vx + vy * vy);
      vx = math.cos(a) * s;
      vy = math.sin(a) * s;
    }
    if (tap) {
      if (dist(p.x, p.y, x, y) < 58) {
        win();
        g.fx.burst(x, y, const Color(0xFFFFFFFF), 24);
        Sfx.play('pop');
      } else {
        g.fx.float('¡casi!', p.x, p.y, Pal.dim, 20);
        vx *= 1.1;
        vy *= 1.1;
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // nervio
    final sp = math.max(1.0, math.sqrt(vx * vx + vy * vy));
    final nx = -vx / sp, ny = -vy / sp;
    final path = Path()..moveTo(x + nx * 30, y + ny * 30);
    for (var i = 1; i <= 6; i++) {
      final d = 30 + i * 10.0;
      final w = math.sin(vt * 16 + i) * 5;
      path.lineTo(x + nx * d - ny * w, y + ny * d + nx * w);
    }
    c.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFFC0203A));
    final sq = res == 1 ? clamp01(1 - since * 4) : 1.0;
    final near = clamp01((y - st) / (sb - st));
    Gfx.shadow(c, x, by(.9), 80 * (.4 + .6 * near) * sq, alpha: .1 + .25 * near);
    Gfx.sprite(c, 'eyeball', x, y, 92 * sq,
        rot: math.atan2(vy, vx) * .15 + boil(vt, 4) * .05);
  }
}

// ───────────────────────── 10. EL GLOTÓN DE LAS TRES ─────────────────────────
class Glutton extends Channel {
  Glutton(super.g);
  @override
  String get name => 'EL GLOTÓN DE LAS TRES';
  @override
  String get sub => 'Dale la hamburguesa';
  @override
  String get ins => '¡DALE DE COMER!';
  @override
  String get hint => 'Arrastra la hamburguesa a su boca';
  @override
  String get bg => 'bg_diner';

  double hx = 0, hy = 0, mx = 0, spd = 0;
  bool grab = false;
  static const gh = 200.0;
  double get gy => st + 20;
  Offset get mouth => Offset(mx, gy + gh * .42);

  @override
  void init(int l) {
    hx = cx;
    hy = sb - 70;
    mx = cx;
    spd = 1.6 + l * .4;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    mx = cx + math.sin(t * spd) * 120;
    if (p.pressed && dist(p.x, p.y, hx, hy) < 80) grab = true;
    if (!p.down) grab = false;
    if (grab) {
      hx = p.x;
      hy = p.y;
    }
    hx = hx.clamp(sl + 30, sr - 30);
    hy = hy.clamp(st + 30, sb - 30);
    if (dist(hx, hy, mouth.dx, mouth.dy) < 55) {
      win();
      g.fx.burst(mouth.dx, mouth.dy, Pal.gold, 24);
      Sfx.play('gulp');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    if (res == 1) {
      final b = 1 + math.sin(since * 22) * .05 * clamp01(1 - since);
      Gfx.shadow(c, mx, gy + gh - 6, 150);
      Gfx.sprite(c, 'glutton_chew', mx, gy, gh, ay: 0, sx: b, sy: 2 - b);
    } else {
      Gfx.shadow(c, mx, gy + gh - 6, 150);
      Gfx.anim(c, 'glutton_open', vt, mx, gy, gh, ay: 0);
    }
    if (res != 1) {
      Gfx.sprite(c, 'burger', hx, hy, grab ? 86 : 78, rot: boil(vt, 5) * .04, drop: grab ? const Offset(10, 26) : const Offset(4, 8));
    }
    Gfx.text(c, 'MÉTELA EN LA BOCA', cx, sb - 18, 16, font: kBody, color: Pal.ink);
  }
}

// ───────────────────────── 11. BICHOS DE OFERTA ─────────────────────────
class _Bug {
  double x, y, a, s;
  bool dead = false;
  double rot = rnd(0, tau);
  _Bug(this.x, this.y, this.a, this.s);
}

class Bugs extends Channel {
  Bugs(super.g);
  @override
  String get name => 'BICHOS DE OFERTA';
  @override
  String get sub => 'Aplasta todos los bichos';
  @override
  String get ins => '¡APLASTA!';
  @override
  String get hint => 'Toca los bichos';
  @override
  String get bg => 'bg_bugs';

  final bugs = <_Bug>[];

  @override
  void init(int l) {
    final n = math.min(3 + l, 6);
    for (var i = 0; i < n; i++) {
      bugs.add(_Bug(rnd(sl + 60, sr - 60), rnd(st + 90, sb - 60), rnd(0, tau), 110 + l * 25.0));
    }
  }

  @override
  void update(double dt) {
    for (final b in bugs) {
      if (b.dead) continue;
      b.a += rnd(-3, 3) * dt;
      b.x += math.cos(b.a) * b.s * dt;
      b.y += math.sin(b.a) * b.s * dt;
      if (b.x < sl + 30 || b.x > sr - 30) b.a = math.pi - b.a;
      if (b.y < st + 80 || b.y > sb - 30) b.a = -b.a;
      b.x = b.x.clamp(sl + 30, sr - 30);
      b.y = b.y.clamp(st + 80, sb - 30);
    }
    if (tap) {
      for (final b in bugs) {
        if (!b.dead && dist(p.x, p.y, b.x, b.y) < 48) {
          b.dead = true;
          g.fx.burst(b.x, b.y, const Color(0xFF7A9A2A), 14, size: 5);
          g.fx.shake(3, .1);
          Sfx.play('squish');
          Sfx.haptic();
          break;
        }
      }
    }
    if (res == 0 && bugs.every((b) => b.dead)) win();
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (final b in bugs.where((b) => b.dead)) {
      Gfx.sprite(c, 'bug_dead', b.x, b.y, 78, rot: b.rot, drop: const Offset(2, 3));
    }
    for (final b in bugs.where((b) => !b.dead)) {
      Gfx.sprite(c, 'bug', b.x, b.y, 72, drop: const Offset(5, 8),
          rot: b.a + math.pi / 2 + boil(vt * 2, b.s) * .12, sx: 1 + boil(vt * 2, b.y) * .05);
    }
    Gfx.text(c, 'QUEDAN ${bugs.where((b) => !b.dead).length}', cx, st + 40, 26, color: Pal.pink);
  }
}

// ───────────────────────── 12. EL TIEMPO CON DORMILÓN ─────────────────────────
class Sleepy extends Channel {
  Sleepy(super.g);
  @override
  String get name => 'EL TIEMPO CON DORMILÓN';
  @override
  String get sub => 'Despierta al meteorólogo';
  @override
  String get ins => '¡DESPIERTA!';
  @override
  String get hint => 'Toca muy rápido';
  @override
  String get bg => 'bg_weather';

  double n = 0, need = 0, hit = 0;
  double get f => clamp01(n / need);

  @override
  void init(int l) => need = 10.0 + l * 2;

  @override
  void update(double dt) {
    hit = math.max(0, hit - dt * 6);
    if (tap && res == 0) {
      n++;
      hit = 1;
      Sfx.play('eh', volume: .7);
      g.fx.float('¡EH!', rnd(sl + 60, sr - 60), rnd(st + 100, cy), Pal.gold, 26);
      if (n >= need) {
        win();
        g.fx.shake(8);
        g.fx.burst(cx + 70, cy, Pal.gold, 30);
        Sfx.play('boing');
      }
    }
    if (res == 0) n = math.max(0, n - dt * .8);
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final x = cx + 70 + hit * rnd(-8, 8);
    if (res == 1) {
      final j = math.max(0.0, math.sin(clamp01(since * 3) * math.pi)) * 40;
      Gfx.sprite(c, 'weather_awake', x, sb + 20 - j, 270, ay: 1);
    } else {
      Gfx.anim(c, 'weather_sleep', vt, x, sb + 20, 270, ay: 1, fps: 10);
      Gfx.text(c, 'Zzz', cx + 130, cy - 70 - math.sin(vt * 3) * 10, 36, rot: -.15);
    }
    Gfx.clayBar(c, Rect.fromLTWH(sl + 36, sb - 30, S.width - 72, 18), f, Pal.gold);
  }
}

// ───────────────────────── JEFE: EL PRESENTADOR COLOSAL ─────────────────────────
class BossEye {
  final double fx, fy;
  bool open = false;
  double t;
  BossEye(this.fx, this.fy) : t = rnd(.3, 1.2);
}

class Boss extends Channel {
  Boss(super.g);
  @override
  String get name => 'JEFE: EL PRESENTADOR COLOSAL';
  @override
  String get sub => 'Toca sus ojos cuando estén abiertos';
  @override
  String get ins => '¡A LOS OJOS!';
  @override
  String get hint => 'Toca los ojos abiertos';
  @override
  String get bg => 'bg_boss';
  @override
  bool get boss => true;
  @override
  double get dur => 9;

  int hp = 0, maxHp = 0;
  double flash = 0;
  // Las cuencas son huecos de la animación; su posición en cada fotograma está en boss_data.dart.
  final eyes = [BossEye(.314, .435), BossEye(.493, .268), BossEye(.686, .435)];
  static const bh = 330.0;
  double get bw => bh * Gfx.aspect('boss');
  int get frame => (vt * 12).floor() % kBossSockets.length;
  Offset eyePos(BossEye e) {
    final s = kBossSockets[frame][eyes.indexOf(e)];
    return Offset(cx - bw / 2 + s.$1 * bw, cy + 20 - bh / 2 + s.$2 * bh);
  }

  double eyeSize(BossEye e) => kBossSockets[frame][eyes.indexOf(e)].$3 * bw * 2 * 1.3;

  @override
  void init(int l) {
    hp = maxHp = 6 + l;
  }

  @override
  void update(double dt) {
    flash = math.max(0, flash - dt * 4);
    for (final e in eyes) {
      e.t -= dt;
      if (e.t <= 0) {
        e.open = !e.open;
        e.t = e.open ? rnd(.5, .9) : rnd(.4, 1.3);
      }
    }
    if (tap && res == 0) {
      for (final e in eyes) {
        final o = eyePos(e);
        if (e.open && dist(p.x, p.y, o.dx, o.dy) < 50) {
          e.open = false;
          e.t = rnd(.5, 1.1);
          hp--;
          flash = 1;
          g.fx.burst(o.dx, o.dy, Pal.pink, 20);
          g.fx.shake(8, .15);
          Sfx.play('bosshit');
          Sfx.haptic(strong: true);
          if (hp <= 0) win();
          break;
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    if (flash > .5) c.drawRect(S, Paint()..color = const Color(0x66FF2050));
    final dying = res == 1 ? clamp01(since * 2) : 0.0;
    c.save();
    c.translate(cx, cy + 20);
    c.rotate(dying * math.sin(vt * 40) * .1);
    c.scale(1 - dying * .4);
    c.translate(-cx, -(cy + 20));
    // el golpe aplasta toda la cara (ojos incluidos)
    c.translate(cx, cy + 20);
    c.scale(1 + flash * .05, 1 - flash * .04);
    c.translate(-cx, -(cy + 20));
    // primero los ojos, detrás: se ven a través de las cuencas huecas
    for (final e in eyes) {
      final o = eyePos(e), d = eyeSize(e);
      if (e.open) {
        Gfx.sprite(c, 'boss_eye', o.dx, o.dy, d, rot: math.sin(vt * 3 + e.fx * 9) * .5);
      } else {
        Gfx.sprite(c, 'boss_eye_closed', o.dx, o.dy, d);
      }
    }
    Gfx.anim(c, 'boss', vt, cx, cy + 20, bh);
    c.restore();
    Gfx.clayBar(c, Rect.fromLTWH(sl + 36, st + 20, S.width - 72, 20), hp / maxHp, Pal.pink);
  }
}
