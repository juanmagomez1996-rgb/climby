import 'dart:math' as math;
import 'dart:ui';

import 'channels.dart';
import 'channels4.dart';
import 'game.dart';
import 'gfx.dart';
import 'sfx.dart';

// Canales 73–85 (ver docs/canales_61_85.md): atrapar con red, memorizar un camino, copiar un
// peinado, inflar con bomba, cortar por la mitad, bajar un río, hacer una foto, unir estrellas,
// encajar figuras, deslizar sobre hielo, empujar en el ring, desenredar cables y jenga.

final List<ChannelFactory> newChannels = [
  HamsterMaze.new, Plumber.new, EggBounce.new, CeilingCat.new, MuseumLasers.new,
  Tarzan.new, BlindTimer.new, MoreCandy.new, Cashier.new, SpellWord.new,
  PaintNumbers.new, Fireworks.new, CatchHen.new, MousePath.new, AlienSalon.new,
  BikePump.new, Tortilla.new, BathRace.new, YetiPhoto.new, Constellations.new,
  ShapeFit.new, PenguinSlide.new, SumoMochi.new, Untangle.new, WaffleJenga.new,
];

// ───────────────────────── 73. ATRAPA LA GALLINA (red) ─────────────────────────
class CatchHen extends Channel {
  CatchHen(super.g);
  @override
  String get name => 'ATRAPA LA GALLINA';
  @override
  String get sub => 'Clotilde se ha escapado del corral';
  @override
  String get ins => '¡ATRÁPALA CON LA RED!';
  @override
  String get hint => 'Lleva la red encima de la gallina y suelta el dedo para atraparla';
  @override
  String get bg => 'bg_farmyard';
  @override
  double get dur => 10;

  Offset hen = Offset.zero, hv = Offset.zero, net = Offset.zero, goal = Offset.zero;
  double dropAt = -1, rest = 0, flee = 0, speed = 230, peck = 0;
  bool hovering = false;
  Rect get yard => Rect.fromLTRB(sl + 36, by(.34), sr - 36, sb - 26);
  static const dropT = .2, catchR = 44.0;

  @override
  void init(int l) {
    speed = 225 + l * 18;
    hen = Offset(cx + rnd(-80, 80), cy + 60);
    net = Offset(cx, sb - 70);
    goal = hen;
  }

  bool get resting => rest > 0;

  @override
  void update(double dt) {
    if (res != 0) return;
    // red: sigue al dedo con velocidad limitada; al soltar cae
    if (dropAt < 0) {
      hovering = p.down;
      if (p.down) {
        final d = Offset(p.x, p.y) - net;
        final m = 620 * dt;
        net += d.distance <= m ? d : d / d.distance * m;
      }
      if (p.released) {
        dropAt = t;
        hovering = false;
        Sfx.play('click');
      }
    } else if (t - dropAt >= dropT && t - dropAt - dt < dropT) {
      if ((net - hen).distance < catchR) {
        win();
        Sfx.play('bonus');
        g.fx.burst(hen.dx, hen.dy - 20, const Color(0xFFB5622D), 16, size: 5);
        return;
      }
      Sfx.play('eh');
      g.fx.float('¡SE ESCAPÓ!', net.dx, net.dy - 50, Pal.pink, 20);
    } else if (t - dropAt > dropT + .35) {
      dropAt = -1;
    }
    // gallina
    final dn = hen - net;
    final threat = (hovering || (dropAt >= 0 && t - dropAt < dropT)) && dn.distance < 125;
    if (rest > 0) {
      rest -= dt;
      peck += dt;
      hv *= math.pow(.01, dt).toDouble();
    } else if (threat && flee <= 0) {
      flee = rnd(.45, .7);
      final away = dn.distance < 1 ? const Offset(1, 0) : dn / dn.distance;
      final side = Offset(-away.dy, away.dx) * (rng.nextBool() ? 1 : -1) * rnd(.2, .9);
      hv = (away + side) * speed;
      Sfx.play('squish', volume: .4, minGapMs: 300);
    }
    if (flee > 0) {
      flee -= dt;
      if (flee <= 0) rest = rnd(.35, .6);
    } else if (rest <= 0 && !threat) {
      if ((goal - hen).distance < 12) {
        goal = Offset(rnd(yard.left, yard.right), rnd(yard.top, yard.bottom));
      }
      final d = goal - hen;
      hv = d / math.max(1, d.distance) * 85;
    }
    hen += hv * dt;
    if (hen.dx < yard.left || hen.dx > yard.right) hv = Offset(-hv.dx, hv.dy);
    if (hen.dy < yard.top || hen.dy > yard.bottom) hv = Offset(hv.dx, -hv.dy);
    hen = Offset(hen.dx.clamp(yard.left, yard.right), hen.dy.clamp(yard.top, yard.bottom));
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final scale = .7 + (hen.dy - yard.top) / yard.height * .45;
    Gfx.shadow(c, hen.dx, hen.dy, 70 * scale, alpha: .4);
    Gfx.anim(c, 'hen', vt, hen.dx, hen.dy + 2, 78 * scale, ay: 1, flip: hv.dx < 0, fps: flee > 0 ? 20 : 12,
        rot: rest > 0 ? math.sin(peck * 14) * .12 : 0);
    // red: arriba mientras se mueve, baja al soltar
    final k = dropAt < 0 ? 0.0 : clamp01((t - dropAt) / dropT);
    final lift = dropAt < 0 ? (hovering ? 46.0 : 30.0) : (1 - k) * 46;
    Gfx.shadow(c, net.dx, net.dy + 6, 100 * (1 - lift / 120), alpha: .3 + k * .2);
    Gfx.sprite(c, 'net', net.dx + 22, net.dy - lift + 18, 128 * (1 + lift / 300), alpha: .95);
    if (res == 0 && t < 2 && !p.down) fingerAt(c, net + Offset(0, math.sin(vt * 9) * 4));
  }
}

// ───────────────────────── 74. EL CAMINO DEL RATÓN (memoria de recorrido) ─────────────────────────
class MousePath extends Channel {
  MousePath(super.g);
  @override
  String get name => 'EL CAMINO DEL RATÓN';
  @override
  String get sub => 'Ratón Pérez busca el queso sin pisar trampas';
  @override
  String get ins => '¡MEMORIZA EL CAMINO!';
  @override
  String get hint => 'Mira el camino y luego tócalo baldosa a baldosa';
  @override
  String get bg => 'bg_pantry';
  @override
  double get dur => showEnd + path.length * .9 + 2.5;

  static const n = 4, ts = 84.0, beat = .42;
  final path = <int>[];
  int idx = 0, wrong = -1;
  Offset mouse = Offset.zero;
  double get showEnd => .6 + path.length * beat + .25;
  Offset get origin => Offset(cx - ts * 2, cy - ts * 2 + 14);
  Rect tile(int i) => Rect.fromLTWH(origin.dx + (i % n) * ts, origin.dy + (i ~/ n) * ts, ts, ts);

  @override
  void init(int l) {
    final len = 5 + math.min(l, 3);
    while (true) {
      path.clear();
      var col = rng.nextInt(n), row = n - 1;
      path.add(row * n + col);
      var ok = true;
      var lastSide = 0;
      while (row > 0 && ok) {
        final left = len - path.length;
        final mustUp = left <= row;
        final goUp = mustUp || rng.nextDouble() < .4;
        if (goUp) {
          row--;
          lastSide = 0;
        } else {
          var dir = lastSide != 0 ? lastSide : (rng.nextBool() ? 1 : -1);
          if (col + dir < 0 || col + dir >= n) dir = -dir;
          if (lastSide != 0 && dir != lastSide) {
            ok = false;
            break;
          }
          col += dir;
          lastSide = dir;
        }
        path.add(row * n + col);
      }
      if (ok && path.length == len && path.toSet().length == len) break;
    }
    mouse = tile(path[0]).center;
  }

  int? botTile() => t >= showEnd && idx + 1 < path.length ? path[idx + 1] : null;

