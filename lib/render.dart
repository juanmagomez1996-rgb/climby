import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'physics.dart';
import 'holds.dart';
import 'climby_game.dart';
import 'storage.dart';

// =========================================================
//  GameAssets — preload all SVGs as PictureInfo at startup
// =========================================================
class GameAssets {
  static final Map<String, PictureInfo> _svgCache = {};
  static final Map<String, ui.Size> _sizes = {};
  static bool loaded = false;

  static final List<String> _allAssets = [
    'assets/character/head_neutral.svg',
    'assets/character/head_happy.svg',
    'assets/character/head_scared.svg',
    'assets/character/head_focused.svg',
    'assets/character/head_burning.svg',
    'assets/character/head_dead.svg',
    'assets/character/torso.svg',
    'assets/character/shorts.svg',
    'assets/character/arm_upper.svg',
    'assets/character/arm_lower.svg',
    'assets/character/hand_left.svg',
    'assets/character/hand_right.svg',
    'assets/character/leg_upper.svg',
    'assets/character/leg_lower.svg',
    'assets/character/foot_left.svg',
    'assets/character/foot_right.svg',
    'assets/holds/hold_normal.svg',
    'assets/holds/hold_fragile.svg',
    'assets/holds/hold_bouncy.svg',
    'assets/holds/hold_magnet.svg',
    'assets/holds/hold_sticky.svg',
    'assets/holds/hold_slippery.svg',
    'assets/holds/hold_moving.svg',
    'assets/ui/logo_climby.svg',
    'assets/ui/trophy.svg',
    'assets/ui/skull.svg',
  ];

  static Future<void> loadAll() async {
    if (loaded) return;
    for (final path in _allAssets) {
      try {
        final raw = await rootBundle.loadString(path);
        final info = await vg.loadPicture(SvgStringLoader(raw), null);
        _svgCache[path] = info;
        _sizes[path] = info.size;
      } catch (e) {
        // Skip missing assets — fallback drawing used
      }
    }
    loaded = true;
  }

  static PictureInfo? _get(String path) => _svgCache[path];
  static ui.Size? _size(String path) => _sizes[path];

