import 'dart:math' as math;
import 'dart:ui';

import 'channels.dart';
import 'game.dart';
import 'gfx.dart';
import 'sfx.dart';

/// Los 30 canales: los 12 originales y los 18 nuevos.
final List<ChannelFactory> allChannels = [
  ...channelFactories,
  KungFu.new, Slingshot.new, Signature.new, Karaoke.new, CountUfos.new,
  CakeStack.new, BubbleGum.new, OddClone.new, Moles.new, Sushi.new,
  Balance.new, UfoParking.new, Disco.new, Doorman.new, Vault.new,
  WashMonster.new, Lasso.new, PingPong.new,
];

// Canales 13–30. Cada uno usa una mecánica distinta (deslizar, apuntar, trazar, memoria…).
// Las posiciones "bx/by" están medidas sobre cada decorado para que los personajes pisen su suelo.

// ───────────────────────── 13. DOJO DEL MAESTRO BLANDO (deslizar) ─────────────────────────
class KungFu extends Channel {
  KungFu(super.g);
  @override
  String get name => 'DOJO DEL MAESTRO BLANDO';
  @override
  String get sub => 'Rompe las tablas en la dirección que marca el maestro';
  @override
  String get ins => '¡DESLIZA!';
  @override
  String get hint => 'Desliza el dedo como la flecha';
  @override
  String get bg => 'bg_dojo';

  final dirs = <int>[];
  int i = 0;
  double breakAt = -9, boardIn = 0;
  double get boardX => bx(.68);
  double get boardY => by(.6);
  static const boardW = 170.0;

  void _block(Canvas c, double x) {
    final r = Rect.fromLTRB(x - 24, boardY + 10, x + 24, by(.78));
    Gfx.shadow(c, x, r.bottom, 70);
    Gfx.clayPanel(c, r, const Color(0xFF8A8A92), radius: 8);
  }

  @override
  void init(int l) {
    final n = 3 + (l >= 2 ? 1 : 0);
    for (var k = 0; k < n; k++) {
      dirs.add(rng.nextInt(4));
    }
  }

  @override
  void update(double dt) {
    boardIn = math.min(1, boardIn + dt * 6);
    final s = swipe();
    if (s == null || res != 0) return;
    final d = s.dx.abs() > s.dy.abs() ? (s.dx > 0 ? 0 : 2) : (s.dy > 0 ? 1 : 3);
    if (d == dirs[i]) {
      i++;
      breakAt = vt;
      boardIn = 0;
      g.fx.burst(boardX, boardY, const Color(0xFFC08A50), 14, size: 6);
      g.fx.shake(4, .1);
      Sfx.play('chop');
      Sfx.haptic();
      if (i >= dirs.length) {
        win();
        Sfx.play('bonus');
      }
    } else {
      lose('¡Golpe torcido!');
      Sfx.play('boing');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    const h = 200.0;
    Gfx.shadow(c, bx(.28), by(.8), 150);
    if (res == 1) {
      Gfx.sprite(c, 'sensei_win', bx(.28), by(.8), h, ay: 1);
    } else {
      Gfx.anim(c, 'sensei', vt, bx(.28), by(.8), h, ay: 1);
    }
    // tabla rota volando
    final bt = vt - breakAt;
    if (bt < .5) {
      for (final side in [-1, 1]) {
        c.save();
        const w = boardW;
        final bh = w / Gfx.aspect('board');
        c.translate(boardX + side * (20 + bt * 260), boardY + bt * bt * 900);
        c.rotate(side * bt * 5);
        c.clipRect(side < 0 ? Rect.fromLTWH(-w / 2, -bh, w / 2, bh * 2) : Rect.fromLTWH(0, -bh, w / 2, bh * 2));
        Gfx.sprite(c, 'board', 0, 0, bh);
        c.restore();
      }
    }
    _block(c, boardX - boardW * .36);
    _block(c, boardX + boardW * .36);
    if (res != 1 && i < dirs.length) {
      final bh = boardW / Gfx.aspect('board');
      Gfx.sprite(c, 'board', boardX, boardY - (1 - boardIn) * 120, bh, ay: .5, alpha: boardIn);
      // flecha de la dirección pedida
      final pulse = 1 + math.sin(vt * 8) * .06;
      Gfx.sprite(c, 'arrow', cx, st + 92, 78 * pulse, rot: dirs[i] * math.pi / 2);
    }
    // progreso
    for (var k = 0; k < dirs.length; k++) {
      Gfx.clayBall(c, cx - (dirs.length - 1) * 16 + k * 32, st + 26, 10, k < i ? Pal.gold : const Color(0xFF5A4A40));
    }
  }
}

// ───────────────────────── 14. TIRO AL ALIEN DE LATA (tirachinas) ─────────────────────────
class _Can {
  double x, vx;
  bool hit = false;
  double fall = 0;
  _Can(this.x, this.vx);
}

class Slingshot extends Channel {
  Slingshot(super.g);
  @override
  String get name => 'TIRO AL ALIEN DE LATA';
  @override
  String get sub => 'Derriba a los aliens con albóndigas';
  @override
  String get ins => '¡APUNTA!';
  @override
  String get hint => 'Tira hacia atrás y suelta';
  @override
  String get bg => 'bg_fair';
  @override
  double get dur => 5.5;

  final cans = <_Can>[];
  bool aiming = false;
  Offset pull = Offset.zero;
  Offset? ball;
  Offset vel = Offset.zero;
  double flight = 0;
  static const slH = 150.0;
  double get shelfY => by(.44);
  Offset get rest => Offset(cx, sb - slH + 36);
  double get slW => slH * Gfx.aspect('slingshot');

  @override
  void init(int l) {
    final n = l >= 3 ? 2 : 1;
    for (var k = 0; k < n; k++) {
      cans.add(_Can(rnd(sl + 70, sr - 70), (rng.nextBool() ? 1 : -1) * (70 + l * 25.0)));
    }
  }

