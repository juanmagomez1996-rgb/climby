import 'dart:math' as math;
import 'dart:ui';

import 'channels.dart';
import 'game.dart';
import 'gfx.dart';
import 'sfx.dart';

// Canales 31–60 (ver docs/canales_31_60.md). Cada uno con una mecánica que no se repite en los 30
// primeros. Las posiciones bx/by están medidas sobre cada decorado para que todo pise su suelo.

final List<ChannelFactory> extraChannels = [
  Inspector.new, Meatballs.new, GrannyScooter.new, JetChicken.new, ShellGame.new,
  SockPairs.new, Matryoshka.new, SausageThrow.new, Crossing.new, CloudSheep.new,
  DivaSpot.new, Grandpa.new, WhatChanged.new, SealBall.new, FireJelly.new,
  WormBand.new, SnailRace.new, PeelBanana.new, Chameleon.new, ShadowPuppets.new,
  MonsterBar.new, BombWires.new, PizzaToss.new, ItchyBear.new, CinemaSneeze.new,
  CrocDentist.new, HotelLift.new, ToyTrain.new, MirrorRobot.new, MarketScale.new,
];

/// Decorado panorámico que se desplaza: se repite en espejo (sin costuras) y cubre la tele.
void scrollBg(Canvas c, String name, double offset) {
  final im = Gfx.img[name]!;
  final r = ZappingGame.bleed;
  final s = r.height / im.height;
  final w = im.width * s;
  final src = Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
  final paint = Paint()..filterQuality = FilterQuality.medium;
  final o = offset % (2 * w);
  var x = r.left - o;
  var k = 0;
  while (x < r.right) {
    if (x + w > r.left) {
      c.save();
      if (k.isOdd) {
        c.translate(x + w, r.top);
        c.scale(-1, 1);
        c.drawImageRect(im, src, Rect.fromLTWH(0, 0, w, r.height), paint);
      } else {
        c.drawImageRect(im, src, Rect.fromLTWH(x, r.top, w, r.height), paint);
      }
      c.restore();
    }
    x += w;
    k++;
  }
}

// ───────────────────────── 31. EL INSPECTOR BIGOTES (lupa) ─────────────────────────
class _Guest {
  final String spr;
  Offset o;
  final double h;
  final bool flip;
  _Guest(this.spr, this.o, this.h, this.flip);
}

class Inspector extends Channel {
  Inspector(super.g);
  @override
  String get name => 'EL INSPECTOR BIGOTES';
  @override
  String get sub => 'Alguien roba calcetines en la fiesta';
  @override
  String get ins => '¡BUSCA AL LADRÓN!';
  @override
  String get hint => 'Arrastra la lupa y déjala sobre él';
  @override
  String get bg => 'bg_party';
  @override
  double get dur => 7;

  final guests = <_Guest>[];
  late final _Guest _thief;
  Offset lens = Offset.zero;
  Offset thiefTo = Offset.zero;
  double hold = 0, sneak = 0, thiefSpd = 0;

  Offset spot() => Offset(bx(rnd(.12, .88)), by(rnd(.64, .9)));

  /// Centro del cuerpo del ladrón (para los tests con bot).
  Offset get thiefBody => _thief.o.translate(0, -_thief.h * .5);

  @override
  void init(int l) {
    lens = Offset(cx, cy - 40);
    final pool = ['player', 'rival', 'cloneA', 'cloneB', 'guest_top', 'guest_curly', 'guest_cowboy', 'guest_bald']..shuffle(rng);
    final spots = <Offset>[];
    while (spots.length < 7) {
      final s = spot();
      if (spots.every((o) => (o - s).distance > 70)) spots.add(s);
    }
    for (var i = 0; i < 6; i++) {
      guests.add(_Guest(pool[i], spots[i], rnd(78, 96), rng.nextBool()));
    }
    _thief = _Guest('thief', spots[6], 82, rng.nextBool());
    thiefTo = _thief.o;
    thiefSpd = 30 + l * 12;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.down && pointerIn) lens = Offset.lerp(lens, Offset(p.x, p.y - 10), 1 - math.exp(-dt * 16))!;
    // el ladrón se escabulle de un sitio a otro
    if ((sneak -= dt) <= 0) {
      sneak = rnd(1.2, 2.2);
      thiefTo = spot();
    }
    final d = thiefTo - _thief.o;
    if (d.distance > 2) _thief.o += d / d.distance * math.min(d.distance, thiefSpd * dt);
    final body = _thief.o.translate(0, -_thief.h * .5);
    if ((body - lens).distance < 40) {
      hold += dt;
      Sfx.play('tick', volume: .4, minGapMs: 140);
      if (hold > .5) {
        win();
        g.fx.burst(body.dx, body.dy, Pal.gold, 20);
        Sfx.play('bonus');
      }
    } else {
      hold = math.max(0, hold - dt * 2);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final all = [...guests, _thief]..sort((a, b) => a.o.dy.compareTo(b.o.dy));
    for (final gu in all) {
      Gfx.shadow(c, gu.o.dx, gu.o.dy - 2, gu.h * .7, alpha: .4);
      Gfx.sprite(c, gu.spr, gu.o.dx, gu.o.dy, gu.h, ay: 1, flip: gu.flip,
          sy: 1 + boil(vt, gu.o.dx) * .02, rot: gu == _thief ? math.sin(vt * 8) * .04 : 0);
    }
    // oscuridad con el agujero de la lupa (se abre al atraparlo)
    const r = 56.0;
    final open = res == 1 ? clamp01(since * 2) : 0.0;
    c.saveLayer(ZappingGame.bleed, Paint());
    c.drawRect(ZappingGame.bleed, Paint()..color = Color.fromRGBO(8, 6, 20, .8 * (1 - open)));
    c.drawCircle(
        lens,
        r,
        Paint()
          ..blendMode = BlendMode.dstOut
          ..shader = Gradient.radial(lens, r, [const Color(0xFFFFFFFF), const Color(0xFFFFFFFF), const Color(0x00FFFFFF)], [0, .8, 1]));
    c.restore();
    Gfx.sprite(c, 'lens', lens.dx, lens.dy, r / .1885, ax: .435, ay: .292, drop: const Offset(6, 10));
    if (hold > 0 && res == 0) {
      c.drawArc(Rect.fromCircle(center: lens, radius: r + 6), -math.pi / 2, tau * clamp01(hold / .5), false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..color = Pal.gold);
    }
    Gfx.anim(c, 'detective', vt, bx(.1), foot(.935), 130, ay: 1);
  }
}

// ───────────────────────── 32. LLUVIA DE ALBÓNDIGAS (atrapar) ─────────────────────────
class _Fall {
  double x, y, vx, vy, rot;
  final bool boot;
  bool done = false;
  _Fall(this.x, this.y, this.vx, this.vy, this.boot) : rot = rnd(0, tau);
}

class Meatballs extends Channel {
  Meatballs(super.g);
  @override
  String get name => 'LLUVIA DE ALBÓNDIGAS';
  @override
  String get sub => 'La nonna tira la cena desde el balcón';
  @override
  String get ins => '¡A LA MESA!';
  @override
  String get hint => 'Mueve el plato: albóndigas sí, botas no';
  @override
  String get bg => 'bg_balcony';
  @override
  double get dur => 6.5;

  final items = <_Fall>[];
  double px = 0, next = .3, bootP = .25, shake = 0;
  int got = 0, need = 5;
  double get plateY => by(.86);

  /// Bot de prueba: va a por la albóndiga más baja y se aparta de las botas.
  double bestX() {
    final live = items.where((i) => !i.done && i.y < plateY + 10).toList();
    final balls = live.where((i) => !i.boot).toList()..sort((a, b) => b.y.compareTo(a.y));
    var x = balls.isEmpty ? cx : balls.first.x + balls.first.vx * .05;
    for (final b in live.where((i) => i.boot && i.y > plateY - 220)) {
      if ((b.x - x).abs() < 90) x = b.x + (x >= b.x ? 110 : -110);
    }
    return x.clamp(sl + 60, sr - 60);
  }

  @override
  void init(int l) {
    px = cx;
    need = 4 + math.min(l, 3);
    bootP = .22 + l * .04;
  }

