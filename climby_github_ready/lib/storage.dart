import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'level.dart';
import 'physics.dart';

class Customization {
  Color skin;
  Color hair;
  Color shirt;
  Color shorts;
  Color shoes;
  BodyType bodyType;

  Customization({
    this.skin = const Color(0xFFC69365),
    this.hair = const Color(0xFF2A1A0D),
    this.shirt = const Color(0xFFD94E7A),
    this.shorts = const Color(0xFF3A3A55),
    this.shoes = const Color(0xFF5A8A3A),
    this.bodyType = BodyType.normal,
  });

  Map<String, dynamic> toJson() => {
        'skin': skin.value,
        'hair': hair.value,
        'shirt': shirt.value,
        'shorts': shorts.value,
        'shoes': shoes.value,
        'bodyType': bodyType.name,
      };

  factory Customization.fromJson(Map<String, dynamic> j) {
    return Customization(
      skin: Color(j['skin'] as int? ?? 0xFFC69365),
      hair: Color(j['hair'] as int? ?? 0xFF2A1A0D),
      shirt: Color(j['shirt'] as int? ?? 0xFFD94E7A),
      shorts: Color(j['shorts'] as int? ?? 0xFF3A3A55),
      shoes: Color(j['shoes'] as int? ?? 0xFF5A8A3A),
      bodyType: BodyType.values.firstWhere(
        (b) => b.name == (j['bodyType'] as String? ?? 'normal'),
        orElse: () => BodyType.normal,
      ),
    );
  }
}

class Prefs {
  static SharedPreferences? _prefs;
  static Customization customization = Customization();
  static bool skipTips = false;
  static bool sfxEnabled = true;
  static bool musicEnabled = true;
  static Map<String, bool> playedModes = {};

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final cs = _prefs!.getString('customize');
    if (cs != null) {
      try {
        customization = Customization.fromJson(jsonDecode(cs));
      } catch (_) {}
    }
    skipTips = _prefs!.getBool('skipTips') ?? false;
    sfxEnabled = _prefs!.getBool('sfxEnabled') ?? true;
    musicEnabled = _prefs!.getBool('musicEnabled') ?? true;
    final pm = _prefs!.getString('playedModes');
    if (pm != null) {
      try {
        final m = jsonDecode(pm) as Map<String, dynamic>;
        playedModes = m.map((k, v) => MapEntry(k, v as bool));
      } catch (_) {}
    }
  }

  static Future<void> saveCustomization() async {
    await _prefs?.setString(
        'customize', jsonEncode(customization.toJson()));
  }

  static Future<void> setSkipTips(bool v) async {
    skipTips = v;
    await _prefs?.setBool('skipTips', v);
  }

  static Future<void> setSfxEnabled(bool v) async {
    sfxEnabled = v;
    await _prefs?.setBool('sfxEnabled', v);
  }

  static Future<void> setMusicEnabled(bool v) async {
    musicEnabled = v;
    await _prefs?.setBool('musicEnabled', v);
  }

  static Future<void> markPlayed(String mode) async {
    playedModes[mode] = true;
    await _prefs?.setString('playedModes', jsonEncode(playedModes));
  }

  static double getRecord(String levelName) {
    return _prefs?.getDouble('record_$levelName') ?? 0;
  }

  static Future<void> setRecord(String levelName, double height) async {
    await _prefs?.setDouble('record_$levelName', height);
  }

  static List<Level> getSavedLevels() {
    final raw = _prefs?.getString('levels') ?? '[]';
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((j) => Level.fromJson(j as Map<String, dynamic>))
          .whereType<Level>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLevel(Level level) async {
    final levels = getSavedLevels();
    final idx = levels.indexWhere((l) => l.name == level.name);
    if (idx >= 0) {
      levels[idx] = level;
    } else {
      levels.add(level);
    }
    await _prefs?.setString(
        'levels', jsonEncode(levels.map((l) => l.toJson()).toList()));
  }

  static Future<void> deleteLevel(String name) async {
    final levels = getSavedLevels().where((l) => l.name != name).toList();
    await _prefs?.setString(
        'levels', jsonEncode(levels.map((l) => l.toJson()).toList()));
  }
}
