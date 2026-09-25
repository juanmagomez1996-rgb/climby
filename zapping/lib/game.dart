import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import 'channels.dart';
import 'gfx.dart';
import 'prefs.dart';
import 'sfx.dart';

class Pointer {
  double x = -999, y = -999, dx = 0, dy = 0;
  bool down = false, pressed = false;
  int? id;
}

enum Mode { loading, menu, playing, paused, over }

enum Phase { tuning, play, result }

/// Resumen de una partida para la pantalla final.
class RunResult {
  final int score, channel;
  final bool record;
  const RunResult(this.score, this.channel, this.record);
}

class ZappingGame extends FlameGame {
  // Mundo lógico de 540x960; todo se escala para encajar en el móvil.
  static const double W = 540, H = 960;
  static const Rect tvRect = Rect.fromLTWH(5, 48, 530, 710);
  static const Rect screen = Rect.fromLTWH(59, 108, 421, 460);
  static final RRect screenClip = RRect.fromRectAndRadius(screen.inflate(3), const Radius.circular(44));
  static const Offset pauseBtn = Offset(506, 24);

  /// Solo para capturas: `--dart-define=TOUR=true` recorre los canales en orden sin perder vidas.
  static const bool tour = bool.fromEnvironment('TOUR');

  final ptr = Pointer();
  final fx = Fx();

  Mode mode = Mode.loading;
  Phase phase = Phase.tuning;
  double phaseT = 0, time = 0;
  int lives = 4, ch = 0, score = 0, lastIdx = -1;
  bool ok = false;
  final List<int> bag = [];
  Channel? cur;
  RunResult? lastRun;

  double _k = 1;
  Offset _off = Offset.zero;

  int get level => score ~/ 5;
  double get speed => 1 + .14 * level;

  @override
  Color backgroundColor() => Pal.bg;

  @override
  Future<void> onLoad() async {
    images.prefix = 'assets/images/';
    await Gfx.load(images);
    await Sfx.load();
    mode = Mode.menu;
    overlays.add('menu');
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _k = math.min(size.x / W, size.y / H);
    _off = Offset((size.x - W * _k) / 2, (size.y - H * _k) / 2);
  }

  // ───────────── Entrada (desde un Listener de Flutter) ─────────────
  Offset _toLogical(Offset o) => (o - _off) / _k;

  void pointerDown(int id, Offset local) {
    if (ptr.id != null) return;
    final o = _toLogical(local);
    ptr
      ..id = id
      ..x = o.dx
      ..y = o.dy
      ..dx = 0
      ..dy = 0
      ..down = true
      ..pressed = true;
    if (mode == Mode.playing && (o - pauseBtn).distance < 34) {
      ptr.pressed = false;
      pause();
    }
  }

  void pointerMove(int id, Offset local) {
    if (id != ptr.id) return;
    final o = _toLogical(local);
    ptr
      ..dx += o.dx - ptr.x
      ..dy += o.dy - ptr.y
      ..x = o.dx
      ..y = o.dy;
  }

  void pointerUp(int id) {
    if (id != ptr.id) return;
    ptr
      ..down = false
      ..id = null;
  }

  // ───────────── Flujo de partida ─────────────
  void startRun() {
    overlays
      ..remove('menu')
      ..remove('over');
    lives = 4;
    ch = 0;
    score = 0;
    lastIdx = -1;
    bag.clear();
    fx.clear();
    mode = Mode.playing;
    _nextChannel();
  }

  void pause() {
    if (mode != Mode.playing) return;
    mode = Mode.paused;
    overlays.add('pause');
  }

  void resume() {
    if (mode != Mode.paused) return;
    overlays.remove('pause');
    mode = Mode.playing;
  }

  void toMenu() {
    overlays
      ..remove('pause')
      ..remove('over');
    fx.clear();
    cur = null;
    mode = Mode.menu;
    overlays.add('menu');
  }

  @override
  void lifecycleStateChange(AppLifecycleState state) {
    super.lifecycleStateChange(state);
    if (state != AppLifecycleState.resumed) pause();
  }

  void _nextChannel() {
    ch++;
    Channel c;
    if (tour) {
      final i = (ch - 1) % (channelFactories.length + 1);
      c = i == channelFactories.length ? Boss(this) : channelFactories[i](this);
    } else if (ch % 10 == 0) {
      c = Boss(this);
    } else {
      if (bag.isEmpty) {
        bag.addAll(List.generate(channelFactories.length, (i) => i)..shuffle(rng));
      }
      var i = bag.removeLast();
      if (i == lastIdx && bag.isNotEmpty) {
        final j = bag.removeLast();
        bag.insert(0, i);
        i = j;
      }
      lastIdx = i;
      c = channelFactories[i](this);
    }
    c.init(level);
    cur = c;
    phase = Phase.tuning;
    phaseT = 0;
    Sfx.play('static', volume: .5);
  }

