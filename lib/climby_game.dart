import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'physics.dart';
import 'holds.dart';
import 'level.dart';
import 'audio.dart';
import 'storage.dart';
import 'render.dart';

enum WeatherType { none, wind, rain, storm }
enum FaceState { neutral, focused, scared, happy, burning, dead }
enum DeathMode { none, fall, lava }

const double kStaminaMax = 100;
const double kStaminaDrainHand = 7;
const double kStaminaDrainFoot = 2;
const double kStaminaRecover = 28;
const double kStaminaDrainHeavy = 12;

class Particle {
  double x, y, vx, vy, life, r;
  Color color;
  String type;
  double rot = 0;
  double rotSpeed = 0;
  Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.life, required this.r,
    required this.color, this.type = 'break',
    this.rot = 0, this.rotSpeed = 0,
  });
}

class Ball {
  double x, y, vx = 0, vy = 0, r;
  Color color;
  // Depth Z: balls with depth<0 drawn behind player, >=0 drawn in front
  double depth;
  Ball(this.x, this.y, this.r, this.color, this.depth);
}

class BallPit {
  List<Ball> balls;
  double pitTop, pitBottom, pitLeft, pitRight;
  double timer = 0;
  String reason;
  bool modalShown = false;
  bool splashed = false;
  BallPit({
    required this.balls,
    required this.pitTop, required this.pitBottom,
    required this.pitLeft, required this.pitRight,
    required this.reason,
  });
}

class ClimbyGame extends FlameGame {
  late Character char;
  Level? level;

  Map<String, Hold?> grips = {'LH': null, 'RH': null, 'LF': null, 'RF': null};
  Map<String, double> stamina = {
    'LH': 100, 'RH': 100, 'LF': 100, 'RF': 100,
  };

  String? dragLimb;
  Vector2 dragWorldPos = Vector2.zero();

  double camY = 200;
  double cameraZoom = 1.0;
  double currentHeight = 0;
  double maxHeight = 0;
  double recordHeight = 0;
  bool fallen = false;
  bool won = false;
  bool started = false;
  double cinematicTimer = 0;

  double shakeTime = 0;
  double shakeIntensity = 0;
  double flashTime = 0;
  double thunderTimer = 0;

  WeatherType weather = WeatherType.none;
  double weatherT = 3;
  double weatherIntensity = 0;
  int weatherDir = 1;

  bool bossMode = false;
  double lavaY = -double.infinity;

  List<Particle> particles = [];
  FaceState faceState = FaceState.neutral;
  BallPit? ballPit;

  // Death animation
  DeathMode deathMode = DeathMode.none;
  double burnTime = 0;

  // Idle animation
  double idleTimer = 0;
  double breatheOffset = 0;
  double blinkTimer = 4;
  bool blinking = false;
  double blinkDuration = 0;

  bool _lavaModalShown = false;

  VoidCallback? onFell;
  VoidCallback? onWon;

  final Map<String, double> _lastGripY = {'LH': 0, 'RH': 0, 'LF': 0, 'RF': 0};

  ClimbyGame();

  @override
  Color backgroundColor() => const Color(0xFFF4EAD5);

  @override
  Future<void> onLoad() async {
    if (level == null) return;
    _initFromLevel();
  }

  void loadLevel(Level lvl) {
    level = lvl;
    _initFromLevel();
  }

  void _initFromLevel() {
    final lvl = level!;
    bossMode = lvl.boss;
    final start = lvl.holds.first;
    char = Character(start.x, start.y - 60, Prefs.customization.bodyType);

    grips = {'LH': null, 'RH': null, 'LF': null, 'RF': null};
    stamina = {'LH': 100, 'RH': 100, 'LF': 100, 'RF': 100};
    fallen = false;
    won = false;
    started = false;
    cinematicTimer = 0;
    weather = WeatherType.none;
    weatherT = 3;
    particles = [];
    ballPit = null;
    cameraZoom = 1.0;
    currentHeight = 0;
    maxHeight = 0;
    faceState = FaceState.neutral;
    dragLimb = null;
    shakeTime = 0;
    flashTime = 0;
    thunderTimer = 5;
    deathMode = DeathMode.none;
    burnTime = 0;
    _lavaModalShown = false;
    idleTimer = 0;
    blinkTimer = 4;
    blinking = false;
    recordHeight = Prefs.getRecord(lvl.name);
    lavaY = bossMode ? start.y - 350 : -double.infinity;

    char.lh.x = start.x - 18;
    char.lh.y = start.y;
    char.lh.px = char.lh.x;
    char.lh.py = char.lh.y;
    char.rh.x = start.x + 18;
    char.rh.y = start.y;
    char.rh.px = char.rh.x;
    char.rh.py = char.rh.y;
    _gripLimb('LH', start, silent: true);
    _gripLimb('RH', start, silent: true);

    for (final limb in ['LF', 'RF']) {
      final p = char.limbByKey(limb);
      Hold? best;
      double bestD = 110;
      for (final h in lvl.holds) {
        if (identical(h, start)) continue;
        final d = dist2(p.x, p.y, h.x, h.y);
        if (d < bestD) {
          bestD = d;
          best = h;
        }
      }
      if (best != null) _gripLimb(limb, best, silent: true);
    }

    camY = (char.chest.y + char.pelvis.y) / 2;
  }

