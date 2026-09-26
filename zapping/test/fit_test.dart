import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapping_infinito/channels.dart';
import 'package:zapping_infinito/channels2.dart';
import 'package:zapping_infinito/game.dart';
import 'package:zapping_infinito/gfx.dart';

/// Escala a la que quedará un texto dentro de su caja (igual que Gfx.textIn).
double fitScale(String s, Rect box, double size) {
  final w = box.width * .94, h = box.height * .9;
  final m = Gfx.measure(s, size, maxW: w);
  var sc = 1.0;
  if (m.width * sc > w) sc = w / m.width;
  if (m.height * sc > h) sc = h / m.height;
  return sc;
}

void main() {
  test('los textos de la tarjeta de cada canal caben y se leen', () {
    final g = ZappingGame();
    const panel = Rect.fromLTWH(59 + 14.0, 108 + 230 - 158.0, 421 - 28.0, 316);
    final safe = Gfx.panelSafe(panel, const Color(0xEE1A1424));
    final fr = [.22, .24, .28, .26];
    final sizes = <double>[40, 26, 21, 19];
    final worst = <String>[];
    for (final f in [...allChannels, Boss.new]) {
      final c = f(g);
      final texts = ['CANAL 00', c.name, c.sub, c.hint];
      for (var i = 0; i < 4; i++) {
        final box = Rect.fromLTWH(0, 0, safe.width, safe.height * fr[i]);
        final sc = fitScale(texts[i], box, sizes[i]);
        // letra efectiva mínima legible: 15 px lógicos
        if (sizes[i] * sc < 15) worst.add('${texts[i]} -> ${(sizes[i] * sc).toStringAsFixed(1)}');
      }
      final ins = fitScale(c.ins, const Rect.fromLTWH(0, 0, 360, 80), 42);
      if (42 * ins < 26) worst.add('${c.ins} -> ${(42 * ins).toStringAsFixed(1)}');
    }
    expect(worst, isEmpty, reason: worst.join('\n'));
  });
}