  @override
  void update(double dt) {
    final target = tile(path[idx]).center;
    mouse = Offset.lerp(mouse, target, 1 - math.exp(-dt * 12))!;
    if (res != 0 || t < showEnd || !tap) return;
    for (var i = 0; i < n * n; i++) {
      if (!tile(i).contains(Offset(p.x, p.y))) continue;
      if (i == path[idx]) return;
      if (idx + 1 < path.length && i == path[idx + 1]) {
        idx++;
        Sfx.play('note${idx % 4}');
        if (idx == path.length - 1) {
          win();
          Sfx.play('bonus');
        }
      } else {
        wrong = i;
        Sfx.play('chop');
        g.fx.shake(8);
        lose('¡Ratonera! Ese no era el camino');
      }
      return;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final showing = t < showEnd;
    final lit = showing ? ((t - .6) / beat).floor() : -1;
    for (var i = 0; i < n * n; i++) {
      final r = tile(i).deflate(4);
      final k = path.indexOf(i);
      final on = showing ? (k >= 0 && k <= lit) : (k >= 0 && k <= idx);
      clayBox(c, r, on ? const Color(0xFFF2C14E) : const Color(0xFFB9A58A), radius: 10, shadow: 4);
      if (i == wrong) Gfx.mark(c, false, r.center.dx, r.center.dy, 50);
    }
    Gfx.sprite(c, 'cheese', tile(path.last).center.dx, tile(path.last).center.dy, 46, rot: math.sin(vt * 3) * .06,
        drop: const Offset(2, 4));
    final hop = (math.sin(vt * 12) * .5 + .5) * 4;
    Gfx.sprite(c, 'mouse_top', mouse.dx, mouse.dy - hop, 58, drop: const Offset(3, 5));
    Gfx.text(c, showing ? '¡MIRA!' : '¡TU TURNO!', cx, st + 30, 24, color: showing ? Pal.gold : Pal.lime);
  }
}

// ───────────────────────── 75. PELUQUERÍA GALÁCTICA (copiar el modelo) ─────────────────────────
class AlienSalon extends Channel {
  AlienSalon(super.g);
  @override
  String get name => 'PELUQUERÍA GALÁCTICA';
  @override
  String get sub => 'Zorg quiere el mismo peinado que en la foto';
  @override
  String get ins => '¡COPIA LA FOTO!';
  @override
  String get hint => 'Toca PELO, COLOR y GAFAS hasta que quede igual que la foto';
  @override
  String get bg => 'bg_salon';
  @override
  double get dur => 10;

  static const hairs = ['hair_afro', 'hair_mohawk', 'hair_bun'];
  static const glasses = ['', 'glasses_round', 'glasses_star'];
  static const tints = [Color(0xFFFF6FA8), Color(0xFF5BC0F8), Color(0xFFFFD23F), Color(0xFFB07CFF)];
  final want = [0, 0, 0], cur = [0, 0, 0];
  static const sizes = [3, 4, 3];
  static const labels = ['PELO', 'COLOR', 'GAFAS'];
  int last = -1;
  double lastAt = -9;

  Rect btn(int i) => Rect.fromCenter(center: Offset(cx + (i - 1) * 136, sb - 40), width: 128, height: 128 * kButtonAspect);

  @override
  void init(int l) {
    for (var k = 0; k < 3; k++) {
      want[k] = rng.nextInt(sizes[k]);
    }
    do {
      for (var k = 0; k < 3; k++) {
        cur[k] = rng.nextInt(sizes[k]);
      }
    } while ([for (var k = 0; k < 3; k++) cur[k] != want[k]].where((x) => x).length < 2);
  }

  int? botButton() {
    for (var k = 0; k < 3; k++) {
      if (cur[k] != want[k]) return k;
    }
    return null;
  }

  @override
  void update(double dt) {
    if (res != 0 || !tap) return;
    for (var k = 0; k < 3; k++) {
      if (btn(k).inflate(6).contains(Offset(p.x, p.y))) {
        cur[k] = (cur[k] + 1) % sizes[k];
        last = k;
        lastAt = vt;
        Sfx.play('pop', volume: .7);
        if (cur[0] == want[0] && cur[1] == want[1] && cur[2] == want[2]) {
          win();
          Sfx.play('bonus');
          g.fx.burst(cx, cy - 60, Pal.pink, 20);
        }
      }
    }
  }

  /// Dibuja a Zorg con peinado, color y gafas; [s] = escala (1 = tamaño grande).
  void drawAlien(Canvas c, Offset base, double s, List<int> a, {double t0 = 0}) {
    final h = 190 * s;
    final top = base.dy - h;
    final bob = math.sin(t0 * 3) * 2 * s;
    Gfx.sprite(c, 'alien_head', base.dx, base.dy + bob, h, ay: 1);
    final hair = hairs[a[0]];
    final col = tints[a[1]];
    final hx = base.dx, hy = top + bob;
    switch (a[0]) {
      case 0:
        Gfx.sprite(c, hair, hx, hy + 22 * s, 168 * s, tint: col);
      case 1:
        Gfx.sprite(c, hair, hx, hy + 26 * s, 104 * s, ay: 1, tint: col);
      default:
        Gfx.sprite(c, hair, hx, hy + 30 * s, 112 * s, ay: 1, tint: col);
    }
    final gl = glasses[a[2]];
    if (gl.isNotEmpty) Gfx.sprite(c, gl, hx, hy + 64 * s, 42 * s);
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    drawAlien(c, Offset(cx + 30, sb - 84), 1, cur, t0: vt);
    // foto del modelo (polaroid)
    final card = Rect.fromLTWH(sl + 14, st + 20, 128, 156);
    c.save();
    c.translate(card.center.dx, card.center.dy);
    c.rotate(-.06);
    c.translate(-card.center.dx, -card.center.dy);
    clayBox(c, card, const Color(0xFFF7F1E3), radius: 6, shadow: 6);
    final pic = Rect.fromLTRB(card.left + 10, card.top + 10, card.right - 10, card.bottom - 34);
    c.drawRect(pic, Paint()..color = const Color(0xFF2E2350));
    c.save();
    c.clipRect(pic);
    drawAlien(c, Offset(pic.center.dx, pic.bottom + 6), .55, want);
    c.restore();
    Gfx.text(c, 'ASÍ', card.center.dx, card.bottom - 17, 18, color: const Color(0xFF6A3FA0), outline: false);
    c.restore();
    for (var k = 0; k < 3; k++) {
      final ok = cur[k] == want[k];
      final pop = last == k ? 1 - clamp01((vt - lastAt) * 5) : 0.0;
      Gfx.button(c, ok ? 'btn_teal' : 'btn_pink', labels[k], btn(k), scale: 1 - pop * .08, size: 34);
    }
  }
}

// ───────────────────────── 76. LA BOMBA DE BICI (inflar sin pasarse) ─────────────────────────
class BikePump extends Channel {
  BikePump(super.g);
  @override
  String get name => 'LA BOMBA DE BICI';
  @override
  String get sub => 'El conejo ciclista tiene prisa por salir';
  @override
  String get ins => '¡INFLA HASTA LO VERDE!';
  @override
  String get hint => 'Sube y baja la bomba con el dedo y para cuando la aguja esté en verde';
  @override
  String get bg => 'bg_bikeshop';
  @override
  double get dur => 10;

  double pressure = 0, lo = .6, k = 0, still = 0, boomAt = -1;
  bool armed = true;
  static const zone = .16;
  double get base => foot(.94);
  double get pumpX => bx(.74);
  double get hy0 => base - 262;
  double get hy1 => base - 168;
  Offset get tire => Offset(bx(.36), cy + 40);
  bool get inGreen => pressure >= lo && pressure <= lo + zone;

