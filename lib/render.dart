import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'physics.dart';
import 'holds.dart';
import 'climby_game.dart';
import 'storage.dart';

// =========================================================
//  GameAssets — preload PNGs as ui.Image
// =========================================================
class GameAssets {
  static final Map<String, ui.Image> _cache = {};
  static bool loaded = false;

  static Future<void> loadAll() async {
    if (loaded) return;
    final assets = [
      'assets/character/head_neutral.png',
      'assets/character/head_happy.png',
      'assets/character/head_scared.png',
      'assets/character/head_focused.png',
      'assets/character/head_burning.png',
      'assets/character/head_dead.png',
      'assets/character/torso.png',
      'assets/character/shorts.png',
      'assets/character/arm_upper.png',
      'assets/character/arm_lower.png',
      'assets/character/hand_left.png',
      'assets/character/hand_right.png',
      'assets/character/leg_upper.png',
      'assets/character/leg_lower.png',
      'assets/character/foot_left.png',
      'assets/character/foot_right.png',
      'assets/holds/hold_normal.png',
      'assets/holds/hold_fragile.png',
      'assets/holds/hold_bouncy.png',
      'assets/holds/hold_magnet.png',
      'assets/holds/hold_sticky.png',
      'assets/holds/hold_slippery.png',
      'assets/holds/hold_moving.png',
      'assets/ui/logo_climby.png',
      'assets/ui/trophy.png',
      'assets/ui/skull.png',
    ];
    for (final path in assets) {
      try {
        final data = await rootBundle.load(path);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        _cache[path] = frame.image;
      } catch (_) {}
    }
    loaded = true;
  }

  static ui.Image? char(String n) => _cache['assets/character/$n.png'];
  static ui.Image? hold(String n) => _cache['assets/holds/$n.png'];
  static ui.Image? ui2(String n) => _cache['assets/ui/$n.png'];
}

// =========================================================
//  GameRenderer
// =========================================================
class GameRenderer {
  static void render(Canvas canvas, ClimbyGame g) {
    if (g.shakeTime > 0) {
      final s = g.shakeIntensity * (g.shakeTime / 0.3);
      canvas.save();
      canvas.translate(rnd(-s, s), rnd(-s, s));
    }
    _drawBackground(canvas, g);
    _drawHolds(canvas, g);
    _drawLava(canvas, g);
    if (g.ballPit != null) {
      _drawBallPitBackground(canvas, g);
      _drawBallPitBalls(canvas, g, behind: true);
    }
    _drawCharacter(canvas, g);
    if (g.ballPit != null) _drawBallPitBalls(canvas, g, behind: false);
    _drawParticles(canvas, g);
    if (g.shakeTime > 0) canvas.restore();
    _drawHUD(canvas, g);
    _drawWeatherIndicator(canvas, g);
    if (g.won) _drawWinBanner(canvas, g);
    if (g.deathMode == DeathMode.lava) _drawBurnOverlay(canvas, g);
  }

  // ---- SPRITE HELPERS ----

  /// Draw image to a rect with optional tint
  static void _img(Canvas c, ui.Image? img, Rect dst, {Color? tint}) {
    if (img == null) return;
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    final p = Paint();
    if (tint != null) p.colorFilter = ColorFilter.mode(tint, BlendMode.modulate);
    c.drawImageRect(img, src, dst, p);
  }

  /// Draw sprite as a bone between two physics points
  static void _bone(Canvas c, ui.Image? img,
      Offset from, Offset to, double drawW, double drawH,
      {double pivotY = 0.08, Color? tint}) {
    if (img == null) {
      // Fallback capsule
      c.drawLine(from, to, Paint()..color = const Color(0xFF3A2E1F)
        ..strokeWidth = drawW * 0.7 + 4..strokeCap = StrokeCap.round);
      c.drawLine(from, to, Paint()..color = (tint ?? const Color(0xFFC69365))
        ..strokeWidth = drawW * 0.7..strokeCap = StrokeCap.round);
      return;
    }
    final ang = math.atan2(to.dy - from.dy, to.dx - from.dx) - math.pi / 2;
    final dist = (to - from).distance;
    final scale = dist / (drawH * (1.0 - pivotY));
    final w = drawW * scale;
    final h = drawH * scale;
    c.save();
    c.translate(from.dx, from.dy);
    c.rotate(ang);
    _img(c, img, Rect.fromLTWH(-w / 2, -h * pivotY, w, h), tint: tint);
    c.restore();
  }

