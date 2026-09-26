import 'dart:math';
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart' show EdgeInsets;

import 'audio.dart';
import 'gfx.dart';
import 'life.dart';
import 'prefs.dart';

enum Mode { loading, menu, playing, paused, over }

const double kSY = 96, kSH = 644, kSB = kSY + kSH, kGY = kSY + 570, kPX = 170;
const _icons = ['apple', 'coin', 'star', 'heart'];
const _stageCols = [Color(0xFF8FD3FF), Color(0xFFFF9EB3), Color(0xFF7D8FC0), Color(0xFFC79AE0), Color(0xFFF0A45A)];

class Ent {
  Ent(this.haz, this.id, this.x, this.y, {this.w = 0, this.h = 0, this.air = false}) : bob = rnd(0, 6);
  final bool haz;
  final String id;
  double x, y;
  final double w, h, bob;
  final bool air;
  bool gone = false, seen = false;
  double hitT = 0;
}

class Follower {
  Follower(this.id, this.key, this.tx, this.h) : frame = rnd(0, 16);
  final String id;
  String key;
  double x = -60, y = kGY, vy = 0, tx, h, frame;
  bool leave = false;
}

class Moment {
  Moment(this.id, this.title, this.hint);
  final String id, title, hint;
  double t = 0, dur = 4, endT = 0, x = 0, v = 0, k = 1;
  int got = 0, n = 0;
  bool done = false, res = false;
  final List<MObj> objs = [];
}

class MObj {
  MObj({this.x = 0, this.y = 0, this.vx = 0, this.vy = 0, this.d = 0, this.t = 0});
  double x, y, vx, vy, d, t, rot = 0;
  bool live = true, got = false;
  int hit = 0;
}

class VidaGame extends FlameGame implements LifeListener {
  late LifeData data;
  Life? life;
  Mode mode = Mode.loading;
  final fx = Fx();
  EdgeInsets safeArea = EdgeInsets.zero;

  // runner
  double dist = 0, speedMul = 1, spawnT = 1.5, fade = 1, stageBanner = 0, deathT = 0, cardT = 0;
  int prevStage = 0;
  final List<Ent> ents = [];
  final List<Follower> followers = [];
  double py = kGY, pvy = 0, pframe = 0, pland = 0, pstumble = 0, pinv = 0;
  bool pground = true, endShown = false;
  int pjumps = 0;
  Moment? moment;
  final List<double> shown = [0, 0, 0, 0], flash = [0, 0, 0, 0];
  double time = 0;

  // Escalado del lienzo lógico a la pantalla
  double _scale = 1;
  Offset _off = Offset.zero;

  Life get L => life!;
  Json get stageData => data.stages[L.stage];

  /// Se llama cuando cambia algo que la interfaz Flutter debe redibujar.
  void Function()? onUi;

  @override
  Future<void> onLoad() async {
    data = await LifeData.load();
    await Gfx.load([...data.pickups.keys, ...data.hazards.keys], [for (final s in data.stages) s['bg'] as String]);
    await Audio.load();
    toMenu();
  }

  // ---------------- flujo ----------------
  void toMenu() {
    mode = Mode.menu;
    overlays.removeAll(['card', 'over', 'pause', 'hud']);
    overlays.add('menu');
    Audio.music(null);
  }

  void play() {
    life = Life(data, this);
    dist = 0;
    speedMul = 1;
    spawnT = 1.5;
    fade = 1;
    stageBanner = 0;
    deathT = 0;
    prevStage = 0;
    ents.clear();
    followers.clear();
    py = kGY;
    pvy = 0;
    pground = true;
    pjumps = 0;
    pstumble = pinv = pland = 0;
    moment = null;
    endShown = false;
    fx.parts.clear();
    fx.floats.clear();
    for (var i = 0; i < 4; i++) {
      shown[i] = L.st[i];
    }
    mode = Mode.playing;
    overlays.removeAll(['menu', 'over', 'pause', 'card']);
    overlays.add('hud');
    L.banner('', 'Toca para saltar. Recoge lo bueno, esquiva lo malo.', 'msg');
    Audio.music('music_0');
  }

  void pause() {
    if (mode != Mode.playing) return;
    mode = Mode.paused;
    overlays.add('pause');
    Audio.pauseAll();
  }

  void resume() {
    if (mode != Mode.paused) return;
    mode = Mode.playing;
    overlays.remove('pause');
    Audio.resumeAll();
  }

  // ---------------- LifeListener ----------------
  @override
  void statChanged(int i, double dv) {
    flash[i] = 1;
    fx.float('${dv > 0 ? '+' : ''}${dv.round()}', 506, 790 + i * 42.0, kStatCols[i], 26);
  }

  @override
  void sound(String name) => Audio.play(name);

  @override
  void yearPassed(int age, bool birthday) {
    Audio.play('tick', volume: 0.5);
    if (birthday) {
      Audio.play('bday');
      fx.burst(kPX, kGY - 200, const Color(0xFFFFD35A), n: 24, sp: 300, up: 200);
      fx.float('¡$age AÑOS!', kPX, kGY - 250, kAccent, 34);
    }
  }

