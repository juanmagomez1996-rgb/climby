import 'dart:math';
import 'dart:ui';

import 'audio.dart';
import 'game.dart';
import 'gfx.dart';

const _green = Color(0xFF6C9A3C), _brown = Color(0xFF8C6A4A);

/// Estado de un minijuego en curso.
class Moment {
  Moment(this.id, this.def, this.title, this.hint) : dur = def.dur;
  final String id;
  final MomentDef def;
  String title, hint;
  double t = 0, dur, endT = 0;
  bool done = false, ok = false;
  int got = 0;
  void Function(bool ok)? onEnd;
  // estado libre de cada minijuego
  final Map<String, dynamic> s = {};
  final List<MObj> objs = [];
}

class MObj {
  MObj({this.x = 0, this.y = 0, this.vx = 0, this.vy = 0, this.d = 0});
  double x, y, vx, vy, d, rot = 0, flip = 0;
  bool live = true, up = false, done = false;
  int hit = 0;
  String id = '';
}

/// Definición de un minijuego. [g] es el juego (stats, efectos, sonido, dibujo).
abstract class MomentDef {
  double get dur => 4;
  bool get tilt => false;
  bool get ownRamon => false;
  void start(VidaGame g, Moment m) {}
  void down(VidaGame g, Moment m, double x, double y) {}
  void move(VidaGame g, Moment m, double x, double y) {}
  void up(VidaGame g, Moment m, double x, double y) {}
  void update(VidaGame g, Moment m, double dt) {}
  void result(VidaGame g, Moment m, bool ok) {}
  void draw(VidaGame g, Moment m, Canvas c, double t) {}
}

double _r(double a, double b) => rnd(a, b);
void _win(VidaGame g, String s, List<double>? fx, [double size = 34]) {
  g.fx.float(s, kW / 2, kSY + 170, _green, size);
  if (fx != null) g.L.apply(fx);
  Audio.play('good');
}

void _lose(VidaGame g, String s, List<double>? fx, [Color col = _brown]) {
  g.fx.float(s, kW / 2, kSY + 170, col, 30);
  if (fx != null) g.L.apply(fx);
  Audio.play('bad');
}

void _dim(Canvas c, double a) => c.drawRect(const Rect.fromLTWH(0, kSY, kW, kSB - kSY), Paint()..color = Color.fromRGBO(43, 29, 20, a));
MObj? _hitObj(Moment m, double x, double y, [double r = 60]) =>
    m.objs.where((o) => o.live && m.t >= o.d && (Offset(x, y) - Offset(o.x, o.y)).distance < r).firstOrNull;

class _Pelota extends MomentDef {
  @override
  double get dur => 3.2;
  @override
  void start(g, m) => m.objs.add(MObj(x: kW + 30, y: kSY + 160, vx: -300, vy: -80));
  @override
  void down(g, m, x, y) {
    final o = m.objs[0];
    if (!o.done && (Offset(x, y) - Offset(o.x, o.y)).distance < 80) {
      o.done = true;
      g.fx.burst(o.x, o.y, const Color(0xFFFFD35A), n: 20);
      Audio.play('good');
      g.L.apply([2, 0, 5, 0]);
      g.fx.float('¡La cogiste!', kPX, kGY - 250, _green);
    }
  }

  @override
  void update(g, m, dt) {
    final o = m.objs[0];
    if (!o.done) {
      o.x += o.vx * dt;
      o.vy += 220 * dt;
      o.y += o.vy * dt;
      o.rot -= dt * 6;
      if (o.x < -40 || o.y > kSB) g.endMoment(false);
    } else {
      o.x += (kPX + 34 - o.x) * 0.3;
      o.y += (kGY - g.curH() * 0.55 - o.y) * 0.3;
      if (m.t > m.dur) g.endMoment(true);
    }
  }

  @override
  void result(g, m, ok) {
    if (!ok) {
      g.fx.float('Se te escapa', kPX, kGY - 250, _brown);
      g.L.apply([0, 0, -3, 0]);
    }
  }

  @override
  void draw(g, m, c, t) => Gfx.item(c, 'ball', m.objs[0].x, m.objs[0].y, 64, rot: m.objs[0].rot);
}