  /// Draw sprite centered at point with optional rotation. Negative aspect = horizontal flip.
  static void _at(Canvas c, ui.Image? img, Offset pos, double size,
      {double aspect = 1.0, double rotation = 0, Color? tint}) {
    if (img == null) return;
    c.save();
    c.translate(pos.dx, pos.dy);
    if (rotation != 0) c.rotate(rotation);
    if (aspect < 0) {
      c.scale(-1, 1); // horizontal flip
      aspect = -aspect;
    }
    _img(c, img, Rect.fromCenter(center: Offset.zero, width: size * aspect, height: size), tint: tint);
    c.restore();
  }

  /// Clamp angle to max deviation from base
  static double _clampAng(double a, double base, double max) {
    double d = a - base;
    while (d > math.pi) d -= 2 * math.pi;
    while (d < -math.pi) d += 2 * math.pi;
    return base + d.clamp(-max, max);
  }

  // ---- BACKGROUND ----
  static void _drawBackground(Canvas canvas, ClimbyGame g) {
    final rect = Rect.fromLTWH(0, 0, g.size.x, g.size.y);
    Paint paint;
    if (g.weather == WeatherType.storm) {
      paint = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF2A2A3A), Color(0xFF5A5A6A), Color(0xFF3A3A45)]).createShader(rect);
    } else if (g.weather == WeatherType.rain) {
      paint = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF5A6A78), Color(0xFFA3A89A), Color(0xFF7A7060)]).createShader(rect);
    } else {
      paint = Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFD6E4EC), Color(0xFFF4EAD5), Color(0xFFD8C89A)]).createShader(rect);
    }
    canvas.drawRect(rect, paint);
    // Bricks
    final bp = Paint()..color = const Color(0x143A2E1F);
    final co = (g.camY * 0.5) % 80;
    for (int r = 0; r < 14; r++) {
      final y = (r * 80 + co) % g.size.y;
      final sh = r.isEven ? 0.0 : 60.0;
      for (double x = -120 + sh; x < g.size.x + 120; x += 120)
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 110, 30), const Radius.circular(4)), bp);
    }
    // Rain
    if (g.weather == WeatherType.rain || g.weather == WeatherType.storm) {
      final t = DateTime.now().millisecondsSinceEpoch / 1.0;
      final rp = Paint()..color = const Color(0x994A7BA6)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
      for (int i = 0; i < 30; i++) {
        final rx = (i * 73 + (t / 8) % 100) % g.size.x;
        final ry = ((i * 137 + t / 3) % (g.size.y + 60)) - 60;
        canvas.drawLine(Offset(rx, ry), Offset(rx + 4, ry + 16), rp);
      }
    }
    if (g.weather == WeatherType.storm && g.flashTime > 0)
      canvas.drawRect(rect, Paint()..color = Color.fromRGBO(255, 255, 255, g.flashTime * 0.6));
    // Finish line
    if (g.level != null) {
      final fy = g.size.y / 2 - (g.level!.finishY - g.camY) * g.cameraZoom;
      if (fy > -50 && fy < g.size.y + 50) {
        _dash(canvas, Offset(0, fy), Offset(g.size.x, fy),
            Paint()..color = const Color(0xFF3A2E1F)..strokeWidth = 3, 10, 6);
        final mr = Rect.fromCenter(center: Offset(g.size.x / 2, fy - 18), width: 130, height: 26);
        canvas.drawRRect(RRect.fromRectAndRadius(mr, const Radius.circular(8)), Paint()..color = const Color(0xFF3A2E1F));
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(g.size.x / 2, fy - 18), width: 124, height: 20),
            const Radius.circular(5)), Paint()..color = const Color(0xFFF2B134));
        _text(canvas, 'META', g.size.x / 2, fy - 26, cc: const Color(0xFF3A2E1F), s: 13, w: FontWeight.w900, a: TextAlign.center);
      }
    }
  }

  static void _dash(Canvas c, Offset a, Offset b, Paint p, double dw, double gap) {
    final dx = b.dx - a.dx, dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy); if (len < 1) return;
    final ux = dx / len, uy = dy / len;
    double d = 0;
    while (d < len) { final e = math.min(d + dw, len);
      c.drawLine(Offset(a.dx + ux * d, a.dy + uy * d), Offset(a.dx + ux * e, a.dy + uy * e), p); d = e + gap; }
  }

  static void _text(Canvas c, String t, double x, double y,
      {Color cc = Colors.black, double s = 14, FontWeight w = FontWeight.normal, TextAlign a = TextAlign.left, Color? c2}) {
    final tp = TextPainter(text: TextSpan(text: t, style: TextStyle(color: cc, fontSize: s, fontWeight: w)),
        textDirection: TextDirection.ltr, textAlign: a)..layout();
    double dx = x; if (a == TextAlign.center) dx -= tp.width / 2;
    tp.paint(c, Offset(dx, y));
  }

  // ---- HOLDS ----
  static void _drawHolds(Canvas canvas, ClimbyGame g) {
    for (final h in g.level!.holds) {
      if (h.broken) continue;
      if (h.type == HoldType.invisible && !h.visible) {
        final s = g.worldToScreen(h.x, h.y);
        if (s.y < -60 || s.y > g.size.y + 60) continue;
        canvas.drawCircle(Offset(s.x, s.y), h.r * g.cameraZoom,
            Paint()..color = const Color(0x143A2E1F)..style = PaintingStyle.stroke..strokeWidth = 1);
        continue;
      }
      final hx = h.type == HoldType.moving ? h.currentX : h.x;
      final s = g.worldToScreen(hx, h.y);
      if (s.y < -60 || s.y > g.size.y + 60) continue;
      final r = h.r * g.cameraZoom;
      final name = _holdName(h.type);
      final img = GameAssets.hold(name);
      if (img != null) {
        final aspect = img.width / img.height;
        _at(canvas, img, Offset(s.x, s.y), r * 2.6, aspect: aspect);
        if (h.type == HoldType.fragile && h.hp < 2) {
          final p = Paint()..color = const Color(0xFF3A2E1F)..strokeWidth = 2..strokeCap = StrokeCap.round;
          canvas.drawLine(Offset(s.x - r * 0.5, s.y - r * 0.3), Offset(s.x + r * 0.4, s.y + r * 0.5), p);
        }
      } else {
        final color = holdColor(h.type);
        canvas.drawCircle(Offset(s.x + 2, s.y + 3), r, Paint()..color = const Color(0x553A2E1F));
        canvas.drawCircle(Offset(s.x, s.y), r, Paint()..color = color);
        canvas.drawCircle(Offset(s.x, s.y), r, Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 3);
      }
    }
  }

  static String _holdName(HoldType t) {
    switch (t) {
      case HoldType.fragile: return 'hold_fragile';
      case HoldType.magnet: return 'hold_magnet';
      case HoldType.slippery: return 'hold_slippery';
      case HoldType.bouncy: return 'hold_bouncy';
      case HoldType.sticky: return 'hold_sticky';
      case HoldType.moving: return 'hold_moving';
      default: return 'hold_normal';
    }
  }

  // ---- LAVA ----
  static void _drawLava(Canvas canvas, ClimbyGame g) {
    if (!g.bossMode || g.lavaY < -150) return;
    final ly = g.size.y / 2 - (g.lavaY - g.camY) * g.cameraZoom;
    if (ly > g.size.y + 100) return;
    final t = DateTime.now().millisecondsSinceEpoch / 200.0;
    final path = Path()..moveTo(0, ly);
    for (double x = 0; x <= g.size.x; x += 20) path.lineTo(x, ly + math.sin(x * 0.05 + t) * 6);
    path.lineTo(g.size.x, g.size.y + 50); path.lineTo(0, g.size.y + 50); path.close();
    canvas.drawPath(path, Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFFFFEB3B), Color(0xFFFF5722), Color(0xFFD32F2F), Color(0xFF5D2A0E)])
      .createShader(Rect.fromLTWH(0, ly, g.size.x, g.size.y - ly + 100)));
    for (int i = 0; i < 7; i++) {
      final bx = (i * 137 + t * 5) % g.size.x;
      canvas.drawCircle(Offset(bx, ly + 20 + (i * 11) % 30), 3.0 + (i % 3), Paint()..color = const Color(0xB3FFAA3A));
    }
    canvas.drawRect(Rect.fromLTWH(0, ly - 12, g.size.x, 12), Paint()..color = const Color(0x44FF9800));
  }

  static void _drawBurnOverlay(Canvas canvas, ClimbyGame g) {
    final t = (g.burnTime / 2.5).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, g.size.x, g.size.y), Paint()
      ..shader = RadialGradient(center: Alignment.center, colors: [
        Colors.transparent, const Color(0x00FF5722), Color.fromRGBO(139, 0, 0, 0.5 * t),
      ], stops: const [0.4, 0.7, 1.0]).createShader(Rect.fromLTWH(0, 0, g.size.x, g.size.y)));
  }

  // ---- CHARACTER ----
  static void _drawCharacter(Canvas canvas, ClimbyGame g) {
    final c = g.char;
    final br = (g.gripCountPublic() == 4 && g.dragLimb == null) ? g.breatheOffset : 0.0;
    final z = g.cameraZoom;
    final head = _ws(g, c.head.x, c.head.y + br);
    final chest = _ws(g, c.chest.x, c.chest.y + br * 0.5);
    final ls = _ws(g, c.ls.x, c.ls.y + br * 0.5);
    final rs = _ws(g, c.rs.x, c.rs.y + br * 0.5);
    final lp = _ws(g, c.lp.x, c.lp.y);
    final rp = _ws(g, c.rp.x, c.rp.y);
    final lh = _ws(g, c.lh.x, c.lh.y);
    final rh = _ws(g, c.rh.x, c.rh.y);
    final le = _ws(g, c.le.x, c.le.y);
    final re = _ws(g, c.re.x, c.re.y);
    final lf = _ws(g, c.lf.x, c.lf.y);
    final rf = _ws(g, c.rf.x, c.rf.y);
    final lk = _ws(g, c.lk.x, c.lk.y);
    final rk = _ws(g, c.rk.x, c.rk.y);

    // Colors from customization
    final cust = Prefs.customization;
    Color? skinC = cust.skin;
    Color? shirtC = cust.shirt;
    Color? shortsC = cust.shorts;
    Color? shoeC = cust.shoes;

    // Burn darkening
    Color? burnC;
    if (g.faceState == FaceState.burning || g.faceState == FaceState.dead) {
      final t = (g.burnTime / 2.5).clamp(0.0, 1.0);
      final v = (255 * (1 - t * 0.8)).round();
      burnC = Color.fromARGB(255, v, v, v);
    }
    // If burning, override all tints
    if (burnC != null) { skinC = burnC; shirtC = burnC; shortsC = burnC; shoeC = burnC; }

    // Don't tint if color is the default (let original PNG colors show)
    // Only tint if user has customized
    final defSkin = const Color(0xFFC69365);
    final defShirt = const Color(0xFFD94E7A);
    final defShorts = const Color(0xFF3A3A55);
    final defShoes = const Color(0xFF5A8A3A);

    Color? skinT = (skinC != defSkin || burnC != null) ? skinC : null;
    Color? shirtT = (shirtC != defShirt || burnC != null) ? shirtC : null;
    Color? shortsT = (shortsC != defShorts || burnC != null) ? shortsC : null;
    Color? shoeT = (shoeC != defShoes || burnC != null) ? shoeC : null;

    final sc = z;

    // DRAW ORDER: back limbs → torso/shorts → front limbs → hands/feet → head

    // 1. BACK ARM (right): shoulder → elbow, elbow → hand position
    _bone(canvas, GameAssets.char('arm_upper'), rs, re, 40 * sc, 145 * sc, tint: skinT);
    _bone(canvas, GameAssets.char('arm_lower'), re, rh, 36 * sc, 144 * sc, tint: skinT);

    // 2. BACK LEG (right): hip → knee, knee → foot position
    _bone(canvas, GameAssets.char('leg_upper'), rp, rk, 44 * sc, 150 * sc, tint: shortsT);
    _bone(canvas, GameAssets.char('leg_lower'), rk, rf, 38 * sc, 150 * sc, tint: skinT);

    // 3. TORSO
    final pelvis = Offset((lp.dx + rp.dx) / 2, (lp.dy + rp.dy) / 2);
    _bone(canvas, GameAssets.char('torso'), chest, pelvis, 68 * sc, 155 * sc, pivotY: 0.10, tint: shirtT);

    // 4. SHORTS (overlaps torso bottom)
    final sEnd = Offset(pelvis.dx, pelvis.dy + 15 * sc);
    _bone(canvas, GameAssets.char('shorts'), pelvis, sEnd, 68 * sc, 115 * sc, pivotY: 0.02, tint: shortsT);

    // 5. FRONT LEG (left)
    _bone(canvas, GameAssets.char('leg_upper'), lp, lk, 44 * sc, 150 * sc, tint: shortsT);
    _bone(canvas, GameAssets.char('leg_lower'), lk, lf, 38 * sc, 150 * sc, tint: skinT);

    // 6. FRONT ARM (left)
    _bone(canvas, GameAssets.char('arm_upper'), ls, le, 40 * sc, 145 * sc, tint: skinT);
    _bone(canvas, GameAssets.char('arm_lower'), le, lh, 36 * sc, 144 * sc, tint: skinT);

    // 7. HANDS — at the END of the forearm, constrained rotation
    final lhAng = math.atan2(lh.dy - le.dy, lh.dx - le.dx) - math.pi / 2;
    final rhAng = math.atan2(rh.dy - re.dy, rh.dx - re.dx) - math.pi / 2;
    final lhRot = _clampAng(lhAng, 0, math.pi * 0.35);
    final rhRot = _clampAng(rhAng, 0, math.pi * 0.35);
    _at(canvas, GameAssets.char('hand_left'), lh, 44 * sc, aspect: 102.0 / 122, rotation: lhRot, tint: skinT);
    // hand_right: flip horizontally by using negative aspect
    _at(canvas, GameAssets.char('hand_right'), rh, 44 * sc, aspect: -98.0 / 122, rotation: rhRot, tint: skinT);

    // 8. FEET — constrained: always point roughly downward, max ±20° tilt
    final lfAng = math.atan2(lf.dy - lk.dy, lf.dx - lk.dx) - math.pi / 2;
    final rfAng = math.atan2(rf.dy - rk.dy, rf.dx - rk.dx) - math.pi / 2;
    final lfRot = _clampAng(lfAng, 0, math.pi * 0.2);
    final rfRot = _clampAng(rfAng, 0, math.pi * 0.2);
    _at(canvas, GameAssets.char('foot_left'), lf, 55 * sc, aspect: 146.0 / 130, rotation: lfRot, tint: shoeT);
    _at(canvas, GameAssets.char('foot_right'), rf, 55 * sc, aspect: 145.0 / 130, rotation: rfRot, tint: shoeT);

    // 9. HEAD — NO TINT (preserves white of eyes/teeth), only burn darkens
    final headImg = _headImg(g.faceState);
    _at(canvas, headImg, head, 68 * sc, aspect: 153.0 / 148,
        tint: burnC);

    // Grip indicators
    for (final k in ['LH', 'RH', 'LF', 'RF']) {
      if (g.grips[k] != null) {
        final p = c.limbByKey(k);
        final s = g.worldToScreen(p.x, p.y);
        canvas.drawCircle(Offset(s.x, s.y), k.contains('F') ? 28 : 20,
            Paint()..color = const Color(0x445A8A3A)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      }
    }
    // Reach indicator
    if (g.dragLimb != null) {
      final isArm = g.dragLimb == 'LH' || g.dragLimb == 'RH';
      final bm = bodyMultipliers(Prefs.customization.bodyType);
      final reach = (isArm ? kArmReachBase : kLegReachBase) * bm.reach;
      final anchor = c.anchorForLimb(g.dragLimb!);
      final s = g.worldToScreen(anchor.x, anchor.y);
      canvas.drawCircle(Offset(s.x, s.y), reach * z,
          Paint()..color = const Color(0x333A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  static Offset _ws(ClimbyGame g, double x, double y) {
    final v = g.worldToScreen(x, y); return Offset(v.x, v.y);
  }

  static ui.Image? _headImg(FaceState s) {
    switch (s) {
      case FaceState.happy: return GameAssets.char('head_happy');
      case FaceState.scared: return GameAssets.char('head_scared');
      case FaceState.focused: return GameAssets.char('head_focused');
      case FaceState.burning: return GameAssets.char('head_burning');
      case FaceState.dead: return GameAssets.char('head_dead');
      default: return GameAssets.char('head_neutral');
    }
  }

  // ---- drawCharacterAt (for menus/previews) ----
  static void drawCharacterAt(Canvas canvas, {
    required Offset headPos, required Offset chestPos,
    required Offset lsPos, required Offset rsPos,
    required Offset lpPos, required Offset rpPos,
    required Offset lhPos, required Offset rhPos,
    required Offset lePos, required Offset rePos,
    required Offset lfPos, required Offset rfPos,
    required Offset lkPos, required Offset rkPos,
    required dynamic cust, required double headR,
    FaceState faceState = FaceState.neutral,
    Map<String, double>? stamina, Map<String, dynamic>? grips,
    double tNow = 0, double scale = 1.0, bool blinking = false,
  }) {
    final sc = scale;
    Color? skinT, shirtT, shortsT;
    if (cust is Customization) {
      final d = Customization();
      if (cust.skin != d.skin) skinT = cust.skin;
      if (cust.shirt != d.shirt) shirtT = cust.shirt;
      if (cust.shorts != d.shorts) shortsT = cust.shorts;
    }
    // Back arm+leg
    _bone(canvas, GameAssets.char('arm_upper'), rsPos, rePos, 40 * sc, 145 * sc, tint: skinT);
    _bone(canvas, GameAssets.char('arm_lower'), rePos, rhPos, 36 * sc, 144 * sc, tint: skinT);
    _bone(canvas, GameAssets.char('leg_upper'), rpPos, rkPos, 44 * sc, 150 * sc, tint: shortsT);
    _bone(canvas, GameAssets.char('leg_lower'), rkPos, rfPos, 38 * sc, 150 * sc, tint: skinT);
    // Torso+shorts
    final pelvis = Offset((lpPos.dx + rpPos.dx) / 2, (lpPos.dy + rpPos.dy) / 2);
    _bone(canvas, GameAssets.char('torso'), chestPos, pelvis, 68 * sc, 155 * sc, pivotY: 0.10, tint: shirtT);
    final sEnd = Offset(pelvis.dx, pelvis.dy + 15 * sc);
    _bone(canvas, GameAssets.char('shorts'), pelvis, sEnd, 68 * sc, 115 * sc, pivotY: 0.02, tint: shortsT);
    // Front leg+arm
    _bone(canvas, GameAssets.char('leg_upper'), lpPos, lkPos, 44 * sc, 150 * sc, tint: shortsT);
    _bone(canvas, GameAssets.char('leg_lower'), lkPos, lfPos, 38 * sc, 150 * sc, tint: skinT);
    _bone(canvas, GameAssets.char('arm_upper'), lsPos, lePos, 40 * sc, 145 * sc, tint: skinT);
    _bone(canvas, GameAssets.char('arm_lower'), lePos, lhPos, 36 * sc, 144 * sc, tint: skinT);
    // Hands+feet (no rotation in preview)
    _at(canvas, GameAssets.char('hand_left'), lhPos, 44 * sc, aspect: 102.0 / 122, tint: skinT);
    _at(canvas, GameAssets.char('hand_right'), rhPos, 44 * sc, aspect: -98.0 / 122, tint: skinT);
    _at(canvas, GameAssets.char('foot_left'), lfPos, 55 * sc, aspect: 146.0 / 130);
    _at(canvas, GameAssets.char('foot_right'), rfPos, 55 * sc, aspect: 145.0 / 130);
    // Head — no tint (preserve eye whites)
    _at(canvas, _headImg(faceState), headPos, 68 * sc, aspect: 153.0 / 148);
  }

  // ---- PARTICLES ----
  static void _drawParticles(Canvas canvas, ClimbyGame g) {
    for (final p in g.particles) {
      final s = g.worldToScreen(p.x, p.y);
      final a = p.life.clamp(0, 1).toDouble();
      if (p.type == 'confetti') {
        canvas.save(); canvas.translate(s.x, s.y); canvas.rotate(p.rot);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.r * 2, height: p.r),
            Paint()..color = p.color.withAlpha((a * 255).round())); canvas.restore();
      } else if (p.type == 'flame') {
        canvas.drawCircle(Offset(s.x, s.y), p.r, Paint()..color = p.color.withAlpha((a * 220).round())
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.r * 0.3));
      } else {
        canvas.drawCircle(Offset(s.x, s.y), p.r, Paint()..color = p.color.withAlpha((a * 150).round()));
      }
    }
  }

  // ---- BALL PIT ----
  static void _drawBallPitBackground(Canvas canvas, ClimbyGame g) {
    final bp = g.ballPit!;
    final ptTop = g.worldToScreen(0, bp.pitTop).y;
    final ptBot = g.worldToScreen(0, bp.pitBottom).y;
    final pl = g.worldToScreen(bp.pitLeft, 0).x;
    final pr = g.worldToScreen(bp.pitRight, 0).x;
    final pitH = ptBot - ptTop + 60;
    canvas.drawOval(Rect.fromCenter(center: Offset((pl + pr) / 2, ptBot + 35), width: (pr - pl) + 60, height: 28),
        Paint()..color = const Color(0x403A2E1F));
    final outer = Rect.fromLTWH(pl - 24, ptTop - 10, pr - pl + 48, pitH);
    canvas.drawRRect(RRect.fromRectAndRadius(outer, const Radius.circular(20)),
        Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF3D6890), Color(0xFF2A4A68)]).createShader(outer));
    canvas.drawRRect(RRect.fromRectAndRadius(outer, const Radius.circular(20)),
        Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 4);
    final inner = Rect.fromLTWH(pl - 12, ptTop, pr - pl + 24, pitH - 14);
    canvas.drawRRect(RRect.fromRectAndRadius(inner, const Radius.circular(14)),
        Paint()..shader = const LinearGradient(
            colors: [Color(0xFF4A7BA6), Color(0xFF5A8FBF), Color(0xFF3D6890)]).createShader(inner));
  }

  static void _drawBallPitBalls(Canvas canvas, ClimbyGame g, {required bool behind}) {
    final bp = g.ballPit!;
    final balls = bp.balls.where((b) => behind ? b.depth < 0 : b.depth >= 0).toList();
    balls.sort((a, b) => b.y.compareTo(a.y));
    for (final b in balls) {
      final s = g.worldToScreen(b.x, b.y);
      canvas.drawCircle(Offset(s.x + 2, s.y + 3), b.r, Paint()..color = const Color(0x593A2E1F));
      canvas.drawCircle(Offset(s.x, s.y), b.r, Paint()..color = b.color);
      canvas.drawCircle(Offset(s.x, s.y), b.r, Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawCircle(Offset(s.x - b.r * 0.35, s.y - b.r * 0.35), b.r * 0.35, Paint()..color = const Color(0x55FFFFFF));
    }
  }

  // ---- HUD ----
  static void _drawHUD(Canvas canvas, ClimbyGame g) {
    // Logo top-right
    final logo = GameAssets.ui2('logo_climby');
    if (logo != null) _img(canvas, logo, Rect.fromLTWH(g.size.x - 118, 8, 108, 36));

    // Height
    _hudBox(canvas, Rect.fromLTWH(12, 12, 110, 50));
    _text(canvas, 'ALTURA', 20, 18, cc: const Color(0xFF3A2E1F), s: 10, w: FontWeight.w700);
    _text(canvas, '${g.currentHeight.toStringAsFixed(1)}m', 20, 30, cc: const Color(0xFF3A2E1F), s: 22, w: FontWeight.w900);
    // Record
    if (g.recordHeight > 0) {
      _hudBox(canvas, Rect.fromLTWH(12, 70, 110, 50));
      _text(canvas, 'RECORD', 20, 76, cc: const Color(0xFF3A2E1F), s: 10, w: FontWeight.w700);
      _text(canvas, '${g.recordHeight.toStringAsFixed(1)}m', 20, 88, cc: const Color(0xFF3A2E1F), s: 22, w: FontWeight.w900);
    }
    // Lava dist
    if (g.bossMode) {
      final start = g.level!.holds.first;
      final playerWorldY = start.y + g.maxHeight * 30;
      final ld = ((playerWorldY - g.lavaY) / 30).clamp(0.0, 999.0);
      _hudBox(canvas, Rect.fromLTWH(12, g.size.y - 100, 130, 36));
      _text(canvas, 'LAVA: ${ld.toStringAsFixed(1)}m', 22, g.size.y - 88, cc: const Color(0xFFE85D3C), s: 13, w: FontWeight.w900);
    }
    // Stamina
    final cx = g.size.x / 2, cy = g.size.y - 40;
    const colors = [Color(0xFFE85D3C), Color(0xFF4A7BA6), Color(0xFF5A8A3A), Color(0xFFF2B134)];
    const keys = ['LH', 'RH', 'LF', 'RF'];
    _hudBox(canvas, Rect.fromCenter(center: Offset(cx, cy), width: 200, height: 50), r: 20);
    for (int i = 0; i < 4; i++) {
      final dx = cx - 70 + i * 47;
      final st = g.stamina[keys[i]]!;
      canvas.drawCircle(Offset(dx, cy), 17, Paint()..color = const Color(0x66FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 3);
      Color rc = Colors.white;
      if (st < 25) rc = const Color(0xFFD33333); else if (st < 50) rc = const Color(0xFFF2B134);
      canvas.drawArc(Rect.fromCircle(center: Offset(dx, cy), radius: 17), -math.pi / 2, math.pi * 2 * st / 100, false,
          Paint()..color = rc..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(dx, cy), 11, Paint()..color = colors[i]);
      canvas.drawCircle(Offset(dx, cy), 11, Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  static void _hudBox(Canvas c, Rect rect, {double r = 12}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(r));
    c.drawRRect(RRect.fromRectAndRadius(rect.shift(const Offset(2, 2)), Radius.circular(r)), Paint()..color = const Color(0xFF3A2E1F));
    c.drawRRect(rr, Paint()..color = const Color(0xFFF4EAD5));
    c.drawRRect(rr, Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  // ---- WEATHER ----
  static void _drawWeatherIndicator(Canvas canvas, ClimbyGame g) {
    if (g.weather == WeatherType.none) return;
    final t = g.weather == WeatherType.wind ? 'VIENTO' : g.weather == WeatherType.rain ? 'LLUVIA' : 'TORMENTA';
    _hudBox(canvas, Rect.fromLTWH(g.size.x - 120, g.size.y / 2 - 18, 110, 36), r: 10);
    _text(canvas, t, g.size.x - 65, g.size.y / 2 - 8, cc: const Color(0xFF3A2E1F), s: 12, w: FontWeight.w900, a: TextAlign.center);
  }

  // ---- WIN BANNER ----
  static void _drawWinBanner(Canvas canvas, ClimbyGame g) {
    final t = g.cinematicTimer.clamp(0, 1).toDouble();
    final sc = (t * 1.2).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(g.size.x / 2, g.size.y * 0.3);
    canvas.rotate(-0.08); canvas.scale(sc);
    _hudBox(canvas, Rect.fromCenter(center: Offset.zero, width: 260, height: 90), r: 20);
    final trophy = GameAssets.ui2('trophy');
    if (trophy != null) _img(canvas, trophy, Rect.fromCenter(center: const Offset(-95, 0), width: 50, height: 50));
    _text(canvas, '¡CIMA!', 10, -18, cc: const Color(0xFF3A2E1F), s: 32, w: FontWeight.w900, a: TextAlign.center);
    canvas.restore();
  }
}