  @override
  void stageChanged(int stage) {
    fade = 0;
    stageBanner = 2.6;
    Audio.play('stage');
    Audio.music('music_$stage');
    fx.burst(kPX, kGY - 100, kCream, n: 30, sp: 220, up: 80);
  }

  @override
  void cardOpened(Json event) {
    cardT = 0;
    Audio.play('card');
    Audio.haptic();
    overlays.add('card');
    onUi?.call();
  }

  @override
  void momentWanted() => startMoment();

  @override
  void died() {
    deathT = 0;
    moment = null;
    overlays.remove('card');
    fx.shake(8, 0.5);
    Audio.play('death');
    Audio.haptic(strong: true);
    Audio.music('music_end');
  }

  @override
  void familyChanged() => syncFollowers();

  void choose(int i, {bool auto = false}) {
    if (life?.card == null) return;
    overlays.remove('card');
    Audio.play('choose');
    Audio.haptic();
    final hurt = L.choose(i, auto: auto);
    if (hurt) {
      fx.shake(12, 0.35);
      pstumble = 0.7;
    }
  }

  // ---------------- familia ----------------
  void syncFollowers() {
    final l = L, want = <(String, String, double, double)>[];
    if (l.flag('pareja')) {
      final old = l.age >= 62, base = l.partner == 'Marga' ? 'marga' : 'lucia';
      var key = old ? '${base}_old' : base;
      if (!Gfx.meta.containsKey(key)) key = old ? 'lucia_old' : base;
      want.add(('pareja', key, 92, old ? 178 : 192));
    }
    if (l.flag('hija')) {
      final ha = (l.age - l.hijaAge).toDouble();
      want.add(('hija', ha < 16 ? 'alba' : 'alba_adult', 34, ha < 16 ? (70 + ha * 7).clamp(70, 165).toDouble() : 180));
    }
    if (l.flag('perro')) want.add(('perro', 'dog', 262, 62));
    for (final w in want) {
      final f = followers.where((f) => f.id == w.$1).firstOrNull;
      if (f != null) {
        if (f.key != w.$2) {
          f.key = w.$2;
          fx.burst(f.x, kGY - 80, kCream, n: 16, sp: 160);
        }
        f.tx = w.$3;
        f.h = w.$4;
        f.leave = false;
      } else {
        followers.add(Follower(w.$1, w.$2, w.$3, w.$4));
      }
    }
    for (final f in followers) {
      if (!want.any((w) => w.$1 == f.id)) f.leave = true;
    }
  }

  // ---------------- entrada ----------------
  Offset toLogical(Offset p) => (p - _off) / _scale;

  void tap(Offset screen) {
    if (mode != Mode.playing || life == null || L.dead || L.card != null) return;
    final p = toLogical(screen);
    if (p.dy < kSY) return; // barra superior (botón de pausa)
    if (moment != null) {
      momentTap(p.dx, p.dy);
    } else {
      jump();
    }
  }

  double curH() {
    final a = L.age;
    return a < 13 ? 118 + a * 4.2 : a < 20 ? 188 : a < 45 ? 206 : a < 65 ? 200 : 186;
  }

  String spriteKey() {
    final s = stageData['sprite'] as String;
    return Gfx.meta.containsKey(s) ? s : (L.stage <= 1 ? 'ramon0' : 'ramon2');
  }

  void jump() {
    final st = stageData, j = (st['jump'] as num).toDouble();
    if (pground) {
      pvy = -j;
      pground = false;
      pjumps = 1;
      Audio.play('jump');
      fx.dust(kPX, kGY, 5);
    } else if (st['dbl'] == true && pjumps < 2) {
      pvy = -j * 0.82;
      pjumps = 2;
      Audio.play('jump2');
      fx.burst(kPX, py, kCream, n: 8, sp: 120);
    }
  }

  // ---------------- runner ----------------
  String _wpick(Map m) {
    var s = 0.0;
    m.forEach((_, v) => s += (v as num));
    var r = rnd(0, s);
    for (final e in m.entries) {
      r -= e.value as num;
      if (r < 0) return e.key as String;
    }
    return m.keys.first as String;
  }

