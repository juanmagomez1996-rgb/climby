import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'trampoline.dart';
import 'physics.dart';
import 'climby_game.dart' show Particle;
import 'audio.dart';
import 'storage.dart';
import 'render.dart';

class FloatText {
  final String text;
  double x, y;
  double life;
  final Color color;
  final double size;
  FloatText(this.text, this.x, this.y, this.color, {this.size = 18, this.life = 1.3});
}

/// Modo TRAMPOLÍN: te lanzas desde la torre, rebotas en la lona,
/// haces mortales, coges estrellas, empujas a los compañeros
/// y al final te califican los jueces.
class TrampolineGame extends FlameGame {
  late TrampolineSim sim;

  double camX = -150, camY = 300, zoom = 0.6;
  final List<FloatText> texts = [];
  final List<Particle> particles = [];
  double shakeTime = 0, shakeIntensity = 0;
  String? bigText;
  double bigTextT = 0;
  Color bigTextColor = const Color(0xFFE85D3C);
  double hintT = 0;
  bool _camReady = false;

  final Map<int, double> _pointers = {};
  final Set<int> _ignoredPointers = {};
  void Function(RunStats stats, int score)? onFinished;
  bool _finishCalled = false;

  TrampolineGame() {
    reset();
  }

  void reset() {
    sim = TrampolineSim(bodyType: Prefs.customization.bodyType);
    texts.clear();
    particles.clear();
    _pointers.clear();
    _ignoredPointers.clear();
    bigText = null;
    hintT = 0;
    _finishCalled = false;
    _camReady = false;
  }

  @override
  Color backgroundColor() => const Color(0xFFD6E4EC);

  // ---------- Entrada ----------

  void pointerDown(int id, double sx, double sy) {
    if (sim.finished) return;
    if (!sim.playerJumped) {
      sim.jump();
      _ignoredPointers.add(id);
      return;
    }
    _pointers[id] = sx;
    _applyControl();
  }

  void pointerMove(int id, double sx, double sy) {
    if (!_pointers.containsKey(id)) return;
    _pointers[id] = sx;
    _applyControl();
  }

  void pointerUp(int id) {
    _ignoredPointers.remove(id);
    if (_pointers.remove(id) != null) _applyControl();
  }

  bool get leftHeld => _pointers.values.any((x) => x < size.x / 2);
  bool get rightHeld => _pointers.values.any((x) => x >= size.x / 2);

  void _applyControl() {
    if (_pointers.isEmpty) {
      sim.setControl(tuck: false, spinDir: 0);
      return;
    }
    final mid = size.x / 2;
    final left = _pointers.values.any((x) => x < mid);
    final right = _pointers.values.any((x) => x >= mid);
    if (left && right) {
      sim.setControl(tuck: true, spinDir: 0); // bolita sin girar
    } else {
      sim.setControl(tuck: true, spinDir: left ? 1 : -1);
    }
  }

  // ---------- Cámara ----------

  Vector2 worldToScreen(double wx, double wy) =>
      Vector2(size.x / 2 + (wx - camX) * zoom, size.y / 2 - (wy - camY) * zoom);

  void _updateCamera(double dt) {
    final p = sim.player;
    final c = p.com();
    final focusX = sim.playerJumped ? c.x : kTowerRight - 60;
    final focusY = sim.playerJumped ? c.y : kTowerTop + 100;
    final top = math.max(focusY + 230, 420.0);
    const bottom = kGroundY - 40;
    final zy = size.y / (top - bottom);
    final zx = size.x / 720;
    final tz = math.min(1.0, math.min(zy, zx)).clamp(0.25, 1.0).toDouble();
    final tx = (focusX * 0.8).clamp(-330.0, 330.0).toDouble();
    final ty = (top + bottom) / 2;
    if (!_camReady) {
      zoom = tz;
      camX = tx;
      camY = ty;
      _camReady = true;
      return;
    }
    final k = math.min(1.0, dt * 4);
    zoom += (tz - zoom) * k;
    camX += (tx - camX) * k;
    camY += (ty - camY) * math.min(1.0, dt * 6);
  }

  // ---------- Bucle ----------

