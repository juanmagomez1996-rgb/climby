import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/painting.dart';

final rng = math.Random();
double rnd(double a, double b) => a + rng.nextDouble() * (b - a);
int rndi(int a, int b) => a + rng.nextInt(b - a + 1);
T pick<T>(List<T> l) => l[rng.nextInt(l.length)];
double clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
double lerp(double a, double b, double t) => a + (b - a) * t;
double dist(double x1, double y1, double x2, double y2) =>
    math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
const tau = math.pi * 2;

/// Paleta compartida (misma que los prototipos).
class Pal {
  static const bg = Color(0xFF1A1424);
  static const panel = Color(0xFF2E2340);
  static const ink = Color(0xFFF2E9D8);
  static const dim = Color(0xFFA99BB8);
  static const gold = Color(0xFFFFB23E);
  static const teal = Color(0xFF53D8C3);
  static const pink = Color(0xFFFF5C7A);
  static const lime = Color(0xFFB8E04A);
  static const tomato = Color(0xFFE0302A);
  static const dark = Color(0xFF120D1A);
}

const kDisplay = 'Bowlby';

/// Proporción alto/ancho de los botones de plastilina y zona plana donde cabe el texto
/// (fracciones medidas sobre btn_gold/teal/pink).
const kButtonAspect = 0.615;
const kButtonFace = Rect.fromLTRB(.17, .22, .83, .76);
const kBody = 'Atkinson';

/// Animaciones en bucle generadas en vídeo (Higgsfield) y convertidas a hojas de sprites.
class AnimInfo {
  final int fw, fh, cols, frames;
  const AnimInfo(this.fw, this.fh, {this.cols = 10, this.frames = 60});
}

const anims = <String, AnimInfo>{
  'host_head': AnimInfo(193, 256),
  'glutton_open': AnimInfo(194, 256),
  'reporter': AnimInfo(159, 256),
  'chef': AnimInfo(141, 256),
  'quizhost': AnimInfo(256, 223),
  'redbutton': AnimInfo(256, 240),
  'weather_sleep': AnimInfo(186, 256),
  'boss': AnimInfo(246, 256),
  'sensei': AnimInfo(215, 256),
  'notary': AnimInfo(222, 256),
  'baker': AnimInfo(233, 256),
  'acrobat': AnimInfo(172, 256),
  'dancer': AnimInfo(196, 256),
  'cow': AnimInfo(256, 227),
  'opponent': AnimInfo(256, 190),
};

const spriteNames = [
  'host_head', 'host_body', 'customer', 'arm', 'reporter', 'tomato', 'splat',
  'chef', 'knife', 'veg_carrot', 'veg_eggplant', 'veg_cucumber', 'veg_radish',
  'finger', 'quizhost', 'chair', 'player', 'rival', 'redbutton', 'soda',
  'eyeball', 'glutton_open', 'glutton_chew', 'burger', 'bug', 'bug_dead',
  'weather_sleep', 'weather_awake', 'boss', 'boss_eye', 'boss_eye_closed',
  'life', 'btn_teal', 'btn_pink', 'btn_gold', 'logo', 'tv', 'room',
  'bg_screw', 'bg_arms', 'bg_gazpacho', 'bg_kitchen', 'bg_quiz', 'bg_chairs',
  'bg_forbidden', 'bg_soda', 'bg_fishing', 'bg_diner', 'bg_bugs', 'bg_weather',
  'bg_boss',
  // canales 13–30
  'sensei_win', 'arrow', 'board', 'slingshot', 'meatball', 'can', 'can_hit',
  'pen', 'singer_red', 'singer_red_sing', 'singer_blue', 'singer_blue_sing',
  'singer_yellow', 'singer_yellow_sing', 'singer_green', 'singer_green_sing',
  'ufo', 'cake', 'cakeplate', 'kid', 'kid_gum', 'bubble', 'cloneA',
  'cloneA_odd', 'cloneB', 'cloneB_odd', 'hole', 'mole', 'mole_hit', 'nigiri',
  'maki', 'chili', 'asteroid', 'pad', 'guest_top', 'guest_cowboy',
  'guest_bald', 'guest_curly', 'key', 'monster', 'monster_clean', 'sponge',
  'mud', 'paddle', 'opponent_lose',
  'bg_dojo', 'bg_fair', 'bg_desk', 'bg_karaoke', 'bg_night', 'bg_bakery',
  'bg_bedroom', 'bg_lab', 'bg_garden', 'bg_sushi', 'bg_circus', 'bg_space',
  'bg_disco', 'bg_club', 'bg_vault', 'bg_bathroom', 'bg_ranch', 'bg_pingpong',
];