  void spawn() {
    final sp = data.spawn[L.stage], x = kW + 80, r = rnd(0, 1);
    final pk = sp['pick'] as Map, hz = sp['haz'] as Map;
    void addHaz(String id, [double dx = 0]) {
      final h = data.hazards[id]!, air = h['air'] == 1;
      ents.add(Ent(true, id, x + dx, air ? kGY - rnd(215, 260) : kGY, w: (h['w'] as num).toDouble(), h: (h['h'] as num).toDouble(), air: air));
    }

    void addPick(String id, double dx, double y) => ents.add(Ent(false, id, x + dx, y));
    if (r < 0.45) {
      final id = _wpick(hz);
      addHaz(id);
      if (data.hazards[id]!['air'] != 1 && rnd(0, 1) < 0.6) {
        for (var i = -1; i <= 1; i++) {
          addPick(_wpick(pk), i * 55.0, kGY - 190 + i.abs() * 30);
        }
      }
    } else if (r < 0.62) {
      final id = _wpick(pk);
      for (var i = 0; i < 3; i++) {
        addPick(id, i * 62.0, kGY - 45);
      }
    } else if (r < 0.78) {
      addPick(_wpick(pk), 0, kGY - rnd(190, 300));
      if (rnd(0, 1) < 0.5) addHaz(_wpick(hz), 170);
    } else {
      final airs = hz.keys.where((k) => data.hazards[k]!['air'] == 1).toList();
      if (airs.isNotEmpty) {
        addHaz(airs[Random().nextInt(airs.length)] as String);
        addPick(_wpick(pk), 0, kGY - 45);
      } else {
        addHaz(_wpick(hz));
      }
    }
    final gap = sp['gap'] as List;
    spawnT = rnd((gap[0] as num).toDouble(), (gap[1] as num).toDouble()) * (L.age > 70 ? 1.2 : 1);
  }

  void updateRunner(double dt) {
    final h = curH(), speed = (stageData['speed'] as num) * speedMul;
    speedMul += ((pstumble > 0 ? 0.55 : 1) - speedMul) * 0.06;
    dist += speed * dt;
    pframe += dt * 13 * (speed / 220);
    if (!pground) {
      pvy += 2700 * dt;
      py += pvy * dt;
      if (py >= kGY) {
        py = kGY;
        pvy = 0;
        pground = true;
        pjumps = 0;
        pland = 0.15;
        fx.dust(kPX, kGY, 6);
        Audio.play('land', volume: 0.6);
      }
    }
    if (pland > 0) pland -= dt;
    if (pstumble > 0) pstumble -= dt;
    if (pinv > 0) pinv -= dt;
    if (pground && pframe.floor() % 8 == 0 && rnd(0, 1) < 0.3) fx.dust(kPX - 12, kGY, 1);
    spawnT -= dt;
    if (spawnT <= 0 && !L.dead) spawn();
    for (final e in ents) {
      e.x -= speed * dt * (e.air ? 1.25 : 1);
    }
    ents.removeWhere((e) => e.x < -120 || e.gone);
    final top = py - h * 0.86, bot = py - 6;
    for (final e in ents) {
      if (!e.haz) {
        if ((e.x - kPX).abs() < 42 && e.y > top - 20 && e.y < bot + 10) {
          e.gone = true;
          final p = data.pickups[e.id]!, f = fxOf(p['fx']);
          L.apply(f, silent: true, dimin: true);
          L.picked++;
          L.score += 3;
          var main = 0;
          for (var i = 1; i < 4; i++) {
            if (f[i] > f[main]) main = i;
          }
          fx.burst(e.x, e.y, kStatCols[main], n: 12, sp: 200);
          Audio.play(p['treat'] == 1 ? 'treat' : 'pick$main', minGapMs: 40);
          fx.float('+${f[main].round()}', e.x, e.y - 30, kStatCols[main], 28);
          if (p['treat'] == 1) fx.float('${f[0].round()}', e.x + 30, e.y - 5, kStatCols[0], 22);
        }
      } else if (pinv <= 0) {
        final hw = e.w * 0.32, htop = e.air ? e.y - e.h * 0.35 : e.y - e.h * 0.8, hbot = e.air ? e.y + e.h * 0.35 : e.y;
        if ((e.x - kPX).abs() < hw + 16 && bot > htop && top < hbot) {
          final hz = data.hazards[e.id]!, kid = L.age < 13 ? 0.5 : 1.0;
          final f = fxOf(hz['fx']);
          f[0] *= 0.7 * kid;
          L.apply(f, cause: hz['cause'] as String?);
          L.hits++;
          pstumble = 0.6;
          pinv = 1.3;
          fx.shake(9, 0.25);
          Audio.play('hit');
          Audio.haptic(strong: true);
          fx.burst(kPX + 20, py - h * 0.5, kCream, n: 10, sp: 180);
          fx.float(hz['msg'] as String, kPX, py - h - 20, kStatCols[0], 30);
          e.hitT = 0.5;
        }
      }
    }
    for (final f in followers) {
      f.x += ((f.leave ? -140 : f.tx) - f.x) * min(1, dt * 1.5);
      f.frame += dt * 13 * (speed / 220);
      if (f.y >= kGY && ents.any((e) => e.haz && !e.air && e.x > f.x && e.x - f.x < 70)) f.vy = -760;
      if (f.vy != 0 || f.y < kGY) {
        f.vy += 2700 * dt;
        f.y += f.vy * dt;
        if (f.y >= kGY) {
          f.y = kGY;
          f.vy = 0;
        }
      }
    }
    followers.removeWhere((f) => f.leave && f.x < -120);
  }

