import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

const double kW = 540, kH = 960;
const kInk = Color(0xFF3B2416), kPaper = Color(0xFFFBF1DC), kCream = Color(0xFFFFF8EC), kAccent = Color(0xFFE0673C);
const kStatCols = [Color(0xFFE2574C), Color(0xFFE9B43A), Color(0xFF8CC152), Color(0xFF5D9CEC)];

class SpriteMeta {
  SpriteMeta(Map<String, dynamic> j)
      : frames = j['frames'] as int,
        cols = j['cols'] as int,
        fw = (j['fw'] as num).toDouble(),
        fh = (j['fh'] as num).toDouble(),
        foot = (j['foot'] as num).toDouble(),
        ref = (j['ref'] as num?)?.toDouble(),
        air0 = (j['air0'] as num?)?.toInt() ?? 0,
        air1 = (j['air1'] as num?)?.toInt() ?? 0;
  final int frames, cols, air0, air1;
  final double fw, fh, foot;
  final double? ref;
}

/// Imágenes del juego y utilidades de dibujo sobre el lienzo lógico de 540×960.
class Gfx {
  static final Map<String, ui.Image> img = {};
  static final Map<String, SpriteMeta> meta = {};

  static Future<void> _load(String key, String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      img[key] = (await codec.getNextFrame()).image;
    } catch (_) {}
  }

  static Future<void> load(Iterable<String> items, Iterable<String> bgs, {Iterable<String> events = const []}) async {
    final m = jsonDecode(await rootBundle.loadString('assets/data/chars.json')) as Map<String, dynamic>;
    m.forEach((k, v) => meta[k] = SpriteMeta(v as Map<String, dynamic>));
    await Future.wait([
      for (final k in meta.keys) _load(k, 'assets/chars/$k.webp'),
      for (final k in items) _load(k, 'assets/items/$k.webp'),
      for (final k in bgs) _load(k, 'assets/bg/$k.webp'),
      _load('title', 'assets/bg/title.webp'),
      _load('tomb', 'assets/bg/tomb.webp'),
      for (final e in events) _load('ev_$e', 'assets/ev/$e.webp'),
    ]);
  }

  static final _paint = Paint()..filterQuality = FilterQuality.medium;

  /// Fotograma [frame] del personaje [key], con los pies en ([x], [feet]) y [h] de altura hasta los pies.
  static bool sprite(Canvas c, String key, double frame, double x, double feet, double h,
      {double rot = 0, double sx = 1, double sy = 1, double alpha = 1, ColorFilter? filter}) {
    final im = img[key], m = meta[key];
    if (im == null || m == null) return false;
    final f = ((frame.floor() % m.frames) + m.frames) % m.frames;
    final src = Rect.fromLTWH((f % m.cols) * m.fw, (f ~/ m.cols) * m.fh, m.fw, m.fh);
    final s = m.ref != null ? h / m.ref! : h / (m.fh * m.foot), w = m.fw * s, hh = m.fh * s;
    c.save();
    c.translate(x, feet);
    if (rot != 0) c.rotate(rot);
    c.scale(sx, sy);
    final p = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1))
      ..colorFilter = filter;
    c.drawImageRect(im, src, Rect.fromLTWH(-w / 2, -hh * m.foot, w, hh), p);
    c.restore();
    return true;
  }

  /// Objeto centrado en ([x], [y]) con [h] de alto.
  static void item(Canvas c, String key, double x, double y, double h, {double rot = 0, double alpha = 1, double sx = 1, double sy = 1}) {
    final im = img[key];
    if (im == null) {
      c.drawCircle(Offset(x, y), h / 2, Paint()..color = const Color(0xFFCC3333));
      return;
    }
    final w = im.width * h / im.height;
    c.save();
    c.translate(x, y);
    if (rot != 0) c.rotate(rot);
    c.scale(sx, sy);
    final p = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1));
    c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), Rect.fromLTWH(-w / 2, -h / 2, w, h), p);
    c.restore();
  }

  static void image(Canvas c, String key, Rect dst, {double alpha = 1}) {
    final im = img[key];
    if (im == null) return;
    c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), dst,
        _paint..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1)));
  }

  static void shadow(Canvas c, double x, double y, double w) =>
      c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w * 2, height: w * 0.36), Paint()..color = const Color(0x3828190F));

  static void rrect(Canvas c, Rect r, double rad, {Color? fill, Color? stroke, double lw = 3}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
    if (fill != null) c.drawRRect(rr, Paint()..color = fill);
    if (stroke != null) {
      c.drawRRect(rr, Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = lw);
    }
  }

  static void paperBox(Canvas c, Rect r, {double alpha = 1}) {
    final a = (alpha.clamp(0, 1) * 255).round();
    rrect(c, r.shift(const Offset(3, 6)), 16, fill: kInk.withAlpha((a * 0.35).round()));
    rrect(c, r, 16, fill: kPaper.withAlpha(a), stroke: kInk.withAlpha(a));
  }

  // ---- texto ----
  static final Map<String, TextPainter> _tp = {};
  static TextPainter _painter(String s, double size, Color col, String font, {Color? stroke, double sw = 0, double maxW = 0}) {
    final key = '$s|$size|${col.toARGB32()}|$font|${stroke?.toARGB32()}|$sw|$maxW';
    return _tp.putIfAbsent(key, () {
      if (_tp.length > 400) _tp.clear();
      final style = TextStyle(
        fontFamily: font,
        fontSize: size,
        height: 1.1,
        color: stroke == null ? col : null,
        foreground: stroke == null
            ? null
            : (Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = sw
              ..strokeJoin = StrokeJoin.round
              ..color = stroke),
      );
      final tp = TextPainter(text: TextSpan(text: s, style: style), textAlign: TextAlign.center, textDirection: TextDirection.ltr);
      tp.layout(maxWidth: maxW > 0 ? maxW : double.infinity);
      return tp;
    });
  }

  /// Texto con alineación [align] (-1 izquierda, 0 centro, 1 derecha) centrado verticalmente en [y].
  static void text(Canvas c, String s, double x, double y,
      {double size = 28, Color color = kInk, String font = 'PatrickHand', Color? stroke, double sw = 6, int align = 0, double alpha = 1, double maxW = 0}) {
    if (alpha <= 0.01 || s.isEmpty) return;
    final a = (alpha.clamp(0, 1) * 255).round();
    final fill = _painter(s, size, color.withAlpha(a), font, maxW: maxW);
    final dx = align < 0 ? x : align > 0 ? x - fill.width : x - fill.width / 2, dy = y - fill.height / 2;
    if (stroke != null) _painter(s, size, color, font, stroke: stroke.withAlpha(a), sw: sw, maxW: maxW).paint(c, Offset(dx, dy));
    fill.paint(c, Offset(dx, dy));
  }

  static List<String> wrap(String s, double maxW, double size, {String font = 'PatrickHand'}) {
    final out = <String>[];
    var cur = '';
    for (final w in s.split(' ')) {
      final t = cur.isEmpty ? w : '$cur $w';
      final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(fontFamily: font, fontSize: size)), textDirection: TextDirection.ltr)..layout();
      if (tp.width > maxW && cur.isNotEmpty) {
        out.add(cur);
        cur = w;
      } else {
        cur = t;
      }
    }
    out.add(cur);
    return out;
  }
}

