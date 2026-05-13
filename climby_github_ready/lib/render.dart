import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'physics.dart';
import 'holds.dart';
import 'climby_game.dart';
import 'storage.dart';

class GameRenderer {
  static void render(Canvas canvas, ClimbyGame g) {
    if (g.shakeTime > 0) {
      final s = g.shakeIntensity * (g.shakeTime / 0.3);
      final dx = rnd(-s, s);
      final dy = rnd(-s, s);
      canvas.save();
      canvas.translate(dx, dy);
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

  static Color _darken(Color c, double f) {
    return Color.fromARGB(c.alpha,
        (c.red * f).round().clamp(0, 255),
        (c.green * f).round().clamp(0, 255),
        (c.blue * f).round().clamp(0, 255));
  }

  static Color _lighten(Color c, double f) {
    return Color.fromARGB(c.alpha,
        ((c.red + (255 - c.red) * f)).round().clamp(0, 255),
        ((c.green + (255 - c.green) * f)).round().clamp(0, 255),
        ((c.blue + (255 - c.blue) * f)).round().clamp(0, 255));
  }

  static void _drawBackground(Canvas canvas, ClimbyGame g) {
    final rect = Rect.fromLTWH(0, 0, g.size.x, g.size.y);
    Paint paint;
    if (g.weather == WeatherType.storm) {
      paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF2A2A3A), Color(0xFF5A5A6A), Color(0xFF3A3A45)],
        ).createShader(rect);
    } else if (g.weather == WeatherType.rain) {
      paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF5A6A78), Color(0xFFA3A89A), Color(0xFF7A7060)],
        ).createShader(rect);
    } else {
      paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFD6E4EC), Color(0xFFF4EAD5), Color(0xFFD8C89A)],
        ).createShader(rect);
    }
    canvas.drawRect(rect, paint);

    final brick = Paint()..color = const Color(0x143A2E1F);
    final camOffset = (g.camY * 0.5) % 80;
    for (int row = 0; row < 14; row++) {
      final y = (row * 80 + camOffset) % g.size.y;
      final shift = row.isEven ? 0.0 : 60.0;
      for (double x = -120 + shift; x < g.size.x + 120; x += 120) {
        final r = RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, 110, 30), const Radius.circular(4));
        canvas.drawRRect(r, brick);
      }
    }

    if (g.weather == WeatherType.rain || g.weather == WeatherType.storm) {
      final tNow = DateTime.now().millisecondsSinceEpoch / 1.0;
      final rainPaint = Paint()..color = const Color(0x994A7BA6)..strokeWidth = 1.5..strokeCap = StrokeCap.round;
      for (int i = 0; i < 30; i++) {
        final rx = (i * 73 + (tNow / 8) % 100) % g.size.x;
        final ry = ((i * 137 + tNow / 3) % (g.size.y + 60)) - 60;
        canvas.drawLine(Offset(rx, ry), Offset(rx + 4, ry + 16), rainPaint);
      }
    }

    if (g.weather == WeatherType.storm && g.flashTime > 0) {
      canvas.drawRect(rect, Paint()..color = Color.fromRGBO(255, 255, 255, g.flashTime * 0.6));
    }

    if (g.level != null) {
      final fy = g.size.y / 2 - (g.level!.finishY - g.camY) * g.cameraZoom;
      if (fy > -50 && fy < g.size.y + 50) {
        _drawDashedLine(canvas, Offset(0, fy), Offset(g.size.x, fy),
            Paint()..color = const Color(0xFF3A2E1F)..strokeWidth = 3, 10, 6);
        final rectMeta = Rect.fromCenter(
            center: Offset(g.size.x / 2, fy - 18), width: 130, height: 26);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rectMeta, const Radius.circular(8)),
            Paint()..color = const Color(0xFF3A2E1F));
        final innerMeta = Rect.fromCenter(
            center: Offset(g.size.x / 2, fy - 18), width: 124, height: 20);
        canvas.drawRRect(
            RRect.fromRectAndRadius(innerMeta, const Radius.circular(5)),
            Paint()..color = const Color(0xFFF2B134));
        _drawText(canvas, 'META', g.size.x / 2, fy - 26,
            color: const Color(0xFF3A2E1F), size: 13, weight: FontWeight.w900, align: TextAlign.center);
      }
    }
  }

  static void _drawDashedLine(Canvas c, Offset a, Offset b, Paint p, double dashW, double gap) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1) return;
    final ux = dx / len;
    final uy = dy / len;
    double drawn = 0;
    while (drawn < len) {
      final segEnd = math.min(drawn + dashW, len);
      c.drawLine(
        Offset(a.dx + ux * drawn, a.dy + uy * drawn),
        Offset(a.dx + ux * segEnd, a.dy + uy * segEnd), p);
      drawn = segEnd + gap;
    }
  }

  static void _drawText(Canvas canvas, String text, double x, double y,
      {Color color = Colors.black, double size = 14,
      FontWeight weight = FontWeight.normal, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(
          color: color, fontSize: size, fontWeight: weight)),
      textDirection: TextDirection.ltr, textAlign: align);
    tp.layout();
    double dx = x;
    if (align == TextAlign.center) dx -= tp.width / 2;
    tp.paint(canvas, Offset(dx, y));
  }

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

  static void _drawHold(Canvas canvas, Hold hold, double sx, double sy, double zoom) {
    final r = hold.r * zoom;
    final color = holdColor(hold.type);
    final dark = _darken(color, 0.7);
    final path = Path();
    const sides = 8;
    for (int i = 0; i < sides; i++) {
      final a = (i / sides) * math.pi * 2;
      final rr = r * (0.85 + math.sin(i * 1.3 + hold.x * 0.01) * 0.15);
      final px = sx + math.cos(a) * rr;
      final py = sy + math.sin(a) * rr;
      if (i == 0) path.moveTo(px, py); else path.lineTo(px, py);
    }
    path.close();

    canvas.drawPath(Path()..addPath(path, const Offset(3, 4)),
        Paint()..color = const Color(0x553A2E1F));
    canvas.drawPath(Path()..addPath(path, const Offset(2, 3)),
        Paint()..color = const Color(0x333A2E1F));

    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_lighten(color, 0.15), color, dark],
      ).createShader(Rect.fromCircle(center: Offset(sx, sy), radius: r)));
    canvas.drawPath(path, Paint()..color = const Color(0xFF3A2E1F)
        ..style = PaintingStyle.stroke..strokeWidth = 3..strokeJoin = StrokeJoin.round);

    final hlPath = Path()..addOval(Rect.fromCircle(
        center: Offset(sx - r * 0.3, sy - r * 0.3), radius: r * 0.4));
    canvas.drawPath(hlPath, Paint()..color = Colors.white.withOpacity(0.5));

    if (hold.type == HoldType.fragile && hold.hp < 2) {
      canvas.drawLine(
        Offset(sx - r * 0.5, sy - r * 0.3),
        Offset(sx + r * 0.4, sy + r * 0.5),
        Paint()..color = const Color(0xFF3A2E1F)..strokeWidth = 2);
      canvas.drawLine(
        Offset(sx + r * 0.1, sy - r * 0.4),
        Offset(sx - r * 0.2, sy + r * 0.3),
        Paint()..color = const Color(0xFF3A2E1F)..strokeWidth = 1.5);
    }

    if (hold.type == HoldType.magnet) {
      _drawMagnetIcon(canvas, sx, sy, r);
    } else if (hold.type == HoldType.bouncy) {
      _drawBouncyIcon(canvas, sx, sy, r);
    } else if (hold.type == HoldType.moving) {
      _drawMovingIcon(canvas, sx, sy, r);
    } else if (hold.type == HoldType.sticky) {
      _drawStickyIcon(canvas, sx, sy, r);
    } else if (hold.type == HoldType.slippery) {
      _drawSlipperyIcon(canvas, sx, sy, r);
    } else if (hold.type == HoldType.fragile) {
      _drawFragileIcon(canvas, sx, sy, r);
    }
  }

  static void _drawMagnetIcon(Canvas canvas, double sx, double sy, double r) {
    final iconR = r * 0.45;
    final p = Paint()..color = const Color(0xFFD33333)..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.18..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(sx - iconR, sy - iconR / 2)
      ..lineTo(sx - iconR, sy + iconR / 3)
      ..arcToPoint(Offset(sx + iconR, sy + iconR / 3),
          radius: Radius.circular(iconR), clockwise: false)
      ..lineTo(sx + iconR, sy - iconR / 2);
    canvas.drawPath(path, p);
    final whiteP = Paint()..color = Colors.white..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.18..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(sx - iconR, sy - iconR / 2),
        Offset(sx - iconR, sy - iconR), whiteP);
    canvas.drawLine(Offset(sx + iconR, sy - iconR / 2),
        Offset(sx + iconR, sy - iconR), whiteP);
  }

  static void _drawBouncyIcon(Canvas canvas, double sx, double sy, double r) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.15..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final s = r * 0.45;
    final path = Path()
      ..moveTo(sx - s * 0.6, sy + s * 0.5)
      ..lineTo(sx + s * 0.3, sy + s * 0.2)
      ..lineTo(sx - s * 0.3, sy - s * 0.2)
      ..lineTo(sx + s * 0.6, sy - s * 0.5);
    canvas.drawPath(path, p);
    final tip = Path()
      ..moveTo(sx + s * 0.6, sy - s * 0.5)
      ..lineTo(sx + s * 0.2, sy - s * 0.6)
      ..moveTo(sx + s * 0.6, sy - s * 0.5)
      ..lineTo(sx + s * 0.5, sy - s * 0.15);
    canvas.drawPath(tip, p);
  }

  static void _drawMovingIcon(Canvas canvas, double sx, double sy, double r) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.15..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final s = r * 0.5;
    canvas.drawLine(Offset(sx - s, sy), Offset(sx + s, sy), p);
    canvas.drawLine(Offset(sx - s, sy), Offset(sx - s * 0.5, sy - s * 0.4), p);
    canvas.drawLine(Offset(sx - s, sy), Offset(sx - s * 0.5, sy + s * 0.4), p);
    canvas.drawLine(Offset(sx + s, sy), Offset(sx + s * 0.5, sy - s * 0.4), p);
    canvas.drawLine(Offset(sx + s, sy), Offset(sx + s * 0.5, sy + s * 0.4), p);
  }

  static void _drawStickyIcon(Canvas canvas, double sx, double sy, double r) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.13..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    final hr = r * 0.45;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final a = (i / 6) * math.pi * 2 + math.pi / 6;
      final px = sx + math.cos(a) * hr;
      final py = sy + math.sin(a) * hr;
      if (i == 0) path.moveTo(px, py);
      else path.lineTo(px, py);
    }
    path.close();
    canvas.drawPath(path, p);
  }

  static void _drawSlipperyIcon(Canvas canvas, double sx, double sy, double r) {
    final p = Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.13..strokeCap = StrokeCap.round;
    final s = r * 0.5;
    final path = Path()
      ..moveTo(sx - s, sy - s * 0.2)
      ..quadraticBezierTo(sx - s * 0.3, sy - s * 0.6, sx, sy - s * 0.2)
      ..quadraticBezierTo(sx + s * 0.3, sy + s * 0.2, sx + s, sy - s * 0.2);
    canvas.drawPath(path, p);
    final path2 = Path()
      ..moveTo(sx - s, sy + s * 0.4)
      ..quadraticBezierTo(sx - s * 0.3, sy, sx, sy + s * 0.4)
      ..quadraticBezierTo(sx + s * 0.3, sy + s * 0.8, sx + s, sy + s * 0.4);
    canvas.drawPath(path2, p);
  }

  static void _drawFragileIcon(Canvas canvas, double sx, double sy, double r) {
    final p = Paint()..color = Colors.white..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.18..strokeCap = StrokeCap.round;
    final s = r * 0.4;
    canvas.drawLine(Offset(sx - s, sy - s), Offset(sx + s, sy + s), p);
    canvas.drawLine(Offset(sx + s, sy - s), Offset(sx - s, sy + s), p);
  }

  static void _drawLava(Canvas canvas, ClimbyGame g) {
    if (!g.bossMode) return;
    if (g.lavaY < -150) return;
    final ly = g.size.y / 2 - (g.lavaY - g.camY) * g.cameraZoom;
    if (ly > g.size.y + 100) return;
    final tNow = DateTime.now().millisecondsSinceEpoch / 200.0;
    final path = Path();
    path.moveTo(0, ly);
    for (double x = 0; x <= g.size.x; x += 20) {
      final wy = ly + math.sin(x * 0.05 + tNow) * 6;
      path.lineTo(x, wy);
    }
    path.lineTo(g.size.x, g.size.y + 50);
    path.lineTo(0, g.size.y + 50);
    path.close();
    canvas.drawPath(path, Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFFFFEB3B), Color(0xFFFF5722), Color(0xFFD32F2F), Color(0xFF5D2A0E)],
      ).createShader(Rect.fromLTWH(0, ly, g.size.x, g.size.y - ly + 100)));
    for (int i = 0; i < 7; i++) {
      final bx = (i * 137 + tNow * 5) % g.size.x;
      final by = ly + 20 + (i * 11) % 30;
      canvas.drawCircle(Offset(bx, by), 3 + (i % 3).toDouble(),
          Paint()..color = const Color(0xB3FFAA3A));
    }
    canvas.drawRect(Rect.fromLTWH(0, ly - 12, g.size.x, 12),
        Paint()..color = const Color(0x44FF9800));
  }

  static void _drawBurnEffect(Canvas canvas, ClimbyGame g) {
    final t = (g.burnTime / 2.5).clamp(0.0, 1.0);
    final shader = RadialGradient(
      center: Alignment.center,
      colors: [
        Colors.transparent,
        const Color(0x00FF5722),
        const Color(0xCC8B0000).withOpacity(0.5 * t),
      ],
      stops: const [0.4, 0.7, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, g.size.x, g.size.y));
    canvas.drawRect(Rect.fromLTWH(0, 0, g.size.x, g.size.y),
        Paint()..shader = shader);
  }

  static void _drawCharacter(Canvas canvas, ClimbyGame g) {
    final c = g.char;
    final cust = Prefs.customization;
    final br = (g.gripCountPublic() == 4 && g.dragLimb == null) ? g.breatheOffset : 0.0;

    final h = g.worldToScreen(c.head.x, c.head.y + br);
    final tt = g.worldToScreen(c.chest.x, c.chest.y + br * 0.5);
    final ls = g.worldToScreen(c.ls.x, c.ls.y + br * 0.5);
    final rs = g.worldToScreen(c.rs.x, c.rs.y + br * 0.5);
    final lp = g.worldToScreen(c.lp.x, c.lp.y);
    final rp = g.worldToScreen(c.rp.x, c.rp.y);
    final lh = g.worldToScreen(c.lh.x, c.lh.y);
    final rh = g.worldToScreen(c.rh.x, c.rh.y);
    final le = g.worldToScreen(c.le.x, c.le.y);
    final re = g.worldToScreen(c.re.x, c.re.y);
    final lf = g.worldToScreen(c.lf.x, c.lf.y);
    final rf = g.worldToScreen(c.rf.x, c.rf.y);
    final lk = g.worldToScreen(c.lk.x, c.lk.y);
    final rk = g.worldToScreen(c.rk.x, c.rk.y);

    Color skinOverride = cust.skin;
    Color shirtOverride = cust.shirt;
    Color shortsOverride = cust.shorts;
    Color hairOverride = cust.hair;
    if (g.faceState == FaceState.burning || g.faceState == FaceState.dead) {
      final t = (g.burnTime / 2.5).clamp(0.0, 1.0);
      skinOverride = Color.lerp(cust.skin, const Color(0xFF1A1A1A), t)!;
      shirtOverride = Color.lerp(cust.shirt, const Color(0xFF222222), t)!;
      shortsOverride = Color.lerp(cust.shorts, const Color(0xFF111111), t)!;
      hairOverride = Color.lerp(cust.hair, const Color(0xFF000000), t)!;
    }
    final overrideCust = _CustOverride(
      skin: skinOverride, shirt: shirtOverride, shorts: shortsOverride,
      shoes: cust.shoes, hair: hairOverride);

    drawCharacterAt(canvas,
      headPos: Offset(h.x, h.y),
      chestPos: Offset(tt.x, tt.y),
      lsPos: Offset(ls.x, ls.y), rsPos: Offset(rs.x, rs.y),
      lpPos: Offset(lp.x, lp.y), rpPos: Offset(rp.x, rp.y),
      lhPos: Offset(lh.x, lh.y), rhPos: Offset(rh.x, rh.y),
      lePos: Offset(le.x, le.y), rePos: Offset(re.x, re.y),
      lfPos: Offset(lf.x, lf.y), rfPos: Offset(rf.x, rf.y),
      lkPos: Offset(lk.x, lk.y), rkPos: Offset(rk.x, rk.y),
      cust: overrideCust,
      headR: 26.0 * g.cameraZoom,
      faceState: g.faceState,
      stamina: g.stamina,
      grips: g.grips,
      tNow: DateTime.now().millisecondsSinceEpoch / 1000.0,
      blinking: g.blinking,
    );

    for (final k in ['LH', 'RH', 'LF', 'RF']) {
      if (g.grips[k] != null) {
        final p = c.limbByKey(k);
        final s = g.worldToScreen(p.x, p.y);
        final isFoot = k.contains('F');
        canvas.drawCircle(Offset(s.x, s.y), isFoot ? 28 : 20,
            Paint()..color = const Color(0x665A8A3A)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      }
    }

    if (g.dragLimb != null) {
      final isArm = g.dragLimb == 'LH' || g.dragLimb == 'RH';
      final bm = bodyMultipliers(Prefs.customization.bodyType);
      final reach = (isArm ? kArmReachBase : kLegReachBase) * bm.reach;
      final anchor = c.anchorForLimb(g.dragLimb!);
      final s = g.worldToScreen(anchor.x, anchor.y);
      canvas.drawCircle(Offset(s.x, s.y), reach * g.cameraZoom,
          Paint()..color = const Color(0x333A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  // ============================================================
  // BEAN CHARACTER — Stumble Guys / Fall Guys style
  // Body is ONE single capsule shape (head + body merged visually)
  // No neck, short rounded arms/legs, big head feel, expressive face
  // ============================================================
  static void drawCharacterAt(Canvas canvas, {
    required Offset headPos,
    required Offset chestPos,
    required Offset lsPos, required Offset rsPos,
    required Offset lpPos, required Offset rpPos,
    required Offset lhPos, required Offset rhPos,
    required Offset lePos, required Offset rePos,
    required Offset lfPos, required Offset rfPos,
    required Offset lkPos, required Offset rkPos,
    required dynamic cust,
    required double headR,
    FaceState faceState = FaceState.neutral,
    Map<String, double>? stamina,
    Map<String, dynamic>? grips,
    double tNow = 0,
    double scale = 1.0,
    bool blinking = false,
  }) {
    final skin = cust.skin as Color;
    final shirt = cust.shirt as Color;
    final shorts = cust.shorts as Color;
    final shoeColor = cust.shoes as Color;
    final shoeDark = _darken(shoeColor, 0.65);
    final hair = cust.hair as Color;
    const ink = Color(0xFF3A2E1F);

    const limbColors = {
      'LH': Color(0xFFE85D3C),
      'RH': Color(0xFF4A7BA6),
      'LF': Color(0xFF5A8A3A),
      'RF': Color(0xFFF2B134),
    };

    final s = scale;

    // ===== 1. BACK ARM (right side) - short and rounded =====
    _drawBeanArm(canvas, rsPos, rePos, rhPos, skin, ink, s, isBack: true);

    // ===== 2. BACK LEG - short capsule =====
    _drawBeanLeg(canvas, rpPos, rkPos, rfPos, shorts, skin, ink, s, isBack: true);

    // ===== 3. BEAN BODY (single capsule, merges head + torso) =====
    // The "body" includes shirt area and rounded bottom (shorts integrated)
    // Compute body center between chest and pelvis
    final bodyTop = Offset(
        (lsPos.dx + rsPos.dx) / 2,
        (lsPos.dy + rsPos.dy) / 2 - 6 * s);
    final bodyBottom = Offset(
        (lpPos.dx + rpPos.dx) / 2,
        (lpPos.dy + rpPos.dy) / 2 + 8 * s);
    final bodyMidX = (bodyTop.dx + bodyBottom.dx) / 2;
    final bodyTopY = bodyTop.dy;
    final bodyBottomY = bodyBottom.dy;
    final bodyHeight = bodyBottomY - bodyTopY;
    final bodyWidth = 56.0 * s;

    // Shadow under body
    canvas.save();
    canvas.translate(2 * s, 3 * s);
    _drawBeanBody(canvas, bodyMidX, bodyTopY, bodyBottomY, bodyWidth,
        const Color(0x553A2E1F), const Color(0x00000000), s, shadow: true);
    canvas.restore();

    // Body fill (shirt color) + shorts band at bottom
    _drawBeanBody(canvas, bodyMidX, bodyTopY, bodyBottomY, bodyWidth,
        shirt, shorts, s);

    // Body outline
    final bodyPath = _buildBeanBodyPath(bodyMidX, bodyTopY, bodyBottomY, bodyWidth);
    canvas.drawPath(bodyPath, Paint()
      ..color = ink..style = PaintingStyle.stroke
      ..strokeWidth = 3 * s..strokeJoin = StrokeJoin.round);

    // Body highlight (top-left)
    final hlPath = Path()
      ..addOval(Rect.fromCenter(
          center: Offset(bodyMidX - bodyWidth * 0.22, bodyTopY + bodyHeight * 0.25),
          width: bodyWidth * 0.35, height: bodyHeight * 0.3));
    canvas.drawPath(hlPath, Paint()..color = Colors.white.withOpacity(0.18));

    // ===== 4. FRONT LEG =====
    _drawBeanLeg(canvas, lpPos, lkPos, lfPos, shorts, skin, ink, s, isBack: false);

    // ===== 5. FRONT ARM =====
    _drawBeanArm(canvas, lsPos, lePos, lhPos, skin, ink, s, isBack: false);

    // ===== 6. HANDS — round chunky mittens =====
    _drawBeanHand(canvas, lhPos, lePos, 'LH', skin, ink, limbColors['LH']!, s,
        stamina?['LH'] ?? 100, grips?['LH'] != null, tNow);
    _drawBeanHand(canvas, rhPos, rePos, 'RH', skin, ink, limbColors['RH']!, s,
        stamina?['RH'] ?? 100, grips?['RH'] != null, tNow);

    // ===== 7. FEET — chunky shoes with laces in front =====
    _drawBeanFoot(canvas, lfPos, 'LF', shoeColor, shoeDark, ink, limbColors['LF']!, s,
        stamina?['LF'] ?? 100, grips?['LF'] != null, tNow);
    _drawBeanFoot(canvas, rfPos, 'RF', shoeColor, shoeDark, ink, limbColors['RF']!, s,
        stamina?['RF'] ?? 100, grips?['RF'] != null, tNow);

    // ===== 8. HEAD + FACE (drawn LAST, always on top) =====
    // Bean characters have head merged into body but we still draw distinct head
    // for expressive face. Head sits at top of bean.
    final headCenter = Offset(headPos.dx, headPos.dy);

    // Head shadow
    canvas.drawCircle(headCenter + Offset(2 * s, 3 * s), headR,
        Paint()..color = const Color(0x553A2E1F));
    // Head
    canvas.drawCircle(headCenter, headR, Paint()..color = skin);
    // Head highlight
    canvas.drawCircle(
        Offset(headCenter.dx - headR * 0.3, headCenter.dy - headR * 0.35),
        headR * 0.4,
        Paint()..color = Colors.white.withOpacity(0.22));
    // Cheeks blush
    canvas.drawCircle(
        Offset(headCenter.dx - headR * 0.5, headCenter.dy + headR * 0.25),
        headR * 0.22,
        Paint()..color = const Color(0x55FF7EB9));
    canvas.drawCircle(
        Offset(headCenter.dx + headR * 0.5, headCenter.dy + headR * 0.25),
        headR * 0.22,
        Paint()..color = const Color(0x55FF7EB9));
    // Head outline
    canvas.drawCircle(headCenter, headR,
        Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 3 * s);

    // Hair (chunky cap shape, fits bean style)
    final hairPath = Path()
      ..moveTo(headCenter.dx - headR + 3 * s, headCenter.dy - 2 * s)
      ..quadraticBezierTo(headCenter.dx - headR - 3 * s, headCenter.dy - headR + 4 * s,
          headCenter.dx - headR * 0.5, headCenter.dy - headR - 2 * s)
      ..quadraticBezierTo(headCenter.dx, headCenter.dy - headR - 8 * s,
          headCenter.dx + headR * 0.5, headCenter.dy - headR - 2 * s)
      ..quadraticBezierTo(headCenter.dx + headR + 3 * s, headCenter.dy - headR + 4 * s,
          headCenter.dx + headR - 3 * s, headCenter.dy - 2 * s)
      ..quadraticBezierTo(headCenter.dx + headR - 8 * s, headCenter.dy - headR * 0.5,
          headCenter.dx + 10 * s, headCenter.dy - headR + 6 * s)
      ..quadraticBezierTo(headCenter.dx, headCenter.dy - headR + 10 * s,
          headCenter.dx - 10 * s, headCenter.dy - headR + 6 * s)
      ..quadraticBezierTo(headCenter.dx - headR + 8 * s, headCenter.dy - headR * 0.5,
          headCenter.dx - headR + 3 * s, headCenter.dy - 2 * s)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = hair);
    canvas.drawPath(hairPath, Paint()..color = ink..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s..strokeJoin = StrokeJoin.round);

    _drawBeanFace(canvas, headCenter.dx, headCenter.dy, headR, faceState, ink, s, blinking);
  }

  // === BEAN body path builder ===
  static Path _buildBeanBodyPath(double cx, double topY, double bottomY, double width) {
    final hw = width / 2;
    final r = width / 2;
    return Path()
      ..moveTo(cx - hw, topY + r * 0.4)
      ..quadraticBezierTo(cx - hw, topY, cx - hw + r * 0.6, topY)
      ..lineTo(cx + hw - r * 0.6, topY)
      ..quadraticBezierTo(cx + hw, topY, cx + hw, topY + r * 0.4)
      ..lineTo(cx + hw, bottomY - r * 0.6)
      ..quadraticBezierTo(cx + hw, bottomY, cx + hw - r * 0.6, bottomY)
      ..lineTo(cx - hw + r * 0.6, bottomY)
      ..quadraticBezierTo(cx - hw, bottomY, cx - hw, bottomY - r * 0.6)
      ..close();
  }

  static void _drawBeanBody(Canvas canvas, double cx, double topY, double bottomY,
      double width, Color shirt, Color shorts, double s, {bool shadow = false}) {
    final bodyPath = _buildBeanBodyPath(cx, topY, bottomY, width);
    if (shadow) {
      canvas.drawPath(bodyPath, Paint()..color = shirt);
      return;
    }
    // Fill with shirt color
    canvas.drawPath(bodyPath, Paint()..color = shirt);
    // Shorts band at bottom 30%
    final shortsHeight = (bottomY - topY) * 0.35;
    final shortsRect = Rect.fromLTRB(
        cx - width / 2 - 2, bottomY - shortsHeight, cx + width / 2 + 2, bottomY + 2);
    canvas.save();
    canvas.clipPath(bodyPath);
    canvas.drawRect(shortsRect, Paint()..color = shorts);
    canvas.restore();
  }

  static void _drawBeanArm(Canvas canvas, Offset shoulder, Offset elbow,
      Offset hand, Color skin, Color ink, double s, {required bool isBack}) {
    // Bean arms: short, rounded, two segments but visually continuous
    // Draw as thick rounded line from shoulder through elbow to hand
    final w = 16.0 * s;
    // Outline (slightly thicker, dark)
    canvas.drawLine(shoulder, elbow,
        Paint()..color = ink..strokeWidth = w + 5..strokeCap = StrokeCap.round);
    canvas.drawLine(elbow, hand,
        Paint()..color = ink..strokeWidth = w - 1 + 5..strokeCap = StrokeCap.round);
    // Fill
    canvas.drawLine(shoulder, elbow,
        Paint()..color = skin..strokeWidth = w..strokeCap = StrokeCap.round);
    canvas.drawLine(elbow, hand,
        Paint()..color = skin..strokeWidth = w - 1..strokeCap = StrokeCap.round);
  }

  static void _drawBeanLeg(Canvas canvas, Offset hip, Offset knee, Offset foot,
      Color shorts, Color skin, Color ink, double s, {required bool isBack}) {
    // Upper leg (shorts color)
    final w1 = 22.0 * s;
    canvas.drawLine(hip, knee,
        Paint()..color = ink..strokeWidth = w1 + 5..strokeCap = StrokeCap.round);
    canvas.drawLine(hip, knee,
        Paint()..color = shorts..strokeWidth = w1..strokeCap = StrokeCap.round);
    // Lower leg (skin color) - shorter
    final w2 = 20.0 * s;
    canvas.drawLine(knee, foot,
        Paint()..color = ink..strokeWidth = w2 + 5..strokeCap = StrokeCap.round);
    canvas.drawLine(knee, foot,
        Paint()..color = skin..strokeWidth = w2..strokeCap = StrokeCap.round);
  }

  static void _drawBeanHand(Canvas canvas, Offset hp, Offset elbow, String key,
      Color skin, Color ink, Color bandColor, double s,
      double stam, bool gripping, double tNow) {
    final cx = hp.dx;
    final cy = hp.dy;
    final vis = _staminaVisuals(stam, tNow);

    if (vis.ringAlpha > 0 && gripping) {
      canvas.drawCircle(Offset(cx, cy), 24 * vis.scale * s,
          Paint()..color = vis.glowColor.withOpacity(vis.ringAlpha)
            ..style = PaintingStyle.stroke..strokeWidth = 3);
    }

    final ang = math.atan2(hp.dy - elbow.dy, hp.dx - elbow.dx);

    // Shadow
    canvas.drawCircle(Offset(cx + 1.5 * s, cy + 2 * s), 14 * vis.scale * s,
        Paint()..color = const Color(0x553A2E1F));

    // Round chunky mitten (single circle, no fingers)
    canvas.drawCircle(Offset(cx, cy), 14 * vis.scale * s,
        Paint()..color = skin);
    // Highlight
    canvas.drawCircle(
        Offset(cx - 4 * s, cy - 4 * s), 5 * vis.scale * s,
        Paint()..color = Colors.white.withOpacity(0.3));
    // Outline
    canvas.drawCircle(Offset(cx, cy), 14 * vis.scale * s,
        Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 2.5 * s);

    // Wristband ring (color id) at the wrist (between elbow and hand)
    final wx = cx - math.cos(ang) * 13 * s;
    final wy = cy - math.sin(ang) * 13 * s;
    final cuffOpacity = vis.blink > 0.5 ? 0.3 : 1.0;
    canvas.save();
    canvas.translate(wx, wy);
    canvas.rotate(ang + math.pi / 2);
    // Thicker band
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 22 * s, height: 11 * s),
            Radius.circular(4 * s)),
        Paint()..color = bandColor.withOpacity(cuffOpacity));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: 22 * s, height: 11 * s),
            Radius.circular(4 * s)),
        Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 2 * s);
    // White stripe
    canvas.drawLine(Offset(-8 * s, 0), Offset(8 * s, 0),
        Paint()..color = Colors.white.withOpacity(cuffOpacity * 0.8)
          ..strokeWidth = 1.5 * s);
    canvas.restore();

    if (vis.glow > 0) {
      canvas.drawCircle(Offset(cx, cy), 18 * vis.scale * s,
          Paint()..color = vis.glowColor.withOpacity(vis.glow * 0.25));
    }
  }

  static void _drawBeanFoot(Canvas canvas, Offset fp, String key,
      Color shoeColor, Color shoeDark, Color ink, Color sockColor, double s,
      double stam, bool gripping, double tNow) {
    final isLeft = key == 'LF';
    final dir = isLeft ? -1 : 1;
    final cx = fp.dx;
    final cy = fp.dy;
    final vis = _staminaVisuals(stam, tNow);

    if (vis.ringAlpha > 0 && gripping) {
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy),
              width: 64 * vis.scale * s, height: 38 * vis.scale * s),
          Paint()..color = vis.glowColor.withOpacity(vis.ringAlpha)
            ..style = PaintingStyle.stroke..strokeWidth = 3);
    }

    final sockOpacity = vis.blink > 0.5 ? 0.3 : 1.0;

    // Sock (cuff above shoe)
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx - dir * 3 * s, cy - 16 * s),
                width: 22 * s, height: 13 * s),
            Radius.circular(3 * s)),
        Paint()..color = sockColor.withOpacity(sockOpacity));
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(cx - dir * 3 * s, cy - 16 * s),
                width: 22 * s, height: 13 * s),
            Radius.circular(3 * s)),
        Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 2 * s);
    // Sock band stripe
    canvas.drawLine(
        Offset(cx - dir * 3 * s - 8 * s, cy - 18 * s),
        Offset(cx - dir * 3 * s + 8 * s, cy - 18 * s),
        Paint()..color = Colors.white.withOpacity(sockOpacity * 0.8)
          ..strokeWidth = 1.5 * s);

    // CHUNKY BOOT/SHOE (rounded, like Stumble Guys feet)
    // Shadow
    final shoePath = Path()
      ..moveTo(cx + dir * 26 * s, cy + 8 * s)
      ..lineTo(cx - dir * 26 * s, cy + 6 * s)
      ..quadraticBezierTo(cx - dir * 32 * s, cy - 6 * s,
          cx - dir * 26 * s, cy - 14 * s)
      ..quadraticBezierTo(cx - dir * 10 * s, cy - 18 * s,
          cx + dir * 18 * s, cy - 12 * s)
      ..quadraticBezierTo(cx + dir * 30 * s, cy - 4 * s,
          cx + dir * 26 * s, cy + 8 * s)
      ..close();
    // Shadow first
    canvas.save();
    canvas.translate(2 * s, 3 * s);
    canvas.drawPath(shoePath, Paint()..color = const Color(0x553A2E1F));
    canvas.restore();
    // Fill
    canvas.drawPath(shoePath, Paint()..color = shoeColor);
    // Highlight gradient
    canvas.drawPath(shoePath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.35), Colors.transparent],
      ).createShader(shoePath.getBounds()));
    // Outline
    canvas.drawPath(shoePath, Paint()..color = ink..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s..strokeJoin = StrokeJoin.round);
    // Sole (darker bottom)
    canvas.drawLine(
        Offset(cx - dir * 26 * s, cy + 6 * s),
        Offset(cx + dir * 26 * s, cy + 8 * s),
        Paint()..color = shoeDark..strokeWidth = 5 * s..strokeCap = StrokeCap.round);

    // === LACE DOTS IN FRONT (drawn last so they're on top of shoe) ===
    final laceP = Paint()..color = Colors.white..style = PaintingStyle.fill;
    final laceLine = Paint()..color = Colors.white..strokeWidth = 1.5 * s..strokeCap = StrokeCap.round;
    final eye1 = Offset(cx - dir * 10 * s, cy - 10 * s);
    final eye2 = Offset(cx + dir * 4 * s, cy - 11 * s);
    final eye3 = Offset(cx + dir * 16 * s, cy - 8 * s);
    // Crossing lace lines
    canvas.drawLine(eye1, Offset(eye2.dx + dir * 4 * s, eye2.dy + 2 * s), laceLine);
    canvas.drawLine(eye2, Offset(eye3.dx - dir * 4 * s, eye3.dy + 2 * s), laceLine);
    // Dots on top
    for (final eye in [eye1, eye2, eye3]) {
      canvas.drawCircle(eye, 2 * s, laceP);
      canvas.drawCircle(eye, 2 * s,
          Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 0.8 * s);
    }

    if (vis.glow > 0) {
      canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, cy), width: 60 * vis.scale * s, height: 36 * vis.scale * s),
          Paint()..color = vis.glowColor.withOpacity(vis.glow * 0.25));
    }
  }

  static _StaminaVis _staminaVisuals(double stam, double t) {
    if (stam > 60) return _StaminaVis(0, 0, 1, 0, Colors.transparent);
    if (stam > 30) {
      final p = (math.sin(t * 4) + 1) / 2;
      return _StaminaVis(p * 0.3, 0, 1, 0.2, const Color(0xFFF2B134));
    }
    if (stam > 15) {
      final p = (math.sin(t * 7) + 1) / 2;
      return _StaminaVis(0.4 + p * 0.3, 0, 1 + p * 0.05, 0.5, const Color(0xFFE85D3C));
    }
    final p = (math.sin(t * 14) + 1) / 2;
    return _StaminaVis(0.7 + p * 0.3, p > 0.5 ? 1 : 0, 1 + p * 0.12, 0.8 + p * 0.2, const Color(0xFFD33333));
  }

  // === BEAN FACE — big expressive eyes, bigger emotions ===
  static void _drawBeanFace(Canvas canvas, double hx, double hy, double headR,
      FaceState face, Color ink, double s, bool blinking) {
    final eyeY = hy - headR * 0.08;
    final mouthY = hy + headR * 0.4;
    final eyeSep = headR * 0.35;
    final eyeSize = headR * 0.22;
    final inkP = Paint()..color = ink;

    if (face == FaceState.dead) {
      // X X eyes
      final p = Paint()..color = ink..strokeWidth = 2.5 * s..strokeCap = StrokeCap.round;
      final r = eyeSize * 0.8;
      canvas.drawLine(Offset(hx - eyeSep - r, eyeY - r),
          Offset(hx - eyeSep + r, eyeY + r), p);
      canvas.drawLine(Offset(hx - eyeSep - r, eyeY + r),
          Offset(hx - eyeSep + r, eyeY - r), p);
      canvas.drawLine(Offset(hx + eyeSep - r, eyeY - r),
          Offset(hx + eyeSep + r, eyeY + r), p);
      canvas.drawLine(Offset(hx + eyeSep - r, eyeY + r),
          Offset(hx + eyeSep + r, eyeY - r), p);
      final wave = Path()..moveTo(hx - headR * 0.25, mouthY)
        ..quadraticBezierTo(hx - headR * 0.12, mouthY + headR * 0.1, hx, mouthY)
        ..quadraticBezierTo(hx + headR * 0.12, mouthY - headR * 0.1, hx + headR * 0.25, mouthY);
      canvas.drawPath(wave, Paint()..color = ink..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s..strokeCap = StrokeCap.round);
    } else if (face == FaceState.burning) {
      // Wide scared eyes
      _drawWideEye(canvas, hx - eyeSep, eyeY, eyeSize, ink, s);
      _drawWideEye(canvas, hx + eyeSep, eyeY, eyeSize, ink, s);
      // Screaming mouth (oval with inner red)
      canvas.drawOval(
          Rect.fromCenter(center: Offset(hx, mouthY + 2 * s),
              width: headR * 0.45, height: headR * 0.55),
          Paint()..color = ink);
      canvas.drawOval(
          Rect.fromCenter(center: Offset(hx, mouthY + 4 * s),
              width: headR * 0.3, height: headR * 0.35),
          Paint()..color = const Color(0xFFE85D3C));
    } else if (face == FaceState.scared) {
      if (blinking) {
        _drawClosedEye(canvas, hx - eyeSep, eyeY, eyeSize, ink, s);
        _drawClosedEye(canvas, hx + eyeSep, eyeY, eyeSize, ink, s);
      } else {
        _drawWideEye(canvas, hx - eyeSep, eyeY, eyeSize, ink, s);
        _drawWideEye(canvas, hx + eyeSep, eyeY, eyeSize, ink, s);
      }
      // Small O mouth
      canvas.drawOval(
          Rect.fromCenter(center: Offset(hx, mouthY + 2 * s),
              width: headR * 0.25, height: headR * 0.3),
          Paint()..color = ink);
    } else if (face == FaceState.happy) {
      // Curved smile eyes
      final p = Paint()..color = ink..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s..strokeCap = StrokeCap.round;
      final eye1 = Path()
        ..moveTo(hx - eyeSep - eyeSize * 0.8, eyeY + eyeSize * 0.3)
        ..quadraticBezierTo(hx - eyeSep, eyeY - eyeSize * 0.9,
            hx - eyeSep + eyeSize * 0.8, eyeY + eyeSize * 0.3);
      canvas.drawPath(eye1, p);
      final eye2 = Path()
        ..moveTo(hx + eyeSep - eyeSize * 0.8, eyeY + eyeSize * 0.3)
        ..quadraticBezierTo(hx + eyeSep, eyeY - eyeSize * 0.9,
            hx + eyeSep + eyeSize * 0.8, eyeY + eyeSize * 0.3);
      canvas.drawPath(eye2, p);
      // Big smile
      final smile = Path()..moveTo(hx - headR * 0.3, mouthY)
        ..quadraticBezierTo(hx, mouthY + headR * 0.35,
            hx + headR * 0.3, mouthY);
      canvas.drawPath(smile, p);
    } else if (face == FaceState.focused) {
      // Determined slits
      final p = Paint()..color = ink..strokeWidth = 3 * s..strokeCap = StrokeCap.round;
      canvas.drawLine(
          Offset(hx - eyeSep - eyeSize * 0.7, eyeY),
          Offset(hx - eyeSep + eyeSize * 0.5, eyeY), p);
      canvas.drawLine(
          Offset(hx + eyeSep - eyeSize * 0.5, eyeY),
          Offset(hx + eyeSep + eyeSize * 0.7, eyeY), p);
      // Angled eyebrows
      canvas.drawLine(
          Offset(hx - eyeSep - eyeSize, eyeY - eyeSize * 1.3),
          Offset(hx - eyeSep + eyeSize * 0.5, eyeY - eyeSize * 0.7),
          Paint()..color = ink..strokeWidth = 2.5 * s..strokeCap = StrokeCap.round);
      canvas.drawLine(
          Offset(hx + eyeSep - eyeSize * 0.5, eyeY - eyeSize * 0.7),
          Offset(hx + eyeSep + eyeSize, eyeY - eyeSize * 1.3),
          Paint()..color = ink..strokeWidth = 2.5 * s..strokeCap = StrokeCap.round);
      // Straight mouth
      canvas.drawLine(
          Offset(hx - headR * 0.18, mouthY + 2 * s),
          Offset(hx + headR * 0.18, mouthY + 2 * s),
          Paint()..color = ink..strokeWidth = 3 * s..strokeCap = StrokeCap.round);
    } else {
      // Neutral - bigger anime-style eyes
      if (blinking) {
        _drawClosedEye(canvas, hx - eyeSep, eyeY, eyeSize, ink, s);
        _drawClosedEye(canvas, hx + eyeSep, eyeY, eyeSize, ink, s);
      } else {
        _drawNeutralEye(canvas, hx - eyeSep, eyeY, eyeSize, ink, s);
        _drawNeutralEye(canvas, hx + eyeSep, eyeY, eyeSize, ink, s);
      }
      // Small smile
      final smile = Path()..moveTo(hx - headR * 0.18, mouthY)
        ..quadraticBezierTo(hx, mouthY + headR * 0.12,
            hx + headR * 0.18, mouthY);
      canvas.drawPath(smile, Paint()..color = ink..style = PaintingStyle.stroke
        ..strokeWidth = 2.5 * s..strokeCap = StrokeCap.round);
    }
  }

  static void _drawNeutralEye(Canvas canvas, double cx, double cy,
      double size, Color ink, double s) {
    // White sclera + dark pupil + white shine
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: size * 1.5, height: size * 1.8),
        Paint()..color = Colors.white);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: size * 1.5, height: size * 1.8),
        Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 1.5 * s);
    canvas.drawCircle(Offset(cx, cy + size * 0.15), size * 0.6,
        Paint()..color = ink);
    canvas.drawCircle(Offset(cx - size * 0.2, cy - size * 0.05), size * 0.25,
        Paint()..color = Colors.white);
  }

  static void _drawWideEye(Canvas canvas, double cx, double cy,
      double size, Color ink, double s) {
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: size * 1.8, height: size * 2),
        Paint()..color = Colors.white);
    canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: size * 1.8, height: size * 2),
        Paint()..color = ink..style = PaintingStyle.stroke..strokeWidth = 2 * s);
    canvas.drawCircle(Offset(cx, cy), size * 0.5, Paint()..color = ink);
    canvas.drawCircle(Offset(cx - size * 0.2, cy - size * 0.1), size * 0.2,
        Paint()..color = Colors.white);
  }

  static void _drawClosedEye(Canvas canvas, double cx, double cy,
      double size, Color ink, double s) {
    final p = Paint()..color = ink..strokeWidth = 2 * s..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(cx - size * 0.7, cy),
        Offset(cx + size * 0.7, cy), p);
  }

  static void _drawParticles(Canvas canvas, ClimbyGame g) {
    for (final p in g.particles) {
      final s = g.worldToScreen(p.x, p.y);
      final alpha = p.life.clamp(0, 1).toDouble();
      if (p.type == 'confetti') {
        canvas.save();
        canvas.translate(s.x, s.y);
        canvas.rotate(p.rot);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.r * 2, height: p.r),
            Paint()..color = p.color.withOpacity(alpha));
        canvas.restore();
      } else if (p.type == 'dust') {
        canvas.drawCircle(Offset(s.x, s.y), p.r,
            Paint()..color = p.color.withOpacity(alpha * 0.6));
      } else if (p.type == 'flame') {
        canvas.drawCircle(Offset(s.x, s.y), p.r,
            Paint()..color = p.color.withOpacity(alpha * 0.85)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.r * 0.3));
      } else if (p.type == 'ash') {
        canvas.drawCircle(Offset(s.x, s.y), p.r,
            Paint()..color = p.color.withOpacity(alpha * 0.5));
      } else {
        canvas.drawCircle(Offset(s.x, s.y), p.r,
            Paint()..color = p.color.withOpacity(alpha));
      }
    }
  }

  static void _drawBallPitBackground(Canvas canvas, ClimbyGame g) {
    final bp = g.ballPit!;
    final ptTop = g.worldToScreen(0, bp.pitTop).y;
    final ptBot = g.worldToScreen(0, bp.pitBottom).y;
    final pl = g.worldToScreen(bp.pitLeft, 0).x;
    final pr = g.worldToScreen(bp.pitRight, 0).x;
    final pitH = ptBot - ptTop + 60;

    canvas.drawOval(
        Rect.fromCenter(center: Offset((pl + pr) / 2, ptBot + 35), width: (pr - pl) + 60, height: 28),
        Paint()..color = const Color(0x403A2E1F));

    final outerRect = Rect.fromLTWH(pl - 24, ptTop - 10, pr - pl + 48, pitH);
    canvas.drawRRect(RRect.fromRectAndRadius(outerRect, const Radius.circular(20)),
        Paint()..shader = const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF3D6890), Color(0xFF2A4A68)],
        ).createShader(outerRect));
    canvas.drawRRect(RRect.fromRectAndRadius(outerRect, const Radius.circular(20)),
        Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 4);

    final innerRect = Rect.fromLTWH(pl - 12, ptTop, pr - pl + 24, pitH - 14);
    canvas.drawRRect(RRect.fromRectAndRadius(innerRect, const Radius.circular(14)),
        Paint()..shader = const LinearGradient(
          colors: [Color(0xFF4A7BA6), Color(0xFF5A8FBF), Color(0xFF3D6890)],
        ).createShader(innerRect));

    for (double i = pl - 10; i < pr + 10; i += 18) {
      canvas.drawLine(Offset(i, ptTop - 4), Offset(i + 8, ptTop - 4),
          Paint()..color = const Color(0xB3FFFFFF)..strokeWidth = 2..strokeCap = StrokeCap.round);
    }
  }

  static void _drawBallPitBalls(Canvas canvas, ClimbyGame g, {required bool behindPlayer}) {
    final bp = g.ballPit!;
    final balls = bp.balls.where((b) =>
      behindPlayer ? b.depth < 0 : b.depth >= 0).toList();
    balls.sort((a, b) => b.y.compareTo(a.y));
    final ptBot = g.worldToScreen(0, bp.pitBottom).y;

    for (final ball in balls) {
      final sp = g.worldToScreen(ball.x, ball.y);
      final fy = ptBot;
      final heightAbove = fy - sp.y;
      if (heightAbove > 0 && heightAbove < 200) {
        final alpha = math.max(0.0, 0.3 - heightAbove / 800);
        final shR = ball.r * (1 - heightAbove / 400).clamp(0.0, 1.0);
        canvas.drawOval(
            Rect.fromCenter(center: Offset(sp.x, fy + 5), width: shR * 2, height: shR * 0.6),
            Paint()..color = Colors.black.withOpacity(alpha));
      }
    }

    for (final ball in balls) {
      final sp = g.worldToScreen(ball.x, ball.y);
      final dark = _darken(ball.color, 0.7);
      canvas.drawCircle(Offset(sp.x + 2, sp.y + 3), ball.r, Paint()..color = const Color(0x593A2E1F));
      canvas.drawCircle(Offset(sp.x, sp.y), ball.r, Paint()..color = ball.color);
      canvas.drawCircle(Offset(sp.x, sp.y), ball.r,
          Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2.5);
      final hlRect = Rect.fromCircle(
          center: Offset(sp.x - ball.r * 0.35, sp.y - ball.r * 0.35), radius: ball.r * 0.45);
      canvas.drawCircle(Offset(sp.x - ball.r * 0.35, sp.y - ball.r * 0.35), ball.r * 0.45,
          Paint()..shader = RadialGradient(colors: [
              Colors.white.withOpacity(0.7), Colors.white.withOpacity(0)
          ]).createShader(hlRect));
      canvas.drawArc(
          Rect.fromCircle(center: Offset(sp.x, sp.y), radius: ball.r * 0.9),
          0.3, math.pi - 0.6, false,
          Paint()..color = dark.withOpacity(0.35)..style = PaintingStyle.stroke..strokeWidth = ball.r * 0.5);
    }
  }

  static void _drawHUD(Canvas canvas, ClimbyGame g) {
    final boxRect = Rect.fromLTWH(12, 12, 110, 50);
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect.shift(const Offset(2, 2)),
        const Radius.circular(12)), Paint()..color = const Color(0xFF3A2E1F));
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(12)),
        Paint()..color = const Color(0xFFF4EAD5));
    canvas.drawRRect(RRect.fromRectAndRadius(boxRect, const Radius.circular(12)),
        Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 3);
    _drawText(canvas, 'ALTURA', 20, 18,
        color: const Color(0xFF3A2E1F), size: 10, weight: FontWeight.w700);
    _drawText(canvas, '${g.currentHeight.toStringAsFixed(1)}m', 20, 30,
        color: const Color(0xFF3A2E1F), size: 22, weight: FontWeight.w900);

    if (g.recordHeight > 0) {
      final rRect = Rect.fromLTWH(12, 70, 110, 50);
      canvas.drawRRect(RRect.fromRectAndRadius(rRect.shift(const Offset(2, 2)),
          const Radius.circular(12)), Paint()..color = const Color(0xFF3A2E1F));
      canvas.drawRRect(RRect.fromRectAndRadius(rRect, const Radius.circular(12)),
          Paint()..color = const Color(0xFFF4EAD5));
      canvas.drawRRect(RRect.fromRectAndRadius(rRect, const Radius.circular(12)),
          Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 3);
      _drawText(canvas, 'RECORD', 20, 76,
          color: const Color(0xFF3A2E1F), size: 10, weight: FontWeight.w700);
      _drawText(canvas, '${g.recordHeight.toStringAsFixed(1)}m', 20, 88,
          color: const Color(0xFF3A2E1F), size: 22, weight: FontWeight.w900);
    }

    if (g.bossMode) {
      final start = g.level!.holds.first;
      final playerWorldY = start.y + g.maxHeight * 30;
      final lavaDistM = ((playerWorldY - g.lavaY) / 30).clamp(0.0, 999.0);
      final lavaRect = Rect.fromLTWH(12, g.size.y - 100, 130, 36);
      canvas.drawRRect(RRect.fromRectAndRadius(lavaRect.shift(const Offset(2, 2)),
          const Radius.circular(12)), Paint()..color = const Color(0xFF3A2E1F));
      canvas.drawRRect(RRect.fromRectAndRadius(lavaRect, const Radius.circular(12)),
          Paint()..color = const Color(0xFFF4EAD5));
      canvas.drawRRect(RRect.fromRectAndRadius(lavaRect, const Radius.circular(12)),
          Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 3);
      _drawText(canvas, 'LAVA: ${lavaDistM.toStringAsFixed(1)}m',
          22, g.size.y - 88, color: const Color(0xFFE85D3C), size: 13, weight: FontWeight.w900);
    }

    final cx = g.size.x / 2;
    final cy = g.size.y - 40;
    const colors = [
      Color(0xFFE85D3C), Color(0xFF4A7BA6),
      Color(0xFF5A8A3A), Color(0xFFF2B134),
    ];
    const limbKeys = ['LH', 'RH', 'LF', 'RF'];
    final bgRect = Rect.fromCenter(center: Offset(cx, cy), width: 200, height: 50);
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect.shift(const Offset(2, 2)),
        const Radius.circular(20)), Paint()..color = const Color(0xFF3A2E1F));
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(20)),
        Paint()..color = const Color(0xFFF4EAD5));
    canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(20)),
        Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 3);

    for (int i = 0; i < 4; i++) {
      final dx = cx - 70 + i * 47;
      final stam = g.stamina[limbKeys[i]]!;
      canvas.drawCircle(Offset(dx, cy), 17,
          Paint()..color = const Color(0x66FFFFFF)..style = PaintingStyle.stroke..strokeWidth = 3);
      final pct = stam / 100;
      Color ringColor = Colors.white;
      if (stam < 25) {
        ringColor = const Color(0xFFD33333);
      } else if (stam < 50) {
        ringColor = const Color(0xFFF2B134);
      }
      canvas.drawArc(
          Rect.fromCircle(center: Offset(dx, cy), radius: 17),
          -math.pi / 2, math.pi * 2 * pct, false,
          Paint()..color = ringColor..style = PaintingStyle.stroke..strokeWidth = 3..strokeCap = StrokeCap.round);
      canvas.drawCircle(Offset(dx, cy), 11, Paint()..color = colors[i]);
      canvas.drawCircle(Offset(dx, cy), 11,
          Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  static void _drawWeatherIndicator(Canvas canvas, ClimbyGame g) {
    if (g.weather == WeatherType.none) return;
    final txt = g.weather == WeatherType.wind ? 'VIENTO' :
                g.weather == WeatherType.rain ? 'LLUVIA' : 'TORMENTA';
    final rect = Rect.fromLTWH(g.size.x - 120, g.size.y / 2 - 18, 110, 36);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.shift(const Offset(2, 2)),
        const Radius.circular(10)), Paint()..color = const Color(0xFF3A2E1F));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()..color = const Color(0xFFF4EAD5));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2.5);
    _drawText(canvas, txt, g.size.x - 65, g.size.y / 2 - 8,
        color: const Color(0xFF3A2E1F), size: 12, weight: FontWeight.w900, align: TextAlign.center);
  }

  static void _drawWinBanner(Canvas canvas, ClimbyGame g) {
    final t = g.cinematicTimer.clamp(0, 1).toDouble();
    final scale = (t * 1.2).clamp(0.0, 1.0);
    final cx = g.size.x / 2;
    final cy = g.size.y * 0.3;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-0.08);
    canvas.scale(scale);
    final rect = Rect.fromCenter(center: Offset.zero, width: 240, height: 80);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.shift(const Offset(4, 4)),
        const Radius.circular(20)), Paint()..color = const Color(0xFF3A2E1F));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)),
        Paint()..color = const Color(0xFFF2B134));
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)),
        Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 4);
    _drawText(canvas, 'CIMA!', 0, -16,
        color: const Color(0xFF3A2E1F), size: 32, weight: FontWeight.w900, align: TextAlign.center);
    canvas.restore();
  }
}

class _CustOverride {
  final Color skin, shirt, shorts, shoes, hair;
  _CustOverride({
    required this.skin, required this.shirt, required this.shorts,
    required this.shoes, required this.hair,
  });
}

class _StaminaVis {
  final double glow;
  final double blink;
  final double scale;
  final double ringAlpha;
  final Color glowColor;
  _StaminaVis(this.glow, this.blink, this.scale, this.ringAlpha, this.glowColor);
}