  // ---------------- momentos ----------------
  void startMoment() {
    final a = L.age;
    final list = data.moments.where((m) {
      final ages = m['ages'] as List;
      return a >= ages[0] && a <= ages[1] && ((m['need'] as List?)?.every((f) => L.flag(f as String)) ?? true);
    }).toList();
    if (list.isEmpty) return;
    final m = list[Random().nextInt(list.length)];
    final M = Moment(m['id'] as String, m['title'] as String, m['hint'] as String);
    L.lastMoment = a;
    switch (M.id) {
      case 'pelota':
        M.dur = 3.2;
        M.objs.add(MObj(x: kW + 30, y: kSY + 160, vx: -300, vy: -80));
      case 'monedas':
        for (var i = 0; i < 5; i++) {
          M.objs.add(MObj(x: rnd(80, kW - 80), y: kSB + 30, vy: -rnd(620, 760), d: i * 0.32));
        }
      case 'corazones':
        for (var i = 0; i < 4; i++) {
          M.objs.add(MObj(x: rnd(80, kW - 80), y: kSB + 30, d: i * 0.45));
        }
      case 'ritmo':
        M.dur = 4.6;
        for (var i = 0; i < 4; i++) {
          M.objs.add(MObj(t: 0.7 + i * 0.95));
        }
      case 'informe':
        M.dur = 3.4;
        M.n = 16;
      default: // equilibrio, bebe
        M.dur = 3.8;
        M.x = rnd(-0.15, 0.15);
        M.k = a > 60 ? 1.35 : 1;
    }
    moment = M;
    Audio.play('moment');
    Audio.haptic();
  }

  void momentTap(double x, double y) {
    final M = moment;
    if (M == null || M.t < 0.35 || M.done) return;
    switch (M.id) {
      case 'pelota':
        final o = M.objs[0];
        if (!o.got && (Offset(x, y) - Offset(o.x, o.y)).distance < 80) {
          o.got = true;
          M.res = true;
          fx.burst(o.x, o.y, const Color(0xFFFFD35A), n: 20);
          Audio.play('good');
          L.apply([2, 0, 5, 0]);
          fx.float('¡La cogiste!', kPX, kGY - 250, const Color(0xFF6C9A3C));
        }
      case 'monedas':
      case 'corazones':
        final coin = M.id == 'monedas';
        final o = M.objs.where((o) => o.live && M.t >= o.d && (Offset(x, y) - Offset(o.x, o.y)).distance < 60).firstOrNull;
        if (o != null) {
          o.live = false;
          M.got++;
          fx.burst(o.x, o.y, coin ? kStatCols[1] : kStatCols[0], n: 14);
          Audio.play(coin ? 'pick1' : 'pick3');
          L.apply(coin ? [0, 3, 0, 0] : [0, 0, 1, 3]);
        }
      case 'ritmo':
        final b = M.objs.where((o) => o.hit == 0 && (M.t - o.t).abs() < 0.45).firstOrNull;
        if (b != null) {
          final dd = (M.t - b.t).abs();
          b.hit = dd < 0.13 ? 2 : dd < 0.25 ? 1 : -1;
          if (b.hit > 0) {
            M.got += b.hit;
            fx.burst(kW / 2, kSY + 300, kStatCols[0], n: b.hit * 10);
            Audio.play('pick3');
            fx.float(b.hit == 2 ? '¡Perfecto!' : '¡Bien!', kW / 2, kSY + 180, kAccent);
          } else {
            Audio.play('bad');
            fx.float('Pisotón', kW / 2, kSY + 180, const Color(0xFF8C6A4A));
          }
        }
      case 'informe':
        M.got++;
        Audio.play('tap', volume: 0.6);
        fx.dust(rnd(200, 340), kSY + 420, 2);
        if (M.got >= M.n) endMoment(true);
      default:
        M.v += (x < kW / 2 ? -1 : 1) * 0.55;
    }
  }

  void endMoment(bool ok) {
    final M = moment;
    if (M == null || M.done) return;
    M.done = true;
    M.endT = 0.7;
    const green = Color(0xFF6C9A3C), brown = Color(0xFF8C6A4A);
    switch (M.id) {
      case 'pelota':
        if (!M.res) {
          fx.float('Se te escapa', kPX, kGY - 250, brown);
          L.apply([0, 0, -3, 0]);
        }
      case 'monedas':
      case 'corazones':
        if (M.got == M.objs.length) {
          fx.float('¡Perfecto!', kW / 2, kSY + 170, green, 38);
          Audio.play('good');
          L.apply(M.id == 'monedas' ? [0, 5, 2, 0] : [0, 0, 3, 3]);
        }
      case 'ritmo':
        if (M.got >= 6) {
          fx.float('¡Bailas de maravilla!', kW / 2, kSY + 170, green, 34);
          L.apply([0, 0, 6, 8]);
          Audio.play('good');
        } else if (M.got <= 2) {
          fx.float('Pisas a todo el mundo', kW / 2, kSY + 170, brown, 30);
          L.apply([0, 0, -3, -3]);
        }
      case 'informe':
        if (ok) {
          fx.float('¡Entregado a tiempo!', kW / 2, kSY + 170, green, 34);
          L.apply([0, 10, -2, 0]);
          Audio.play('good');
        } else {
          fx.float('Llega tarde. Otra vez.', kW / 2, kSY + 170, brown, 30);
          L.apply([0, -4, -4, 0]);
          Audio.play('bad');
        }
      default:
        final baby = M.id == 'bebe';
        if (ok) {
          fx.float(baby ? '¡Se ha dormido!' : '¡Equilibrio perfecto!', kW / 2, kSY + 170, green, 34);
          L.apply(baby ? [0, 0, 5, 8] : [6, 0, 2, 0]);
          Audio.play('good');
        } else {
          fx.float(baby ? 'Llora aún más fuerte' : '¡Te caes de culo!', kW / 2, kSY + 170, kStatCols[0], 32);
          L.apply(baby ? [-2, 0, -4, -2] : [-8, 0, -3, 0], cause: 'una caída tonta');
          fx.shake(10, 0.3);
          Audio.play('hit');
          pstumble = 0.7;
        }
    }
  }

