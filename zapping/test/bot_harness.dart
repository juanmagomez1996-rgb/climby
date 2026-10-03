import 'package:zapping_infinito/channels.dart';
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

