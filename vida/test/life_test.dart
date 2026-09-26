import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:una_vida/life.dart';

class _Quiet implements LifeListener {
  int cards = 0, moments = 0;
  bool dead = false;
  @override
  void statChanged(int i, double dv) {}
  @override
  void sound(String name) {}
  @override
  void yearPassed(int age, bool birthday) {}
  @override
  void stageChanged(int stage) {}
  @override
  void cardOpened(Json event) => cards++;
  @override
  void momentWanted([String? id, Json? opts, void Function(bool ok)? onEnd]) {
    moments++;
    onEnd?.call(true);
  }
  @override
  void died() => dead = true;
  @override
  void familyChanged() {}
  final List<String> found = [];
  @override
  void pathFound(String key, String head, String name, String icon) => found.add(key);
}

LifeData _data() => LifeData(jsonDecode(File('assets/data/life.json').readAsStringSync()) as Json);

void main() {
  test('cada evento, objeto y personaje tiene su imagen', () {
    final d = _data();
    for (final e in d.events.where((e) => e['auto'] == null)) {
      final img = e['img'] ?? e['id'];
      expect(File('assets/ev/$img.webp').existsSync(), isTrue, reason: 'falta la viñeta de ${e['id']}');
      if (e['pimg'] != null) {
        for (final k in d.partners.values.where((k) => k != 'lucia')) {
          expect(File('assets/ev/${e['id']}_$k.webp').existsSync(), isTrue, reason: 'falta ${e['id']}_$k');
        }
      }
      for (final o in (e['o'] as List).cast<Json>()) {
        expect(o['t'], isA<String>());
      }
    }
    for (final k in [...d.pickups.keys, ...d.hazards.keys]) {
      expect(File('assets/items/$k.webp').existsSync(), isTrue, reason: 'falta el sprite de $k');
    }
    for (final s in d.stages) {
      expect(File('assets/bg/${s['bg']}.webp').existsSync(), isTrue);
      expect(File('assets/chars/${s['sprite']}.webp').existsSync(), isTrue);
    }
    for (final h in d.hazards.values) {
      expect(h['cause'], isA<String>(), reason: 'cada obstáculo necesita una causa de muerte legible');
    }
  });

  test('las vidas terminan a una edad razonable y viven muchos eventos', () {
    final d = _data(), ages = <int>[];
    for (var seed = 0; seed < 40; seed++) {
      final rng = Random(seed), q = _Quiet(), life = Life(d, q, rng: rng);
      while (!life.dead && life.age < 101) {
        // un jugador medio: recoge algo cada año y se choca de vez en cuando
        for (var k = 0; k < 6; k++) {
          life.apply([1, 0.6, 1, 1], silent: true, dimin: true);
        }
        if (rng.nextDouble() < 0.4) life.apply([-2, 0, -1, 0], cause: 'una piedra traicionera');
        life.yearTick();
        if (life.card != null) life.choose(rng.nextInt((life.card!['o'] as List).length));
      }
      expect(life.dead, isTrue);
      expect(life.cause, isNotEmpty);
      expect(life.epitaph(), startsWith('«Aquí yace Ramón.'));
      expect(q.cards, greaterThan(10));
      ages.add(life.age);
    }
    final mean = ages.reduce((a, b) => a + b) / ages.length;
    expect(mean, inInclusiveRange(55, 90), reason: 'edad media $mean');
  });

  test('las consecuencias llegan años después', () {
    final d = _data(), life = Life(d, _Quiet(), rng: Random(1));
    life.age = 6;
    life.card = d.events.firstWhere((e) => e['id'] == 'cole');
    life.choose(0);
    expect(life.later.single['at'], 26);
    expect(life.tags.single.text, 'se sentó con el niño raro');
  });

  test('las decisiones con minijuego aplican el resultado', () {
    final d = _data(), life = Life(d, _Quiet(), rng: Random(3));
    life.age = 18;
    life.card = d.events.firstWhere((e) => e['id'] == 'carnet');
    life.choose(0);
    expect(life.flag('carnet'), isTrue);
    expect(life.tags.any((t) => t.text.contains('carné')), isTrue);
  });

  test('en los cumpleaños redondos se soplan las velas', () {
    final d = _data(), q = _Quiet(), life = Life(d, q, rng: Random(5));
    life.age = 29;
    life.yearTick();
    expect(q.moments, 1);
    expect(life.card, isNull);
  });

  test('cada camino tiene su arte y sus finales completos', () {
    final d = _data();
    expect(d.paths, isNotEmpty);
    for (final bg in d.pathBgs) {
      expect(File('assets/bg/$bg.webp').existsSync(), isTrue, reason: 'falta el fondo $bg');
    }
    for (final p in d.paths.values) {
      final stages = [...(p['stages'] as Map).values, for (final b in (p['branches'] as Map).values) ...((b as Json)['stages'] as Map).values];
      for (final st in stages.cast<Json>()) {
        final sp = st['sprite'] as String;
        expect(File('assets/chars/$sp.webp').existsSync(), isTrue, reason: 'falta $sp');
        expect(File('assets/chars/${sp}_jump.webp').existsSync(), isTrue, reason: 'falta el salto de $sp');
        for (final k in [...((st['spawn'] as Json)['pick'] as Map).keys, ...((st['spawn'] as Json)['haz'] as Map).keys]) {
          expect(d.pickups.containsKey(k) || d.hazards.containsKey(k), isTrue, reason: '$k no existe');
        }
      }
      for (final b in (p['branches'] as Map).values.cast<Json>()) {
        expect(b['epitaph'], isA<String>());
      }
    }
    for (final k in d.partners.values) {
      for (final v in ['', '_mid', '_old']) {
        expect(File('assets/chars/$k$v.webp').existsSync(), isTrue, reason: 'falta $k$v');
      }
    }
  });

  test('el camino del fútbol cambia la vida y siempre llega a un final', () {
    final d = _data();
    final branches = <String>{};
    for (var seed = 0; seed < 30; seed++) {
      final rng = Random(seed), q = _Quiet(), life = Life(d, q, rng: rng);
      life.flags['futbolin'] = true;
      while (!life.dead && life.age < 60) {
        life.apply([2, 1, 1, 1], silent: true, dimin: true);
        life.yearTick();
        final c = life.card;
        // entra siempre en el camino; en lo demás, al azar
        if (c != null) life.choose(c['id'] == 'ojeador' ? 0 : rng.nextInt((c['o'] as List).length));
      }
      if (life.dead) continue;
      expect(life.path, 'futbol', reason: 'semilla $seed');
      expect(life.branch, isNotNull, reason: 'semilla $seed: sin final a los 60');
      expect(life.stageInfo(1)['bg'], 'bgf_cantera');
      expect(life.stageInfo(3)['sprite'], startsWith('ramon3_'));
      expect(q.found, contains('futbol'));
      expect(life.epitaph(), contains((life.branchData!['epitaph'] as String)));
      branches.add(life.branch!);
    }
    expect(branches.length, greaterThanOrEqualTo(2), reason: 'finales vistos: $branches');
  });
}