  void updateMoment(double dt) {
    final M = moment!;
    M.t += dt;
    if (M.done) {
      M.endT -= dt;
      if (M.endT <= 0) moment = null;
      return;
    }
    switch (M.id) {
      case 'pelota':
        final o = M.objs[0];
        if (!o.got) {
          o.x += o.vx * dt;
          o.vy += 220 * dt;
          o.y += o.vy * dt;
          o.rot -= dt * 6;
          if (o.x < -40 || o.y > kSB) endMoment(false);
        } else {
          o.x += (kPX + 34 - o.x) * 0.3;
          o.y += (kGY - curH() * 0.55 - o.y) * 0.3;
          if (M.t > M.dur) endMoment(true);
        }
      case 'monedas':
      case 'corazones':
        final coin = M.id == 'monedas';
        for (final o in M.objs) {
          if (!o.live || M.t < o.d) continue;
          if (coin) {
            o.vy += 900 * dt;
            o.y += o.vy * dt;
            if (o.y > kSB + 40 && o.vy > 0) o.live = false;
          } else {
            o.y -= 200 * dt;
            o.x += sin(M.t * 3 + o.d * 5) * 40 * dt;
            if (o.y < kSY - 30) o.live = false;
          }
        }
        if (M.t > 0.5 && M.objs.every((o) => !o.live)) endMoment(true);
      case 'ritmo':
        for (final b in M.objs) {
          if (b.hit == 0 && M.t - b.t > 0.45) b.hit = -1;
        }
        if (M.t > M.dur) endMoment(true);
      case 'informe':
        if (M.t > M.dur) endMoment(false);
      default:
        M.v += (M.x * 2.4 * M.k + rnd(-2.6, 2.6) * M.k) * dt;
        M.v *= 0.985;
        M.x += M.v * dt;
        if (M.x.abs() >= 1) {
          endMoment(false);
        } else if (M.t > M.dur) {
          endMoment(true);
        }
    }
  }

  // ---------------- bucle ----------------
  @override
  void update(double dt) {
    super.update(dt);
    dt = min(dt, 0.05);
    time += dt;
    fx.update(dt);
    if (mode != Mode.playing || life == null) return;
    final l = L;
    for (var i = 0; i < 4; i++) {
      flash[i] = max(0, flash[i] - dt * 2);
      shown[i] += (l.st[i] - shown[i]) * min(1, dt * 6);
    }
    fade = min(1, fade + dt / 1.4);
    if (fade >= 1) prevStage = l.stage;
    if (stageBanner > 0) stageBanner -= dt;
    if (l.banners.isNotEmpty) {
      l.banners.first.time += dt;
      if (l.banners.first.time > 3.2) l.banners.removeAt(0);
    }
    if (l.dead) {
      deathT += dt;
      speedMul += (0 - speedMul) * 0.04;
      updateRunner(dt * (1 - deathT).clamp(0, 1));
      if (deathT > 3.2 && !endShown) {
        endShown = true;
        mode = Mode.over;
        overlays.remove('hud');
        overlays.add('over');
      }
      return;
    }
    if (l.card != null) {
      cardT += dt;
      onUi?.call();
      if (cardT > 10) choose(Random().nextInt((l.card!['o'] as List).length), auto: true);
      return;
    }
    if (moment != null) {
      updateMoment(dt);
      return;
    }
    updateRunner(dt);
    l.advance(dt);
  }

  @override
  void render(Canvas canvas) {
    final sw = size.x, sh = size.y;
    canvas.drawRect(Rect.fromLTWH(0, 0, sw, sh), Paint()..color = const Color(0xFF2B1D14));
    _scale = min(sw / kW, sh / kH);
    _off = Offset((sw - kW * _scale) / 2, (sh - kH * _scale) / 2);
    canvas.save();
    canvas.translate(_off.dx, _off.dy);
    canvas.scale(_scale);
    canvas.clipRect(const Rect.fromLTWH(0, 0, kW, kH));
    if (mode == Mode.menu || mode == Mode.loading || life == null) {
      _drawCover(canvas, 'title');
    } else {
      _drawPlay(canvas);
    }
    canvas.restore();
    super.render(canvas);
  }