  @override
  void update(double dt) {
    for (final cn in cans) {
      if (cn.hit) {
        cn.fall += dt;
        continue;
      }
      cn.x += cn.vx * dt;
      if (cn.x < sl + 50 || cn.x > sr - 50) {
        cn.vx = -cn.vx;
        cn.x = cn.x.clamp(sl + 50, sr - 50);
      }
    }
    if (res != 0) return;
    if (ball == null) {
      if (p.pressed && p.y > cy) aiming = true;
      if (aiming && p.down) {
        var d = Offset(p.x, p.y) - rest;
        if (d.distance > 110) d = d / d.distance * 110;
        if (d.dy < 0) d = Offset(d.dx, 0);
        pull = d;
      }
      if (aiming && p.released) {
        aiming = false;
        if (pull.distance > 25) {
          ball = rest + pull;
          vel = -pull * 9.5;
          flight = 0;
          Sfx.play('boing', volume: .6);
        }
        pull = Offset.zero;
      }
    } else {
      flight += dt;
      vel = vel.translate(0, 700 * dt);
      ball = ball! + vel * dt;
      final scale = lerp(1, .55, clamp01(flight / .6));
      for (final cn in cans) {
        if (cn.hit) continue;
        final cc = Offset(cn.x, shelfY - 50);
        if ((ball! - cc).distance < 30 + 20 * scale && ball!.dy < shelfY) {
          cn.hit = true;
          g.fx.burst(cc.dx, cc.dy, const Color(0xFFB0B0B8), 16);
          g.fx.shake(6, .15);
          Sfx.play('bosshit');
          Sfx.haptic();
          ball = null;
          break;
        }
      }
      if (ball != null && (ball!.dy > sb + 40 || ball!.dx < sl - 40 || ball!.dx > sr + 40 || flight > 1.4)) ball = null;
      if (cans.every((c) => c.hit)) win();
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // estante hecho con una tabla
    Gfx.sprite(c, 'board', cx, shelfY + 8, S.width * .95 / Gfx.aspect('board'));
    for (final cn in cans) {
      final fallY = cn.fall * cn.fall * 900;
      if (!cn.hit) Gfx.shadow(c, cn.x, shelfY - 2, 70, ratio: .18);
      Gfx.sprite(c, cn.hit ? 'can_hit' : 'can', cn.x, shelfY + fallY, 100,
          ay: 1, rot: cn.hit ? cn.fall * 6 : boil(vt, cn.vx) * .03);
    }
    // tirachinas
    final tipL = Offset(cx - slW * .33, sb - slH + 12), tipR = Offset(cx + slW * .33, sb - slH + 12);
    final pos = ball == null ? rest + pull : null;
    final band = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFB0302A);
    if (pos != null) c.drawLine(tipL, pos, band);
    Gfx.shadow(c, cx, sb + 6, 90, alpha: .4);
    Gfx.sprite(c, 'slingshot', cx, sb + 14, slH, ay: 1);
    if (pos != null) {
      c.drawLine(tipR, pos, band);
      Gfx.sprite(c, 'meatball', pos.dx, pos.dy, 34);
      if (aiming && pull.distance > 25) {
        // puntos de trayectoria
        var q = pos, v = -pull * 9.5;
        for (var k = 0; k < 7; k++) {
          for (var s = 0; s < 4; s++) {
            v = v.translate(0, 700 * .02);
            q = q + v * .02;
          }
          Gfx.clayBall(c, q.dx, q.dy, 4, const Color(0xCCFFFFFF));
        }
      }
    }
    if (ball != null) {
      Gfx.sprite(c, 'meatball', ball!.dx, ball!.dy, 34 * lerp(1, .55, clamp01(flight / .6)), rot: flight * 10,
          drop: Offset(6, 10 + flight * 20));
    }
  }
}

// ───────────────────────── 15. FIRMA AQUÍ (trazar) ─────────────────────────
class Signature extends Channel {
  Signature(super.g);
  @override
  String get name => 'VENTANILLA NÚMERO 3';
  @override
  String get sub => 'Firma siguiendo la línea sin salirte';
  @override
  String get ins => '¡FIRMA!';
  @override
  String get hint => 'Arrastra desde el punto verde';
  @override
  String get bg => 'bg_desk';
  @override
  double get dur => 5.0;

  final pts = <Offset>[];
  int k = 0;
  bool drawing = false;

  @override
  void init(int l) {
    final x0 = bx(.2), x1 = bx(.8), yc = by(.52);
    // Más ondas, un garabato encima y menos margen: una firma de verdad.
    final ph = rnd(0, tau), loops = 1.9 + l * .3, ph2 = rnd(0, tau);
    for (var i = 0; i <= 90; i++) {
      final u = i / 90;
      pts.add(Offset(lerp(x0, x1, u),
          yc + math.sin(u * tau * loops + ph) * 50 + math.sin(u * tau * loops * 2.4 + ph2) * 16));
    }
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.pressed && (Offset(p.x, p.y) - pts[k]).distance < 40) drawing = true;
    if (!p.down) {
      drawing = false;
      return;
    }
    if (!drawing) return;
    final f = Offset(p.x, p.y);
    // avanza por los puntos cercanos
    for (var j = k + 1; j < math.min(pts.length, k + 5); j++) {
      if ((f - pts[j]).distance < 24) k = j;
    }
    var near = double.infinity;
    for (var j = math.max(0, k - 3); j < math.min(pts.length, k + 6); j++) {
      near = math.min(near, (f - pts[j]).distance);
    }
    if (near > 32) {
      lose('¡Firma torcida!');
      Sfx.play('boing');
    } else if (k >= pts.length - 1) {
      win();
      Sfx.play('pop');
      g.fx.burst(pts.last.dx, pts.last.dy, Pal.pink, 18);
    } else {
      Sfx.play('shake', volume: .25, minGapMs: 120);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // guía punteada
    for (var j = k; j < pts.length; j += 3) {
      c.drawCircle(pts[j], 3.5, Paint()..color = const Color(0x88404050));
    }
    // tinta
    if (k > 0) {
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var j = 1; j <= k; j++) {
        path.lineTo(pts[j].dx, pts[j].dy);
      }
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF2A2A7A));
    }
    Gfx.clayBall(c, pts[0].dx, pts[0].dy, 12, Pal.lime);
    Gfx.clayBall(c, pts.last.dx, pts.last.dy, 12, Pal.pink);
    // el funcionario vigila
    Gfx.shadow(c, bx(.83), by(.93) - 4, 120, alpha: .3);
    Gfx.anim(c, 'notary', vt, bx(.83), by(.93), 150, ay: 1, rot: res == -1 ? math.sin(vt * 20) * .08 : 0);
    if (res == 1) {
      Gfx.text(c, 'APROBADO', cx, by(.3), 40,
          color: const Color(0xFFD02030), rot: -.2, scale: 1 + math.max(0.0, .2 - since) * 3);
    }
    final pen = drawing ? Offset(p.x, p.y) : pts[k];
    Gfx.sprite(c, 'pen', pen.dx, pen.dy, 110, ax: .04, ay: .96, drop: drawing ? const Offset(12, 16) : const Offset(6, 8));
  }
}

// ───────────────────────── 16. KARAOKE DE COLORES (memoria) ─────────────────────────
class Karaoke extends Channel {
  Karaoke(super.g);
  @override
  String get name => 'KARAOKE DE COLORES';
  @override
  String get sub => 'Repite la canción del coro';
  @override
  String get ins => '¡ESCUCHA!';
  @override
  String get hint => 'Mira quién canta y repítelo';
  @override
  String get bg => 'bg_karaoke';
  @override
  double get dur => 2.4 + seq.length * 1.25;

  static const cols = ['red', 'blue', 'yellow', 'green'];
  final seq = <int>[];
  int input = 0;
  final singT = [-9.0, -9.0, -9.0, -9.0];
  int shown = 0;
  static const step = .6;
  bool get listening => t < seq.length * step + .3;
  Rect slot(int i) => Rect.fromLTWH(sl + 8 + i * (S.width - 16) / 4, by(.46), (S.width - 16) / 4, by(.76) - by(.46));

  @override
  void init(int l) {
    final n = 3 + math.min(l, 3) ~/ 2 + (l >= 4 ? 1 : 0);
    for (var k = 0; k < n; k++) {
      seq.add(rng.nextInt(4));
    }
  }

  @override
  void update(double dt) {
    // demostración
    if (shown < seq.length && t >= .3 + shown * step) {
      final s = seq[shown];
      singT[s] = vt;
      Sfx.play('note$s');
      shown++;
    }
    if (listening || res != 0 || !p.pressed) return;
    for (var i = 0; i < 4; i++) {
      if (slot(i).contains(Offset(p.x, p.y))) {
        singT[i] = vt;
        Sfx.play('note$i');
        if (seq[input] == i) {
          input++;
          if (input >= seq.length) {
            win();
            g.fx.burst(cx, by(.5), Pal.gold, 24);
          }
        } else {
          lose('¡Desafinaste!');
        }
        break;
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var i = 0; i < 4; i++) {
      final r = slot(i);
      final singing = vt - singT[i] < (listening ? step * .8 : .35);
      final x = r.center.dx, y = by(.74);
      Gfx.shadow(c, x, y, 80);
      Gfx.sprite(c, singing ? 'singer_${cols[i]}_sing' : 'singer_${cols[i]}', x, y + (singing ? -6 : 0), 108,
          ay: 1, sy: 1 + boil(vt, i.toDouble()) * .015);
      if (singing) Gfx.note(c, x + 26, y - 118 - (vt - singT[i]) * 40, 30, Pal.gold);
    }
    final msg = listening ? 'ESCUCHA…' : (res == 0 ? '¡TU TURNO!' : '');
    if (msg.isNotEmpty) Gfx.text(c, msg, cx, st + 40, 30, color: listening ? Pal.teal : Pal.gold);
    for (var k = 0; k < seq.length; k++) {
      Gfx.clayBall(c, cx - (seq.length - 1) * 14 + k * 28, st + 78, 9, k < input ? Pal.lime : const Color(0xFF4A3B60));
    }
  }
}

// ───────────────────────── 17. ¿CUÁNTOS OVNIS? (contar) ─────────────────────────
class CountUfos extends Channel {
  CountUfos(super.g);
  @override
  String get name => 'ALERTA OVNI';
  @override
  String get sub => 'Cuenta los platillos antes de que se vayan';
  @override
  String get ins => '¡CUENTA!';
  @override
  String get hint => 'Luego toca el número correcto';
  @override
  String get bg => 'bg_night';
  @override
  double get dur => 6;

