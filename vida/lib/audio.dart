import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/services.dart';

import 'prefs.dart';

/// Efectos (assets/audio/sfx_*.wav) y música por etapa con fundido cruzado.
class Audio {
  static const _sfx = [
    'jump', 'jump2', 'land', 'hit', 'treat', 'card', 'choose', 'stage', 'bad', 'good',
    'tick', 'death', 'bday', 'moment', 'tap', 'pick0', 'pick1', 'pick2', 'pick3',
  ];
  static final Map<String, AudioPool> _pools = {};
  static final Map<String, int> _last = {};
  static final List<AudioPlayer> _players = [];
  static AudioPlayer? _cur;
  static String? _track;
  static bool _ready = false;

  static Future<void> load() async {
    FlameAudio.updatePrefix('assets/audio/');
    for (final n in _sfx) {
      try {
        _pools[n] = await FlameAudio.createPool('sfx_$n.wav', maxPlayers: n == 'tick' ? 1 : 3);
      } catch (_) {
        // Sin audio (tests, emulador sin salida): el juego sigue en silencio.
      }
    }
    try {
      for (var i = 0; i < 2; i++) {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setPlayerMode(PlayerMode.mediaPlayer);
        _players.add(p);
      }
      _ready = true;
    } catch (_) {}
  }

  static void play(String name, {double volume = 1, int minGapMs = 0}) {
    if (!Prefs.sfx) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (minGapMs > 0 && now - (_last[name] ?? 0) < minGapMs) return;
    _last[name] = now;
    _pools[name]?.start(volume: volume).catchError((_) => () async {});
  }

  /// Cambia de tema con un fundido de ~1 s. [track] = null para silenciar.
  static Future<void> music(String? track) async {
    if (!_ready || track == _track) return;
    _track = track;
    final old = _cur;
    _cur = null;
    if (old != null) _fade(old, 0.55, 0, stop: true);
    if (track == null || !Prefs.music) return;
    final p = _players.firstWhere((x) => x != old, orElse: () => _players.first);
    try {
      await p.stop();
      await p.setVolume(0);
      await p.play(AssetSource('audio/$track.ogg'));
      _cur = p;
      _fade(p, 0, 0.55);
    } catch (_) {}
  }

  static void _fade(AudioPlayer p, double from, double to, {bool stop = false}) async {
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 90));
      try { await p.setVolume(from + (to - from) * i / steps); } catch (_) {}
    }
    if (stop) { try { await p.stop(); } catch (_) {} }
  }

  static void pauseAll() { for (final p in _players) { p.pause().catchError((_) {}); } }
  static void resumeAll() { if (Prefs.music) _cur?.resume().catchError((_) {}); }

  /// Vuelve a aplicar el ajuste de música (al activarla o desactivarla).
  static void refresh(String? wanted) {
    final t = _track;
    _track = null;
    if (!Prefs.music) {
      for (final p in _players) { p.stop().catchError((_) {}); }
      _cur = null;
      _track = t;
      return;
    }
    music(wanted ?? t);
  }

  static void haptic({bool strong = false}) {
    if (!Prefs.vibration) return;
    strong ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
  }
}
