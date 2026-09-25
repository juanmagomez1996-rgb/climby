part of 'render.dart';

// =========================================================
//  TrampolineRenderer — dibuja el modo TRAMPOLÍN
// =========================================================
class TrampolineRenderer {
  static const _ink = Color(0xFF3A2E1F);
  static const _botNames = ['', 'Rocco', 'Lupe'];

  static Color skinFor(Jumper j) {
    if (j.isPlayer) return Prefs.customization.skin;
    return j.colorIndex == 1 ? const Color(0xFFE0AC69) : const Color(0xFF8D5524);
  }

  static Offset _o(TrampolineGame g, double x, double y) {
    final v = g.worldToScreen(x, y);
    return Offset(v.x, v.y);
  }

  static void render(Canvas canvas, TrampolineGame g) {
    final shaking = g.shakeTime > 0;
    if (shaking) {
      final s = g.shakeIntensity * (g.shakeTime / 0.3).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(rnd(-s, s), rnd(-s, s));
    }
    _drawSky(canvas, g);
    _drawGround(canvas, g);
    _drawJudgesTable(canvas, g);
    _drawTower(canvas, g);
    _drawTrampoline(canvas, g);
    _drawItems(canvas, g);
    for (final b in g.sim.bots) {
      _drawJumper(canvas, g, b);
    }
    _drawJumper(canvas, g, g.sim.player);
    _drawParticles(canvas, g);
    _drawTexts(canvas, g);
    if (shaking) canvas.restore();
    _drawHUD(canvas, g);
  }