  final ufos = <Offset>[];
  final opts = <int>[];
  int picked = -1;
  static const showFor = 2.2;

  @override
  void init(int l) {
    final n = rndi(3, 6) + math.min(l, 3).toInt();
    var tries = 0;
    while (ufos.length < n && tries++ < 400) {
      final o = Offset(rnd(sl + 50, sr - 50), rnd(st + 50, by(.7)));
      if (ufos.every((u) => (u - o).distance > 80)) ufos.add(o);
    }
    final c = ufos.length;
    final set = <int>{c};
    while (set.length < 3) {
      final int v = c + pick<int>(const [-2, -1, 1, 2]);
      if (v > 0) set.add(v);
    }
    opts.addAll(set.toList()..shuffle(rng));
  }

  Rect optRect(int i) {
    final w = (S.width - 40) / 3;
    return Rect.fromLTWH(sl + 12 + i * (w + 8), sb - 22 - w * kButtonAspect, w, w * kButtonAspect);
  }

  @override
  void update(double dt) {
    if (t < showFor || res != 0 || !p.pressed) return;
    for (var i = 0; i < 3; i++) {
      if (optRect(i).contains(Offset(p.x, p.y))) {
        picked = i;
        if (opts[i] == ufos.length) {
          win();
          g.fx.burst(optRect(i).center.dx, optRect(i).center.dy, Pal.gold, 20);
        } else {
          lose('Eran ${ufos.length}');
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var i = 0; i < ufos.length; i++) {
      final u = ufos[i];
      final appear = clamp01((t - i * .08) * 5);
      final leave = t > showFor ? (t - showFor) * (t - showFor) * 1400 : 0.0;
      if (appear <= 0) continue;
      Gfx.sprite(c, 'ufo', u.dx + math.sin(vt * 2 + i) * 6, u.dy - leave + math.sin(vt * 3 + i) * 5, 44 * appear,
          rot: math.sin(vt * 2.5 + i) * .08);
    }
    if (t >= showFor) {
      Gfx.text(c, '¿CUÁNTOS OVNIS?', cx, cy - 10, 34, color: Pal.gold, fitW: S.width - 30);
      final lbl = ['btn_teal', 'btn_pink', 'btn_gold'];
      for (var i = 0; i < 3; i++) {
        Gfx.button(c, lbl[i], '${opts[i]}', optRect(i), scale: picked == i ? 1.08 : 1, size: 50);
      }
    }
  }
}

// ───────────────────────── 18. TARTA DE PISOS (apilar) ─────────────────────────
class CakeStack extends Channel {
  CakeStack(super.g);
  @override
  String get name => 'PASTELERÍA DE PISOS';
  @override
  String get sub => 'Apila los bizcochos sin que se caigan';
  @override
  String get ins => '¡APILA!';
  @override
  String get hint => 'Toca para soltar el piso encima';
  @override
  String get bg => 'bg_bakery';
  @override
  double get dur => 5.5;

  final stack = <double>[];
  int need = 3;
  double mx = 0, dir = 1, spd = 0, dropT = -1, dropFrom = 0;
  double? fallX;
  double fallT = 0;
  final landAt = <double>[];
  String rate = '';
  double rateAt = -9;
  static const w = 150.0;
  double get lh => w / Gfx.aspect('cake');
  // el primer piso apoya justo en la superficie del soporte (no se hunde en él)
  double get plateTop => by(.62) - 40 - lh * .22;
  double levelY(int n) => plateTop - n * lh * .78;

  @override
  void init(int l) {
    need = 3 + (l >= 3 ? 1 : 0);
    spd = 230 + l * 40;
    mx = sl + 80;
  }

  @override
  void update(double dt) {
    if (fallX != null) fallT += dt;
    if (res != 0) return;
    if (dropT >= 0) {
      dropT += dt;
      if (dropT >= .16) {
        dropT = -1;
        final topX = stack.isEmpty ? cx : stack.last;
        if ((mx - topX).abs() > w * .5) {
          fallX = mx;
          fallT = 0;
          lose('¡Se cayó la tarta!');
          Sfx.play('splat');
        } else {
          final off = (mx - topX).abs();
          // encaja un poco hacia el piso de abajo para que se vea bien asentado
          final x = off < w * .12 ? topX : mx;
          stack.add(x);
          landAt.add(t);
          rate = off < w * .12 ? '¡PERFECTO!' : off < w * .3 ? '¡BIEN!' : '¡POR POCO!';
          rateAt = t;
          Sfx.play('squish');
          g.fx.burst(mx, levelY(stack.length), const Color(0xFFFFF4E6), 10, size: 5);
          if (stack.length >= need) {
            win();
            Sfx.play('bonus');
          }
        }
        mx = rng.nextBool() ? sl + 70 : sr - 70;
      }
      return;
    }
    mx += dir * spd * dt;
    if (mx < sl + 70 || mx > sr - 70) {
      dir = -dir;
      mx = mx.clamp(sl + 70, sr - 70);
    }
    if (tap) {
      dropT = 0;
      dropFrom = levelY(stack.length + 1) - 70;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, bx(.84), by(.97), 120);
    Gfx.anim(c, 'baker', vt, bx(.84), by(.97), 170, ay: 1);
    Gfx.shadow(c, cx, by(.62) + 16, 170, alpha: .35);
    Gfx.sprite(c, 'cakeplate', cx, by(.62) + 20, 70, ay: 1);
    for (var i = 0; i < stack.length; i++) {
      // aplastón al caer: se ve que el piso se asienta sobre el de abajo
      final lt = t - landAt[i];
      final sq = lt < .35 ? math.sin(lt / .35 * math.pi) * .16 * (1 - lt / .35) : 0.0;
      final baseY = levelY(i + 1) + lh - 5;
      Gfx.shadow(c, stack[i], baseY, w * .95, alpha: .45, ratio: .16);
      Gfx.sprite(c, 'cake', stack[i], levelY(i + 1) + lh, lh,
          ay: 1, sy: 1 - sq + boil(vt, i.toDouble()) * .01, sx: 1 + sq * .8);
    }
    if (res == 1) Gfx.clayBall(c, stack.last, levelY(stack.length) + 6, 12, const Color(0xFFD0203A));
    if (fallX != null) {
      Gfx.sprite(c, 'cake', fallX! + fallT * 120 * (fallX! > cx ? 1 : -1), levelY(stack.length + 1) + fallT * fallT * 1400,
          lh, rot: fallT * 5 * (fallX! > cx ? 1 : -1));
    } else if (res == 0) {
      final y = dropT >= 0 ? lerp(dropFrom, levelY(stack.length + 1) + lh * .5, dropT / .16) : levelY(stack.length + 1) - 70;
      Gfx.sprite(c, 'cake', mx, y, lh);
    }
    if (t - rateAt < .9 && stack.isNotEmpty) {
      final k = t - rateAt;
      Gfx.text(c, rate, stack.last, levelY(stack.length) - 30 - k * 40, 30,
          color: rate == '¡PERFECTO!' ? Pal.lime : Pal.gold, scale: 1 + math.max(0.0, .15 - k) * 3);
    }
    Gfx.text(c, '${stack.length}/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 19. GLOBO DE CHICLE (mantener y soltar) ─────────────────────────
class BubbleGum extends Channel {
  BubbleGum(super.g);
  @override
  String get name => 'CHICLE DE MARTE';
  @override
  String get sub => 'Hincha el globo hasta el círculo, ¡sin explotarlo!';
  @override
  String get ins => '¡SOPLA!';
  @override
  String get hint => 'Mantén pulsado y suelta a tiempo';
  @override
  String get bg => 'bg_bedroom';
  @override
  bool get survive => false;

  double r = 0, target = 0, grow = 0;
  bool blowing = false, popped = false;
  static const kidH = 300.0;
  double get kidW => kidH * Gfx.aspect('kid');
  Offset get mouth => Offset(cx - kidW / 2 + kidW * .51, sb + 16 - kidH + kidH * .565);
  static const tol = 12.0;

  @override
  void init(int l) {
    target = rnd(70, 92);
    grow = 70 + l * 12;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    blowing = p.down && pointerIn;
    if (blowing) {
      r += grow * dt;
      Sfx.play('shake', volume: .2, minGapMs: 160);
      if (r > target + tol) {
        popped = true;
        lose('¡Te explotó en la cara!');
        g.fx.burst(mouth.dx, mouth.dy, const Color(0xFFFF8AC0), 30, size: 9);
        g.fx.shake(8);
        Sfx.play('splat');
      }
    } else if (r > 0) {
      if ((r - target).abs() <= tol) {
        win();
        Sfx.play('pop');
        g.fx.burst(mouth.dx, mouth.dy - r, Pal.gold, 16);
      } else {
        r = math.max(0, r - 160 * dt);
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.sprite(c, popped ? 'kid_gum' : 'kid', cx, sb + 16, kidH, ay: 1, sy: 1 + (blowing ? .02 : 0) + boil(vt) * .008);
    // anillo objetivo
    if (!popped) {
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = tol * 2
        ..color = const Color(0x5553D8C3);
      c.drawCircle(mouth, target, ring);
      c.drawCircle(
          mouth,
          target,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Pal.teal);
    }
    if (r > 2 && !popped) {
      final lift = res == 1 ? since * since * 400 : 0.0;
      Gfx.sprite(c, 'bubble', mouth.dx, mouth.dy - lift, r * 2 * 1.03, alpha: .92);
    }
  }
}

// ───────────────────────── 20. ¿CUÁL ES EL RARO? (encontrar) ─────────────────────────
class OddClone extends Channel {
  OddClone(super.g);
  @override
  String get name => 'FÁBRICA DE CLONES';
  @override
  String get sub => 'Uno de los clones es diferente';
  @override
  String get ins => '¡BUSCA!';
  @override
  String get hint => 'Toca el clon distinto';
  @override
  String get bg => 'bg_lab';

  late String base, odd;
  int cols = 3, rows = 3, oddI = 0, picked = -1;
  final seeds = <double>[];

  @override
  void init(int l) {
    final a = rng.nextBool();
    base = a ? 'cloneA' : 'cloneB';
    odd = a ? 'cloneA_odd' : 'cloneB_odd';
    if (l >= 2) cols = 4;
    if (l >= 4) rows = 4;
    oddI = rng.nextInt(cols * rows);
    for (var i = 0; i < cols * rows; i++) {
      seeds.add(rnd(0, 100));
    }
  }

  Offset cell(int i) {
    final w = (S.width - 20) / cols, top = st + 30, h = (by(.93) - top) / rows;
    return Offset(sl + 10 + w * (i % cols + .5), top + h * (i ~/ cols + 1));
  }

  double get ch => math.min((S.width - 20) / cols, (by(.93) - st - 30) / rows) * .95;

  @override
  void update(double dt) {
    if (res != 0 || !p.pressed) return;
    for (var i = 0; i < cols * rows; i++) {
      final o = cell(i);
      if (Rect.fromLTRB(o.dx - ch * .38, o.dy - ch, o.dx + ch * .38, o.dy).contains(Offset(p.x, p.y))) {
        picked = i;
        if (i == oddI) {
          win();
          g.fx.burst(o.dx, o.dy - ch / 2, Pal.gold, 22);
        } else {
          lose('¡Ese era un clon!');
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (var i = 0; i < cols * rows; i++) {
      final o = cell(i);
      final hop = res == 1 && i != oddI ? -(math.sin(vt * 16 + i).abs()) * 8 : 0.0;
      Gfx.shadow(c, o.dx, o.dy, ch * .55, alpha: .25);
      Gfx.sprite(c, i == oddI ? odd : base, o.dx, o.dy + hop, ch,
          ay: 1, rot: boil(vt, seeds[i]) * .04, sy: 1 + boil(vt, seeds[i] + 7) * .02);
      if (picked == i && res == -1) Gfx.mark(c, false, o.dx, o.dy - ch / 2, 70);
    }
  }
}

// ───────────────────────── 21. TOPOS CON GAFAS (golpear) ─────────────────────────
class _Hole {
  final Offset o;
  double up = 0, t = 0;
  int state = 0; // 0 abajo, 1 subiendo/arriba, 2 bajando, 3 golpeado
  _Hole(this.o);
}

class Moles extends Channel {
  Moles(super.g);
  @override
  String get name => 'TOPOS CON GAFAS';
  @override
  String get sub => 'Dales un toque antes de que se escondan';
  @override
  String get ins => '¡TOCA TOPOS!';
  @override
  String get hint => 'Toca los topos que asoman';
  @override
  String get bg => 'bg_garden';

  final holes = <_Hole>[];
  int hits = 0, need = 4;
  double spawn = .2, stay = .8;

  @override
  void init(int l) {
    for (final fy in [.5, .76]) {
      for (final fx in [.2, .5, .8]) {
        holes.add(_Hole(Offset(bx(fx), by(fy))));
      }
    }
    need = 4 + l ~/ 2;
    stay = .85 / (1 + l * .15);
  }

  @override
  void update(double dt) {
    if ((spawn -= dt) <= 0 && res == 0) {
      spawn = stay * .55;
      final free = holes.where((h) => h.state == 0).toList();
      if (free.isNotEmpty) {
        pick(free)
          ..state = 1
          ..t = 0;
      }
    }
    for (final h in holes) {
      h.t += dt;
      switch (h.state) {
        case 1:
          h.up = math.min(1, h.up + dt * 7);
          if (h.t > stay) {
            h.state = 2;
          }
        case 2:
          h.up = math.max(0, h.up - dt * 6);
          if (h.up == 0) h.state = 0;
        case 3:
          if (h.t > .4) h.state = 2;
        default:
      }
    }
    if (tap && res == 0) {
      for (final h in holes) {
        if (h.state == 1 && h.up > .4 && Rect.fromCenter(center: h.o.translate(0, -48), width: 110, height: 115).contains(Offset(p.x, p.y))) {
          h.state = 3;
          h.t = 0;
          hits++;
          g.fx.burst(h.o.dx, h.o.dy - 60, Pal.gold, 12);
          g.fx.shake(4, .1);
          Sfx.play('bosshit', volume: .7);
          Sfx.haptic();
          if (hits >= need) win();
          break;
        }
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // Capas: agujero entero; el topo recortado por la boca (arriba libre, abajo la elipse oscura);
    // delante, solo el borde de tierra delantero (sin nada oscuro que tape al topo).
    const hw = 120.0;
    final hh = hw / Gfx.aspect('hole');
    for (final h in holes) {
      Gfx.sprite(c, 'hole', h.o.dx, h.o.dy, hh);
      if (h.up > 0) {
        final x0 = h.o.dx - hw / 2, y0 = h.o.dy - hh / 2;
        final mouth = Rect.fromLTRB(x0 + hw * .238, y0 + hh * .19, x0 + hw * .776, y0 + hh * .62);
        final clip = Path()
          ..addRect(Rect.fromLTRB(h.o.dx - 90, h.o.dy - 220, h.o.dx + 90, mouth.center.dy))
          ..addOval(mouth);
        c.save();
        c.clipPath(clip);
        final bottom = mouth.bottom + 96 - h.up * 90;
        Gfx.sprite(c, h.state == 3 ? 'mole_hit' : 'mole', h.o.dx + 2, bottom, 92,
            ay: 1, sy: 1 + (h.state == 3 ? -.06 : boil(vt, h.o.dx) * .015));
        c.restore();
        Gfx.sprite(c, 'hole_front', h.o.dx, h.o.dy, hh);
      }
    }
    Gfx.text(c, '$hits/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 22. SUSHI VOLADOR (cortar) ─────────────────────────
class _Flyer {
  double x, y, vx, vy, rot;
  final String spr;
  bool cut = false;
  double cutT = 0;
  _Flyer(this.x, this.y, this.vx, this.vy, this.spr) : rot = rnd(0, tau);
}

class Sushi extends Channel {
  Sushi(super.g);
  @override
  String get name => 'SUSHI VOLADOR';
  @override
  String get sub => 'Corta el sushi al vuelo, ¡no el chile!';
  @override
  String get ins => '¡CORTA!';
  @override
  String get hint => 'Desliza el dedo por encima';
  @override
  String get bg => 'bg_sushi';

  final fl = <_Flyer>[];
  final trail = <Offset>[];
  final queue = <String>[];
  double cd = .1;
  int cut = 0;
  static const need = 3;

  @override
  void init(int l) {
    queue.addAll(['nigiri', 'maki', 'nigiri', 'maki', 'nigiri', 'chili']);
    if (l >= 2) queue.add('chili');
    queue.shuffle(rng);
    // el primero nunca es el chile
    if (queue.first == 'chili') queue.add(queue.removeAt(0));
  }

  @override
  void update(double dt) {
    if ((cd -= dt) <= 0 && queue.isNotEmpty) {
      cd = .5;
      final x = rnd(sl + 60, sr - 60);
      fl.add(_Flyer(x, sb + 40, (cx - x) * rnd(.4, .9), -rnd(650, 760), queue.removeAt(0)));
    }
    for (final f in fl) {
      f.vy += 700 * dt;
      f.x += f.vx * dt;
      f.y += f.vy * dt;
      f.rot += dt * 3;
      if (f.cut) f.cutT += dt;
    }
    fl.removeWhere((f) => f.y > sb + 120 && f.vy > 0);
    if (p.down) {
      trail.add(Offset(p.x, p.y));
      if (trail.length > 8) trail.removeAt(0);
    } else {
      trail.clear();
    }
    if (res != 0 || trail.length < 2) return;
    final a = trail[trail.length - 2], b = trail.last;
    if ((b - a).distance < 6) return;
    for (final f in fl) {
      if (f.cut) continue;
      if (_segDist(Offset(f.x, f.y), a, b) < 34) {
        f.cut = true;
        if (f.spr == 'chili') {
          lose('¡Picante!');
          g.fx.burst(f.x, f.y, Pal.tomato, 30, speed: 500);
          g.fx.shake(10);
          Sfx.play('boom');
        } else {
          cut++;
          g.fx.burst(f.x, f.y, const Color(0xFFFFF4E6), 12, size: 5);
          Sfx.play('chop');
          if (cut >= need) win();
        }
      }
    }
  }

  static double _segDist(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / (ab.distanceSquared)).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    for (final f in fl) {
      const h = 64.0;
      if (!f.cut) {
        Gfx.sprite(c, f.spr, f.x, f.y, f.spr == 'chili' ? 90 : h, rot: f.rot);
        continue;
      }
      if (f.spr == 'chili') continue;
      final w = h * Gfx.aspect(f.spr);
      for (final side in [-1, 1]) {
        c.save();
        c.translate(f.x + side * f.cutT * 90, f.y);
        c.rotate(f.rot + side * f.cutT * 3);
        c.clipRect(side < 0 ? Rect.fromLTWH(-w, -h, w, h * 2) : Rect.fromLTWH(0, -h, w, h * 2));
        Gfx.sprite(c, f.spr, 0, 0, h);
        c.restore();
      }
    }
    if (trail.length > 1) {
      for (var i = 1; i < trail.length; i++) {
        c.drawLine(
            trail[i - 1],
            trail[i],
            Paint()
              ..strokeWidth = 3 + i * 1.2
              ..strokeCap = StrokeCap.round
              ..color = Color.fromRGBO(255, 255, 255, i / trail.length * .8));
      }
    }
    Gfx.text(c, '$cut/$need', sr - 24, st + 34, 30, align: 1, color: Pal.gold);
  }
}

// ───────────────────────── 23. EL GRAN EQUILIBRISTA (equilibrio) ─────────────────────────
class Balance extends Channel {
  Balance(super.g);
  @override
  String get name => 'EL GRAN EQUILIBRISTA';
  @override
  String get sub => 'Que no se caiga del monociclo';
  @override
  String get ins => '¡EQUILIBRA!';
  @override
  String get hint => 'Mueve la rueda debajo de él';
  @override
  String get bg => 'bg_circus';
  @override
  bool get survive => true;

  double x = 0, vx = 0, th = 0, w = 0, gust = 0;
  double gain = 5;

  @override
  void init(int l) {
    x = cx;
    th = (rng.nextBool() ? 1 : -1) * .03;
    gain = 1.8 + l * .25;
  }

  @override
  void update(double dt) {
    final tx = p.down && pointerIn ? p.x : x;
    final nx = lerp(x, tx.clamp(sl + 50, sr - 50), 1 - math.exp(-dt * 10));
    final nvx = (nx - x) / math.max(dt, 1e-4);
    final ax = (nvx - vx) / math.max(dt, 1e-4);
    x = nx;
    vx = nvx;
    if (res == -1) {
      w += math.sin(th).sign * 8 * dt;
      th += w * dt;
      return;
    }
    if ((gust -= dt) <= 0) {
      gust = rnd(.8, 1.4);
      w += rnd(-.12, .12);
    }
    // péndulo invertido: la gravedad lo tumba y mover la base lo endereza
    final alpha = gain * math.sin(th) - (ax / 200).clamp(-10, 10) * math.cos(th);
    w += alpha * dt;
    w *= math.pow(.35, dt).toDouble();
    th += w * dt;
    if (th.abs() > 1.05) {
      lose('¡Al suelo!');
      Sfx.play('boing');
      g.fx.shake(8);
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    final baseY = by(.74);
    Gfx.shadow(c, x, baseY, 90);
    c.save();
    c.translate(x, baseY);
    c.rotate(th.clamp(-1.6, 1.6));
    Gfx.anim(c, 'acrobat', vt, 0, 0, 300, ay: 1);
    c.restore();
    // indicador de inclinación
    final r = Rect.fromLTWH(cx - 110, st + 22, 220, 14);
    c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(7)), Paint()..color = const Color(0x88120D1A));
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: r.center, width: 60, height: 14), const Radius.circular(7)),
        Paint()..color = const Color(0x8853D8C3));
    Gfx.clayBall(c, r.center.dx + (th / 1.05).clamp(-1, 1) * 110, r.center.dy, 10, th.abs() > .65 ? Pal.pink : Pal.gold);
  }
}

// ───────────────────────── 24. APARCA EL PLATILLO (pilotar) ─────────────────────────
class _Rock {
  Offset o;
  final double r, rot;
  _Rock(this.o, this.r) : rot = rnd(0, tau);
}

class UfoParking extends Channel {
  UfoParking(super.g);
  @override
  String get name => 'APARCA EL PLATILLO';
  @override
  String get sub => 'Llega a la plataforma sin chocar';
  @override
  String get ins => '¡PILOTA!';
  @override
  String get hint => 'Arrastra el platillo entre los asteroides';
  @override
  String get bg => 'bg_space';
  @override
  double get dur => 5;

  Offset u = Offset.zero;
  final rocks = <_Rock>[];
  double padX = 0, drift = 0;
  bool grab = false;

  @override
  void init(int l) {
    u = Offset(cx, st + 60);
    padX = rnd(sl + 80, sr - 80);
    drift = l >= 2 ? 40.0 + l * 8 : 0;
    for (final y in [st + 170, st + 300]) {
      final gapW = 150 - math.min(l, 4) * 8.0;
      final gap = rnd(sl + gapW / 2 + 10, sr - gapW / 2 - 10);
      for (var x = sl + 10; x < sr + 20; x += 54) {
        if ((x - gap).abs() > gapW / 2 + 20) rocks.add(_Rock(Offset(x, y + rnd(-10, 10)), rnd(24, 30)));
      }
    }
  }

  @override
  void update(double dt) {
    for (var i = 0; i < rocks.length; i++) {
      rocks[i].o = rocks[i].o.translate(math.sin(vt * 1.5 + (i < rocks.length / 2 ? 0 : 2)) * drift * dt, 0);
    }
    if (res != 0) return;
    if (p.pressed) grab = true;
    if (!p.down) grab = false;
    if (grab) {
      u = u.translate(p.dx, p.dy);
      u = Offset(u.dx.clamp(sl + 30, sr - 30), u.dy.clamp(st + 30, sb - 30));
    }
    for (final r in rocks) {
      if ((r.o - u).distance < r.r + 26) {
        lose('¡Choque espacial!');
        g.fx.burst(u.dx, u.dy, Pal.gold, 30, speed: 450);
        g.fx.shake(10);
        Sfx.play('boom');
        return;
      }
    }
    if ((u.dx - padX).abs() < 40 && (u.dy - (sb - 70)).abs() < 26) {
      win();
      u = Offset(padX, sb - 70);
      Sfx.play('bonus');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.sprite(c, 'pad', padX, sb - 18, 60, ay: 1);
    for (final r in rocks) {
      Gfx.sprite(c, 'asteroid', r.o.dx, r.o.dy, r.r * 2.3, rot: r.rot + vt * .4);
    }
    if (res != -1) {
      // haz de luz hacia la plataforma
      Gfx.sprite(c, 'ufo', u.dx, u.dy, 52, rot: grab ? (p.dx * .01).clamp(-.3, .3) : math.sin(vt * 3) * .05);
    }
  }
}

// ───────────────────────── 25. NOCHE DE DISCO (ritmo) ─────────────────────────
class Disco extends Channel {
  Disco(super.g);
  @override
  String get name => 'NOCHE DE DISCO';
  @override
  String get sub => 'Toca justo cuando el aro cierra';
  @override
  String get ins => '¡AL RITMO!';
  @override
  String get hint => 'Toca cuando el aro llegue al centro';
  @override
  String get bg => 'bg_disco';
  @override
  double get dur => beats.last + .6;

  final beats = <double>[];
  int next = 0;
  double hitFx = -9;
  static const win_ = .15;
  Offset get target => Offset(cx, st + 120);

  @override
  void init(int l) {
    final gap = math.max(.5, .75 - l * .05);
    for (var i = 0; i < 4; i++) {
      beats.add(1.0 + i * gap);
    }
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (next < beats.length && t > beats[next] + win_) {
      lose('¡Te perdiste el paso!');
      return;
    }
    if (tap) {
      if (next < beats.length && (t - beats[next]).abs() <= win_) {
        next++;
        hitFx = vt;
        Sfx.play('note${next % 4}');
        g.fx.burst(target.dx, target.dy, pick([Pal.pink, Pal.teal, Pal.gold, Pal.lime]), 14);
        if (next >= beats.length) win();
      } else {
        lose('¡Fuera de ritmo!');
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, cx, by(.9), 130);
    Gfx.anim(c, 'dancer', vt, cx, by(.9), 240, ay: 1, sx: 1 + math.max(0.0, .15 - (vt - hitFx)) * .8);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    c.drawCircle(target, 38, ringPaint..color = const Color(0xCCFFFFFF));
    for (var i = next; i < beats.length; i++) {
      final dtb = beats[i] - t;
      if (dtb > 1.2) continue;
      final r = 38 + dtb * 150;
      c.drawCircle(target, math.max(4, r), ringPaint..color = [Pal.pink, Pal.teal, Pal.gold, Pal.lime][i % 4]);
    }
    final fl = clamp01(1 - (vt - hitFx) * 4);
    if (fl > 0) Gfx.clayBall(c, target.dx, target.dy, 30 * fl, Pal.gold);
  }
}

// ───────────────────────── 26. EL PORTERO (clasificar) ─────────────────────────
class Doorman extends Channel {
  Doorman(super.g);
  @override
  String get name => 'CLUB INTERGALÁCTICO';
  @override
  String get sub => 'Tú decides quién entra';
  @override
  String get ins => '¡DECIDE!';
  @override
  String get hint => 'Desliza a la derecha para dejarle entrar';
  @override
  String get bg => 'bg_club';
  @override
  double get dur => 6;

  static const hats = ['guest_top', 'guest_cowboy'];
  static const noHats = ['guest_bald', 'guest_curly'];
  bool wantHat = true;
  final queue = <String>[];
  int idx = 0, decided = 0; // decided: 0 nada, 1 dentro, -1 fuera
  double moveT = 0;

  @override
  void init(int l) {
    wantHat = rng.nextBool();
    final n = 4 + (l >= 3 ? 1 : 0);
    for (var i = 0; i < n; i++) {
      queue.add(rng.nextBool() ? pick(hats) : pick(noHats));
    }
  }

  bool ok(String s) => hats.contains(s) == wantHat;

  @override
  void update(double dt) {
    moveT += dt;
    if (decided != 0 && moveT > .35) {
      decided = 0;
      idx++;
      moveT = 0;
      if (idx >= queue.length) win();
    }
    if (res != 0 || decided != 0 || moveT < .25) return;
    final s = swipe(min: 50);
    if (s == null || s.dx.abs() < s.dy.abs()) return;
    final letIn = s.dx > 0;
    if (letIn == ok(queue[idx])) {
      decided = letIn ? 1 : -1;
      moveT = 0;
      Sfx.play(letIn ? 'pop' : 'boing', volume: .7);
    } else {
      lose(letIn ? '¡Ese no podía entrar!' : '¡Ese sí podía entrar!');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    // cartel con la norma
    // cartel grande con la norma: es lo más importante de la pantalla
    final sw = math.sin(vt * 2.2) * .025;
    // baja colgando justo cuando desaparece el «¡DECIDE!» del principio
    final drop = 1 - clamp01((t - .7) / .3);
    final sign = Rect.fromLTWH(sl + 14, st + 12 - drop * drop * 150, S.width - 28, 104);
    c.save();
    c.translate(sign.center.dx, sign.top);
    c.rotate(sw);
    c.translate(-sign.center.dx, -sign.top);
    Gfx.clayPanel(c, sign, const Color(0xFFF7F1E3), radius: 18);
    Gfx.text(c, 'NORMA DEL PORTERO', sign.center.dx, sign.top + 26, 18, color: const Color(0xFF6A3FA0), fitW: sign.width - 40);
    final pulse = 1 + math.sin(vt * 6) * .04;
    Gfx.text(c, wantHat ? 'SOLO CON SOMBRERO' : 'PROHIBIDO EL SOMBRERO', sign.center.dx, sign.top + 66, 34,
        color: wantHat ? const Color(0xFF1E9E54) : const Color(0xFFD02050),
        fitW: sign.width - 36, fitH: 44, scale: pulse);
    c.restore();
    final floorY = by(.78);
    // cola al fondo
    for (var i = queue.length - 1; i > idx; i--) {
      final k = i - idx;
      Gfx.shadow(c, sl + 40 - k * 6 + (k * 22.0), floorY - k * 6, 60 - k * 5, alpha: .3);
      Gfx.sprite(c, queue[i], sl + 40 - k * 6 + (k * 22.0), floorY - k * 6, 92 - k * 8, ay: 1, alpha: .9);
    }
    if (idx < queue.length) {
      var x = bx(.4), y = floorY, a = 1.0, s = 1.0;
      final e = clamp01(moveT / .35);
      if (idx > 0 && decided == 0) x = lerp(sl + 60, x, clamp01(moveT / .25));
      if (decided == 1) {
        x = lerp(x, bx(.63), e);
        y = lerp(y, by(.56), e);
        s = 1 - e * .4;
        a = 1 - e;
      } else if (decided == -1) {
        x = lerp(x, sl - 80, e);
      }
      Gfx.shadow(c, x, y, 90 * s);
      Gfx.sprite(c, queue[idx], x, y - (decided == 0 ? (math.sin(vt * 10).abs() * 4) : 0), 150 * s, ay: 1, alpha: a);
    }
    Gfx.sprite(c, 'arrow', sl + 34, sb - 28, 26, rot: math.pi);
    Gfx.text(c, 'FUERA', sl + 56, sb - 28, 20, color: Pal.pink, align: 0);
    Gfx.text(c, 'DENTRO', sr - 56, sb - 28, 20, color: Pal.lime, align: 1);
    Gfx.sprite(c, 'arrow', sr - 34, sb - 28, 26);
  }
}

// ───────────────────────── 27. CAJA FUERTE (girar) ─────────────────────────
class Vault extends Channel {
  Vault(super.g);
  @override
  String get name => 'LA CAJA FUERTE DE LA ABUELA';
  @override
  String get sub => 'Gira la llave hasta cada marca iluminada';
  @override
  String get ins => '¡GIRA!';
  @override
  String get hint => 'Gira el dedo alrededor de la llave';
  @override
  String get bg => 'bg_vault';
  @override
  double get dur => 5.5;

  double ang = 0, hold = 0;
  final targets = <double>[];
  int k = 0;
  Offset get center => Offset(bx(.5), by(.43));

  @override
  void init(int l) {
    var a = 0.0;
    final n = l >= 2 ? 3 : 2;
    for (var i = 0; i < n; i++) {
      a += (rng.nextBool() ? 1 : -1) * rnd(1.2, 2.6);
      targets.add(a);
    }
  }

  static double _wrap(double a) {
    while (a > math.pi) {
      a -= tau;
    }
    while (a < -math.pi) {
      a += tau;
    }
    return a;
  }

  @override
  void update(double dt) {
    if (res != 0) return;
    if (p.down && (Offset(p.x, p.y) - center).distance > 20) {
      final pa = math.atan2(p.y - p.dy - center.dy, p.x - p.dx - center.dx);
      final na = math.atan2(p.y - center.dy, p.x - center.dx);
      final d = _wrap(na - pa);
      ang += d;
      if (d.abs() > .03) Sfx.play('click', volume: .4, minGapMs: 70);
    }
    if (_wrap(ang - targets[k]).abs() < .14) {
      hold += dt;
      if (hold > .3) {
        hold = 0;
        k++;
        Sfx.play('ratchet');
        Sfx.haptic();
        g.fx.burst(center.dx, center.dy, Pal.gold, 12);
        if (k >= targets.length) {
          win();
          Sfx.play('bonus');
        }
      }
    } else {
      hold = 0;
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    const rad = 96.0;
    // marcas alrededor del plato
    for (var i = 0; i < 24; i++) {
      final a = i * tau / 24;
      c.drawLine(center + Offset(math.cos(a), math.sin(a)) * (rad - 8), center + Offset(math.cos(a), math.sin(a)) * rad,
          Paint()
            ..strokeWidth = 3
            ..color = const Color(0x99402A10));
    }
    if (k < targets.length) {
      final a = targets[k] - math.pi / 2;
      final o = center + Offset(math.cos(a), math.sin(a)) * (rad + 14);
      Gfx.clayBall(c, o.dx, o.dy, 13 + math.sin(vt * 8) * 2, hold > 0 ? Pal.lime : Pal.pink);
    }
    // llave: la punta señala el ángulo actual
    final open = res == 1 ? clamp01(since * 2) : 0.0;
    for (final shadowPass in [true, false]) {
      c.save();
      c.translate(center.dx + (shadowPass ? 5 : 0), center.dy + (shadowPass ? 8 : 0));
      c.rotate(ang - math.pi / 2);
      if (shadowPass) {
        Gfx.silhouette(c, 'key', 0, 0, 170 / Gfx.aspect('key'), ax: .12);
      } else {
        Gfx.sprite(c, 'key', 0, 0, 170 / Gfx.aspect('key'), ax: .12);
      }
      c.restore();
    }
    for (var i = 0; i < targets.length; i++) {
      Gfx.clayBall(c, cx - (targets.length - 1) * 16 + i * 32, sb - 30, 10, i < k ? Pal.lime : const Color(0xFF3A3A3A));
    }
    if (open > 0) c.drawRect(S, Paint()..color = Color.fromRGBO(255, 230, 150, open * .5));
  }
}

// ───────────────────────── 28. LAVA AL MONSTRUO (frotar) ─────────────────────────
class _Mud {
  final Offset o;
  final double r, rot;
  double dirt = 1;
  _Mud(this.o, this.r) : rot = rnd(0, tau);
}

class WashMonster extends Channel {
  WashMonster(super.g);
  @override
  String get name => 'BAÑO DE BLUBU';
  @override
  String get sub => 'Frota hasta quitarle todo el barro';
  @override
  String get ins => '¡FROTA!';
  @override
  String get hint => 'Arrastra la esponja sobre el barro';
  @override
  String get bg => 'bg_bathroom';

  final mud = <_Mud>[];
  static const mh = 280.0;
  double get mw => mh * Gfx.aspect('monster');
  double get footY => by(.8);

  @override
  void init(int l) {
    final n = 5 + math.min(l, 4);
    while (mud.length < n) {
      final o = Offset(cx + rnd(-mw * .32, mw * .32), footY - mh * rnd(.45, .82));
      if (mud.every((m) => (m.o - o).distance > 40)) mud.add(_Mud(o, rnd(22, 30)));
    }
  }

  @override
  void update(double dt) {
    if (res != 0 || !p.down) return;
    final moved = math.sqrt(p.dx * p.dx + p.dy * p.dy);
    if (moved < 1) return;
    for (final m in mud) {
      if (m.dirt > 0 && (m.o - Offset(p.x, p.y)).distance < m.r + 26) {
        m.dirt = math.max(0, m.dirt - moved * .012);
        if (rng.nextDouble() < .3) {
          g.fx.blobs.add(Blob(p.x + rnd(-20, 20), p.y + rnd(-10, 10), rnd(-60, 60), rnd(-200, -80), rnd(3, 7), .5,
              const Color(0xFFF4FBFF)));
        }
        Sfx.play('shake', volume: .3, minGapMs: 110);
      }
    }
    if (mud.every((m) => m.dirt <= 0)) {
      win();
      Sfx.play('bonus');
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.sprite(c, res == 1 ? 'monster_clean' : 'monster', cx, footY, mh, ay: 1, sy: 1 + boil(vt) * .01);
    for (final m in mud) {
      if (m.dirt > 0) Gfx.sprite(c, 'mud', m.o.dx, m.o.dy, m.r * 2.2, rot: m.rot, alpha: m.dirt);
    }
    // capa delantera: la espuma y el frente de la bañera (recortados siguiendo las burbujas) tapan a Blubu
    Gfx.cover(c, 'tub_front', ZappingGame.bleed);
    if (p.down && res == 0) Gfx.sprite(c, 'sponge', p.x, p.y, 62, rot: math.sin(vt * 20) * .15);
  }
}

// ───────────────────────── 29. LAZO VAQUERO (rodear) ─────────────────────────
class Lasso extends Channel {
  Lasso(super.g);
  @override
  String get name => 'RODEO MARCIANO';
  @override
  String get sub => 'Atrapa a la vaca alienígena con el lazo';
  @override
  String get ins => '¡ENLAZA!';
  @override
  String get hint => 'Dibuja un círculo alrededor de la vaca';
  @override
  String get bg => 'bg_ranch';

  Offset cow = Offset.zero, v = Offset.zero;
  final path = <Offset>[];
  double spd = 0, fade = 0;
  final loop = <Offset>[];

  @override
  void init(int l) {
    cow = Offset(cx, cy);
    spd = 140 + l * 30;
    final a = rnd(0, tau);
    v = Offset(math.cos(a), math.sin(a)) * spd;
  }

  bool _inside(List<Offset> poly, Offset q) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > q.dy) != (b.dy > q.dy) && q.dx < (b.dx - a.dx) * (q.dy - a.dy) / (b.dy - a.dy) + a.dx) inside = !inside;
    }
    return inside;
  }

  @override
  void update(double dt) {
    fade = math.max(0, fade - dt * 2);
    if (res == 1) return;
    if (rng.nextDouble() < dt * 1.2) {
      final a = math.atan2(v.dy, v.dx) + rnd(-1.2, 1.2);
      v = Offset(math.cos(a), math.sin(a)) * spd;
    }
    cow += v * dt;
    if (cow.dx < sl + 60 || cow.dx > sr - 60) v = Offset(-v.dx, v.dy);
    if (cow.dy < st + 80 || cow.dy > sb - 40) v = Offset(v.dx, -v.dy);
    cow = Offset(cow.dx.clamp(sl + 60, sr - 60), cow.dy.clamp(st + 80, sb - 40));
    if (res != 0) return;
    if (p.pressed) path.clear();
    if (p.down && pointerIn) {
      final q = Offset(p.x, p.y);
      if (path.isEmpty || (path.last - q).distance > 6) path.add(q);
      if (path.length > 220) path.removeAt(0);
      // ¿se ha cerrado el lazo?
      if (path.length > 25) {
        for (var i = 0; i < path.length - 20; i++) {
          if ((path[i] - q).distance < 24) {
            final poly = path.sublist(i);
            if (_inside(poly, cow.translate(0, -30))) {
              loop
                ..clear()
                ..addAll(poly);
              win();
              Sfx.play('bonus');
              g.fx.burst(cow.dx, cow.dy - 30, Pal.gold, 24);
            } else {
              fade = 1;
              loop
                ..clear()
                ..addAll(poly);
              Sfx.play('boing', volume: .5);
            }
            path.clear();
            break;
          }
        }
      }
    }
    if (p.released) path.clear();
  }

  void _rope(Canvas c, List<Offset> pts, double a, {bool close = false}) {
    if (pts.length < 2) return;
    final pa = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final q in pts.skip(1)) {
      pa.lineTo(q.dx, q.dy);
    }
    if (close) pa.close();
    Paint st(double w, Color col) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = col.withValues(alpha: a);
    c.drawPath(pa, st(10, const Color(0xFF5A3A1A)));
    c.drawPath(pa, st(5, const Color(0xFFC89A5A)));
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    Gfx.shadow(c, cow.dx, cow.dy, 110);
    Gfx.anim(c, 'cow', res == 1 ? 0 : vt, cow.dx, cow.dy, 110, ay: .95, flip: v.dx < 0, fps: res == 1 ? 0 : 14);
    _rope(c, path, 1);
    if (res == 1) {
      _rope(c, loop, 1, close: true);
    } else if (fade > 0) {
      _rope(c, loop, fade, close: true);
    }
  }
}

// ───────────────────────── 30. PING-PONG ALIENÍGENA (rebotar) ─────────────────────────
class PingPong extends Channel {
  PingPong(super.g);
  @override
  String get name => 'PING-PONG ALIENÍGENA';
  @override
  String get sub => 'Aguanta el peloteo contra el alien de 4 brazos';
  @override
  String get ins => '¡DEVUELVE!';
  @override
  String get hint => 'Mueve la pala con el dedo';
  @override
  String get bg => 'bg_pingpong';
  @override
  bool get survive => true;

  double px = 0, ox = 0;
  Offset b = Offset.zero, v = Offset.zero;
  double spd = 0, z = 0;
  static const padW = 110.0;
  double get padY => sb - 42;
  double get oppY => st + 70;
  static const serveAt = 1.0;
  bool served = false;

  @override
  void init(int l) {
    px = cx;
    ox = cx;
    spd = 380 + l * 45;
    b = Offset(cx, oppY + 40);
  }

  @override
  void update(double dt) {
    if (p.down && pointerIn) px = lerp(px, p.x, 1 - math.exp(-dt * 18));
    px = px.clamp(sl + padW / 2, sr - padW / 2);
    if (res == -1) return;
    // saque: el alien bota la pelota en la mano y la lanza al decir ¡YA!
    if (!served) {
      ox = lerp(ox, cx, 1 - math.exp(-dt * 4));
      b = Offset(ox + 34, oppY + 20 - (math.sin(t * 9)).abs() * 22);
      if (t < serveAt) return;
      served = true;
      final a = rnd(.3, .6) * (px < cx ? -1 : 1);
      v = Offset(math.sin(a), math.cos(a)) * spd * .85;
      Sfx.play('pop');
    }
    ox = lerp(ox, b.dx, 1 - math.exp(-dt * 4));
    b += v * dt;
    z = math.sin(clamp01((b.dy - oppY) / (padY - oppY)) * math.pi);
    if (b.dx < sl + 14 || b.dx > sr - 14) {
      v = Offset(-v.dx, v.dy);
      b = Offset(b.dx.clamp(sl + 14, sr - 14), b.dy);
    }
    if (v.dy < 0 && b.dy <= oppY + 30) {
      final a = rnd(-.7, .7);
      v = Offset(math.sin(a), math.cos(a)) * spd;
      Sfx.play('click');
    }
    if (v.dy > 0 && b.dy >= padY - 14) {
      if ((b.dx - px).abs() < padW / 2 + 12) {
        final off = (b.dx - px) / (padW / 2);
        final a = off * .8;
        v = Offset(math.sin(a), -math.cos(a)) * spd;
        b = Offset(b.dx, padY - 15);
        Sfx.play('pop', volume: .7);
        Sfx.haptic();
      } else if (b.dy > padY + 20) {
        lose('¡Punto para el alien!');
        Sfx.play('lose');
      }
    }
  }

  @override
  void render(Canvas c) {
    drawBg(c);
    if (res == 1) {
      Gfx.sprite(c, 'opponent_lose', ox, oppY + 40, 110, ay: 1);
    } else {
      Gfx.anim(c, 'opponent', vt, ox, oppY + 40, 110, ay: 1);
    }
    // sombra de la pelota y la pelota (más grande cuanto más alta)
    c.drawOval(Rect.fromCenter(center: b.translate(6, 8), width: 22, height: 10), Paint()..color = const Color(0x55000000));
    Gfx.clayBall(c, b.dx, b.dy - z * 26, 12 + z * 5, const Color(0xFFFFF4E6));
    Gfx.sprite(c, 'paddle', px, padY, padW / Gfx.aspect('paddle'), drop: const Offset(5, 8));
    if (!served) {
      Gfx.text(c, '¡PREPÁRATE!', cx, cy + 10, 40, color: Pal.gold, scale: 1 + math.sin(vt * 8) * .04);
    } else if (t - serveAt < .7) {
      final k = t - serveAt;
      Gfx.text(c, '¡YA!', cx, cy + 10, 80, color: Pal.lime, scale: 1 + math.max(0.0, .25 - k) * 2.4);
    }
  }
}