  @override
  void update(double dt) {
    super.update(dt);
    if (size.x <= 0) return;
    dt = math.min(dt, 1 / 20);
    sim.update(dt);
    _processEvents();
    _updateCamera(dt);
    hintT += dt;

    if (shakeTime > 0) {
      shakeTime -= dt;
      if (shakeTime <= 0) shakeIntensity = 0;
    }
    if (bigTextT > 0) bigTextT -= dt;

    for (final t in texts) {
      t.y += 60 * dt;
      t.life -= dt;
    }
    texts.removeWhere((t) => t.life <= 0);

    for (final p in particles) {
      if (p.type == 'sparkle') {
        p.vy -= 200 * dt;
      } else {
        p.vy -= kGravity * dt * 0.7;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
      if (p.rotSpeed != 0) p.rot += p.rotSpeed * dt;
    }
    particles.removeWhere((p) => p.life <= 0 || p.y < kGroundY - 50);
  }

  void shake(double intensity, double dur) {
    if (intensity > shakeIntensity) shakeIntensity = intensity;
    if (dur > shakeTime) shakeTime = dur;
  }

  void _banner(String text, Color color, [double t = 1.4]) {
    bigText = text;
    bigTextColor = color;
    bigTextT = t;
  }

  void _processEvents() {
    for (final e in sim.events) {
      final isP = e.jumper.isPlayer;
      switch (e.type) {
        case 'jump':
          audio.whoosh();
          break;
        case 'bounce':
          if (isP) audio.trampolineBounce();
          break;
        case 'land':
          if (isP && e.text == 'crash') shake(10, 0.3);
          if (isP && e.text == 'feet') _dust(e.x, kBedY);
          break;
        case 'trick':
          final good = !e.text.contains('fallido') && !e.text.contains('culo') && e.text != '¡Plaf!';
          _banner(e.text, good ? const Color(0xFF5A8A3A) : const Color(0xFFE85D3C));
          texts.add(FloatText('+${e.points}', e.x, e.y, const Color(0xFFF2B134), size: 22));
          if (good) {
            _confetti(e.x, e.y, 24);
            audio.newRecord();
          } else {
            audio.slip();
          }
          break;
        case 'detach':
          audio.crack();
          _clayBits(e.x, e.y, e.jumper);
          texts.add(FloatText(e.text, e.x, e.y + 30, const Color(0xFFE85D3C), size: 20));
          if (isP) shake(12, 0.35);
          break;
        case 'reattach':
          if (isP) audio.grip();
          break;
        case 'star':
        case 'balloon':
          if (e.type == 'star') {
            audio.magnet();
          } else {
            audio.boing();
          }
          _sparkle(e.x, e.y, e.type == 'star' ? const Color(0xFFF2B134) : const Color(0xFFFF7EB9));
          texts.add(FloatText(e.text, e.x, e.y, const Color(0xFFF2B134)));
          break;
        case 'push':
          audio.boing();
          shake(6, 0.15);
          texts.add(FloatText('${e.text} +${e.points}', e.x, e.y, const Color(0xFF4A7BA6), size: 20));
          break;
        case 'knockout':
          audio.win();
          _banner('${e.text} +${e.points}', const Color(0xFF8B5FBF));
          _confetti(e.x, e.y + 40, 20);
          break;
        case 'out':
          audio.fall();
          _banner(e.text, const Color(0xFFE85D3C));
          break;
        case 'timeup':
          audio.countdown(0);
          _banner('¡TIEMPO!', const Color(0xFF3A2E1F), 2);
          break;
        case 'finish':
          if (!_finishCalled) {
            _finishCalled = true;
            Future.delayed(const Duration(milliseconds: 700), () => onFinished?.call(sim.stats, sim.score));
          }
          break;
      }
    }
    sim.events.clear();
  }

  // ---------- Partículas ----------

  void _confetti(double x, double y, int count) {
    const colors = [
      Color(0xFFE85D3C), Color(0xFFF2B134), Color(0xFF5A8A3A),
      Color(0xFF4A7BA6), Color(0xFFFF7EB9), Color(0xFF8B5FBF),
    ];
    for (int i = 0; i < count; i++) {
      particles.add(Particle(
        x: x, y: y, vx: rnd(-300, 300), vy: rnd(150, 450),
        life: 1.8, r: rnd(3, 7), color: colors[kRand.nextInt(colors.length)],
        type: 'confetti', rot: rnd(0, 6.28), rotSpeed: rnd(-8, 8),
      ));
    }
  }

  void _sparkle(double x, double y, Color c) {
    for (int i = 0; i < 12; i++) {
      final a = i / 12 * math.pi * 2;
      particles.add(Particle(
        x: x, y: y, vx: math.cos(a) * 180, vy: math.sin(a) * 180,
        life: 0.6, r: rnd(2, 4), color: c, type: 'sparkle',
      ));
    }
  }

  void _clayBits(double x, double y, Jumper j) {
    for (int i = 0; i < 10; i++) {
      particles.add(Particle(
        x: x + rnd(-10, 10), y: y + rnd(-10, 10), vx: rnd(-220, 220), vy: rnd(100, 380),
        life: 1.0, r: rnd(3, 6), color: TrampolineRenderer.skinFor(j), type: 'break',
      ));
    }
  }

  void _dust(double x, double y) {
    for (int i = 0; i < 6; i++) {
      particles.add(Particle(
        x: x + rnd(-20, 20), y: y + rnd(0, 6), vx: rnd(-80, 80), vy: rnd(40, 120),
        life: 0.5, r: rnd(2, 4), color: const Color(0xFFD8C89A), type: 'dust',
      ));
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (size.x <= 0) return;
    TrampolineRenderer.render(canvas, this);
  }
}