class Gfx {
  static final Map<String, ui.Image> img = {};
  static final List<ui.Image> noise = [];

  static Future<void> load(Images images) async {
    await Future.wait([
      for (final n in spriteNames)
        images.load('$n.webp').then((i) => img[n] = i),
      for (final n in anims.keys)
        images.load('anim_$n.webp').then((i) => img['anim_$n'] = i),
    ]);
    for (var k = 0; k < 3; k++) {
      noise.add(await images.load('noise$k.png'));
    }
  }

  static final Paint _p = Paint()..filterQuality = FilterQuality.medium;

  /// Dibuja un sprite con altura [h] (el ancho sale del aspecto) y ancla en fracciones.
  static void sprite(Canvas c, String name, double x, double y, double h,
      {double rot = 0,
      double sx = 1,
      double sy = 1,
      double alpha = 1,
      bool flip = false,
      double ax = .5,
      double ay = .5,
      Rect? src}) {
    final im = img[name]!;
    final s = src ?? Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
    _draw(c, im, s, x, y, h, rot, sx, sy, alpha, flip, ax, ay);
  }

  /// Frame de una animación a 12 fps.
  static void anim(Canvas c, String name, double t, double x, double y, double h,
      {double rot = 0,
      double sx = 1,
      double sy = 1,
      double alpha = 1,
      bool flip = false,
      double ax = .5,
      double ay = .5,
      double fps = 12}) {
    final a = anims[name]!;
    final f = (t * fps).floor() % a.frames;
    final src = Rect.fromLTWH((f % a.cols) * a.fw.toDouble(),
        (f ~/ a.cols) * a.fh.toDouble(), a.fw.toDouble(), a.fh.toDouble());
    _draw(c, img['anim_$name']!, src, x, y, h, rot, sx, sy, alpha, flip, ax, ay);
  }

