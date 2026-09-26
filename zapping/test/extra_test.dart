import 'dart:ui' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:zapping_infinito/channels.dart';
import 'package:zapping_infinito/channels3.dart';
import 'package:zapping_infinito/game.dart';

/// Juega un canal con un "bot": cada frame el bot decide dónde está el dedo.
/// Devuelve el resultado (1 gana, -1 pierde, 0 se acabó el tiempo sin resolver).
int play(Channel Function(ZappingGame) make, void Function(Channel c, Pointer p, int frame) bot,
    {int level = 0, double hz = 60}) {
  final g = ZappingGame();
  final c = make(g)..init(level);
  final dt = 1 / hz;
  var wasDown = false;
  for (var i = 0; i < (c.dur + 1) * hz && c.res == 0; i++) {
    final p = g.ptr;
    p.down = false;
    bot(c, p, i);
    p.pressed = p.down && !wasDown;
    p.released = !p.down && wasDown;
    if (p.pressed) {
      p.sx = p.x;
      p.sy = p.y;
    }
    wasDown = p.down;
    c.t += dt;
    c.vt += dt;
    c.update(dt);
    if (c.t >= c.dur && c.res == 0) {
      lastWhy = 'tiempo';
      return c.survive ? 1 : 0;
    }
  }
  lastWhy = '${c.why} t=${c.t.toStringAsFixed(2)}';
  return c.res;
}

String lastWhy = '';

void touch(Pointer p, double x, double y) {
  p
    ..down = true
    ..x = x
    ..y = y;
}

