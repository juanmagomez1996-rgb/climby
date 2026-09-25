// Modo TRAMPOLÍN — simulación pura (sin Flutter) para poder probarla sin UI.
//
// Coordenadas de mundo: y hacia arriba (igual que el modo escalada).
// 30 unidades = 1 metro.
import 'dart:math' as math;
import 'physics.dart';

const double kTrampStep = 1 / 120;
const double kAirDamping = 0.9995;
const double kBedLeft = -260;
const double kBedRight = 260;
const double kBedY = 0;
const double kGroundY = -230;
const double kTowerLeft = -440;
const double kTowerRight = -300;
const double kTowerTop = 600;
const double kWorldHalfWidth = 640;
const double kMaxApex = 1050;
const double kUnitsPerMeter = 30;

double wrapAngle(double a) {
  while (a > math.pi) {
    a -= 2 * math.pi;
  }
  while (a < -math.pi) {
    a += 2 * math.pi;
  }
  return a;
}

/// Resorte blando: deja que las extremidades se estiren como chicle
/// y vuelvan a su largo, con límites duros para que no se rompan.
class Spring {
  final Point a, b;
  final double rest;
  final double k;
  final double minF, maxF;
  Spring(this.a, this.b, this.rest, {this.k = 0.1, this.minF = 0.6, this.maxF = 1.8});

  double get stretch => dist2(a.x, a.y, b.x, b.y) / rest;

  void solve() {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 0.0001) return;
    double target = rest;
    double s = k;
    if (d > rest * maxF) {
      target = rest * maxF;
      s = 1;
    } else if (d < rest * minF) {
      target = rest * minF;
      s = 1;
    }
    final diff = (target - d) / d * 0.5 * s;
    final ox = dx * diff;
    final oy = dy * diff;
    if (!a.locked) {
      a.x -= ox;
      a.y -= oy;
    }
    if (!b.locked) {
      b.x += ox;
      b.y += oy;
    }
  }
}

/// Lona elástica: fila de nodos que solo se mueven en vertical.
class TrampolineBed {
  static const int n = 33;
  final double left = kBedLeft, right = kBedRight, rest = kBedY;
  late final double dx = (right - left) / (n - 1);
  final List<double> y = List.filled(n, kBedY);
  final List<double> py = List.filled(n, kBedY);
  double waveSpeed = 520;
  double support = 210;
  double damping = 0.988;
  double nodeMass = 0.6;
  double maxDepth = 200;

  bool contains(double x) => x > left && x < right;

  double surfaceAt(double x) {
    if (!contains(x)) return rest;
    final t = (x - left) / dx;
    final i = t.floor().clamp(0, n - 2);
    final f = t - i;
    return y[i] * (1 - f) + y[i + 1] * f;
  }

  double nodeX(int i) => left + i * dx;

  void step(double h) {
    final c2 = waveSpeed * waveSpeed / (dx * dx);
    final ny = List<double>.from(y);
    for (int i = 1; i < n - 1; i++) {
      final acc = c2 * (y[i - 1] - 2 * y[i] + y[i + 1]) + support * (rest - y[i]);
      final v = (y[i] - py[i]) * damping;
      // Viscosidad: apaga los zigzags de alta frecuencia de la lona
      final vl = y[i - 1] - py[i - 1], vr = y[i + 1] - py[i + 1];
      final visc = 0.22 * (vl - 2 * (y[i] - py[i]) + vr);
      ny[i] = math.max(rest - maxDepth, y[i] + v + visc + acc * h * h);
    }
    for (int i = 1; i < n - 1; i++) {
      py[i] = y[i];
      y[i] = ny[i];
    }
  }

  /// Empuja el punto fuera de la lona y hunde la lona. Devuelve true si tocó.
  bool collide(Point p, double r, double pointMass) {
    if (!contains(p.x)) return false;
    final s = surfaceAt(p.x);
    final bottom = p.y - r;
    if (bottom >= s) return false;
    if (bottom < s - 70) return false; // está debajo de la lona, no encima
    final pen = s - bottom;
    final t = (p.x - left) / dx;
    final i = t.floor().clamp(0, n - 2);
    final f = t - i;
    final pointShare = nodeMass / (nodeMass + pointMass);
    final bedShare = 1 - pointShare;
    p.y += pen * pointShare;
    if (i > 0) y[i] = math.max(rest - maxDepth, y[i] - pen * bedShare * (1 - f));
    if (i + 1 < n - 1) y[i + 1] = math.max(rest - maxDepth, y[i + 1] - pen * bedShare * f);
    // Fricción de la lona
    p.px += (p.x - p.px) * 0.04;
    return true;
  }

  double depthAt(double x) => rest - surfaceAt(x);
}

enum JumperFace { neutral, focused, scared, happy, dead }

enum LandingKind { feet, seat, crash }

class JumperPart {
  final String key;
  final List<Point> points;
  final Point root;
  final Point socket;
  final List<Stick> joints;
  bool attached = true;
  double detachedFor = 0;
  JumperPart(this.key, this.points, this.root, this.socket, this.joints);
}

/// Muñeco de plastilina para el trampolín: extremidades de goma
/// que se pueden soltar y volver a pegar.
class Jumper {
  final bool isPlayer;
  final BodyType bodyType;
  final int colorIndex;