  static void _draw(Canvas c, ui.Image im, Rect src, double x, double y,
      double h, double rot, double sx, double sy, double alpha, bool flip,
      double ax, double ay) {
    final w = h * src.width / src.height;
    c.save();
    c.translate(x, y);
    if (rot != 0) c.rotate(rot);
    c.scale(flip ? -sx : sx, sy);
    _p.color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1));
    c.drawImageRect(im, src, Rect.fromLTWH(-w * ax, -h * ay, w, h), _p);
    c.restore();
  }

  /// Cubre el rectángulo con la imagen (recorte centrado).
  static void cover(Canvas c, String name, Rect r, {double zoom = 1, Offset pan = Offset.zero}) {
    final im = img[name]!;
    final iw = im.width.toDouble(), ih = im.height.toDouble();
    final s = math.max(r.width / iw, r.height / ih) * zoom;
    final w = r.width / s, h = r.height / s;
    final src = Rect.fromLTWH((iw - w) / 2 + pan.dx, (ih - h) / 2 + pan.dy, w, h);
    c.drawImageRect(im, src, r, _p..color = const Color(0xFFFFFFFF));
  }

  static double aspect(String name) {
    final a = anims[name];
    if (a != null) return a.fw / a.fh;
    final im = img[name];
    return im == null ? 1 : im.width / im.height;
  }

  // ---------- Texto ----------
  static final Map<String, (TextPainter, TextPainter?)> _tc = {};

  static (TextPainter, TextPainter?) _painters(String s, double size, Color col,
      String font, double? maxW, bool outline, TextAlign align) {
    final key = '$s|$size|${col.toARGB32()}|$font|$maxW|$outline|$align';
    final hit = _tc[key];
    if (hit != null) return hit;
    if (_tc.length > 400) _tc.clear();
    TextPainter mk(Paint? fg, Color? color) {
      final tp = TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: font,
            fontSize: size,
            height: 1.1,
            color: fg == null ? color : null,
            foreground: fg,
          ),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxW ?? double.infinity);
      return tp;
    }

    final fill = mk(null, col);
    final stroke = outline
        ? mk(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = size * 0.16
              ..strokeJoin = StrokeJoin.round
              ..color = Pal.dark,
            null)
        : null;
    return _tc[key] = (fill, stroke);
  }

  /// Texto con contorno oscuro. [align]: 0 izq, .5 centro, 1 der. y = centro vertical.
  static void text(Canvas c, String s, double x, double y, double size,
      {Color color = Pal.ink,
      String font = kDisplay,
      double align = .5,
      double? maxW,
      bool outline = true,
      double scale = 1,
      double rot = 0,
      double alpha = 1,
      double? fitW,
      double? fitH}) {
    final ta = align == .5
        ? TextAlign.center
        : (align < .5 ? TextAlign.left : TextAlign.right);
    final (fill, stroke) = _painters(s, size, color, font, maxW, outline, ta);
    final w = fill.width, h = fill.height;
    // Encoge (nunca agranda) para que quepa en fitW x fitH.
    var k = scale;
    if (fitW != null && w * k > fitW) k = fitW / w;
    if (fitH != null && h * k > fitH) k = fitH / h;
    c.save();
    c.translate(x, y);
    if (rot != 0) c.rotate(rot);
    if (k != 1) c.scale(k);
    final o = Offset(-w * align, -h / 2);
    if (alpha < 1) {
      c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha.clamp(0, 1)));
    }
    if (stroke != null) {
      stroke.paint(c, o + const Offset(0, 2));
      stroke.paint(c, o);
    }
    fill.paint(c, o);
    if (alpha < 1) c.restore();
    c.restore();
  }

  // ---------- Formas de plastilina ----------
  /// Sombra de contacto bajo un personaje apoyado en el suelo.
  static void shadow(Canvas c, double x, double y, double w, {double alpha = .35}) {
    final r = Rect.fromCenter(center: Offset(x, y), width: w, height: w * .2);
    c.drawOval(
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(x, y), w / 2,
              [Color.fromRGBO(0, 0, 0, alpha), const Color(0x00000000)], [0, 1])
);
  }

  static void clayBall(Canvas c, double x, double y, double r, Color col) {
    final hsl = HSLColor.fromColor(col);
    final light = hsl.withLightness((hsl.lightness + .22).clamp(0, 1)).toColor();
    final dark = hsl.withLightness((hsl.lightness - .22).clamp(0, 1)).toColor();
    c.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..shader = ui.Gradient.radial(Offset(x - r * .35, y - r * .4), r * 1.5,
              [light, col, dark], [0, .45, 1]));
  }

  /// Barra tipo "churro" de plastilina.
  static void clayBar(Canvas c, Rect r, double f, Color col) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
    c.drawRRect(rr.shift(const Offset(0, 3)), Paint()..color = const Color(0x66000000));
    c.drawRRect(rr, Paint()..color = const Color(0xFF241A33));
    if (f > 0) {
      final fr = Rect.fromLTWH(r.left, r.top, math.max(r.height, r.width * clamp01(f)), r.height);
      final hsl = HSLColor.fromColor(col);
      c.drawRRect(
          RRect.fromRectAndRadius(fr, Radius.circular(r.height / 2)),
          Paint()
            ..shader = ui.Gradient.linear(fr.topLeft, fr.bottomLeft, [
              hsl.withLightness((hsl.lightness + .18).clamp(0, 1)).toColor(),
              col,
              hsl.withLightness((hsl.lightness - .2).clamp(0, 1)).toColor(),
            ], [0, .45, 1]));
    }
    c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Pal.dark);
  }

  /// Botón de plastilina dibujado en el lienzo, con el texto ajustado a su cara plana.
  static void button(Canvas c, String img, String label, Rect r, {double scale = 1, double size = 44}) {
    final h = r.width * kButtonAspect;
    final cy = r.center.dy;
    sprite(c, img, r.center.dx, cy, h * scale);
    final face = Rect.fromLTRB(r.left + r.width * kButtonFace.left, cy - h / 2 + h * kButtonFace.top,
        r.left + r.width * kButtonFace.right, cy - h / 2 + h * kButtonFace.bottom);
    text(c, label, face.center.dx, face.center.dy, size,
        scale: scale, fitW: face.width * scale, fitH: face.height * scale);
  }

  static void clayPanel(Canvas c, Rect r, Color col, {double radius = 18}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawRRect(rr.shift(const Offset(0, 5)), Paint()..color = const Color(0x77000000));
    final hsl = HSLColor.fromColor(col);
    c.drawRRect(
        rr,
        Paint()
          ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, [
            hsl.withLightness((hsl.lightness + .08).clamp(0, 1)).toColor(),
            hsl.withLightness((hsl.lightness - .08).clamp(0, 1)).toColor(),
          ]));
    c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x55000000));
  }

  /// Visto bueno / cruz gruesos de plastilina.
  static void mark(Canvas c, bool ok, double x, double y, double s) {
    final path = Path();
    if (ok) {
      path
        ..moveTo(x - s * .45, y)
        ..lineTo(x - s * .12, y + s * .32)
        ..lineTo(x + s * .5, y - s * .38);
    } else {
      path
        ..moveTo(x - s * .38, y - s * .38)
        ..lineTo(x + s * .38, y + s * .38)
        ..moveTo(x + s * .38, y - s * .38)
        ..lineTo(x - s * .38, y + s * .38);
    }
    Paint st(double w, Color col) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = col;
    c.drawPath(path.shift(const Offset(0, 6)), st(s * .26, const Color(0x88000000)));
    c.drawPath(path, st(s * .26, Pal.dark));
    c.drawPath(path, st(s * .18, ok ? Pal.lime : Pal.pink));
    c.drawPath(path.shift(Offset(-s * .02, -s * .03)),
        st(s * .05, const Color(0x66FFFFFF)));
  }

  static void note(Canvas c, double x, double y, double s, Color col) {
    final p = Paint()..color = col;
    final o = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Pal.dark;
    c.drawRect(Rect.fromLTWH(x + s * .22, y - s * .9, s * .12, s * .9), p);
    c.drawRect(Rect.fromLTWH(x + s * .22, y - s * .9, s * .12, s * .9), o);
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: s * .6, height: s * .45), p);
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: s * .6, height: s * .45), o);
  }
}

