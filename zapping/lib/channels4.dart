import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import 'channels.dart';
import 'channels3.dart' show scrollBg;
import 'game.dart';
import 'gfx.dart';
import 'sfx.dart';

// Canales 61–72 (ver docs/canales_61_85.md). Mecánicas nuevas: girar el tablero, rotar piezas,
// dibujar una cama elástica, invertir la gravedad, cruzar láseres, soltarse de lianas, contar el
// tiempo a ciegas, comparar cantidades, dar el cambio, deletrear, colorear por números y fuegos.

/// Caja de plastilina con relieve (luz arriba a la izquierda) y sombra de contacto.
void clayBox(Canvas c, Rect r, Color col, {double radius = 10, double shadow = 5}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
  if (shadow > 0) {
    c.drawRRect(
        rr.shift(Offset(shadow * .6, shadow)),
        Paint()
          ..color = const Color(0x55000000)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
  }
  final hsl = HSLColor.fromColor(col);
  final light = hsl.withLightness((hsl.lightness + .14).clamp(0, 1)).toColor();
  final dark = hsl.withLightness((hsl.lightness - .16).clamp(0, 1)).toColor();
  c.drawRRect(rr, Paint()..shader = Gradient.linear(r.topLeft, r.bottomRight, [light, col, dark], [0, .45, 1]));
}

/// Dedo de demostración (el mismo de los tutoriales).
void fingerAt(Canvas c, Offset o, {double alpha = 1}) =>
    Gfx.sprite(c, 'finger', o.dx + 16, o.dy + 10, 50, rot: -.3, alpha: alpha);

/// Cuerda/cable de plastilina: trazo grueso con borde oscuro y brillo.
void clayLine(Canvas c, List<Offset> pts, Color col, double w) {
  if (pts.length < 2) return;
  final path = Path()..moveTo(pts[0].dx, pts[0].dy);
  for (final q in pts.skip(1)) {
    path.lineTo(q.dx, q.dy);
  }
  final hsl = HSLColor.fromColor(col);
  final dark = hsl.withLightness((hsl.lightness - .2).clamp(0, 1)).toColor();
  final base = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  c.drawPath(path.shift(const Offset(3, 5)), Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = w
    ..color = const Color(0x44000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  c.drawPath(path, base
    ..strokeWidth = w + 3
    ..color = dark);
  c.drawPath(path, base
    ..strokeWidth = w
    ..color = col);
  c.drawPath(path.shift(Offset(-w * .15, -w * .2)), Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = w * .28
    ..color = const Color(0x55FFFFFF));
}

/// Número con coma decimal: 3 → "3", 3,5 → "3,50" ([fixed] siempre con dos decimales).
String num2(double v, {bool fixed = false}) {
  final cents = (v * 100).round();
  final e = cents ~/ 100, c = cents % 100;
  return c == 0 && !fixed ? '$e' : '$e,${c.toString().padLeft(2, '0')}';
}

/// Dinero (la fuente de plastilina no tiene el símbolo del euro).
String euros(double v) => '${num2(v)} ${v == 1 ? 'EURO' : 'EUROS'}';

double angNorm(double a) {
  while (a > math.pi) {
    a -= tau;
  }
  while (a < -math.pi) {
    a += tau;
  }
  return a;
}

// ───────────────────────── 61. EL LABERINTO DEL HÁMSTER (girar el tablero) ─────────────────────────
class HamsterMaze extends Channel {
  HamsterMaze(super.g);
  @override
  String get name => 'EL LABERINTO DEL HÁMSTER';
  @override
  String get sub => 'Bolita quiere volver a su madriguera';
  @override
  String get ins => '¡GIRA EL LABERINTO!';
  @override
  String get hint => 'Gira el tablero con el dedo para que la bola caiga al agujero';
  @override
  String get bg => 'bg_petshop';
  @override
  double get dur => 10;

  static const half = 138.0, r = 17.0, frame = 12.0;
  Offset get center => Offset(cx, cy + 16);
  double ang = 0, grabA = 0, grabAng = 0, roll = 0, inHole = -1;
  bool grabbing = false;
  Offset ball = Offset.zero, vel = Offset.zero, hole = Offset.zero;
  final walls = <Rect>[];
  final gapLeft = <bool>[];
  final barY = <double>[];
  double gap = 80;

  @override
  void init(int l) {
    gap = l >= 2 ? 70 : 82;
    var left = rng.nextBool();
    final ys = l >= 3 ? [-84.0, -28.0, 28.0, 84.0] : [-70.0, 0.0, 70.0];
    for (final y in ys) {
      barY.add(y);
      gapLeft.add(left);
      walls.add(left ? Rect.fromLTRB(-half + gap, y - 7, half, y + 7) : Rect.fromLTRB(-half, y - 7, half - gap, y + 7));
      left = !left;
    }
    ball = Offset(gapLeft[0] ? half - frame - r - 6 : -half + frame + r + 6, -half + frame + r + 2);
    hole = Offset(gapLeft.last ? half - frame - 30 : -half + frame + 30, half - frame - 26);
  }

  /// Ángulo que pondría el bot: inclina hacia el hueco de la barra que tiene debajo.
  double botAng() {
    for (var i = 0; i < barY.length; i++) {
      if (ball.dy < barY[i] - 4) {
        final gx = gapLeft[i] ? -half + gap / 2 : half - gap / 2;
        if ((ball.dx - gx).abs() < 14) return 0;
        return ball.dx < gx ? .55 : -.55;
      }
    }
    if ((ball.dx - hole.dx).abs() < 8) return 0;
    return ball.dx < hole.dx ? .4 : -.4;
  }

  @override
  void update(double dt) {
    if (res == 0) {
      final rel = Offset(p.x, p.y) - center;
      if (p.pressed && rel.distance > 24) {
        grabbing = true;
        grabA = math.atan2(rel.dy, rel.dx);
        grabAng = ang;
      }
      if (grabbing && p.down) {
        ang = (grabAng + angNorm(math.atan2(rel.dy, rel.dx) - grabA)).clamp(-1.25, 1.25);
      }
      if (!p.down) grabbing = false;
    }
    if (inHole >= 0) return;
    final gl = Offset(math.sin(ang), math.cos(ang)) * 900;
    const steps = 4;
    final h = dt / steps;
    final lim = half - frame - r;
    for (var s = 0; s < steps; s++) {
      vel += gl * h;
      vel *= 1 - .5 * h;
      ball += vel * h;
      for (final w in walls) {
        final q = Offset(ball.dx.clamp(w.left, w.right), ball.dy.clamp(w.top, w.bottom));
        final d = ball - q;
        final dl = d.distance;
        if (dl < r) {
          final n = dl < .001 ? const Offset(0, -1) : d / dl;
          ball = q + n * r;
          final vn = vel.dx * n.dx + vel.dy * n.dy;
          if (vn < 0) vel -= n * vn * 1.25;
        }
      }
      if (ball.dx < -lim) {
        ball = Offset(-lim, ball.dy);
        if (vel.dx < 0) vel = Offset(-vel.dx * .25, vel.dy);
      }
      if (ball.dx > lim) {
        ball = Offset(lim, ball.dy);
        if (vel.dx > 0) vel = Offset(-vel.dx * .25, vel.dy);
      }
      if (ball.dy < -lim) {
        ball = Offset(ball.dx, -lim);
        if (vel.dy < 0) vel = Offset(vel.dx, -vel.dy * .25);
      }
      if (ball.dy > lim) {
        ball = Offset(ball.dx, lim);
        if (vel.dy > 0) vel = Offset(vel.dx, -vel.dy * .25);
      }
    }
    roll += vel.dx * dt / r;
    if (res == 0 && (ball - hole).distance < 17) {
      inHole = vt;
      win();
      Sfx.play('gulp');
      g.fx.burst(center.dx, center.dy, Pal.gold, 18);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // tablero de madera girado
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(ang);
    const board = Rect.fromLTRB(-half, -half, half, half);
    clayBox(c, board, const Color(0xFFB9824C), radius: 18, shadow: 9);
    clayBox(c, board.deflate(frame), const Color(0xFFF0DDB0), radius: 10, shadow: 0);
    // migas de serrín
    for (var i = 0; i < 26; i++) {
      final a = i * 2.39, d = 20 + (i * 37) % 110;
      c.drawCircle(Offset(math.cos(a) * d, math.sin(a) * d), 2.2, Paint()..color = const Color(0x33A0703A));
    }
    Gfx.sprite(c, 'hole', hole.dx, hole.dy, 30);
    for (final w in walls) {
      clayBox(c, w, const Color(0xFF6FB7E0), radius: 7, shadow: 3);
    }
    if (res == 1) {
      final k = clamp01((vt - inHole) * 3);
      Gfx.sprite(c, 'hamsterball', hole.dx, hole.dy - k * 4, r * 2.1 * (1 - k * .55), rot: roll);
    } else {
      Gfx.shadow(c, ball.dx + 3, ball.dy + r * .8, r * 2, alpha: .35, ratio: .35);
      Gfx.sprite(c, 'hamsterball', ball.dx, ball.dy, r * 2.1, rot: roll);
    }
    c.restore();
    // demostración: un dedo da la vuelta alrededor del tablero
    if (res == 0 && t < 2.4 && !grabbing) {
      final k = math.sin(vt * 2.2) * .5;
      final a = -math.pi / 2 + k;
      const rr = 175.0;
      c.drawArc(Rect.fromCircle(center: center, radius: rr), -math.pi / 2 - .6, 1.2, false, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCFFB23E));
      fingerAt(c, center + Offset(math.cos(a) * rr, math.sin(a) * rr));
    }
  }
}

// ───────────────────────── 62. FONTANERO EXPRÉS (girar piezas) ─────────────────────────
class Plumber extends Channel {
  Plumber(super.g);
  @override
  String get name => 'FONTANERO EXPRÉS';
  @override
  String get sub => 'La flor del sótano se muere de sed';
  @override
  String get ins => '¡CONECTA LAS TUBERÍAS!';
  @override
  String get hint => 'Toca las tuberías para girarlas hasta llevar el agua a la derecha';
  @override
  String get bg => 'bg_plumb';
  @override
  double get dur => _dur;

  double _dur = 11;
  static const ts = 100.0;
  final type = List.filled(9, 0), rot = List.filled(9, 0);
  final shown = List.filled(9, 0.0);
  final need = <int, Set<int>>{};
  int inRow = 0, outRow = 0;
  List<int> flow = [];
  Offset get origin => Offset(cx - ts * 1.5, st + 48);
  Rect cell(int i) => Rect.fromLTWH(origin.dx + (i % 3) * ts, origin.dy + (i ~/ 3) * ts, ts, ts);

  /// Lados que une una pieza (0 arriba, 1 derecha, 2 abajo, 3 izquierda). Recta: izq-der; codo: izq-abajo.
  static Set<int> conn(int type, int r) => type == 0 ? {(3 + r) % 4, (1 + r) % 4} : {(3 + r) % 4, (2 + r) % 4};

  @override
  void init(int l) {
    _dur = math.max(7.5, 11 - l * .5);
    var r = inRow = rng.nextInt(3);
    outRow = rng.nextInt(3);
    var entry = 3;
    for (var col = 0; col < 3; col++) {
      final target = col == 2 ? outRow : rng.nextInt(3);
      while (true) {
        final i = r * 3 + col;
        final exit = r == target ? 1 : (target > r ? 2 : 0);
        type[i] = (exit - entry).abs() == 2 ? 0 : 1;
        need[i] = {entry, exit};
        if (exit == 1) {
          entry = 3;
          break;
        }
        r += exit == 2 ? 1 : -1;
        entry = exit == 2 ? 0 : 2;
      }
    }
    for (var i = 0; i < 9; i++) {
      if (!need.containsKey(i)) type[i] = rng.nextInt(2);
    }
    do {
      for (var i = 0; i < 9; i++) {
        rot[i] = rng.nextInt(4);
      }
    } while (trace() != null || wrongCells() < 3);
    for (var i = 0; i < 9; i++) {
      shown[i] = rot[i] * math.pi / 2;
    }
  }

  int wrongCells() => need.entries.where((e) => !_same(conn(type[e.key], rot[e.key]), e.value)).length;
  static bool _same(Set<int> a, Set<int> b) => a.length == b.length && a.containsAll(b);

  /// Recorre el agua desde la entrada; devuelve las casillas si llega a la salida.
  List<int>? trace() {
    var r = inRow, col = 0, entry = 3;
    final cells = <int>[];
    while (true) {
      if (r < 0 || r > 2 || col < 0 || col > 2 || cells.length > 9) return null;
      final i = r * 3 + col;
      final cs = conn(type[i], rot[i]);
      if (!cs.contains(entry)) return null;
      cells.add(i);
      final exit = cs.firstWhere((s) => s != entry);
      if (exit == 1 && col == 2) return r == outRow ? cells : null;
      switch (exit) {
        case 0:
          r--;
          entry = 2;
        case 1:
          col++;
          entry = 3;
        case 2:
          r++;
          entry = 0;
        default:
          col--;
          entry = 1;
      }
    }
  }

  /// Bot: centro de una casilla del camino que aún está mal girada.
  Offset? botTap() {
    for (final e in need.entries) {
      if (!_same(conn(type[e.key], rot[e.key]), e.value)) return cell(e.key).center;
    }
    return null;
  }

  @override
  void update(double dt) {
    for (var i = 0; i < 9; i++) {
      final target = rot[i] * math.pi / 2;
      var d = angNorm(target - shown[i]);
      shown[i] += d * (1 - math.exp(-dt * 18));
    }
    if (res != 0 || !tap) return;
    for (var i = 0; i < 9; i++) {
      if (cell(i).contains(Offset(p.x, p.y))) {
        rot[i] = (rot[i] + 1) % 4;
        Sfx.play('ratchet', volume: .7);
        final f = trace();
        if (f != null) {
          flow = f;
          win();
          Sfx.play('bonus');
        }
      }
    }
  }

  Offset _side(Rect r, int s) => switch (s) {
        0 => r.topCenter,
        1 => r.centerRight,
        2 => r.bottomCenter,
        _ => r.centerLeft,
      };

  @override
  void render(Canvas c) {
    drawBg(c);
    final inY = cell(inRow * 3).center.dy, outY = cell(outRow * 3 + 2).center.dy;
    const copper = Color(0xFFC77A3E);
    clayBox(c, Rect.fromLTRB(sl - 20, inY - 11, origin.dx + 4, inY + 11), copper, radius: 9, shadow: 4);
    clayBox(c, Rect.fromLTRB(origin.dx + ts * 3 - 4, outY - 11, sr + 20, outY + 11), copper, radius: 9, shadow: 4);
    clayBox(c, Rect.fromLTRB(origin.dx - 8, origin.dy - 8, origin.dx + ts * 3 + 8, origin.dy + ts * 3 + 8),
        const Color(0xFF4A4550), radius: 14, shadow: 8);
    for (var i = 0; i < 9; i++) {
      final r = cell(i);
      Gfx.sprite(c, type[i] == 0 ? 'pipe_straight' : 'pipe_corner', r.center.dx, r.center.dy, ts - 4,
          rot: shown[i], drop: const Offset(2, 3));
    }
    // agua avanzando por el camino al ganar
    if (res == 1) {
      final k = since * 7;
      final water = const Color(0xFF4FB6F2);
      final pts = <Offset>[Offset(sl - 20, inY)];
      var entry = 3;
      for (var n = 0; n < flow.length && n < k; n++) {
        final i = flow[n];
        final cs = conn(type[i], rot[i]);
        final exit = cs.firstWhere((s) => s != entry);
        final r = cell(i);
        pts.addAll([_side(r, entry), r.center, _side(r, exit)]);
        entry = (exit + 2) % 4;
      }
      if (k > flow.length) pts.add(Offset(sr + 20, outY));
      clayLine(c, pts, water, 12);
      if (k > flow.length) {
        for (var j = 0; j < 3; j++) {
          Gfx.clayBall(c, sr - 6 - j * 9, outY + 16 + ((vt * 90 + j * 30) % 60), 5, water);
        }
      }
    }
    Gfx.anim(c, 'plumber', vt, bx(.12), sb - 2, 92, ay: 1);
    if (res == 0 && t < 1.8) {
      final r = cell(4);
      fingerAt(c, r.center + Offset(0, math.sin(vt * 9) * 4));
    }
  }
}

// ───────────────────────── 63. HUEVOS SALTARINES (dibujar la cama elástica) ─────────────────────────
class EggSim {
  Offset e, v;
  bool bounced = false;
  EggSim(this.e, this.v);
}

class EggBounce extends Channel {
  EggBounce(super.g);
  @override
  String get name => 'HUEVOS SALTARINES';
  @override
  String get sub => 'La gallina Clotilde pone huevos desde la viga';
  @override
  String get ins => '¡DIBUJA UNA CAMA ELÁSTICA!';
  @override
  String get hint => 'Desliza para trazar una cama elástica que mande el huevo a la cesta';
  @override
  String get bg => 'bg_barn';
  @override
  double get dur => 11;

  static const gravity = 620.0, er = 14.0, maxLen = 170.0;
  EggSim? egg;
  Offset? ta, tb;
  double usedAt = -1, spin = 0, henX = 0, henDir = 1, layAt = 1.3, dropX = 0, brokeAt = -1;
  int caught = 0, need = 2;
  double basketX = 0;
  Offset brokeAtPos = Offset.zero;
  double get shelfY => st + 96;
  double get floorY => foot(.9);
  double get mouthY => floorY - 60;

  @override
  void init(int l) {
    need = l >= 3 ? 3 : 2;
    basketX = rng.nextBool() ? bx(.17) : bx(.83);
    henX = cx;
    _plan();
  }

  void _plan() {
    final away = basketX < cx ? 1.0 : -1.0;
    dropX = cx + away * rnd(10, 90);
  }

  /// Un paso de la física del huevo. 1 = a la cesta, -1 = roto o fuera, 0 = sigue.
  int stepSim(EggSim s, Offset? a, Offset? b, double dt) {
    s.v += const Offset(0, gravity) * dt;
    s.e += s.v * dt;
    if (a != null && b != null && !s.bounced) {
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (len2 > 1) {
        final k = (((s.e - a).dx * ab.dx + (s.e - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
        final q = a + ab * k;
        final d = s.e - q;
        if (d.distance < er) {
          var n = Offset(-ab.dy, ab.dx) / math.sqrt(len2);
          if (n.dy > 0) n = -n;
          final vn = s.v.dx * n.dx + s.v.dy * n.dy;
          if (vn < 0) {
            s.v -= n * (2 * vn);
            final out = s.v.dx * n.dx + s.v.dy * n.dy;
            if (out < 600) s.v += n * (600 - out);
            s.e = q + n * (er + 1);
            s.bounced = true;
          }
        }
      }
    }
    if (s.v.dy > 0 && (s.e.dx - basketX).abs() < 34 && s.e.dy >= mouthY && s.e.dy - s.v.dy * dt < mouthY) return 1;
    if (s.e.dy > floorY - 8) return -1;
    if (s.e.dx < sl - 30 || s.e.dx > sr + 30) return -1;
    return 0;
  }

  /// Bot: busca una cama elástica bajo el huevo que lo mande a la cesta (prueba ángulos).
  (Offset, Offset)? botLine() {
    final e = egg;
    if (e == null || e.bounced) return null;
    for (var y = floorY - 70; y > floorY - 230; y -= 15) {
      for (var a = -1.0; a <= 1.0; a += .02) {
        final mid = Offset(e.e.dx, y);
        final d = Offset(math.cos(a), math.sin(a)) * 60;
        final s = EggSim(e.e, e.v);
        var r = 0;
        for (var i = 0; i < 600 && r == 0; i++) {
          r = stepSim(s, mid - d, mid + d, 1 / 120);
        }
        if (r == 1) return (mid - d, mid + d);
      }
    }
    return null;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    // gallina: pasea por la viga y se para a poner el huevo
    final e = egg;
    if (e == null) {
      if (t < layAt - .6) {
        henX += henDir * 90 * dt;
        if (henX > sr - 70 || henX < sl + 70) henDir = -henDir;
      } else {
        henX += (dropX - henX) * (1 - math.exp(-dt * 10));
        henDir = dropX >= henX ? 1 : -1;
      }
      if (t >= layAt) {
        egg = EggSim(Offset(henX, shelfY + 8), Offset.zero);
        Sfx.play('pop', volume: .6);
      }
    }
    // trazar la cama elástica
    if (p.released) {
      final a = Offset(p.sx, p.sy), b0 = Offset(p.x, p.y);
      var d = b0 - a;
      if (d.distance > 40) {
        if (d.distance > maxLen) d = d / d.distance * maxLen;
        ta = a;
        tb = a + d;
        usedAt = -1;
        Sfx.play('boing', volume: .5);
      }
    }
    final eg = egg;
    if (eg == null) return;
    spin += dt * 3;
    final wasBounced = eg.bounced;
    final r = stepSim(eg, usedAt < 0 ? ta : null, usedAt < 0 ? tb : null, dt);
    if (eg.bounced && !wasBounced) {
      usedAt = t;
      Sfx.play('boing');
    }
    if (r == 1) {
      caught++;
      Sfx.play('bonus');
      g.fx.burst(basketX, mouthY, Pal.gold, 10);
      egg = null;
      if (caught >= need) {
        win();
      } else {
        layAt = t + 1.0;
        _plan();
      }
    } else if (r == -1) {
      brokeAtPos = Offset(eg.e.dx.clamp(sl + 20, sr - 20), floorY);
      brokeAt = vt;
      egg = null;
      Sfx.play('splat');
      lose('¡Tortilla en el suelo!');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // viga para la gallina
    clayBox(c, Rect.fromLTRB(sl - 20, shelfY, sr + 20, shelfY + 16), const Color(0xFF8A5A33), radius: 6, shadow: 6);
    Gfx.anim(c, 'hen', vt, henX, shelfY + 3, 84, ay: 1, flip: henDir < 0);
    // cesta
    Gfx.shadow(c, basketX, floorY, 100, alpha: .45);
    Gfx.sprite(c, 'basket', basketX, floorY + 4, 82, ay: 1);
    for (var i = 0; i < caught; i++) {
      Gfx.sprite(c, 'egg', basketX - 14 + i * 14, mouthY + 6, 24);
    }
    // cama elástica
    final a = ta, b = tb;
    if (a != null && b != null) {
      final fade = usedAt < 0 ? 1.0 : 1 - clamp01((t - usedAt) * 3);
      if (fade > 0) {
        final mid = Offset.lerp(a, b, .5)!;
        final sag = usedAt >= 0 ? math.sin(clamp01((t - usedAt) * 3) * math.pi) * 14 : 0.0;
        for (final q in [a, b]) {
          clayLine(c, [q, q + const Offset(0, 26)], Color.fromRGBO(90, 90, 100, fade), 6);
        }
        clayLine(c, [a, mid + Offset(0, sag), b], Color.fromRGBO(226, 61, 84, fade), 11);
      }
    }
    if (p.down && res == 0) {
      var d = Offset(p.x - p.sx, p.y - p.sy);
      if (d.distance > maxLen) d = d / d.distance * maxLen;
      clayLine(c, [Offset(p.sx, p.sy), Offset(p.sx, p.sy) + d], const Color(0x88E23D54), 9);
    }
    final eg = egg;
    if (eg != null) {
      Gfx.sprite(c, 'egg', eg.e.dx, eg.e.dy, er * 2.6, rot: eg.bounced ? spin * 2 : math.sin(spin * 3) * .2,
          drop: const Offset(3, 6));
    }
    if (brokeAt >= 0) {
      Gfx.sprite(c, 'egg_broken', brokeAtPos.dx, brokeAtPos.dy, 34, ay: .8);
    }
    Gfx.text(c, '$caught/$need', sr - 30, shelfY + 46, 26, color: Pal.gold);
    if (res == 0 && t < 2.2) {
      final k = (vt * .8) % 1;
      final a0 = Offset(cx - 70, floorY - 110), b0 = Offset(cx + 60, floorY - 140);
      clayLine(c, [a0, Offset.lerp(a0, b0, k)!], const Color(0x99E23D54), 9);
      fingerAt(c, Offset.lerp(a0, b0, k)!);
    }
  }
}

// ───────────────────────── 64. EL GATO DEL TECHO (invertir la gravedad) ─────────────────────────
class _Spike {
  double x;
  final bool top;
  bool passed = false;
  _Spike(this.x, this.top);
}

class CeilingCat extends Channel {
  CeilingCat(super.g);
  @override
  String get name => 'EL GATO DEL TECHO';
  @override
  String get sub => 'Bigotes corre por el pasillo patas arriba';
  @override
  String get ins => '¡TOCA PARA DAR LA VUELTA!';
  @override
  String get hint => 'Toca para pasar del suelo al techo y esquivar los pinchos';
  @override
  String get bg => 'bg_corridor';
  @override
  bool get survive => true;
  @override
  double get dur => 7.5;

  final spikes = <_Spike>[];
  double scroll = 0, speed = 250, y = 0, vy = 0;
  bool up = false;
  int passed = 0;
  // suelo y techo del pasillo medidos sobre el decorado (1280x720 escalado al alto de la tele)
  double get floorY => ZappingGame.bleed.top + ZappingGame.bleed.height * .845;
  double get ceilY => ZappingGame.bleed.top + ZappingGame.bleed.height * .145;
  double get catX => sl + 105;

  @override
  void init(int l) {
    speed = 250 + l * 18;
    y = floorY;
    var x = sr + 120;
    var top = rng.nextBool();
    for (var i = 0; i < 14; i++) {
      spikes.add(_Spike(x, top));
      x += rnd(185, 260);
      top = rng.nextDouble() < .55 ? !top : top;
    }
  }

  bool get flipping => (up && y > ceilY + 1) || (!up && y < floorY - 1);

  /// Bot: el próximo pincho de mi lado está cerca → dar la vuelta.
  bool botShouldTap() {
    for (final s in spikes) {
      if (s.x < catX - 45) continue;
      final mine = s.top == up;
      return mine && s.x - catX < 130 && !flipping;
    }
    return false;
  }

  @override
  void update(double dt) {
    scroll += speed * dt;
    for (final s in spikes) {
      s.x -= speed * dt;
    }
    if (res != 0) return;
    if (tap) {
      up = !up;
      Sfx.play('boing', volume: .7);
    }
    vy += (up ? -1 : 1) * 3600 * dt;
    y += vy * dt;
    if (y > floorY) {
      y = floorY;
      vy = 0;
    }
    if (y < ceilY) {
      y = ceilY;
      vy = 0;
    }
    for (final s in spikes) {
      if ((s.x - catX).abs() < 38) {
        final hit = s.top ? y < ceilY + 34 : y > floorY - 34;
        if (hit) {
          g.fx.shake(10);
          Sfx.play('lose');
          lose('¡Pinchazo gatuno!');
        }
      }
      if (!s.passed && s.x < catX - 40) {
        s.passed = true;
        passed++;
      }
    }
  }

  @override
  void render(Canvas c) {
    scrollBg(c, bg, scroll);
    for (final s in spikes) {
      if (s.x < sl - 80 || s.x > sr + 80) continue;
      if (s.top) {
        Gfx.sprite(c, 'spikes', s.x, ceilY - 2, 40, ay: 1, sy: -1);
      } else {
        Gfx.sprite(c, 'spikes', s.x, floorY + 2, 40, ay: 1);
      }
    }
    final mid = (floorY + ceilY) / 2;
    final onTop = y < mid;
    final hurt = res == -1;
    if (!flipping) Gfx.shadow(c, catX, onTop ? ceilY : floorY, 90, alpha: .4);
    Gfx.anim(c, 'runcat', hurt ? resAt : vt, catX, y + (onTop ? -3 : 3), 92,
        ay: 1, sy: onTop ? -1 : 1, rot: hurt ? math.sin(vt * 30) * .1 : 0, fps: 16);
    Gfx.text(c, 'PINCHOS: $passed', sr - 70, mid, 20, color: Pal.gold, alpha: .9);
    if (res == 0 && t < 1.6) {
      fingerAt(c, Offset(cx + 40, mid + math.sin(vt * 9) * 5));
    }
  }
}

// ───────────────────────── 65. LÁSERES DEL MUSEO (cruzar en el momento justo) ─────────────────────────
class Laser {
  final double y, phase, period, speed;
  final int kind; // 0 parpadea, 1 tiene un hueco que se mueve
  Laser(this.y, this.kind, this.phase, this.period, this.speed);
}

class MuseumLasers extends Channel {
  MuseumLasers(super.g);
  @override
  String get name => 'LÁSERES DEL MUSEO';
  @override
  String get sub => 'El ladrón de calcetines va a por el diamante';
  @override
  String get ins => '¡ESQUIVA LOS LÁSERES!';
  @override
  String get hint => 'Arrastra al ladrón hasta el diamante sin tocar un láser encendido';
  @override
  String get bg => 'bg_museum';
  @override
  double get dur => 11;

  final lasers = <Laser>[];
  Offset thief = Offset.zero; // pies
  bool caught = false;
  static const gapW = 104.0, step = 230.0;
  Offset get gem => Offset(cx, by(.345));

  @override
  void init(int l) {
    thief = Offset(cx, sb - 14);
    final ys = l >= 3 ? [312.0, 374.0, 436.0, 498.0] : [330.0, 400.0, 470.0];
    for (var i = 0; i < ys.length; i++) {
      final kind = l == 0 ? 0 : (i.isOdd ? 1 : rng.nextInt(2));
      lasers.add(Laser(ys[i], kind, rnd(0, 3), rnd(1.5, 2.1) / (1 + l * .08), rnd(1.3, 1.8) * (1 + l * .06)));
    }
  }

  bool on(Laser z) => z.kind == 1 || ((t + z.phase) % z.period) < z.period * .55;
  double gapX(Laser z, [double dt = 0]) => cx + math.sin((t + dt) * z.speed + z.phase) * 120;
  bool hits(Laser z, Offset feet) {
    if (!on(z)) return false;
    if (feet.dy - 52 > z.y || feet.dy - 10 < z.y) return false;
    return z.kind == 0 || (feet.dx - gapX(z)).abs() > gapW / 2 - 16;
  }

  double offLeft(Laser z) {
    final ph = (t + z.phase) % z.period;
    return ph < z.period * .55 ? 0 : z.period - ph;
  }

  /// Bot: espera debajo del siguiente láser y cruza cuando está apagado (o por el hueco).
  Offset botTarget() {
    for (final z in lasers.reversed) {
      if (thief.dy - 10 <= z.y) continue; // ya lo ha pasado
      final wait = Offset(z.kind == 1 ? gapX(z, .15) : thief.dx, z.y + 60);
      final ok = z.kind == 0 ? offLeft(z) > .42 : (thief.dx - gapX(z)).abs() < 14 && (thief.dx - gapX(z, .3)).abs() < 22;
      if (thief.dy > z.y + 56 && !ok) return wait;
      if (thief.dy > z.y + 56 || ok || thief.dy < z.y + 56) {
        return Offset(z.kind == 1 ? gapX(z, .1) : thief.dx, z.y - 14);
      }
    }
    return gem + const Offset(0, 40);
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.down) {
      final target = Offset(p.x, p.y + 20);
      final d = target - thief;
      final m = step * dt;
      thief += d.distance <= m ? d : d / d.distance * m;
      thief = Offset(thief.dx.clamp(sl + 30, sr - 30), thief.dy.clamp(gem.dy + 30, sb - 8));
    }
    for (final z in lasers) {
      if (hits(z, thief)) {
        caught = true;
        g.fx.shake(10);
        Sfx.play('boom', volume: .6);
        lose('¡Saltó la alarma!');
        return;
      }
    }
    if ((thief - const Offset(0, 40) - gem).distance < 46) {
      win();
      Sfx.play('bonus');
      g.fx.burst(gem.dx, gem.dy, const Color(0xFF8FD8FF), 20);
    }
  }

  void _beam(Canvas c, double x0, double x1, double y, double a) {
    final glow = Paint()
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..color = Color.fromRGBO(255, 40, 60, .35 * a)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    c.drawLine(Offset(x0, y), Offset(x1, y), glow);
    c.drawLine(Offset(x0, y), Offset(x1, y), Paint()
      ..strokeWidth = 3.5
      ..color = Color.fromRGBO(255, 120, 130, a));
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // diamante sobre el pedestal
    if (res != 1) {
      final glint = .5 + math.sin(vt * 4) * .5;
      c.drawCircle(gem, 34, Paint()
        ..color = Color.fromRGBO(140, 220, 255, .25 + glint * .2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
      Gfx.sprite(c, 'diamond', gem.dx, gem.dy, 44, rot: math.sin(vt * 2) * .05);
    }
    for (final z in lasers) {
      clayBox(c, Rect.fromCenter(center: Offset(sl + 8, z.y), width: 18, height: 26), const Color(0xFF555566), radius: 5, shadow: 3);
      clayBox(c, Rect.fromCenter(center: Offset(sr - 8, z.y), width: 18, height: 26), const Color(0xFF555566), radius: 5, shadow: 3);
      if (!on(z)) {
        _beam(c, sl + 16, sr - 16, z.y, .12);
        continue;
      }
      final flick = .85 + math.sin(vt * 40 + z.y) * .15;
      if (z.kind == 0) {
        _beam(c, sl + 16, sr - 16, z.y, flick);
      } else {
        final gx = gapX(z);
        _beam(c, sl + 16, gx - gapW / 2, z.y, flick);
        _beam(c, gx + gapW / 2, sr - 16, z.y, flick);
      }
    }
    Gfx.shadow(c, thief.dx, thief.dy, 56, alpha: .45);
    Gfx.sprite(c, 'thief', thief.dx, thief.dy, 86, ay: 1, rot: caught ? math.sin(vt * 30) * .12 : math.sin(vt * 9) * .04);
    if (res == 1) Gfx.sprite(c, 'diamond', thief.dx + 18, thief.dy - 50, 30);
    if (caught) {
      final a = (math.sin(vt * 16) * .5 + .5) * .35;
      c.drawRect(ZappingGame.bleed, Paint()..color = Color.fromRGBO(255, 0, 30, a));
    }
    if (res == 0 && t < 2 && !p.down) {
      fingerAt(c, thief + Offset(0, -30 - (vt * 40) % 40));
    }
  }
}

// ───────────────────────── 66. TARZÁN DE PLASTILINA (soltarse a tiempo) ─────────────────────────
class Tarzan extends Channel {
  Tarzan(super.g);
  @override
  String get name => 'TARZÁN DE PLASTILINA';
  @override
  String get sub => 'Chita cruza la selva de liana en liana';
  @override
  String get ins => '¡SUÉLTATE A TIEMPO!';
  @override
  String get hint => 'Toca para soltarte y agarrar la liana siguiente';
  @override
  String get bg => 'bg_jungle';
  @override
  double get dur => 10;

  final ax = <double>[], len = <double>[], ph = <double>[];
  double amp = .62, w = 2.5, grabbedAt = 0;
  int cur = 0;
  bool flying = false;
  Offset pos = Offset.zero, vel = Offset.zero, grabFrom = Offset.zero;
  double get anchorY => st - 6;
  double get waterY => by(.9);

  @override
  void init(int l) {
    w = 2.5 * (1 + l * .07);
    amp = .62;
    for (var i = 0; i < 3; i++) {
      ax.add(sl + 70 + i * 140.5);
      len.add(rnd(225, 262));
      // cada liana va a contratiempo de la anterior: cuando tú vas hacia delante, ella viene hacia ti
      ph.add(i == 0 ? -math.pi / 2 - .2 : ph[i - 1] + math.pi + rnd(-.5, .5));
    }
  }

  double theta(int i, [double dt = 0]) => amp * math.sin(w * (t + dt) + ph[i]);
  Offset hand(int i, [double dt = 0]) {
    final th = theta(i, dt);
    return Offset(ax[i] + math.sin(th) * len[i], anchorY + math.cos(th) * len[i]);
  }

  Offset releaseVel() {
    final th = theta(cur);
    final dth = amp * w * math.cos(w * t + ph[cur]);
    return Offset(math.cos(th), -math.sin(th)) * (len[cur] * dth) + const Offset(0, -140);
  }

  /// Distancia del punto a la liana j (solo su mitad de abajo) en el instante t+dt.
  bool _touches(int j, Offset q, double dt) {
    final a = Offset(ax[j], anchorY), b = hand(j, dt);
    final ab = b - a;
    final k = (((q - a).dx * ab.dx + (q - a).dy * ab.dy) / (ab.dx * ab.dx + ab.dy * ab.dy)).clamp(.45, 1.05);
    return (q - (a + ab * k)).distance < 30;
  }

  /// Bot: ¿si me suelto ahora, agarro la siguiente?
  bool wouldCatch() {
    if (flying || cur >= 2) return false;
    var q = hand(cur), v = releaseVel();
    if (v.dx <= 60) return false;
    for (var i = 1; i < 150; i++) {
      const h = 1 / 120;
      v += const Offset(0, 900) * h;
      q += v * h;
      if (_touches(cur + 1, q, i * h)) return true;
      if (q.dy > waterY) return false;
    }
    return false;
  }

  @override
  void update(double dt) {
    if (res != 0) {
      if (flying) {
        vel += Offset(0, 900 * dt);
        pos += vel * dt;
      }
      return;
    }
    if (!flying) {
      if (tap) {
        flying = true;
        pos = hand(cur);
        vel = releaseVel();
        Sfx.play('boing', volume: .6);
      }
      return;
    }
    vel += Offset(0, 900 * dt);
    pos += vel * dt;
    final j = cur + 1;
    if (j < 3 && _touches(j, pos, 0)) {
      cur = j;
      flying = false;
      grabFrom = pos;
      grabbedAt = vt;
      Sfx.play('squish');
      if (cur == 2) {
        win();
        Sfx.play('bonus');
      }
      return;
    }
    if (pos.dy > waterY) {
      Sfx.play('splat');
      g.fx.burst(pos.dx, waterY, const Color(0xFF7A8F4A), 14);
      lose('¡Al río con los cocodrilos!');
    } else if (pos.dx < sl - 40 || pos.dx > sr + 40) {
      lose('¡Se fue volando!');
    }
  }

  void _vine(Canvas c, int i) {
    final a = Offset(ax[i], anchorY), b = hand(i);
    clayLine(c, [a, Offset.lerp(a, b, .5)! + Offset(math.sin(vt * 2 + i) * 4, 0), b], const Color(0xFF4E8A2E), 8);
    for (var k = 1; k < 5; k++) {
      final q = Offset.lerp(a, b, k / 5)!;
      c.save();
      c.translate(q.dx, q.dy);
      c.rotate(k.isOdd ? .7 : -.7);
      c.drawOval(Rect.fromCenter(center: Offset(k.isOdd ? 9 : -9, 0), width: 18, height: 9), Paint()..color = const Color(0xFF6DB33F));
      c.restore();
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    clayBox(c, Rect.fromLTRB(sl - 30, st - 30, sr + 30, st + 12), const Color(0xFF7A5230), radius: 14, shadow: 6);
    for (var i = 0; i < 3; i++) {
      _vine(c, i);
    }
    // plátano en la última liana
    Gfx.text(c, 'META', ax[2], st + 40, 18, color: Pal.gold);
    Offset at;
    double rot;
    if (flying) {
      at = pos;
      rot = math.atan2(vel.dx, -vel.dy) * .3;
    } else {
      final k = clamp01((vt - grabbedAt) * 8);
      at = Offset.lerp(grabFrom, hand(cur), cur == 0 ? 1 : k)!;
      rot = -theta(cur);
    }
    Gfx.sprite(c, 'tarzan', at.dx, at.dy - 6, 96, ay: .02, rot: rot);
    if (res == 0 && !flying && cur == 0 && t < 2) fingerAt(c, Offset(cx, cy + 60 + math.sin(vt * 9) * 4));
  }
}

// ───────────────────────── 67. CRONÓMETRO A CIEGAS (reloj interno) ─────────────────────────
class BlindTimer extends Channel {
  BlindTimer(super.g);
  @override
  String get name => 'CRONÓMETRO A CIEGAS';
  @override
  String get sub => 'El búho relojero pone a prueba tu reloj interno';
  @override
  String get ins => '¡PARA EN ${num2(target)} SEGUNDOS!';
  @override
  String get hint => 'Cuenta en tu cabeza y toca cuando creas que han pasado';
  @override
  String get bg => 'bg_clockshop';
  @override
  double get dur => 60;

  double target = 3, tol = .3, start = -1, stopped = -1;
  double get elapsed => start < 0 ? 0 : (stopped >= 0 ? stopped : vt - start);

  @override
  void init(int l) {
    target = pick(l < 2 ? [2.0, 3.0] : [2.0, 2.5, 3.0, 3.5, 4.0]);
    tol = math.max(.15, .3 - l * .035);
  }

  bool botShouldTap() => start >= 0 && vt - start >= target - .005;

  @override
  void update(double dt) {
    if (start < 0) start = vt;
    if (res != 0) return;
    if (tap) {
      stopped = vt - start;
      final err = stopped - target;
      Sfx.play('click');
      if (err.abs() <= tol) {
        win();
        Sfx.play('bonus');
      } else {
        lose(err > 0 ? '¡Te pasaste! ${num2(stopped, fixed: true)} s' : '¡Muy pronto! ${num2(stopped, fixed: true)} s');
      }
    } else if (vt - start > target + 1.3) {
      stopped = vt - start;
      lose('¡Se te durmió el dedo!');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'owl', vt, bx(.84), foot(.93), 120, ay: 1);
    final o = Offset(cx - 20, cy + 6);
    const h = 270.0;
    Gfx.sprite(c, 'stopwatch', o.dx, o.dy, h, drop: const Offset(8, 12));
    final face = o + const Offset(0, h * .1);
    final hidden = stopped < 0 && elapsed > 1.0;
    final e = elapsed;
    // aguja
    final a = hidden ? -math.pi / 2 + math.sin(vt * 23) * 2.5 : -math.pi / 2 + e * tau;
    c.drawLine(face, face + Offset(math.cos(a), math.sin(a)) * 70, Paint()
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = hidden ? const Color(0x33E0302A) : Pal.tomato);
    Gfx.clayBall(c, face.dx, face.dy, 8, Pal.tomato);
    final txt = hidden ? '?,??' : num2(e, fixed: true);
    Gfx.text(c, txt, face.dx, face.dy + 42, 34,
        color: stopped >= 0 ? (res == 1 ? Pal.lime : Pal.pink) : const Color(0xFF3A2A4A), outline: false);
    if (hidden && res == 0) {
      Gfx.text(c, '¡CUENTA!', face.dx, face.dy - 40, 20, color: const Color(0xFF6A3FA0), outline: false, alpha: .7);
    }
    if (stopped >= 0) {
      Gfx.text(c, 'OBJETIVO ${num2(target, fixed: true)} s', cx, st + 34, 22, color: Pal.gold);
    }
  }
}

// ───────────────────────── 68. ¿DÓNDE HAY MÁS? (comparar de un vistazo) ─────────────────────────
class MoreCandy extends Channel {
  MoreCandy(super.g);
  @override
  String get name => '¿DÓNDE HAY MÁS?';
  @override
  String get sub => 'El mapache Glotón siempre quiere el plato más lleno';
  @override
  String get ins => '¡TOCA EL QUE TENGA MÁS!';
  @override
  String get hint => 'Toca el plato con más bombones antes de que se acabe el tiempo';
  @override
  String get bg => 'bg_candyshop';
  @override
  double get dur => 30;

  int round = 0, rounds = 3, picked = -1;
  final counts = [0, 0];
  final spots = [<Offset>[], <Offset>[]];
  double roundAt = 0, limit = 2.6, nextAt = -1;
  Offset plate(int i) => Offset(i == 0 ? bx(.27) : bx(.73), foot(.81));
  int get answer => counts[0] > counts[1] ? 0 : 1;

  @override
  void init(int l) {
    limit = math.max(1.6, 2.7 - l * .15);
    _deal();
  }

  void _deal() {
    final diff = [3, 2, 1][round.clamp(0, 2)];
    final lo = 4 + rng.nextInt(4 + round * 2);
    final more = rng.nextInt(2);
    counts[more] = lo + diff;
    counts[1 - more] = lo;
    final grid = <Offset>[];
    for (var row = -2; row <= 2; row++) {
      for (var col = -4; col <= 4; col++) {
        final q = Offset(col * 19.0 + (row.isOdd ? 9.5 : 0), row * 11.0);
        if ((q.dx / 78) * (q.dx / 78) + (q.dy / 28) * (q.dy / 28) <= 1) grid.add(q);
      }
    }
    for (var i = 0; i < 2; i++) {
      final g2 = [...grid]..shuffle(rng);
      final n = counts[i];
      final base = g2.take(math.min(n, g2.length)).toList();
      // los que no caben van encima, formando montoncito
      for (var k = base.length; k < n; k++) {
        base.add(base[k % base.length] + const Offset(4, -13));
      }
      base.sort((a, b) => a.dy.compareTo(b.dy));
      spots[i] = base;
    }
    roundAt = t;
    picked = -1;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (nextAt >= 0) {
      if (t >= nextAt) {
        nextAt = -1;
        round++;
        _deal();
      }
      return;
    }
    if (tap) {
      for (var i = 0; i < 2; i++) {
        final o = plate(i);
        if (Rect.fromCenter(center: o - const Offset(0, 20), width: 210, height: 150).contains(Offset(p.x, p.y))) {
          picked = i;
          if (i == answer) {
            Sfx.play('bonus');
            g.fx.float('¡${counts[i]} > ${counts[1 - i]}!', o.dx, o.dy - 70, Pal.lime, 22);
            if (round + 1 >= rounds) {
              win();
            } else {
              nextAt = t + .55;
            }
          } else {
            Sfx.play('lose');
            lose('¡Había ${counts[1 - i]} contra ${counts[i]}!');
          }
        }
      }
    } else if (t - roundAt > limit) {
      lose('¡Muy lento, el mapache se los comió!');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'raccoon', vt, cx, by(.6), 128, ay: 1);
    for (var i = 0; i < 2; i++) {
      final o = plate(i);
      Gfx.shadow(c, o.dx, o.dy + 10, 220, alpha: .45);
      final rim = Rect.fromCenter(center: o - const Offset(0, 8), width: 200, height: 76);
      c.drawOval(rim, Paint()..shader = Gradient.linear(rim.topLeft, rim.bottomRight, [const Color(0xFFFFFFFF), const Color(0xFFD9D4CC)]));
      c.drawOval(rim.deflate(16), Paint()..color = const Color(0xFFEDE8E0));
      final glow = picked == i;
      for (final q in spots[i]) {
        Gfx.sprite(c, 'bonbon', o.dx + q.dx, o.dy - 12 + q.dy, 27, rot: (q.dx * 7 % 1) - .5);
      }
      if (glow) Gfx.mark(c, i == answer, o.dx, o.dy - 70, 54);
    }
    // tiempo de la ronda
    if (res == 0 && nextAt < 0) {
      final f = 1 - clamp01((t - roundAt) / limit);
      Gfx.clayBar(c, Rect.fromLTWH(cx - 90, st + 26, 180, 14), f, f < .35 ? Pal.pink : Pal.gold);
    }
    for (var k = 0; k < rounds; k++) {
      Gfx.clayBall(c, cx - 24 + k * 24, st + 56, 7, k < round || (k == round && res == 1) ? Pal.lime : const Color(0x88FFFFFF));
    }
  }
}

// ───────────────────────── 69. LA CAJERA DEL SÚPER (dar el cambio) ─────────────────────────
class Cashier extends Channel {
  Cashier(super.g);
  @override
  String get name => 'LA CAJERA DEL SÚPER';
  @override
  String get sub => 'La perezosa Lola tarda tanto que hay cola';
  @override
  String get ins => '¡DA EL CAMBIO JUSTO!';
  @override
  String get hint => 'Toca el montón de monedas que suma el cambio';
  @override
  String get bg => 'bg_checkout';
  @override
  double get dur => 8;

  double price = 0, paid = 10;
  final piles = <List<double>>[];
  int good = 0, picked = -1;
  double get change => paid - price;
  Offset pileAt(int i) => Offset(bx(.2 + i * .3), foot(.84));

  @override
  void init(int l) {
    final halves = l >= 2;
    paid = l >= 3 && rng.nextBool() ? 20 : 10;
    final ch = halves ? (rng.nextInt(12) + 3) / 2 : (rng.nextInt(6) + 2).toDouble();
    price = paid - ch;
    final sums = <double>{ch};
    final step = halves ? .5 : 1.0;
    while (sums.length < 3) {
      final s = ch + (rng.nextBool() ? 1 : -1) * step * (1 + rng.nextInt(2));
      if (s > 0) sums.add(s);
    }
    final list = sums.toList()..shuffle(rng);
    good = list.indexOf(ch);
    for (final s in list) {
      piles.add(_coins(s, halves));
    }
  }

  List<double> _coins(double s, bool halves) {
    final out = <double>[];
    var left = s;
    while (left > .001) {
      final opts = [2.0, 1.0, if (halves) .5].where((v) => v <= left + .001).toList();
      final v = opts.length > 1 && rng.nextDouble() < .35 ? opts[1] : opts[0];
      out.add(v);
      left -= v;
    }
    return out..shuffle(rng);
  }

  @override
  void update(double dt) {
    if (res != 0 || !tap) return;
    for (var i = 0; i < 3; i++) {
      if ((Offset(p.x, p.y) - pileAt(i) + const Offset(0, 24)).distance < 66) {
        picked = i;
        final sum = piles[i].fold(0.0, (a, b) => a + b);
        if (i == good) {
          win();
          Sfx.play('bonus');
        } else {
          Sfx.play('lose');
          lose('¡Ese montón suma ${euros(sum)}!');
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'sloth', vt * .6, bx(.24), foot(.66), 150, ay: 1, fps: 10);
    // ticket de la compra
    final card = Rect.fromLTWH(cx - 10, st + 30, 196, 110);
    Gfx.clayPanel(c, card, const Color(0xFFF7F1E3), radius: 14);
    final safe = Gfx.panelSafe(card, const Color(0xFFF7F1E3));
    Gfx.textIn(c, 'CUESTA ${euros(price)}', Rect.fromLTWH(safe.left, safe.top, safe.width, safe.height / 2), 22,
        color: const Color(0xFF6A3FA0));
    Gfx.textIn(c, 'PAGA ${euros(paid)}', Rect.fromLTWH(safe.left, safe.center.dy, safe.width, safe.height / 2), 22,
        color: const Color(0xFF2E8B57));
    Gfx.sprite(c, 'banknote', card.right - 6, card.bottom + 6, 40, rot: .2);
    for (var i = 0; i < 3; i++) {
      final o = pileAt(i);
      final coins = piles[i];
      Gfx.shadow(c, o.dx, o.dy + 12, 120, alpha: .35);
      for (var k = 0; k < coins.length; k++) {
        final v = coins[k];
        final q = o + Offset((k % 3 - 1) * 34.0, -(k ~/ 3) * 30.0 - (k % 3 == 1 ? 6 : 0));
        final s = v == 2 ? 44.0 : (v == 1 ? 40.0 : 34.0);
        Gfx.sprite(c, 'coin', q.dx, q.dy, s, tint: v == .5 ? const Color(0xFFE8A070) : null, drop: const Offset(2, 3));
        Gfx.clayBall(c, q.dx, q.dy, s * .26, v == .5 ? const Color(0xFFB86A3A) : const Color(0xFFB8860B));
        Gfx.text(c, v == .5 ? '50' : '${v.toInt()}', q.dx, q.dy, v == .5 ? 13 : 17, color: Pal.ink);
      }
      if (picked == i) Gfx.mark(c, i == good, o.dx, o.dy - 90, 52);
    }
    Gfx.text(c, '¿CUÁL ES EL CAMBIO?', cx, by(.66), 20, color: Pal.gold);
  }
}

// ───────────────────────── 70. ESCRIBE LA PALABRA (deletrear) ─────────────────────────
class SpellWord extends Channel {
  SpellWord(super.g);
  @override
  String get name => 'ESCRIBE LA PALABRA';
  @override
  String get sub => 'El loro profesor dicta y no repite';
  @override
  String get ins => '¡ESCRÍBELA!';
  @override
  String get hint => 'Toca las letras en orden para escribir lo que sale en la pizarra';
  @override
  String get bg => 'bg_classroom';
  @override
  double get dur => 6 + word.length * 1.1;

  static const words = {
    'cat': 'GATO', 'an_duck': 'PATO', 'boot': 'BOTA', 'battery': 'PILA', 'fish': 'PEZ', 'net': 'RED',
    'pizza': 'PIZZA', 'cheese': 'QUESO', 'cake': 'TARTA', 'key': 'LLAVE', 'egg': 'HUEVO', 'tire': 'RUEDA',
  };
  String pic = 'cat', word = 'GATO';
  final letters = <String>[];
  final pos = <Offset>[], home = <Offset>[];
  final used = <bool>[];
  final slotOf = <int>[];
  int idx = 0, wrong = -1;
  Offset slot(int k) => Offset(cx + (k - (word.length - 1) / 2) * 46, by(.37));

  @override
  void init(int l) {
    final pool = words.entries.where((e) => l >= 2 || e.value.length <= 4).toList();
    final e = pick(pool);
    pic = e.key;
    word = e.value;
    letters.addAll(word.split(''));
    final decoys = l >= 3 ? 2 : (l >= 1 ? 1 : 0);
    for (var i = 0; i < decoys; i++) {
      letters.add(pick('BCDFMNRST'.split('').where((ch) => !word.contains(ch)).toList()));
    }
    letters.shuffle(rng);
    final n = letters.length;
    final perRow = n <= 5 ? n : (n + 1) ~/ 2;
    for (var i = 0; i < n; i++) {
      final row = i ~/ perRow, col = i % perRow;
      final inRow = row == 0 ? perRow : n - perRow;
      final o = Offset(cx + (col - (inRow - 1) / 2) * 66, foot(.78) + row * 64);
      home.add(o);
      pos.add(o);
      used.add(false);
      slotOf.add(-1);
    }
  }

  int? botPick() {
    if (idx >= word.length) return null;
    for (var i = 0; i < letters.length; i++) {
      if (!used[i] && letters[i] == word[idx]) return i;
    }
    return null;
  }

  @override
  void update(double dt) {
    for (var i = 0; i < letters.length; i++) {
      final target = slotOf[i] >= 0 ? slot(slotOf[i]) : home[i];
      pos[i] = Offset.lerp(pos[i], target, 1 - math.exp(-dt * 14))!;
    }
    if (res != 0 || !tap) return;
    for (var i = 0; i < letters.length; i++) {
      if (used[i]) continue;
      if (Rect.fromCenter(center: home[i], width: 60, height: 60).contains(Offset(p.x, p.y))) {
        if (letters[i] == word[idx]) {
          used[i] = true;
          slotOf[i] = idx;
          idx++;
          Sfx.play('note${idx % 4}');
          if (idx == word.length) {
            win();
            Sfx.play('bonus');
          }
        } else {
          wrong = i;
          Sfx.play('eh');
          lose('¡Ahí no va la ${letters[i]}!');
        }
        return;
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.anim(c, 'parrot', vt, bx(.11), foot(.69), 118, ay: 1);
    Gfx.sprite(c, pic, cx, by(.24), 74, rot: math.sin(vt * 2) * .04);
    for (var k = 0; k < word.length; k++) {
      final o = slot(k);
      c.drawLine(o + const Offset(-17, 22), o + const Offset(17, 22), Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xCCFFFFFF));
    }
    for (var i = 0; i < letters.length; i++) {
      final o = pos[i];
      final s = slotOf[i] >= 0 ? 44.0 : 58.0;
      final shake = wrong == i ? math.sin(vt * 40) * 4 : 0.0;
      Gfx.sprite(c, 'letter_cube', o.dx + shake, o.dy, s, drop: const Offset(3, 5));
      Gfx.text(c, letters[i], o.dx + shake, o.dy + s * .06, s * .5,
          color: wrong == i ? Pal.tomato : const Color(0xFF5A3418), outline: false);
    }
  }
}

// ───────────────────────── 71. COLOREA POR NÚMEROS ─────────────────────────
class PaintRegion {
  final Path path;
  final int n;
  final Offset label;
  int painted = -1;
  PaintRegion(this.path, this.n, this.label);
}

class PaintNumbers extends Channel {
  PaintNumbers(super.g);
  @override
  String get name => 'COLOREA POR NÚMEROS';
  @override
  String get sub => 'El cerdito pintor inaugura su exposición';
  @override
  String get ins => '¡PINTA CADA NÚMERO!';
  @override
  String get hint => 'Elige un bote y toca las zonas que llevan su número';
  @override
  String get bg => 'bg_studio';
  @override
  double get dur => 12;

  static const colors = [Color(0xFFE0473A), Color(0xFF3E7BD8), Color(0xFFF2C230)];
  final regions = <PaintRegion>[];
  int sel = -1;
  Rect get cv => Rect.fromLTRB(bx(.31), by(.25), bx(.73), by(.6));
  Offset potAt(int i) => Offset(bx(.4 + i * .19), foot(.92));

  Offset _u(double x, double y) => Offset(cv.left + x * cv.width, cv.top + y * cv.height);
  Path _rect(double l, double t, double r, double b) => Path()..addRect(Rect.fromPoints(_u(l, t), _u(r, b)));
  Path _poly(List<double> xy) {
    final p = Path()..moveTo(_u(xy[0], xy[1]).dx, _u(xy[0], xy[1]).dy);
    for (var i = 2; i < xy.length; i += 2) {
      final q = _u(xy[i], xy[i + 1]);
      p.lineTo(q.dx, q.dy);
    }
    return p..close();
  }

  Path _circle(double x, double y, double r) => Path()..addOval(Rect.fromCircle(center: _u(x, y), radius: r * cv.width));

  @override
  void init(int l) {
    final which = rng.nextInt(3);
    final shapes = <(Path, Offset)>[];
    switch (which) {
      case 0: // casa
        shapes.addAll([
          (_rect(.2, .47, .8, .92), _u(.3, .7)),
          (_poly([.1, .49, .5, .14, .9, .49]), _u(.5, .36)),
          (_rect(.42, .64, .58, .92), _u(.5, .79)),
          (_circle(.14, .15, .09), _u(.14, .15)),
        ]);
      case 1: // barco
        shapes.addAll([
          (_rect(0, .76, 1, 1), _u(.15, .89)),
          (_poly([.12, .6, .88, .6, .72, .82, .28, .82]), _u(.5, .7)),
          (_poly([.52, .08, .52, .56, .86, .56]), _u(.63, .43)),
          (_circle(.2, .2, .1), _u(.2, .2)),
        ]);
      default: // árbol
        shapes.addAll([
          (_rect(0, .82, 1, 1), _u(.18, .91)),
          (_rect(.43, .5, .57, .86), _u(.5, .7)),
          (_circle(.5, .34, .25), _u(.5, .3)),
          (_circle(.86, .13, .08), _u(.86, .13)),
        ]);
    }
    final nums = [0, 1, 2, rng.nextInt(3)]..shuffle(rng);
    for (var i = 0; i < shapes.length; i++) {
      regions.add(PaintRegion(shapes[i].$1, nums[i], shapes[i].$2));
    }
    if (l >= 3) sel = -1;
  }

  /// Bot: [bote, zona] siguiente.
  (int, int)? botNext() {
    for (var i = 0; i < regions.length; i++) {
      if (regions[i].painted < 0) return (regions[i].n, i);
    }
    return null;
  }

  int? _hit(Offset q) {
    for (var i = regions.length - 1; i >= 0; i--) {
      if (regions[i].path.contains(q)) return i;
    }
    return null;
  }

  @override
  void update(double dt) {
    if (res != 0 || !tap) return;
    final q = Offset(p.x, p.y);
    for (var i = 0; i < 3; i++) {
      if ((q - potAt(i) + const Offset(0, 20)).distance < 42) {
        sel = i;
        Sfx.play('squish', volume: .7);
        return;
      }
    }
    final r = _hit(q);
    if (r == null) return;
    final reg = regions[r];
    if (reg.painted >= 0) return;
    if (sel < 0) {
      g.fx.float('¡ELIGE UN BOTE!', q.dx, q.dy - 30, Pal.gold, 20);
      return;
    }
    reg.painted = sel;
    if (sel != reg.n) {
      Sfx.play('splat');
      lose('¡Ahí iba el ${reg.n + 1}!');
      return;
    }
    Sfx.play('pop');
    if (regions.every((e) => e.painted >= 0)) {
      win();
      Sfx.play('bonus');
      g.fx.burst(cv.center.dx, cv.center.dy, Pal.gold, 20);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xFF4A3A5A);
    for (final r in regions) {
      if (r.painted >= 0) {
        final col = colors[r.painted];
        c.drawPath(r.path, Paint()
          ..shader = Gradient.linear(cv.topLeft, cv.bottomRight,
              [HSLColor.fromColor(col).withLightness(.68).toColor(), col], [0, 1]));
      } else {
        c.drawPath(r.path, Paint()..color = const Color(0xFFFBF7EE));
      }
      c.drawPath(r.path, ink);
    }
    for (final r in regions) {
      if (r.painted < 0) Gfx.text(c, '${r.n + 1}', r.label.dx, r.label.dy, 22, color: const Color(0xFF4A3A5A), outline: false);
    }
    Gfx.anim(c, 'pig', vt, bx(.14), foot(.97), 118, ay: 1);
    for (var i = 0; i < 3; i++) {
      final o = potAt(i);
      final up = sel == i ? -10.0 : 0.0;
      if (sel == i) Gfx.shadow(c, o.dx, o.dy, 80, alpha: .6);
      Gfx.sprite(c, 'paint_pot', o.dx, o.dy + up, 62, ay: 1, tint: colors[i], drop: const Offset(3, 4));
      Gfx.text(c, '${i + 1}', o.dx, o.dy - 26 + up, 24, color: Pal.ink);
    }
    if (res == 0 && sel < 0 && t < 2.4) fingerAt(c, potAt(0) + Offset(0, -30 + math.sin(vt * 9) * 4));
  }
}

// ───────────────────────── 72. FUEGOS ARTIFICIALES (tocar en lo más alto) ─────────────────────────
class FwRocket {
  double x, y, vy;
  final Color col;
  bool done = false;
  FwRocket(this.x, this.y, this.vy, this.col);
}

class _Spark {
  double x, y, vx, vy, life;
  final Color col;
  _Spark(this.x, this.y, this.vx, this.vy, this.life, this.col);
}

class Fireworks extends Channel {
  Fireworks(super.g);
  @override
  String get name => 'FUEGOS ARTIFICIALES';
  @override
  String get sub => 'Fiesta mayor en el pueblo de plastilina';
  @override
  String get ins => '¡TOCA EN LO MÁS ALTO!';
  @override
  String get hint => 'Toca cada cohete justo cuando se para arriba del todo';
  @override
  String get bg => 'bg_plaza';
  @override
  double get dur => 11;

  static const gravity = 520.0, window = 115.0;
  static const palette = [Color(0xFFFF5C7A), Color(0xFF53D8C3), Color(0xFFFFB23E), Color(0xFFB98CFF), Color(0xFFB8E04A)];
  final rockets = <FwRocket>[];
  final sparks = <_Spark>[];
  int good = 0, miss = 0, need = 4, level = 0;
  double nextAt = .5;
  bool glow = true;
  double get launchY => by(.84);

  @override
  void init(int l) {
    level = l;
    glow = l < 2;
    need = l >= 3 ? 5 : 4;
  }

  FwRocket? botTarget() {
    for (final r in rockets) {
      if (!r.done && r.vy.abs() < 70) return r;
    }
    return null;
  }

  void _boom(FwRocket r) {
    for (var i = 0; i < 30; i++) {
      final a = i / 30 * tau, s = rnd(150, 230);
      sparks.add(_Spark(r.x, r.y, math.cos(a) * s, math.sin(a) * s, rnd(.9, 1.3), i.isEven ? r.col : Pal.ink));
    }
  }

  @override
  void update(double dt) {
    for (final s in sparks) {
      s.vy += 120 * dt;
      s.vx *= 1 - 1.4 * dt;
      s.vy *= 1 - 1.4 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.life -= dt;
    }
    sparks.removeWhere((s) => s.life <= 0);
    for (final r in rockets) {
      r.vy += gravity * dt;
      r.y += r.vy * dt;
    }
    if (res != 0) return;
    final alive = rockets.where((r) => !r.done).length;
    if (t >= nextAt && alive < (level >= 2 ? 3 : 2)) {
      final h = rnd(190, 290);
      rockets.add(FwRocket(rnd(sl + 60, sr - 60), launchY, -math.sqrt(2 * gravity * h), palette[rng.nextInt(palette.length)]));
      nextAt = t + rnd(.8, 1.3) / (1 + level * .08);
      Sfx.play('click', volume: .5);
    }
    if (tap) {
      FwRocket? best;
      for (final r in rockets) {
        if (r.done) continue;
        if ((Offset(p.x, p.y) - Offset(r.x, r.y)).distance < 52) best = r;
      }
      if (best != null) {
        best.done = true;
        if (best.vy.abs() < window) {
          good++;
          _boom(best);
          Sfx.play('boom', volume: .7);
          if (good >= need) win();
        } else {
          miss++;
          g.fx.float('¡PRONTO!', best.x, best.y - 30, Pal.pink, 20);
          Sfx.play('eh');
        }
      }
    }
    for (final r in rockets) {
      if (!r.done && r.vy > 0 && r.y > launchY) {
        r.done = true;
        miss++;
        g.fx.float('¡SE APAGÓ!', r.x, launchY - 40, Pal.pink, 20);
      }
    }
    if (miss >= 2) lose('¡Fuegos fallidos!');
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (final s in sparks) {
      final a = clamp01(s.life);
      c.drawLine(Offset(s.x, s.y), Offset(s.x - s.vx * .06, s.y - s.vy * .06), Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = s.col.withValues(alpha: a * .6));
      Gfx.clayBall(c, s.x, s.y, 4.5 * (.5 + a * .5), s.col);
    }
    for (final r in rockets) {
      if (r.done) continue;
      final top = r.vy.abs() < window;
      if (top && glow) {
        c.drawCircle(Offset(r.x, r.y), 30, Paint()
          ..color = r.col.withValues(alpha: .4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
      }
      if (r.vy < -60) {
        for (var k = 0; k < 3; k++) {
          Gfx.clayBall(c, r.x + rnd(-4, 4), r.y + 34 + k * 9 + rnd(0, 6), 4 - k.toDouble(), Pal.gold);
        }
      }
      Gfx.sprite(c, 'rocket', r.x, r.y, 66, tint: r.col, rot: r.vy > 0 ? clamp01(r.vy / 300) * .6 : 0);
    }
    Gfx.text(c, '$good/$need', sr - 36, st + 34, 26, color: Pal.gold);
    for (var k = 0; k < 2; k++) {
      Gfx.clayBall(c, sl + 30 + k * 22, st + 34, 8, k < miss ? Pal.pink : const Color(0x66FFFFFF));
    }
  }
}