  @override
  void init(int l) {
    lo = rnd(.52, .7);
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    pressure = math.max(0, pressure - .012 * dt);
    if (p.down && p.x > cx - 40) {
      k = clamp01((p.y - hy0) / (hy1 - hy0));
    } else {
      k += (0 - k) * (1 - math.exp(-dt * 6));
    }
    if (k > .82 && armed) {
      armed = false;
      pressure += rnd(.075, .11);
      still = 0;
      Sfx.play('shake', volume: .5);
      if (pressure > 1) {
        boomAt = vt;
        g.fx.shake(14);
        g.fx.burst(tire.dx, tire.dy, const Color(0xFF333333), 22);
        Sfx.play('boom');
        lose('¡PUM! Rueda reventada');
        return;
      }
    }
    if (k < .3) armed = true;
    if (inGreen && k < .3) {
      still += dt;
      if (still > .9) {
        win();
        Sfx.play('bonus');
      }
    } else {
      still = 0;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'cyclist', vt, bx(.1), foot(.95), 150, ay: 1);
    // rueda: aplastada abajo cuando le falta aire
    final f = clamp01(pressure);
    if (boomAt < 0) {
      Gfx.shadow(c, tire.dx, tire.dy + 82, 150, alpha: .4);
      Gfx.sprite(c, 'tire', tire.dx, tire.dy + 80, 160 * (.86 + f * .14), ay: 1, sy: .8 + f * .2, sx: 1.06 - f * .06);
    } else {
      Gfx.sprite(c, 'tire', tire.dx, tire.dy + 80, 120, ay: 1, sy: .45, rot: .2, alpha: .8);
    }
    // manguera
    final hy = lerp(hy0, hy1, k);
    clayLine(c, [Offset(pumpX + 26, base - 22), Offset(pumpX + 10, base + 4), Offset(tire.dx + 70, base + 2), tire + const Offset(50, 30)],
        const Color(0xFF2A2A2A), 7);
    Gfx.shadow(c, pumpX, base, 90, alpha: .45);
    // barra que entra en el cuerpo de la bomba
    c.drawRect(Rect.fromLTRB(pumpX - 4, hy, pumpX + 4, base - 186), Paint()..color = const Color(0xFFB9BCC4));
    Gfx.sprite(c, 'pump_body', pumpX, base, 200, ay: 1);
    Gfx.sprite(c, 'pump_handle', pumpX, hy, 84, ay: .2);
    // manómetro
    final gc = Offset(cx, st + 86);
    const gr = 64.0;
    Gfx.clayBall(c, gc.dx, gc.dy, gr + 10, const Color(0xFFE8E2D4));
    double ang(double v) => math.pi + v * math.pi;
    final arc = Rect.fromCircle(center: gc, radius: gr - 8);
    final pz = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    c.drawArc(arc, ang(0), math.pi, false, pz..color = const Color(0xFFB0A898));
    c.drawArc(arc, ang(lo), zone * math.pi, false, pz..color = const Color(0xFF4CC36A));
    c.drawArc(arc, ang(.92), .08 * math.pi, false, pz..color = Pal.tomato);
    final a = ang(math.min(1.05, pressure)) + math.sin(vt * 30) * .01;
    c.drawLine(gc, gc + Offset(math.cos(a), math.sin(a)) * (gr - 6), Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF2A2030));
    Gfx.clayBall(c, gc.dx, gc.dy, 7, Pal.tomato);
    if (inGreen && res == 0) {
      c.drawArc(Rect.fromCircle(center: gc, radius: gr + 16), -math.pi / 2, tau * clamp01(still / .9), false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = Pal.lime);
    }
    if (res == 0 && t < 2.2 && !p.down) {
      fingerAt(c, Offset(pumpX, lerp(hy0, hy1, (math.sin(vt * 6) * .5 + .5)) - 10));
    }
  }
}

// ───────────────────────── 77. PARTE LA TORTILLA (cortar por la mitad) ─────────────────────────
class Tortilla extends Channel {
  Tortilla(super.g);
  @override
  String get name => 'PARTE LA TORTILLA';
  @override
  String get sub => 'Los gemelos quieren exactamente la mitad';
  @override
  String get ins => '¡CÓRTALA POR LA MITAD!';
  @override
  String get hint => 'Desliza de lado a lado para cortarla en dos partes iguales';
  @override
  String get bg => 'bg_table';
  @override
  double get dur => 6;

  static const R = 118.0;
  double minShare = .44, pct = 0;
  Offset a = Offset.zero, b = Offset.zero;
  bool cut = false;
  Offset get center => Offset(cx, cy + 10);

  @override
  void init(int l) => minShare = math.min(.47, .44 + l * .008);

  /// Parte pequeña (0..0,5) que deja una recta que pasa a distancia [d] del centro.
  static double share(double d) {
    if (d >= R) return 0;
    final seg = R * R * math.acos(d / R) - d * math.sqrt(R * R - d * d);
    final f = seg / (math.pi * R * R);
    return math.min(f, 1 - f);
  }

  double lineDist(Offset a, Offset b) {
    final ab = b - a;
    final n = Offset(-ab.dy, ab.dx) / ab.distance;
    final q = center - a;
    return (q.dx * n.dx + q.dy * n.dy).abs();
  }

  @override
  void update(double dt) {
    if (res != 0 || !p.released) return;
    final s = Offset(p.sx, p.sy), e = Offset(p.x, p.y);
    if ((e - s).distance < 70) return;
    final d = lineDist(s, e);
    if (d >= R - 4) return;
    a = s;
    b = e;
    cut = true;
    final sh = share(d);
    pct = sh * 100;
    Sfx.play('chop');
    if (sh >= minShare) {
      win();
      Sfx.play('bonus');
    } else {
      lose('¡${pct.round()} % y ${100 - pct.round()} %!');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final h = R * 2 / .8;
    if (!cut) {
      Gfx.shadow(c, center.dx, center.dy + R * .9, R * 2.3, alpha: .4);
      Gfx.sprite(c, 'tortilla', center.dx, center.dy, h);
    } else {
      final ab = b - a;
      var n = Offset(-ab.dy, ab.dx) / ab.distance;
      final gap = clamp01(since * 3) * 16;
      for (final side in [1.0, -1.0]) {
        c.save();
        // semiplano de este lado de la recta del corte
        final far = 900.0;
        final dir = ab / ab.distance;
        final p0 = a - dir * far, p1 = a + dir * far;
        final clip = Path()
          ..moveTo(p0.dx, p0.dy)
          ..lineTo(p1.dx, p1.dy)
          ..lineTo(p1.dx + n.dx * far * side, p1.dy + n.dy * far * side)
          ..lineTo(p0.dx + n.dx * far * side, p0.dy + n.dy * far * side)
          ..close();
        c.translate(n.dx * gap * side, n.dy * gap * side);
        c.clipPath(clip);
        Gfx.sprite(c, 'tortilla', center.dx, center.dy, h);
        c.restore();
      }
      final q = center - a;
      final along = (q.dx * ab.dx + q.dy * ab.dy) / ab.distance;
      final foot0 = a + ab / ab.distance * along;
      final towards = center - foot0;
      final small = towards.distance < .01 ? n : -towards / towards.distance;
      n = small;
      final bigPct = 100 - pct.round();
      Gfx.text(c, '${pct.round()} %', center.dx + n.dx * (R * .55 + gap), center.dy + n.dy * (R * .55 + gap), 26,
          color: res == 1 ? Pal.lime : Pal.pink);
      Gfx.text(c, '$bigPct %', center.dx - n.dx * (R * .45 + gap), center.dy - n.dy * (R * .45 + gap), 26,
          color: res == 1 ? Pal.lime : Pal.gold);
    }
    if (p.down && res == 0) {
      clayLine(c, [Offset(p.sx, p.sy), Offset(p.x, p.y)], const Color(0xCCE8EEF5), 6);
    }
    if (res == 0 && t < 2.2 && !p.down) {
      final k = (vt * .7) % 1;
      final f = Offset(center.dx - 150 + k * 300, center.dy + 4);
      clayLine(c, [Offset(center.dx - 150, center.dy + 4), f], const Color(0x88E8EEF5), 5);
      fingerAt(c, f);
    }
  }
}

// ───────────────────────── 78. CARRERA DE BAÑERAS (esquivar río abajo) ─────────────────────────
class _Float {
  double x, y;
  final bool log;
  _Float(this.x, this.y, this.log);
}

void vScrollBg(Canvas c, String name, double offset) {
  final im = Gfx.image(name);
  if (im == null) return;
  final r = ZappingGame.bleed;
  final s = r.width / im.width;
  final h = im.height * s;
  final src = Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
  final paint = Paint()..filterQuality = FilterQuality.medium;
  final o = offset % (2 * h);
  var y = r.top + o - 2 * h;
  var k = 0;
  while (y < r.bottom) {
    if (y + h > r.top) {
      c.save();
      if (k.isOdd) {
        c.translate(r.left, y + h);
        c.scale(1, -1);
        c.drawImageRect(im, src, Rect.fromLTWH(0, 0, r.width, h), paint);
      } else {
        c.drawImageRect(im, src, Rect.fromLTWH(r.left, y, r.width, h), paint);
      }
      c.restore();
    }
    y += h;
    k++;
  }
}

class BathRace extends Channel {
  BathRace(super.g);
  @override
  String get name => 'CARRERA DE BAÑERAS';
  @override
  String get sub => 'El capitán Patito baja el río en su bañera';
  @override
  String get ins => '¡ESQUIVA LAS ROCAS!';
  @override
  String get hint => 'Arrastra la bañera a los lados sin chocar con rocas, troncos ni la orilla';
  @override
  String get bg => 'bg_river';
  @override
  bool get survive => true;
  @override
  double get dur => 7;

