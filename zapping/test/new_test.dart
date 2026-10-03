import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zapping_infinito/channels.dart';
import 'package:zapping_infinito/channels4.dart';
import 'package:zapping_infinito/channels5.dart';
import 'package:zapping_infinito/game.dart';

import 'bot_harness.dart';

/// Juega [n] partidas con el bot y cuenta las ganadas.
int wins(Channel Function(ZappingGame) make, void Function(Channel c, Pointer p, int f) Function() bot,
    {int n = 8, int level = 0}) {
  var ok = 0;
  for (var s = 0; s < n; s++) {
    if (play(make, bot(), level: level) == 1) ok++;
  }
  return ok;
}

/// Toque corto cada [every] frames (pulsar un frame y soltar el siguiente).
bool tick(int f, int every) => f % every == 0;

void main() {
  test('61 hámster: inclinar hacia los huecos mete la bola', () {
    for (final l in [0, 3]) {
      final ok = wins(HamsterMaze.new, () => (c, p, f) {
            final h = c as HamsterMaze;
            final a = -math.pi / 2 + (f < 2 ? 0 : h.botAng());
            touch(p, h.center.dx + math.cos(a) * 150, h.center.dy + math.sin(a) * 150);
          }, level: l);
      expect(ok, greaterThanOrEqualTo(6), reason: 'nivel $l: $lastWhy');
    }
    expect(play(HamsterMaze.new, (c, p, f) {}), isNot(1));
  });

  test('62 fontanero: girar las piezas del camino conecta el agua', () {
    expect(wins(Plumber.new, () => (c, p, f) {
          final o = (c as Plumber).botTap();
          if (o != null && tick(f, 6)) touch(p, o.dx, o.dy);
        }), 8);
    expect(play(Plumber.new, (c, p, f) {}), isNot(1));
  });

  test('63 huevos: la cama elástica bien puesta los manda a la cesta', () {
    final ok = wins(EggBounce.new, () {
      Object? planned;
      (Offset, Offset)? line;
      var step = -1;
      return (c, p, f) {
        final e = c as EggBounce;
        if (e.egg != null && !identical(e.egg, planned) && !e.egg!.bounced) {
          planned = e.egg;
          line = e.botLine();
          step = 0;
        }
        final l = line;
        if (l == null || step < 0) return;
        if (step == 0) touch(p, l.$1.dx, l.$1.dy);
        if (step == 1) touch(p, l.$2.dx, l.$2.dy);
        step = step >= 2 ? -1 : step + 1;
      };
    });
    expect(ok, greaterThanOrEqualTo(6), reason: lastWhy);
    expect(play(EggBounce.new, (c, p, f) {}), -1);
  });

  test('64 gato: dar la vuelta antes de cada pincho aguanta', () {
    final ok = wins(CeilingCat.new, () {
      var last = -99;
      return (c, p, f) {
        if ((c as CeilingCat).botShouldTap() && f - last > 6) {
          touch(p, c.cx, c.cy);
          last = f;
        }
      };
    });
    expect(ok, greaterThanOrEqualTo(7), reason: lastWhy);
    expect(play(CeilingCat.new, (c, p, f) {}), -1);
  });

  test('65 láseres: esperar y cruzar apagados llega al diamante', () {
    for (final l in [0, 2]) {
      final ok = wins(MuseumLasers.new, () => (c, p, f) {
            final m = c as MuseumLasers;
            final q = m.botTarget();
            touch(p, q.dx, q.dy - 20);
          }, level: l);
      expect(ok, greaterThanOrEqualTo(6), reason: 'nivel $l: $lastWhy');
    }
    // ir recto sin mirar acaba saltando la alarma
    expect(play(MuseumLasers.new, (c, p, f) => touch(p, c.cx, c.st)), isNot(1));
  });

  test('66 tarzán: soltarse cuando se llega a la otra liana', () {
    final ok = wins(Tarzan.new, () => (c, p, f) {
          if ((c as Tarzan).wouldCatch() && f.isEven) touch(p, c.cx, c.cy);
        });
    expect(ok, greaterThanOrEqualTo(7), reason: lastWhy);
    expect(play(Tarzan.new, (c, p, f) {
      if (f == 3) touch(p, c.cx, c.cy);
    }), isNot(1));
  });

  test('67 cronómetro: parar a tiempo gana, muy pronto pierde', () {
    expect(wins(BlindTimer.new, () => (c, p, f) {
          if ((c as BlindTimer).botShouldTap()) touch(p, c.cx, c.cy);
        }), 8);
    expect(play(BlindTimer.new, (c, p, f) {
      if (f == 40) touch(p, c.cx, c.cy);
    }), -1);
    expect(play(BlindTimer.new, (c, p, f) {}), -1);
  });

  test('68 bombones: elegir el plato más lleno tres veces', () {
    expect(wins(MoreCandy.new, () => (c, p, f) {
          final m = c as MoreCandy;
          final o = m.plate(m.answer);
          if (m.nextAt < 0 && tick(f, 12)) touch(p, o.dx, o.dy - 20);
        }), 8);
    expect(play(MoreCandy.new, (c, p, f) {
      final m = c as MoreCandy;
      final o = m.plate(1 - m.answer);
      if (tick(f, 12)) touch(p, o.dx, o.dy - 20);
    }), -1);
  });

  test('69 cajera: el montón del cambio justo', () {
    for (final l in [0, 3]) {
      expect(wins(Cashier.new, () => (c, p, f) {
            final k = c as Cashier;
            final o = k.pileAt(k.good);
            if (f == 20) touch(p, o.dx, o.dy - 24);
          }, level: l), 8);
      expect(play(Cashier.new, (c, p, f) {
        final k = c as Cashier;
        final o = k.pileAt((k.good + 1) % 3);
        if (f == 20) touch(p, o.dx, o.dy - 24);
      }, level: l), -1);
    }
  });

  test('70 deletrear: letras en orden', () {
    for (final l in [0, 3]) {
      expect(wins(SpellWord.new, () => (c, p, f) {
            final s = c as SpellWord;
            final i = s.botPick();
            if (i != null && tick(f, 8)) touch(p, s.home[i].dx, s.home[i].dy);
          }, level: l), 8);
    }
  });

  test('71 colorear: cada zona con su número', () {
    expect(wins(PaintNumbers.new, () => (c, p, f) {
          final k = c as PaintNumbers;
          final nx = k.botNext();
          if (nx == null) return;
          if (f % 12 == 0) {
            final o = k.potAt(nx.$1);
            touch(p, o.dx, o.dy - 20);
          } else if (f % 12 == 6) {
            final o = k.regions[nx.$2].label;
            touch(p, o.dx, o.dy);
          }
        }), 8);
  });

  test('72 fuegos: tocar en lo más alto', () {
    final ok = wins(Fireworks.new, () => (c, p, f) {
          final r = (c as Fireworks).botTarget();
          if (r != null && f.isEven) touch(p, r.x, r.y);
        });
    expect(ok, greaterThanOrEqualTo(7), reason: lastWhy);
    expect(play(Fireworks.new, (c, p, f) {}), -1);
  });

  test('73 gallina: soltar la red cuando descansa debajo', () {
    final ok = wins(CatchHen.new, () => (c, p, f) {
          final h = c as CatchHen;
          if (h.dropAt >= 0) return;
          if ((h.net - h.hen).distance < 20 && h.resting) return; // suelta
          touch(p, h.hen.dx, h.hen.dy);
        });
    expect(ok, greaterThanOrEqualTo(6), reason: lastWhy);
  });

  test('74 ratón: repetir el camino', () {
    for (final l in [0, 3]) {
      expect(wins(MousePath.new, () => (c, p, f) {
            final m = c as MousePath;
            final i = m.botTile();
            if (i != null && tick(f, 8)) touch(p, m.tile(i).center.dx, m.tile(i).center.dy);
          }, level: l), 8);
    }
    expect(play(MousePath.new, (c, p, f) {
      final m = c as MousePath;
      if (m.t > m.showEnd && f % 8 == 0) touch(p, m.tile(0).center.dx + 300, m.tile(0).center.dy);
    }), isNot(1));
  });

  test('75 peluquería: igualar la foto', () {
    expect(wins(AlienSalon.new, () => (c, p, f) {
          final a = c as AlienSalon;
          final k = a.botButton();
          if (k != null && tick(f, 8)) touch(p, a.btn(k).center.dx, a.btn(k).center.dy);
        }), 8);
  });

  test('76 bomba: inflar hasta lo verde y parar', () {
    final ok = wins(BikePump.new, () => (c, p, f) {
          final b = c as BikePump;
          if (b.pressure < b.lo + .03) touch(p, b.pumpX, f % 16 < 8 ? b.hy0 - 10 : b.hy1 + 20);
        });
    expect(ok, greaterThanOrEqualTo(7), reason: lastWhy);
    // bombear sin parar revienta la rueda
    expect(play(BikePump.new, (c, p, f) {
      final b = c as BikePump;
      touch(p, b.pumpX, f % 16 < 8 ? b.hy0 - 10 : b.hy1 + 20);
    }), -1);
  });

  test('77 tortilla: corte por el centro gana, por el borde pierde', () {
    for (final dy in [0.0, 70.0]) {
      expect(play(Tortilla.new, (c, p, f) {
        final k = c as Tortilla;
        if (f >= 5 && f <= 15) touch(p, k.center.dx - 160 + (f - 5) * 32, k.center.dy + dy);
      }), dy == 0 ? 1 : -1);
    }
  });

  test('78 bañeras: buscar el hueco entre rocas', () {
    for (final l in [0, 3]) {
      final ok = wins(BathRace.new, n: 16, () => (c, p, f) {
            final b = c as BathRace;
            touch(p, b.botX(), b.tubY);
          }, level: l);
      expect(ok, greaterThanOrEqualTo(14), reason: 'nivel $l: $lastWhy');
    }
  });

  test('79 yeti: foto con el yeti dentro del visor', () {
    final ok = wins(YetiPhoto.new, () => (c, p, f) {
          if ((c as YetiPhoto).inside) touch(p, c.cx, c.cy);
        });
    expect(ok, greaterThanOrEqualTo(7), reason: lastWhy);
    expect(play(YetiPhoto.new, (c, p, f) {
      if (f == 2) touch(p, c.cx, c.cy);
    }), -1);
  });

  test('80 constelaciones: un trazo por todas las estrellas', () {
    for (final l in [0, 3]) {
      final ok = wins(Constellations.new, () {
        List<Offset>? path;
        return (c, p, f) {
          final k = c as Constellations;
          path ??= [for (final i in k.botOrder()) k.stars[i]];
          final seg = f ~/ 10, u = (f % 10) / 10;
          if (seg + 1 >= path!.length) {
            touch(p, path!.last.dx, path!.last.dy);
            return;
          }
          final o = Offset.lerp(path![seg], path![seg + 1], u)!;
          touch(p, o.dx, o.dy);
        };
      }, level: l);
      expect(ok, greaterThanOrEqualTo(7), reason: 'nivel $l: $lastWhy');
    }
  });

  test('81 figuras: girar y encajar las tres', () {
    final ok = wins(ShapeFit.new, () {
      var step = 0, piece = -1;
      Offset from = Offset.zero;
      return (c, p, f) {
        final s = c as ShapeFit;
        if (piece < 0 || s.placed[piece]) {
          piece = [0, 1, 2].firstWhere((i) => !s.placed[i], orElse: () => -1);
          step = 0;
          if (piece < 0) return;
        }
        if (s.rot[piece] != s.holeRot[piece]) {
          if (step++ % 4 == 0) touch(p, s.pos[piece].dx, s.pos[piece].dy);
          return;
        }
        if (step % 20 == 0) from = s.pos[piece];
        final k = step % 20;
        step++;
        if (k < 12) {
          final o = Offset.lerp(from, s.hole(piece), k / 11)!;
          touch(p, o.dx, o.dy);
        }
      };
    });
    expect(ok, greaterThanOrEqualTo(7), reason: lastWhy);
  });

  test('82 pingüino: el camino más corto llega al pez', () {
    final ok = wins(PenguinSlide.new, () {
      var step = 0;
      return (c, p, f) {
        final k = c as PenguinSlide;
        if (k.moving) return;
        final s = k.solve(k.pen);
        if (s == null || s.isEmpty) return;
        final o = k.cellC(k.pen);
        final d = PenguinSlide.dirs[s.first];
        final ph = step++ % 6;
        if (ph == 0) touch(p, o.dx, o.dy);
        if (ph == 1) touch(p, o.dx + d.dx * 70, o.dy + d.dy * 70);
      };
    });
    expect(ok, 8, reason: lastWhy);
  });

  test('83 sumo: empujar desde detrás saca al rival', () {
    for (final l in [0, 3]) {
      final ok = wins(SumoMochi.new, () => (c, p, f) {
            final q = (c as SumoMochi).botTarget();
            touch(p, q.dx, q.dy);
          }, level: l);
      expect(ok, greaterThanOrEqualTo(6), reason: 'nivel $l: $lastWhy');
    }
    expect(play(SumoMochi.new, (c, p, f) {}), isNot(1));
  });

  test('84 cables: colocarlos en corro deshace los cruces', () {
    for (final l in [0, 3]) {
      expect(wins(Untangle.new, () {
        var node = 0, step = 0;
        Offset from = Offset.zero;
        return (c, p, f) {
          final u = c as Untangle;
          if (node >= u.nodes.length) return;
          final k = step++ % 14;
          if (k == 0) from = u.nodes[node];
          if (k < 11) {
            final o = Offset.lerp(from, u.solved(node), k / 10)!;
            touch(p, o.dx, o.dy);
          }
          if (k == 13) node++;
        };
      }, level: l), 8, reason: lastWhy);
    }
  });

  test('85 jenga: quitar solo los gofres que no sujetan', () {
    for (final l in [0, 3]) {
      expect(wins(WaffleJenga.new, () => (c, p, f) {
            final w = c as WaffleJenga;
            final pk = w.botPick();
            if (pk != null && tick(f, 10)) {
              final o = w.piece(pk.$1, pk.$2);
              touch(p, o.dx, o.dy);
            }
          }, level: l), 8);
    }
    // quitar el centro de una capa sin un lado la tumba
    expect(play(WaffleJenga.new, (c, p, f) {
      final w = c as WaffleJenga;
      if (!tick(f, 10)) return;
      for (var i = 0; i < 7; i += 2) {
        for (var k = 0; k < 3; k++) {
          final e = [...w.ends[i]];
          if (!e[k]) continue;
          e[k] = false;
          if (!WaffleJenga.stable(e)) {
            final o = w.piece(i, k);
            touch(p, o.dx, o.dy);
            return;
          }
        }
      }
      // si no hay ninguno peligroso, deja una capa con un solo lado y vuelve a mirar
      final pk = w.botPick();
      if (pk != null) touch(p, w.piece(pk.$1, pk.$2).dx, w.piece(pk.$1, pk.$2).dy);
    }), -1);
  });

  test('todos los nuevos se inicializan y avanzan en todos los niveles', () {
    final g = ZappingGame();
    for (final f in newChannels) {
      for (var l = 0; l < 7; l++) {
        final c = f(g)..init(l);
        for (var i = 0; i < 90; i++) {
          c.t += 1 / 60;
          c.vt += 1 / 60;
          c.update(1 / 60);
        }
        expect(c.name.isNotEmpty && c.dur > 2, isTrue);
      }
    }
  });
}
