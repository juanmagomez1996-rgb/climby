import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/cache.dart';
import 'package:flutter/painting.dart';

import 'font_data.dart';

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
  'glutton_open': AnimInfo(242, 320, frames: 14),
  'reporter': AnimInfo(159, 256),
  'chef': AnimInfo(141, 256),
  'quizhost': AnimInfo(256, 223),
  'redbutton': AnimInfo(320, 299, frames: 32),
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
  'cloneA_odd', 'cloneB', 'cloneB_odd', 'hole', 'hole_front', 'mole', 'mole_hit', 'nigiri',
  'maki', 'chili', 'asteroid', 'pad', 'guest_top', 'guest_cowboy',
  'guest_bald', 'guest_curly', 'key', 'monster', 'monster_clean', 'sponge',
  'mud', 'tub_front', 'knob', 'paddle', 'opponent_lose',
  'bg_dojo', 'bg_fair', 'bg_desk', 'bg_karaoke', 'bg_night', 'bg_bakery',
  'bg_bedroom', 'bg_lab', 'bg_garden', 'bg_sushi', 'bg_circus', 'bg_space',
  'bg_disco', 'bg_club', 'bg_vault', 'bg_bathroom', 'bg_ranch', 'bg_pingpong',
  // interfaz de plastilina
  'font', 'bar_track', 'bar_gold', 'bar_pink', 'life_off', 'mark_ok', 'mark_no',
  'ico_pause', 'ico_sound', 'ico_mute', 'ico_vibe', 'ico_novibe', 'ico_help',
  'panel_dark', 'panel_cream', 'note', 'hook',
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
      Rect? src,
      Offset? drop}) {
    final im = img[name]!;
    final s = src ?? Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble());
    if (drop != null) _silhouette(c, im, s, x + drop.dx, y + drop.dy, h, rot, sx, sy, flip, ax, ay);
    _draw(c, im, s, x, y, h, rot, sx, sy, alpha, flip, ax, ay);
  }

  /// Solo la sombra con la silueta del sprite (cuando el sprite se dibuja dentro de un lienzo girado).
  static void silhouette(Canvas c, String name, double x, double y, double h, {double rot = 0, double ax = .5, double ay = .5}) {
    final im = img[name]!;
    _silhouette(c, im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()), x, y, h, rot, 1, 1, false, ax, ay);
  }

  static final Paint _sp = Paint()
    ..filterQuality = FilterQuality.low
    ..colorFilter = const ColorFilter.mode(Color(0x5A000000), BlendMode.srcIn)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

  /// Sombra proyectada con la silueta exacta del sprite (para objetos que flotan o vistos desde arriba).
  static void _silhouette(Canvas c, ui.Image im, Rect src, double x, double y, double h, double rot,
      double sx, double sy, bool flip, double ax, double ay) {
    final w = h * src.width / src.height;
    c.save();
    c.translate(x, y);
    if (rot != 0) c.rotate(rot);
    c.scale(flip ? -sx : sx, sy);
    c.drawImageRect(im, src, Rect.fromLTWH(-w * ax, -h * ay, w, h), _sp);
    c.restore();
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

  // ---------- Texto: fuente de plastilina hecha de sprites ----------
  /// Reloj del temblor de las letras (lo avanza el juego; los overlays pasan el suyo).
  static double time = 0;

  static const _subst = {'…': '...', '·': '-', '×': 'X', 'Ü': 'U', '"': '', '(': '', ')': '', "'": '', '’': ''};

  static String _norm(String s) {
    var u = s.toUpperCase();
    _subst.forEach((k, v) => u = u.replaceAll(k, v));
    return u;
  }

  /// Escala del atlas para un tamaño de letra (la mayúscula mide un 72 % del tamaño; mínimo legible 18).
  static double _k(double size) => math.max(size, 18) * .72 / kFontCap;
  static const _overlap = .12; // las letras se montan un poco, como plastilina pegada

  static double _adv(String ch, double k) {
    if (ch == ' ') return kFontCap * .36 * k;
    final g = kFontGlyphs[ch];
    return ((g?.$3 ?? kFontCap * .5) - kFontCap * _overlap) * k;
  }

  static double _lineW(String line, double k) {
    if (line.isEmpty) return 0;
    var w = 0.0;
    for (final r in line.runes) {
      w += _adv(String.fromCharCode(r), k);
    }
    return w + kFontCap * _overlap * k;
  }

  static List<String> _wrap(String s, double k, double? maxW) {
    final out = <String>[];
    for (final para in s.split('\n')) {
      if (maxW == null) {
        out.add(para);
        continue;
      }
      var cur = '';
      for (final w in para.split(' ')) {
        final t = cur.isEmpty ? w : '$cur $w';
        if (_lineW(t, k) > maxW && cur.isNotEmpty) {
          out.add(cur);
          cur = w;
        } else {
          cur = t;
        }
      }
      out.add(cur);
    }
    return out;
  }

  /// Tamaño que ocupará un texto (sin aplicar fitW/fitH).
  static Size measure(String s, double size, {double? maxW}) {
    final k = _k(size);
    final lines = _wrap(_norm(s), k, maxW);
    final lh = kFontCap * k * 1.45;
    var w = 0.0;
    for (final l in lines) {
      w = math.max(w, _lineW(l, k));
    }
    return Size(w, lines.length * lh);
  }

  /// Texto con letras de plastilina que tiemblan un poco a 12 fps.
  /// [align]: 0 izquierda, .5 centro, 1 derecha. [y] = centro vertical del bloque.
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
      double? fitH,
      double? t}) {
    final atlas = img['font'];
    if (atlas == null) return;
    final str = _norm(s);
    final k = _k(size);
    final lines = _wrap(str, k, maxW);
    final lh = kFontCap * k * 1.45;
    var w = 0.0;
    for (final l in lines) {
      w = math.max(w, _lineW(l, k));
    }
    final h = lines.length * lh;
    var sc = scale;
    // por defecto, nunca más ancho que la pantalla de la tele
    fitW ??= maxW ?? 420;
    if (w * sc > fitW) sc = fitW / w;
    if (fitH != null && h * sc > fitH) sc = math.min(sc, fitH / h);
    final tt = t ?? time;
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, alpha.clamp(0, 1));
    if (color != Pal.ink) paint.colorFilter = ColorFilter.mode(color, BlendMode.modulate);
    c.save();
    c.translate(x, y);
    if (rot != 0) c.rotate(rot);
    if (sc != 1) c.scale(sc);
    final seed0 = (s.hashCode % 97).toDouble();
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lw = _lineW(line, k);
      var gx = -w * align + (w - lw) * align;
      // centro de la mayúscula de esta línea
      final cy = -h / 2 + i * lh + lh / 2;
      final top = cy - (kFontBase - kFontCap / 2) * k;
      var j = 0;
      for (final r in line.runes) {
        final ch = String.fromCharCode(r);
        final g = kFontGlyphs[ch];
        if (g != null) {
          final gw = g.$3 * k, gh = kFontLineH * k;
          final seed = seed0 + i * 31 + j * 7.0;
          final dy = boil(tt, seed) * kFontCap * k * .035;
          final gr = boil(tt, seed + 13) * .045;
          c.save();
          c.translate(gx + gw / 2, top + gh / 2 + dy);
          c.rotate(gr);
          c.drawImageRect(atlas, Rect.fromLTWH(g.$1, g.$2, g.$3, kFontLineH),
              Rect.fromLTWH(-gw / 2, -gh / 2, gw, gh), paint);
          c.restore();
        }
        gx += _adv(ch, k);
        j++;
      }
    }
    c.restore();
  }

  // ---------- Formas de plastilina ----------
  /// Sombra de contacto bajo un personaje apoyado en el suelo.
  static void shadow(Canvas c, double x, double y, double w, {double alpha = .35, double ratio = .2}) {
    final r = Rect.fromCenter(center: Offset(x, y), width: w, height: w * ratio);
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

  /// Dibuja [im] estirado en [dst] conservando los extremos redondeados (3 trozos en horizontal).
  static void _hslice(Canvas c, ui.Image im, Rect dst, Paint p) {
    final iw = im.width.toDouble(), ih = im.height.toDouble();
    final cap = ih * .55;
    final s = dst.height / ih;
    final dc = math.min(cap * s, dst.width / 2);
    final sc = dc / s;
    c.drawImageRect(im, Rect.fromLTWH(0, 0, sc, ih), Rect.fromLTWH(dst.left, dst.top, dc, dst.height), p);
    c.drawImageRect(im, Rect.fromLTWH(sc, 0, iw - 2 * sc, ih),
        Rect.fromLTWH(dst.left + dc, dst.top, math.max(0, dst.width - 2 * dc), dst.height), p);
    c.drawImageRect(im, Rect.fromLTWH(iw - sc, 0, sc, ih), Rect.fromLTWH(dst.right - dc, dst.top, dc, dst.height), p);
  }

  /// Dibuja un sprite estirado en [dst] sin deformar las esquinas (9 trozos); [corner] en fracción del alto de la imagen.
  static void nine(Canvas c, String name, Rect dst, {double corner = .3, Paint? paint}) {
    final im = img[name]!;
    final p = paint ?? _p;
    final iw = im.width.toDouble(), ih = im.height.toDouble();
    final cs = ih * corner;
    final cd = math.min(math.min(dst.width, dst.height) / 2, math.min(cs, dst.height * corner * 1.2));
    final xs = [0.0, cs, iw - cs, iw], ys = [0.0, cs, ih - cs, ih];
    final xd = [dst.left, dst.left + cd, dst.right - cd, dst.right];
    final yd = [dst.top, dst.top + cd, dst.bottom - cd, dst.bottom];
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final d = Rect.fromLTRB(xd[i], yd[j], xd[i + 1], yd[j + 1]);
        if (d.width <= 0 || d.height <= 0) continue;
        c.drawImageRect(im, Rect.fromLTRB(xs[i], ys[j], xs[i + 1], ys[j + 1]), d, p);
      }
    }
  }

  /// Barra de plastilina: carril morado y relleno de "churro" dorado o rosa (o teñido).
  static void clayBar(Canvas c, Rect r, double f, Color col) {
    _hslice(c, img['bar_track']!, r.inflate(r.height * .35), _p..color = const Color(0xFFFFFFFF));
    if (f <= 0) return;
    final fw = math.max(r.height * 1.2, r.width * clamp01(f));
    final pink = col == Pal.pink;
    final p = Paint()..filterQuality = FilterQuality.medium;
    if (!pink && col != Pal.gold) p.colorFilter = ColorFilter.mode(col, BlendMode.modulate);
    _hslice(c, img[pink ? 'bar_pink' : 'bar_gold']!, Rect.fromLTWH(r.left, r.top, fw, r.height), p);
  }

  /// Botón de plastilina dibujado en el lienzo, con el texto ajustado a su cara plana.
  static void button(Canvas c, String img, String label, Rect r, {double scale = 1, double size = 44}) {
    final h = r.width * kButtonAspect;
    final cy = r.center.dy;
    shadow(c, r.center.dx, cy + h * scale * .46, r.width * .85 * scale, alpha: .45, ratio: .16);
    sprite(c, img, r.center.dx, cy, h * scale);
    final face = Rect.fromLTRB(r.left + r.width * kButtonFace.left, cy - h / 2 + h * kButtonFace.top,
        r.left + r.width * kButtonFace.right, cy - h / 2 + h * kButtonFace.bottom);
    textIn(c, label, Rect.fromCenter(center: face.center, width: face.width * scale, height: face.height * scale), size,
        scale: scale);
  }

  /// Zona segura de una placa: dentro del churro del borde y lejos de las esquinas redondeadas.
  /// Medido sobre los sprites (panel_dark 600x320: borde ~35 px de lado y ~28 arriba/abajo,
  /// esquina interior de radio ~40) y escalado igual que lo escala [nine].
  static Rect panelSafe(Rect r, Color col) {
    final light = HSLColor.fromColor(col).lightness > .45;
    final ih = light ? 336.0 : 320.0;
    final cs = ih * .32;
    final cd = math.min(math.min(r.width, r.height) / 2, math.min(cs, r.height * .32 * 1.2));
    final k = cd / cs;
    final hx = (light ? 48.0 : 54.0) * k, vy = (light ? 40.0 : 42.0) * k;
    return Rect.fromLTRB(r.left + hx, r.top + vy, r.right - hx, r.bottom - vy);
  }

  /// Texto centrado dentro de una caja: parte en líneas y se encoge hasta caber entero,
  /// dejando margen para el temblor de las letras (±3,5 % de alto y un poco de giro).
  static void textIn(Canvas c, String s, Rect box, double size,
      {Color color = Pal.ink, double scale = 1, double rot = 0, double alpha = 1}) {
    final w = box.width * .94, h = box.height * .9;
    text(c, s, box.center.dx, box.center.dy, size,
        color: color, maxW: w / scale, fitW: w, fitH: h, scale: scale, rot: rot, alpha: alpha);
  }

  /// Placa de plastilina: morada oscura o crema (teñida con [col] si es clara).
  static void clayPanel(Canvas c, Rect r, Color col, {double radius = 18}) {
    final light = HSLColor.fromColor(col).lightness > .45;
    final p = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, col.a);
    if (light && col.toARGB32() != 0xFFF7F1E3) {
      p.colorFilter = ColorFilter.mode(col.withValues(alpha: 1), BlendMode.modulate);
    }
    nine(c, light ? 'panel_cream' : 'panel_dark', r, corner: .32, paint: p);
  }

  /// Visto bueno / cruz de plastilina.
  static void mark(Canvas c, bool ok, double x, double y, double s) {
    sprite(c, ok ? 'mark_ok' : 'mark_no', x, y, s * .95, rot: boil(time, ok ? 3 : 4) * .04);
  }

  /// Nota musical de plastilina (x,y = cabeza de la nota).
  static void note(Canvas c, double x, double y, double s, Color col) {
    final im = img['note']!;
    final h = s * 1.15, w = h * im.width / im.height;
    final p = Paint()
      ..filterQuality = FilterQuality.medium
      ..colorFilter = ColorFilter.mode(col, BlendMode.modulate);
    c.drawImageRect(im, Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        Rect.fromLTWH(x - w * .35, y - h * .82, w, h), p);
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
      final a = clamp01(f.life * 2);
      // placa oscura detrás: el aviso se lee aunque pase por encima de otros textos del canal
      final sz = Gfx.measure(f.s, f.size, maxW: 340);
      final col = Color.fromRGBO(0x2A, 0x1F, 0x3A, .92 * a);
      final r = Rect.fromCenter(center: Offset(f.x, f.y), width: math.min(sz.width + 48, 400), height: sz.height + 30);
      Gfx.clayPanel(c, r, col, radius: 16);
      Gfx.textIn(c, f.s, Gfx.panelSafe(r, col), f.size,
          color: f.col, alpha: a, scale: 1 + math.max(0, .25 - k) * 1.6);
    }
  }

  void clear() {
    blobs.clear();
    floats.clear();
    shakeAmp = shakeT = 0;
  }
}
