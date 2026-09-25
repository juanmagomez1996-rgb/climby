import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

import 'prefs.dart';

/// Efectos de sonido sintetizados (assets/audio/*.wav), con un pool por efecto.
class Sfx {
  static const _names = [
    'static', 'go', 'tick', 'win', 'lose', 'chop', 'splat', 'pop', 'squish',
    'boing', 'bosshit', 'click', 'ratchet', 'shake', 'eh', 'boom', 'gulp',
    'bonus', 'gameover', 'note0', 'note1', 'note2', 'note3',
  ];
  static final Map<String, AudioPool> _pools = {};
  static final Map<String, int> _last = {};

  static Future<void> load() async {
    FlameAudio.updatePrefix('assets/audio/');
    for (final n in _names) {
      try {
        _pools[n] = await FlameAudio.createPool('$n.wav', maxPlayers: 3);
      } catch (_) {
        // Sin audio (p. ej. en tests): el juego sigue funcionando en silencio.
      }
    }
  }

  /// Reproduce [name]. [minGapMs] evita saturar cuando se llama en cada frame.
  static void play(String name, {double volume = 1, int minGapMs = 0}) {
    if (!Prefs.sound) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (minGapMs > 0 && now - (_last[name] ?? 0) < minGapMs) return;
    _last[name] = now;
    _pools[name]?.start(volume: volume).catchError((_) => () async {});
  }

  static void haptic({bool strong = false}) {
    if (!Prefs.vibration) return;
    strong ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
  }
}
