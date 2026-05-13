import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'storage.dart';

// Synthesizes audio in-memory and plays via audioplayers (BytesSource).
// All sounds generated as 16-bit PCM WAV at 22050Hz mono.

const int _sampleRate = 22050;

Uint8List _wav(List<double> samples) {
  final byteData = ByteData(44 + samples.length * 2);
  // RIFF header
  byteData.setUint8(0, 0x52); byteData.setUint8(1, 0x49);
  byteData.setUint8(2, 0x46); byteData.setUint8(3, 0x46);
  byteData.setUint32(4, 36 + samples.length * 2, Endian.little);
  byteData.setUint8(8, 0x57); byteData.setUint8(9, 0x41);
  byteData.setUint8(10, 0x56); byteData.setUint8(11, 0x45);
  // fmt subchunk
  byteData.setUint8(12, 0x66); byteData.setUint8(13, 0x6D);
  byteData.setUint8(14, 0x74); byteData.setUint8(15, 0x20);
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little); // PCM
  byteData.setUint16(22, 1, Endian.little); // mono
  byteData.setUint32(24, _sampleRate, Endian.little);
  byteData.setUint32(28, _sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2, Endian.little);
  byteData.setUint16(34, 16, Endian.little);
  // data
  byteData.setUint8(36, 0x64); byteData.setUint8(37, 0x61);
  byteData.setUint8(38, 0x74); byteData.setUint8(39, 0x61);
  byteData.setUint32(40, samples.length * 2, Endian.little);
  // samples
  for (int i = 0; i < samples.length; i++) {
    final s = (samples[i].clamp(-1.0, 1.0) * 32767).toInt();
    byteData.setInt16(44 + i * 2, s, Endian.little);
  }
  return byteData.buffer.asUint8List();
}

// === Synth helpers ===
List<double> _tone({
  required double freq,
  String type = 'sine',
  required double dur,
  double attack = 0.005,
  double release = 0.1,
  double vol = 0.5,
  double? freqEnd,
}) {
  final n = (dur * _sampleRate).toInt();
  final samples = List<double>.filled(n, 0);
  for (int i = 0; i < n; i++) {
    final t = i / _sampleRate;
    final progress = i / n;
    double f = freq;
    if (freqEnd != null) {
      // Exponential ramp
      f = freq * math.pow(freqEnd / freq, progress).toDouble();
    }
    final phase = 2 * math.pi * f * t;
    double sample;
    switch (type) {
      case 'square':
        sample = math.sin(phase) > 0 ? 1.0 : -1.0;
        break;
      case 'triangle':
        final p = (phase / (2 * math.pi)) % 1.0;
        sample = (p < 0.5) ? 4 * p - 1 : 3 - 4 * p;
        break;
      case 'sawtooth':
        sample = 2 * ((phase / (2 * math.pi)) % 1.0) - 1;
        break;
      case 'sine':
      default:
        sample = math.sin(phase);
    }
    // Envelope
    double env;
    if (t < attack) {
      env = t / attack;
    } else if (t > dur - release) {
      env = math.max(0.0, (dur - t) / release);
    } else {
      env = 1.0;
    }
    samples[i] = sample * env * vol;
  }
  return samples;
}

List<double> _noise({required double dur, double vol = 0.4, double filterFreq = 800}) {
  final n = (dur * _sampleRate).toInt();
  final samples = List<double>.filled(n, 0);
  final r = math.Random();
  // Simple lowpass filter
  double prev = 0;
  final alpha = filterFreq / (filterFreq + _sampleRate / (2 * math.pi));
  for (int i = 0; i < n; i++) {
    final raw = (r.nextDouble() * 2 - 1);
    final filtered = prev + alpha * (raw - prev);
    prev = filtered;
    final t = i / _sampleRate;
    final env = math.max(0.0, 1.0 - t / dur);
    samples[i] = filtered * env * vol;
  }
  return samples;
}

List<double> _mix(List<List<double>> tracks) {
  final n = tracks.map((t) => t.length).reduce(math.max);
  final out = List<double>.filled(n, 0);
  for (final track in tracks) {
    for (int i = 0; i < track.length; i++) {
      out[i] += track[i];
    }
  }
  // Normalize
  double maxAbs = 0;
  for (final s in out) {
    if (s.abs() > maxAbs) maxAbs = s.abs();
  }
  if (maxAbs > 1) {
    for (int i = 0; i < n; i++) {
      out[i] /= maxAbs;
    }
  }
  return out;
}

