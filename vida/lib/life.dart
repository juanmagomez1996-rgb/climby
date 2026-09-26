import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

typedef Json = Map<String, dynamic>;

/// Contenido del juego (assets/data/life.json, exportado de web/data.js).
class LifeData {
  LifeData(this.raw)
      : stats = (raw['stats'] as List).cast<String>(),
        start = (raw['start'] as List).map((e) => (e as num).toDouble()).toList(),
        stages = (raw['stages'] as List).cast<Json>(),
        pickups = (raw['pickups'] as Map).cast<String, Json>(),
        hazards = (raw['hazards'] as Map).cast<String, Json>(),
        spawn = (raw['spawn'] as List).cast<Json>(),
        moments = (raw['moments'] as List).cast<Json>(),
        events = (raw['events'] as List).cast<Json>();

  final Json raw;
  final List<String> stats;
  final List<double> start;
  final List<Json> stages, spawn, moments, events;
  final Map<String, Json> pickups, hazards;

  static Future<LifeData> load() async =>
      LifeData(jsonDecode(await rootBundle.loadString('assets/data/life.json')) as Json);

  int stageOf(int age) {
    var k = 0;
    for (var i = 0; i < stages.length; i++) {
      if (age >= (stages[i]['from'] as num)) k = i;
    }
    return k;
  }
}

List<double> fxOf(dynamic v) => v == null ? const [] : (v as List).map((e) => (e as num).toDouble()).toList();

class LifeBanner {
  LifeBanner(this.head, this.text, this.kind);
  final String head, text;
  final String kind; // 'later', 'msg', 'auto', 'risk', 'life'
  double time = 0;
}

class Tag {
  Tag(this.age, this.text);
  final int age;
  final String text;
}

/// Lo que la vida necesita contarle al juego (sonidos, números flotantes, cartas…).
abstract class LifeListener {
  void statChanged(int i, double dv);
  void sound(String name);
  void yearPassed(int age, bool birthday);
  void stageChanged(int stage);
  void cardOpened(Json event);
  void momentWanted();
  void died();
  void familyChanged();
}

/// Estado y reglas de una vida (sin dibujo ni física): años, stats, eventos y consecuencias.
class Life {
  Life(this.d, this.l, {Random? rng})
      : rng = rng ?? Random(),
        st = List.of(d.start);

  final LifeData d;
  final LifeListener l;
  final Random rng;

  int age = 0;
  double yt = 0;
  final List<double> st;
  final Map<String, bool> flags = {};
  String? partner;
  int hijaAge = 0;
  final List<Json> later = [];
  final List<Tag> tags = [];
  final Set<String> done = {};
  final List<LifeBanner> banners = [];
  int stage = 0;
  int lastEvent = -5, lastMoment = 0;
  double score = 0;
  int picked = 0, hits = 0;
  bool dead = false;
  String cause = '', lastHurt = '';
  Json? card;

  bool flag(String f) => flags[f] == true;
  double r(double a, double b) => a + rng.nextDouble() * (b - a);

  String tr(String s) => s
      .replaceAll('{p}', partner ?? 'tu pareja')
      .replaceAll('{h}', 'Alba')
      .replaceAll('{a}', '$age');

  static double yearDur(int a) => a < 4 ? 0.8 : 2.0;

  /// Aplica un cambio de stats. [dimin]: los objetos rinden menos cuanto más llena está la barra.
  void apply(List<double> fx, {String? cause, bool silent = false, bool dimin = false}) {
    for (var i = 0; i < fx.length && i < 4; i++) {
      final v = fx[i];
      if (v == 0) continue;
      double dv;
      if (dimin && v > 0) {
        dv = v * max(0.15, 1 - st[i] / 115);
      } else {
        dv = (v * r(0.8, 1.2)).roundToDouble();
        if (dv == 0) dv = v.sign;
      }
      st[i] = (st[i] + dv).clamp(0, 100);
      if (!silent) l.statChanged(i, dv);
      if (i == 0 && dv < 0 && cause != null) lastHurt = cause;
    }
    if (st[0] <= 0) die();
  }

  void banner(String head, String text, String kind) => banners.add(LifeBanner(head, tr(text), kind));

  void die([String? why]) {
    if (dead) return;
    dead = true;
    card = null;
    cause = why ?? (lastHurt.isNotEmpty ? 'por $lastHurt' : 'por no cuidarse');
    l.died();
  }