void main() {
  test('31 inspector: la lupa sobre el ladrón gana', () {
    expect(play(Inspector.new, (c, p, f) {
      final i = c as Inspector;
      final th = i.thiefBody;
      touch(p, th.dx, th.dy + 10);
    }), 1);
    expect(play(Inspector.new, (c, p, f) {}), isNot(1));
  });

  test('32 albóndigas: perseguir albóndigas y huir de botas gana', () {
    for (var s = 0; s < 5; s++) {
      expect(
          play(Meatballs.new, (c, p, f) {
            final m = c as Meatballs;
            final target = m.bestX();
            touch(p, target, m.plateY);
          }),
          1);
    }
  });

  test('33 abuela: saltar a tiempo gana', () {
    for (var s = 0; s < 5; s++) {
      var last = -99;
      expect(
          play(GrannyScooter.new, (c, p, f) {
            final gs = c as GrannyScooter;
            final near = gs.nextObstacleDist();
            if (near < 95 && near > 20 && f - last > 20) {
              touch(p, c.cx, c.cy);
              last = f;
            }
          }),
          1);
    }
    expect(play(GrannyScooter.new, (c, p, f) {}), -1);
  });

  test('34 pollo: mantener cuando cae por debajo del hueco gana', () {
    for (var s = 0; s < 5; s++) {
      expect(
          play(JetChicken.new, (c, p, f) {
            final j = c as JetChicken;
            if (j.y > j.targetY() + 8 || j.vy > 260) touch(p, c.cx, c.cy);
          }),
          1);
    }
    expect(play(JetChicken.new, (c, p, f) {}), -1);
  });

  test('35 trileros: tocar el vaso de la bolita gana y otro pierde', () {
    expect(play(ShellGame.new, (c, p, f) {
      final s = c as ShellGame;
      if (c.t > s.shuffleEnd + .2) {
        final o = s.cupAt(s.ball);
        touch(p, o.dx, o.dy - 40);
      }
    }), 1);
    expect(play(ShellGame.new, (c, p, f) {
      final s = c as ShellGame;
      if (c.t > s.shuffleEnd + .2) {
        final o = s.cupAt((s.ball + 1) % 3);
        touch(p, o.dx, o.dy - 40);
      }
    }), -1);
  });

  test('36 calcetines: recordar las parejas gana', () {
    expect(play(SockPairs.new, (c, p, f) {
      final s = c as SockPairs;
      if (c.t < s.peek + .1 || f % 12 != 0) return;
      final i = s.nextSmartTap();
      if (i >= 0) touch(p, s.card(i).center.dx, s.card(i).center.dy);
    }), 1);
  });

  test('37 muñecas: de mayor a menor gana; al revés pierde', () {
    expect(play(Matryoshka.new, (c, p, f) {
      final m = c as Matryoshka;
      if (f % 10 != 0) return;
      final o = m.dollCenter(m.nextSize);
      touch(p, o.dx, o.dy);
    }), 1);
    expect(play(Matryoshka.new, (c, p, f) {
      final m = c as Matryoshka;
      final o = m.dollCenter(m.sizes.length - 1);
      touch(p, o.dx, o.dy);
    }), -1);
  });

  test('38 salchichas: lanzar solo cuando hay hueco gana', () {
    for (var s = 0; s < 5; s++) {
      var last = -99;
      expect(
          play(SausageThrow.new, (c, p, f) {
            final st = c as SausageThrow;
            if (st.flyY < 0 && st.safeToThrow() && f - last > 6) {
              touch(p, c.cx, c.cy);
              last = f;
            }
          }),
          1);
    }
  });

  test('39 cruce: sin tocar hay atasco; alternando bien se aguanta', () {
    expect(play(Crossing.new, (c, p, f) {}), -1);
    var ok = 0;
    for (var s = 0; s < 5; s++) {
      final r = play(Crossing.new, (c, p, f) {
        final k = c as Crossing;
        if (k.shouldToggle()) touch(p, c.cx, c.cy);
      });
      if (r == 1) ok++;
    }
    expect(ok, greaterThanOrEqualTo(4), reason: lastWhy);
  });

  test('40 ovejas: empujar desde detrás hacia el corral gana', () {
    var ok = 0;
    for (var s = 0; s < 5; s++) {
      final r = play(CloudSheep.new, (c, p, f) {
        final k = c as CloudSheep;
        final o = k.pushPoint();
        if (o != null) touch(p, o.dx, o.dy);
      });
      if (r == 1) ok++;
    }
    expect(ok, greaterThanOrEqualTo(3), reason: lastWhy);
  });

  test('41 diva: el foco sobre ella gana; sin foco no', () {
    expect(play(DivaSpot.new, (c, p, f) {
      final d = (c as DivaSpot).diva;
      touch(p, d.dx, d.dy - 80);
    }), 1);
    expect(play(DivaSpot.new, (c, p, f) {}), 0);
  });

  test('42 abuelo: andar solo cuando duerme gana; andar siempre pierde', () {
    var ok = 0;
    for (var s = 0; s < 6; s++) {
      if (play(Grandpa.new, (c, p, f) {
            if ((c as Grandpa).state == 0) touch(p, c.cx, c.cy);
          }) ==
          1) {
        ok++;
      }
    }
    expect(ok, greaterThanOrEqualTo(5), reason: lastWhy);
    expect(play(Grandpa.new, (c, p, f) => touch(p, c.cx, c.cy)), -1);
  });

  test('43 qué ha cambiado: tocar al cambiado gana y a otro pierde', () {
    expect(play(WhatChanged.new, (c, p, f) {
      final w = c as WhatChanged;
      if (w.showAfter) touch(p, w.slotX(w.changed), w.row - 50);
    }), 1);
    expect(play(WhatChanged.new, (c, p, f) {
      final w = c as WhatChanged;
      if (w.showAfter) touch(p, w.slotX((w.changed + 1) % w.n), w.row - 50);
    }), -1);
  });

  test('44 foca: golpear la pelota al bajar gana; sin tocar cae', () {
    var ok = 0;
    for (var s = 0; s < 5; s++) {
      var last = -99;
      if (play(SealBall.new, (c, p, f) {
            final k = c as SealBall;
            if (k.v.dy > 0 && k.b.dy > k.water - 150 && f - last > 8) {
              touch(p, k.b.dx, k.b.dy);
              last = f;
            }
          }) ==
          1) {
        ok++;
      }
    }
    expect(ok, greaterThanOrEqualTo(4), reason: lastWhy);
    expect(play(SealBall.new, (c, p, f) {}), -1);
  });

  test('45 bombero: apuntar a cada llama gana', () {
    expect(play(FireJelly.new, (c, p, f) {
      final k = c as FireJelly;
      final alive = k.flames.where((q) => q[2] > 0);
      if (alive.isNotEmpty) touch(p, alive.first[0], alive.first[1]);
    }), 1);
  });

  test('46 gusanos: tocar a tiempo gana; sin tocar pierde', () {
    expect(play(WormBand.new, (c, p, f) {
      final k = c as WormBand;
      for (final n in k.notes) {
        if (n[2] == 0 && (n[1] - c.t).abs() < .03) {
          touch(p, k.laneX(n[0].toInt()), c.cy);
          break;
        }
      }
    }), 1);
    expect(play(WormBand.new, (c, p, f) {}), -1);
  });

  test('47 caracoles: alternar rápido gana; lento pierde', () {
    expect(play(SnailRace.new, (c, p, f) {
      final k = c as SnailRace;
      if (f % 6 < 3) touch(p, k.btn((f ~/ 6) % 2).center.dx, k.btn(0).center.dy);
    }), 1);
    expect(play(SnailRace.new, (c, p, f) {
      final k = c as SnailRace;
      if (f % 30 < 3) touch(p, k.btn((f ~/ 30) % 2).center.dx, k.btn(0).center.dy);
    }), -1);
  });

  test('48 plátano: arrastrar las tres cáscaras gana', () {
    expect(play(PeelBanana.new, (c, p, f) {
      final k = c as PeelBanana;
      final i = k.done.indexOf(false);
      if (i < 0) return;
      final step = f % 16;
      if (step >= 13) return; // soltar
      final tip = Offset(c.cx + (i - 1) * 24, k.top.dy + 20);
      final d = k.dirOf(i);
      touch(p, tip.dx + d.dx / d.distance * step * 13, tip.dy + d.dy / d.distance * step * 13);
    }), 1);
  });

  test('49 camaleón: cambiar de color al cambiar de franja gana; sin tocar pierde', () {
    expect(play(Chameleon.new, (c, p, f) {
      final k = c as Chameleon;
      if (k.colIdx != k.zone && f % 4 == 0) touch(p, c.cx, c.cy);
    }), 1);
    expect(play(Chameleon.new, (c, p, f) {}), -1);
  });

  test('50 sombras: elegir el animal correcto gana', () {
    expect(play(ShadowPuppets.new, (c, p, f) {
      final k = c as ShadowPuppets;
      if (c.t > .5) touch(p, k.opt(k.answer).center.dx, k.opt(k.answer).center.dy);
    }), 1);
    expect(play(ShadowPuppets.new, (c, p, f) {
      final k = c as ShadowPuppets;
      if (c.t > .5) touch(p, k.opt((k.answer + 1) % 3).center.dx, k.opt(0).center.dy);
    }), -1);
  });

  test('todos los extra se inicializan en todos los niveles', () {
    final g = ZappingGame();
    for (final f in extraChannels) {
      for (var l = 0; l < 6; l++) {
        final c = f(g)..init(l);
        for (var i = 0; i < 60; i++) {
          c.t += 1 / 60;
          c.vt += 1 / 60;
          c.update(1 / 60);
        }
        expect(c.name.isNotEmpty && c.dur > 2, isTrue);
      }
    }
  });
}
