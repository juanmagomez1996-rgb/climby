import 'package:shared_preferences/shared_preferences.dart';

class Prefs {
  static SharedPreferences? _p;
  static int best = 0;
  static bool sound = true;
  static bool vibration = true;

  static Future<void> init() async {
    try {
      _p = await SharedPreferences.getInstance();
      best = _p!.getInt('best') ?? 0;
      sound = _p!.getBool('sound') ?? true;
      vibration = _p!.getBool('vibration') ?? true;
    } catch (_) {}
  }

  /// Guarda el récord si [score] lo supera. Devuelve true si es nuevo récord.
  static bool submit(int score) {
    if (score <= best) return false;
    best = score;
    _p?.setInt('best', best);
    return true;
  }

  static void setSound(bool v) {
    sound = v;
    _p?.setBool('sound', v);
  }

  static void setVibration(bool v) {
    vibration = v;
    _p?.setBool('vibration', v);
  }
}