  final floats = <_Float>[];
  double scroll = 0, speed = 230, x = 0, nextAt = .3, tilt = 0;
  bool passRight = true;
  double get bankL => sl - 14 + .215 * 449;
  double get bankR => sl - 14 + .785 * 449;
  double get tubY => sb - 96;
  static const tubW = 23.0;

  @override
  void init(int l) {
    speed = 230 + l * 20;
    x = cx;
  }

  bool _hit(_Float f, double px, double py) {
    if (f.log) {
      return Rect.fromCenter(center: Offset(f.x, f.y), width: 112, height: 30).inflate(12).contains(Offset(px, py)) ||
          Rect.fromCenter(center: Offset(f.x, f.y), width: 112, height: 30).inflate(4).contains(Offset(px, py - 36)) ||
          Rect.fromCenter(center: Offset(f.x, f.y), width: 112, height: 30).inflate(4).contains(Offset(px, py + 36));
    }
    return (Offset(f.x, f.y) - Offset(px, py)).distance < 37 || (Offset(f.x, f.y) - Offset(px, py - 30)).distance < 27 ||
        (Offset(f.x, f.y) - Offset(px, py + 30)).distance < 27;
  }

  /// Bot: va al centro del hueco libre del obstáculo que tiene más cerca (por delante).
  double botX() {
    _Float? next;
    for (final f in floats) {
      if (f.y > tubY + 62 || f.y < tubY - 360) continue;
      if (next == null || f.y > next.y) next = f;
    }
    if (next == null) return x;
    final half = next.log ? 56 + 12 + 4 : 37 + 6;
    final lo = bankL + tubW + 4, hi = bankR - tubW - 4;
    final leftHi = next.x - half, rightLo = next.x + half;
    final leftW = leftHi - lo, rightW = hi - rightLo;
    return leftW > rightW ? (lo + leftHi) / 2 : (rightLo + hi) / 2;
  }

  @override
  void update(double dt) {
    scroll += speed * dt;
    for (final f in floats) {
      f.y += speed * dt;
    }
    floats.removeWhere((f) => f.y > sb + 80);
    if (res != 0) return;
    if (t >= nextAt) {
      final log = rng.nextDouble() < .4;
      final half = log ? 56.0 : 26.0;
      // el obstáculo deja siempre un paso de al menos 80 px a un lado
      // paso libre a la derecha (true) o a la izquierda; si cambia de lado, más distancia
      final right = rng.nextDouble() < .6 ? passRight : !passRight;
      final fx = right ? rnd(bankL + half - 10, bankR - half - 100) : rnd(bankL + half + 100, bankR - half + 10);
      floats.add(_Float(fx.clamp(bankL + half - 14, bankR - half + 14), st - 50, log));
      nextAt = t + rnd(.8, 1.0) * 230 / speed + (right != passRight ? .25 : 0);
      passRight = right;
    }
    final old = x;
    if (p.down) x += (p.x - x) * (1 - math.exp(-dt * 12));
    tilt = ((x - old) / math.max(dt, 1e-4) / 600).clamp(-.35, .35);
    if (x - tubW < bankL || x + tubW > bankR) {
      Sfx.play('chop');
      g.fx.shake(10);
      lose('¡Encallado en la orilla!');
      return;
    }
    for (final f in floats) {
      if (_hit(f, x, tubY)) {
        Sfx.play('chop');
        g.fx.shake(10);
        g.fx.burst(x, tubY - 30, const Color(0xFFFFFFFF), 12, size: 5);
        lose(f.log ? '¡Contra el tronco!' : '¡Contra la roca!');
        return;
      }
    }
  }

  @override
  void render(Canvas c) {
    vScrollBg(c, bg, scroll);
    for (final f in floats) {
      if (f.log) {
        Gfx.sprite(c, 'log_top', f.x, f.y, 34, drop: const Offset(3, 6), rot: math.sin(vt * 2 + f.x) * .05);
      } else {
        Gfx.sprite(c, 'rock_top', f.x, f.y, 56);
      }
    }
    // estela
    for (var k = 0; k < 4; k++) {
      final yy = tubY + 50 + k * 12.0;
      Gfx.clayBall(c, x - 14 + math.sin(vt * 9 + k) * 4, yy, 5 - k.toDouble(), const Color(0xFFEFF8FF));
      Gfx.clayBall(c, x + 14 + math.cos(vt * 9 + k) * 4, yy, 5 - k.toDouble(), const Color(0xFFEFF8FF));
    }
    Gfx.sprite(c, 'bathtub_top', x, tubY, 104, rot: tilt + (res == -1 ? math.sin(vt * 30) * .1 : 0), drop: const Offset(4, 8));
    if (res == 0 && t < 1.8 && !p.down) fingerAt(c, Offset(x + math.sin(vt * 5) * 50, tubY + 10));
  }
}

// ───────────────────────── 79. LA FOTO DEL YETI (encuadrar) ─────────────────────────
class YetiPhoto extends Channel {
  YetiPhoto(super.g);
  @override
  String get name => 'LA FOTO DEL YETI';
  @override
  String get sub => 'Nadie se cree que el abominable existe';
  @override
  String get ins => '¡HAZLE LA FOTO!';
  @override
  String get hint => 'Toca cuando el yeti esté entero dentro del visor';
  @override
  String get bg => 'bg_snow';
  @override
  double get dur => 10;

  double x = 0, dir = 1, wait = 0, speed = 140, shotAt = -1;
  final stops = <double>[];
  int leg = 0;
  static const yh = 150.0;
  double get yw => yh * 194 / 300 * .82;
  double get ground => foot(.86);
  late Rect vf;

  @override
  void init(int l) {
    final w = math.max(126.0, 160.0 - l * 8);
    vf = Rect.fromCenter(center: Offset(cx + rnd(-30, 30), ground - yh / 2 - 6), width: w, height: yh + 40);
    speed = 140 * (1 + l * .1);
    stops.addAll([vf.left - 70, vf.right + 70]);
    dir = rng.nextBool() ? 1 : -1;
    x = dir > 0 ? sl - 60 : sr + 60;
    leg = dir > 0 ? 0 : 1;
  }

  Rect get body => Rect.fromLTRB(x - yw / 2, ground - yh + 8, x + yw / 2, ground);
  bool get inside => vf.contains(body.topLeft) && vf.contains(body.bottomRight);
  bool get partly => body.overlaps(vf);

