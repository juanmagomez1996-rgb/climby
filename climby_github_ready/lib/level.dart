import 'dart:convert';
import 'dart:math' as math;
import 'holds.dart';
import 'physics.dart';

class WeatherSpec {
  final bool wind;
  final bool rain;
  WeatherSpec({this.wind = true, this.rain = false});

  Map<String, dynamic> toJson() => {'wind': wind, 'rain': rain};
  factory WeatherSpec.fromJson(Map<String, dynamic> j) =>
      WeatherSpec(
        wind: j['wind'] ?? true,
        rain: j['rain'] ?? false,
      );
}

class Level {
  String name;
  List<Hold> holds;
  double startY;
  double finishY;
  WeatherSpec weather;
  bool boss;

  Level({
    required this.name,
    required this.holds,
    required this.startY,
    required this.finishY,
    WeatherSpec? weather,
    this.boss = false,
  }) : weather = weather ?? WeatherSpec();

  Map<String, dynamic> toJson() => {
        'name': name,
        'holds': holds.map((h) => h.toJson()).toList(),
        'startY': startY,
        'finishY': finishY,
        'weather': weather.toJson(),
        'boss': boss,
      };

  static Level? fromJson(Map<String, dynamic> j) {
    try {
      final holdsList = (j['holds'] as List)
          .map((e) => Hold.fromJson(e as Map<String, dynamic>))
          .whereType<Hold>()
          .toList();
      if (holdsList.length < 2) return null;
      return Level(
        name: j['name'] as String? ?? 'Sin nombre',
        holds: holdsList,
        startY: (j['startY'] as num?)?.toDouble() ?? 0,
        finishY: (j['finishY'] as num?)?.toDouble() ?? 800,
        weather: j['weather'] != null
            ? WeatherSpec.fromJson(j['weather'] as Map<String, dynamic>)
            : WeatherSpec(),
        boss: j['boss'] ?? false,
      );
    } catch (e) {
      return null;
    }
  }

  String exportToCode() {
    final json = jsonEncode(toJson());
    return base64Encode(utf8.encode(json));
  }

  static Level? fromCode(String code) {
    try {
      final json = utf8.decode(base64Decode(code.trim()));
      final j = jsonDecode(json) as Map<String, dynamic>;
      return fromJson(j);
    } catch (e) {
      return null;
    }
  }

  factory Level.procedural([int? seed]) {
    final r = seed != null ? math.Random(seed) : math.Random();
    final holds = <Hold>[];
    holds.add(Hold(0, 60, HoldType.big));
    double y = 150;
    for (int i = 0; i < 28; i++) {
      final variant = i % 4;
      double x;
      if (variant == 0) {
        x = -90 + r.nextDouble() * 50 - 25;
      } else if (variant == 1) {
        x = 90 + r.nextDouble() * 50 - 25;
      } else if (variant == 2) {
        x = -30 + r.nextDouble() * 50 - 25;
      } else {
        x = 30 + r.nextDouble() * 50 - 25;
      }
      final types = [
        HoldType.small,
        HoldType.medium,
        HoldType.medium,
        HoldType.medium,
        HoldType.big,
      ];
      HoldType type = types[r.nextInt(types.length)];
      if (i > 5 && r.nextDouble() < 0.06) type = HoldType.fragile;
      if (i > 8 && r.nextDouble() < 0.04) {
        type = [
          HoldType.magnet,
          HoldType.slippery,
          HoldType.bouncy,
          HoldType.sticky
        ][r.nextInt(4)];
      }
      holds.add(Hold(x, y, type));
      y += 70 + r.nextDouble() * 40;
    }
    holds.add(Hold(0, y + 50, HoldType.big));
    return Level(
      name: seed != null ? 'Reto Diario' : 'Pared Procedural',
      holds: holds,
      startY: 0,
      finishY: y + 70,
      weather: WeatherSpec(wind: true),
    );
  }

  factory Level.boss() {
    final holds = <Hold>[];
    holds.add(Hold(0, 60, HoldType.big));
    double y = 140;
    for (int i = 0; i < 35; i++) {
      final variant = i % 5;
      double x;
      if (variant == 0) {
        x = -100 + rnd(-20, 20);
      } else if (variant == 1) {
        x = 100 + rnd(-20, 20);
      } else if (variant == 2) {
        x = -40;
      } else if (variant == 3) {
        x = 40;
      } else {
        x = rnd(-80, 80);
      }
      final types = [
        HoldType.small,
        HoldType.medium,
        HoldType.small,
        HoldType.fragile,
      ];
      HoldType type = types[kRand.nextInt(types.length)];
      if (i > 3 && kRand.nextDouble() < 0.15) {
        type = [HoldType.fragile, HoldType.slippery, HoldType.moving]
            [kRand.nextInt(3)];
      }
      if (i > 6 && kRand.nextDouble() < 0.08) type = HoldType.bouncy;
      holds.add(Hold(x, y, type));
      y += rnd(75, 100);
    }
    holds.add(Hold(0, y + 50, HoldType.big));
    return Level(
      name: 'Boss Climb',
      holds: holds,
      startY: 0,
      finishY: y + 70,
      weather: WeatherSpec(wind: true, rain: true),
      boss: true,
    );
  }
}

int dailySeed() {
  final d = DateTime.now();
  return d.year * 10000 + d.month * 100 + d.day;
}