class _Lluvia extends MomentDef {
  _Lluvia(this.coin);
  final bool coin;
  @override
  void start(g, m) {
    for (var i = 0; i < (coin ? 5 : 4); i++) {
      m.objs.add(MObj(x: _r(80, kW - 80), y: kSB + 30, vy: coin ? -_r(620, 760) : 0, d: i * (coin ? 0.32 : 0.45)));
    }
  }

  @override
  void down(g, m, x, y) {
    final o = _hitObj(m, x, y);
    if (o == null) return;
    o.live = false;
    m.got++;
    g.fx.burst(o.x, o.y, coin ? kStatCols[1] : kStatCols[0], n: 14);
    Audio.play(coin ? 'pick1' : 'pick3');
    g.L.apply(coin ? [0, 3, 0, 0] : [0, 0, 1, 3]);
  }

  @override
  void move(g, m, x, y) => down(g, m, x, y);
  @override
  void update(g, m, dt) {
    for (final o in m.objs) {
      if (!o.live || m.t < o.d) continue;
      if (coin) {
        o.vy += 900 * dt;
        o.y += o.vy * dt;
        if (o.y > kSB + 40 && o.vy > 0) o.live = false;
      } else {
        o.y -= 200 * dt;
        o.x += sin(m.t * 3 + o.d * 5) * 40 * dt;
        if (o.y < kSY - 30) o.live = false;
      }
    }
    if (m.t > 0.5 && m.objs.every((o) => !o.live)) g.endMoment(m.got == m.objs.length);
  }

  @override
  void result(g, m, ok) {
    if (ok) _win(g, '¡Perfecto!', coin ? [0, 5, 2, 0] : [0, 0, 3, 3], 38);
  }

  @override
  void draw(g, m, c, t) {
    for (final o in m.objs) {
      if (o.live && m.t >= o.d) Gfx.item(c, coin ? 'coin' : 'heart', o.x, o.y, 72, rot: sin(t * 5 + o.d) * 0.2);
    }
  }
}

class _Ritmo extends MomentDef {
  @override
  double get dur => 4.6;
  @override
  void start(g, m) {
    for (var i = 0; i < 4; i++) {
      m.objs.add(MObj(d: 0.7 + i * 0.95));
    }
  }

  @override
  void down(g, m, x, y) {
    final b = m.objs.where((b) => b.hit == 0 && (m.t - b.d).abs() < 0.45).firstOrNull;
    if (b == null) return;
    final dd = (m.t - b.d).abs();
    b.hit = dd < 0.13 ? 2 : dd < 0.25 ? 1 : -1;
    if (b.hit > 0) {
      m.got += b.hit;
      g.fx.burst(kW / 2, kSY + 300, kStatCols[0], n: b.hit * 10);
      Audio.play('pick3');
      g.fx.float(b.hit == 2 ? '¡Perfecto!' : '¡Bien!', kW / 2, kSY + 180, kAccent);
    } else {
      Audio.play('bad');
      g.fx.float('Pisotón', kW / 2, kSY + 180, _brown);
    }
  }

  @override
  void update(g, m, dt) {
    for (final b in m.objs) {
      if (b.hit == 0 && m.t - b.d > 0.45) b.hit = -1;
    }
    if (m.t > m.dur) g.endMoment(m.got >= 6);
  }

  @override
  void result(g, m, ok) {
    if (ok) {
      _win(g, m.title.contains('BATER') ? '¡Qué ritmo!' : '¡Bailas de maravilla!', [0, 0, 6, 8]);
    } else if (m.got <= 2) {
      _lose(g, 'Pisas a todo el mundo', [0, 0, -3, -3]);
    }
  }