  bool condOk(Json e) =>
      ((e['need'] as List?)?.every((f) => flag(f as String)) ?? true) &&
      ((e['not'] as List?)?.every((f) => !flag(f as String)) ?? true);

  /// Avanza el tiempo de la vida (solo cuando se está corriendo).
  void advance(double dt) {
    yt += dt / yearDur(age);
    if (yt >= 1) {
      yt -= 1;
      yearTick();
    }
  }

  void yearTick() {
    age++;
    final s = st, a = age;
    // salud: el cuerpo se gasta; la tristeza también pasa factura
    if (a > 40) s[0] -= 0.5;
    if (a > 60) s[0] -= 0.8;
    if (a > 75) s[0] -= 0.7;
    if (s[2] < 20) s[0] -= 1;
    // dinero: sueldo, coste de vida, hijos y pensión
    if (a >= 18) s[1] -= 1.2;
    if (a >= 19 && !flag('jubilado') && a < 67) s[1] += flag('curro') ? 2.2 : 1.6;
    if (flag('jubilado') || a >= 67) s[1] += 0.8;
    if (flag('hija') && a - hijaAge < 22) s[1] -= 0.8;
    // la felicidad y las relaciones vuelven poco a poco a su punto medio
    s[2] -= (s[2] - 45) * 0.05 + (a < 13 ? 0 : 0.4);
    s[3] -= (s[3] - 40) * 0.05 + (a < 13 ? 0 : 0.4);
    if (a < 28) s[0] += 1.2;
    if (!flag('pareja') && a > 30) s[3] -= 0.5;
    if (flag('pareja')) s[2] += 0.4;
    if (flag('perro')) s[2] += 0.3;
    if (s[3] > 70) s[2] += 0.3;
    if (s[1] < 10 && a > 18) s[2] -= 0.6;
    for (var i = 0; i < 4; i++) {
      s[i] = s[i].clamp(0, 100);
    }
    score += (s[2] + s[3] + s[0] * 0.5 + s[1] * 0.3) / 10;
    l.yearPassed(a, a % 10 == 0 && a <= 90);

    final sg = d.stageOf(a);
    if (sg != stage) {
      stage = sg;
      l.stageChanged(sg);
    }
    for (final c in later.where((c) => c['at'] == a).toList()) {
      banner('CONSECUENCIA · $a AÑOS', c['t'] as String, 'later');
      final fx = fxOf(c['fx']);
      apply(fx, cause: c['cause'] as String?);
      if (c['unflag'] != null) flags[c['unflag'] as String] = false;
      l.sound(fx.fold<double>(0, (x, y) => x + y) >= 0 ? 'good' : 'bad');
    }
    later.removeWhere((c) => c['at'] == a);
    l.familyChanged();
    if (dead) return;
    if (s[0] <= 0) return die();
    if (a >= 100 || (a >= 70 && rng.nextDouble() < (a - 69) * 0.009 + (100 - s[0]) / 1500)) {
      return die(a >= 95 ? 'de viejísimo' : 'de viejo, en su cama');
    }
    // eventos automáticos
    for (final e in d.events) {
      final ages = e['ages'] as List;
      if (e['auto'] == null || done.contains(e['id']) || a < ages[0] || a > ages[1] || !condOk(e)) continue;
      if (a == ages[1] || rng.nextDouble() < 0.35) {
        done.add(e['id'] as String);
        final au = e['auto'] as Json;
        banner('A LOS $a AÑOS', au['t'] as String, 'auto');
        apply(fxOf(au['fx']));
        l.sound('bad');
        if (au['unflag'] != null) flags[au['unflag'] as String] = false;
        l.familyChanged();
        return;
      }
    }
    // decisiones
    final cands = d.events.where((e) {
      final ages = e['ages'] as List;
      return e['auto'] == null && !done.contains(e['id']) && a >= ages[0] && a <= ages[1] && condOk(e);
    }).toList();
    Json? ev;
    for (final e in cands) {
      if (e['key'] != null && (a == (e['ages'] as List)[1] || rng.nextDouble() < 0.55)) {
        ev = e;
        break;
      }
    }
    if (ev == null && a - lastEvent >= 2) {
      final pool = cands.where((e) => e['key'] == null || a == (e['ages'] as List)[1]).toList();
      if (pool.isNotEmpty && rng.nextDouble() < 0.55) ev = pool[rng.nextInt(pool.length)];
    }
    if (ev != null) {
      done.add(ev['id'] as String);
      card = ev;
      lastEvent = a;
      l.cardOpened(ev);
      return;
    }
    if (a >= 4 && a - lastMoment >= 4 && a - lastEvent >= 1 && rng.nextDouble() < 0.5) l.momentWanted();
  }