/// Movimiento "stop-motion": ruido que cambia a 12 fps, entre -1 y 1.
double boil(double t, [double seed = 0]) {
  final step = (t * 12).floor() + seed * 97;
  final v = math.sin(step * 12.9898 + seed * 78.233) * 43758.5453;
  return (v - v.floorToDouble()) * 2 - 1;
}

// ---------- Partículas de plastilina y textos flotantes ----------
class Blob {
  double x, y, vx, vy, r, life, max;
  Color col;
  Blob(this.x, this.y, this.vx, this.vy, this.r, this.life, this.col) : max = life;
}

class Floater {
  String s;
  double x, y, life, size;
  Color col;
  Floater(this.s, this.x, this.y, this.col, this.size) : life = 1.1;
}

class Fx {
  final blobs = <Blob>[];
  final floats = <Floater>[];
  double shakeAmp = 0, shakeT = 0;

  void burst(double x, double y, Color col, int n, {double speed = 320, double size = 7}) {
    for (var i = 0; i < n; i++) {
      final a = rnd(0, tau), s = rnd(speed * .3, speed);
      blobs.add(Blob(x, y, math.cos(a) * s, math.sin(a) * s - 120,
          rnd(size * .5, size * 1.4), rnd(.5, .95), col));
    }
  }

  void float(String s, double x, double y, Color col, double size) =>
      floats.add(Floater(s, x, y, col, size));

  void shake(double amp, [double t = .25]) {
    shakeAmp = math.max(shakeAmp, amp);
    shakeT = math.max(shakeT, t);
  }

  Offset get shakeOffset => shakeT > 0
      ? Offset(rnd(-shakeAmp, shakeAmp), rnd(-shakeAmp, shakeAmp))
      : Offset.zero;

  void update(double dt) {
    for (final b in blobs) {
      b.vy += 900 * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.vx *= math.pow(.2, dt).toDouble();
      b.life -= dt;
    }
    blobs.removeWhere((b) => b.life <= 0);
    for (final f in floats) {
      f.y -= 60 * dt;
      f.life -= dt;
    }
    floats.removeWhere((f) => f.life <= 0);
    if (shakeT > 0) {
      shakeT -= dt;
      if (shakeT <= 0) shakeAmp = 0;
    }
  }

  void render(Canvas c) {
    for (final b in blobs) {
      Gfx.clayBall(c, b.x, b.y, b.r * clamp01(b.life / b.max * 1.5), b.col);
    }
    for (final f in floats) {
      final k = 1 - f.life / 1.1;
      Gfx.text(c, f.s, f.x, f.y, f.size,
          color: f.col, alpha: clamp01(f.life * 2), scale: 1 + math.max(0, .25 - k) * 1.6);
    }
  }

  void clear() {
    blobs.clear();
    floats.clear();
    shakeAmp = shakeT = 0;
  }
}