  void start() {
    started = true;
    if (bossMode) {
      audio.startBossMusic();
    } else {
      audio.startMusic();
    }
  }

  void shake(double intensity, double dur) {
    if (intensity > shakeIntensity) shakeIntensity = intensity;
    if (dur > shakeTime) shakeTime = dur;
  }

  void _gripLimb(String key, Hold hold, {bool silent = false}) {
    grips[key] = hold;
    final p = char.limbByKey(key);
    p.locked = true;
    final hx = hold.type == HoldType.moving ? hold.currentX : hold.x;
    p.lockX = hx;
    p.lockY = hold.y;
    p.x = hx;
    p.y = hold.y;
    p.px = hx;
    p.py = hold.y;
    if (!silent) {
      final lastY = _lastGripY[key] ?? hold.y;
      if (hold.y > lastY + 30) _spawnDust(hx, hold.y - 5);
      if (hold.type == HoldType.magnet) {
        audio.magnet();
      } else if (hold.type == HoldType.slippery) {
        audio.slip();
      } else {
        audio.grip();
      }
    }
    _lastGripY[key] = hold.y;
  }

  void _releaseLimb(String key) {
    final hold = grips[key];
    if (hold != null) {
      if (hold.type == HoldType.fragile && !hold.broken) {
        hold.hp -= 1;
        if (hold.hp <= 0) {
          hold.broken = true;
          _spawnBreakParticles(hold.x, hold.y, holdColor(HoldType.fragile));
          audio.crack();
          shake(8, 0.25);
        }
      }
      if (hold.type == HoldType.bouncy) {
        final p = char.limbByKey(key);
        p.py = p.y - 12;
        p.px = p.x;
        for (final pt in [char.chest, char.pelvis]) {
          pt.py = pt.y - 8;
        }
        audio.trampolineBounce();
      } else {
        audio.release();
      }
    }
    grips[key] = null;
    char.limbByKey(key).locked = false;
  }

  int _gripCount() => grips.values.where((v) => v != null).length;
  // Public accessor used by render.dart
  int gripCountPublic() => _gripCount();

  Hold? _findHoldNear(double x, double y, [double radius = kHoldSnap]) {
    Hold? best;
    double bestD = double.infinity;
    for (final h in level!.holds) {
      if (h.broken) continue;
      final hx = h.type == HoldType.moving ? h.currentX : h.x;
      final d = dist2(x, y, hx, h.y) - h.r;
      double r2 = radius;
      if (h.type == HoldType.magnet) r2 = radius * 1.8;
      if (d < r2 && d < bestD) {
        bestD = d;
        best = h;
      }
    }
    return best;
  }