  @override
  void update(double dt) {
    if (res != 0) return;
    if (wait > 0) {
      wait -= dt;
    } else {
      final target = leg < stops.length ? stops[leg] : (dir > 0 ? sr + 80 : sl - 80);
      final d = target - x;
      final m = speed * dt;
      if (d.abs() <= m) {
        x = target;
        if (leg < stops.length) {
          wait = rnd(.5, 1.3);
          // a veces se da la vuelta y vuelve a cruzar
          if (rng.nextDouble() < .45) {
            leg = leg == 0 ? 1 : 0;
          } else {
            leg = dir > 0 ? leg + 1 : leg - 1;
            if (leg < 0) leg = stops.length;
          }
        } else {
          dir = -dir;
          leg = dir > 0 ? 0 : 1;
        }
        final nt = leg < stops.length ? stops[leg] : (dir > 0 ? sr + 80 : sl - 80);
        if (nt != x) dir = nt > x ? 1 : -1;
      } else {
        dir = d > 0 ? 1 : -1;
        x += dir * m;
      }
    }
    if (tap) {
      shotAt = vt;
      Sfx.play('click');
      if (inside) {
        win();
        Sfx.play('bonus');
      } else if (partly) {
        lose('¡Salió cortado!');
      } else {
        lose('¡Foto sin yeti!');
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, x, ground, 110, alpha: .35);
    Gfx.anim(c, 'yeti', wait > 0 ? 0 : vt, x, ground + 4, yh, ay: 1, flip: dir < 0);
    for (final sx in stops) {
      Gfx.sprite(c, 'bush', sx, ground + 14, 104, ay: 1);
    }
    // visor: oscurece fuera
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(ZappingGame.bleed)
      ..addRect(vf);
    c.drawPath(dim, Paint()..color = const Color(0x55000018));
    final ok = res == 1, bad = res == -1;
    final col = ok ? Pal.lime : (bad ? Pal.pink : const Color(0xFFFFFFFF));
    final pc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = col;
    const L = 22.0;
    for (final cn in [vf.topLeft, vf.topRight, vf.bottomLeft, vf.bottomRight]) {
      final sx = cn.dx == vf.left ? 1.0 : -1.0, sy = cn.dy == vf.top ? 1.0 : -1.0;
      c.drawLine(cn, cn + Offset(L * sx, 0), pc);
      c.drawLine(cn, cn + Offset(0, L * sy), pc);
    }
    if (res == 0 && (vt * 2).floor().isEven) Gfx.clayBall(c, vf.right - 14, vf.top + 14, 6, Pal.tomato);
    if (shotAt >= 0) {
      final f = 1 - clamp01((vt - shotAt) * 3);
      if (f > 0) c.drawRect(ZappingGame.bleed, Paint()..color = Color.fromRGBO(255, 255, 255, f));
    }
  }
}

// ───────────────────────── 80. CONSTELACIONES (un solo trazo) ─────────────────────────
class Constellations extends Channel {
  Constellations(super.g);
  @override
  String get name => 'CONSTELACIONES';
  @override
  String get sub => 'El erizo astrónomo une las estrellas';
  @override
  String get ins => '¡ÚNELAS DE UN TRAZO!';
  @override
  String get hint => 'Pasa por todas las estrellas sin levantar el dedo';
  @override
  String get bg => 'bg_observatory';
  @override
  double get dur => 10;

  final stars = <Offset>[];
  final lit = <int>[];
  Offset? meteor;
  Rect get sky => Rect.fromLTRB(sl + 46, st + 50, sr - 46, by(.66));

  @override
  void init(int l) {
    final n = 5 + math.min(l, 2);
    while (true) {
      stars.clear();
      var tries = 0;
      while (stars.length < n && tries++ < 500) {
        final q = Offset(rnd(sky.left, sky.right), rnd(sky.top, sky.bottom));
        if (stars.every((s) => (s - q).distance > 74)) stars.add(q);
      }
      if (stars.length < n) continue;
      meteor = null;
      if (l < 2) break;
      final order = botOrder();
      for (var k = 0; k < 40 && meteor == null; k++) {
        final m = Offset(rnd(sky.left, sky.right), rnd(sky.top, sky.bottom));
        if (stars.any((s) => (s - m).distance < 60)) continue;
        var clear = true;
        for (var i = 0; i + 1 < order.length; i++) {
          if (_segDist(m, stars[order[i]], stars[order[i + 1]]) < 46) clear = false;
        }
        if (clear) meteor = m;
      }
      if (meteor != null) break;
    }
  }

  static double _segDist(Offset q, Offset a, Offset b) {
    final ab = b - a;
    final k = (((q - a).dx * ab.dx + (q - a).dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy)).clamp(0.0, 1.0);
    return (q - (a + ab * k)).distance;
  }

  /// Orden del bot: empieza por la de más a la izquierda y va a la más cercana.
  List<int> botOrder() {
    final left = List.generate(stars.length, (i) => i);
    left.sort((a, b) => stars[a].dx.compareTo(stars[b].dx));
    final out = [left.removeAt(0)];
    while (left.isNotEmpty) {
      final last = stars[out.last];
      left.sort((a, b) => (stars[a] - last).distance.compareTo((stars[b] - last).distance));
      out.add(left.removeAt(0));
    }
    return out;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.down) {
      final q = Offset(p.x, p.y);
      if (meteor != null && (q - meteor!).distance < 24) {
        Sfx.play('boom', volume: .6);
        lose('¡Te quemaste con el meteorito!');
        return;
      }
      for (var i = 0; i < stars.length; i++) {
        if (!lit.contains(i) && (q - stars[i]).distance < 28) {
          lit.add(i);
          Sfx.play('note${lit.length % 4}', volume: .8);
          if (lit.length == stars.length) {
            win();
            Sfx.play('bonus');
          }
        }
      }
    } else if (p.released && lit.isNotEmpty) {
      lit.clear();
      g.fx.float('¡SIN LEVANTAR EL DEDO!', cx, cy, Pal.pink, 20);
      Sfx.play('eh');
    }
  }