  late Point head, neck, chest, pelvis;
  late Point ls, rs, lp, rp;
  late Point lar, rar, le, re, lh, rh;
  late Point llr, rlr, lk, rk, lf, rf;
  late List<Point> points;
  late List<Stick> bodySticks;
  late List<Spring> springs;
  final Map<Spring, String> springPart = {};
  late Map<String, JumperPart> parts;

  // Control
  bool tuck = false;
  int spinDir = 0;
  double stretchTimer = 0; // "estirón" al soltar la bolita
  Point? reachHand;
  double reachX = 0, reachY = 0;

  // Estado del salto
  bool simulated = true;
  bool airborne = true;
  bool touchedThisStep = false;
  String? firstContactKind;
  int noContactSteps = 0;
  int contactSteps = 0;
  int airSteps = 0;
  double angAccum = 0;
  double extendedRot = 0;
  double lastAngle = math.pi / 2;
  double apexTarget = 500;
  double peakY = -double.infinity;
  double lastImpactSpeed = 0;
  JumperFace face = JumperFace.neutral;
  double faceTimer = 0;

  // Fuera de la cama
  bool off = false;
  double offTimer = 0;
  double lastPushedByPlayer = -99;

  // IA de los compañeros
  double aiTimer = 0;
  double homeX = 0; // carril al que vuelve en cada bote

  late final double mass;
  late final double spinScale;

  Jumper(double x, double feetY, this.bodyType,
      {this.isPlayer = false, this.colorIndex = 0}) {
    final bm = bodyMultipliers(bodyType);
    mass = bm.weight;
    spinScale = 1 / bm.width;
    _build(x, feetY, bm.width);
  }

  void _build(double x, double f, double w) {
    lf = Point(x - 14, f, 'LF');
    rf = Point(x + 14, f, 'RF');
    lk = Point(x - 12, f + 44, 'LK');
    rk = Point(x + 12, f + 44, 'RK');
    lp = Point(x - 12 * w, f + 86, 'LP');
    rp = Point(x + 12 * w, f + 86, 'RP');
    llr = Point(x - 12 * w, f + 86, 'LLR');
    rlr = Point(x + 12 * w, f + 86, 'RLR');
    pelvis = Point(x, f + 86, 'pelvis');
    chest = Point(x, f + 140, 'chest');
    neck = Point(x, f + 160, 'neck');
    head = Point(x, f + 185, 'head');
    ls = Point(x - 24 * w, f + 144, 'LS');
    rs = Point(x + 24 * w, f + 144, 'RS');
    lar = Point(x - 24 * w, f + 144, 'LAR');
    rar = Point(x + 24 * w, f + 144, 'RAR');
    le = Point(x - 28 * w, f + 102, 'LE');
    re = Point(x + 28 * w, f + 102, 'RE');
    lh = Point(x - 30 * w, f + 60, 'LH');
    rh = Point(x + 30 * w, f + 60, 'RH');

    points = [
      head, neck, chest, pelvis, ls, rs, lp, rp,
      lar, rar, le, re, lh, rh, llr, rlr, lk, rk, lf, rf,
    ];

    bodySticks = [
      Stick(neck, chest),
      Stick(chest, pelvis),
      Stick(chest, ls),
      Stick(chest, rs),
      Stick(ls, rs),
      Stick(neck, ls),
      Stick(neck, rs),
      Stick(pelvis, lp),
      Stick(pelvis, rp),
      Stick(lp, rp),
      Stick(ls, rp, stiffness: 0.8),
      Stick(rs, lp, stiffness: 0.8),
      Stick(ls, lp, stiffness: 0.8),
      Stick(rs, rp, stiffness: 0.8),
    ];

    springs = [];
    void limb(String key, Point a, Point b, double len) {
      final s = Spring(a, b, len);
      springs.add(s);
      springPart[s] = key;
    }

    limb('LA', lar, le, 42);
    limb('LA', le, lh, 42);
    limb('RA', rar, re, 42);
    limb('RA', re, rh, 42);
    limb('LL', llr, lk, 42);
    limb('LL', lk, lf, 44);
    limb('RL', rlr, rk, 42);
    limb('RL', rk, rf, 44);

    parts = {
      'HEAD': JumperPart('HEAD', [head], head, neck,
          [Stick(neck, head, length: 25), Stick(chest, head, length: 45, stiffness: 0.5)]),
      'LA': JumperPart('LA', [lar, le, lh], lar, ls, [Stick(ls, lar, length: 0)]),
      'RA': JumperPart('RA', [rar, re, rh], rar, rs, [Stick(rs, rar, length: 0)]),
      'LL': JumperPart('LL', [llr, lk, lf], llr, lp, [Stick(lp, llr, length: 0)]),
      'RL': JumperPart('RL', [rlr, rk, rf], rlr, rp, [Stick(rp, rlr, length: 0)]),
    };
  }

  // ---------- Utilidades ----------

  bool partAttached(String key) => parts[key]!.attached;

  bool isAttachedPoint(Point p) {
    for (final part in parts.values) {
      if (!part.attached && part.points.contains(p)) return false;
    }
    return true;
  }

  Iterable<Point> get attachedPoints => points.where(isAttachedPoint);

  ({double x, double y}) com() {
    double sx = 0, sy = 0;
    int c = 0;
    for (final p in attachedPoints) {
      sx += p.x;
      sy += p.y;
      c++;
    }
    return (x: sx / c, y: sy / c);
  }

