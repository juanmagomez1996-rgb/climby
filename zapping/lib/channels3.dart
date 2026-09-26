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
    Gfx.anim(c, 'detective', vt, bx(.1), by(.935), 130, ay: 1);
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
      items.add(_Fall(bx(.14), by(.5), rnd(120, 300), rnd(-460, -300), boot));
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
    Gfx.anim(c, 'nonna', vt, bx(.12), by(.655), 150, ay: 1);
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
    y = cy;
    spd = 190 + l * 22;
    gap = math.max(150, 190 - l * 10);
    need = 3;
    var x = sr + 80;
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
      vy -= 2300 * dt;
      Sfx.play('shake', volume: .2, minGapMs: 120);
      if (rng.nextDouble() < .6) g.fx.burst(cxp - 30, y + 18, Pal.gold, 1, speed: 140, size: 5);
    }
    vy += 1100 * dt;
    vy = vy.clamp(-420.0, 480.0);
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
    Gfx.anim(c, 'octopus', vt, cx, tableY - 38, 190, ay: 1);
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
    Gfx.anim(c, 'washer', vt, bx(.85), by(.93), 150, ay: 1);
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
    need = 4 + math.min(l ~/ 2, 2);
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
    Gfx.anim(c, 'dogchef', vt, bx(.16), by(.95), 170, ay: 1);
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
    Gfx.anim(c, 'shepherd', vt, bx(.14), by(.93), 150, ay: 1);
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
