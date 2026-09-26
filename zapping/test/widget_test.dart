import 'package:flutter_test/flutter_test.dart';
import 'package:zapping_infinito/channels.dart';
import 'package:zapping_infinito/channels2.dart';
import 'package:zapping_infinito/game.dart';

void main() {
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