  ({double x, double y}) comVel(double h) {
    double sx = 0, sy = 0;
    int c = 0;
    for (final p in attachedPoints) {
      sx += (p.x - p.px) / h;
      sy += (p.y - p.py) / h;
      c++;
    }
    return (x: sx / c, y: sy / c);
  }

  /// Vector "arriba" del cuerpo (pelvis → cuello).
  ({double x, double y}) up() {
    final dx = neck.x - pelvis.x;
    final dy = neck.y - pelvis.y;
    final d = math.sqrt(dx * dx + dy * dy).clamp(0.001, double.infinity);
    return (x: dx / d, y: dy / d);
  }

  double bodyAngle() {
    final u = up();
    return math.atan2(u.y, u.x);
  }

  bool get upright => up().y > 0.57; // < ~55°

  double angularVelocity(double h) {
    final c = com();
    final v = comVel(h);
    double num = 0, den = 0;
    for (final p in attachedPoints) {
      final rx = p.x - c.x, ry = p.y - c.y;
      final vx = (p.x - p.px) / h - v.x, vy = (p.y - p.py) / h - v.y;
      num += rx * vy - ry * vx;
      den += rx * rx + ry * ry;
    }
    return den > 0 ? num / den : 0;
  }

  void addVelocity(double vx, double vy, double h, {Iterable<Point>? only}) {
    for (final p in only ?? points) {
      p.px -= vx * h;
      p.py -= vy * h;
    }
  }

  void translate(double dx, double dy) {
    for (final p in points) {
      p.x += dx;
      p.y += dy;
      p.px += dx;
      p.py += dy;
    }
  }

  double radiusOf(Point p) {
    switch (p.kind) {
      case 'head':
        return 15;
      case 'LF':
      case 'RF':
        return 9;
      case 'LH':
      case 'RH':
        return 8;
      default:
        return 9;
    }
  }

  // ---------- Fuerzas ----------

  void applyGravity() {
    for (final p in points) {
      p.applyForce(0, -kGravity);
    }
  }

  /// "Músculos": empujan brazos y piernas hacia la pose elegida
  /// (estirado o bolita), más el giro que pide el jugador.
  void applyControl(double h) {
    final c = com();
    final cv = comVel(h);
    final u = up();
    final rx = u.y, ry = -u.x; // derecha del cuerpo

    final targets = <Point, ({double x, double y})>{};
    ({double x, double y}) at(Point base, double along, double side) =>
        (x: base.x + u.x * along + rx * side, y: base.y + u.y * along + ry * side);

    if (tuck) {
      targets[lk] = at(pelvis, 32, -18);
      targets[rk] = at(pelvis, 32, 18);
      targets[lf] = at(pelvis, -6, -22);
      targets[rf] = at(pelvis, -6, 22);
      targets[le] = at(ls, -18, -20);
      targets[re] = at(rs, -18, 20);
      targets[lh] = at(pelvis, 34, -30);
      targets[rh] = at(pelvis, 34, 30);
    } else {
      final s = 1 + 0.45 * (stretchTimer / 0.3).clamp(0.0, 1.0);
      targets[lk] = at(pelvis, -44 * s, -10);
      targets[rk] = at(pelvis, -44 * s, 10);
      targets[lf] = at(pelvis, -88 * s, -14);
      targets[rf] = at(pelvis, -88 * s, 14);
      targets[le] = at(ls, 38 * s, -14);
      targets[re] = at(rs, 38 * s, 14);
      targets[lh] = at(ls, 80 * s, -26);
      targets[rh] = at(rs, 80 * s, 26);
    }
    targets[head] = at(neck, 25, 0);

    if (reachHand != null) {
      targets[reachHand!] = (x: reachX, y: reachY);
    }

    const kp = 700.0, kd = 45.0;
    double sumFx = 0, sumFy = 0;
    int n = 0;
    final attached = attachedPoints.toList();
    final w = angularVelocity(h);
    for (final e in targets.entries) {
      final p = e.key;
      if (!attached.contains(p)) continue;
      // Se amortigua solo el movimiento relativo, no el giro del cuerpo entero
      final vx = (p.x - p.px) / h - cv.x + w * (p.y - c.y);
      final vy = (p.y - p.py) / h - cv.y - w * (p.x - c.x);
      final k = identical(p, reachHand) ? kp * 1.6 : kp;
      final fx = k * (e.value.x - p.x) - kd * vx;
      final fy = k * (e.value.y - p.y) - kd * vy;
      p.applyForce(fx, fy);
      sumFx += fx;
      sumFy += fy;
    }
    n = attached.length;
    // Fuerzas internas: el total se reparte para no "volar" solo
    for (final p in attached) {
      p.applyForce(-sumFx / n, -sumFy / n);
    }

    // Giro
    double alpha = 0;
    if (spinDir != 0) {
      final maxW = (tuck ? 12.0 : 7.0) * spinScale;
      if (spinDir * w < maxW) alpha = 30.0 * spinDir * spinScale;
    } else if (airborne && !tuck && !touchedThisStep) {
      // Sin tocar la pantalla el giro se frena y el muñeco se endereza
      // poco a poco: así se puede aterrizar de pie si sueltas a tiempo
      final err = wrapAngle(bodyAngle() - math.pi / 2);
      alpha = -w * 3 - err * 7;
    } else if (touchedThisStep && !tuck) {
      // En la lona el muñeco intenta ponerse de pie
      final err = wrapAngle(bodyAngle() - math.pi / 2);
      alpha = -err * 45 - w * 7;
    }
    if (alpha != 0) {
      for (final p in attached) {
        p.applyForce(-(p.y - c.y) * alpha, (p.x - c.x) * alpha);
      }
    }
  }