  @override
  void draw(g, m, c, t) {
    const cx = kW / 2, cy = kSY + 300;
    Gfx.item(c, 'heart', cx, cy, 90 + sin(t * 10) * 4);
    final next = m.objs.where((b) => b.hit == 0).firstOrNull;
    if (next != null) {
      final k = ((next.d - m.t) / 0.9).clamp(0.0, 1.0);
      c.drawCircle(const Offset(cx, cy), 48 + k * 150, Paint()
        ..color = kAccent.withValues(alpha: 1 - k * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8);
    }
    c.drawCircle(const Offset(cx, cy), 48, Paint()
      ..color = const Color(0xB3FFF8EC)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
    for (var i = 0; i < m.objs.length; i++) {
      final b = m.objs[i];
      Gfx.item(c, 'heart', cx - 75 + i * 50, cy + 130, 32, alpha: b.hit > 0 ? 1 : b.hit < 0 ? 0.2 : 0.45);
    }
  }
}

class _Informe extends MomentDef {
  @override
  double get dur => 3.4;
  bool _run(Moment m) => m.title.contains('MARAT');
  @override
  void down(g, m, x, y) {
    m.got++;
    Audio.play('tap', volume: 0.6);
    g.fx.dust(_r(200, 340), kSY + 420, 2);
    if (m.got >= 16) g.endMoment(true);
  }

  @override
  void update(g, m, dt) {
    if (m.t > m.dur) g.endMoment(false);
  }

  @override
  void result(g, m, ok) {
    final run = _run(m);
    if (ok) {
      _win(g, run ? '¡Maratón terminada!' : '¡Entregado a tiempo!', run ? [10, 0, 5, 0] : [0, 10, -2, 0]);
    } else {
      _lose(g, run ? 'Te retiras en el km 30' : 'Llega tarde. Otra vez.', run ? [-3, 0, -3, 0] : [0, -4, -4, 0]);
    }
  }

  @override
  void draw(g, m, c, t) {
    final run = _run(m);
    for (var i = 0; i < min(m.got, 16); i++) {
      Gfx.item(c, run ? 'trophy' : 'bills', kW / 2 + sin(i * 7.0) * 8, kSY + 470 - i * 9, run ? 44 : 60, rot: sin(i * 3.0) * 0.1);
    }
    Gfx.rrect(c, const Rect.fromLTWH(110, kSY + 520, 320, 26), 12, fill: kCream, stroke: kInk);
    Gfx.rrect(c, Rect.fromLTWH(110, kSY + 520, 320 * m.got / 16, 26), 12, fill: kStatCols[1]);
    Gfx.text(c, '${m.got}/16', kW / 2, kSY + 533, size: 22);
  }
}

class _Equilibrio extends MomentDef {
  _Equilibrio(this.baby);
  final bool baby;
  @override
  double get dur => 3.8;
  @override
  bool get tilt => true;
  @override
  void start(g, m) {
    m.s['x'] = _r(-0.15, 0.15);
    m.s['v'] = 0.0;
    m.s['k'] = g.L.age > 60 ? 1.35 : 1.0;
  }

  @override
  void down(g, m, x, y) => m.s['v'] = (m.s['v'] as double) + (x < kW / 2 ? -1 : 1) * 0.55;
  @override
  void update(g, m, dt) {
    final k = m.s['k'] as double;
    var v = m.s['v'] as double, x = m.s['x'] as double;
    v += (x * 2.4 * k + _r(-2.6, 2.6) * k) * dt;
    v *= 0.985;
    x += v * dt;
    m.s['v'] = v;
    m.s['x'] = x;
    if (x.abs() >= 1) {
      g.endMoment(false);
    } else if (m.t > m.dur) {
      g.endMoment(true);
    }
  }

  @override
  void result(g, m, ok) {
    if (ok) {
      _win(g, baby ? '¡Se ha dormido!' : '¡Equilibrio perfecto!', baby ? [0, 0, 5, 8] : [6, 0, 2, 0]);
    } else {
      _lose(g, baby ? 'Llora aún más fuerte' : '¡Te caes de culo!', null, kStatCols[0]);
      g.L.apply(baby ? [-2, 0, -4, -2] : [-8, 0, -3, 0], cause: 'una caída tonta');
      g.pstumble = 0.7;
    }
  }

  @override
  void draw(g, m, c, t) {
    const y = kSY + 190;
    Gfx.rrect(c, const Rect.fromLTWH(120, y, 300, 20), 10, fill: kCream, stroke: kInk);
    c.drawRect(const Rect.fromLTWH(kW / 2 - 60, y + 3, 120, 14), Paint()..color = const Color(0x998CC152));
    c.drawCircle(Offset(kW / 2 + (m.s['x'] as double) * 150, y + 10), 14, Paint()..color = kAccent);
    Gfx.text(c, '◀', 60, kSY + 400, size: 60, color: const Color(0x99FFF8EC));
    Gfx.text(c, '▶', kW - 60, kSY + 400, size: 60, color: const Color(0x99FFF8EC));
    if (baby) {
      Gfx.item(c, 'rattle', kPX + 70, kGY - g.curH() * 0.6, 50, rot: sin(t * 9) * 0.5);
      Gfx.text(c, 'zZz', kPX + 60, kGY - g.curH() - 20 + sin(t * 3) * 6, size: 30, color: kCream, stroke: kInk, sw: 5);
    }
  }
}

/// Soplar las velas en los cumpleaños redondos: pasa el dedo por las llamas.
class _Velas extends MomentDef {
  @override
  double get dur => 5;
  @override
  void start(g, m) {
    final n = (g.L.age ~/ 10).clamp(1, 9);
    for (var i = 0; i < n; i++) {
      m.objs.add(MObj(x: kW / 2 - (n - 1) * 24 + i * 48.0, y: kSY + 330 + (i % 2) * 14));
    }
    m.title = '¡${g.L.age} AÑOS! SOPLA LAS VELAS';
  }

  @override
  void down(g, m, x, y) {
    final o = m.objs.where((o) => o.live && (x - o.x).abs() < 34 && (y - (o.y - 40)).abs() < 60).firstOrNull;
    if (o == null) return;
    o.live = false;
    m.got++;
    g.fx.puff(o.x, o.y - 44);
    Audio.play('tap');
    if (m.got == m.objs.length) g.endMoment(true);
  }

  @override
  void move(g, m, x, y) => down(g, m, x, y);
  @override
  void update(g, m, dt) {
    if (m.t > m.dur) g.endMoment(false);
  }

  @override
  void result(g, m, ok) {
    if (ok) {
      _win(g, '¡Pide un deseo!', [2, 0, 6, 4], 40);
      g.confetti();
    } else {
      _lose(g, 'Quedan ${m.objs.length - m.got} velas encendidas', [0, 0, -2, 0]);
    }
  }

  @override
  void draw(g, m, c, t) {
    _dim(c, 0.5);
    Gfx.item(c, 'bigcake', kW / 2, kSY + 420, 230);
    for (final o in m.objs) {
      Gfx.item(c, 'candle', o.x, o.y, 70);
      if (o.live) c.drawCircle(Offset(o.x, o.y - 44), 18 * (1 + sin(t * 20 + o.x) * 0.12), Paint()..color = const Color(0x59FFC850));
    }
  }
}

/// Encestar: arrastra la pelota hacia atrás y suelta (tirachinas).
class _Canasta extends MomentDef {
  static const hx = kW - 120, hy = kSY + 250, bx = 120.0, by = kSY + 520;
  @override
  double get dur => 10;
  void _reset(Moment m) {
    final b = m.objs.isEmpty ? MObj() : m.objs[0];
    b
      ..x = bx
      ..y = by
      ..vx = 0
      ..vy = 0
      ..live = false
      ..done = false;
    if (m.objs.isEmpty) m.objs.add(b);
  }

  @override
  void start(g, m) {
    m.s['shots'] = 3;
    _reset(m);
  }

  @override
  void down(g, m, x, y) {
    final b = m.objs[0];
    if (!b.live && (m.s['shots'] as int) > 0 && (Offset(x, y) - Offset(b.x, b.y)).distance < 90) m.s['aim'] = [x, y, x, y];
  }

  @override
  void move(g, m, x, y) {
    final a = m.s['aim'] as List?;
    if (a != null) {
      a[2] = x;
      a[3] = y;
    }
  }

  @override
  void up(g, m, x, y) {
    final a = m.s['aim'] as List?;
    if (a == null) return;
    m.s['aim'] = null;
    final dx = (a[0] as double) - (a[2] as double), dy = (a[1] as double) - (a[3] as double);
    if (sqrt(dx * dx + dy * dy) < 15) return;
    final b = m.objs[0];
    b.vx = (dx * 5.5).clamp(-1000, 1000);
    b.vy = (dy * 5.5).clamp(-1350, 900);
    b.live = true;
    m.s['shots'] = (m.s['shots'] as int) - 1;
    Audio.play('jump');
  }

  @override
  void update(g, m, dt) {
    final b = m.objs[0];
    if (b.live) {
      final py = b.y;
      b.vy += 1100 * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.rot += dt * 8;
      const rx0 = hx + 2, rx1 = hx + 64, ry = hy + 5;
      if (!b.done && b.vy > 0 && py < ry && b.y >= ry && b.x > rx0 && b.x < rx1) {
        b.done = true;
        m.got++;
        g.fx.burst(b.x, ry, const Color(0xFFFFD35A), n: 22);
        Audio.play('good');
        g.fx.float('¡Canasta!', hx - 40, hy - 40, _green, 36);
        g.L.apply([1, 0, 3, 1]);
      }
      if (b.y > kSB + 40 || b.x > kW + 40 || b.x < -40) {
        if (!b.done) g.fx.float('Fuera', kW / 2, kSY + 200, _brown);
        _reset(m);
        if ((m.s['shots'] as int) <= 0) g.endMoment(m.got >= 2);
      }
    }
    if (m.t > m.dur && !b.live) g.endMoment(m.got >= 2);
  }

  @override
  void result(g, m, ok) {
    if (ok) {
      _win(g, m.got == 3 ? '¡Tres de tres!' : '¡Buen tiro!', m.got == 3 ? [2, 0, 4, 3] : [0, 0, 2, 1]);
    } else {
      _lose(g, 'Mejor el ajedrez', [0, 0, -2, 0]);
    }
  }

  @override
  void draw(g, m, c, t) {
    _dim(c, 0.4);
    final b = m.objs[0];
    Gfx.item(c, 'hoop', hx, hy, 190);
    final a = m.s['aim'] as List?;
    if (a != null) {
      final vx = ((a[0] as double) - (a[2] as double)) * 5.5, vy = ((a[1] as double) - (a[3] as double)) * 5.5;
      for (var i = 1; i < 9; i++) {
        final tt = i * 0.07;
        c.drawCircle(Offset(b.x + vx * tt, b.y + vy * tt + 550 * tt * tt), 5, Paint()..color = const Color(0xCCFFF8EC));
      }
    }
    Gfx.item(c, 'basketball', b.x, b.y, 58, rot: b.rot);
    for (var i = 0; i < (m.s['shots'] as int); i++) {
      Gfx.item(c, 'basketball', 40 + i * 34.0, kSY + 600, 28);
    }
  }
}

/// Atrapar el ramo en la boda: arrastra a Ramón a izquierda y derecha.
class _Ramo extends MomentDef {
  @override
  double get dur => 6;
  @override
  bool get ownRamon => true;
  @override
  void start(g, m) {
    m.s['rx'] = kW / 2;
    m.s['fr'] = 0.0;
    m.objs.add(MObj(x: _r(120, kW - 120), y: kSY - 20, d: _r(0, 6)));
  }

  @override
  void down(g, m, x, y) => m.s['tx'] = x;
  @override
  void move(g, m, x, y) => m.s['tx'] = x;
  @override
  void update(g, m, dt) {
    var rx = m.s['rx'] as double;
    final tx = m.s['tx'] as double?;
    if (tx != null) {
      final d = tx - rx;
      rx += d.clamp(-520 * dt, 520 * dt);
      if (d.abs() > 4) m.s['fr'] = (m.s['fr'] as double) + dt * 14;
      m.s['rx'] = rx;
    }
    final o = m.objs[0];
    o.y += 150 * dt;
    o.x = (o.x + sin(m.t * 2.2 + o.d) * 120 * dt).clamp(40, kW - 40);
    o.rot = sin(m.t * 3) * 0.4;
    if (!o.done && o.y > kGY - g.curH() * 0.95 && (o.x - rx).abs() < 60) {
      o.done = true;
      g.fx.burst(o.x, o.y, const Color(0xFFFFB3C6), n: 26);
      g.endMoment(true);
    }
    if (o.y > kGY + 10) g.endMoment(false);
  }

  @override
  void result(g, m, ok) {
    if (ok) {
      _win(g, '¡El ramo es tuyo!', [0, 0, 6, 8]);
      g.confetti();
    } else {
      _lose(g, 'El ramo se lo lleva tu cuñado', [0, 0, -2, 0]);
    }
  }

  @override
  void draw(g, m, c, t) {
    final rx = m.s['rx'] as double;
    Gfx.shadow(c, rx, kGY + 2, 32);
    Gfx.sprite(c, g.spriteKey(), m.s['fr'] as double, rx, kGY, g.curH());
    final o = m.objs[0];
    if (!o.done) Gfx.item(c, 'bouquet', o.x, o.y, 80, rot: o.rot);
  }
}

/// Examen práctico: mantén pulsado para acelerar y suelta para frenar entre los conos.
class _Aparcar extends MomentDef {
  static const z0 = 350.0, z1 = 450.0;
  @override
  double get dur => 8;
  @override
  void start(g, m) {
    m.s['cx'] = 70.0;
    m.s['v'] = 0.0;
    m.s['hold'] = false;
    m.s['moved'] = false;
  }

  @override
  void down(g, m, x, y) => m.s['hold'] = true;
  @override
  void up(g, m, x, y) => m.s['hold'] = false;
  @override
  void update(g, m, dt) {
    var v = m.s['v'] as double, cx = m.s['cx'] as double;
    final hold = m.s['hold'] as bool;
    if (hold) {
      v += 420 * dt;
      m.s['moved'] = true;
    } else {
      v = max(0, v - 300 * dt);
    }
    v = min(v, 420);
    cx += v * dt;
    m.s['v'] = v;
    m.s['cx'] = cx;
    if (cx > z1 + 45) {
      g.fx.shake(10, 0.3);
      Audio.play('hit');
      g.endMoment(false);
      return;
    }
    if (m.s['moved'] == true && !hold && v == 0) g.endMoment(cx > z0 && cx < z1);
    if (m.t > m.dur) g.endMoment(false);
  }

  @override
  void result(g, m, ok) {
    if (ok) {
      _win(g, '¡Aparcado perfecto!', null, 36);
    } else {
      _lose(g, (m.s['cx'] as double) > z1 ? '¡Te comes el cono!' : 'Te quedas a medias', null, kStatCols[0]);
    }
  }

  @override
  void draw(g, m, c, t) {
    const y = kSY + 470;
    _dim(c, 0.45);
    c.drawRect(const Rect.fromLTWH(0, y + 10, kW, 90), Paint()..color = const Color(0xFF5B5B66));
    for (var x = 0.0; x < kW; x += 60) {
      c.drawRect(Rect.fromLTWH(x, y + 55, 34, 5), Paint()..color = const Color(0xFFF6F0DC));
    }
    c.drawRect(const Rect.fromLTWH(z0, y + 14, z1 - z0, 82), Paint()..color = const Color(0x738CC152));
    Gfx.item(c, 'cone', z0 - 20, y + 20, 56);
    Gfx.item(c, 'cone', z1 + 20, y + 20, 56);
    final v = m.s['v'] as double;
    Gfx.item(c, 'car', m.s['cx'] as double, y + 8 + (v > 0 ? sin(t * 40) * 1.5 : 0), 90);
    if (!m.done) {
      Gfx.text(c, m.s['hold'] == true ? 'Acelerando…' : 'Mantén pulsado para acelerar', kW / 2, y + 150, size: 26, color: kCream, stroke: kInk, sw: 5);
    }
  }
}

/// Pesca de jubilado: espera a que el corcho se hunda y toca en ese momento.
class _Pesca extends MomentDef {
  @override
  double get dur => 13;
  void _next(Moment m) {
    m.s['wait'] = _r(1.2, 3.2);
    m.s['bite'] = 0.0;
  }

  @override
  void start(g, m) {
    m.s['tries'] = 3;
    _next(m);
  }

  void _try(VidaGame g, Moment m, bool okNow) {
    m.s['tries'] = (m.s['tries'] as int) - 1;
    if ((m.s['tries'] as int) > 0) {
      _next(m);
    } else {
      g.endMoment(okNow || m.got > 0);
    }
  }

  @override
  void down(g, m, x, y) {
    if ((m.s['bite'] as double) > 0) {
      m.got++;
      m.s['bite'] = 0.0;
      Audio.play('good');
      g.fx.burst(kW / 2 + 60, kSY + 430, const Color(0xFFBFE3FF), n: 20);
      g.fx.float('¡Un pez!', kW / 2, kSY + 250, _green, 36);
      g.L.apply([1, 0, 3, 0]);
      m.objs.add(MObj());
      _try(g, m, true);
    } else if ((m.s['wait'] as double) > 0) {
      g.fx.float('¡Muy pronto!', kW / 2, kSY + 250, _brown);
      Audio.play('bad');
      _next(m);
    }
  }

  @override
  void update(g, m, dt) {
    for (final f in m.objs) {
      f.d += dt;
    }
    var bite = m.s['bite'] as double;
    if (bite > 0) {
      bite -= dt;
      m.s['bite'] = bite;
      if (bite <= 0) {
        g.fx.float('Se escapó…', kW / 2, kSY + 250, _brown);
        _try(g, m, false);
      }
    } else {
      final w = (m.s['wait'] as double) - dt;
      m.s['wait'] = w;
      if (w <= 0) {
        m.s['bite'] = 0.75;
        Audio.play('tap');
        g.fx.burst(kW / 2 + 60, kSY + 430, const Color(0xFFBFE3FF), n: 10, sp: 150);
      }
    }
    if (m.t > m.dur) g.endMoment(m.got > 0);
  }

  @override
  void result(g, m, ok) {
    if (ok) {
      _win(g, m.got >= 3 ? '¡Cena para toda la familia!' : '${m.got} ${m.got == 1 ? 'pez' : 'peces'}', [1, 1, 3, 1]);
    } else {
      _lose(g, 'Hoy no pican', [0, 0, -1, 0]);
    }
  }

  @override
  void draw(g, m, c, t) {
    const wy = kSY + 400;
    _dim(c, 0.25);
    c.drawRect(const Rect.fromLTWH(0, wy, kW, kSB - wy),
        Paint()..shader = Gradient.linear(const Offset(0, wy), const Offset(0, kSB), [const Color(0xFF6FA8C8), const Color(0xFF2F5D7C)]));
    final wave = Paint()
      ..color = const Color(0x59FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (var i = 0; i < 6; i++) {
      final p = Path(), yy = wy + 30 + i * 45;
      for (var x = 0.0; x <= kW; x += 20) {
        final py = yy + sin(x / 40 + t * 2 + i) * 4;
        x == 0 ? p.moveTo(x, py) : p.lineTo(x, py);
      }
      c.drawPath(p, wave);
    }
    Gfx.item(c, 'boat', 120, wy + 10, 110);
    final bite = m.s['bite'] as double;
    const bx = kW / 2 + 60;
    final by = wy + 28 + (bite > 0 ? 22 : sin(t * 3) * 4);
    c.drawPath(Path()
      ..moveTo(150, wy - 70)
      ..quadraticBezierTo(bx - 60, wy - 120, bx, by - 20), Paint()
      ..color = const Color(0x9928190F)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    Gfx.item(c, 'bobber', bx, by, 44);
    if (bite > 0) Gfx.text(c, '¡PICA!', bx, by - 60, size: 40, color: kCream, stroke: kInk, sw: 7, font: 'Chewy');
    for (final f in m.objs) {
      if (f.d < 1.2) Gfx.item(c, 'fish', bx - f.d * 60, by - sin(f.d / 1.2 * pi) * 180, 80, rot: -0.6 + f.d);
    }
    for (var i = 0; i < (m.s['tries'] as int); i++) {
      Gfx.item(c, 'bobber', 30 + i * 30.0, kSY + 600, 22);
    }
  }
}

/// Recuerdos: memoria por parejas con las ilustraciones de tu propia vida.
class _Recuerdos extends MomentDef {
  @override
  double get dur => 16;
  @override
  void start(g, m) {
    final lived = g.L.seen.where((id) => Gfx.img.containsKey('ev_$id')).toSet().toList();
    final pool = lived.length >= 3 ? lived : Gfx.img.keys.where((k) => k.startsWith('ev_')).map((k) => k.substring(3)).toList();
    pool.shuffle();
    final three = pool.take(3).toList(), deck = [...three, ...three]..shuffle();
    for (var i = 0; i < deck.length; i++) {
      m.objs.add(MObj(x: 40 + (i % 2) * 235.0, y: kSY + 150 + (i ~/ 2) * 150.0)..id = deck[i]);
    }
    m.s['lock'] = 0.0;
    m.s['open'] = <MObj>[];
  }

  @override
  void down(g, m, x, y) {
    if ((m.s['lock'] as double) > 0) return;
    final c = m.objs.where((c) => !c.up && !c.done && x > c.x && x < c.x + 225 && y > c.y && y < c.y + 135).firstOrNull;
    if (c == null) return;
    c.up = true;
    Audio.play('card');
    final open = m.s['open'] as List<MObj>..add(c);
    if (open.length == 2) {
      if (open[0].id == open[1].id) {
        open[0].done = open[1].done = true;
        m.got++;
        open.clear();
        Audio.play('good');
        g.fx.burst(c.x + 112, c.y + 67, const Color(0xFFFFD35A), n: 18);
        g.L.apply([0, 0, 2, 3]);
        if (m.got == 3) g.endMoment(true);
      } else {
        m.s['lock'] = 0.8;
      }
    }
  }

  @override
  void update(g, m, dt) {
    for (final c in m.objs) {
      c.flip += ((c.up || c.done ? 1 : 0) - c.flip) * min(1, dt * 12);
    }
    var lock = m.s['lock'] as double;
    if (lock > 0) {
      lock -= dt;
      m.s['lock'] = lock;
      if (lock <= 0) {
        for (final c in m.s['open'] as List<MObj>) {
          c.up = false;
        }
        (m.s['open'] as List<MObj>).clear();
      }
    }
    if (m.t > m.dur) g.endMoment(m.got >= 2);
  }

  @override
  void result(g, m, ok) {
    if (ok) {
      _win(g, m.got == 3 ? 'Qué vida más bonita' : 'Casi todo lo recuerdas', [0, 0, 5, 3]);
    } else {
      _lose(g, 'La memoria ya no es lo que era', [0, 0, -2, 0]);
    }
  }

  @override
  void draw(g, m, c, t) {
    _dim(c, 0.55);
    const w = 225.0, h = 135.0;
    for (final k in m.objs) {
      final s = cos(k.flip * pi).abs(), face = k.flip > 0.5;
      c.save();
      c.translate(k.x + w / 2, k.y + h / 2);
      c.scale(max(0.02, s), 1);
      const r = Rect.fromLTWH(-w / 2, -h / 2, w, h);
      Gfx.rrect(c, r.shift(const Offset(3, 5)), 12, fill: const Color(0x4D000000));
      if (face && Gfx.img.containsKey('ev_${k.id}')) {
        c.save();
        c.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(12)));
        Gfx.image(c, 'ev_${k.id}', r);
        c.restore();
        Gfx.rrect(c, r, 12, stroke: k.done ? const Color(0xFF8CC152) : kInk, lw: 4);
      } else {
        Gfx.rrect(c, r, 12, fill: const Color(0xFFF3E2C0), stroke: kInk, lw: 4);
        Gfx.item(c, 'photo', 0, 0, 90, alpha: 0.7);
      }
      c.restore();
    }
  }
}

final Map<String, MomentDef> kMoments = {
  'pelota': _Pelota(),
  'monedas': _Lluvia(true),
  'corazones': _Lluvia(false),
  'ritmo': _Ritmo(),
  'informe': _Informe(),
  'equilibrio': _Equilibrio(false),
  'bebe': _Equilibrio(true),
  'velas': _Velas(),
  'canasta': _Canasta(),
  'ramo': _Ramo(),
  'aparcar': _Aparcar(),
  'pesca': _Pesca(),
  'recuerdos': _Recuerdos(),
};