  void outcome(Json? o) {
    if (o == null) return;
    if (o['fx'] != null) apply(fxOf(o['fx']), cause: o['cause'] as String?);
    if (o['flag'] != null) flags[o['flag'] as String] = true;
    if (o['unflag'] != null) flags[o['unflag'] as String] = false;
    if (o['partner'] != null) partner = o['partner'] as String;
    if (o['flag'] == 'hija') hijaAge = age;
    if (o['later'] != null) {
      final lt = Json.of(o['later'] as Json);
      lt['at'] = lt['at'] ?? age + (lt['in'] as num).toInt();
      later.add(lt);
    }
    if (o['m'] != null) banner('', o['m'] as String, 'msg');
    final fx = fxOf(o['fx']);
    if (o['cause'] != null && fx.isNotEmpty && fx[0] < 0) lastHurt = o['cause'] as String;
  }

  /// Resuelve la opción [i] de la carta abierta. Devuelve true si hubo un percance (risk).
  bool choose(int i, {bool auto = false}) {
    final e = card;
    if (e == null) return false;
    card = null;
    final o = (e['o'] as List)[i] as Json;
    if (auto) banner('LA VIDA DECIDE POR TI', o['t'] as String, 'life');
    if (o['tag'] != null) tags.add(Tag(age, tr(o['tag'] as String)));
    outcome(o);
    if (o['chance'] != null) {
      final c = o['chance'] as Json;
      final p = (c['p'] as num) + (c['stat'] != null ? (st[(c['stat'] as num).toInt()] - 50) / 250 : 0);
      final ok = rng.nextDouble() < p;
      outcome((ok ? c['ok'] : c['ko']) as Json?);
      l.sound(ok ? 'good' : 'bad');
    }
    var hurt = false;
    if (o['risk'] != null) {
      final rk = o['risk'] as Json;
      if (rng.nextDouble() < (rk['p'] as num)) {
        banner('¡AY!', rk['t'] as String, 'risk');
        apply(fxOf(rk['fx']), cause: rk['cause'] as String?);
        l.sound('hit');
        hurt = true;
      }
    }
    l.familyChanged();
    return hurt;
  }

  int get finalScore => (score + age * 2).round();

  String epitaph() {
    final s = st;
    final best = [
      [2, 'Fue feliz, que no es poco.'],
      [1, 'Tenía mucho dinero. Ahora lo tiene otro.'],
      [3, 'Nunca comió solo.'],
      [0, 'Murió sanísimo, curiosamente.'],
    ]..sort((x, y) => s[y[0] as int].compareTo(s[x[0] as int]));
    String low;
    if (s[2] < 25) {
      low = 'No sonreía ni en las fotos.';
    } else if (s[3] < 25) {
      low = flag('planta') ? 'A su entierro fue su planta.' : 'A su entierro fueron cuatro, pero puntuales.';
    } else if (s[1] < 12) {
      low = 'Debe tres euros a medio barrio.';
    } else if (age < 40) {
      low = 'Se fue demasiado pronto, con la tele encendida.';
    } else if (flag('hija')) {
      low = 'Alba aún guarda su jersey feo.';
    } else if (flag('perro')) {
      low = 'Tornillo sigue esperándole en la puerta.';
    } else if (partner != null && flag('pareja')) {
      low = tr('{p} dice que roncaba, y que lo echa de menos.');
    } else {
      low = 'Hizo lo que pudo con lo que le tocó.';
    }
    return '«Aquí yace Ramón. ${best.first[1]} $low»';
  }

  /// Hasta 5 momentos notables repartidos a lo largo de la vida.
  List<Tag> notable() {
    if (tags.length <= 5) return tags;
    return [for (var i = 0; i < 5; i++) tags[((i * (tags.length - 1)) / 4).round()]];
  }
}