  void integrate(double h) {
    for (final p in points) {
      p.integrate(h, kAirDamping);
    }
  }

  void solveConstraints() {
    for (final s in bodySticks) {
      s.solve();
    }
    for (final part in parts.values) {
      if (!part.attached) continue;
      for (final j in part.joints) {
        j.solve();
      }
    }
    for (final s in springs) {
      s.solve();
    }
  }

  // ---------- Piezas sueltas ----------

  void detach(String key, double vx, double vy, double h) {
    final part = parts[key]!;
    if (!part.attached) return;
    part.attached = false;
    part.detachedFor = 0;
    if (identical(reachHand, lh) && key == 'LA') reachHand = null;
    if (identical(reachHand, rh) && key == 'RA') reachHand = null;
    addVelocity(vx, vy, h, only: part.points);
  }

  int get detachedCount => parts.values.where((p) => !p.attached).length;

  /// Devuelve las piezas que se volvieron a pegar en este paso.
  List<String> updateParts(double h) {
    final reattached = <String>[];
    for (final part in parts.values) {
      if (part.attached) continue;
      part.detachedFor += h;
      if (part.detachedFor < 1.1) continue;
      final root = part.root, sock = part.socket;
      final dx = sock.x - root.x, dy = sock.y - root.y;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d < 12 || part.detachedFor > 4) {
        final ox = sock.x - root.x, oy = sock.y - root.y;
        for (final p in part.points) {
          p.x += ox;
          p.y += oy;
          p.px = p.x - (sock.x - sock.px);
          p.py = p.y - (sock.y - sock.py);
        }
        part.attached = true;
        reattached.add(part.key);
        continue;
      }
      // Imán de plastilina: la pieza vuelve volando a su sitio
      final rvx = (root.x - root.px) / h - (sock.x - sock.px) / h;
      final rvy = (root.y - root.py) / h - (sock.y - sock.py) / h;
      final fx = 160 * dx - 14 * rvx;
      final fy = 160 * dy - 14 * rvy + kGravity;
      for (final p in part.points) {
        p.applyForce(fx, fy);
      }
    }
    return reattached;
  }
}

// =========================================================
//  Mundo
// =========================================================

class TrampItem {
  double x, baseY;
  final String kind; // 'star' | 'balloon'
  final double r;
  bool alive = true;
  double respawn = 0;
  double phase;
  TrampItem(this.x, this.baseY, this.kind, this.phase) : r = kind == 'star' ? 22 : 26;
  double y(double t) => baseY + math.sin(t * 2 + phase) * 8;
  int get points => kind == 'star' ? 50 : 30;
}

class TrampEvent {
  final String type;
  final Jumper jumper;
  final double x, y;
  final String text;
  final int points;
  TrampEvent(this.type, this.jumper, this.x, this.y, {this.text = '', this.points = 0});
}

class RunStats {
  int landings = 0;
  int clean = 0;
  int seats = 0;
  int crashes = 0;
  int maxFlips = 0;
  int totalFlips = 0;
  int layoutTricks = 0;
  final Set<String> tricks = {};
  int stars = 0;
  int balloons = 0;
  int pushes = 0;
  int knockouts = 0;
  int partsLost = 0;
  int outs = 0;
  double maxHeight = 0;
  int bestCombo = 0;
}

String trickName(int flips, bool layout) {
  String base;
  switch (flips) {
    case 1:
      base = 'Mortal';
      break;
    case 2:
      base = 'Doble mortal';
      break;
    case 3:
      base = 'Triple mortal';
      break;
    default:
      base = 'Mortal x$flips';
  }
  return '$base ${layout ? 'estirado' : 'agrupado'}';
}

class TrampolineSim {
  final math.Random rng;
  final TrampolineBed bed = TrampolineBed();
  late Jumper player;
  final List<Jumper> bots = [];
  final List<TrampItem> items = [];
  final List<TrampEvent> events = [];
  final RunStats stats = RunStats();
  final BodyType bodyType;

  double time = 0; // tiempo desde el primer salto
  double clock = 0; // tiempo total
  final double duration;
  bool playerJumped = false;
  bool timeUp = false;
  bool finished = false;
  double finishWait = 0;
  int score = 0;
  int combo = 0;
  double _acc = 0;

  TrampolineSim({this.bodyType = BodyType.normal, int botCount = 2, int? seed, this.duration = 45})
      : rng = math.Random(seed) {
    _placePlayerOnTower();
    for (int i = 0; i < botCount; i++) {
      final b = Jumper(-120.0 + i * 240, 300 + i * 140.0, BodyType.values[(i + 1) % 3],
          colorIndex: i + 1);
      b.apexTarget = 300 + rng.nextDouble() * 200;
      b.homeX = i.isEven ? -185 : 185;
      bots.add(b);
    }
    for (int i = 0; i < 6; i++) {
      items.add(_newItem());
    }
  }

  List<Jumper> get jumpers => [player, ...bots];