  void _finish(bool win) {
    phase = Phase.result;
    phaseT = 0;
    ok = win;
    final c = cur!;
    if (win) {
      final before = level;
      score++;
      fx.float(c.boss ? '¡JEFE VENCIDO!' : '¡BIEN!', screen.center.dx, screen.center.dy - 150, Pal.lime, 44);
      fx.burst(screen.center.dx, screen.center.dy, Pal.lime, 26, speed: 360);
      Sfx.play('win');
      Sfx.haptic();
      if (c.boss && lives < 4) {
        lives++;
        fx.float('+1 VIDA', screen.center.dx, screen.center.dy - 90, Pal.pink, 30);
        Sfx.play('bonus');
      }
      if (level > before) {
        fx.float('¡MÁS RÁPIDO!', screen.center.dx, screen.center.dy + 120, Pal.gold, 36);
      }
    } else {
      if (!tour) lives--;
      fx.shake(14, .35);
      Sfx.play('lose');
      Sfx.haptic(strong: true);
      fx.float(c.why.isEmpty ? '¡FALLO!' : c.why, screen.center.dx, screen.center.dy - 150, Pal.pink, 30);
    }
  }

  void _gameOver() {
    final rec = Prefs.submit(score);
    lastRun = RunResult(score, ch, rec);
    mode = Mode.over;
    Sfx.play('gameover');
    overlays.add('over');
  }

  @override
  void update(double dt) {
    super.update(dt);
    dt = math.min(dt, 1 / 20);
    time += dt;
    fx.update(dt);
    if (mode == Mode.playing) {
      phaseT += dt;
      final c = cur!;
      c.vt += dt;
      switch (phase) {
        case Phase.tuning:
          if (phaseT > (c.boss ? 1.9 : 1.35)) {
            phase = Phase.play;
            phaseT = 0;
            Sfx.play('go');
          }
        case Phase.play:
          final gdt = dt * speed;
          c.t += gdt;
          c.update(gdt);
          if (c.res == 0 && c.t >= c.dur) {
            c.survive ? c.win() : c.lose('¡Tiempo!');
          }
          if (c.res != 0) {
            if (c.since > .35 || c.t >= c.dur) _finish(c.res > 0);
          } else if (c.t.floor() != (c.t - gdt).floor() && c.dur - c.t < 3.2) {
            Sfx.play('tick');
          }
        case Phase.result:
          if (phaseT > .9) lives <= 0 ? _gameOver() : _nextChannel();
      }
    }
    ptr
      ..pressed = false
      ..dx = 0
      ..dy = 0;
  }

  // ───────────── Dibujo ─────────────
  @override
  void render(Canvas canvas) {
    // Fondo del salón, cubriendo toda la pantalla del móvil.
    Gfx.cover(canvas, 'room', Rect.fromLTWH(0, 0, size.x, size.y));
    if (mode == Mode.loading) return;
    canvas.save();
    canvas.translate(_off.dx, _off.dy);
    canvas.scale(_k);

    _topBar(canvas);
    canvas.save();
    final sh = fx.shakeOffset;
    canvas.translate(sh.dx, sh.dy);
    canvas.save();
    canvas.clipRRect(screenClip);
    _screen(canvas);
    _crt(canvas);
    canvas.restore();
    Gfx.sprite(canvas, 'tv', tvRect.left, tvRect.top, tvRect.height, ax: 0, ay: 0);
    canvas.restore();
    _hud(canvas);
    fx.render(canvas);
    canvas.restore();
    super.render(canvas);
  }