// ---- partículas y textos flotantes ----
final _rng = Random();
double rnd(double a, double b) => a + _rng.nextDouble() * (b - a);

class Particle {
  Particle(this.x, this.y, this.vx, this.vy, this.r, this.life, this.col, this.g, {this.puff = false});
  double x, y, vx, vy, r, life;
  final Color col;
  final double g;
  final bool puff;
}

class Floater {
  Floater(this.s, this.x, this.y, this.col, this.size);
  final String s;
  double x, y, life = 1.2;
  final Color col;
  final double size;
}

class Fx {
  final List<Particle> parts = [];
  final List<Floater> floats = [];
  double shakeT = 0, shakeA = 0;

  void burst(double x, double y, Color col, {int n = 14, double sp = 260, double up = 0}) {
    for (var i = 0; i < n; i++) {
      final a = rnd(0, pi * 2), v = rnd(sp * 0.3, sp);
      parts.add(Particle(x, y, cos(a) * v, sin(a) * v - up, rnd(3, 7), rnd(0.4, 0.9), col, 600));
    }
  }

  void dust(double x, double y, [int n = 4]) {
    for (var i = 0; i < n; i++) {
      parts.add(Particle(x + rnd(-10, 10), y, rnd(-80, -20), rnd(-60, -10), rnd(4, 9), rnd(0.3, 0.6), const Color(0xCCE6D7BE), 0, puff: true));
    }
  }

  void float(String s, double x, double y, Color col, [double size = 30]) => floats.add(Floater(s, x, y, col, size));
  void puff(double x, double y) {
    for (var i = 0; i < 6; i++) {
      parts.add(Particle(x, y, rnd(-40, 40), rnd(-90, -40), rnd(5, 9), rnd(0.4, 0.7), const Color(0xCCDCDCDC), -30, puff: true));
    }
  }
  void shake(double a, double t) {
    shakeA = max(shakeA, a);
    shakeT = max(shakeT, t);
  }

  void update(double dt) {
    for (final p in parts) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += p.g * dt;
      p.life -= dt;
      if (p.puff) p.r += dt * 14;
    }
    parts.removeWhere((p) => p.life <= 0);
    for (final f in floats) {
      f.y -= 55 * dt;
      f.life -= dt * 0.85;
    }
    floats.removeWhere((f) => f.life <= 0);
    if (shakeT > 0) {
      shakeT -= dt;
    } else {
      shakeA = 0;
    }
  }

  void renderParts(Canvas c) {
    for (final p in parts) {
      final a = (p.life / 0.4).clamp(0.0, 1.0);
      c.drawCircle(Offset(p.x, p.y), p.r, Paint()..color = p.col.withValues(alpha: p.col.a * a));
    }
  }

  void renderFloats(Canvas c) {
    for (final f in floats) {
      Gfx.text(c, f.s, f.x, f.y, size: f.size, color: f.col, stroke: kCream, sw: 6, alpha: f.life.clamp(0, 1), font: 'Chewy');
    }
  }
}