  TrampItem _newItem() {
    return TrampItem(
      -220 + rng.nextDouble() * 440,
      200 + rng.nextDouble() * 700,
      rng.nextDouble() < 0.65 ? 'star' : 'balloon',
      rng.nextDouble() * 6,
    );
  }

  void _placePlayerOnTower() {
    player = Jumper(kTowerRight - 40, kTowerTop, bodyType, isPlayer: true);
    player.simulated = false;
    player.airborne = true;
    player.apexTarget = kTowerTop + 110;
    playerJumped = false;
  }

  /// Lanzarse desde la torre.
  void jump() {
    if (playerJumped || finished) return;
    playerJumped = true;
    player.simulated = true;
    player.airborne = true;
    player.peakY = -double.infinity;
    player.addVelocity(290, 520, kTrampStep);
    player.lastAngle = player.bodyAngle();
    events.add(TrampEvent('jump', player, player.chest.x, player.chest.y));
  }

  /// Control del jugador: dir = -1 izquierda, 1 derecha, 0 sin giro.
  void setControl({required bool tuck, required int spinDir}) {
    if (player.tuck && !tuck) player.stretchTimer = 0.3;
    player.tuck = tuck;
    player.spinDir = spinDir;
  }

  double get timeLeft => math.max(0, duration - time);

  void update(double dt) {
    if (finished) return;
    _acc += math.min(dt, 1 / 20);
    while (_acc >= kTrampStep) {
      _step(kTrampStep);
      _acc -= kTrampStep;
      if (finished) break;
    }
  }

  void _step(double h) {
    clock += h;
    if (playerJumped) time += h;
    if (!timeUp && time >= duration) {
      timeUp = true;
      events.add(TrampEvent('timeup', player, player.chest.x, player.chest.y));
    }
    if (timeUp) {
      finishWait += h;
      final settled = !playerJumped || (!player.airborne && player.contactSteps > 10);
      if (settled || finishWait > 3.5) {
        finished = true;
        events.add(TrampEvent('finish', player, player.chest.x, player.chest.y));
        return;
      }
    }

    final active = jumpers.where((j) => j.simulated).toList();

    bed.step(h);
    _updateAi(h);
    _updateReach();

    for (final j in active) {
      if (j.stretchTimer > 0) j.stretchTimer -= h;
      j.applyGravity();
      j.applyControl(h);
      for (final key in j.updateParts(h)) {
        events.add(TrampEvent('reattach', j, j.parts[key]!.socket.x, j.parts[key]!.socket.y, text: key));
      }
      j.integrate(h);
      j.touchedThisStep = false;
    }

    for (int it = 0; it < 12; it++) {
      for (final j in active) {
        j.solveConstraints();
      }
      if (it >= 5) {
        for (final j in active) {
          _collideWorld(j);
        }
        _collideJumpers(active, h, it == 11);
      }
    }

    for (final j in active) {
      _postStep(j, h);
    }
    _updateItems(h);
  }

  void _collideWorld(Jumper j) {
    for (final p in j.points) {
      final r = j.radiusOf(p);
      if (bed.collide(p, r, j.mass)) {
        if (!j.touchedThisStep && j.airborne) j.firstContactKind ??= p.kind;
        if (j.isAttachedPoint(p)) j.touchedThisStep = true;
      }
      // Suelo
      if (p.y - r < kGroundY) {
        p.y = kGroundY + r;
        p.px += (p.x - p.px) * 0.2;
      }
      // Torre
      if (p.x > kTowerLeft && p.x < kTowerRight && p.y - r < kTowerTop) {
        final toTop = kTowerTop - (p.y - r);
        final toRight = kTowerRight - p.x + r;
        if (toTop < toRight) {
          p.y = kTowerTop + r;
        } else {
          p.x = kTowerRight + r;
        }
      }
      // Bordes del mundo
      if (p.x < -kWorldHalfWidth) p.x = -kWorldHalfWidth;
      if (p.x > kWorldHalfWidth) p.x = kWorldHalfWidth;
    }
  }

  void _collideJumpers(List<Jumper> active, double h, bool detectPushes) {
    for (int a = 0; a < active.length; a++) {
      for (int b = a + 1; b < active.length; b++) {
        final ja = active[a], jb = active[b];
        bool pushed = false;
        double nxHit = 0, nyHit = 0;
        for (final p in _hitPoints(ja)) {
          for (final q in _hitPoints(jb)) {
            final dx = q.x - p.x, dy = q.y - p.y;
            final d = math.sqrt(dx * dx + dy * dy);
            final minD = ja.radiusOf(p) + jb.radiusOf(q) + 6;
            if (d >= minD || d < 0.001) continue;
            final nx = dx / d, ny = dy / d;
            final o = (minD - d) / 2;
            p.x -= nx * o;
            p.y -= ny * o;
            q.x += nx * o;
            q.y += ny * o;
            if (detectPushes && !pushed) {
              // Solo cuenta si el que empuja se mueve hacia el otro
              final va = ((p.x - p.px) * nx + (p.y - p.py) * ny) / h;
              final vb = ((q.x - q.px) * nx + (q.y - q.py) * ny) / h;
              final pusherFast = ja.isPlayer ? va > 280 : (jb.isPlayer ? -vb > 280 : false);
              if (pusherFast && va - vb > 340) {
                pushed = true;
                nxHit = nx;
                nyHit = ny;
              }
            }
          }
        }
        if (pushed) {
          if (ja.isPlayer) _onPush(ja, jb, nxHit, nyHit, h);
          if (jb.isPlayer) _onPush(jb, ja, -nxHit, -nyHit, h);
        }
      }
    }
  }