  @override
  void update(double dt) {
    if (p.down && pointerIn) px = lerp(px, p.x, 1 - math.exp(-dt * 20));
    px = px.clamp(sl + 60, sr - 60);
    shake = math.max(0, shake - dt * 4);
    if (res == 0 && (next -= dt) <= 0) {
      next = rnd(.45, .7);
      final boot = rng.nextDouble() < bootP && items.where((i) => i.boot).length < 2;
      items.add(_Fall(bx(.29), by(.47), rnd(90, 260), rnd(-440, -300), boot));
    }
    for (final i in items) {
      if (i.done) continue;
      i.vy += 900 * dt;
      i.x += i.vx * dt;
      i.y += i.vy * dt;
      i.rot += dt * (i.boot ? 6 : 3);
      if (i.x > sr - 20) i.vx = -i.vx.abs();
      if (i.vy > 0 && (i.y - plateY).abs() < 16 && (i.x - px).abs() < 62 && res == 0) {
        i.done = true;
        if (i.boot) {
          lose('¡Eso era una bota!');
          Sfx.play('boing');
          g.fx.shake(8);
        } else {
          got++;
          shake = 1;
          Sfx.play('squish');
          g.fx.burst(i.x, plateY - 10, const Color(0xFFC0392B), 8, size: 4);
          if (got >= need) {
            win();
            Sfx.play('bonus');
          }
        }
      } else if (i.y > sb + 40) {
        i.done = true;
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // la nonna sale por su puerta y se queda en la acera, junto al marco
    Gfx.shadow(c, bx(.22), by(.705), 110, alpha: .45);
    Gfx.anim(c, 'nonna', vt, bx(.22), by(.71), 165, ay: 1);
    for (final i in items) {
      if (i.done) continue;
      Gfx.sprite(c, i.boot ? 'boot' : 'meatball2', i.x, i.y, i.boot ? 50 : 36, rot: i.rot, drop: const Offset(4, 8));
    }
    // plato con las albóndigas apiladas
    final py = plateY + math.sin(shake * 12) * 4 * shake;
    Gfx.shadow(c, px, plateY + 30, 140, alpha: .45);
    Gfx.sprite(c, 'plate', px, py, 56);
    for (var k = 0; k < got; k++) {
      final row = k < 3 ? 0 : 1;
      final col = row == 0 ? k : k - 3;
      final n = row == 0 ? math.min(got, 3) : got - 3;
      Gfx.sprite(c, 'meatball2', px + (col - (n - 1) / 2) * 26, py - 10 - row * 18, 28);
    }
    Gfx.text(c, '$got/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 33. LA ABUELA EN PATINETE (saltar) ─────────────────────────
class _Obst {
  double x;
  final String spr;
  final double h;
  bool passed = false;
  _Obst(this.x, this.spr, this.h);
}

class GrannyScooter extends Channel {
  GrannyScooter(super.g);
  @override
  String get name => 'LA ABUELA EN PATINETE';
  @override
  String get sub => 'Llega tarde al bingo y no frena';
  @override
  String get ins => '¡SALTA!';
  @override
  String get hint => 'Toca para saltar los obstáculos';
  @override
  String get bg => 'bg_street';
  @override
  double get dur => 7;

  double y = 0, vy = 0, spd = 0, scroll = 0;
  int passed = 0, need = 3;
  final obs = <_Obst>[];
  double get ground => ZappingGame.bleed.top + ZappingGame.bleed.height * .895;
  double get gx => sl + 100;
  bool get air => y < 0;

  /// Distancia al siguiente obstáculo sin pasar (para los tests con bot).
  double nextObstacleDist() {
    var m = double.infinity;
    for (final o in obs) {
      if (!o.passed && o.x - gx > -10) m = math.min(m, o.x - gx);
    }
    return m;
  }

  @override
  void init(int l) {
    spd = 250 + l * 30;
    need = 3 + (l >= 3 ? 1 : 0);
    var x = sr + 60;
    for (var i = 0; i < need + 1; i++) {
      final k = rng.nextInt(3);
      obs.add(_Obst(x, ['cat', 'gnome', 'trashcan'][k], [44.0, 66.0, 60.0][k]));
      x += rnd(250, 330) + spd * .25;
    }
  }

  @override
  void update(double dt) {
    final s = res == -1 ? 0.0 : spd;
    scroll += s * dt;
    if (tap && !air && res == 0) {
      vy = -620;
      Sfx.play('boing', volume: .6);
    }
    vy += 1700 * dt;
    y = math.min(0, y + vy * dt);
    if (y == 0) vy = 0;
    for (final o in obs) {
      o.x -= s * dt;
      if (res != 0) continue;
      final w = o.h * Gfx.aspect(o.spr) * .7;
      if ((o.x - gx).abs() < w / 2 + 22 && -y < o.h - 8) {
        lose('¡Abuela al suelo!');
        Sfx.play('splat');
        g.fx.shake(10);
      } else if (!o.passed && o.x < gx - w / 2 - 20) {
        o.passed = true;
        passed++;
        if (passed >= need) {
          win();
          Sfx.play('bonus');
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    scrollBg(c, bg, scroll);
    for (final o in obs) {
      if (o.x < sl - 80 || o.x > sr + 80) continue;
      Gfx.shadow(c, o.x, ground, o.h * 1.1, alpha: .45);
      Gfx.sprite(c, o.spr, o.x, ground + 2, o.h, ay: 1);
    }
    final k = clamp01(-y / 140);
    Gfx.shadow(c, gx, ground, 110 * (1 - k * .5), alpha: .45 * (1 - k * .6));
    final rot = res == -1 ? clamp01(since * 4) * 1.2 : (air ? -.15 : 0.0);
    Gfx.anim(c, 'grandma', vt, gx, ground + y + 4, 128, ay: 1, rot: rot);
    Gfx.text(c, '$passed/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 34. POLLO A REACCIÓN (volar) ─────────────────────────
class JetChicken extends Channel {
  JetChicken(super.g);
  @override
  String get name => 'POLLO A REACCIÓN';
  @override
  String get sub => 'Escapa del horno con tu mochila cohete';
  @override
  String get ins => '¡VUELA!';
  @override
  String get hint => 'Mantén pulsado para subir, suelta para bajar';
  @override
  String get bg => 'bg_kitchen2';
  @override
  double get dur => 7;

  double y = 0, vy = 0, spd = 0, scroll = 0, gap = 0;
  final forks = <List<double>>[]; // [x, centro del hueco, pasado]
  int passed = 0, need = 3;
  double get cxp => sl + 110;

  /// Centro del hueco del siguiente tenedor (para los tests con bot).
  double targetY() {
    for (final f in forks) {
      if (f[2] == 0) return f[1];
    }
    return cy;
  }

  @override
  void init(int l) {
    // arranca con un impulso hacia arriba y el primer tenedor lejos: da tiempo a entender
    y = cy + 60;
    vy = -380;
    spd = 165 + l * 18;
    gap = math.max(175, 215 - l * 10);
    need = 3;
    var x = sr + 170;
    var yc = cy;
    for (var i = 0; i < need; i++) {
      // cada hueco cerca del anterior: exige reflejos, no teletransportarse
      yc = (yc + rnd(-120, 120)).clamp(st + 60 + gap / 2, sb - 60 - gap / 2);
      forks.add([x, yc, 0]);
      x += rnd(240, 280);
    }
  }

  @override
  void update(double dt) {
    if (res == -1) {
      vy += 1400 * dt;
      y = math.min(sb + 60, y + vy * dt);
      return;
    }
    scroll += spd * dt;
    if (p.down && pointerIn) {
      vy -= 1900 * dt;
      Sfx.play('shake', volume: .2, minGapMs: 120);
      if (rng.nextDouble() < .6) g.fx.burst(cxp - 30, y + 18, Pal.gold, 1, speed: 140, size: 5);
    }
    vy += 820 * dt;
    vy = vy.clamp(-360.0, 400.0);
    y += vy * dt;
    if (res != 0) return;
    if (y < st + 18 || y > sb - 18) {
      lose(y < st + 18 ? '¡Contra el techo!' : '¡Al suelo!');
      Sfx.play('splat');
      g.fx.shake(8);
    }
    for (final f in forks) {
      f[0] -= spd * dt;
      if ((f[0] - cxp).abs() < 30 && (y < f[1] - gap / 2 + 22 || y > f[1] + gap / 2 - 22)) {
        lose('¡Pinchado!');
        Sfx.play('boing');
        g.fx.shake(10);
      } else if (f[2] == 0 && f[0] < cxp - 36) {
        f[2] = 1;
        passed++;
        Sfx.play('pop', volume: .6);
        if (passed >= need) {
          win();
          Sfx.play('bonus');
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    scrollBg(c, bg, scroll * .6);
    for (final f in forks) {
      if (f[0] < sl - 60 || f[0] > sr + 60) continue;
      final top = f[1] - gap / 2, bot = f[1] + gap / 2;
      Gfx.sprite(c, 'fork', f[0], top, 360, ay: 1, drop: const Offset(8, 8));
      Gfx.sprite(c, 'fork', f[0], bot, 360, ay: 1, rot: math.pi, drop: const Offset(8, 8));
    }
    final rot = res == -1 ? since * 6 : (vy / 480) * .35;
    Gfx.anim(c, 'chicken', vt, cxp, y, 86, rot: rot, fps: 18);
    Gfx.text(c, '$passed/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 35. LOS TRILEROS (seguir) ─────────────────────────
class ShellGame extends Channel {
  ShellGame(super.g);
  @override
  String get name => 'LOS TRILEROS';
  @override
  String get sub => 'El pulpo Tentáculos esconde la bolita';
  @override
  String get ins => '¡NO LA PIERDAS!';
  @override
  String get hint => 'Sigue el vaso de la bolita y tócalo';
  @override
  String get bg => 'bg_trile';
  @override
  double get dur => 1.4 + swaps.length * swapT + 2.6;

  final pos = [0, 1, 2]; // pos[vaso] = hueco
  int ball = 0, picked = -1;
  final swaps = <List<int>>[];
  double swapT = .38;
  double get tableY => by(.745);
  double slotX(int s) => bx(.28 + s * .22);
  double get shuffleEnd => 1.4 + swaps.length * swapT;

  @override
  void init(int l) {
    ball = rng.nextInt(3);
    final n = 4 + math.min(l, 4);
    swapT = .4 / (1 + l * .12);
    for (var i = 0; i < n; i++) {
      final a = rng.nextInt(3);
      swaps.add([a, (a + 1 + rng.nextInt(2)) % 3]);
    }
  }

  // posición del vaso [cup] en el instante actual (con arcos al intercambiar)
  Offset cupAt(int cup) {
    final order = [0, 1, 2];
    var tt = t - 1.4;
    for (final s in swaps) {
      final ca = order.indexOf(s[0]), cb = order.indexOf(s[1]);
      if (tt < swapT && tt >= 0) {
        final k = tt / swapT, e = k * k * (3 - 2 * k);
        if (cup == ca || cup == cb) {
          final from = cup == ca ? s[0] : s[1], to = cup == ca ? s[1] : s[0];
          final up = cup == ca ? -1.0 : 1.0;
          return Offset(lerp(slotX(from), slotX(to), e), tableY - math.sin(e * math.pi) * 26 * up);
        }
      }
      if (tt >= swapT) {
        order[ca] = s[1];
        order[cb] = s[0];
      }
      tt -= swapT;
      if (tt < 0) break;
    }
    return Offset(slotX(order[cup]), tableY);
  }

  @override
  void update(double dt) {
    if (res != 0 || t < shuffleEnd) return;
    if (tap) {
      for (var cup = 0; cup < 3; cup++) {
        final o = cupAt(cup);
        if (Rect.fromLTRB(o.dx - 48, o.dy - 100, o.dx + 48, o.dy + 10).contains(Offset(p.x, p.y))) {
          picked = cup;
          if (cup == ball) {
            win();
            Sfx.play('bonus');
          } else {
            lose('¡La bolita estaba en otro!');
            Sfx.play('lose');
          }
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // el pulpo se apoya en la parte de atrás del mantel: los tentáculos descansan sobre la mesa
    Gfx.shadow(c, cx, by(.715), 250, alpha: .45, ratio: .12);
    Gfx.anim(c, 'octopus', vt, cx, by(.728), 215, ay: 1);
    for (var cup = 0; cup < 3; cup++) {
      final o = cupAt(cup);
      final showBall = t < 1.0 || (res != 0 && (cup == ball));
      final lift = t < 1.0 ? math.sin(clamp01(t / 1.0) * math.pi) * 60 : (res != 0 && (cup == picked || cup == ball) ? clamp01(since * 4) * 60 : 0.0);
      if (showBall && cup == ball) {
        Gfx.shadow(c, o.dx, o.dy - 2, 30, alpha: .5);
        Gfx.clayBall(c, o.dx, o.dy - 12, 11, const Color(0xFFFFF4E6));
      }
      Gfx.shadow(c, o.dx, o.dy - 2, 90, alpha: .45 * (1 - lift / 80));
      Gfx.sprite(c, 'cup', o.dx, o.dy - lift, 92, ay: 1);
    }
    if (t >= shuffleEnd && res == 0) {
      Gfx.text(c, '¿DÓNDE ESTÁ?', cx, st + 40, 30, color: Pal.gold, scale: 1 + math.sin(vt * 6) * .04);
    }
  }
}

// ───────────────────────── 36. CALCETINES PERDIDOS (parejas) ─────────────────────────
class SockPairs extends Channel {
  SockPairs(super.g);
  @override
  String get name => 'CALCETINES PERDIDOS';
  @override
  String get sub => 'La lavadora ha desparejado los calcetines';
  @override
  String get ins => '¡MEMORIZA!';
  @override
  String get hint => 'Encuentra las 3 parejas';
  @override
  String get bg => 'bg_laundry';
  @override
  double get dur => 9;

  final cards = <int>[];
  final up = List.filled(6, false), done = List.filled(6, false);
  final flipAt = List.filled(6, -9.0);
  int first = -1, second = -1, fails = 0, maxFails = 2;
  double peek = 1.4, back = -1;
  static const socks = ['sock_a', 'sock_b', 'sock_c'];

  Rect card(int i) {
    const w = 104.0, h = 124.0;
    final col = i % 3, row = i ~/ 3;
    return Rect.fromCenter(center: Offset(cx + (col - 1) * 122, st + 118 + row * 142), width: w, height: h);
  }

  @override
  void init(int l) {
    cards.addAll([0, 0, 1, 1, 2, 2]..shuffle(rng));
    peek = math.max(.8, 1.5 - l * .15);
    maxFails = l >= 3 ? 1 : 2;
  }

  bool shown(int i) => t < peek || up[i] || done[i];

  /// Bot de prueba con memoria perfecta: destapa la pareja de la carta abierta.
  int nextSmartTap() {
    if (first >= 0) {
      for (var i = 0; i < 6; i++) {
        if (i != first && !done[i] && !up[i] && cards[i] == cards[first]) return i;
      }
    }
    for (var i = 0; i < 6; i++) {
      if (!done[i] && !up[i]) return i;
    }
    return -1;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (back >= 0 && (back -= dt) < 0) {
      up[first] = up[second] = false;
      flipAt[first] = flipAt[second] = vt;
      first = second = -1;
    }
    if (!tap || t < peek || second >= 0) return;
    for (var i = 0; i < 6; i++) {
      if (!card(i).contains(Offset(p.x, p.y)) || up[i] || done[i]) continue;
      up[i] = true;
      flipAt[i] = vt;
      Sfx.play('click');
      if (first < 0) {
        first = i;
      } else {
        second = i;
        if (cards[first] == cards[second]) {
          done[first] = done[second] = true;
          g.fx.burst(card(i).center.dx, card(i).center.dy, Pal.lime, 12);
          Sfx.play('pop');
          first = second = -1;
          if (done.every((d) => d)) {
            win();
            Sfx.play('bonus');
          }
        } else {
          fails++;
          Sfx.play('boing', volume: .6);
          if (fails >= maxFails) {
            lose('¡Calcetines desparejados!');
          } else {
            back = .5;
          }
        }
      }
      break;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'washer', vt, bx(.85), foot(.93), 150, ay: 1);
    for (var i = 0; i < 6; i++) {
      final r = card(i);
      final f = clamp01((vt - flipAt[i]) / .16);
      final face = shown(i);
      final sx = (f < 1 ? (f - .5).abs() * 2 : 1.0).clamp(.05, 1.0);
      final lift = done[i] ? 0.0 : math.sin(vt * 3 + i) * 2;
      c.save();
      c.translate(r.center.dx, r.center.dy + lift);
      c.scale(sx, 1);
      final rr = Rect.fromCenter(center: Offset.zero, width: r.width, height: r.height);
      Gfx.shadow(c, 0, r.height / 2 + 2, r.width * .9, alpha: .4);
      if (face) {
        Gfx.clayPanel(c, rr, done[i] ? const Color(0xFFDFF7C8) : const Color(0xFFF7F1E3));
        Gfx.sprite(c, socks[cards[i]], 0, 0, r.height * .62, rot: -.2);
      } else {
        Gfx.clayPanel(c, rr, const Color(0xFF5A3F8A));
        Gfx.textIn(c, '?', Gfx.panelSafe(rr, const Color(0xFF5A3F8A)), 48, color: Pal.gold);
      }
      c.restore();
    }
    if (t >= peek) {
      for (var k = 0; k < maxFails; k++) {
        Gfx.mark(c, k >= fails, sr - 30 - k * 36, st + 32, 30);
      }
    }
  }
}

// ───────────────────────── 37. MUÑECAS RUSAS (ordenar) ─────────────────────────
class Matryoshka extends Channel {
  Matryoshka(super.g);
  @override
  String get name => 'MUÑECAS RUSAS';
  @override
  String get sub => 'La familia Matrioska se pone en fila';
  @override
  String get ins => '¡DE MAYOR A MENOR!';
  @override
  String get hint => 'Toca de la más grande a la más pequeña';
  @override
  String get bg => 'bg_russian';
  @override
  double get dur => 5.5;

  final sizes = <double>[];
  final order = <int>[]; // order[slot] = índice de tamaño (0 = la mayor)
  final hopAt = <double>[];
  int nextSize = 0;
  double get shelf => by(.735);

  @override
  void init(int l) {
    final n = l >= 3 ? 6 : 5;
    final step = l >= 4 ? 14.0 : 20.0;
    for (var i = 0; i < n; i++) {
      sizes.add(150 - i * step);
      order.add(i);
      hopAt.add(-9);
    }
    order.shuffle(rng);
  }

  double slotX(int s) => lerp(bx(.12), bx(.88), s / (order.length - 1));

  /// Centro de la muñeca de tamaño [k] (para los tests con bot).
  Offset dollCenter(int k) {
    final s = order.indexOf(k);
    return Offset(slotX(s), shelf - sizes[k] / 2);
  }

  @override
  void update(double dt) {
    if (res != 0 || !tap) return;
    for (var s = 0; s < order.length; s++) {
      final k = order[s];
      final h = sizes[k], w = h * Gfx.aspect('matryoshka');
      if (!Rect.fromLTRB(slotX(s) - w / 2, shelf - h, slotX(s) + w / 2, shelf).contains(Offset(p.x, p.y))) continue;
      if (k < nextSize) return; // ya tocada
      if (k == nextSize) {
        hopAt[k] = vt;
        nextSize++;
        Sfx.play('note${math.min(nextSize - 1, 3)}');
        g.fx.burst(slotX(s), shelf - h, Pal.gold, 8, size: 4);
        if (nextSize >= sizes.length) {
          win();
          Sfx.play('bonus');
        }
      } else {
        lose('¡Esa no tocaba!');
        Sfx.play('boing');
        hopAt[k] = vt;
      }
      return;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var s = 0; s < order.length; s++) {
      final k = order[s];
      final h = sizes[k];
      final hk = vt - hopAt[k];
      final hop = hk < .35 ? math.sin(hk / .35 * math.pi) * 26 : 0.0;
      final doneK = k < nextSize;
      Gfx.shadow(c, slotX(s), shelf - 2, h * .6, alpha: .45);
      Gfx.sprite(c, 'matryoshka', slotX(s), shelf - hop, h,
          ay: 1, rot: res == -1 && k >= nextSize ? math.sin(vt * 20 + s) * .08 : boil(vt, s.toDouble()) * .03);
      if (doneK) {
        Gfx.clayBall(c, slotX(s), shelf - h - 22 - hop, 15, Pal.lime);
        Gfx.text(c, '${k + 1}', slotX(s), shelf - h - 22 - hop, 20, color: Pal.ink);
      }
    }
  }
}

// ───────────────────────── 38. LANZASALCHICHAS (clavar en el queso) ─────────────────────────
class SausageThrow extends Channel {
  SausageThrow(super.g);
  @override
  String get name => 'LANZASALCHICHAS';
  @override
  String get sub => 'El perro Frankfurt las clava en un queso que gira';
  @override
  String get ins => '¡LANZA!';
  @override
  String get hint => 'Toca para lanzar sin tocar otra salchicha';
  @override
  String get bg => 'bg_sausage';
  @override
  double get dur => 7;

  final stuck = <double>[]; // ángulos relativos al queso
  double a = 0, w = 0, flyY = -1;
  int thrown = 0, need = 4;
  double? bounceA;
  double bounceT = 0;
  Offset get c0 => Offset(cx, by(.4));
  static const r = 92.0, sl0 = 76.0;
  double get launchY => by(.76);

  /// ¿Caería en un hueco si se lanzara ahora? (para los tests con bot)
  bool safeToThrow() {
    final tt = (launchY - (c0.dy + r + sl0 * .1)) / 1300;
    final rel = (math.pi / 2 - (a + w * tt * (1 + .25 * math.sin(t * 1.7)))) % tau;
    return !stuck.any((s) => (((s - rel + math.pi) % tau) - math.pi).abs() < .5);
  }

  @override
  void init(int l) {
    w = (2.0 + l * .3) * (rng.nextBool() ? 1 : -1);
    need = 3;
    for (var i = 0; i < 2 + math.min(l, 2); i++) {
      stuck.add(i * tau / (2 + math.min(l, 2)) + rnd(-.3, .3));
    }
  }

  @override
  void update(double dt) {
    a += w * dt * (1 + .25 * math.sin(t * 1.7));
    if (bounceA != null) bounceT += dt;
    if (res != 0) return;
    if (flyY < 0 && tap) {
      flyY = launchY;
      Sfx.play('click');
    }
    if (flyY >= 0) {
      flyY -= 1300 * dt;
      if (flyY <= c0.dy + r + sl0 * .1) {
        final rel = (math.pi / 2 - a) % tau;
        final hit = stuck.any((s) {
          final d = ((s - rel + math.pi) % tau) - math.pi;
          return d.abs() < .26;
        });
        flyY = -1;
        if (hit) {
          bounceA = 0;
          bounceT = 0;
          lose('¡Chocó con otra salchicha!');
          Sfx.play('boing');
          g.fx.shake(8);
        } else {
          stuck.add(rel);
          thrown++;
          Sfx.play('chop');
          g.fx.burst(cx, c0.dy + r, Pal.gold, 8, size: 4);
          if (thrown >= need) {
            win();
            Sfx.play('bonus');
          }
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, c0.dx + 8, c0.dy + r + 40, r * 1.8, alpha: .25);
    c.save();
    c.translate(c0.dx, c0.dy);
    c.rotate(a);
    for (final s in stuck) {
      // salchicha clavada: sale del borde hacia fuera
      c.save();
      c.rotate(s - math.pi / 2);
      Gfx.sprite(c, 'sausage', 0, r - 10, sl0, ay: 0, sx: 1.7);
      c.restore();
    }
    Gfx.sprite(c, 'cheese', 0, 0, r * 2.1);
    c.restore();
    // la que vuela (o la que rebota)
    if (flyY >= 0) Gfx.sprite(c, 'sausage', cx, flyY, sl0, ay: 0, sx: 1.7, drop: const Offset(4, 8));
    if (bounceA != null) {
      Gfx.sprite(c, 'sausage', cx + bounceT * 160, c0.dy + r + bounceT * bounceT * 900 - bounceT * 200, sl0,
          rot: bounceT * 12, sx: 1.7);
    }
    if (flyY < 0 && res == 0) Gfx.sprite(c, 'sausage', cx, launchY, sl0, ay: 0, sx: 1.7, rot: math.sin(vt * 8) * .05);
    Gfx.anim(c, 'dogchef', vt, bx(.16), foot(.95), 170, ay: 1);
    for (var i = 0; i < need; i++) {
      Gfx.sprite(c, 'sausage', sr - 24 - i * 20, st + 34, 36, sx: 1.7, alpha: i < need - thrown ? 1 : .25);
    }
  }
}

// ───────────────────────── 39. GUARDIA DE CRUCE (semáforo) ─────────────────────────
class _Car {
  double d; // distancia recorrida desde la entrada
  final bool horiz;
  final Color col;
  double wait = 0;
  _Car(this.horiz, this.col) : d = -40;
}

class Crossing extends Channel {
  Crossing(super.g);
  @override
  String get name => 'GUARDIA DE CRUCE';
  @override
  String get sub => 'Caracoles-coche en un cruce sin semáforo';
  @override
  String get ins => '¡DIRIGE EL TRÁFICO!';
  @override
  String get hint => 'Toca para cambiar quién pasa. ¡Sin choques!';
  @override
  String get bg => 'bg_cross';
  @override
  bool get survive => true;
  @override
  double get dur => 6.5;

  bool hGreen = true;
  double spd = 0, nh = .2, nv = .6, flash = 0;
  final cars = <_Car>[];
  Offset get x0 => Offset(bx(.5), by(.575));
  static const box = 46.0;
  double get hLen => ZappingGame.bleed.width + 80;
  double get stopD => (x0.dx - (ZappingGame.bleed.left - 40)) - box - 34;
  double get stopDv => (x0.dy - (ZappingGame.bleed.top - 40)) - box - 34;

  Offset _carPos(_Car k) => k.horiz
      ? Offset(ZappingGame.bleed.left - 40 + k.d, x0.dy + 12)
      : Offset(x0.dx - 12, ZappingGame.bleed.top - 40 + k.d);

  /// Bot de prueba: da paso a los que esperan cuando el cruce queda libre.
  bool shouldToggle() {
    final stopG = hGreen ? stopD : stopDv;
    final inBox = cars.any((k) => k.horiz == hGreen && k.d > stopG - 20 && k.d < stopG + 2 * box + 110);
    final busy = cars.any((k) => k.horiz == hGreen && k.d > stopG - 90 && k.d < stopG + 2 * box + 110);
    final waiting = cars.where((k) => k.horiz != hGreen).fold(0.0, (m, k) => math.max(m, k.wait));
    return (waiting > .25 && !busy) || (waiting > 2.2 && !inBox);
  }

  @override
  void init(int l) => spd = 150 + l * 16;

  @override
  void update(double dt) {
    flash = math.max(0, flash - dt * 3);
    if (res != 0) return;
    if (tap) {
      hGreen = !hGreen;
      flash = 1;
      Sfx.play('tick');
    }
    if ((nh -= dt) <= 0) {
      nh = rnd(1.6, 2.4);
      cars.add(_Car(true, pick([Pal.pink, Pal.gold, Pal.lime])));
    }
    if ((nv -= dt) <= 0) {
      nv = rnd(1.6, 2.4);
      cars.add(_Car(false, pick([Pal.teal, const Color(0xFFB08CFF), const Color(0xFFFF8A3D)])));
    }
    for (final k in cars) {
      final green = k.horiz == hGreen;
      final stop = k.horiz ? stopD : stopDv;
      // coche de delante en el mismo carril
      final ahead = cars.where((o) => o.horiz == k.horiz && o.d > k.d).fold<double?>(null, (m, o) => m == null || o.d < m ? o.d : m);
      var limit = double.infinity;
      if (!green && k.d <= stop + 1) limit = stop;
      if (ahead != null) limit = math.min(limit, ahead - 62);
      final nd = math.min(k.d + spd * dt, limit);
      if (nd - k.d < spd * dt * .3) {
        k.wait += dt;
      } else {
        k.wait = 0;
      }
      k.d = math.max(k.d, nd);
      if (k.wait > 3.5) {
        lose('¡Atasco monumental!');
        Sfx.play('lose');
      }
    }
    cars.removeWhere((k) => k.d > (k.horiz ? hLen : ZappingGame.bleed.height + 80));
    // choque: uno de cada dirección dentro del cruce a la vez
    bool inBox(_Car k) {
      final o = _carPos(k);
      return (o.dx - x0.dx).abs() < box && (o.dy - x0.dy).abs() < box;
    }

    final hIn = cars.where((k) => k.horiz && inBox(k));
    final vIn = cars.where((k) => !k.horiz && inBox(k));
    if (hIn.isNotEmpty && vIn.isNotEmpty) {
      lose('¡Choque de caracoles!');
      Sfx.play('splat');
      g.fx.burst(x0.dx, x0.dy, Pal.pink, 24);
      g.fx.shake(10);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (final k in cars) {
      final o = _carPos(k);
      Gfx.sprite(c, 'snailcar', o.dx, o.dy, 42,
          rot: k.horiz ? 0 : math.pi / 2, tint: k.col, drop: const Offset(4, 6), sy: 1 + boil(vt, k.d) * .03);
      if (k.wait > 2.0) Gfx.text(c, '!', o.dx, o.dy - 34, 24, color: Pal.pink, scale: 1 + math.sin(vt * 14) * .15);
    }
    // semáforos de plastilina en las esquinas del cruce
    void light(Offset o, bool green) {
      Gfx.clayBall(c, o.dx, o.dy, 13, green ? Pal.lime : const Color(0xFFE0303A));
    }

    light(Offset(x0.dx - box - 30, x0.dy - box - 16), hGreen);
    light(Offset(x0.dx + box + 16, x0.dy - box - 30), !hGreen);
    final pk = 1 + flash * .12;
    Gfx.anim(c, 'pigcop', vt, bx(.84), by(.44), 130 * pk, ay: 1);
  }
}

// ───────────────────────── 40. PASTOR DE NUBES (empujar) ─────────────────────────
class _Sheep {
  Offset o, v = Offset.zero;
  bool inPen = false;
  final double ph = rnd(0, tau);
  _Sheep(this.o);
}

class CloudSheep extends Channel {
  CloudSheep(super.g);
  @override
  String get name => 'PASTOR DE NUBES';
  @override
  String get sub => 'Las ovejas-nube se escapan del corral';
  @override
  String get ins => '¡AL CORRAL!';
  @override
  String get hint => 'Acerca el dedo: las ovejas huyen de él';
  @override
  String get bg => 'bg_clouds';
  @override
  double get dur => 8;

  final sheep = <_Sheep>[];
  Rect get pen => Rect.fromLTRB(bx(.67), by(.66), bx(.95), by(.8));

  /// Bot de prueba: se pone detrás de la primera oveja suelta, en línea con el corral.
  Offset? pushPoint() {
    for (final k in sheep) {
      if (k.inPen) continue;
      final d = pen.center - k.o;
      return k.o - d / d.distance * 80;
    }
    return null;
  }

  @override
  void init(int l) {
    final n = 3 + math.min(l ~/ 2, 2);
    for (var i = 0; i < n; i++) {
      sheep.add(_Sheep(Offset(bx(rnd(.15, .5)), by(rnd(.2, .7)))));
    }
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    final f = Offset(p.x, p.y);
    for (final s in sheep) {
      if (s.inPen) continue;
      if (p.down && pointerIn) {
        final d = s.o - f;
        final dd = d.distance;
        if (dd < 150 && dd > 1) s.v += d / dd * 1600 * dt * (1 - dd / 150);
      }
      s.v += Offset(math.sin(t * 1.3 + s.ph), math.cos(t * 1.1 + s.ph)) * 30 * dt; // deriva
      s.v *= math.pow(.25, dt).toDouble();
      s.o += s.v * dt;
      final r = Rect.fromLTRB(sl + 34, st + 40, sr - 34, sb - 30);
      if (s.o.dx < r.left || s.o.dx > r.right) s.v = Offset(-s.v.dx, s.v.dy);
      if (s.o.dy < r.top || s.o.dy > r.bottom) s.v = Offset(s.v.dx, -s.v.dy);
      s.o = Offset(s.o.dx.clamp(r.left, r.right), s.o.dy.clamp(r.top, r.bottom));
      if (pen.deflate(6).contains(s.o)) {
        s.inPen = true;
        Sfx.play('pop');
        g.fx.burst(s.o.dx, s.o.dy, const Color(0xFFFFFFFF), 10);
        if (sheep.every((k) => k.inPen)) {
          win();
          Sfx.play('bonus');
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'shepherd', vt, bx(.14), foot(.93), 150, ay: 1);
    void draw(_Sheep s) {
      final bob = math.sin(vt * 3 + s.ph) * 4;
      Gfx.sprite(c, 'sheep', s.o.dx, s.o.dy + bob, 58, flip: s.v.dx < -5, drop: const Offset(0, 20));
    }

    for (final s in sheep.where((s) => s.inPen)) {
      draw(s);
    }
    Gfx.sprite(c, 'fence', pen.center.dx, pen.bottom + 6, pen.width * .62, ay: 1);
    for (final s in sheep.where((s) => !s.inPen)) {
      draw(s);
    }
    if (p.down && pointerIn && res == 0) {
      c.drawCircle(Offset(p.x, p.y), 140,
          Paint()..shader = Gradient.radial(Offset(p.x, p.y), 140, [const Color(0x33FFFFFF), const Color(0x00FFFFFF)]));
    }
    final inN = sheep.where((s) => s.inPen).length;
    Gfx.text(c, '$inN/${sheep.length}', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 41. EL FOCO DE LA DIVA (seguir) ─────────────────────────
class DivaSpot extends Channel {
  DivaSpot(super.g);
  @override
  String get name => 'EL FOCO DE LA DIVA';
  @override
  String get sub => 'La diva no para de moverse por el escenario';
  @override
  String get ins => '¡ILUMÍNALA!';
  @override
  String get hint => 'Mantén el foco encima de ella';
  @override
  String get bg => 'bg_theater';
  @override
  double get dur => 7;

  Offset diva = Offset.zero, to = Offset.zero, spot = Offset.zero;
  double fill = 0, need = 2.4, spd = 0, next = 0;
  bool left = false;

  @override
  void init(int l) {
    diva = Offset(cx, by(.84));
    to = diva;
    spot = Offset(cx - 120, by(.62));
    spd = 90 + l * 18;
    need = 2.2 + l * .15;
  }

  bool get lit => (spot - diva.translate(0, -80)).distance < 70;

  @override
  void update(double dt) {
    if (p.down && pointerIn) spot = Offset.lerp(spot, Offset(p.x, p.y), 1 - math.exp(-dt * 14))!;
    if (res != 0) return;
    if ((next -= dt) <= 0 || (to - diva).distance < 4) {
      next = rnd(.7, 1.6);
      to = Offset(bx(rnd(.18, .82)), by(rnd(.8, .88)));
    }
    final d = to - diva;
    if (d.distance > 1) {
      final step = d / d.distance * math.min(d.distance, spd * dt);
      diva += step;
      if (step.dx.abs() > .2) left = step.dx < 0;
    }
    if (lit) {
      fill += dt;
      Sfx.play('note${rng.nextInt(4)}', volume: .25, minGapMs: 260);
      if (fill >= need) {
        win();
        Sfx.play('bonus');
        g.fx.burst(diva.dx, diva.dy - 120, Pal.gold, 24);
      }
    } else {
      fill = math.max(0, fill - dt * .6);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, diva.dx, diva.dy - 2, 110, alpha: .5);
    Gfx.anim(c, 'diva', vt, diva.dx, diva.dy, 170, ay: 1, flip: left);
    // foco de teatro: un cañón en el techo proyecta un cono de luz cálida que termina en un óvalo
    const r = 80.0;
    final lamp = Offset(cx + (spot.dx - cx) * .35, st - 6);
    final ang = math.atan2(spot.dy - lamp.dy, spot.dx - lamp.dx) - math.pi / 2;
    Path cone(double spread) {
      final nx = math.cos(ang), ny = math.sin(ang);
      return Path()
        ..moveTo(lamp.dx - nx * 12, lamp.dy - ny * 12)
        ..lineTo(lamp.dx + nx * 12, lamp.dy + ny * 12)
        ..lineTo(spot.dx + nx * r * spread, spot.dy + ny * r * spread)
        ..lineTo(spot.dx - nx * r * spread, spot.dy - ny * r * spread)
        ..close();
    }

    final dark = res == 1 ? .15 : .7;
    c.saveLayer(ZappingGame.bleed, Paint());
    c.drawRect(ZappingGame.bleed, Paint()..color = Color.fromRGBO(6, 3, 14, dark));
    // el cono aclara un poco (aire con polvo) y el óvalo del suelo ilumina del todo
    c.drawPath(cone(.95), Paint()
      ..blendMode = BlendMode.dstOut
      ..color = const Color(0x99FFFFFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    c.drawOval(Rect.fromCenter(center: spot, width: r * 2, height: r * 2.1), Paint()
      ..blendMode = BlendMode.dstOut
      ..shader = Gradient.radial(spot, r * 1.05, [const Color(0xFFFFFFFF), const Color(0xF0FFFFFF), const Color(0x00FFFFFF)], [0, .72, 1]));
    c.restore();
    // brillo cálido encima (suma de luz)
    final warm = lit ? 1.0 : .6;
    c.drawPath(cone(.95), Paint()
      ..blendMode = BlendMode.plus
      ..color = Color.fromRGBO(150, 115, 50, .45 * warm)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    c.drawCircle(spot, r, Paint()
      ..blendMode = BlendMode.plus
      ..shader = Gradient.radial(spot, r, [Color.fromRGBO(160, 125, 55, .6 * warm), const Color(0x00000000)]));
    // motas de polvo flotando dentro del haz
    for (var k = 0; k < 14; k++) {
      final u = ((k * .137 + vt * .08) % 1);
      final o = Offset.lerp(lamp, spot, u)! + Offset(math.sin(k * 7.3 + vt) * r * .7 * u, math.cos(k * 3.1 + vt * .7) * 10);
      c.drawCircle(o, 1.6, Paint()..color = Color.fromRGBO(255, 240, 200, .5 * (1 - u * .5)));
    }
    // el cañón de luz
    c.save();
    c.translate(lamp.dx, lamp.dy);
    c.rotate(ang);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-17, -26, 34, 34), const Radius.circular(8)), Paint()..color = const Color(0xFF3A3346));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-19, 2, 38, 8), const Radius.circular(4)), Paint()..color = const Color(0xFFD9A441));
    c.restore();
    if (res == 0 && !lit) Gfx.text(c, 'ARRASTRA EL FOCO HASTA ELLA', cx, st + 78, 18, color: Pal.gold, alpha: .6 + math.sin(vt * 5) * .3);
    Gfx.sprite(c, 'audience', cx, sb + 14, 96, ay: 1, sx: 1.05);
    Gfx.clayBar(c, Rect.fromLTWH(sl + 70, st + 22, S.width - 140, 18), clamp01(fill / need), Pal.gold);
    Gfx.text(c, 'APLAUSOS', cx, st + 52, 16, color: Pal.gold);
  }
}

// ───────────────────────── 42. NO DESPIERTES AL ABUELO (luz roja) ─────────────────────────
class Grandpa extends Channel {
  Grandpa(super.g);
  @override
  String get name => 'NO DESPIERTES AL ABUELO';
  @override
  String get sub => 'Galletas a medianoche y el abuelo tiene el sueño ligero';
  @override
  String get ins => '¡DE PUNTILLAS!';
  @override
  String get hint => 'Mantén para andar. ¡Suelta si abre los ojos!';
  @override
  String get bg => 'bg_nightroom';
  @override
  double get dur => 8;

  double kx = 0, walkT = 0, phaseT = 0, sleepFor = 0, caught = 0;
  int state = 0; // 0 duerme, 1 se remueve (aviso), 2 despierto
  bool moving = false;
  double get floor => foot(.92);
  double get jarX => bx(.87);

  @override
  void init(int l) {
    kx = bx(.08);
    sleepFor = rnd(1.4, 2.4) / (1 + l * .1);
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    phaseT += dt;
    switch (state) {
      case 0:
        if (phaseT > sleepFor) {
          state = 1;
          phaseT = 0;
        }
      case 1:
        if (phaseT > .45) {
          state = 2;
          phaseT = 0;
          Sfx.play('eh');
        }
      default:
        if (phaseT > rnd(1.0, 1.4)) {
          state = 0;
          phaseT = 0;
          sleepFor = rnd(1.2, 2.2);
        }
    }
    moving = p.down && pointerIn;
    if (moving) {
      kx += 95 * dt;
      walkT += dt;
      if (state == 2 && phaseT > .12) {
        lose('¡Te ha pillado!');
        Sfx.play('boing');
        g.fx.shake(8);
      }
    }
    if (kx >= jarX - 40) {
      win();
      Sfx.play('bonus');
      g.fx.burst(jarX, floor - 70, Pal.gold, 20);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // abuelo en su sillón
    final gx = bx(.5), gy = by(.74);
    Gfx.shadow(c, gx, gy - 4, 190, alpha: .5);
    if (state == 2 || res == -1) {
      Gfx.sprite(c, 'grandpa_awake', gx, gy, 200, ay: 1, rot: res == -1 ? math.sin(vt * 30) * .02 : 0);
      Gfx.text(c, '!', gx + 70, gy - 190, 44, color: Pal.pink, scale: 1 + math.sin(vt * 12) * .1);
    } else {
      final twitch = state == 1 ? math.sin(vt * 50) * 3 : 0.0;
      Gfx.anim(c, 'grandpa', vt, gx + twitch, gy, 200, ay: 1);
      if (state == 0) {
        for (var i = 0; i < 3; i++) {
          final k = (vt * .6 + i / 3) % 1;
          Gfx.text(c, 'Z', gx + 40 + k * 50, gy - 170 - k * 60, 16 + k * 14, color: Pal.teal, alpha: 1 - k);
        }
      } else {
        Gfx.text(c, '?', gx + 70, gy - 190, 36, color: Pal.gold);
      }
    }
    Gfx.shadow(c, jarX, floor - 2, 80, alpha: .45);
    Gfx.sprite(c, 'cookiejar', jarX, floor, 86, ay: 1);
    Gfx.shadow(c, kx, floor - 2, 70, alpha: .45);
    Gfx.anim(c, 'kid', moving && res == 0 ? walkT : 0, kx, floor, 110, ay: 1);
    // indicador de avance
    Gfx.clayBar(c, Rect.fromLTWH(sl + 60, st + 22, S.width - 120, 16), clamp01((kx - bx(.08)) / (jarX - 40 - bx(.08))), Pal.teal);
  }
}

// ───────────────────────── 43. ¿QUÉ HA CAMBIADO? (observar) ─────────────────────────
class _Pose {
  String spr;
  Color? tint;
  bool hat, flip;
  double scale;
  _Pose(this.spr, this.tint, this.hat, this.flip, this.scale);
  _Pose copy() => _Pose(spr, tint, hat, flip, scale);
}

class WhatChanged extends Channel {
  WhatChanged(super.g);
  @override
  String get name => '¿QUÉ HA CAMBIADO?';
  @override
  String get sub => 'Foto de grupo: se va la luz y alguien cambia';
  @override
  String get ins => '¡FÍJATE BIEN!';
  @override
  String get hint => 'Toca al que ha cambiado o se ha movido';
  @override
  String get bg => 'bg_photo';
  @override
  double get dur => look + dark + 3.4;

  final before = <_Pose>[], after = <_Pose>[];
  final jitter = <double>[];
  final changed = <int>{};
  int n = 6;
  double look = 2, dark = .9;
  String kind = '';

  // dos filas: la de atrás sobre el banco alto, la de delante en el suelo
  int get perRow => (n + 1) ~/ 2;
  bool back(int i) => i < perRow;
  double rowY(int i) => back(i) ? by(.555) : by(.665);
  double slotX(int i) {
    final k = back(i) ? i : i - perRow;
    final m = back(i) ? perRow : n - perRow;
    // libre de la cámara del trípode (a la derecha)
    return lerp(bx(.14), bx(.68), m == 1 ? .5 : k / (m - 1)) + (back(i) ? 0 : 22);
  }

  double hOf(int i) => back(i) ? 78 : 92;
  bool get lightsOff => t > look && t < look + dark;
  bool get showAfter => t >= look + dark;

  @override
  void init(int l) {
    n = l >= 3 ? 8 : (l >= 1 ? 7 : 6);
    look = math.max(1.4, 2.2 - l * .15);
    final pool = ['player', 'rival', 'cloneA', 'cloneB', 'guest_bald', 'guest_curly', 'guest_top', 'guest_cowboy', 'sheep', 'gnome']..shuffle(rng);
    for (var i = 0; i < n; i++) {
      before.add(_Pose(pool[i], null, rng.nextDouble() < .3, rng.nextBool(), 1));
      jitter.add(rnd(-7, 7));
    }
    after.addAll(before.map((p) => p.copy()));
    final a = rng.nextInt(n);
    switch (rng.nextInt(4)) {
      case 0: // dos se cambian de sitio
        var b = rng.nextInt(n);
        while (b == a || before[b].spr == before[a].spr) {
          b = rng.nextInt(n);
        }
        final tmp = after[a];
        after[a] = after[b];
        after[b] = tmp;
        changed.addAll([a, b]);
        kind = 'se cambiaron de sitio';
      case 1:
        after[a].hat = !after[a].hat;
        changed.add(a);
        kind = after[a].hat ? 'se puso gorro' : 'se quitó el gorro';
      case 2:
        after[a].flip = !after[a].flip;
        changed.add(a);
        kind = 'se dio la vuelta';
      default:
        after[a].spr = pool[n];
        changed.add(a);
        kind = 'lo cambiaron por otro';
    }
  }

  @override
  void update(double dt) {
    if (res != 0 || !showAfter || !tap) return;
    // la fila de delante tapa en parte a la de atrás: gana el personaje más cercano al dedo
    var best = -1;
    var bd = double.infinity;
    for (var i = 0; i < n; i++) {
      final x = slotX(i), y = rowY(i);
      if ((p.x - x).abs() < 32 && p.y > y - hOf(i) && p.y < y + 6) {
        final d = (Offset(p.x, p.y) - Offset(x, y - hOf(i) / 2)).distance;
        if (d < bd) {
          bd = d;
          best = i;
        }
      }
    }
    for (final i in [best]) {
      if (i >= 0) {
        final x = slotX(i), y = rowY(i);
        if (changed.contains(i)) {
          win();
          Sfx.play('bonus');
          g.fx.burst(x, y - 50, Pal.gold, 18);
        } else {
          lose('¡No fue ese! ${changed.length > 1 ? 'Dos' : 'Uno'} $kind');
          Sfx.play('boing');
        }
        return;
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final list = showAfter ? after : before;
    for (final i in [for (var k = 0; k < n; k++) k]) {
      final ps = list[i];
      final h = hOf(i);
      // tras el apagón todos se recolocan un poco: el cambio no salta a la vista
      final x = slotX(i) + (showAfter ? jitter[i] : 0);
      final y = rowY(i);
      Gfx.shadow(c, x, y - 2, h * .62, alpha: .4);
      Gfx.sprite(c, ps.spr, x, y, h, ay: 1, flip: ps.flip, sy: 1 + boil(vt, i.toDouble()) * .02);
      if (ps.hat) Gfx.sprite(c, 'partyhat', x, y - h * .9, h * .36, ay: 1, rot: -.15);
      if (res == -1 && changed.contains(i)) {
        c.drawCircle(Offset(x, y - h / 2), h * .55,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..color = Pal.lime);
      }
    }
    // apagón total (flash, negro y vuelve la luz)
    final ft = t - look;
    if (ft > 0 && ft < dark) {
      final k = ft < .12 ? 1 - ft / .12 : 0.0;
      c.drawRect(ZappingGame.bleed, Paint()..color = const Color(0xFF050308));
      if (k > 0) c.drawRect(ZappingGame.bleed, Paint()..color = Color.fromRGBO(255, 255, 255, k));
      Gfx.text(c, '¡SE FUE LA LUZ!', cx, cy, 30, color: Pal.dim);
    } else if (ft >= dark && ft < dark + .2) {
      c.drawRect(ZappingGame.bleed, Paint()..color = Color.fromRGBO(5, 3, 8, 1 - (ft - dark) / .2));
    }
    if (t < look) {
      Gfx.text(c, 'MEMORIZA LA FOTO', cx, st + 40, 28, color: Pal.gold, scale: 1 + math.sin(vt * 6) * .04);
    } else if (showAfter && res == 0) {
      Gfx.text(c, '¿QUIÉN HA CAMBIADO?', cx, st + 40, 26, color: Pal.gold, maxW: S.width - 40);
    }
  }
}

// ───────────────────────── 44. LA FOCA MALABARISTA (mantener en el aire) ─────────────────────────
class SealBall extends Channel {
  SealBall(super.g);
  @override
  String get name => 'LA FOCA MALABARISTA';
  @override
  String get sub => 'Que la pelota no toque el agua';
  @override
  String get ins => '¡ARRIBA!';
  @override
  String get hint => 'Toca la pelota para golpearla';
  @override
  String get bg => 'bg_pool';
  @override
  double get dur => 8;

  Offset b = Offset.zero, v = Offset.zero;
  double spin = 0, grav = 0;
  int hits = 0, need = 5;
  double splashAt = -9;
  static const r = 30.0;
  double get water => by(.64);

  @override
  void init(int l) {
    // la foca la lanza hacia arriba al empezar
    b = Offset(bx(.28), by(.6));
    v = Offset(rnd(90, 150), -620);
    grav = 650 + l * 70;
    need = 5 + math.min(l, 3);
  }

  @override
  void update(double dt) {
    if (res == -1) return;
    if (tap && res == 0 && (Offset(p.x, p.y) - b).distance < r + 42) {
      v = Offset((b.dx - p.x) * 5 + rnd(-80, 80) + (cx - b.dx) * .8, -rnd(560, 640));
      hits++;
      spin = v.dx / 60;
      Sfx.play('pop');
      g.fx.burst(b.dx, b.dy + r, const Color(0xFFFFFFFF), 6, size: 4);
      if (hits >= need) {
        win();
        Sfx.play('bonus');
      }
    }
    v = Offset(v.dx, v.dy + grav * dt);
    b += v * dt;
    if (b.dx < sl + r || b.dx > sr - r) {
      v = Offset(-v.dx * .8, v.dy);
      b = Offset(b.dx.clamp(sl + r, sr - r), b.dy);
    }
    if (b.dy < st + r) {
      v = Offset(v.dx, v.dy.abs() * .5);
    }
    if (b.dy > water - 6 && res == 0) {
      lose('¡Al agua!');
      splashAt = vt;
      Sfx.play('splat');
      g.fx.burst(b.dx, water, const Color(0xFF7FD3FF), 24);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'seal', vt, bx(.23), by(.735), 130, ay: 1);
    final hk = clamp01((water - b.dy) / 300);
    Gfx.shadow(c, b.dx, water + 6, 70 * (1 - hk * .5), alpha: .3 * (1 - hk * .5));
    Gfx.sprite(c, 'beachball', b.dx, b.dy, r * 2, rot: vt * spin);
    Gfx.text(c, '$hits/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 45. BOMBERO DE GELATINA (apuntar y mantener) ─────────────────────────
class FireJelly extends Channel {
  FireJelly(super.g);
  @override
  String get name => 'BOMBERO DE GELATINA';
  @override
  String get sub => 'La casa de jengibre está ardiendo';
  @override
  String get ins => '¡APAGA EL FUEGO!';
  @override
  String get hint => 'Mantén el chorro sobre cada llama';
  @override
  String get bg => 'bg_ginger';
  @override
  double get dur => 7;

  final flames = <List<double>>[]; // [x, y, vida]
  Offset aim = Offset.zero;
  bool spraying = false;
  // boquilla de la manguera en las manos del bombero
  Offset get nozzle => Offset(bx(.2) + 44, foot(.95) - 110);
  double burn = .75;

  @override
  void init(int l) {
    // centro de las tres ventanas de la casa (medido sobre el decorado)
    for (final f in const [[.37, .345], [.615, .345], [.655, .605]]) {
      flames.add([bx(f[0]), by(f[1]), 1]);
    }
    burn = .7 + l * .08;
    aim = Offset(cx, cy);
  }

  @override
  void update(double dt) {
    spraying = p.down && pointerIn && res == 0;
    if (spraying) aim = Offset(p.x, p.y);
    if (res != 0) return;
    for (final f in flames) {
      if (f[2] <= 0) continue;
      if (spraying && (aim - Offset(f[0], f[1])).distance < 48) {
        f[2] -= dt / burn;
        Sfx.play('shake', volume: .25, minGapMs: 100);
        if (f[2] <= 0) {
          g.fx.burst(f[0], f[1], const Color(0xFFDDEEFF), 16);
          Sfx.play('pop');
        }
      } else {
        f[2] = math.min(1, f[2] + dt * .25);
      }
    }
    if (flames.every((f) => f[2] <= 0)) {
      win();
      Sfx.play('bonus');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var i = 0; i < flames.length; i++) {
      final f = flames[i];
      if (f[2] <= 0) {
        // humo al apagarse
        Gfx.clayBall(c, f[0] + math.sin(vt * 2 + i) * 6, f[1] - 20 - (vt * 30) % 30, 10, const Color(0xFFB8B8C0));
        continue;
      }
      // la llama nace del alféizar de su ventana y la ilumina por dentro
      c.drawRect(Rect.fromCenter(center: Offset(f[0], f[1]), width: 62, height: 60),
          Paint()..color = Color.fromRGBO(255, 150, 40, .35 * f[2] + math.sin(vt * 9 + i) * .05));
      Gfx.anim(c, 'flame', vt + i * .7, f[0], f[1] + 30, 76 * (.45 + .55 * f[2]), ay: 1);
    }
    // chorro: gotas a lo largo de una curva desde la boquilla
    if (spraying) {
      final ctrl = Offset((nozzle.dx + aim.dx) / 2, math.min(nozzle.dy, aim.dy) - 60);
      for (var k = 0; k < 16; k++) {
        final u = ((k / 16) + vt * 3) % 1;
        final a = Offset.lerp(nozzle, ctrl, u)!, b2 = Offset.lerp(ctrl, aim, u)!;
        final o = Offset.lerp(a, b2, u)!;
        Gfx.clayBall(c, o.dx, o.dy, 5 + u * 3, const Color(0xFF7FC8FF));
      }
    }
    Gfx.anim(c, 'gummy', vt, bx(.2), foot(.95), 150, ay: 1);
  }
}

// ───────────────────────── 46. LA BANDA DE GUSANOS (ritmo) ─────────────────────────
class WormBand extends Channel {
  WormBand(super.g);
  @override
  String get name => 'LA BANDA DE GUSANOS';
  @override
  String get sub => 'Concierto dentro de una manzana';
  @override
  String get ins => '¡AL RITMO!';
  @override
  String get hint => 'Toca la columna cuando la nota llegue a la raya';
  @override
  String get bg => 'bg_apple';
  @override
  double get dur => notes.isEmpty ? 6 : notes.last[1] + 1.4;

  final notes = <List<double>>[]; // [carril, tiempo de llegada, estado 0/1 acierto/-1 fallo]
  final flashAt = [-9.0, -9.0, -9.0];
  int misses = 0, maxMiss = 2;
  double fall = 0;
  double laneX(int i) => cx + (i - 1) * 104;
  double get lineY => by(.64);
  double get topY => st + 20;

  @override
  void init(int l) {
    fall = 1.4 / (1 + l * .12);
    final n = 6 + math.min(l, 4);
    var tt = 1.4;
    for (var i = 0; i < n; i++) {
      notes.add([rng.nextInt(3).toDouble(), tt, 0]);
      tt += rnd(.4, .7) / (1 + l * .08);
    }
  }

  double noteY(List<double> n) => lineY - (n[1] - t) / fall * (lineY - topY);

  @override
  void update(double dt) {
    if (res != 0) return;
    for (final n in notes) {
      if (n[2] == 0 && t - n[1] > .22) {
        n[2] = -1;
        misses++;
        Sfx.play('eh', volume: .6);
      }
    }
    if (tap) {
      final lane = ((p.x - laneX(0)) / 104).round().clamp(0, 2);
      flashAt[lane] = vt;
      List<double>? best;
      for (final n in notes) {
        if (n[2] == 0 && n[0] == lane && (n[1] - t).abs() < .2) best = n;
      }
      if (best != null) {
        best[2] = 1;
        Sfx.play('note${lane + 1}');
        g.fx.burst(laneX(lane), lineY, [Pal.pink, Pal.gold, Pal.teal][lane], 10, size: 4);
      } else {
        misses++;
        Sfx.play('eh', volume: .6);
      }
    }
    if (misses >= maxMiss) {
      lose('¡Desafinado!');
    } else if (notes.every((n) => n[2] != 0) && t > notes.last[1] + .25) {
      win();
      Sfx.play('bonus');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    const cols = [Pal.pink, Pal.gold, Pal.teal];
    for (var i = 0; i < 3; i++) {
      final f = clamp01(1 - (vt - flashAt[i]) / .2);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(laneX(i) - 44, topY, laneX(i) + 44, lineY + 30), const Radius.circular(22)),
          Paint()..color = cols[i].withValues(alpha: .1 + f * .25));
    }
    c.drawLine(Offset(laneX(0) - 50, lineY), Offset(laneX(2) + 50, lineY),
        Paint()
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xDDFFF4E6));
    for (final n in notes) {
      if (n[2] != 0) continue;
      final y = noteY(n);
      if (y < topY - 20 || y > lineY + 40) continue;
      Gfx.note(c, laneX(n[0].toInt()), y, 44, cols[n[0].toInt()]);
    }
    Gfx.anim(c, 'worms', vt, cx, foot(.93), 150, ay: 1, fps: 14);
    for (var k = 0; k < maxMiss; k++) {
      Gfx.mark(c, k >= misses, sr - 30 - k * 36, st + 32, 30);
    }
  }
}

// ───────────────────────── 47. CARRERA DE CARACOLES (alternar) ─────────────────────────
class SnailRace extends Channel {
  SnailRace(super.g);
  @override
  String get name => 'CARRERA DE CARACOLES';
  @override
  String get sub => 'La gran final contra el caracol chulito';
  @override
  String get ins => '¡IZQUIERDA, DERECHA!';
  @override
  String get hint => 'Pulsa los dos botones alternando';
  @override
  String get bg => 'bg_race';
  @override
  double get dur => 7;

  double me = 0, rival = 0, rivalSpd = 0, stumble = 0, push = 0;
  int last = -1;
  double get start => bx(.1);
  double get finish => bx(.86);
  Rect btn(int i) => Rect.fromCenter(center: Offset(i == 0 ? bx(.24) : bx(.76), sb - 44), width: 150, height: 150 * kButtonAspect);

  @override
  void init(int l) {
    me = rival = start;
    rivalSpd = (finish - start) / (5.6 - math.min(l, 4) * .35);
  }

  @override
  void update(double dt) {
    stumble = math.max(0, stumble - dt);
    push = math.max(0, push - dt * 6);
    if (res != 0) return;
    rival += rivalSpd * dt;
    if (tap) {
      for (var i = 0; i < 2; i++) {
        if (!btn(i).inflate(8).contains(Offset(p.x, p.y))) continue;
        if (i != last && stumble <= 0) {
          me += 15;
          push = 1;
          Sfx.play('squish', volume: .5);
        } else {
          stumble = .25;
          Sfx.play('boing', volume: .5);
        }
        last = i;
      }
    }
    if (me >= finish) {
      win();
      Sfx.play('bonus');
      g.fx.burst(finish, by(.66), Pal.gold, 20);
    } else if (rival >= finish) {
      lose('¡Te ganó el chulito!');
      Sfx.play('lose');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, rival, by(.56), 90, alpha: .4);
    Gfx.anim(c, 'snail2', vt, rival, by(.565), 74, ay: 1, fps: 16);
    Gfx.shadow(c, me, by(.7), 100, alpha: .45);
    Gfx.anim(c, 'snail', vt * (1 + push), me, by(.705), 84, ay: 1, sx: 1 + push * .08, rot: stumble > 0 ? math.sin(vt * 40) * .08 : 0);
    Gfx.button(c, last == 0 ? 'btn_teal' : 'btn_gold', 'IZQ', btn(0), scale: last == 0 ? .94 : 1, size: 40);
    Gfx.button(c, last == 1 ? 'btn_teal' : 'btn_gold', 'DER', btn(1), scale: last == 1 ? .94 : 1, size: 40);
  }
}

// ───────────────────────── 48. PELA EL PLÁTANO (arrastrar en dirección) ─────────────────────────
class PeelBanana extends Channel {
  PeelBanana(super.g);
  @override
  String get name => 'PELA EL PLÁTANO';
  @override
  String get sub => 'Un plátano con muchas cosquillas en el spa';
  @override
  String get ins => '¡PÉLALO!';
  @override
  String get hint => 'Arrastra cada cáscara hacia fuera y abajo';
  @override
  String get bg => 'bg_spa';
  @override
  double get dur => 6;

  final open = [0.0, 0.0, 0.0]; // izquierda, centro, derecha (0 cerrada, 1 abierta)
  final done = [false, false, false];
  int grab = -1;
  double get base => by(.755);
  static const bh = 200.0;
  Offset get top => Offset(cx, base - bh + 30);
  Offset dirOf(int i) => [const Offset(-1, .6), const Offset(0, 1), const Offset(1, .6)][i];

  @override
  void init(int l) {}

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.pressed) {
      grab = -1;
      var best = 90.0;
      for (var i = 0; i < 3; i++) {
        if (done[i]) continue;
        final tip = Offset(cx + (i - 1) * 24, top.dy + 20);
        final d = (Offset(p.x, p.y) - tip).distance;
        if (d < best) {
          best = d;
          grab = i;
        }
      }
    }
    if (grab >= 0 && p.down) {
      final d = Offset(p.x - p.sx, p.y - p.sy);
      final dir = dirOf(grab);
      final proj = (d.dx * dir.dx + d.dy * dir.dy) / dir.distance;
      open[grab] = clamp01(proj / 120);
      if (open[grab] >= 1) {
        done[grab] = true;
        grab = -1;
        Sfx.play('squish');
      }
    }
    if (!p.down) {
      if (grab >= 0 && open[grab] > .7) {
        done[grab] = true;
        Sfx.play('squish');
      }
      grab = -1;
    }
    for (var i = 0; i < 3; i++) {
      if (done[i]) {
        open[i] = math.min(1, open[i] + dt * 6);
      } else if (grab != i) {
        open[i] = math.max(0, open[i] - dt * 4);
      }
    }
    if (done.every((d) => d)) {
      win();
      Sfx.play('bonus');
      g.fx.burst(cx, top.dy, Pal.gold, 20);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final wig = res == 1 ? math.sin(since * 20) * .04 * clamp01(1 - since) : 0.0;
    Gfx.anim(c, 'banana', vt, cx, base, bh, ay: 1, rot: wig, fps: 14);
    // cáscaras: cuelgan desde abajo y tapan la fruta; al abrir giran hacia fuera
    void peel(int i) {
      final o = open[i];
      final pivot = Offset(cx + (i - 1) * 25, base - 14);
      c.save();
      c.translate(pivot.dx, pivot.dy);
      if (i == 1) {
        // la del centro se dobla hacia delante (se acorta y cae)
        c.scale(1, 1 - o * 1.7);
      } else {
        c.rotate((i == 0 ? -1 : 1) * o * 2.4);
      }
      Gfx.sprite(c, 'peel', 0, 0, bh - 24, ay: 1, sx: i == 1 ? 2.0 : 1.8, flip: i == 2);
      c.restore();
    }

    peel(0);
    peel(2);
    peel(1);
    if (res == 0 && t < 1.5) {
      final k = (vt * 1.2) % 1;
      Gfx.sprite(c, 'finger', cx - 60 - k * 60, top.dy + 40 + k * 40, 50, rot: -.5, alpha: 1 - k);
    }
    final n = done.where((d) => d).length;
    Gfx.text(c, '$n/3', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 49. CAMALEÓN DESPISTADO (camuflaje) ─────────────────────────
class Chameleon extends Channel {
  Chameleon(super.g);
  @override
  String get name => 'CAMALEÓN DESPISTADO';
  @override
  String get sub => 'Un halcón vigila la pared de colores';
  @override
  String get ins => '¡CAMÚFLATE!';
  @override
  String get hint => 'Toca para cambiar de color como la pared';
  @override
  String get bg => 'bg_bands';
  @override
  double get dur => (bx(.93) - bx(.05)) / spd + 1;

  static const zoneCols = [Color(0xFFE8413A), Color(0xFF2F63DA), Color(0xFFF5C530)];
  final cycle = [0, 1, 2];
  int ci = 0;
  double x = 0, spd = 0, exposed = 0, changeAt = -9;
  double get ledge => by(.495);
  int get zone => ((x - bx(0)) / (449 / 3)).floor().clamp(0, 2);
  int get colIdx => cycle[ci];

  @override
  void init(int l) {
    spd = 62 + l * 10;
    x = bx(.05);
    cycle.shuffle(rng);
    ci = cycle.indexOf(0);
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    x += spd * dt;
    if (tap) {
      ci = (ci + 1) % 3;
      changeAt = vt;
      Sfx.play('pop', volume: .6);
    }
    if (colIdx != zone) {
      exposed += dt;
      if (exposed > .6) {
        lose('¡El halcón te ha visto!');
        Sfx.play('boing');
        g.fx.shake(8);
      }
    } else {
      exposed = 0;
    }
    if (x >= bx(.93)) {
      win();
      Sfx.play('bonus');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final pop = clamp01(1 - (vt - changeAt) / .2);
    Gfx.anim(c, 'chameleon', vt, x, ledge + 4, 70 * (1 + pop * .12), ay: 1, tint: zoneCols[colIdx]);
    // halcón vigilando, más cerca cuanto más expuesto
    final e = clamp01(exposed / .6);
    Gfx.sprite(c, 'hawk', cx + math.sin(vt * .8) * 120, st + 30 + e * 40, 110 + e * 30, ay: .6);
    if (e > 0) Gfx.text(c, '!', cx + math.sin(vt * .8) * 120 + 60, st + 20, 40, color: Pal.pink, alpha: e);
    // orden de colores: cuál viene al tocar
    for (var k = 0; k < 3; k++) {
      final idx = cycle[(ci + k) % 3];
      Gfx.clayBall(c, sl + 36 + k * 30, sb - 30, k == 0 ? 13 : 9, zoneCols[idx]);
    }
  }
}

// ───────────────────────── 50. SOMBRAS CHINESCAS (emparejar) ─────────────────────────
class ShadowPuppets extends Channel {
  ShadowPuppets(super.g);
  @override
  String get name => 'SOMBRAS CHINESCAS';
  @override
  String get sub => 'El titiritero hace sombras con la lámpara';
  @override
  String get ins => '¿QUÉ ANIMAL ES?';
  @override
  String get hint => 'Toca el animal de la sombra';
  @override
  String get bg => 'bg_shadow';
  @override
  double get dur => 4.5;

  static const animals = ['an_rabbit', 'an_elephant', 'an_giraffe', 'an_duck', 'an_crab', 'an_trex', 'an_pig'];
  final opts = <String>[];
  int answer = 0, picked = -1;
  bool flip = false;
  double rot = 0;
  Rect opt(int i) => Rect.fromCenter(center: Offset(cx + (i - 1) * 130, by(.84)), width: 112, height: 112);

  @override
  void init(int l) {
    final pool = [...animals]..shuffle(rng);
    opts.addAll(pool.take(3));
    answer = rng.nextInt(3);
    flip = rng.nextBool();
    rot = l >= 2 ? rnd(-.35, .35) : 0;
  }

  @override
  void update(double dt) {
    if (res != 0 || !tap) return;
    for (var i = 0; i < 3; i++) {
      if (opt(i).contains(Offset(p.x, p.y))) {
        picked = i;
        if (i == answer) {
          win();
          Sfx.play('bonus');
        } else {
          lose('¡Era otro animal!');
          Sfx.play('boing');
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // sombra sobre la pantalla de papel (silueta exacta del animal, borrosa y temblona)
    final sx = cx + math.sin(vt * 1.3) * 10, sy = by(.4);
    // al resolver, el animal aparece exactamente encima de su sombra (mismo tamaño, giro y lado)
    c.save();
    c.translate(sx, sy);
    c.rotate(rot + math.sin(vt * 2) * .03);
    c.scale(flip ? -1 : 1, 1);
    for (var k = 0; k < 3; k++) {
      Gfx.silhouette(c, opts[answer], 0, 0, 190);
    }
    if (res != 0) Gfx.sprite(c, opts[answer], 0, 0, 190, alpha: clamp01(since * 3));
    c.restore();
    for (var i = 0; i < 3; i++) {
      final r = opt(i);
      final s = picked == i ? 1.08 : 1 + math.sin(vt * 5 + i) * .02;
      final rr = Rect.fromCenter(center: r.center, width: r.width * s, height: r.height * s);
      Gfx.shadow(c, r.center.dx, r.bottom, r.width * .9, alpha: .4);
      Gfx.clayPanel(c, rr, const Color(0xFFF7F1E3));
      Gfx.sprite(c, opts[i], r.center.dx, r.center.dy, 70);
    }
  }
}

// ───────────────────────── 51. BAR DE MONSTRUOS (servir) ─────────────────────────
class MonsterBar extends Channel {
  MonsterBar(super.g);
  @override
  String get name => 'BAR DE MONSTRUOS';
  @override
  String get sub => 'Tres clientes con mucha sed';
  @override
  String get ins => '¡SIRVE!';
  @override
  String get hint => 'Arrastra a cada uno el batido que pide';
  @override
  String get bg => 'bg_monsterbar';
  @override
  double get dur => 7;

  static const cols = [Color(0xFFFF6FA8), Color(0xFF7FD3FF), Color(0xFFB7F26A), Color(0xFFFFC04A)];
  static const who = ['cyclops', 'slime', 'horned'];
  final want = <int>[]; // color que pide cada cliente
  final served = [false, false, false];
  final glasses = <List<double>>[]; // [color, x, y, en uso]
  int grab = -1;
  double get counter => by(.535);
  double custX(int i) => bx(.2 + i * .3);
  Offset home(int k) => Offset(bx(.12 + k * .19), sb - 14);
  Offset botFrom = Offset.zero; // solo para los tests con bot

  @override
  void init(int l) {
    final c = [0, 1, 2, 3]..shuffle(rng);
    want.addAll(c.take(3));
    final tray = [...c]..shuffle(rng);
    for (var k = 0; k < 4; k++) {
      glasses.add([tray[k].toDouble(), home(k).dx, home(k).dy, 0]);
    }
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.pressed) {
      for (var k = 0; k < glasses.length; k++) {
        final gl = glasses[k];
        if (gl[3] == 0 && (Offset(p.x, p.y) - Offset(gl[1], gl[2] - 30)).distance < 50) grab = k;
      }
    }
    if (grab >= 0 && p.down) {
      glasses[grab][1] = p.x;
      glasses[grab][2] = p.y + 30;
    }
    if (grab >= 0 && !p.down) {
      final gl = glasses[grab];
      var hit = -1;
      for (var i = 0; i < 3; i++) {
        if (!served[i] && (gl[1] - custX(i)).abs() < 60 && gl[2] < counter + 40) hit = i;
      }
      if (hit >= 0) {
        if (want[hit] == gl[0].toInt()) {
          served[hit] = true;
          gl[3] = 1;
          gl[1] = custX(hit) + 40;
          gl[2] = counter + 4;
          Sfx.play('gulp');
          g.fx.burst(custX(hit), counter - 60, cols[want[hit]], 14);
          if (served.every((s) => s)) {
            win();
            Sfx.play('bonus');
          }
        } else {
          lose('¡Ese batido no lo pidió!');
          Sfx.play('boing');
        }
      } else {
        final h = home(grab);
        gl[1] = h.dx;
        gl[2] = h.dy;
      }
      grab = -1;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var i = 0; i < 3; i++) {
      final ok = served[i];
      Gfx.sprite(c, who[i], custX(i), counter + 6, 118, ay: 1,
          rot: ok ? math.sin(vt * 10 + i) * .05 : boil(vt, i.toDouble()) * .02);
      if (!ok) {
        // bocadillo grande con el batido que pide (late para llamar la atención)
        final pulse = 1 + math.sin(vt * 5 + i * 2) * .05;
        final b = Offset(custX(i) + 14, counter - 168);
        final tail = Path()
          ..moveTo(b.dx - 14, b.dy + 40)
          ..lineTo(b.dx + 8, b.dy + 40)
          ..lineTo(custX(i) - 4, counter - 104)
          ..close();
        c.drawPath(tail, Paint()..color = const Color(0xFFF7F1E3));
        Gfx.clayPanel(c, Rect.fromCenter(center: b, width: 88 * pulse, height: 96 * pulse), const Color(0xFFF7F1E3));
        Gfx.sprite(c, 'glass', b.dx, b.dy + 2, 74 * pulse, tint: cols[want[i]]);
      } else {
        Gfx.mark(c, true, custX(i) + 30, counter - 120, 40);
      }
    }
    Gfx.anim(c, 'bartender', vt, bx(.9), foot(.97), 130, ay: 1);
    // bandeja con los batidos para arrastrar
    final tray = Rect.fromLTRB(bx(.03), by(.72), bx(.8), sb - 4);
    Gfx.clayPanel(c, tray, const Color(0xE62A1F3A), radius: 16);
    for (var k = 0; k < glasses.length; k++) {
      final gl = glasses[k];
      if (gl[3] == 1) continue;
      Gfx.sprite(c, 'glass', gl[1], gl[2], k == grab ? 96 : 84, ay: 1, tint: cols[gl[0].toInt()],
          drop: k == grab ? const Offset(8, 18) : const Offset(3, 5));
    }
    for (var k = 0; k < glasses.length; k++) {
      final gl = glasses[k];
      if (gl[3] == 1) Gfx.sprite(c, 'glass', gl[1], gl[2], 60, ay: 1, tint: cols[gl[0].toInt()]);
    }
    if (res == 0 && t < 2 && grab < 0) {
      final k = (vt * .8) % 1;
      final a = home(0), b = Offset(custX(0), counter);
      final o = Offset.lerp(a, b, k * k * (3 - 2 * k))!;
      Gfx.sprite(c, 'finger', o.dx + 14, o.dy - 20, 50, rot: -.3, alpha: 1 - k * .5);
    }
  }
}

// ───────────────────────── 52. ARTIFICIERO CONFUSO (Stroop) ─────────────────────────
class BombWires extends Channel {
  BombWires(super.g);
  @override
  String get name => 'ARTIFICIERO CONFUSO';
  @override
  String get sub => 'La bomba de gelatina dice un color y lo pinta de otro';
  @override
  String get ins => '¡COLOR DE LA TINTA!';
  @override
  String get hint => 'Corta el cable del COLOR de la letra, no de la palabra';
  @override
  String get bg => 'bg_bombroom';
  @override
  double get dur => 5;

  static const names = ['ROJO', 'AZUL', 'AMARILLO', 'VERDE'];
  static const cols = [Color(0xFFE8413A), Color(0xFF2F63DA), Color(0xFFF5C530), Color(0xFF3FB950)];
  final wires = <int>[]; // color de cada cable (de izquierda a derecha)
  int word = 0, ink = 0, cutW = -1;
  Offset get bombC => Offset(cx, by(.47));

  @override
  void init(int l) {
    final pool = [0, 1, 2, 3]..shuffle(rng);
    wires.addAll(pool.take(3));
    ink = pick(wires);
    word = pick([for (final w in wires) if (w != ink) w]);
  }

  // curva de cada cable: de la bomba a su borne del banco
  Offset wireAt(int i, double u) {
    final a = Offset(bombC.dx + (i - 1) * 34, bombC.dy + 60);
    final b = Offset(bx(.2 + i * .3), by(.76));
    final ctrl = Offset((a.dx + b.dx) / 2 + (i - 1) * 30, math.max(a.dy, b.dy) + 70);
    final p1 = Offset.lerp(a, ctrl, u)!, p2 = Offset.lerp(ctrl, b, u)!;
    return Offset.lerp(p1, p2, u)!;
  }

  bool _crosses(int i, Offset s0, Offset s1) {
    // ¿el trazo del dedo cruza la curva del cable?
    var prev = wireAt(i, 0);
    for (var k = 1; k <= 20; k++) {
      final cur = wireAt(i, k / 20);
      if (_segX(s0, s1, prev, cur)) return true;
      prev = cur;
    }
    return false;
  }

  static bool _segX(Offset a, Offset b, Offset c, Offset d) {
    double cross(Offset o, Offset p, Offset q) => (p.dx - o.dx) * (q.dy - o.dy) - (p.dy - o.dy) * (q.dx - o.dx);
    final d1 = cross(c, d, a), d2 = cross(c, d, b), d3 = cross(a, b, c), d4 = cross(a, b, d);
    return (d1 > 0) != (d2 > 0) && (d3 > 0) != (d4 > 0);
  }

  Offset? _last;

  @override
  void update(double dt) {
    if (res != 0) return;
    final f = Offset(p.x, p.y);
    if (p.down && _last != null) {
      for (var i = 0; i < 3; i++) {
        if (_crosses(i, _last!, f)) {
          cutW = i;
          Sfx.play('chop');
          if (wires[i] == ink) {
            win();
            Sfx.play('bonus');
          } else {
            lose('¡BOOM! Era el color de la tinta');
            Sfx.play('boom');
            g.fx.shake(14, .4);
            g.fx.burst(bombC.dx, bombC.dy, Pal.pink, 40, speed: 500);
          }
          break;
        }
      }
    }
    _last = p.down ? f : null;
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var i = 0; i < 3; i++) {
      final path = Path();
      final cut = cutW == i;
      for (var k = 0; k <= 24; k++) {
        final o = wireAt(i, k / 24);
        if (cut && k == 12) {
          path.moveTo(o.dx, o.dy + 10);
          continue;
        }
        k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      c.drawPath(path.shift(const Offset(3, 5)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x44000000));
      c.drawPath(path, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..color = cols[wires[i]]);
      c.drawPath(path.shift(const Offset(-2, -2)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = const Color(0x55FFFFFF));
      final b = wireAt(i, 1);
      Gfx.clayBall(c, b.dx, b.dy, 13, const Color(0xFF55565E));
    }
    final shake = res == 0 ? math.sin(vt * 30) * clamp01(t / dur) * 3 : 0.0;
    Gfx.sprite(c, 'bomb', bombC.dx + shake, bombC.dy, 150, drop: const Offset(6, 10));
    // la palabra en la pantalla del reloj (pintada con la tinta engañosa)
    Gfx.text(c, names[word], bombC.dx + shake, bombC.dy + 14, 26, color: cols[ink], fitW: 78);
    // mini tutorial: un dedo corta un cable gris deslizando por encima
    if (res == 0 && t < 3) {
      final r = Rect.fromLTWH(sr - 128, st + 12, 116, 86);
      Gfx.clayPanel(c, r, const Color(0xF22A1F3A), radius: 14);
      final k = (vt * .9) % 1;
      final wy = r.center.dy + 6;
      final cutNow = k > .5;
      final wp = Paint()
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFB0B4BE);
      if (cutNow) {
        c.drawLine(Offset(r.left + 22, wy), Offset(r.center.dx - 6, wy + 4), wp);
        c.drawLine(Offset(r.center.dx + 6, wy + 4), Offset(r.right - 22, wy), wp);
      } else {
        c.drawLine(Offset(r.left + 22, wy), Offset(r.right - 22, wy), wp);
      }
      final fy = lerp(r.top + 18, r.bottom - 12, k);
      c.drawLine(Offset(r.center.dx, r.top + 14), Offset(r.center.dx, fy), Paint()
        ..strokeWidth = 3
        ..color = Color.fromRGBO(255, 214, 90, .8));
      Gfx.sprite(c, 'finger', r.center.dx + 8, fy + 8, 30, rot: -.4);
      Gfx.text(c, 'DESLIZA', r.center.dx, r.top + 14, 14, color: Pal.gold);
    }
    final left = math.max(0, dur - t);
    Gfx.text(c, left.toStringAsFixed(1), bombC.dx + 50, bombC.dy - 70, 20, color: Pal.pink);
    Gfx.anim(c, 'bombtech', vt, bx(.12), foot(.99), 150, ay: 1);
  }
}

// ───────────────────────── 53. PIZZA VOLADORA (lanzar con el dedo) ─────────────────────────
class PizzaToss extends Channel {
  PizzaToss(super.g);
  @override
  String get name => 'PIZZA VOLADORA';
  @override
  String get sub => 'Reparto sin ascensor a un bloque de pisos';
  @override
  String get ins => '¡LANZA LA PIZZA!';
  @override
  String get hint => 'Arrastra hacia la ventana: la línea te enseña por dónde irá. Suelta para lanzar';
  @override
  String get bg => 'bg_building';
  @override
  double get dur => 8;

  int target = 0, got = 0, need = 2;
  Offset? fly;
  Offset v = Offset.zero;
  double spin = 0, popT = 0;
  final done = <int>{};
  static const g0 = 900.0;
  // centro del hueco de cada ventana (medido sobre el decorado) y su alféizar
  Offset win_(int i) => Offset(bx([.225, .5, .77][i % 3]), by([.14, .345, .545][i ~/ 3]));
  double sill(int i) => win_(i).dy + 31;
  Offset get hand => Offset(cx - 46, foot(.99) - 128);

  Offset _vel(Offset drag) {
    final len = drag.distance.clamp(40.0, 300.0);
    return drag / drag.distance * (560 + len * 1.9);
  }

  bool _hits(Offset o, int w) => (o - win_(w)).distance < 40;

  /// Bot de prueba: busca un arrastre que lleve la pizza a [w] (simulando el vuelo).
  Offset? aimFor(Offset w) {
    final wi = [for (var k = 0; k < 9; k++) k].firstWhere((k) => win_(k) == w);
    for (var len = 40.0; len <= 300; len += 6) {
      for (var a = -1.2; a <= 1.2; a += .03) {
        final d = Offset(math.sin(a), -math.cos(a)) * len;
        var o = hand, vv = _vel(d);
        for (var k = 0; k < 120; k++) {
          vv = Offset(vv.dx, vv.dy + g0 / 60);
          o += vv / 60;
          if (_hits(o, wi)) return d;
          if (o.dy > sb + 60) break;
        }
      }
    }
    return null;
  }

  @override
  void init(int l) {
    need = 2 + (l >= 3 ? 1 : 0);
    target = 3 + rng.nextInt(6);
  }

  @override
  void update(double dt) {
    popT += dt;
    if (fly != null) {
      v = Offset(v.dx, v.dy + g0 * dt);
      fly = fly! + v * dt;
      spin += dt * 12;
      final w = win_(target);
      if (_hits(fly!, target) && res == 0) {
        got++;
        done.add(target);
        Sfx.play('gulp');
        g.fx.burst(w.dx, w.dy, Pal.gold, 16);
        fly = null;
        if (got >= need) {
          win();
          Sfx.play('bonus');
        } else {
          var n = target;
          while (n == target || done.contains(n)) {
            n = rng.nextInt(9);
          }
          target = n;
          popT = 0;
        }
      } else if (fly!.dy > sb + 60 || fly!.dx < sl - 60 || fly!.dx > sr + 60) {
        fly = null;
        Sfx.play('splat', volume: .6);
      }
    }
    if (res != 0 || fly != null) return;
    final s = swipe(min: 30);
    if (s != null) {
      fly = hand;
      v = _vel(s);
      Sfx.play('click');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // clientes asomados a su ventana: el cuerpo se esconde bajo el alféizar
    void lean(int i, double rise, {bool eating = false}) {
      final w = win_(i);
      c.save();
      c.clipRect(Rect.fromLTRB(w.dx - 70, w.dy - 110, w.dx + 70, sill(i)));
      Gfx.sprite(c, 'hungry', w.dx, sill(i) + 18 - rise * 22, 66, ay: 1, rot: eating ? 0 : math.sin(vt * 8 + i) * .06);
      c.restore();
      if (eating) Gfx.sprite(c, 'pizza', w.dx + 14, sill(i) - 18, 26);
    }

    for (final i in done) {
      lean(i, 1, eating: true);
    }
    if (res != 1) {
      lean(target, clamp01(popT * 4));
      Gfx.text(c, '¡AQUÍ!', win_(target).dx, win_(target).dy - 52, 18, color: Pal.gold, scale: 1 + math.sin(vt * 10) * .08);
    }
    Gfx.anim(c, 'pizzaiolo', vt, cx, foot(.99), 160, ay: 1);
    // línea de puntos mientras arrastras: por dónde irá la pizza
    if (p.down && fly == null && res == 0) {
      final d = Offset(p.x - p.sx, p.y - p.sy);
      if (d.distance > 12) {
        var o = hand, vv = _vel(d);
        for (var k = 0; k < 70; k++) {
          vv = Offset(vv.dx, vv.dy + g0 / 60);
          o += vv / 60;
          if (k % 3 == 0) c.drawCircle(o, 4.5 - k * .04, Paint()..color = Color.fromRGBO(255, 214, 90, 1 - k / 80));
          if (o.dy > sb) break;
        }
      }
    }
    if (fly != null) {
      final k = clamp01((hand.dy - fly!.dy) / 400);
      Gfx.sprite(c, 'pizza', fly!.dx, fly!.dy, 56 - k * 20, rot: spin, drop: const Offset(6, 12));
    }
    if (res == 0 && t < 2.2 && !p.down) {
      final k = (vt * .8) % 1;
      Gfx.sprite(c, 'finger', hand.dx + 20 + k * 30, hand.dy + 30 - k * 90, 50, rot: -.3, alpha: 1 - k);
    }
    Gfx.text(c, '$got/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 54. EL OSO TIENE PICOR (buscar a ciegas) ─────────────────────────
class ItchyBear extends Channel {
  ItchyBear(super.g);
  @override
  String get name => 'EL OSO TIENE PICOR';
  @override
  String get sub => 'Encuentra el punto exacto donde le pica';
  @override
  String get ins => '¡RÁSCALE!';
  @override
  String get hint => 'Pasa el dedo por su espalda: cuanto más cerca, más se alegra';
  @override
  String get bg => 'bg_forest';
  @override
  double get dur => 7;

  Offset spot = Offset.zero;
  double hold = 0, warm = 0;
  double get base => foot(.97);
  static const bh = 380.0;

  @override
  void init(int l) {
    spot = Offset(cx + rnd(-70, 70), base - bh * rnd(.35, .62));
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.down && pointerIn) {
      final d = (Offset(p.x, p.y) - spot).distance;
      warm = clamp01(1 - d / 170);
      if (d < 26) {
        hold += dt;
        Sfx.play('squish', volume: .3, minGapMs: 180);
        if (hold > .9) {
          win();
          Sfx.play('bonus');
          g.fx.burst(spot.dx, spot.dy, Pal.gold, 20);
        }
      } else {
        hold = math.max(0, hold - dt);
      }
    } else {
      warm = math.max(0, warm - dt * 2);
      hold = math.max(0, hold - dt);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, cx, base - 4, 240, alpha: .45);
    Gfx.anim(c, 'bear', vt, cx, base, bh, ay: 1, fps: 12 + warm * 10, rot: res == 1 ? math.sin(since * 16) * .03 : 0);
    if (p.down && pointerIn && res == 0) {
      final f = Offset(p.x, p.y);
      // uñas rascando y termómetro de frío/caliente
      for (var k = 0; k < 3; k++) {
        c.drawLine(f.translate(-10 + k * 10.0, -10 + math.sin(vt * 30) * 4), f.translate(-6 + k * 10.0, 12 + math.sin(vt * 30) * 4),
            Paint()
              ..strokeWidth = 4
              ..strokeCap = StrokeCap.round
              ..color = const Color(0xCCFFFFFF));
      }
      final col = Color.lerp(const Color(0xFF7FD3FF), const Color(0xFFFF5C7A), warm)!;
      c.drawCircle(f, 30 + warm * 16, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = col.withValues(alpha: .8));
      if (warm > .7) Gfx.text(c, warm > .9 ? '¡AHÍ, AHÍ!' : '¡CALIENTE!', f.dx, f.dy - 56, 22, color: col);
    }
    Gfx.clayBar(c, Rect.fromLTWH(sl + 70, st + 22, S.width - 140, 18), clamp01(hold / .9), Pal.pink);
  }
}

// ───────────────────────── 55. ESTORNUDOS EN EL CINE (reaccionar) ─────────────────────────
class CinemaSneeze extends Channel {
  CinemaSneeze(super.g);
  @override
  String get name => 'ESTORNUDOS EN EL CINE';
  @override
  String get sub => 'Todo el público está resfriado';
  @override
  String get ins => '¡PAÑUELO!';
  @override
  String get hint => 'Toca al que va a estornudar antes de que lo haga';
  @override
  String get bg => 'bg_cinema';
  @override
  double get dur => 7;

  final build = [-1.0, -1.0, -1.0, -1.0]; // -1 tranquilo, ≥0 cargando el estornudo
  final saved = [-9.0, -9.0, -9.0, -9.0];
  int got = 0, need = 4, blew = -1;
  double next = .6, fuse = 1.3;
  double sx(int i) => bx(.14 + i * .24);
  double get sy => foot(.93);

  @override
  void init(int l) {
    need = 4 + math.min(l ~/ 2, 2);
    fuse = math.max(.8, 1.35 - l * .1);
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if ((next -= dt) <= 0) {
      final calm = [for (var i = 0; i < 4; i++) if (build[i] < 0 && t - saved[i] > .6) i];
      if (calm.isNotEmpty) build[pick(calm)] = 0;
      next = rnd(.5, .9);
    }
    for (var i = 0; i < 4; i++) {
      if (build[i] < 0) continue;
      build[i] += dt;
      if (build[i] > fuse) {
        blew = i;
        lose('¡AAACHÍS!');
        Sfx.play('splat');
        g.fx.burst(sx(i), sy - 110, const Color(0xFFB7F26A), 30, speed: 420);
        g.fx.shake(8);
        return;
      }
    }
    if (tap) {
      for (var i = 0; i < 4; i++) {
        if ((p.x - sx(i)).abs() < 50 && p.y > sy - 170 && build[i] >= 0) {
          build[i] = -1;
          saved[i] = t;
          got++;
          Sfx.play('pop');
          if (got >= need) {
            win();
            Sfx.play('bonus');
          }
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var i = 0; i < 4; i++) {
      final b = build[i];
      final k = b < 0 ? 0.0 : clamp01(b / fuse);
      final shake = b >= 0 ? math.sin(vt * (20 + k * 40)) * k * 4 : 0.0;
      Gfx.sprite(c, 'spec${i + 1}', sx(i) + shake, sy, 150, ay: 1, sy: 1 + k * .08, sx: 1 - k * .03);
      if (b >= 0) {
        final a = 'A' * (1 + (k * 3).floor());
        Gfx.text(c, '$a...', sx(i), sy - 175, 20 + k * 10, color: Color.lerp(Pal.gold, Pal.pink, k)!);
      }
      if (t - saved[i] < .7) Gfx.sprite(c, 'tissue', sx(i), sy - 135, 50, alpha: clamp01(1 - (t - saved[i]) / .7));
      if (blew == i) Gfx.sprite(c, 'splat', cx, cy - 40, 260 * clamp01(since * 5), tint: const Color(0xFFB7F26A), alpha: .85);
    }
    Gfx.text(c, '$got/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 56. DENTISTA DE COCODRILO (observar) ─────────────────────────
class CrocDentist extends Channel {
  CrocDentist(super.g);
  @override
  String get name => 'DENTISTA DE COCODRILO';
  @override
  String get sub => 'Uno de sus dientes está podrido';
  @override
  String get ins => '¡ARRANCA EL MALO!';
  @override
  String get hint => 'Agarra el diente podrido y tira de él. ¡Si es sano, muerde!';
  @override
  String get bg => 'bg_dentist';
  @override
  double get dur => 6;

  final teeth = <Offset>[];
  final upper = <bool>[];
  int bad = 0, picked = -1, grab = -1;
  double subtle = 1, pull = 0;
  Offset grabAt = Offset.zero;
  double get base => foot(.98);
  static const ch = 380.0, th = 46.0, pullNeed = 48.0;
  // encías medidas sobre el vídeo del cocodrilo: arriba siguiendo el labio, abajo a los lados de la lengua
  static const upperJaw = [[.22, .49], [.34, .45], [.5, .44], [.66, .45], [.78, .49]];
  static const lowerJaw = [[.22, .725], [.33, .79], [.67, .79], [.78, .725]];

  @override
  void init(int l) {
    final w = ch * Gfx.aspect('croc');
    final x0 = cx - w / 2, y0 = base - ch;
    for (final j in upperJaw) {
      teeth.add(Offset(x0 + j[0] * w, y0 + j[1] * ch));
      upper.add(true);
    }
    for (final j in lowerJaw) {
      teeth.add(Offset(x0 + j[0] * w, y0 + j[1] * ch));
      upper.add(false);
    }
    bad = rng.nextInt(teeth.length);
    subtle = math.max(.35, 1 - l * .15);
  }

  /// Centro del diente (el ancla es la encía; la punta va hacia dentro de la boca).
  Offset toothCenter(int i) => teeth[i] + Offset(0, upper[i] ? th / 2 : -th / 2);

  @override
  void update(double dt) {
    if (res != 0) return;
    final f = Offset(p.x, p.y);
    if (p.pressed) {
      grab = -1;
      var bd = 30.0;
      for (var i = 0; i < teeth.length; i++) {
        final d = (f - toothCenter(i)).distance;
        if (d < bd) {
          bd = d;
          grab = i;
        }
      }
      grabAt = f;
      pull = 0;
    }
    if (grab >= 0 && p.down) {
      pull = (f - grabAt).distance;
      Sfx.play('ratchet', volume: .25, minGapMs: 140);
      if (pull >= pullNeed) {
        picked = grab;
        if (grab == bad) {
          win();
          Sfx.play('pop');
          Sfx.play('bonus');
        } else {
          lose('¡ÑAM! Ese estaba sano');
          Sfx.play('boing');
          g.fx.shake(12, .3);
        }
        grab = -1;
      }
    }
    if (!p.down) {
      grab = -1;
      pull = 0;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final bite = res == -1 ? clamp01(since * 6) : 0.0;
    Gfx.anim(c, 'croc', vt, cx, base, ch, ay: 1, sy: 1 - bite * .35);
    if (bite > .8) return;
    for (var i = 0; i < teeth.length; i++) {
      final o = teeth[i];
      final isBad = i == bad;
      if (i == picked) {
        // el diente arrancado sale volando
        final k = since;
        Gfx.sprite(c, isBad ? 'tooth_bad' : 'tooth', o.dx + k * 140, o.dy - k * 260 + k * k * 700, th, rot: k * 9);
        continue;
      }
      // el diente agarrado se estira un poco hacia el dedo y tiembla
      var off = Offset.zero;
      var wob = isBad ? math.sin(vt * 14) * .07 * subtle : 0.0;
      if (i == grab) {
        final d = Offset(p.x, p.y) - grabAt;
        off = d.distance == 0 ? Offset.zero : d / d.distance * math.min(pull, pullNeed) * .35;
        wob += math.sin(vt * 40) * .08;
      }
      Gfx.sprite(c, isBad ? 'tooth_bad' : 'tooth', o.dx + off.dx, o.dy + off.dy, th,
          ay: 0, rot: wob + (upper[i] ? 0 : math.pi), drop: const Offset(2, 3));
    }
    if (grab >= 0) {
      Gfx.clayBar(c, Rect.fromLTWH(cx - 80, st + 20, 160, 16), clamp01(pull / pullNeed), Pal.gold);
      Gfx.text(c, '¡TIRA!', cx, st + 50, 20, color: Pal.gold);
    } else if (res == 0 && t < 2.4) {
      final k = (vt * .9) % 1;
      final o = toothCenter(2);
      Gfx.sprite(c, 'finger', o.dx + 10, o.dy + 20 + k * 50, 48, rot: -.3, alpha: 1 - k);
    }
  }
}

// ───────────────────────── 57. ASCENSOR DEL HOTEL (inercia) ─────────────────────────
class HotelLift extends Channel {
  HotelLift(super.g);
  @override
  String get name => 'ASCENSOR DEL HOTEL';
  @override
  String get sub => 'El botones lleva fantasmas a su planta';
  @override
  String get ins => '¡A SU PLANTA!';
  @override
  String get hint => 'Mantén las flechas y frena justo en la planta';
  @override
  String get bg => 'bg_hotel';
  @override
  double get dur => 9;

  double y = 0, v = 0, still = 0, doorT = -9;
  int want = 2, got = 0, need = 2;
  static const floors = [.87, .70, .53, .36];
  double floorY(int f) => by(floors[f]);
  Rect btn(int i) => Rect.fromCenter(center: Offset(sr - 44, sb - 120 + i * 84), width: 72, height: 72);

  @override
  void init(int l) {
    y = floorY(0);
    want = 2 + rng.nextInt(2);
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    var acc = 0.0;
    if (p.down && btn(0).inflate(10).contains(Offset(p.x, p.y))) acc = -520;
    if (p.down && btn(1).inflate(10).contains(Offset(p.x, p.y))) acc = 520;
    if (acc == 0) {
      // freno suave: la cabina sigue un poco por inercia
      final f = 260 * dt;
      v = v.abs() <= f ? 0 : v - v.sign * f;
    } else {
      v = (v + acc * dt).clamp(-240.0, 240.0);
      Sfx.play('ratchet', volume: .25, minGapMs: 160);
    }
    y += v * dt;
    y = y.clamp(floorY(3), floorY(0));
    if (y == floorY(3) || y == floorY(0)) v = 0;
    if (vt - doorT < .7) return;
    if ((y - floorY(want)).abs() < 9 && v.abs() < 30) {
      still += dt;
      if (still > .3) {
        still = 0;
        got++;
        doorT = vt;
        Sfx.play('bonus');
        g.fx.burst(cx, y - 50, const Color(0xFFFFFFFF), 14);
        if (got >= need) {
          win();
        } else {
          var n = want;
          while (n == want) {
            n = rng.nextInt(4);
          }
          want = n;
        }
      }
    } else {
      still = 0;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var f = 0; f < 4; f++) {
      final fy = floorY(f);
      final isWant = f == want && res == 0;
      Gfx.clayBall(c, bx(.3), fy - 60, 16, isWant ? Pal.gold : const Color(0xFF6A5A7A));
      Gfx.text(c, '$f', bx(.3), fy - 60, 20, color: isWant ? Pal.ink : Pal.dim);
      if (isWant) Gfx.sprite(c, 'arrow', bx(.3) - 34, fy - 60, 22, rot: 0, alpha: .6 + math.sin(vt * 8) * .4);
    }
    // cabina con el fantasma dentro (o saliendo)
    final dk = vt - doorT;
    Gfx.shadow(c, cx, y + 2, 70, alpha: .3);
    Gfx.sprite(c, 'cabin', cx, y + 4, 96, ay: 1);
    if (dk > .7 || res == 1) {
      Gfx.sprite(c, 'ghost', cx, y - 40 + math.sin(vt * 4) * 3, 46);
      Gfx.clayBall(c, cx + 24, y - 78, 13, Pal.gold);
      Gfx.text(c, '$want', cx + 24, y - 78, 16);
    } else {
      Gfx.sprite(c, 'ghost', cx + dk * 160, y - 40 - dk * 30, 46, alpha: clamp01(1 - dk / .7));
    }
    Gfx.anim(c, 'bellhop', vt, bx(.1), foot(.97), 110, ay: 1);
    Gfx.button(c, 'btn_teal', '', btn(0), size: 30);
    Gfx.sprite(c, 'arrow', btn(0).center.dx, btn(0).center.dy - 4, 30, rot: -math.pi / 2);
    Gfx.button(c, 'btn_pink', '', btn(1), size: 30);
    Gfx.sprite(c, 'arrow', btn(1).center.dx, btn(1).center.dy - 4, 30, rot: math.pi / 2);
    Gfx.text(c, '$got/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 58. EL TREN DE JUGUETE (agujas) ─────────────────────────
class ToyTrain extends Channel {
  ToyTrain(super.g);
  @override
  String get name => 'EL TREN DE JUGUETE';
  @override
  String get sub => 'Cada tren a la estación de su color';
  @override
  String get ins => '¡CAMBIA LAS AGUJAS!';
  @override
  String get hint => 'Toca para desviar el tren arriba o abajo';
  @override
  String get bg => 'bg_toyfloor';
  @override
  double get dur => 9;

  static const cols = [Color(0xFFFF5C7A), Color(0xFF53D8C3)];
  bool up = true;
  double d = -1, spd = 0, flip = 0;
  int color = 0, got = 0, need = 3;
  late List<Offset> trunk, top, bottom;

  @override
  void init(int l) {
    spd = 200 + l * 20;
    final j = Offset(bx(.4), by(.52));
    trunk = [Offset(ZappingGame.bleed.left - 60, j.dy), j];
    top = _curve(j, Offset(bx(.62), by(.52)), Offset(bx(.84), by(.26)));
    bottom = _curve(j, Offset(bx(.62), by(.52)), Offset(bx(.84), by(.78)));
    _newTrain();
  }

  List<Offset> _curve(Offset a, Offset ctrl, Offset b) => [
        for (var k = 0; k <= 16; k++)
          Offset.lerp(Offset.lerp(a, ctrl, k / 16)!, Offset.lerp(ctrl, b, k / 16)!, k / 16)!,
      ];

  void _newTrain() {
    d = 40;
    color = rng.nextInt(2);
  }

  double _len(List<Offset> pts) {
    var s = 0.0;
    for (var i = 1; i < pts.length; i++) {
      s += (pts[i] - pts[i - 1]).distance;
    }
    return s;
  }

  (Offset, double) _at(List<Offset> pts, double dist) {
    for (var i = 1; i < pts.length; i++) {
      final seg = (pts[i] - pts[i - 1]).distance;
      if (dist <= seg) {
        final o = Offset.lerp(pts[i - 1], pts[i], dist / seg)!;
        final dd = pts[i] - pts[i - 1];
        return (o, math.atan2(dd.dy, dd.dx));
      }
      dist -= seg;
    }
    final dd = pts.last - pts[pts.length - 2];
    return (pts.last, math.atan2(dd.dy, dd.dx));
  }

  // la rama se decide al pasar por la aguja
  bool? branchUp;

  @override
  void update(double dt) {
    flip = math.max(0, flip - dt * 4);
    if (res != 0) return;
    if (tap) {
      up = !up;
      flip = 1;
      Sfx.play('tick');
    }
    d += spd * dt;
    final lt = _len(trunk);
    if (d > lt && branchUp == null) branchUp = up;
    if (branchUp != null && d > lt + _len(branchUp! ? top : bottom)) {
      final station = branchUp! ? 0 : 1;
      if (station == color) {
        got++;
        Sfx.play('bonus');
        g.fx.burst((branchUp! ? top : bottom).last.dx, (branchUp! ? top : bottom).last.dy, cols[color], 16);
        if (got >= need) {
          win();
          return;
        }
        branchUp = null;
        _newTrain();
      } else {
        lose('¡Estación equivocada!');
        Sfx.play('boing');
      }
    }
  }

  void _track(Canvas c, List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final o in pts.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    // traviesas
    for (var s = 0.0; s < _len(pts); s += 18) {
      final (o, a) = _at(pts, s);
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(a);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: 8, height: 34), const Radius.circular(3)),
          Paint()..color = const Color(0xFF7A4A2A));
      c.restore();
    }
    for (final off in [-10.0, 10.0]) {
      c.drawPath(path.shift(Offset(0, off)), Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = const Color(0xFF9AA0AA));
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    _track(c, trunk);
    _track(c, top);
    _track(c, bottom);
    Gfx.sprite(c, 'station', top.last.dx + 26, top.last.dy - 10, 86, tint: cols[0], drop: const Offset(4, 6));
    Gfx.sprite(c, 'station', bottom.last.dx + 26, bottom.last.dy - 10, 86, tint: cols[1], drop: const Offset(4, 6));
    // palanca de la aguja: base, palo y pomo son una sola pieza que gira junta
    final j = trunk.last;
    final pv = Offset(j.dx - 4, j.dy + 46);
    final ang = (up ? -.55 : .55) + math.sin(flip * math.pi) * (up ? -.12 : .12);
    Gfx.shadow(c, pv.dx, pv.dy + 6, 54, alpha: .45);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: pv, width: 40, height: 14), const Radius.circular(7)),
        Paint()..color = const Color(0xFF3A3346));
    final tip = pv + Offset(math.sin(ang) * 46, -math.cos(ang) * 46);
    c.drawLine(pv, tip, Paint()
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6F7480));
    c.drawLine(pv + const Offset(-2, -2), tip + const Offset(-2, -2), Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x55FFFFFF));
    Gfx.clayBall(c, tip.dx, tip.dy, 13, up ? cols[0] : cols[1]);
    Gfx.clayBall(c, pv.dx, pv.dy, 7, const Color(0xFF9AA0AA));
    // flecha hacia la vía elegida, del color de su estación
    Gfx.sprite(c, 'arrow', j.dx + 34, j.dy + (up ? -24 : 24), 26, rot: up ? -.6 : .6, tint: up ? cols[0] : cols[1]);
    // tren
    if (res != 1) {
      final lt = _len(trunk);
      final (o, a) = d <= lt ? _at(trunk, d) : _at((branchUp ?? up) ? top : bottom, d - lt);
      Gfx.sprite(c, 'loco', o.dx, o.dy, 38, rot: a, tint: cols[color], drop: const Offset(4, 6));
    }
    Gfx.text(c, '$got/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 59. ROBOT AL REVÉS (control invertido) ─────────────────────────
class MirrorRobot extends Channel {
  MirrorRobot(super.g);
  @override
  String get name => 'ROBOT AL REVÉS';
  @override
  String get sub => 'Al robot le han cruzado los cables';
  @override
  String get ins => '¡TODO AL REVÉS!';
  @override
  String get hint => 'Arrastra: el robot va justo al contrario';
  @override
  String get bg => 'bg_labfloor';
  @override
  double get dur => 7;

  Offset r = Offset.zero, bat = Offset.zero;
  final goos = <Offset>[];
  Offset? last;
  double walk = 0;
  bool face = false;

  @override
  void init(int l) {
    r = Offset(bx(.22), by(.82));
    bat = Offset(bx(.8), by(.25));
    final n = 2 + math.min(l, 2);
    for (var i = 0; i < n; i++) {
      final u = (i + 1) / (n + 1);
      final base = Offset.lerp(r, bat, u)!;
      goos.add(base + Offset(rnd(-50, 50), rnd(-30, 30)));
    }
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    final f = Offset(p.x, p.y);
    if (p.down && last != null) {
      final d = f - last!;
      final nr = r - d * 1.1;
      if ((nr - r).distance > .5) {
        walk += dt;
        face = nr.dx < r.dx;
      }
      r = Offset(nr.dx.clamp(sl + 20, sr - 20), nr.dy.clamp(st + 40, sb - 10));
    }
    last = p.down ? f : null;
    for (final gp in goos) {
      if ((Offset((r.dx - gp.dx) / 46, (r.dy - gp.dy) / 26)).distance < 1) {
        lose('¡Al charco de moco!');
        Sfx.play('splat');
        return;
      }
    }
    if ((r - bat).distance < 38) {
      win();
      Sfx.play('bonus');
      g.fx.burst(bat.dx, bat.dy - 30, Pal.gold, 24);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (final gp in goos) {
      Gfx.sprite(c, 'goo', gp.dx, gp.dy, 56, sx: 1 + boil(vt, gp.dx) * .04);
    }
    Gfx.shadow(c, bat.dx, bat.dy + 2, 60, alpha: .4);
    Gfx.sprite(c, 'battery', bat.dx, bat.dy + 4, 70, ay: 1, sy: 1 + math.sin(vt * 6) * .03);
    final sink = res == -1 ? clamp01(since * 3) : 0.0;
    Gfx.shadow(c, r.dx, r.dy + 2, 60, alpha: .4 * (1 - sink));
    Gfx.anim(c, 'robot', walk, r.dx, r.dy + 4 + sink * 30, 80 * (1 - sink * .5), ay: 1, flip: face, alpha: 1 - sink * .6);
    if (p.down && pointerIn && res == 0) {
      // eco del dedo: flecha fantasma hacia donde va de verdad
      Gfx.text(c, '¡AL REVÉS!', r.dx, r.dy - 96, 16, color: Pal.pink, alpha: .8);
    }
  }
}

// ───────────────────────── 60. LA BALANZA DEL MERCADO (equilibrar) ─────────────────────────
class MarketScale extends Channel {
  MarketScale(super.g);
  @override
  String get name => 'LA BALANZA DEL MERCADO';
  @override
  String get sub => 'La morsa frutera pesa una sandía';
  @override
  String get ins => '¡EQUILÍBRALA!';
  @override
  String get hint => 'Arrastra pesas al platillo hasta que quede recta';
  @override
  String get bg => 'bg_market';
  @override
  double get dur => 8;

  static const kinds = [1, 1, 2, 2, 5];
  final onPan = [false, false, false, false, false];
  final pos = <Offset>[];
  int melon = 0, grab = -1;
  double tilt = 0, tv = 0, level = 0;
  Offset get pivot => Offset(cx, by(.33));
  static const arm = 118.0;
  Offset tray(int k) => Offset(bx(.14 + k * .18), by(.8));
  Offset panAt(double side) => pivot + Offset(side * arm * math.cos(tilt), side * arm * math.sin(tilt)) + const Offset(0, 96);
  int get right => [for (var k = 0; k < 5; k++) if (onPan[k]) kinds[k]].fold(0, (a, b) => a + b);
  Offset botFrom = Offset.zero; // solo para los tests con bot

  /// Bot de prueba: pesas que suman exactamente lo que pesa la sandía.
  List<int> botSubset() {
    for (var mask = 1; mask < 32; mask++) {
      var sum = 0;
      for (var k = 0; k < 5; k++) {
        if (mask & (1 << k) != 0) sum += kinds[k];
      }
      if (sum == melon) return [for (var k = 0; k < 5; k++) if (mask & (1 << k) != 0) k];
    }
    return [];
  }

  @override
  void init(int l) {
    melon = pick([3, 4, 6, 7, 8, 9]);
    for (var k = 0; k < 5; k++) {
      pos.add(tray(k));
    }
  }

  @override
  void update(double dt) {
    // el brazo gira hacia el lado que más pesa (muelle con rozamiento)
    final target = ((melon - right) * .07).clamp(-.32, .32);
    tv += ((target - tilt) * 60 - tv * 9) * dt;
    tilt += tv * dt;
    if (res != 0) return;
    if (p.pressed) {
      for (var k = 0; k < 5; k++) {
        if ((Offset(p.x, p.y) - pos[k]).distance < 44) grab = k;
      }
    }
    if (grab >= 0 && p.down) pos[grab] = Offset(p.x, p.y);
    if (grab >= 0 && !p.down) {
      final pan = panAt(1);
      onPan[grab] = (pos[grab] - pan).distance < 80;
      Sfx.play(onPan[grab] ? 'squish' : 'click', volume: .7);
      grab = -1;
    }
    for (var k = 0; k < 5; k++) {
      if (k == grab) continue;
      if (onPan[k]) {
        final i = [for (var j = 0; j < 5; j++) if (onPan[j]) j].indexOf(k);
        pos[k] = panAt(1) + Offset((i - 1.5) * 20, -18 - (i ~/ 3) * 18);
      } else {
        pos[k] = Offset.lerp(pos[k], tray(k), 1 - math.exp(-dt * 12))!;
      }
    }
    if (right == melon && tilt.abs() < .03) {
      level += dt;
      if (level > .4) {
        win();
        Sfx.play('bonus');
        g.fx.burst(pivot.dx, pivot.dy, Pal.gold, 24);
      }
    } else {
      level = 0;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'walrus', vt, bx(.9), by(.64), 125, ay: 1);
    Gfx.sprite(c, 'scalebase', pivot.dx, by(.64), by(.64) - pivot.dy + 16, ay: 1);
    // brazo de la balanza (latón)
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(tilt);
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-arm - 6, -7, arm * 2 + 12, 14), const Radius.circular(7)),
        Paint()..color = const Color(0xFFB8862E));
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(-arm - 6, -7, arm * 2 + 12, 5), const Radius.circular(4)),
        Paint()..color = const Color(0x55FFFFFF));
    c.restore();
    Gfx.clayBall(c, pivot.dx, pivot.dy, 10, const Color(0xFFD9A441));
    for (final side in [-1.0, 1.0]) {
      final pa = panAt(side);
      Gfx.sprite(c, 'pan', pa.dx, pa.dy + 8, 112, ay: .92);
    }
    final lp = panAt(-1);
    Gfx.sprite(c, 'watermelon', lp.dx, lp.dy - 6, 64, ay: 1);
    // aguja
    c.save();
    c.translate(pivot.dx, pivot.dy);
    c.rotate(tilt);
    c.drawLine(Offset.zero, const Offset(0, -46), Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = level > 0 ? Pal.lime : Pal.pink);
    c.restore();
    // bandeja clara con las pesas (antes se perdían sobre el fondo oscuro)
    final trayR = Rect.fromLTRB(bx(.05), by(.715), bx(.95), sb - 4);
    Gfx.clayPanel(c, trayR, const Color(0xFFF7F1E3), radius: 16);
    Gfx.text(c, 'PESAS', trayR.left + 44, trayR.top + 16, 14, color: const Color(0xFF6A3FA0));
    for (var k = 0; k < 5; k++) {
      final o = pos[k];
      final h = 44.0 + kinds[k] * 7;
      final lift = k == grab ? 1.08 : 1 + math.sin(vt * 4 + k) * .015;
      Gfx.sprite(c, 'weight', o.dx, o.dy + h / 2, h * lift, ay: 1, drop: k == grab ? const Offset(6, 14) : const Offset(2, 4));
      Gfx.clayBall(c, o.dx, o.dy + h * .12, 12 + kinds[k] * .8, Pal.gold);
      Gfx.text(c, '${kinds[k]}', o.dx, o.dy + h * .12, 16.0 + kinds[k], color: Pal.ink);
    }
    Gfx.text(c, '?', lp.dx, lp.dy - 38, 26, color: Pal.gold);
    Gfx.text(c, 'PESAS: $right', bx(.72), st + 34, 20, color: Pal.gold);
    // demostración: un dedo arrastra una pesa al platillo
    if (res == 0 && t < 2.6 && grab < 0 && right == 0) {
      final k = (vt * .7) % 1;
      final e = k * k * (3 - 2 * k);
      final o = Offset.lerp(tray(0), panAt(1), e)!;
      Gfx.sprite(c, 'weight', o.dx, o.dy + 25, 50, ay: 1, alpha: .6);
      Gfx.sprite(c, 'finger', o.dx + 16, o.dy + 10, 50, rot: -.3, alpha: 1 - k * .4);
      Gfx.text(c, 'ARRASTRA LAS PESAS AL PLATILLO', cx, trayR.top - 16, 17, color: Pal.gold, maxW: S.width - 30);
    }
  }
}
