import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guardado local: récord, vidas vividas, ajustes y las últimas vidas.
class Prefs {
  static SharedPreferences? _p;
  static int best = 0;
  static int lives = 0;
  static bool music = true;
  static bool sfx = true;
  static bool vibration = true;
  static List<Map<String, dynamic>> history = [];
  /// Caminos y finales descubiertos ('futbol', 'futbol_leyenda'…).
  static List<String> found = [];

  static Future<void> init() async {
    try {
      _p = await SharedPreferences.getInstance();
      best = _p!.getInt('best') ?? 0;
      lives = _p!.getInt('lives') ?? 0;
      music = _p!.getBool('music') ?? true;
      sfx = _p!.getBool('sfx') ?? true;
      vibration = _p!.getBool('vibration') ?? true;
      final h = _p!.getString('history');
      if (h != null) history = (jsonDecode(h) as List).cast<Map<String, dynamic>>();
      found = _p!.getStringList('found') ?? [];
    } catch (_) {}
  }

  /// Registra una vida terminada. Devuelve true si es nuevo récord.
  static bool submit(int score, int age) {
    lives++;
    history = [{'age': age, 'score': score}, ...history].take(10).toList();
    final rec = score > best;
    if (rec) best = score;
    _p?.setInt('best', best);
    _p?.setInt('lives', lives);
    _p?.setString('history', jsonEncode(history));
    return rec;
  }

  /// Guarda un camino o final descubierto. Devuelve true si es nuevo.
  static bool discover(String key) {
    if (found.contains(key)) return false;
    found = [...found, key];
    _p?.setStringList('found', found);
    return true;
  }

  static int get foundBranches => found.where((k) => k.contains('_')).length;

  static void reset() {
    found = [];
    _p?.remove('found');
    best = 0;
    lives = 0;
    history = [];
    _p?.setInt('best', 0);
    _p?.setInt('lives', 0);
    _p?.remove('history');
  }

  static void setMusic(bool v) { music = v; _p?.setBool('music', v); }
  static void setSfx(bool v) { sfx = v; _p?.setBool('sfx', v); }
  static void setVibration(bool v) { vibration = v; _p?.setBool('vibration', v); }
}