  List<Point> _hitPoints(Jumper j) =>
      [j.head, j.chest, j.pelvis, j.lh, j.rh, j.lf, j.rf, j.lk, j.rk, j.le, j.re];

  void _onPush(Jumper me, Jumper other, double nx, double ny, double h) {
    if (clock - other.lastPushedByPlayer < 1.5) return;
    other.lastPushedByPlayer = clock;
    // Empujón exagerado: que se note
    other.addVelocity(nx * 420, ny * 200 + 220, h);
    me.addVelocity(-nx * 120, 0, h);
    stats.pushes++;
    _addScore(50);
    events.add(TrampEvent('push', other, other.chest.x, other.chest.y + 40, text: '¡Empujón!', points: 50));
  }

  void _addScore(int pts) => score += pts;

  void _postStep(Jumper j, double h) {
    final angle = j.bodyAngle();
    if (j.airborne) {
      final d = wrapAngle(angle - j.lastAngle);
      j.angAccum += d;
      if (!j.tuck) j.extendedRot += d.abs();
      final c = j.com();
      if (c.y > j.peakY) j.peakY = c.y;
    }
    j.lastAngle = angle;

    if (j.faceTimer > 0) {
      j.faceTimer -= h;
    } else {
      j.face = j.airborne
          ? (j.spinDir != 0 ? JumperFace.focused : (j.comVel(h).y < -700 ? JumperFace.scared : JumperFace.neutral))
          : JumperFace.neutral;
    }
    if (!j.partAttached('HEAD')) j.face = JumperFace.dead;

    if (j.airborne) j.airSteps++;
    // Justo después de despegar la lona aún sube con el cuerpo: no cuenta como aterrizaje
    if (j.touchedThisStep && !(j.airborne && j.airSteps < 14)) {
      j.contactSteps++;
      j.noContactSteps = 0;
      if (j.airborne) {
        j.airborne = false;
        _onLanding(j, h);
      } else if (j.contactSteps > 100) {
        // Se quedó tirado en la lona: rebote de rescate
        _launch(j, h, math.min(j.apexTarget, 260));
      }
    } else {
      j.noContactSteps++;
      if (!j.airborne && j.noContactSteps > 3) {
        j.airborne = true;
        j.airSteps = 0;
        final v = j.comVel(h);
        if (v.y > 0 && bed.contains(j.com().x)) _launch(j, h, j.apexTarget);
        j.angAccum = 0;
        j.extendedRot = 0;
        j.firstContactKind = null;
        j.peakY = -double.infinity;
      }
    }

    // Fuera de la cama
    final c = j.com();
    if (!j.off && !bed.contains(c.x) && c.y < kBedY - 40 && j.airborne) {
      j.off = true;
      j.offTimer = 0;
      if (j.isPlayer) {
        stats.outs++;
        combo = 0;
        events.add(TrampEvent('out', j, c.x, c.y + 60, text: '¡Fuera de la cama!'));
      } else if (clock - j.lastPushedByPlayer < 4) {
        stats.knockouts++;
        _addScore(200);
        events.add(TrampEvent('knockout', j, c.x, c.y + 60, text: '¡Lo sacaste!', points: 200));
      }
    }
    if (j.off) {
      j.offTimer += h;
      if (j.offTimer > 1.6) _respawn(j);
    }
  }

  void _launch(Jumper j, double h, double apex) {
    final c = j.com();
    final v = j.comVel(h);
    final targetVy = apex > c.y + 20 ? math.sqrt(2 * kGravity * (apex - c.y)) : 200.0;
    // Hacia el centro para no salir volando de la cama
    final targetVx = v.x * 0.4 - (c.x - j.homeX) * 1.1;
    j.addVelocity(targetVx - v.x, targetVy - v.y, h);
    j.airborne = true;
    j.airSteps = 0;
    j.contactSteps = 0;
    j.noContactSteps = 4;
    j.angAccum = 0;
    j.extendedRot = 0;
    j.firstContactKind = null;
    j.peakY = -double.infinity;
    events.add(TrampEvent('bounce', j, c.x, c.y));
  }

  void _respawn(Jumper j) {
    if (j.isPlayer) {
      _placePlayerOnTower();
      return;
    }
    final x = j.homeX + rng.nextDouble() * 60 - 30;
    final c = j.com();
    j.translate(x - c.x, 800 - c.y);
    for (final p in j.points) {
      p.px = p.x;
      p.py = p.y;
    }
    for (final part in j.parts.values) {
      part.attached = true;
    }
    j.off = false;
    j.airborne = true;
    j.apexTarget = 300 + rng.nextDouble() * 220;
  }