  void _topBar(Canvas c) {
    if (mode == Mode.menu) return;
    final live = mode == Mode.playing || mode == Mode.paused;
    final on = (time * 2).floor().isEven;
    Gfx.clayBall(c, 40, 24, 8, live && on ? Pal.pink : const Color(0xFF6A5A7A));
    Gfx.text(c, live ? 'EN EMISIÓN' : 'ZAPPING INFINITO', 56, 24, 17,
        align: 0, color: live ? Pal.ink : Pal.dim);
    if (mode == Mode.playing) {
      Gfx.clayBall(c, pauseBtn.dx, pauseBtn.dy, 20, const Color(0xFF4A3B60));
      final p = Paint()..color = Pal.ink;
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pauseBtn.dx - 8, pauseBtn.dy - 9, 5, 18), const Radius.circular(2)), p);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(pauseBtn.dx + 3, pauseBtn.dy - 9, 5, 18), const Radius.circular(2)), p);
    }
  }

  void _screen(Canvas c) {
    final S = screen;
    if (mode == Mode.menu || mode == Mode.loading) {
      // Modo demostración: Tito presentando, con cortes de estática.
      Gfx.cover(c, 'bg_screw', S.inflate(6));
      Gfx.sprite(c, 'host_body', S.center.dx, S.bottom + 12, 230, ay: 1);
      Gfx.anim(c, 'host_head', time, S.center.dx, S.bottom - 247, 150, rot: math.sin(time * 1.3) * .08);
      if ((time % 6) > 5.6) _noise(c, 1);
      return;
    }
    final ch = cur;
    if (mode == Mode.over || ch == null) {
      _noise(c, 1);
      return;
    }
    if (phase == Phase.tuning) {
      _tuning(c, ch);
      return;
    }
    ch.render(c);
    if (phase == Phase.play && ch.t < .8) {
      final k = 1 + math.max(0.0, .4 - ch.t) * 1.5;
      Gfx.text(c, ch.ins, S.center.dx, S.top + 70, 42,
          scale: k, rot: math.sin(ch.t * 30) * .04, maxW: S.width - 30);
    }
    if (phase == Phase.result) {
      c.drawRect(S, Paint()..color = ok ? const Color(0x3353D8C3) : const Color(0x44FF5C7A));
      final pop = 1 + math.max(0.0, .15 - phaseT) * 3;
      Gfx.mark(c, ok, S.center.dx, S.center.dy + 30, 150 * pop);
    }
  }

  void _noise(Canvas c, double alpha) {
    final im = Gfx.noise[(time * 30).floor() % 3];
    c.drawImageRect(
        im,
        Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        screen.inflate(6),
        Paint()
          ..filterQuality = FilterQuality.none
          ..color = Color.fromRGBO(255, 255, 255, alpha));
  }

  void _tuning(Canvas c, Channel chn) {
    final S = screen;
    _noise(c, 1);
    // destello de encendido
    if (phaseT < .15) {
      final k = phaseT / .15;
      c.drawRect(Rect.fromCenter(center: S.center, width: S.width, height: 6 + k * S.height),
          Paint()..color = Color.fromRGBO(255, 255, 255, 1 - k));
    }
    final a = clamp01(phaseT * 3);
    final panel = Rect.fromLTWH(S.left + 18, S.center.dy - 140, S.width - 36, 280);
    c.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, a));
    Gfx.clayPanel(c, panel, const Color(0xEE1A1424), radius: 22);
    Gfx.text(c, 'CANAL ${ch.toString().padLeft(2, '0')}', S.center.dx, panel.top + 44, 42,
        color: chn.boss ? Pal.pink : Pal.lime);
    Gfx.text(c, chn.name, S.center.dx, panel.top + 104, 25, color: Pal.gold, maxW: panel.width - 30);
    Gfx.text(c, chn.sub, S.center.dx, panel.top + 170, 21,
        font: kBody, color: Pal.ink, maxW: panel.width - 30, outline: false);
    Gfx.text(c, chn.hint, S.center.dx, panel.bottom - 34, 18,
        font: kBody, color: Pal.teal, maxW: panel.width - 30, outline: false);
    c.restore();
  }

  void _crt(Canvas c) {
    final S = screen;
    final lines = Paint()..color = const Color(0x1A000000);
    for (var y = S.top; y < S.bottom; y += 4) {
      c.drawRect(Rect.fromLTWH(S.left, y, S.width, 2), lines);
    }
    c.drawRect(
        S.inflate(6),
        Paint()
          ..shader = ui.Gradient.radial(S.center, S.height * .78,
              [const Color(0x00000000), const Color(0x00000000), const Color(0x99000000)], [0, .55, 1]));
    // reflejo del cristal
    c.drawOval(
        Rect.fromLTWH(S.left - 40, S.top - 80, S.width * .8, S.height * .45),
        Paint()
          ..shader = ui.Gradient.linear(S.topLeft, S.center,
              [const Color(0x22FFFFFF), const Color(0x00FFFFFF)]));
  }

  void _hud(Canvas c) {
    final ch = cur;
    const bar = Rect.fromLTWH(40, 772, 460, 22);
    if (mode == Mode.playing || mode == Mode.paused) {
      if (phase == Phase.play && ch != null) {
        final f = 1 - ch.t / ch.dur;
        Gfx.clayBar(c, bar, f, f < .3 ? Pal.pink : Pal.gold);
      } else {
        Gfx.text(c, phase == Phase.tuning ? 'SINTONIZANDO…' : (ok ? 'SEÑAL OK' : 'SIN SEÑAL'),
            bar.center.dx, bar.center.dy, 18, color: Pal.dim);
      }
    }
    if (mode == Mode.menu) return;
    Gfx.text(c, 'VIDAS', 36, 822, 15, font: kBody, align: 0, color: Pal.dim);
    for (var i = 0; i < 4; i++) {
      final on = i < lives;
      final x = 62.0 + i * 62, y = 870.0;
      Gfx.sprite(c, 'life', x, y + (on ? boil(time, i.toDouble()) * 1.5 : 0), 56,
          alpha: on ? 1 : .22, rot: on ? math.sin(time * 2 + i) * .06 : 0);
      if (!on) Gfx.mark(c, false, x, y, 30);
    }
    Gfx.text(c, 'CANALES', 504, 822, 15, font: kBody, align: 1, color: Pal.dim);
    Gfx.text(c, '$score', 504, 868, 50, align: 1, color: Pal.gold);
    Gfx.text(c, 'Récord ${math.max(Prefs.best, score)}', 504, 918, 15,
        font: kBody, align: 1, color: Pal.dim, outline: false);
    if (level > 0) {
      Gfx.text(c, 'VELOCIDAD x${speed.toStringAsFixed(2)}', 36, 918, 15,
          font: kBody, align: 0, color: Pal.lime, outline: false);
    }
  }
}
