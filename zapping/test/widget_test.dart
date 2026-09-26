import 'package:flutter_test/flutter_test.dart';
import 'package:zapping_infinito/channels.dart';
import 'package:zapping_infinito/channels2.dart';
import 'package:zapping_infinito/game.dart';

void main() {
  balanceTest();
  test('hay 30 canales y la pantalla cabe dentro de la tele', () {
    expect(allChannels.length, 30);
    expect(ZappingGame.tvRect.contains(ZappingGame.screen.topLeft), isTrue);
    expect(ZappingGame.tvRect.contains(ZappingGame.screen.bottomRight), isTrue);
  });

  test('cada canal se inicializa y avanza sin errores', () {
    final g = ZappingGame();
    for (final f in [...allChannels, Boss.new]) {
      final c = f(g)..init(0);
      for (var i = 0; i < 120; i++) {
        c.t += 1 / 60;
        c.vt += 1 / 60;
        c.update(1 / 60);
      }
      expect(c.name, isNotEmpty);
    }
  });
}

/// El equilibrista: sin tocar se cae; una persona que reacciona con retraso lo mantiene,
/// a 60 y a 120 Hz (la física no depende de la pantalla ni del refresco).
void balanceTest() {
  for (final hz in [60.0, 120.0]) {
    test('equilibrista a $hz Hz', () {
      double run(bool human) {
        final g = ZappingGame();
        final c = Balance(g)..init(0);
        final dt = 1 / hz;
        final hist = <double>[];
        var worst = 0.0;
        for (var i = 0; i < hz * 6 && c.res == 0; i++) {
          c.t += dt;
          c.vt += dt;
          hist.add(c.th);
          if (human) {
            final seen = hist.length > hz * .2 ? hist[hist.length - (hz * .2).round()] : 0.0;
            g.ptr
              ..down = true
              ..x = (c.x + seen * 150).clamp(c.sl + 50, c.sr - 50)
              ..y = c.cy;
          }
          c.update(dt);
          worst = worst > c.th.abs() ? worst : c.th.abs();
        }
        return c.res.toDouble();
      }

      expect(run(false), -1, reason: 'sin tocar debe caerse');
      expect(run(true), 0, reason: 'con un control razonable debe aguantar');
    });
  }
}