  void _onLanding(Jumper j, double h) {
    final c = j.com();
    final v = j.comVel(h);
    j.lastImpactSpeed = -v.y;
    final kind = j.firstContactKind ?? 'pelvis';
    j.firstContactKind = null;
    const feetKinds = {'LF', 'RF', 'LK', 'RK'};
    const seatKinds = {'pelvis', 'LP', 'RP', 'LLR', 'RLR', 'LH', 'RH', 'LF', 'RF', 'LK', 'RK'};
    LandingKind landing;
    if (feetKinds.contains(kind) && j.upright) {
      landing = LandingKind.feet;
    } else if (seatKinds.contains(kind)) {
      landing = LandingKind.seat;
    } else {
      landing = LandingKind.crash;
    }

    final flips = ((j.angAccum.abs() + 0.87) / (2 * math.pi)).floor();
    final layout = j.angAccum.abs() > 0.1 && j.extendedRot / j.angAccum.abs() > 0.6;
    final heightM = ((j.peakY - kBedY) / kUnitsPerMeter).clamp(0.0, 999.0);

    // Ajuste de la altura del próximo bote
    if (landing == LandingKind.feet) {
      j.apexTarget = math.min(kMaxApex, math.max(j.apexTarget, j.peakY) + 25);
    } else if (landing == LandingKind.seat) {
      j.apexTarget = math.max(260, j.apexTarget * 0.8);
    } else {
      j.apexTarget = math.max(220, j.apexTarget * 0.6);
    }
    if (!j.isPlayer) j.apexTarget = 280 + rng.nextDouble() * 260;

    // Piezas que salen volando si el golpe es fuerte
    int lost = 0;
    if (landing == LandingKind.crash && j.lastImpactSpeed > 450) {
      final keys = <String>[];
      if (kind == 'head' || kind == 'neck') keys.add('HEAD');
      final limbs = ['LA', 'RA', 'LL', 'RL']..shuffle(rng);
      final extra = j.lastImpactSpeed > 950 ? 2 : (j.lastImpactSpeed > 700 ? 1 : 0);
      keys.addAll(limbs.take(extra + (keys.isEmpty ? 1 : 0)));
      for (final k in keys) {
        final part = j.parts[k]!;
        final ox = part.root.x - c.x, oy = part.root.y - c.y;
        final od = math.sqrt(ox * ox + oy * oy).clamp(1.0, double.infinity);
        j.detach(k, ox / od * 380 + (rng.nextDouble() - 0.5) * 200, 450 + rng.nextDouble() * 250, h);
        lost++;
      }
      if (lost > 0) {
        events.add(TrampEvent('detach', j, c.x, c.y + 40, text: lost > 1 ? '¡Se desarmó!' : '¡Pop!'));
      }
    }

    if (landing == LandingKind.feet) {
      j.face = JumperFace.happy;
      j.faceTimer = 0.5;
    } else if (landing == LandingKind.crash) {
      j.face = JumperFace.scared;
      j.faceTimer = 0.8;
    }

    events.add(TrampEvent('land', j, c.x, c.y, text: landing.name));

    if (!j.isPlayer) return;

    stats.landings++;
    if (heightM > stats.maxHeight) stats.maxHeight = heightM;
    stats.partsLost += lost;
    if (landing == LandingKind.feet) stats.clean++;
    if (landing == LandingKind.seat) stats.seats++;
    if (landing == LandingKind.crash) stats.crashes++;

    if (flips >= 1) {
      final name = trickName(flips, layout);
      double pts = 100.0 * flips * flips * (layout ? 1.5 : 1);
      String label;
      if (landing == LandingKind.feet) {
        combo++;
        pts *= 1 + 0.25 * (combo - 1);
        label = combo > 1 ? '$name  x$combo' : name;
        stats.tricks.add(name);
        stats.totalFlips += flips;
        if (flips > stats.maxFlips) stats.maxFlips = flips;
        if (layout) stats.layoutTricks++;
        if (combo > stats.bestCombo) stats.bestCombo = combo;
      } else if (landing == LandingKind.seat) {
        combo = 0;
        pts *= 0.4;
        label = '$name (de culo)';
        stats.tricks.add(name);
        if (flips > stats.maxFlips) stats.maxFlips = flips;
      } else {
        combo = 0;
        pts = 25;
        label = '$name fallido';
      }
      final ip = pts.round();
      _addScore(ip);
      events.add(TrampEvent('trick', j, c.x, c.y + 90, text: label, points: ip));
    } else if (landing == LandingKind.crash) {
      combo = 0;
      _addScore(25);
      events.add(TrampEvent('trick', j, c.x, c.y + 90, text: '¡Plaf!', points: 25));
    } else if (landing == LandingKind.seat) {
      combo = 0;
    }
  }

  void _updateAi(double h) {
    for (final b in bots) {
      if (!b.simulated) continue;
      if (!b.airborne) {
        b.tuck = false;
        b.spinDir = 0;
        b.aiTimer = 0.15 + rng.nextDouble() * 0.2;
        continue;
      }
      b.aiTimer -= h;
      if (b.aiTimer <= 0) {
        if (b.tuck || b.spinDir != 0) {
          b.tuck = false;
          b.spinDir = 0;
          b.stretchTimer = 0.3;
          b.aiTimer = 10; // un truco por salto
        } else if (rng.nextDouble() < 0.6 && b.comVel(h).y > 0) {
          b.tuck = rng.nextDouble() < 0.7;
          b.spinDir = rng.nextBool() ? 1 : -1;
          b.aiTimer = 0.35 + rng.nextDouble() * 0.5;
        } else {
          b.aiTimer = 10;
        }
      }
    }
  }