  static PictureInfo? char(String name) => _get('assets/character/$name.svg');
  static ui.Size? charSize(String name) => _size('assets/character/$name.svg');
  static PictureInfo? hold(String name) => _get('assets/holds/$name.svg');
  static ui.Size? holdSize(String name) => _size('assets/holds/$name.svg');
  static PictureInfo? ui2(String name) => _get('assets/ui/$name.svg');
  static ui.Size? uiSize(String name) => _size('assets/ui/$name.svg');
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
      _drawBallPitBalls(canvas, g, behindPlayer: true);
    }

    _drawCharacter(canvas, g);

    if (g.ballPit != null) {
      _drawBallPitBalls(canvas, g, behindPlayer: false);
    }

    _drawParticles(canvas, g);

    if (g.shakeTime > 0) canvas.restore();

    _drawHUD(canvas, g);
    _drawWeatherIndicator(canvas, g);
    if (g.won) _drawWinBanner(canvas, g);
    if (g.deathMode == DeathMode.lava) _drawBurnEffect(canvas, g);
  }

  // =========================================================
  //  SVG DRAWING HELPERS
  // =========================================================

  /// Paint an SVG Picture to canvas at a given rect with optional color tint
  static void _paintSvg(Canvas canvas, PictureInfo? info, Rect dst, {Color? tint}) {
    if (info == null) return;
    canvas.save();
    canvas.translate(dst.left, dst.top);
    canvas.scale(dst.width / info.size.width, dst.height / info.size.height);
    if (tint != null) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, info.size.width, info.size.height), Paint());
      canvas.drawPicture(info.picture);
      canvas.drawRect(
        Rect.fromLTWH(0, 0, info.size.width, info.size.height),
        Paint()..colorFilter = ColorFilter.mode(tint, BlendMode.modulate),
      );
      canvas.restore(); // saveLayer
    } else {
      canvas.drawPicture(info.picture);
    }
    canvas.restore();
  }

  /// Draw SVG as a bone between two physics points
  /// pivotY = fraction from top where rotation anchor is (0=top, 1=bottom)
  static void _drawSvgBone(Canvas canvas, PictureInfo? info,
      Offset from, Offset to, double drawWidth, double drawHeight,
      {double pivotY = 0.08, Color? tint}) {
    if (info == null) {
      // Fallback: colored capsule
      final p = Paint()..color = (tint ?? const Color(0xFFC69365))
        ..strokeWidth = drawWidth * 0.7..strokeCap = StrokeCap.round;
      canvas.drawLine(from, to, Paint()..color = const Color(0xFF3A2E1F)
        ..strokeWidth = drawWidth * 0.7 + 4..strokeCap = StrokeCap.round);
      canvas.drawLine(from, to, p);
      return;
    }
    final angle = math.atan2(to.dy - from.dy, to.dx - from.dx) - math.pi / 2;
    final dist = (to - from).distance;
    final scale = dist / (drawHeight * (1.0 - pivotY));

    canvas.save();
    canvas.translate(from.dx, from.dy);
    canvas.rotate(angle);
    final w = drawWidth * scale;
    final h = drawHeight * scale;
    final rect = Rect.fromLTWH(-w / 2, -h * pivotY, w, h);
    _paintSvg(canvas, info, rect, tint: tint);
    canvas.restore();
  }

  /// Draw SVG centered at a point with constrained rotation
  static void _drawSvgAt(Canvas canvas, PictureInfo? info,
      Offset pos, double size,
      {double aspect = 1.0, double rotation = 0, Color? tint}) {
    if (info == null) return;
    final w = size * aspect;
    final h = size;
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    if (rotation != 0) canvas.rotate(rotation);
    final rect = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    _paintSvg(canvas, info, rect, tint: tint);
    canvas.restore();
  }

  /// Clamp an angle to a range around a base angle
  static double _clampAngle(double angle, double base, double maxDev) {
    double diff = angle - base;
    // Normalize to [-pi, pi]
    while (diff > math.pi) diff -= 2 * math.pi;
    while (diff < -math.pi) diff += 2 * math.pi;
    diff = diff.clamp(-maxDev, maxDev);
    return base + diff;
  }

  // =========================================================
  //  BACKGROUND
  // =========================================================
  static void _drawBackground(Canvas canvas, ClimbyGame g) {
    final rect = Rect.fromLTWH(0, 0, g.size.x, g.size.y);
    Paint paint;
    if (g.weather == WeatherType.storm) {
      paint = Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF2A2A3A), Color(0xFF5A5A6A), Color(0xFF3A3A45)],
      ).createShader(rect);
    } else if (g.weather == WeatherType.rain) {
      paint = Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF5A6A78), Color(0xFFA3A89A), Color(0xFF7A7060)],
      ).createShader(rect);
    } else {
      paint = Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFD6E4EC), Color(0xFFF4EAD5), Color(0xFFD8C89A)],
      ).createShader(rect);
    }
    canvas.drawRect(rect, paint);

    // Brick texture
    final brick = Paint()..color = const Color(0x143A2E1F);
    final camOffset = (g.camY * 0.5) % 80;
    for (int row = 0; row < 14; row++) {
      final y = (row * 80 + camOffset) % g.size.y;
      final shift = row.isEven ? 0.0 : 60.0;
      for (double x = -120 + shift; x < g.size.x + 120; x += 120) {
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 110, 30), const Radius.circular(4)), brick);
      }
    }

    // Rain
    if (g.weather == WeatherType.rain || g.weather == WeatherType.storm) {
      final tNow = DateTime.now().millisecondsSinceEpoch / 1.0;
      final rp = Paint()..color = const Color(0x994A7BA6)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
      for (int i = 0; i < 30; i++) {
        final rx = (i * 73 + (tNow / 8) % 100) % g.size.x;
        final ry = ((i * 137 + tNow / 3) % (g.size.y + 60)) - 60;
        canvas.drawLine(Offset(rx, ry), Offset(rx + 4, ry + 16), rp);
      }
    }
    if (g.weather == WeatherType.storm && g.flashTime > 0) {
      canvas.drawRect(rect, Paint()..color = Color.fromRGBO(255, 255, 255, g.flashTime * 0.6));
    }

    // Finish line
    if (g.level != null) {
      final fy = g.size.y / 2 - (g.level!.finishY - g.camY) * g.cameraZoom;
      if (fy > -50 && fy < g.size.y + 50) {
        _drawDashedLine(canvas, Offset(0, fy), Offset(g.size.x, fy),
            Paint()..color = const Color(0xFF3A2E1F)..strokeWidth = 3, 10, 6);
        final mr = Rect.fromCenter(center: Offset(g.size.x / 2, fy - 18), width: 130, height: 26);
        canvas.drawRRect(RRect.fromRectAndRadius(mr, const Radius.circular(8)),
            Paint()..color = const Color(0xFF3A2E1F));
        canvas.drawRRect(RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(g.size.x / 2, fy - 18), width: 124, height: 20),
            const Radius.circular(5)), Paint()..color = const Color(0xFFF2B134));
        _drawText(canvas, 'META', g.size.x / 2, fy - 26,
            color: const Color(0xFF3A2E1F), size: 13, weight: FontWeight.w900, align: TextAlign.center);
      }
    }
  }

  static void _drawDashedLine(Canvas c, Offset a, Offset b, Paint p, double dW, double gap) {
    final dx = b.dx - a.dx; final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy); if (len < 1) return;
    final ux = dx / len; final uy = dy / len;
    double drawn = 0;
    while (drawn < len) {
      final se = math.min(drawn + dW, len);
      c.drawLine(Offset(a.dx + ux * drawn, a.dy + uy * drawn),
          Offset(a.dx + ux * se, a.dy + uy * se), p);
      drawn = se + gap;
    }
  }

  static void _drawText(Canvas canvas, String text, double x, double y,
      {Color color = Colors.black, double size = 14,
      FontWeight weight = FontWeight.normal, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr, textAlign: align);
    tp.layout();
    double dx = x;
    if (align == TextAlign.center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, y));
  }

  // =========================================================
  //  HOLDS (SVG-based)
  // =========================================================
  static void _drawHolds(Canvas canvas, ClimbyGame g) {
    for (final hold in g.level!.holds) {
      if (hold.broken) continue;
      if (hold.type == HoldType.invisible && !hold.visible) {
        final s = g.worldToScreen(hold.x, hold.y);
        if (s.y < -60 || s.y > g.size.y + 60) continue;
        canvas.drawCircle(Offset(s.x, s.y), hold.r * g.cameraZoom,
            Paint()..color = const Color(0x143A2E1F)..style = PaintingStyle.stroke..strokeWidth = 1);
        continue;
      }
      final hx = hold.type == HoldType.moving ? hold.currentX : hold.x;
      final s = g.worldToScreen(hx, hold.y);
      if (s.y < -60 || s.y > g.size.y + 60) continue;
      _drawHold(canvas, hold, s.x, s.y, g.cameraZoom);
    }
  }

  static String _holdAssetName(HoldType type) {
    switch (type) {
      case HoldType.fragile: return 'hold_fragile';
      case HoldType.magnet: return 'hold_magnet';
      case HoldType.slippery: return 'hold_slippery';
      case HoldType.bouncy: return 'hold_bouncy';
      case HoldType.sticky: return 'hold_sticky';
      case HoldType.moving: return 'hold_moving';
      default: return 'hold_normal';
    }
  }

  static void _drawHold(Canvas canvas, Hold hold, double sx, double sy, double zoom) {
    final r = hold.r * zoom;
    final assetName = _holdAssetName(hold.type);
    final info = GameAssets.hold(assetName);
    if (info != null) {
      final svgSize = GameAssets.holdSize(assetName)!;
      final aspect = svgSize.width / svgSize.height;
      final drawH = r * 2.6;
      final drawW = drawH * aspect;
      _paintSvg(canvas, info,
          Rect.fromCenter(center: Offset(sx, sy), width: drawW, height: drawH));
      // Crack overlay for damaged fragile
      if (hold.type == HoldType.fragile && hold.hp < 2) {
        final p = Paint()..color = const Color(0xFF3A2E1F)..strokeWidth = 2..strokeCap = StrokeCap.round;
        canvas.drawLine(Offset(sx - r * 0.5, sy - r * 0.3), Offset(sx + r * 0.4, sy + r * 0.5), p);
      }
    } else {
      // Fallback circle
      final color = holdColor(hold.type);
      canvas.drawCircle(Offset(sx + 2, sy + 3), r, Paint()..color = const Color(0x553A2E1F));
      canvas.drawCircle(Offset(sx, sy), r, Paint()..color = color);
      canvas.drawCircle(Offset(sx, sy), r, Paint()..color = const Color(0xFF3A2E1F)
        ..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }

  // =========================================================
  //  LAVA
  // =========================================================
  static void _drawLava(Canvas canvas, ClimbyGame g) {
    if (!g.bossMode) return;
    if (g.lavaY < -150) return;
    final ly = g.size.y / 2 - (g.lavaY - g.camY) * g.cameraZoom;
    if (ly > g.size.y + 100) return;
    final tNow = DateTime.now().millisecondsSinceEpoch / 200.0;
    final path = Path()..moveTo(0, ly);
    for (double x = 0; x <= g.size.x; x += 20) {
      path.lineTo(x, ly + math.sin(x * 0.05 + tNow) * 6);
    }
    path.lineTo(g.size.x, g.size.y + 50);
    path.lineTo(0, g.size.y + 50);
    path.close();
    canvas.drawPath(path, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFFFFEB3B), Color(0xFFFF5722), Color(0xFFD32F2F), Color(0xFF5D2A0E)],
    ).createShader(Rect.fromLTWH(0, ly, g.size.x, g.size.y - ly + 100)));
    for (int i = 0; i < 7; i++) {
      final bx = (i * 137 + tNow * 5) % g.size.x;
      final by = ly + 20 + (i * 11) % 30;
      canvas.drawCircle(Offset(bx, by), 3 + (i % 3).toDouble(), Paint()..color = const Color(0xB3FFAA3A));
    }
    canvas.drawRect(Rect.fromLTWH(0, ly - 12, g.size.x, 12), Paint()..color = const Color(0x44FF9800));
  }

  static void _drawBurnEffect(Canvas canvas, ClimbyGame g) {
    final t = (g.burnTime / 2.5).clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, g.size.x, g.size.y), Paint()
      ..shader = RadialGradient(center: Alignment.center, colors: [
        Colors.transparent, const Color(0x00FF5722),
        Color.fromRGBO(139, 0, 0, 0.5 * t),
      ], stops: const [0.4, 0.7, 1.0]).createShader(
          Rect.fromLTWH(0, 0, g.size.x, g.size.y)));
  }

  // =========================================================
  //  CHARACTER (SVG sprite-based with physics)
  // =========================================================
  static void _drawCharacter(Canvas canvas, ClimbyGame g) {
    final c = g.char;
    final br = (g.gripCountPublic() == 4 && g.dragLimb == null) ? g.breatheOffset : 0.0;
    final z = g.cameraZoom;

    // Screen positions for all physics points
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

    // Get customization colors
    final cust = Prefs.customization;
    final skinTint = cust.skinColor;
    final shirtTint = cust.shirtColor;
    final shortsTint = cust.shortsColor;

    // Burn tint — darkens everything progressively
    Color? burnTint;
    if (g.faceState == FaceState.burning || g.faceState == FaceState.dead) {
      final t = (g.burnTime / 2.5).clamp(0.0, 1.0);
      final grey = (255 * (1 - t * 0.8)).round();
      burnTint = Color.fromARGB(255, grey, grey, grey);
    }

    // Apply burn on top of customization tints
    Color? skinFinal = burnTint ?? skinTint;
    Color? shirtFinal = burnTint ?? shirtTint;
    Color? shortsFinal = burnTint ?? shortsTint;
    Color? shoeFinal = burnTint;

    // Scale factor
    final sc = z * 1.0;

    // ===== DRAW ORDER: back limbs → torso → front limbs → hands/feet → head =====

    // 1. BACK ARM (right): shoulder → elbow → hand
    _drawSvgBone(canvas, GameAssets.char('arm_upper'), rs, re,
        38 * sc, 145 * sc, tint: skinFinal);
    _drawSvgBone(canvas, GameAssets.char('arm_lower'), re, rh,
        34 * sc, 144 * sc, tint: skinFinal);

    // 2. BACK LEG (right): hip → knee → foot
    _drawSvgBone(canvas, GameAssets.char('leg_upper'), rp, rk,
        42 * sc, 150 * sc, tint: shortsFinal);
    _drawSvgBone(canvas, GameAssets.char('leg_lower'), rk, rf,
        36 * sc, 150 * sc, tint: skinFinal);

    // 3. TORSO: chest → pelvis center
    final pelvis = Offset((lp.dx + rp.dx) / 2, (lp.dy + rp.dy) / 2);
    _drawSvgBone(canvas, GameAssets.char('torso'), chest, pelvis,
        65 * sc, 155 * sc, pivotY: 0.10, tint: shirtFinal);

    // 4. SHORTS: pelvis → just below
    final shortsEnd = Offset(pelvis.dx, pelvis.dy + 18 * sc);
    _drawSvgBone(canvas, GameAssets.char('shorts'), pelvis, shortsEnd,
        65 * sc, 115 * sc, pivotY: 0.05, tint: shortsFinal);

    // 5. FRONT LEG (left)
    _drawSvgBone(canvas, GameAssets.char('leg_upper'), lp, lk,
        42 * sc, 150 * sc, tint: shortsFinal);
    _drawSvgBone(canvas, GameAssets.char('leg_lower'), lk, lf,
        36 * sc, 150 * sc, tint: skinFinal);

    // 6. FRONT ARM (left)
    _drawSvgBone(canvas, GameAssets.char('arm_upper'), ls, le,
        38 * sc, 145 * sc, tint: skinFinal);
    _drawSvgBone(canvas, GameAssets.char('arm_lower'), le, lh,
        34 * sc, 144 * sc, tint: skinFinal);

    // 7. HANDS — constrained rotation (max ±40° from vertical down)
    final handSize = 42 * sc;
    final lhAng = math.atan2(lh.dy - le.dy, lh.dx - le.dx);
    final rhAng = math.atan2(rh.dy - re.dy, rh.dx - re.dx);
    // Clamp hands: mostly hang down (pi/2 = straight down in screen coords)
    // Allow ±60° deviation from the forearm angle but never flip upside down
    final lhRot = _clampAngle(lhAng - math.pi / 2, 0, math.pi * 0.35);
    final rhRot = _clampAngle(rhAng - math.pi / 2, 0, math.pi * 0.35);

    _drawSvgAt(canvas, GameAssets.char('hand_left'), lh, handSize,
        aspect: 102.0 / 122, rotation: lhRot, tint: skinFinal);
    _drawSvgAt(canvas, GameAssets.char('hand_right'), rh, handSize,
        aspect: 98.0 / 122, rotation: rhRot, tint: skinFinal);

    // 8. FEET — constrained rotation (always pointing roughly down/forward)
    final footSize = 52 * sc;
    final lfRawAng = math.atan2(lf.dy - lk.dy, lf.dx - lk.dx);
    final rfRawAng = math.atan2(rf.dy - rk.dy, rf.dx - rk.dx);
    // Feet should point ~down with max ±30° tilt
    // In screen coords, "straight down" for the foot sprite is ~0 rotation
    final lfRot = _clampAngle(lfRawAng - math.pi / 2, 0, math.pi * 0.25);
    final rfRot = _clampAngle(rfRawAng - math.pi / 2, 0, math.pi * 0.25);

    _drawSvgAt(canvas, GameAssets.char('foot_left'), lf, footSize,
        aspect: 146.0 / 130, rotation: lfRot, tint: shoeFinal);
    _drawSvgAt(canvas, GameAssets.char('foot_right'), rf, footSize,
        aspect: 145.0 / 130, rotation: rfRot, tint: shoeFinal);

    // 9. HEAD — always on top, no rotation (face always readable)
    final headInfo = _getHeadInfo(g.faceState);
    final headSize = 65 * sc;
    _drawSvgAt(canvas, headInfo, head, headSize,
        aspect: 153.0 / 148, tint: (g.faceState == FaceState.burning || g.faceState == FaceState.dead) ? burnTint : skinFinal);

    // Grip indicators (green circles around gripped limbs)
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

  static Offset _ws(ClimbyGame g, double wx, double wy) {
    final v = g.worldToScreen(wx, wy);
    return Offset(v.x, v.y);
  }

  static PictureInfo? _getHeadInfo(FaceState state) {
    switch (state) {
      case FaceState.happy: return GameAssets.char('head_happy');
      case FaceState.scared: return GameAssets.char('head_scared');
      case FaceState.focused: return GameAssets.char('head_focused');
      case FaceState.burning: return GameAssets.char('head_burning');
      case FaceState.dead: return GameAssets.char('head_dead');
      default: return GameAssets.char('head_neutral');
    }
  }

  // =========================================================
  //  PARTICLES
  // =========================================================
  static void _drawParticles(Canvas canvas, ClimbyGame g) {
    for (final p in g.particles) {
      final s = g.worldToScreen(p.x, p.y);
      final alpha = p.life.clamp(0, 1).toDouble();
      if (p.type == 'confetti') {
        canvas.save();
        canvas.translate(s.x, s.y);
        canvas.rotate(p.rot);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.r * 2, height: p.r),
            Paint()..color = p.color.withAlpha((alpha * 255).round()));
        canvas.restore();
      } else if (p.type == 'flame') {
        canvas.drawCircle(Offset(s.x, s.y), p.r,
            Paint()..color = p.color.withAlpha((alpha * 220).round())
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.r * 0.3));
      } else {
        canvas.drawCircle(Offset(s.x, s.y), p.r,
            Paint()..color = p.color.withAlpha((alpha * 150).round()));
      }
    }
  }

  // =========================================================
  //  BALL PIT
  // =========================================================
  static void _drawBallPitBackground(Canvas canvas, ClimbyGame g) {
    final bp = g.ballPit!;
    final ptTop = g.worldToScreen(0, bp.pitTop).y;
    final ptBot = g.worldToScreen(0, bp.pitBottom).y;
    final pl = g.worldToScreen(bp.pitLeft, 0).x;
    final pr = g.worldToScreen(bp.pitRight, 0).x;
    final pitH = ptBot - ptTop + 60;
    canvas.drawOval(Rect.fromCenter(center: Offset((pl + pr) / 2, ptBot + 35),
        width: (pr - pl) + 60, height: 28), Paint()..color = const Color(0x403A2E1F));
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

  static void _drawBallPitBalls(Canvas canvas, ClimbyGame g, {required bool behindPlayer}) {
    final bp = g.ballPit!;
    final balls = bp.balls.where((b) => behindPlayer ? b.depth < 0 : b.depth >= 0).toList();
    balls.sort((a, b) => b.y.compareTo(a.y));
    for (final ball in balls) {
      final s = g.worldToScreen(ball.x, ball.y);
      canvas.drawCircle(Offset(s.x + 2, s.y + 3), ball.r, Paint()..color = const Color(0x593A2E1F));
      canvas.drawCircle(Offset(s.x, s.y), ball.r, Paint()..color = ball.color);
      canvas.drawCircle(Offset(s.x, s.y), ball.r, Paint()..color = const Color(0xFF3A2E1F)
        ..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.drawCircle(Offset(s.x - ball.r * 0.35, s.y - ball.r * 0.35), ball.r * 0.35,
          Paint()..color = const Color(0x55FFFFFF));
    }
  }

  // =========================================================
  //  HUD
  // =========================================================
  static void _drawHUD(Canvas canvas, ClimbyGame g) {
    // Logo in top-right corner (small)
    final logoInfo = GameAssets.ui2('logo_climby');
    if (logoInfo != null) {
      _paintSvg(canvas, logoInfo,
          Rect.fromLTWH(g.size.x - 115, 8, 105, 32));
    }

    // Height box
    _drawHudBox(canvas, Rect.fromLTWH(12, 12, 110, 50));
    _drawText(canvas, 'ALTURA', 20, 18, color: const Color(0xFF3A2E1F), size: 10, weight: FontWeight.w700);
    _drawText(canvas, '${g.currentHeight.toStringAsFixed(1)}m', 20, 30,
        color: const Color(0xFF3A2E1F), size: 22, weight: FontWeight.w900);

    // Record box
    if (g.recordHeight > 0) {
      _drawHudBox(canvas, Rect.fromLTWH(12, 70, 110, 50));
      _drawText(canvas, 'RECORD', 20, 76, color: const Color(0xFF3A2E1F), size: 10, weight: FontWeight.w700);
      _drawText(canvas, '${g.recordHeight.toStringAsFixed(1)}m', 20, 88,
          color: const Color(0xFF3A2E1F), size: 22, weight: FontWeight.w900);
    }

    // Lava distance
    if (g.bossMode) {
      final start = g.level!.holds.first;
      final playerWorldY = start.y + g.maxHeight * 30;
      final lavaDistM = ((playerWorldY - g.lavaY) / 30).clamp(0.0, 999.0);
      _drawHudBox(canvas, Rect.fromLTWH(12, g.size.y - 100, 130, 36));
      _drawText(canvas, 'LAVA: ${lavaDistM.toStringAsFixed(1)}m', 22, g.size.y - 88,
          color: const Color(0xFFE85D3C), size: 13, weight: FontWeight.w900);
    }

    // Stamina HUD
    final cx = g.size.x / 2;
    final cy = g.size.y - 40;
    const colors = [Color(0xFFE85D3C), Color(0xFF4A7BA6), Color(0xFF5A8A3A), Color(0xFFF2B134)];
    const limbKeys = ['LH', 'RH', 'LF', 'RF'];
    _drawHudBox(canvas, Rect.fromCenter(center: Offset(cx, cy), width: 200, height: 50), radius: 20);
    for (int i = 0; i < 4; i++) {
      final dx = cx - 70 + i * 47;
      final stam = g.stamina[limbKeys[i]]!;
      canvas.drawCircle(Offset(dx, cy), 17,
          Paint()..color = const Color(0x66FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 3);
      final pct = stam / 100;
      Color ringColor = Colors.white;
      if (stam < 25) ringColor = const Color(0xFFD33333);
      else if (stam < 50) ringColor = const Color(0xFFF2B134);
      canvas.drawArc(Rect.fromCircle(center: Offset(dx, cy), radius: 17),
          -math.pi / 2, math.pi * 2 * pct, false,
          Paint()..color = ringColor..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(dx, cy), 11, Paint()..color = colors[i]);
      canvas.drawCircle(Offset(dx, cy), 11,
          Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  static void _drawHudBox(Canvas canvas, Rect rect, {double radius = 12}) {
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(RRect.fromRectAndRadius(rect.shift(const Offset(2, 2)), Radius.circular(radius)),
        Paint()..color = const Color(0xFF3A2E1F));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFF4EAD5));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 3);
  }

  // =========================================================
  //  WEATHER INDICATOR
  // =========================================================
  static void _drawWeatherIndicator(Canvas canvas, ClimbyGame g) {
    if (g.weather == WeatherType.none) return;
    final txt = g.weather == WeatherType.wind ? 'VIENTO'
        : g.weather == WeatherType.rain ? 'LLUVIA' : 'TORMENTA';
    final rect = Rect.fromLTWH(g.size.x - 120, g.size.y / 2 - 18, 110, 36);
    _drawHudBox(canvas, rect, radius: 10);
    _drawText(canvas, txt, g.size.x - 65, g.size.y / 2 - 8,
        color: const Color(0xFF3A2E1F), size: 12, weight: FontWeight.w900, align: TextAlign.center);
  }

  // =========================================================
  //  WIN BANNER (with trophy SVG)
  // =========================================================
  static void _drawWinBanner(Canvas canvas, ClimbyGame g) {
    final t = g.cinematicTimer.clamp(0, 1).toDouble();
    final scale = (t * 1.2).clamp(0.0, 1.0);
    canvas.save();
    canvas.translate(g.size.x / 2, g.size.y * 0.3);
    canvas.rotate(-0.08);
    canvas.scale(scale);
    final rect = Rect.fromCenter(center: Offset.zero, width: 260, height: 90);
    _drawHudBox(canvas, rect, radius: 20);
    // Trophy SVG
    final trophyInfo = GameAssets.ui2('trophy');
    if (trophyInfo != null) {
      _paintSvg(canvas, trophyInfo, Rect.fromCenter(center: const Offset(-95, 0), width: 50, height: 50));
    }
    _drawText(canvas, '¡CIMA!', 10, -18,
        color: const Color(0xFF3A2E1F), size: 32, weight: FontWeight.w900, align: TextAlign.center);
    canvas.restore();
  }
}
