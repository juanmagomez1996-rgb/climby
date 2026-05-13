import 'package:flutter/material.dart';

enum HoldType {
  small,
  medium,
  big,
  fragile,
  magnet,
  slippery,
  bouncy,
  sticky,
  moving,
  invisible,
}

const Map<HoldType, double> holdRadiusMap = {
  HoldType.small: 14,
  HoldType.medium: 20,
  HoldType.big: 28,
  HoldType.fragile: 18,
  HoldType.magnet: 22,
  HoldType.slippery: 18,
  HoldType.bouncy: 20,
  HoldType.sticky: 22,
  HoldType.moving: 20,
  HoldType.invisible: 16,
};

const Map<HoldType, Color> holdColorMap = {
  HoldType.small: Color(0xFFE85D3C),
  HoldType.medium: Color(0xFFF2B134),
  HoldType.big: Color(0xFF5A8A3A),
  HoldType.fragile: Color(0xFFD33333),
  HoldType.magnet: Color(0xFF666666),
  HoldType.slippery: Color(0xFF7FC7E5),
  HoldType.bouncy: Color(0xFFFF7EB9),
  HoldType.sticky: Color(0xFFA87850),
  HoldType.moving: Color(0xFF8B5FBF),
  HoldType.invisible: Color(0x33FFFFFF),
};

double holdRadius(HoldType t) => holdRadiusMap[t] ?? 18;
Color holdColor(HoldType t) => holdColorMap[t] ?? const Color(0xFF999999);

String holdTypeToString(HoldType t) => t.name;
HoldType? holdTypeFromString(String s) {
  for (final t in HoldType.values) {
    if (t.name == s) return t;
  }
  return null;
}

class Hold {
  double x, y, r;
  HoldType type;
  bool broken = false;
  int hp;
  bool visible = true;
  // Moving hold pattern
  double? baseX;
  double moveAmplitude = 0;
  double moveFreq = 0;
  double movePhase = 0;
  double currentX;
  // Slippery timer
  double slipTimer = 0;

  Hold(this.x, this.y, this.type)
      : r = holdRadius(type),
        hp = type == HoldType.fragile ? 2 : 999999,
        currentX = x,
        visible = type != HoldType.invisible {
    if (type == HoldType.moving) {
      baseX = x;
      moveAmplitude = 40;
      moveFreq = 0.8;
    }
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'type': holdTypeToString(type),
        if (type == HoldType.moving) 'amp': moveAmplitude,
        if (type == HoldType.moving) 'freq': moveFreq,
      };

  static Hold? fromJson(Map<String, dynamic> j) {
    final t = holdTypeFromString(j['type'] as String? ?? 'medium');
    if (t == null) return null;
    final h = Hold((j['x'] as num).toDouble(), (j['y'] as num).toDouble(), t);
    if (j['amp'] != null) h.moveAmplitude = (j['amp'] as num).toDouble();
    if (j['freq'] != null) h.moveFreq = (j['freq'] as num).toDouble();
    return h;
  }
}