  void _updateReach() {
    final j = player;
    j.reachHand = null;
    if (!j.simulated || j.tuck) return;
    double best = 140;
    for (final it in items) {
      if (!it.alive) continue;
      final iy = it.y(clock);
      for (final hand in [j.lh, j.rh]) {
        final key = identical(hand, j.lh) ? 'LA' : 'RA';
        if (!j.partAttached(key)) continue;
        final sh = identical(hand, j.lh) ? j.ls : j.rs;
        final d = dist2(sh.x, sh.y, it.x, iy);
        if (d < best) {
          best = d;
          j.reachHand = hand;
          // No más lejos que el largo del brazo estirado
          final k = math.min(1.0, 110 / d);
          j.reachX = sh.x + (it.x - sh.x) * k;
          j.reachY = sh.y + (iy - sh.y) * k;
        }
      }
    }
  }

  void _updateItems(double h) {
    for (int i = 0; i < items.length; i++) {
      final it = items[i];
      if (!it.alive) {
        it.respawn -= h;
        if (it.respawn <= 0) items[i] = _newItem();
        continue;
      }
      if (!player.simulated) continue;
      final iy = it.y(clock);
      for (final p in [player.lh, player.rh, player.head, player.chest, player.lf, player.rf]) {
        if (!player.isAttachedPoint(p)) continue;
        if (dist2(p.x, p.y, it.x, iy) < it.r + 16) {
          it.alive = false;
          it.respawn = 2.5;
          if (it.kind == 'star') {
            stats.stars++;
          } else {
            stats.balloons++;
          }
          _addScore(it.points);
          events.add(TrampEvent(it.kind, player, it.x, iy, text: '+${it.points}', points: it.points));
          break;
        }
      }
    }
  }
}

// =========================================================
//  Jueces
// =========================================================

class JudgeVerdict {
  final String name;
  final String emoji;
  final String role;
  final double score;
  final String comment;
  JudgeVerdict(this.name, this.emoji, this.role, this.score, this.comment);
}

double _judgeRound(double v, math.Random rng) {
  v += (rng.nextDouble() - 0.5) * 0.6;
  return ((v.clamp(0.0, 10.0)) * 2).round() / 2;
}

List<JudgeVerdict> judgeRun(RunStats s, int score, math.Random rng) {
  final out = <JudgeVerdict>[];

  // 1. Técnica
  double tech;
  if (s.landings == 0) {
    tech = 1.5;
  } else {
    tech = 3 + 7 * s.clean / s.landings - 0.8 * s.outs - 0.2 * s.crashes;
  }
  tech = _judgeRound(tech, rng);
  out.add(JudgeVerdict('Doña Técnica', '🧐', 'Aterrizajes', tech,
      tech >= 8 ? 'Aterrizajes impecables. Casi sonrío.'
          : tech >= 5 ? 'Correcto, pero esos pies... ¡juntos!'
          : '¿Eso fue un aterrizaje o un accidente?'));

  // 2. Riesgo
  double risk = 1.5 + s.maxFlips * 1.6 + s.layoutTricks * 0.5 + s.maxHeight / 8;
  risk = _judgeRound(risk, rng);
  out.add(JudgeVerdict('Capitán Riesgo', '😎', 'Dificultad', risk,
      risk >= 8 ? '¡ESO es volar! Me ha temblado el bigote.'
          : risk >= 5 ? 'Bien... pero yo quiero un triple.'
          : 'Mi abuela gira más que tú.'));

  // 3. Show
  double show = 3 + s.crashes * 0.9 + s.partsLost * 0.5 + s.pushes * 0.7 + s.knockouts * 1.5 +
      (s.maxFlips >= 3 ? 1 : 0);
  show = _judgeRound(show, rng);
  out.add(JudgeVerdict('Chispa', '🤡', 'Espectáculo', show,
      s.partsLost > 0 && show >= 7 ? '¡Se le salió una pieza! ¡Otra vez, otra vez!'
          : s.knockouts > 0 ? '¡Tiraste a un compañero! Maravilloso caos.'
          : show >= 6 ? '¡Me divertí muchísimo!'
          : 'Un poco sosito... ¡empuja a alguien!'));

  // 4. Variedad
  double variety = 2 + s.tricks.length * 1.4 + (s.stars + s.balloons) * 0.25 + s.bestCombo * 0.3;
  variety = _judgeRound(variety, rng);
  out.add(JudgeVerdict('Profe Plastilina', '🎨', 'Variedad', variety,
      variety >= 8 ? 'Qué repertorio. Una obra de arte moldeable.'
          : variety >= 5 ? 'Buen material, falta mezclar colores.'
          : 'Siempre lo mismo... ¡prueba estirado!'));

  // 5. El abuelo (imprevisible)
  double grandpa = 4.5 + rng.nextDouble() * 3.5 + (score > 1500 ? 1 : 0) + (s.stars > 5 ? 0.5 : 0);
  grandpa = _judgeRound(grandpa, rng);
  const grandpaLines = [
    'En mis tiempos saltábamos sin trampolín.',
    '¿Ya empezó? Me quedé dormido.',
    'Me recuerda a mi boda. Un desastre precioso.',
    'Le pongo nota por el color de la camiseta.',
    '¡Bravo! ...¿quién era?',
  ];
  out.add(JudgeVerdict('El Abuelo', '👴', 'Criterio propio', grandpa,
      grandpaLines[rng.nextInt(grandpaLines.length)]));

  return out;
}