  Vector2 worldToScreen(double wx, double wy) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final z = cameraZoom;
    return Vector2(cx + wx * z, cy - (wy - camY) * z);
  }

  Vector2 _screenToWorld(double sx, double sy) {
    final cx = size.x / 2;
    final cy = size.y / 2;
    final z = cameraZoom;
    return Vector2((sx - cx) / z, -(sy - cy) / z + camY);
  }

  String? _findLimbAtScreen(double sx, double sy) {
    for (final k in ['LH', 'RH', 'LF', 'RF']) {
      final p = char.limbByKey(k);
      final s = worldToScreen(p.x, p.y);
      if (dist2(sx, sy, s.x, s.y) < 38) return k;
    }
    return null;
  }

  void handlePointerDown(double sx, double sy) {
    if (fallen || won || !started) return;
    final limb = _findLimbAtScreen(sx, sy);
    if (limb == null) return;
    if (grips[limb] != null) _releaseLimb(limb);
    dragLimb = limb;
    final w = _screenToWorld(sx, sy);
    dragWorldPos.setFrom(w);
  }

  void handlePointerMove(double sx, double sy) {
    if (dragLimb == null) return;
    final w = _screenToWorld(sx, sy);
    dragWorldPos.setFrom(w);
  }

  void handlePointerUp() {
    if (dragLimb == null) return;
    final limb = dragLimb!;
    final p = char.limbByKey(limb);
    final hold = _findHoldNear(p.x, p.y);
    if (hold != null) _gripLimb(limb, hold);
    dragLimb = null;
  }

  void _spawnBreakParticles(double x, double y, Color color) {
    for (int i = 0; i < 14; i++) {
      particles.add(Particle(
        x: x, y: y,
        vx: rnd(-200, 200), vy: rnd(50, 300),
        life: 1.2, r: rnd(2, 5),
        color: color, type: 'break',
      ));
    }
  }

  void _spawnDust(double x, double y) {
    for (int i = 0; i < 5; i++) {
      particles.add(Particle(
        x: x + rnd(-8, 8), y: y + rnd(-3, 3),
        vx: rnd(-40, 40), vy: rnd(20, 80),
        life: 0.6, r: rnd(2, 4),
        color: const Color(0xFFD8C89A),
        type: 'dust',
      ));
    }
  }

  void _spawnConfetti(double x, double y, [int count = 30]) {
    final colors = [
      const Color(0xFFE85D3C), const Color(0xFFF2B134),
      const Color(0xFF5A8A3A), const Color(0xFF4A7BA6),
      const Color(0xFFFF7EB9), const Color(0xFF8B5FBF),
    ];
    for (int i = 0; i < count; i++) {
      particles.add(Particle(
        x: x, y: y,
        vx: rnd(-300, 300), vy: rnd(150, 450),
        life: 2.5, r: rnd(3, 7),
        color: colors[kRand.nextInt(colors.length)],
        type: 'confetti',
        rot: rnd(0, 6.28), rotSpeed: rnd(-8, 8),
      ));
    }
  }

  void _spawnFlame(double x, double y) {
    final colors = [
      const Color(0xFFFF5722), const Color(0xFFFF9800),
      const Color(0xFFFFEB3B), const Color(0xFFD32F2F),
    ];
    particles.add(Particle(
      x: x + rnd(-12, 12), y: y + rnd(-12, 12),
      vx: rnd(-30, 30), vy: rnd(40, 120),
      life: 0.8, r: rnd(4, 9),
      color: colors[kRand.nextInt(colors.length)],
      type: 'flame',
    ));
  }

  void _spawnAsh(double x, double y) {
    particles.add(Particle(
      x: x + rnd(-6, 6), y: y + rnd(-6, 6),
      vx: rnd(-20, 20), vy: rnd(30, 80),
      life: 2.5, r: rnd(2, 4),
      color: const Color(0xFF555555),
      type: 'ash',
    ));
  }

  void _activateBallPit(String reason) {
    final pitTop = char.pelvis.y - 200;
    final pitBottom = pitTop - 250;
    final balls = <Ball>[];
    final colors = [
      const Color(0xFFE85D3C), const Color(0xFFF2B134),
      const Color(0xFF5A8A3A), const Color(0xFF4A7BA6),
      const Color(0xFFFF7EB9), const Color(0xFF8B5FBF),
      const Color(0xFFFFAA3A), const Color(0xFF7FC7E5),
    ];
    const pitWidth = 600.0;
    const ballR = 22.0;
    final cols = (pitWidth / (ballR * 1.8)).floor();
    const rows = 6;
    for (int row = 0; row < rows; row++) {
      for (int col = 0; col < cols; col++) {
        final x = -pitWidth / 2 + col * ballR * 1.8 +
            (row % 2 == 1 ? ballR * 0.9 : 0) + rnd(-3, 3);
        final y = pitBottom + row * ballR * 1.7 + rnd(-3, 3);
        // Random depth: half behind player, half in front
        final depth = kRand.nextDouble() < 0.5 ? -1.0 : 1.0;
        balls.add(Ball(x, y, ballR + rnd(-2, 2),
            colors[kRand.nextInt(colors.length)], depth));
      }
    }
    ballPit = BallPit(
      balls: balls,
      pitTop: pitTop, pitBottom: pitBottom,
      pitLeft: -pitWidth / 2, pitRight: pitWidth / 2,
      reason: reason,
    );
    audio.stopMusic();
  }

  void _activateLavaBurn() {
    fallen = true;
    deathMode = DeathMode.lava;
    faceState = FaceState.burning;
    burnTime = 0;
    // Release all grips so character falls into lava
    for (final k in ['LH', 'RH', 'LF', 'RF']) {
      grips[k] = null;
      final p = char.limbByKey(k);
      p.locked = false;
    }
    audio.fall();
    shake(15, 0.6);
    audio.stopMusic();
  }

  void _updateLavaBurn(double dt) {
    burnTime += dt;

    // Apply gravity so character sinks into lava
    final bm = bodyMultipliers(Prefs.customization.bodyType);
    for (final p in char.points) {
      if (p.locked) continue;
      p.applyForce(0, -kGravity * bm.weight * 0.5); // slower sinking
    }
    for (final p in char.points) {
      p.integrate(dt);
    }
    for (int i = 0; i < kIterations; i++) {
      for (final s in char.sticks) {
        s.solve();
      }
    }

    if (burnTime < 2.5) {
      // Spawn flames on all body parts
      for (int i = 0; i < 4; i++) {
        final pt = char.points[kRand.nextInt(char.points.length)];
        _spawnFlame(pt.x + rnd(-10, 10), pt.y + rnd(-10, 10));
      }
      if (kRand.nextDouble() < 0.4) {
        _spawnAsh(char.chest.x + rnd(-20, 20), char.chest.y + rnd(-30, 30));
      }
      // Shake character
      if (kRand.nextDouble() < 0.4) {
        for (final p in char.points) {
          p.x += rnd(-3, 3);
          p.y += rnd(-3, 3);
        }
      }
    }

    final torsoY = (char.chest.y + char.pelvis.y) / 2;
    camY += (torsoY - camY) * 0.05;

    if (burnTime > 2.5 && faceState == FaceState.burning) {
      faceState = FaceState.dead;
    }
    if (burnTime > 3.5 && !_lavaModalShown) {
      _lavaModalShown = true;
      onFell?.call();
    }
  }

  void _updateBallPit(double dt) {
    final bp = ballPit!;
    bp.timer += dt;
    final targetCam = (bp.pitTop + bp.pitBottom) / 2 + 80;
    camY += (targetCam - camY) * 0.05;

    if (!bp.splashed && char.pelvis.y < bp.pitTop + 30) {
      bp.splashed = true;
      audio.splash();
      shake(12, 0.3);
      final cx = char.pelvis.x;
      final cy = char.pelvis.y;
      for (final ball in bp.balls) {
        final dx = ball.x - cx;
        final dy = ball.y - cy;
        final d = math.sqrt(dx * dx + dy * dy).clamp(1.0, double.infinity);
        if (d < 180) {
          final force = (180 - d) * 4;
          ball.vx += dx / d * force;
          ball.vy += dy / d * force + 200;
        }
      }
      Future.delayed(const Duration(milliseconds: 250), audio.boing);
      Future.delayed(const Duration(milliseconds: 600), audio.boing);
    }

    for (final p in char.points) {
      if (p.locked) continue;
      if (p.y < bp.pitBottom + 10) {
        p.y = bp.pitBottom + 10;
        p.py = p.y + (p.y - p.py).abs() * 0.5;
      }
      if (p.x < bp.pitLeft + 20) {
        p.x = bp.pitLeft + 20;
        p.px = p.x + (p.px - p.x) * 0.5;
      }
      if (p.x > bp.pitRight - 20) {
        p.x = bp.pitRight - 20;
        p.px = p.x + (p.px - p.x) * 0.5;
      }
    }

    const gBall = 600.0;
    const damp = 0.92;
    for (final ball in bp.balls) {
      ball.vy -= gBall * dt;
      ball.x += ball.vx * dt;
      ball.y += ball.vy * dt;
      if (ball.y < bp.pitBottom + ball.r) {
        ball.y = bp.pitBottom + ball.r;
        if (ball.vy < 0) ball.vy = -ball.vy * 0.4;
        ball.vx *= 0.85;
      }
      if (ball.x < bp.pitLeft + ball.r) {
        ball.x = bp.pitLeft + ball.r;
        ball.vx = ball.vx.abs() * 0.5;
      }
      if (ball.x > bp.pitRight - ball.r) {
        ball.x = bp.pitRight - ball.r;
        ball.vx = -ball.vx.abs() * 0.5;
      }
      ball.vx *= damp;
      ball.vy *= damp;
    }

    for (int iter = 0; iter < 3; iter++) {
      for (int i = 0; i < bp.balls.length; i++) {
        final a = bp.balls[i];
        for (int j = i + 1; j < bp.balls.length; j++) {
          final b = bp.balls[j];
          final dx = b.x - a.x;
          final dy = b.y - a.y;
          final d = math.sqrt(dx * dx + dy * dy);
          final minD = a.r + b.r;
          if (d < minD && d > 0.001) {
            final overlap = (minD - d) / 2;
            final nx = dx / d;
            final ny = dy / d;
            a.x -= nx * overlap;
            a.y -= ny * overlap;
            b.x += nx * overlap;
            b.y += ny * overlap;
            final va = a.vx * nx + a.vy * ny;
            final vb = b.vx * nx + b.vy * ny;
            final exchange = (vb - va) * 0.4;
            a.vx += nx * exchange;
            a.vy += ny * exchange;
            b.vx -= nx * exchange;
            b.vy -= ny * exchange;
          }
        }
      }
    }

    final charPoints = [
      char.head, char.chest, char.pelvis,
      char.lh, char.rh, char.lf, char.rf,
    ];
    const charR = 18.0;
    for (final p in charPoints) {
      for (final ball in bp.balls) {
        final dx = ball.x - p.x;
        final dy = ball.y - p.y;
        final d = math.sqrt(dx * dx + dy * dy);
        final minD = ball.r + charR;
        if (d < minD && d > 0.001) {
          final nx = dx / d;
          final ny = dy / d;
          final overlap = minD - d;
          ball.x += nx * overlap * 0.7;
          ball.y += ny * overlap * 0.7;
          final pvx = (p.x - p.px) * 60;
          final pvy = (p.y - p.py) * 60;
          ball.vx += pvx * 0.3;
          ball.vy += pvy * 0.3;
          if (!p.locked) {
            p.x -= nx * overlap * 0.3;
            p.y -= ny * overlap * 0.3;
          }
        }
      }
    }

    if (bp.timer > 2.5 && !bp.modalShown) {
      bp.modalShown = true;
      onFell?.call();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (level == null) return;
    dt = math.min(dt, 1 / 30);

    if (shakeTime > 0) {
      shakeTime -= dt;
      if (shakeTime <= 0) {
        shakeTime = 0;
        shakeIntensity = 0;
      }
    }
    if (flashTime > 0) {
      flashTime -= dt * 3;
      if (flashTime < 0) flashTime = 0;
    }

    // Idle: breathing + blink
    idleTimer += dt;
    breatheOffset = math.sin(idleTimer * 1.5) * 1.5;
    blinkTimer -= dt;
    if (blinkTimer <= 0) {
      blinking = true;
      blinkDuration = 0;
      blinkTimer = rnd(3, 7);
    }
    if (blinking) {
      blinkDuration += dt;
      if (blinkDuration > 0.15) blinking = false;
    }

    if (won) {
      cinematicTimer += dt;
      cameraZoom = math.min(1.6, 1 + cinematicTimer * 0.4);
      _updateParticles(dt);
      if (cinematicTimer % 0.3 < dt && cinematicTimer < 3) {
        _spawnConfetti(char.head.x + rnd(-100, 100), char.head.y + 100, 8);
      }
      return;
    }

    // Lava burn — no ball pit, just burn animation
    if (deathMode == DeathMode.lava) {
      _updateLavaBurn(dt);
      _updateParticles(dt);
      return;
    }

    if (ballPit != null) {
      final bm = bodyMultipliers(Prefs.customization.bodyType);
      for (final p in char.points) {
        if (p.locked) continue;
        p.applyForce(0, -kGravity * bm.weight);
      }
      for (final p in char.points) {
        p.integrate(dt);
      }
      for (int i = 0; i < kIterations; i++) {
        for (final s in char.sticks) {
          s.solve();
        }
      }
      _updateBallPit(dt);
      _updateParticles(dt);
      return;
    }

    if (!started) return;

    final bm = bodyMultipliers(Prefs.customization.bodyType);

    final tNow = DateTime.now().millisecondsSinceEpoch / 1000.0;
    for (final h in level!.holds) {
      if (h.type == HoldType.moving && h.baseX != null) {
        h.currentX = h.baseX! + math.sin(tNow * h.moveFreq + h.movePhase) * h.moveAmplitude;
        for (final k in ['LH', 'RH', 'LF', 'RF']) {
          if (identical(grips[k], h)) {
            char.limbByKey(k).lockX = h.currentX;
            char.limbByKey(k).lockY = h.y;
          }
        }
      }
    }

    weatherT -= dt;
    if (weatherT <= 0) {
      if (weather != WeatherType.none) {
        weather = WeatherType.none;
        weatherT = rnd(4, 8);
      } else if (currentHeight > 3) {
        final opts = <WeatherType>[];
        if (level!.weather.wind) opts.add(WeatherType.wind);
        if (level!.weather.rain) {
          opts.add(WeatherType.rain);
          opts.add(WeatherType.wind);
        }
        if (bossMode) opts.add(WeatherType.storm);
        if (opts.isNotEmpty) {
          weather = opts[kRand.nextInt(opts.length)];
          weatherDir = kRand.nextBool() ? -1 : 1;
          weatherIntensity = rnd(120, 240);
          weatherT = rnd(3, 5);
          audio.whoosh();
        }
      } else {
        weatherT = rnd(2, 4);
      }
    }

    if (weather == WeatherType.storm) {
      thunderTimer -= dt;
      if (thunderTimer <= 0) {
        flashTime = 1.0;
        audio.thunder();
        shake(6, 0.4);
        thunderTimer = rnd(3, 7);
      }
    }

    if (bossMode) {
      final start = level!.holds.first;
      final playerWorldY = start.y + maxHeight * 30;
      final lavaSpeed = 22 + maxHeight * 0.8;
      lavaY += lavaSpeed * dt;
      if (lavaY > playerWorldY - 30) {
        _activateLavaBurn();
      }
    }

    for (final k in ['LH', 'RH', 'LF', 'RF']) {
      final isHand = k == 'LH' || k == 'RH';
      if (grips[k] != null) {
        double baseDrain = isHand ? kStaminaDrainHand : kStaminaDrainFoot;
        if (_gripCount() <= 2) {
          baseDrain = isHand ? kStaminaDrainHeavy : kStaminaDrainHand;
        }
        double mult = 1;
        final h = grips[k]!;
        if (h.type == HoldType.sticky) {
          mult = 0.4;
        } else if (h.type == HoldType.magnet) {
          mult = 0.6;
        } else if (h.type == HoldType.slippery) {
          mult = 2.5;
        }
        stamina[k] = math.max(0, stamina[k]! - baseDrain * mult * dt * bm.weight);
        if (stamina[k]! <= 0) _releaseLimb(k);
      } else {
        final recoverRate = isHand ? kStaminaRecover : kStaminaRecover * 1.4;
        stamina[k] = math.min(kStaminaMax, stamina[k]! + recoverRate * dt);
      }
    }

    for (final k in ['LH', 'RH', 'LF', 'RF']) {
      final h = grips[k];
      if (h != null && h.type == HoldType.slippery) {
        h.slipTimer += dt;
        if (h.slipTimer > 1) {
          _releaseLimb(k);
          h.slipTimer = 0;
        }
      }
    }

    for (final p in char.points) {
      if (p.locked) continue;
      p.applyForce(0, -kGravity * bm.weight);
      if (weather == WeatherType.wind || weather == WeatherType.rain) {
        p.applyForce(weatherDir * weatherIntensity, 0);
      }
      if (weather == WeatherType.storm) {
        p.applyForce(weatherDir * weatherIntensity * 1.5, 0);
        if (kRand.nextDouble() < 0.02) p.applyForce(0, rnd(-200, 100));
      }
    }

    for (final k in ['LH', 'RH', 'LF', 'RF']) {
      if (grips[k] != null) continue;
      if (dragLimb != k) continue;
      final p = char.limbByKey(k);
      for (final h in level!.holds) {
        if (h.type != HoldType.magnet || h.broken) continue;
        final d = dist2(p.x, p.y, h.x, h.y);
        if (d < 80 && d > 5) {
          final fx = (h.x - p.x) / d * 800;
          final fy = (h.y - p.y) / d * 800;
          p.applyForce(fx, fy);
        }
      }
    }

    if (dragLimb != null && _gripCount() > 0) {
      final limb = dragLimb!;
      final p = char.limbByKey(limb);
      if (!p.locked) {
        final isArm = limb == 'LH' || limb == 'RH';
        final reach = (isArm ? kArmReachBase : kLegReachBase) * bm.reach;
        final anchor = char.anchorForLimb(limb);
        double dx = dragWorldPos.x - anchor.x;
        double dy = dragWorldPos.y - anchor.y;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d > reach) {
          dx = dx / d * reach;
          dy = dy / d * reach;
        }
        final tx = anchor.x + dx;
        final ty = anchor.y + dy;
        final ddx = tx - p.x;
        final ddy = ty - p.y;
        final dd = math.sqrt(ddx * ddx + ddy * ddy);
        if (dd > 0.1) {
          final k = math.min(0.6, 25 / dd);
          p.x += ddx * k;
          p.y += ddy * k;
          p.px = p.x - ddx * k * 0.3;
          p.py = p.y - ddy * k * 0.3;
        }
      }
    }

    if (_gripCount() == 0 && dragLimb != null) dragLimb = null;

    for (final p in char.points) {
      p.integrate(dt);
    }
    for (int i = 0; i < kIterations; i++) {
      for (final s in char.sticks) {
        s.solve();
      }
    }

    for (final k in ['LH', 'RH', 'LF', 'RF']) {
      final h = grips[k];
      if (h != null && h.broken) _releaseLimb(k);
    }

    for (final h in level!.holds) {
      if (h.type == HoldType.invisible) {
        bool nearAny = false;
        for (final k in ['LH', 'RH', 'LF', 'RF']) {
          final p = char.limbByKey(k);
          if (dist2(p.x, p.y, h.x, h.y) < 80) {
            nearAny = true;
            break;
          }
        }
        h.visible = nearAny;
      }
    }

    _updateParticles(dt);

    if (_gripCount() == 0 && !fallen && !won) {
      final start = level!.holds.first;
      if (char.pelvis.y < start.y - 80) {
        fallen = true;
        faceState = FaceState.scared;
        audio.fall();
        shake(10, 0.4);
        if (bossMode) {
          // In boss mode: burn in lava, no ball pit
          _activateLavaBurn();
        } else {
          // Normal mode: fall into ball pit
          deathMode = DeathMode.fall;
          _activateBallPit('¡Te caíste!');
        }
      }
    }

    final start = level!.holds.first;
    final h2 = math.max(0.0, (char.head.y - start.y) / 30);
    currentHeight = h2;
    if (h2 > maxHeight) maxHeight = h2;
    if (h2 > recordHeight) {
      recordHeight = h2;
      Prefs.setRecord(level!.name, h2);
    }

    final minStam = stamina.values.reduce(math.min);
    // Don't override burning/dead face
    if (faceState != FaceState.burning && faceState != FaceState.dead) {
      if (_gripCount() == 0) {
        faceState = FaceState.scared;
      } else if (minStam < 30) {
        faceState = FaceState.focused;
      } else if (h2 > recordHeight - 1 && recordHeight > 2) {
        faceState = FaceState.focused;
      } else {
        faceState = FaceState.neutral;
      }
    }

    final torsoY = (char.chest.y + char.pelvis.y) / 2;
    camY += (torsoY - camY) * 0.08;

    if (char.head.y >= level!.finishY && !won) {
      won = true;
      faceState = FaceState.happy;
      cinematicTimer = 0;
      _spawnConfetti(char.head.x, char.head.y + 50, 50);
      audio.stopMusic();
      audio.win();
      shake(8, 0.4);
      Future.delayed(const Duration(milliseconds: 2200), () {
        onWon?.call();
      });
    }
  }

  void _updateParticles(double dt) {
    for (final p in particles) {
      if (p.type == 'dust' || p.type == 'flame' || p.type == 'ash') {
        p.vy += 60 * dt;
      } else {
        p.vy -= kGravity * dt * 0.7;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.rotSpeed != 0) p.rot += p.rotSpeed * dt;
    }
    particles.removeWhere((p) => p.life <= 0 || p.y < -500);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (level == null) return;
    GameRenderer.render(canvas, this);
  }
}