  void _drawCover(Canvas c, String key, {double alpha = 1}) {
    final im = Gfx.img[key];
    if (im == null) return;
    final s = max(kW / im.width, kH / im.height), w = im.width * s, h = im.height * s;
    Gfx.image(c, key, Rect.fromLTWH((kW - w) / 2, (kH - h) / 2, w, h), alpha: alpha);
  }

  void _drawBg(Canvas c, String key, double alpha) {
    final im = Gfx.img[key];
    if (im == null || alpha <= 0) return;
    final s = kSH / im.height, w = im.width * s, off = dist % w;
    for (var x = -off; x < kW; x += w) {
      Gfx.image(c, key, Rect.fromLTWH(x, kSY, w + 1, kSH), alpha: alpha);
    }
  }

  void _drawPlay(Canvas c) {
    final l = L, t = time;
    c.save();
    if (fx.shakeA > 0) c.translate(rnd(-fx.shakeA, fx.shakeA), rnd(-fx.shakeA, fx.shakeA));
    c.save();
    c.clipRect(const Rect.fromLTWH(0, kSY, kW, kSH));
    if (fade < 1) _drawBg(c, data.stages[prevStage]['bg'] as String, 1);
    _drawBg(c, stageData['bg'] as String, fade);
    for (final e in ents) {
      if (e.haz) {
        if (!e.air) Gfx.shadow(c, e.x, kGY + 2, e.w * 0.45);
        final wob = e.air ? sin(t * 8 + e.bob) * 6 : 0.0;
        if (e.hitT > 0) e.hitT -= 1 / 60;
        Gfx.item(c, e.id, e.x, e.air ? e.y + wob : e.y - e.h / 2, e.h * (e.air ? 1 : 1.05), rot: e.hitT > 0 ? sin(t * 40) * 0.2 : 0);
      } else {
        if (e.y > kGY - 60) Gfx.shadow(c, e.x, kGY + 2, 18);
        Gfx.item(c, e.id, e.x, e.y + sin(t * 4 + e.bob) * 5, 50, sx: 1 + sin(t * 6 + e.bob) * 0.04);
      }
    }
    for (final f in followers) {
      Gfx.shadow(c, f.x, kGY + 2, f.id == 'perro' ? 26 : 30);
      Gfx.sprite(c, f.key, f.frame, f.x, f.y, f.h);
    }
    _drawRamon(c, t);
    fx.renderParts(c);
    if (moment != null) _drawMoment(c, t);
    if (l.card != null) c.drawRect(const Rect.fromLTWH(0, kSY, kW, kSH), Paint()..color = const Color(0x592B1D14));
    if (l.dead) c.drawRect(const Rect.fromLTWH(0, kSY, kW, kSH), Paint()..color = Color.fromRGBO(20, 12, 30, (deathT / 3).clamp(0, 0.6)));
    _drawBanners(c);
    c.restore();
    fx.renderFloats(c);
    _drawHud(c, t);
    c.restore();
    if (l.dead && deathT > 2.4) {
      final im = Gfx.img['tomb'];
      if (im != null) {
        final h = im.height * kW / im.width;
        Gfx.image(c, 'tomb', Rect.fromLTWH(0, (kH - h) / 2, kW, h), alpha: ((deathT - 2.4) / 1.2).clamp(0, 1));
      }
    }
  }