  void _star(Canvas c, Offset o, double r, Color col) {
    final path = Path();
    for (var k = 0; k < 10; k++) {
      final a = -math.pi / 2 + k * math.pi / 5;
      final rr = k.isEven ? r : r * .45;
      final q = o + Offset(math.cos(a), math.sin(a)) * rr;
      k == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
    }
    path.close();
    c.drawPath(path.shift(const Offset(2, 3)), Paint()..color = const Color(0x55000000));
    c.drawPath(path, Paint()..shader = Gradient.radial(o - Offset(r * .3, r * .3), r * 1.4, [const Color(0xFFFFFFFF), col], [0, 1]));
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final line = <Offset>[for (final i in lit) stars[i], if (p.down && lit.isNotEmpty && res == 0) Offset(p.x, p.y)];
    if (line.length > 1) clayLine(c, line, const Color(0xFFFFD46B), 5);
    for (var i = 0; i < stars.length; i++) {
      final on = lit.contains(i);
      final tw = 1 + math.sin(vt * 5 + i * 1.7) * .08;
      if (on) {
        c.drawCircle(stars[i], 24, Paint()
          ..color = const Color(0x66FFF1B0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      }
      _star(c, stars[i], (on ? 19 : 15) * tw, on ? const Color(0xFFFFC93C) : const Color(0xFFE8D9A8));
    }
    if (meteor != null) {
      final m = meteor!;
      c.drawCircle(m, 26, Paint()
        ..color = const Color(0x66FF4030)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      Gfx.clayBall(c, m.dx, m.dy, 15, const Color(0xFFE0402A));
      for (var k = 1; k < 4; k++) {
        Gfx.clayBall(c, m.dx + k * 9, m.dy - k * 7, 7 - k * 1.5, const Color(0xFFFF8A3A));
      }
    }
    Gfx.anim(c, 'hedgehog', vt, bx(.16), foot(.97), 118, ay: 1);
    if (res == 0 && t < 2.2 && lit.isEmpty) {
      final o = botOrder();
      final k = (vt * .8) % 1;
      fingerAt(c, Offset.lerp(stars[o[0]], stars[o[1]], k)!);
    }
  }
}

// ───────────────────────── 81. ENCAJA LA FIGURA (girar y arrastrar) ─────────────────────────
class ShapeFit extends Channel {
  ShapeFit(super.g);
  @override
  String get name => 'ENCAJA LA FIGURA';
  @override
  String get sub => 'El juguete favorito del bebé gigante';
  @override
  String get ins => '¡GIRA Y ENCAJA!';
  @override
  String get hint => 'Toca una pieza para girarla y arrástrala a su agujero';
  @override
  String get bg => 'bg_playroom';
  @override
  double get dur => 12;

  static const shapes = ['block_tri', 'block_l', 'block_arrow'];
  static const cols = [Color(0xFFFF6B6B), Color(0xFF5BC0F8), Color(0xFFFFD23F)];
  final holeRot = [0, 0, 0], rot = [0, 0, 0], homeSlot = [0, 1, 2];
  final placed = [false, false, false];
  final pos = <Offset>[];
  final shownRot = [0.0, 0.0, 0.0];
  int grab = -1, bad = -1;
  double badAt = -9;
  Offset grabOff = Offset.zero;
  Offset hole(int i) => Offset(cx + (i - 1) * 124, by(.46));
  Offset home(int i) => Offset(cx + (homeSlot[i] - 1) * 124, by(.46) + 150);

  @override
  void init(int l) {
    homeSlot.shuffle(rng);
    for (var i = 0; i < 3; i++) {
      holeRot[i] = rng.nextInt(4);
      rot[i] = (holeRot[i] + 1 + rng.nextInt(3)) % 4;
      shownRot[i] = rot[i] * math.pi / 2;
      pos.add(home(i));
    }
  }

  @override
  void update(double dt) {
    for (var i = 0; i < 3; i++) {
      shownRot[i] += angNorm(rot[i] * math.pi / 2 - shownRot[i]) * (1 - math.exp(-dt * 16));
      if (i != grab) pos[i] = Offset.lerp(pos[i], placed[i] ? hole(i) : home(i), 1 - math.exp(-dt * 12))!;
    }
    if (res != 0) return;
    final q = Offset(p.x, p.y);
    if (p.pressed) {
      for (var i = 0; i < 3; i++) {
        if (!placed[i] && (q - pos[i]).distance < 52) {
          grab = i;
          grabOff = pos[i] - q;
        }
      }
    }
    if (grab >= 0 && p.down) pos[grab] = q + grabOff;
    if (grab >= 0 && !p.down) {
      final i = grab;
      grab = -1;
      if ((Offset(p.x, p.y) - Offset(p.sx, p.sy)).distance < 14) {
        rot[i] = (rot[i] + 1) % 4;
        Sfx.play('click');
        return;
      }
      for (var h = 0; h < 3; h++) {
        if ((pos[i] - hole(h)).distance < 48) {
          if (h == i && rot[i] == holeRot[h]) {
            placed[i] = true;
            Sfx.play('pop');
            g.fx.burst(hole(h).dx, hole(h).dy, cols[i], 10, size: 5);
            if (placed.every((x) => x)) {
              win();
              Sfx.play('bonus');
            }
          } else {
            bad = i;
            badAt = vt;
            Sfx.play('eh');
          }
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final board = Rect.fromCenter(center: Offset(cx, by(.46)), width: 392, height: 128);
    clayBox(c, board, const Color(0xFFC98A4B), radius: 18, shadow: 8);
    for (var h = 0; h < 3; h++) {
      Gfx.sprite(c, shapes[h], hole(h).dx, hole(h).dy, 86, rot: holeRot[h] * math.pi / 2, tint: const Color(0xFF3A2414));
    }
    for (var i = 0; i < 3; i++) {
      final shake = bad == i ? math.sin((vt - badAt) * 40) * 5 * (1 - clamp01((vt - badAt) * 3)) : 0.0;
      final big = i == grab ? 1.08 : 1.0;
      Gfx.sprite(c, shapes[i], pos[i].dx + shake, pos[i].dy, 80 * big, rot: shownRot[i], tint: cols[i],
          drop: i == grab ? const Offset(8, 14) : (placed[i] ? null : const Offset(3, 5)));
    }
    if (res == 0 && t < 2.4 && grab < 0) fingerAt(c, pos[0] + Offset(0, math.sin(vt * 9) * 4));
  }
}

// ───────────────────────── 82. EL PINGÜINO PATINADOR (deslizar hasta chocar) ─────────────────────────
class PenguinSlide extends Channel {
  PenguinSlide(super.g);
  @override
  String get name => 'EL PINGÜINO PATINADOR';
  @override
  String get sub => 'Pingu tiene hambre y el hielo resbala';
  @override
  String get ins => '¡LLEGA HASTA EL PEZ!';
  @override
  String get hint => 'Desliza en una dirección: el pingüino no frena hasta chocar';
  @override
  String get bg => 'bg_icerink';
  @override
  double get dur => 11;

  static const n = 5, ts = 74.0;
  static const dirs = [Offset(0, -1), Offset(1, 0), Offset(0, 1), Offset(-1, 0)];
  final blocks = <int>{};
  int pen = 0, fish = 0, target = -1;
  Offset at = Offset.zero;
  Offset face = const Offset(0, 1);
  Offset get origin => Offset(cx - ts * n / 2, cy - ts * n / 2 + 10);
  Offset cellC(int i) => origin + Offset((i % n + .5) * ts, (i ~/ n + .5) * ts);

  /// Casilla donde para al deslizar y si pasa por el pez.
  (int, bool) slide(int from, int d) {
    var c = from % n, r = from ~/ n;
    var eats = false;
    while (true) {
      final nc = c + dirs[d].dx.toInt(), nr = r + dirs[d].dy.toInt();
      if (nc < 0 || nr < 0 || nc >= n || nr >= n || blocks.contains(nr * n + nc)) break;
      c = nc;
      r = nr;
      if (r * n + c == fish) eats = true;
    }
    return (r * n + c, eats);
  }

  /// Camino más corto (direcciones) desde [from].
  List<int>? solve(int from) {
    final prev = <int, (int, int)>{from: (-1, -1)};
    final q = [from];
    while (q.isNotEmpty) {
      final s = q.removeAt(0);
      for (var d = 0; d < 4; d++) {
        final (to, eats) = slide(s, d);
        if (eats) {
          final out = [d];
          var cur = s;
          while (prev[cur]!.$1 >= 0) {
            out.insert(0, prev[cur]!.$2);
            cur = prev[cur]!.$1;
          }
          return out;
        }
        if (!prev.containsKey(to)) {
          prev[to] = (s, d);
          q.add(to);
        }
      }
    }
    return null;
  }

  @override
  void init(int l) {
    final minMoves = l >= 2 ? 3 : 2;
    while (true) {
      blocks.clear();
      final nb = 5 + rng.nextInt(3);
      while (blocks.length < nb) {
        blocks.add(rng.nextInt(n * n));
      }
      final free = [for (var i = 0; i < n * n; i++) if (!blocks.contains(i)) i]..shuffle(rng);
      pen = free[0];
      fish = free[1];
      final s = solve(pen);
      if (s != null && s.length >= minMoves && s.length <= minMoves + 2) break;
    }
    at = cellC(pen);
  }

  bool get moving => target >= 0;

  @override
  void update(double dt) {
    if (moving) {
      final goal = cellC(target);
      final d = goal - at;
      final m = 640 * dt;
      if (d.distance <= m) {
        at = goal;
        pen = target;
        target = -1;
        Sfx.play('click', volume: .5);
      } else {
        at += d / d.distance * m;
        // ¿pasa por encima del pez?
        if ((at - cellC(fish)).distance < ts * .4 && res == 0) {
          win();
          Sfx.play('gulp');
        }
      }
    }
    if (res != 0 || moving || !p.released) return;
    final d = Offset(p.x - p.sx, p.y - p.sy);
    if (d.distance < 30) return;
    final dir = d.dx.abs() > d.dy.abs() ? (d.dx > 0 ? 1 : 3) : (d.dy > 0 ? 2 : 0);
    final (to, _) = slide(pen, dir);
    face = dirs[dir];
    if (to == pen) {
      Sfx.play('eh', volume: .6);
      return;
    }
    target = to;
    Sfx.play('shake', volume: .5);
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0x33FFFFFF);
    for (var i = 0; i <= n; i++) {
      c.drawLine(origin + Offset(i * ts, 0), origin + Offset(i * ts, n * ts), grid);
      c.drawLine(origin + Offset(0, i * ts), origin + Offset(n * ts, i * ts), grid);
    }
    for (final b in blocks) {
      final o = cellC(b);
      Gfx.sprite(c, 'ice_block', o.dx, o.dy, ts - 2, drop: const Offset(4, 7));
    }
    if (res != 1) {
      final f = cellC(fish);
      Gfx.sprite(c, 'fish', f.dx, f.dy + math.sin(vt * 8) * 2, 40, rot: math.sin(vt * 6) * .2, drop: const Offset(2, 4));
    }
    Gfx.shadow(c, at.dx, at.dy + 26, 54, alpha: .35);
    final lean = moving ? face.dx * .35 : math.sin(vt * 3) * .05;
    Gfx.sprite(c, 'penguin', at.dx, at.dy, 72, rot: lean, flip: face.dx < 0);
    if (res == 0 && t < 2.2 && !p.down) {
      final k = (vt * 1.2) % 1;
      fingerAt(c, at + Offset(30 + k * 60, 20));
    }
  }
}

// ───────────────────────── 83. SUMO DE MOCHIS (empujar fuera) ─────────────────────────
class SumoMochi extends Channel {
  SumoMochi(super.g);
  @override
  String get name => 'SUMO DE MOCHIS';
  @override
  String get sub => 'Gran final del torneo de pasteles de arroz';
  @override
  String get ins => '¡ECHA AL RIVAL DEL RING!';
  @override
  String get hint => 'Arrastra tu mochi rosa para empujar al verde fuera del círculo';
  @override
  String get bg => 'bg_dohyo';
  @override
  double get dur => 10;

  static const mr = 30.0;
  Offset me = Offset.zero, mv = Offset.zero, foe = Offset.zero, fv = Offset.zero;
  double power = 900, bump = 0;
  Offset get ring => Offset(bx(.5), by(.49));
  double get R => 449 * .305;

  @override
  void init(int l) {
    power = 820 + l * 90;
    me = ring + const Offset(-62, 18);
    foe = ring + const Offset(62, -18);
  }

  /// Bot: se pone detrás del rival (respecto al centro) y empuja hacia fuera.
  Offset botTarget() {
    final out0 = foe - ring;
    final out = out0.distance < 1 ? const Offset(1, 0) : out0 / out0.distance;
    final rel = me - foe;
    final behind = rel.dx * out.dx + rel.dy * out.dy < -20;
    return behind ? foe + out * 90 : foe - out * 75 + Offset(-out.dy, out.dx) * 30;
  }

  @override
  void update(double dt) {
    bump = math.max(0, bump - dt * 4);
    if (res != 0) {
      mv *= math.pow(.05, dt).toDouble();
      fv *= math.pow(.05, dt).toDouble();
      me += mv * dt;
      foe += fv * dt;
      return;
    }
    // yo: muelle hacia el dedo
    if (p.down) {
      var a = (Offset(p.x, p.y) - me) * 16 - mv * 5;
      if (a.distance > 1700) a = a / a.distance * 1700;
      mv += a * dt;
    } else {
      mv *= math.pow(.1, dt).toDouble();
    }
    // rival: va a por mí, pero si está cerca del borde vuelve al centro
    final toMe = me - foe, toC = ring - foe;
    final edge = clamp01(((foe - ring).distance - R * .45) / (R * .5));
    var dir = toMe / math.max(1, toMe.distance) * (1 - edge) + toC / math.max(1, toC.distance) * edge * 1.3;
    if (dir.distance > 0) dir = dir / dir.distance;
    fv += (dir * power - fv * 2.6) * dt;
    me += mv * dt;
    foe += fv * dt;
    // choque
    final d = foe - me;
    final dl = d.distance;
    if (dl < mr * 2 && dl > 0) {
      final n = d / dl;
      final over = mr * 2 - dl;
      me -= n * over * .5;
      foe += n * over * .5;
      final rv = (mv - fv);
      final vn = rv.dx * n.dx + rv.dy * n.dy;
      if (vn > 0) {
        const mMe = 1.0, mFoe = 1.0;
        final j = 1.8 * vn / (1 / mMe + 1 / mFoe);
        mv -= n * (j / mMe);
        fv += n * (j / mFoe);
        if (vn > 120) {
          bump = 1;
          Sfx.play('squish', volume: .6, minGapMs: 120);
        }
      }
    }
    if ((foe - ring).distance > R + 6) {
      win();
      Sfx.play('bonus');
      g.fx.burst(foe.dx, foe.dy, const Color(0xFF9BE7B0), 14);
    } else if ((me - ring).distance > R + 6) {
      Sfx.play('lose');
      lose('¡Te echaron del ring!');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (final (o, v, col, isMe) in [(foe, fv, const Color(0xFF9BE7B0), false), (me, mv, const Color(0xFFFFA8C8), true)]) {
      final sp = v.distance;
      final st0 = 1 + clamp01(sp / 900) * .12 + bump * .08;
      final ang = math.atan2(v.dy, v.dx);
      Gfx.shadow(c, o.dx + 4, o.dy + mr * .7, mr * 2.4, alpha: .4, ratio: .45);
      c.save();
      c.translate(o.dx, o.dy);
      c.rotate(ang);
      c.scale(st0, 1 / st0);
      c.rotate(-ang);
      Gfx.sprite(c, 'mochi', 0, 0, mr * 2.3, tint: col, flip: !isMe, rot: isMe ? .1 : -.1);
      c.restore();
    }
    if (res == 0 && t < 2 && !p.down) fingerAt(c, me + Offset(20 + math.sin(vt * 6) * 20, 10));
  }
}

// ───────────────────────── 84. DESENREDA LOS CABLES (sin cruces) ─────────────────────────
class Untangle extends Channel {
  Untangle(super.g);
  @override
  String get name => 'DESENREDA LOS CABLES';
  @override
  String get sub => 'Detrás de la tele vive el caos';
  @override
  String get ins => '¡QUE NO SE CRUCE NINGUNO!';
  @override
  String get hint => 'Arrastra los enchufes hasta que ningún cable se cruce con otro';
  @override
  String get bg => 'bg_behindtv';
  @override
  double get dur => 13;

  static const cols = [Color(0xFFE0473A), Color(0xFF3E7BD8), Color(0xFFF2C230), Color(0xFF4CC36A), Color(0xFFB07CFF), Color(0xFFFF8A3A), Color(0xFF53D8C3), Color(0xFFFF6FA8), Color(0xFF8B5A2B)];
  final nodes = <Offset>[];
  final edges = <(int, int)>[];
  int grab = -1;
  Rect get area => Rect.fromLTRB(sl + 44, st + 60, sr - 44, sb - 44);
  Offset solved(int i) => Offset(cx, cy + 10) + Offset(math.cos(-math.pi / 2 + i * tau / nodes.length), math.sin(-math.pi / 2 + i * tau / nodes.length)) * 140;

  @override
  void init(int l) {
    final n = l >= 2 ? 6 : 5;
    for (var i = 0; i < n; i++) {
      edges.add((i, (i + 1) % n));
    }
    if (n == 5) {
      edges.addAll([(0, 2), (2, 4)]);
    } else {
      edges.addAll([(0, 2), (2, 4), (4, 0)]);
    }
    do {
      nodes.clear();
      while (nodes.length < n) {
        final q = Offset(rnd(area.left, area.right), rnd(area.top, area.bottom));
        if (nodes.every((o) => (o - q).distance > 70)) nodes.add(q);
      }
    } while (crossings() < 2);
  }

  static bool _cross(Offset a, Offset b, Offset c, Offset d) {
    double o(Offset p, Offset q, Offset r) => (q.dx - p.dx) * (r.dy - p.dy) - (q.dy - p.dy) * (r.dx - p.dx);
    final d1 = o(a, b, c), d2 = o(a, b, d), d3 = o(c, d, a), d4 = o(c, d, b);
    return ((d1 > 0) != (d2 > 0)) && ((d3 > 0) != (d4 > 0)) && d1 != 0 && d2 != 0 && d3 != 0 && d4 != 0;
  }

  Set<int> crossingEdges() {
    final out = <int>{};
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        final (a, b) = edges[i];
        final (c2, d) = edges[j];
        if (a == c2 || a == d || b == c2 || b == d) continue;
        if (_cross(nodes[a], nodes[b], nodes[c2], nodes[d])) out.addAll([i, j]);
      }
    }
    return out;
  }

  int crossings() {
    var n = 0;
    for (var i = 0; i < edges.length; i++) {
      for (var j = i + 1; j < edges.length; j++) {
        final (a, b) = edges[i];
        final (c2, d) = edges[j];
        if (a == c2 || a == d || b == c2 || b == d) continue;
        if (_cross(nodes[a], nodes[b], nodes[c2], nodes[d])) n++;
      }
    }
    return n;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    final q = Offset(p.x, p.y);
    if (p.pressed) {
      var best = 40.0;
      for (var i = 0; i < nodes.length; i++) {
        final d = (nodes[i] - q).distance;
        if (d < best) {
          best = d;
          grab = i;
        }
      }
      if (grab >= 0) Sfx.play('click', volume: .6);
    }
    if (grab >= 0 && p.down) {
      nodes[grab] = Offset(q.dx.clamp(area.left - 20, area.right + 20), q.dy.clamp(area.top - 20, area.bottom + 20));
    }
    if (grab >= 0 && !p.down) {
      grab = -1;
      if (crossings() == 0) {
        win();
        Sfx.play('bonus');
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    c.drawRect(ZappingGame.bleed, Paint()..color = const Color(0x33000000));
    final bad = crossingEdges();
    for (var i = 0; i < edges.length; i++) {
      final (a, b) = edges[i];
      final pa = nodes[a], pb = nodes[b];
      final mid = Offset.lerp(pa, pb, .5)! + Offset(0, 14 + math.sin(vt * 2 + i) * 3);
      clayLine(c, [pa, mid, pb], cols[i % cols.length], bad.contains(i) && res == 0 ? 7 : 8);
    }
    for (var i = 0; i < nodes.length; i++) {
      final big = i == grab ? 1.15 : 1.0;
      Gfx.sprite(c, 'plug', nodes[i].dx, nodes[i].dy, 46 * big, drop: i == grab ? const Offset(6, 10) : const Offset(2, 4));
    }
    final n = crossings();
    Gfx.text(c, n == 0 ? '¡SIN CRUCES!' : 'CRUCES: $n', cx, st + 30, 22, color: n == 0 ? Pal.lime : Pal.gold);
    if (res == 0 && t < 2 && grab < 0) fingerAt(c, nodes[0] + Offset(math.sin(vt * 5) * 18, 0));
  }
}

// ───────────────────────── 85. JENGA DE GOFRES (quitar sin derrumbar) ─────────────────────────
class WaffleJenga extends Channel {
  WaffleJenga(super.g);
  @override
  String get name => 'JENGA DE GOFRES';
  @override
  String get sub => 'El desayuno más inestable del mundo';
  @override
  String get ins => '¡QUITA SIN QUE SE CAIGA!';
  @override
  String get hint => 'Toca un gofre que se pueda quitar sin que la torre se derrumbe';
  @override
  String get bg => 'bg_breakfast';
  @override
  double get dur => 10;

  static const layers = 7, endS = 40.0, barH = 22.0;
  // capas pares: tres gofres de punta [izq, centro, der]; impares: una barra larga
  final ends = <List<bool>>[];
  int removed = 0, need = 3, fallFrom = -1;
  final gone = <(Offset, double)>[];
  double get base => by(.857);

  double layerY(int i) {
    var y = base;
    for (var k = 0; k < i; k++) {
      y -= k.isEven ? endS : barH;
    }
    return y; // borde de abajo de la capa i
  }

  Offset piece(int layer, int k) => Offset(cx + (k - 1) * 44, layerY(layer) - endS / 2);

  static bool stable(List<bool> e) => e[1] || (e[0] && e[2]);

  int safeMoves() {
    var n = 0;
    for (var i = 0; i < layers; i += 2) {
      final e = ends[i];
      final cnt = e.where((x) => x).length;
      if (cnt == 3) n += 2;
      if (cnt == 2 && e[1]) n += 1;
    }
    return n;
  }

  @override
  void init(int l) {
    need = l >= 2 ? 4 : 3;
    do {
      ends.clear();
      for (var i = 0; i < layers; i++) {
        if (i.isOdd) {
          ends.add([]);
          continue;
        }
        final opts = [
          [true, true, true],
          [false, true, true],
          [true, true, false],
          [true, false, true],
        ];
        ends.add([...(i == 0 ? opts[0] : opts[rng.nextInt(opts.length)])]);
      }
    } while (safeMoves() < need + 1);
  }

  (int, int)? botPick() {
    for (var i = 0; i < layers; i += 2) {
      for (var k = 0; k < 3; k++) {
        if (!ends[i][k]) continue;
        final e = [...ends[i]]..[k] = false;
        if (stable(e)) return (i, k);
      }
    }
    return null;
  }

  @override
  void update(double dt) {
    if (res != 0 || !tap) return;
    final q = Offset(p.x, p.y);
    for (var i = 0; i < layers; i += 2) {
      for (var k = 0; k < 3; k++) {
        if (!ends[i][k]) continue;
        if (Rect.fromCenter(center: piece(i, k), width: 44, height: endS + 4).contains(q)) {
          ends[i][k] = false;
          gone.add((piece(i, k), t));
          if (stable(ends[i])) {
            removed++;
            Sfx.play('pop');
            if (removed >= need) {
              win();
              Sfx.play('bonus');
            }
          } else {
            fallFrom = i;
            Sfx.play('boom', volume: .6);
            g.fx.shake(12);
            lose('¡Se derrumbó el desayuno!');
          }
          return;
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final wob = math.sin(vt * 3) * .006 * (1 + removed);
    for (var i = 0; i < layers; i++) {
      final fall = fallFrom >= 0 && i > fallFrom ? clamp01(since * 1.6) : 0.0;
      final side = (i.isEven ? 1 : -1) * (fallFrom >= 0 ? 1.0 : 0);
      c.save();
      final pivot = Offset(cx, base);
      c.translate(pivot.dx, pivot.dy);
      c.rotate(wob * (i + 1) + side * fall * .9);
      c.translate(-pivot.dx + side * fall * 140, -pivot.dy + fall * fall * 200);
      if (i.isOdd) {
        Gfx.sprite(c, 'waffle_long', cx, layerY(i), barH + 1, ay: 1, sx: 1.04, drop: const Offset(2, 3));
      } else {
        for (var k = 0; k < 3; k++) {
          if (!ends[i][k]) continue;
          final o = piece(i, k);
          Gfx.sprite(c, 'waffle_end', o.dx, o.dy, endS, drop: const Offset(2, 3));
        }
      }
      c.restore();
    }
    // gofres que salen hacia la cámara
    for (final (o, t0) in gone) {
      final k = clamp01((t - t0) * 2.5);
      if (k >= 1) continue;
      Gfx.sprite(c, 'waffle_end', o.dx + k * 60, o.dy + k * 90, endS * (1 + k * .8), alpha: 1 - k);
    }
    Gfx.text(c, '$removed/$need', sr - 40, st + 34, 26, color: Pal.gold);
    if (res == 0 && t < 2.2) {
      final pk = botPick();
      if (pk != null) fingerAt(c, piece(pk.$1, pk.$2) + Offset(0, math.sin(vt * 9) * 4));
    }
  }
}