List<double> _seq(List<List<double>> tracks, double gap) {
  final out = <double>[];
  final gapSamples = (gap * _sampleRate).toInt();
  for (int t = 0; t < tracks.length; t++) {
    out.addAll(tracks[t]);
    if (t < tracks.length - 1) out.addAll(List<double>.filled(gapSamples, 0));
  }
  return out;
}

class AudioSystem {
  final List<AudioPlayer> _sfxPool = [];
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _bossMusicPlayer = AudioPlayer();
  int _poolIdx = 0;
  final Map<String, Uint8List> _cache = {};
  Timer? _musicTimer;
  bool _musicPlaying = false;
  String _currentMusic = '';

  bool get sfxEnabled => Prefs.sfxEnabled;
  bool get musicEnabled => Prefs.musicEnabled;

  AudioSystem() {
    for (int i = 0; i < 6; i++) {
      _sfxPool.add(AudioPlayer());
    }
  }

  void _play(String key, List<double> samples, {double volume = 1.0}) {
    if (!sfxEnabled) return;
    Uint8List? bytes = _cache[key];
    if (bytes == null) {
      bytes = _wav(samples);
      _cache[key] = bytes;
    }
    final player = _sfxPool[_poolIdx];
    _poolIdx = (_poolIdx + 1) % _sfxPool.length;
    player.stop();
    player.setVolume(volume);
    player.play(BytesSource(bytes));
    HapticFeedback.lightImpact();
  }

  // === SFX ===
  void grip() {
    _play('grip', _mix([
      _tone(freq: 280, freqEnd: 180, dur: 0.08, vol: 0.4, release: 0.05),
      _noise(dur: 0.04, vol: 0.15, filterFreq: 1200),
    ]));
  }

  void release() {
    _play('release', _tone(
        freq: 200, freqEnd: 120, type: 'triangle',
        dur: 0.06, vol: 0.25, release: 0.03));
  }

  void crack() {
    _play('crack', _mix([
      _noise(dur: 0.2, vol: 0.4, filterFreq: 3000),
      _tone(freq: 600, freqEnd: 100, type: 'sawtooth', dur: 0.15, vol: 0.2),
    ]));
    HapticFeedback.heavyImpact();
  }

  void whoosh() {
    _play('whoosh', _noise(dur: 0.5, vol: 0.3, filterFreq: 600));
  }

  void win() {
    final notes = [523.0, 659.0, 784.0, 1047.0];
    final tracks = notes.map((f) => _mix([
          _tone(freq: f, type: 'triangle', dur: 0.18, vol: 0.5, release: 0.15),
          _tone(freq: f * 2, dur: 0.15, vol: 0.25, release: 0.1),
        ])).toList();
    tracks.add(_tone(freq: 1047, type: 'triangle', dur: 0.5, vol: 0.5, release: 0.4));
    _play('win', _seq(tracks, 0.05));
    HapticFeedback.heavyImpact();
  }

  void fall() {
    _play('fall', _seq([
      _tone(freq: 800, freqEnd: 100, type: 'square', dur: 0.6, vol: 0.3, release: 0.1),
      _tone(freq: 150, freqEnd: 80, type: 'square', dur: 0.3, vol: 0.25, release: 0.2),
    ], 0.0));
    HapticFeedback.heavyImpact();
  }

  void boing() {
    final r = math.Random();
    final f = 180.0 + r.nextDouble() * 140;
    _play('boing_${f.toInt()}', _tone(
        freq: f, freqEnd: f * 2.4,
        dur: 0.18, vol: 0.35, release: 0.1));
  }

  void splash() {
    _play('splash', _mix([
      _noise(dur: 0.4, vol: 0.45, filterFreq: 1500),
      _tone(freq: 90, freqEnd: 50, dur: 0.3, vol: 0.6, release: 0.2),
    ]));
    HapticFeedback.heavyImpact();
  }

  void click() {
    _play('click', _tone(freq: 900, dur: 0.04, vol: 0.18, release: 0.02));
  }

  void countdown(int n) {
    if (n == 0) {
      _play('countdown_go', _mix([
        _tone(freq: 523, type: 'triangle', dur: 0.4, vol: 0.4, release: 0.3),
        _tone(freq: 659, type: 'triangle', dur: 0.4, vol: 0.4, release: 0.3),
        _tone(freq: 784, type: 'triangle', dur: 0.4, vol: 0.4, release: 0.3),
      ]));
    } else {
      _play('countdown_n', _tone(freq: 440, dur: 0.12, vol: 0.4, release: 0.05));
    }
    HapticFeedback.mediumImpact();
  }