  // ---- FONDO ----
  static void _drawSky(Canvas canvas, TrampolineGame g) {
    final rect = Rect.fromLTWH(0, 0, g.size.x, g.size.y);
    canvas.drawRect(rect, Paint()
      ..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF9CC8E4), Color(0xFFD6E4EC), Color(0xFFF4EAD5)]).createShader(rect));
    // Nubes con paralaje
    final cp = Paint()..color = const Color(0xCCFFFFFF);
    for (int i = 0; i < 6; i++) {
      final wx = -500.0 + i * 230;
      final wy = 250.0 + (i * 173 % 700);
      final sx = g.size.x / 2 + (wx - g.camX * 0.4) * g.zoom;
      final sy = g.size.y / 2 - (wy - g.camY * 0.6) * g.zoom;
      final r = 26 * g.zoom + 10;
      canvas.drawCircle(Offset(sx, sy), r, cp);
      canvas.drawCircle(Offset(sx + r, sy + r * 0.2), r * 0.8, cp);
      canvas.drawCircle(Offset(sx - r, sy + r * 0.25), r * 0.7, cp);
    }
  }

  static void _drawGround(Canvas canvas, TrampolineGame g) {
    final gy = g.worldToScreen(0, kGroundY).y;
    if (gy > g.size.y) return;
    final r = Rect.fromLTWH(0, gy, g.size.x, g.size.y - gy + 10);
    canvas.drawRect(r, Paint()..color = const Color(0xFF7CB35B));
    canvas.drawRect(Rect.fromLTWH(0, gy, g.size.x, 6 * g.zoom + 2), Paint()..color = const Color(0xFF5A8A3A));
    canvas.drawLine(Offset(0, gy), Offset(g.size.x, gy), Paint()..color = _ink..strokeWidth = 3);
  }

  static void _drawJudgesTable(Canvas canvas, TrampolineGame g) {
    final z = g.zoom;
    const faces = ['🧐', '😎', '🤡', '🎨', '👴'];
    final tl = _o(g, 330, kGroundY + 60);
    final br = _o(g, 600, kGroundY);
    // Cabezas de los jueces
    for (int i = 0; i < 5; i++) {
      final p = _o(g, 355.0 + i * 55, kGroundY + 88);
      final bob = math.sin(g.sim.clock * 3 + i) * 2 * z;
      canvas.drawCircle(p.translate(0, bob), 20 * z, Paint()..color = const Color(0xFFF4EAD5));
      canvas.drawCircle(p.translate(0, bob), 20 * z, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2);
      GameRenderer._text(canvas, faces[i], p.dx, p.dy + bob - 15 * z, s: 26 * z, a: TextAlign.center);
    }
    final table = Rect.fromPoints(tl, br);
    canvas.drawRRect(RRect.fromRectAndRadius(table, Radius.circular(6 * z)), Paint()..color = const Color(0xFF8B5FBF));
    canvas.drawRRect(RRect.fromRectAndRadius(table, Radius.circular(6 * z)),
        Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 3);
    GameRenderer._text(canvas, 'JUECES', table.center.dx, table.center.dy - 11 * z,
        cc: Colors.white, s: 20 * z, w: FontWeight.w900, a: TextAlign.center);
  }

  static void _drawTower(Canvas canvas, TrampolineGame g) {
    final z = g.zoom;
    final tl = _o(g, kTowerLeft, kTowerTop);
    final br = _o(g, kTowerRight, kGroundY);
    final r = Rect.fromPoints(tl, br);
    canvas.drawRect(r, Paint()..color = const Color(0xFFB5835A));
    // Ladrillos de plastilina
    final bp = Paint()..color = const Color(0x333A2E1F)..strokeWidth = 2;
    for (double y = kGroundY + 40; y < kTowerTop; y += 40) {
      final a = _o(g, kTowerLeft, y);
      final b = _o(g, kTowerRight, y);
      canvas.drawLine(a, b, bp);
      final off = ((y - kGroundY) / 40).round().isEven ? 0.0 : 35.0;
      for (double x = kTowerLeft + 35 + off; x < kTowerRight; x += 70) {
        canvas.drawLine(_o(g, x, y), _o(g, x, y + 40), bp);
      }
    }
    canvas.drawRect(r, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 3);
    // Plataforma
    final plat = Rect.fromPoints(_o(g, kTowerLeft - 12, kTowerTop + 14), _o(g, kTowerRight + 12, kTowerTop));
    canvas.drawRRect(RRect.fromRectAndRadius(plat, Radius.circular(5 * z)), Paint()..color = const Color(0xFFE85D3C));
    canvas.drawRRect(RRect.fromRectAndRadius(plat, Radius.circular(5 * z)),
        Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 3);
    // Bandera
    final pole0 = _o(g, kTowerLeft + 20, kTowerTop + 14);
    final pole1 = _o(g, kTowerLeft + 20, kTowerTop + 130);
    canvas.drawLine(pole0, pole1, Paint()..color = _ink..strokeWidth = 4 * z + 1);
    final wave = math.sin(g.sim.clock * 5) * 6 * z;
    final flag = Path()
      ..moveTo(pole1.dx, pole1.dy)
      ..quadraticBezierTo(pole1.dx + 30 * z, pole1.dy + 8 * z + wave, pole1.dx + 55 * z, pole1.dy + 18 * z)
      ..lineTo(pole1.dx, pole1.dy + 36 * z)
      ..close();
    canvas.drawPath(flag, Paint()..color = const Color(0xFFF2B134));
    canvas.drawPath(flag, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2);
    final label = _o(g, (kTowerLeft + kTowerRight) / 2, kTowerTop - 40);
    GameRenderer._text(canvas, '${(kTowerTop / kUnitsPerMeter).round()} m', label.dx, label.dy,
        cc: Colors.white, s: 22 * z, w: FontWeight.w900, a: TextAlign.center);
  }

  static void _drawTrampoline(Canvas canvas, TrampolineGame g) {
    final z = g.zoom;
    final bed = g.sim.bed;
    // Patas
    final legP = Paint()..color = _ink..strokeWidth = 7 * z + 2..strokeCap = StrokeCap.round;
    for (final x in [kBedLeft - 20, -90.0, 90.0, kBedRight + 20]) {
      canvas.drawLine(_o(g, x, kBedY - 8), _o(g, x + (x < 0 ? -18 : 18), kGroundY), legP);
    }
    // Marco con acolchado
    final padP = Paint()..color = const Color(0xFF4A7BA6)..strokeWidth = 16 * z + 3..strokeCap = StrokeCap.round;
    final padO = Paint()..color = _ink..strokeWidth = 16 * z + 7..strokeCap = StrokeCap.round;
    for (final seg in [[kBedLeft - 34, kBedLeft + 4], [kBedRight - 4, kBedRight + 34]]) {
      canvas.drawLine(_o(g, seg[0], kBedY - 4), _o(g, seg[1], kBedY - 4), padO);
      canvas.drawLine(_o(g, seg[0], kBedY - 4), _o(g, seg[1], kBedY - 4), padP);
    }
    // Lona
    final path = Path();
    for (int i = 0; i < TrampolineBed.n; i++) {
      final p = _o(g, bed.nodeX(i), bed.y[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 10 * z + 4
      ..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
    canvas.drawPath(path, Paint()..color = const Color(0xFF2E2E40)..style = PaintingStyle.stroke..strokeWidth = 10 * z
      ..strokeJoin = StrokeJoin.round);
    canvas.drawPath(path.shift(Offset(0, -2 * z)), Paint()..color = const Color(0x66FFFFFF)..style = PaintingStyle.stroke
      ..strokeWidth = 2 * z);
  }

  static void _drawItems(Canvas canvas, TrampolineGame g) {
    final z = g.zoom;
    final t = g.sim.clock;
    for (final it in g.sim.items) {
      if (!it.alive) continue;
      final p = _o(g, it.x, it.y(t));
      if (p.dy < -60 || p.dy > g.size.y + 60) continue;
      if (it.kind == 'star') {
        final r = it.r * z;
        final path = Path();
        for (int i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5 + t * 1.5;
          final rr = i.isEven ? r : r * 0.45;
          final x = p.dx + math.cos(a) * rr, y = p.dy + math.sin(a) * rr;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, Paint()..color = const Color(0xFFF2B134));
        canvas.drawPath(path, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2.5..strokeJoin = StrokeJoin.round);
      } else {
        final col = (it.phase * 10).round().isEven ? const Color(0xFFFF7EB9) : const Color(0xFF7FC7E5);
        final body = Rect.fromCenter(center: p, width: it.r * 1.6 * z, height: it.r * 2 * z);
        final sBase = Offset(p.dx, body.bottom);
        final string = Path()
          ..moveTo(sBase.dx, sBase.dy)
          ..quadraticBezierTo(sBase.dx + 8 * z * math.sin(t * 3), sBase.dy + 18 * z, sBase.dx, sBase.dy + 36 * z);
        canvas.drawPath(string, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 1.5);
        canvas.drawOval(body, Paint()..color = col);
        canvas.drawOval(body, Paint()..color = _ink..style = PaintingStyle.stroke..strokeWidth = 2.5);
        canvas.drawCircle(Offset(body.left + body.width * 0.3, body.top + body.height * 0.28), 4 * z,
            Paint()..color = const Color(0x88FFFFFF));
      }
    }
  }

  // ---- MUÑECOS ----
  static FaceState _face(JumperFace f) {
    switch (f) {
      case JumperFace.focused:
        return FaceState.focused;
      case JumperFace.scared:
        return FaceState.scared;
      case JumperFace.happy:
        return FaceState.happy;
      case JumperFace.dead:
        return FaceState.dead;
      case JumperFace.neutral:
        return FaceState.neutral;
    }
  }

  static void _drawJumper(Canvas canvas, TrampolineGame g, Jumper j) {
    final z = g.zoom;
    Offset o(Point p) => _o(g, p.x, p.y);

    Color? skinT, shirtT, shortsT, shoeT;
    if (j.isPlayer) {
      final cust = Prefs.customization;
      final d = Customization();
      if (cust.skin != d.skin) skinT = cust.skin;
      if (cust.shirt != d.shirt) shirtT = cust.shirt;
      if (cust.shorts != d.shorts) shortsT = cust.shorts;
      if (cust.shoes != d.shoes) shoeT = cust.shoes;
    } else if (j.colorIndex == 1) {
      skinT = const Color(0xFFE0AC69);
      shirtT = const Color(0xFF4A7BA6);
      shortsT = const Color(0xFFF2B134);
      shoeT = const Color(0xFFE85D3C);
    } else {
      skinT = const Color(0xFF8D5524);
      shirtT = const Color(0xFF5A8A3A);
      shortsT = const Color(0xFF8B5FBF);
      shoeT = const Color(0xFF4A7BA6);
    }

    final sc = z;
    final lp = o(j.lp), rp = o(j.rp);
    final pelvis = Offset((lp.dx + rp.dx) / 2, (lp.dy + rp.dy) / 2);

    // Brazo y pierna de atrás (derechos)
    GameRenderer._bone(canvas, GameAssets.char('arm_upper'), o(j.rar), o(j.re), 96 * sc, 145 * sc, tint: skinT);
    GameRenderer._bone(canvas, GameAssets.char('arm_lower'), o(j.re), o(j.rh), 88 * sc, 144 * sc, tint: skinT);
    GameRenderer._bone(canvas, GameAssets.char('leg_upper'), o(j.rlr), o(j.rk), 104 * sc, 150 * sc, tint: shortsT);
    GameRenderer._bone(canvas, GameAssets.char('leg_lower'), o(j.rk), o(j.rf), 92 * sc, 150 * sc, tint: skinT);
    // Torso y pantalón
    GameRenderer._bone(canvas, GameAssets.char('torso'), o(j.chest), pelvis, 80 * sc, 155 * sc, pivotY: 0.10, tint: shirtT);
    final dir = Offset(pelvis.dx - o(j.chest).dx, pelvis.dy - o(j.chest).dy);
    final dl = dir.distance.clamp(0.001, double.infinity);
    final sEnd = pelvis + dir / dl * 15 * sc;
    GameRenderer._bone(canvas, GameAssets.char('shorts'), pelvis, sEnd, 80 * sc, 115 * sc, pivotY: 0.02, tint: shortsT);
    // Pierna y brazo de delante (izquierdos)
    GameRenderer._bone(canvas, GameAssets.char('leg_upper'), o(j.llr), o(j.lk), 104 * sc, 150 * sc, tint: shortsT);
    GameRenderer._bone(canvas, GameAssets.char('leg_lower'), o(j.lk), o(j.lf), 92 * sc, 150 * sc, tint: skinT);
    GameRenderer._bone(canvas, GameAssets.char('arm_upper'), o(j.lar), o(j.le), 96 * sc, 145 * sc, tint: skinT);
    GameRenderer._bone(canvas, GameAssets.char('arm_lower'), o(j.le), o(j.lh), 88 * sc, 144 * sc, tint: skinT);
    // Manos
    final lh = o(j.lh), rh = o(j.rh), le = o(j.le), re = o(j.re);
    GameRenderer._at(canvas, GameAssets.char('hand_right'), lh, 48 * sc, aspect: 98.0 / 122,
        rotation: math.atan2(lh.dy - le.dy, lh.dx - le.dx) - math.pi / 2, tint: skinT);
    GameRenderer._at(canvas, GameAssets.char('hand_left'), rh, 48 * sc, aspect: -102.0 / 122,
        rotation: math.atan2(rh.dy - re.dy, rh.dx - re.dx) - math.pi / 2, tint: skinT);
    // Pies
    final lf = o(j.lf), rf = o(j.rf), lk = o(j.lk), rk = o(j.rk);
    GameRenderer._at(canvas, GameAssets.char('foot_left'), lf, 55 * sc, aspect: 146.0 / 130,
        rotation: math.atan2(lf.dy - lk.dy, lf.dx - lk.dx) - math.pi / 2, tint: shoeT);
    GameRenderer._at(canvas, GameAssets.char('foot_right'), rf, 55 * sc, aspect: -145.0 / 130,
        rotation: math.atan2(rf.dy - rk.dy, rf.dx - rk.dx) - math.pi / 2, tint: shoeT);
    // Cabeza: gira con el cuerpo; si salió volando, da vueltas
    final hp = o(j.head), np = o(j.neck);
    double headRot = math.atan2(hp.dy - np.dy, hp.dx - np.dx) + math.pi / 2;
    if (!j.partAttached('HEAD')) headRot = g.sim.clock * 9;
    GameRenderer._at(canvas, GameRenderer._headImg(_face(j.face)), hp, 55 * sc, aspect: 153.0 / 148,
        rotation: headRot, tint: skinT);

    if (!j.isPlayer && j.colorIndex < _botNames.length) {
      GameRenderer._text(canvas, _botNames[j.colorIndex], hp.dx, hp.dy - 48 * z,
          cc: _ink, s: 13, w: FontWeight.w800, a: TextAlign.center);
    }
  }

  // ---- EFECTOS ----
  static void _drawParticles(Canvas canvas, TrampolineGame g) {
    for (final p in g.particles) {
      final s = _o(g, p.x, p.y);
      final a = p.life.clamp(0.0, 1.0);
      if (p.type == 'confetti') {
        canvas.save();
        canvas.translate(s.dx, s.dy);
        canvas.rotate(p.rot);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: p.r * 2, height: p.r),
            Paint()..color = p.color.withAlpha((a * 255).round()));
        canvas.restore();
      } else {
        canvas.drawCircle(s, p.r, Paint()..color = p.color.withAlpha((a * 230).round()));
      }
    }
  }

  static void _drawTexts(Canvas canvas, TrampolineGame g) {
    for (final t in g.texts) {
      final s = _o(g, t.x, t.y);
      final a = (t.life / 0.4).clamp(0.0, 1.0);
      GameRenderer._text(canvas, t.text, s.dx + 2, s.dy + 2,
          cc: _ink.withAlpha((a * 255).round()), s: t.size, w: FontWeight.w900, a: TextAlign.center);
      GameRenderer._text(canvas, t.text, s.dx, s.dy,
          cc: t.color.withAlpha((a * 255).round()), s: t.size, w: FontWeight.w900, a: TextAlign.center);
    }
  }

  // ---- HUD ----
  static void _drawHUD(Canvas canvas, TrampolineGame g) {
    final sim = g.sim;
    GameRenderer._hudBox(canvas, const Rect.fromLTWH(12, 12, 118, 50));
    GameRenderer._text(canvas, 'PUNTOS', 20, 18, cc: _ink, s: 10, w: FontWeight.w700);
    GameRenderer._text(canvas, '${sim.score}', 20, 30, cc: _ink, s: 22, w: FontWeight.w900);

    GameRenderer._hudBox(canvas, const Rect.fromLTWH(12, 70, 118, 50));
    GameRenderer._text(canvas, 'TIEMPO', 20, 76, cc: _ink, s: 10, w: FontWeight.w700);
    final tl = sim.timeLeft;
    GameRenderer._text(canvas, '${tl.ceil()}s', 20, 88,
        cc: tl < 10 ? const Color(0xFFE85D3C) : _ink, s: 22, w: FontWeight.w900);

    if (sim.playerJumped) {
      final hM = ((sim.player.com().y - kBedY) / kUnitsPerMeter).clamp(0.0, 999.0);
      GameRenderer._hudBox(canvas, const Rect.fromLTWH(12, 128, 118, 50));
      GameRenderer._text(canvas, 'ALTURA', 20, 134, cc: _ink, s: 10, w: FontWeight.w700);
      GameRenderer._text(canvas, '${hM.toStringAsFixed(1)}m', 20, 146, cc: _ink, s: 22, w: FontWeight.w900);
    }

    if (sim.combo >= 2) {
      GameRenderer._hudBox(canvas, const Rect.fromLTWH(12, 186, 118, 36));
      GameRenderer._text(canvas, 'COMBO x${sim.combo}', 71, 194,
          cc: const Color(0xFF8B5FBF), s: 16, w: FontWeight.w900, a: TextAlign.center);
    }

    final cx = g.size.x / 2;
    if (!sim.playerJumped && !sim.finished) {
      final pulse = 1 + math.sin(g.hintT * 5) * 0.05;
      canvas.save();
      canvas.translate(cx, g.size.y * 0.42);
      canvas.scale(pulse);
      GameRenderer._hudBox(canvas, Rect.fromCenter(center: Offset.zero, width: 280, height: 110), r: 18);
      GameRenderer._text(canvas, '¡TOCA PARA SALTAR!', 0, -42, cc: const Color(0xFFE85D3C), s: 20, w: FontWeight.w900, a: TextAlign.center);
      GameRenderer._text(canvas, 'Mantén IZQ o DER para girar', 0, -12, cc: _ink, s: 14, w: FontWeight.w700, a: TextAlign.center);
      GameRenderer._text(canvas, 'Suelta para estirarte', 0, 8, cc: _ink, s: 14, w: FontWeight.w700, a: TextAlign.center);
      GameRenderer._text(canvas, 'y caer de pie', 0, 28, cc: _ink, s: 14, w: FontWeight.w700, a: TextAlign.center);
      canvas.restore();
    } else if (sim.playerJumped && !sim.timeUp) {
      // Zonas de giro
      final lOn = g.leftHeld, rOn = g.rightHeld;
      final y = g.size.y - 46;
      _zone(canvas, Rect.fromLTWH(12, y, cx - 18, 36), '← GIRAR', lOn);
      _zone(canvas, Rect.fromLTWH(cx + 6, y, cx - 18, 36), 'GIRAR →', rOn);
    }

    if (g.bigText != null && g.bigTextT > 0) {
      final t = g.bigTextT;
      final pop = t > 1.2 ? (1.4 - t) / 0.2 : 1.0;
      final alpha = (t / 0.3).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(cx, g.size.y * 0.3);
      canvas.rotate(-0.05);
      canvas.scale(0.6 + 0.4 * pop.clamp(0.0, 1.0));
      final tp = TextPainter(
          text: TextSpan(text: g.bigText, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          textDirection: TextDirection.ltr)
        ..layout();
      final w = math.min(g.size.x - 30, tp.width + 40);
      canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
      GameRenderer._hudBox(canvas, Rect.fromCenter(center: Offset.zero, width: w, height: 56), r: 16);
      GameRenderer._text(canvas, g.bigText!, 0, -17, cc: g.bigTextColor, s: 26, w: FontWeight.w900, a: TextAlign.center);
      canvas.restore();
      canvas.restore();
    }
  }

  static void _zone(Canvas canvas, Rect r, String label, bool on) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(12));
    canvas.drawRRect(rr, Paint()..color = on ? const Color(0xCCF2B134) : const Color(0x55F4EAD5));
    canvas.drawRRect(rr, Paint()..color = const Color(0x883A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2);
    GameRenderer._text(canvas, label, r.center.dx, r.center.dy - 9,
        cc: const Color(0xCC3A2E1F), s: 14, w: FontWeight.w900, a: TextAlign.center);
  }
}