  void _drawRamon(Canvas c, double t) {
    final key = spriteKey(), h = curH();
    var rot = 0.0, sx = 1.0, sy = 1.0, alpha = 1.0, frame = pframe;
    final bal = moment != null && (moment!.id == 'equilibrio' || moment!.id == 'bebe');
    if (!pground) {
      frame = 4;
      rot = (pvy / 3000).clamp(-0.15, 0.2);
      sx = 0.95;
      sy = 1.06;
    }
    if (pland > 0) {
      sx = 1.1;
      sy = 0.9;
    }
    if (pstumble > 0) rot = sin(pstumble * 18) * 0.12 + 0.18;
    if (pinv > 0 && (t * 14).floor() % 2 == 1) alpha = 0.55;
    if (life!.card != null || (moment != null && !bal)) {
      frame = 0;
      sy = 1 + sin(t * 3) * 0.012;
    }
    if (bal) {
      frame = 0;
      rot = moment!.x * 0.7;
    }
    Gfx.shadow(c, kPX, kGY + 2, 32 * (1 - ((kGY - py) / 400).clamp(0, 0.6)));
    if (!life!.dead) {
      Gfx.sprite(c, key, frame, kPX, py, h, rot: rot, sx: sx, sy: sy, alpha: alpha);
      return;
    }
    final d = deathT;
    Gfx.sprite(c, key, 0, kPX, py, h, alpha: (1 - d / 2.4).clamp(0, 1), rot: d.clamp(0, 1) * -0.05);
    // el alma sube con su aureola
    final a = (d / 1.2).clamp(0.0, 1.0) * (3.2 - d).clamp(0.0, 1.0);
    const white = ColorFilter.matrix([0.3, 0.3, 0.3, 0, 120, 0.3, 0.3, 0.3, 0, 120, 0.3, 0.3, 0.3, 0, 120, 0, 0, 0, 0.7, 0]);
    Gfx.sprite(c, key, 0, kPX, py - d * 70, h, alpha: a, filter: white);
    c.drawOval(Rect.fromCenter(center: Offset(kPX + 8, py - d * 70 - h * 1.02), width: 60, height: 18),
        Paint()
          ..color = const Color(0xFFFFD35A).withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
  }

  void _drawBanners(Canvas c) {
    if (stageBanner > 0) {
      final a = stageBanner.clamp(0.0, 1.0) * ((2.6 - stageBanner) * 3).clamp(0.0, 1.0), y = kSY + 200;
      Gfx.paperBox(c, Rect.fromLTWH(70, y - 55, 400, 110), alpha: a);
      Gfx.text(c, 'NUEVA ETAPA', kW / 2, y - 22, size: 22, color: kAccent, alpha: a, font: 'Chewy');
      Gfx.text(c, stageData['name'] as String, kW / 2, y + 16, size: 50, alpha: a, font: 'Chewy');
    }
    final l = L;
    if (l.banners.isEmpty || l.card != null) return;
    final b = l.banners.first;
    final a = (b.time * 4).clamp(0.0, 1.0) * ((3.2 - b.time) * 3).clamp(0.0, 1.0);
    final lines = Gfx.wrap(b.text, 440, 28);
    final hh = 30 + lines.length * 32 + (b.head.isNotEmpty ? 26 : 0), y = kSY + 24;
    c.save();
    c.translate(0, (1 - a) * -30);
    Gfx.paperBox(c, Rect.fromLTWH(34, y, 472, hh.toDouble()), alpha: a);
    var yy = y + 26;
    if (b.head.isNotEmpty) {
      final col = {'later': const Color(0xFF9B59B6), 'auto': const Color(0xFF9B59B6), 'risk': kStatCols[0], 'life': const Color(0xFF8C6A4A)}[b.kind] ?? kAccent;
      Gfx.text(c, b.head, kW / 2, yy, size: 20, color: col, alpha: a, font: 'Chewy');
      yy += 28;
    }
    for (var i = 0; i < lines.length; i++) {
      Gfx.text(c, lines[i], kW / 2, yy + i * 32, size: 28, alpha: a);
    }
    c.restore();
  }

  void _drawMoment(Canvas c, double t) {
    final M = moment!;
    final a = (M.t * 4).clamp(0.0, 1.0) * (M.done ? (M.endT / 0.3).clamp(0.0, 1.0) : 1.0);
    c.drawRect(const Rect.fromLTWH(0, kSY, kW, kSH), Paint()..color = Color.fromRGBO(43, 29, 20, 0.25 * a));
    Gfx.text(c, M.title, kW / 2, kSY + 60, size: 42, color: kCream, stroke: kInk, sw: 8, alpha: a, font: 'Chewy');
    if (M.t < 1.6 && !M.done) Gfx.text(c, M.hint, kW / 2, kSY + 104, size: 26, color: kCream, stroke: kInk, sw: 6, alpha: a * (1.6 - M.t).clamp(0, 1));
    if (!M.done) {
      Gfx.rrect(c, const Rect.fromLTWH(120, kSY + 128, 300, 12), 6, fill: kCream, stroke: kInk, lw: 2);
      Gfx.rrect(c, Rect.fromLTWH(120, kSY + 128, 300 * (1 - M.t / M.dur).clamp(0, 1), 12), 6, fill: kAccent);
    }
    switch (M.id) {
      case 'pelota':
        Gfx.item(c, 'ball', M.objs[0].x, M.objs[0].y, 64, rot: M.objs[0].rot);
      case 'monedas':
      case 'corazones':
        for (final o in M.objs) {
          if (o.live && M.t >= o.d) Gfx.item(c, M.id == 'monedas' ? 'coin' : 'heart', o.x, o.y, 72, rot: sin(t * 5 + o.d) * 0.2);
        }
      case 'ritmo':
        const cx = kW / 2, cy = kSY + 300;
        Gfx.item(c, 'heart', cx, cy, 90 + sin(t * 10) * 4);
        final next = M.objs.where((b) => b.hit == 0).firstOrNull;
        if (next != null) {
          final k = ((next.t - M.t) / 0.9).clamp(0.0, 1.0);
          c.drawCircle(const Offset(cx, cy), 48 + k * 150, Paint()
            ..color = kAccent.withValues(alpha: 1 - k * 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8);
        }
        c.drawCircle(const Offset(cx, cy), 48, Paint()
          ..color = const Color(0xB3FFF8EC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
        for (var i = 0; i < M.objs.length; i++) {
          final b = M.objs[i];
          Gfx.item(c, 'heart', cx - 75 + i * 50, cy + 130, 32, alpha: b.hit > 0 ? 1 : b.hit < 0 ? 0.2 : 0.45);
        }
      case 'informe':
        for (var i = 0; i < min(M.got, M.n); i++) {
          Gfx.item(c, 'bills', kW / 2 + sin(i * 7.0) * 8, kSY + 470 - i * 9, 60, rot: sin(i * 3.0) * 0.1);
        }
        Gfx.rrect(c, const Rect.fromLTWH(110, kSY + 520, 320, 26), 12, fill: kCream, stroke: kInk);
        Gfx.rrect(c, Rect.fromLTWH(110, kSY + 520, 320 * M.got / M.n, 26), 12, fill: kStatCols[1]);
        Gfx.text(c, '${M.got}/${M.n}', kW / 2, kSY + 533, size: 22);
      default:
        const y = kSY + 170;
        Gfx.rrect(c, const Rect.fromLTWH(120, y, 300, 20), 10, fill: kCream, stroke: kInk);
        c.drawRect(const Rect.fromLTWH(kW / 2 - 60, y + 3, 120, 14), Paint()..color = const Color(0x998CC152));
        c.drawCircle(Offset(kW / 2 + M.x * 150, y + 10), 14, Paint()..color = kAccent);
        Gfx.text(c, '◀', 60, kSY + 400, size: 60, color: const Color(0x99FFF8EC));
        Gfx.text(c, '▶', kW - 60, kSY + 400, size: 60, color: const Color(0x99FFF8EC));
        if (M.id == 'bebe') Gfx.text(c, 'zZz', kPX + 60, kGY - curH() - 20 + sin(t * 3) * 6, size: 30, color: kCream, stroke: kInk, sw: 5);
    }
  }

  void _drawHud(Canvas c, double t) {
    final l = L;
    c.drawRect(const Rect.fromLTWH(0, 0, kW, kSY), Paint()..color = const Color(0xFF2B1D14));
    Gfx.text(c, 'RAMÓN', 22, 30, size: 22, color: const Color(0xFFE8C9A0), align: -1, font: 'Chewy');
    Gfx.text(c, '${l.age} ${l.age == 1 ? 'año' : 'años'}', 22, 66, size: 40, color: kCream, align: -1, font: 'Chewy');
    Gfx.text(c, stageData['name'] as String, 175, 30, size: 22, color: const Color(0xFFE8C9A0), align: -1, font: 'Chewy');
    Gfx.text(c, '${l.score.round()} pts', 452, 30, size: 26, color: const Color(0xFFFFD35A), align: 1, font: 'Chewy');
    const rx = 175.0, rw = 280.0, ry = 62.0;
    for (var i = 0; i < data.stages.length; i++) {
      final a = (data.stages[i]['from'] as num).toDouble(), b = i + 1 < data.stages.length ? (data.stages[i + 1]['from'] as num).toDouble() : 100.0;
      c.drawRect(Rect.fromLTWH(rx + rw * a / 100, ry, rw * (b - a) / 100, 10), Paint()..color = _stageCols[i]);
    }
    Gfx.rrect(c, const Rect.fromLTWH(rx, ry, rw, 10), 5, stroke: kCream, lw: 2);
    final px = rx + rw * ((l.age + l.yt) / 100).clamp(0, 1);
    c.drawPath(Path()
      ..moveTo(px, ry - 2)
      ..lineTo(px - 7, ry - 12)
      ..lineTo(px + 7, ry - 12)
      ..close(), Paint()..color = kCream);
    c.drawRect(const Rect.fromLTWH(0, kSB, kW, kH - kSB), Paint()..color = kInk);
    c.drawRect(const Rect.fromLTWH(0, kSB, kW, 6), Paint()..color = const Color(0xFF4A2F1D));
    for (var i = 0; i < 4; i++) {
      final y = kSB + 50 + i * 42.0, v = shown[i];
      Gfx.item(c, _icons[i], 40, y, 36 + flash[i] * 10);
      Gfx.text(c, data.stats[i], 70, y, size: 24, color: const Color(0xFFF4E2C4), align: -1);
      Gfx.rrect(c, Rect.fromLTWH(190, y - 12, 270, 24), 12, fill: const Color(0xFF2B1D14), stroke: const Color(0xFFF4E2C4), lw: 2);
      if (v > 0.5) Gfx.rrect(c, Rect.fromLTWH(192, y - 10, 266 * v / 100, 20), 10, fill: kStatCols[i]);
      if (v < 20 && (t * 4).floor() % 2 == 1) Gfx.rrect(c, Rect.fromLTWH(190, y - 12, 270, 24), 12, stroke: kStatCols[0]);
      Gfx.text(c, '${v.round()}', 476, y, size: 24, color: kCream, align: -1, font: 'Chewy');
    }
  }

  /// Récord al terminar una vida (lo llama la pantalla final una sola vez).
  late final Map<Life, bool> _submitted = {};
  bool submitScore() => _submitted.putIfAbsent(L, () => Prefs.submit(L.finalScore, L.age));
}