  void trampolineBounce() {
    _play('trampoline', _tone(
        freq: 200, freqEnd: 600,
        dur: 0.18, vol: 0.4, release: 0.1));
  }

  void magnet() {
    _play('magnet', _tone(
        freq: 800, freqEnd: 1400,
        dur: 0.15, vol: 0.2, release: 0.1));
  }

  void slip() {
    _play('slip', _tone(
        freq: 600, freqEnd: 200,
        dur: 0.2, vol: 0.25, release: 0.15));
  }

  void newRecord() {
    final notes = [659.0, 784.0, 988.0, 1319.0];
    final tracks = notes.map((f) =>
        _tone(freq: f, type: 'triangle', dur: 0.12, vol: 0.4, release: 0.08)).toList();
    _play('newRecord', _seq(tracks, 0.0));
  }

  void thunder() {
    _play('thunder', _mix([
      _noise(dur: 0.8, vol: 0.5, filterFreq: 400),
      _tone(freq: 80, freqEnd: 40, dur: 0.6, vol: 0.4),
    ]));
    HapticFeedback.heavyImpact();
  }

  // === MUSIC ===
  // Lullaby loop: pentatonic C major, music-box feel
  // We pre-generate one full loop and play in loop mode.
  Uint8List _generateLullaby() {
    // Pattern: [freq, durBeats]. Whole pattern = 8 beats at 0.5s each = 4s
    final pattern = [
      [523.0, 0.5], [659.0, 0.5], [784.0, 0.5], [659.0, 0.5],
      [523.0, 0.5], [440.0, 0.5], [392.0, 1.0],
      [523.0, 0.5], [659.0, 0.5], [784.0, 0.5], [880.0, 0.5],
      [784.0, 0.5], [659.0, 0.5], [523.0, 1.0],
    ];
    final tracks = <List<double>>[];
    for (final note in pattern) {
      tracks.add(_mix([
        _tone(freq: note[0], type: 'sine', dur: note[1] * 0.95,
            vol: 0.18, attack: 0.02, release: 0.3),
        _tone(freq: note[0] * 2, type: 'triangle', dur: note[1] * 0.95,
            vol: 0.06, attack: 0.02, release: 0.3),
      ]));
    }
    return _wav(_seq(tracks, 0.0));
  }

  Uint8List _generateBossMusic() {
    // Minor pentatonic, faster, sawtooth filtered
    final pattern = [
      [330.0, 0.25], [392.0, 0.25], [466.0, 0.25], [392.0, 0.25],
      [330.0, 0.25], [294.0, 0.25], [262.0, 0.5],
      [330.0, 0.25], [392.0, 0.25], [466.0, 0.25], [523.0, 0.25],
      [466.0, 0.25], [392.0, 0.25], [330.0, 0.5],
    ];
    final tracks = <List<double>>[];
    for (final note in pattern) {
      tracks.add(_tone(
          freq: note[0], type: 'sawtooth',
          dur: note[1] * 0.95, vol: 0.12,
          attack: 0.02, release: 0.15));
    }
    return _wav(_seq(tracks, 0.0));
  }

  Future<void> startMusic() async {
    if (!musicEnabled) return;
    if (_currentMusic == 'normal') return;
    _currentMusic = 'normal';
    await _bossMusicPlayer.stop();
    final bytes = _cache['music_normal'] ??= _generateLullaby();
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.35);
    await _musicPlayer.play(BytesSource(bytes));
    _musicPlaying = true;
  }

  Future<void> startBossMusic() async {
    if (!musicEnabled) return;
    if (_currentMusic == 'boss') return;
    _currentMusic = 'boss';
    await _musicPlayer.stop();
    final bytes = _cache['music_boss'] ??= _generateBossMusic();
    await _bossMusicPlayer.setReleaseMode(ReleaseMode.loop);
    await _bossMusicPlayer.setVolume(0.3);
    await _bossMusicPlayer.play(BytesSource(bytes));
    _musicPlaying = true;
  }

  Future<void> stopMusic() async {
    _currentMusic = '';
    _musicPlaying = false;
    await _musicPlayer.stop();
    await _bossMusicPlayer.stop();
  }

  Future<void> setMusicEnabled(bool v) async {
    await Prefs.setMusicEnabled(v);
    if (!v) {
      await stopMusic();
    }
  }

  Future<void> setSfxEnabled(bool v) async {
    await Prefs.setSfxEnabled(v);
  }
}

final audio = AudioSystem();
