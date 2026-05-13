import 'dart:math' as math;

const double kGravity = 1200;
const double kDamping = 0.985;
const int kIterations = 16;
const double kArmReachBase = 168;
const double kLegReachBase = 230;
const double kHoldSnap = 40;
final math.Random kRand = math.Random();

double rnd(double a, double b) => a + kRand.nextDouble() * (b - a);
double dist2(double ax, double ay, double bx, double by) =>
    math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));

enum BodyType { thin, normal, thick }

({double width, double weight, double reach}) bodyMultipliers(BodyType t) {
  switch (t) {
    case BodyType.thin:
      return (width: 0.85, weight: 0.85, reach: 1.1);
    case BodyType.thick:
      return (width: 1.2, weight: 1.25, reach: 0.95);
    case BodyType.normal:
      return (width: 1.0, weight: 1.0, reach: 1.0);
  }
}

class Point {
  double x, y;
  double px, py;
  double fx = 0, fy = 0;
  bool locked = false;
  double lockX = 0, lockY = 0;
  String kind;

  Point(this.x, this.y, this.kind)
      : px = x,
        py = y,
        lockX = x,
        lockY = y;

  void applyForce(double fxIn, double fyIn) {
    fx += fxIn;
    fy += fyIn;
  }

  void integrate(double dt) {
    if (locked) {
      x = lockX;
      y = lockY;
      px = x;
      py = y;
      fx = 0;
      fy = 0;
      return;
    }
    final vx = (x - px) * kDamping;
    final vy = (y - py) * kDamping;
    px = x;
    py = y;
    x += vx + fx * dt * dt;
    y += vy + fy * dt * dt;
    fx = 0;
    fy = 0;
  }
}

class Stick {
  Point p1, p2;
  double length;
  double minLength;
  double maxLength;
  double stiffness;

  Stick(this.p1, this.p2,
      {double? length,
      double? minLength,
      double? maxLength,
      this.stiffness = 1.0})
      : length = length ?? dist2(p1.x, p1.y, p2.x, p2.y),
        minLength = minLength ?? length ?? dist2(p1.x, p1.y, p2.x, p2.y),
        maxLength = maxLength ?? length ?? dist2(p1.x, p1.y, p2.x, p2.y);

  void solve() {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    final d = math.sqrt(dx * dx + dy * dy);
    if (d < 0.0001) return;
    double target = length;
    if (d < minLength) {
      target = minLength;
    } else if (d > maxLength) {
      target = maxLength;
    } else {
      return;
    }
    final diff = (target - d) / d * 0.5 * stiffness;
    final ox = dx * diff;
    final oy = dy * diff;
    if (!p1.locked) {
      p1.x -= ox;
      p1.y -= oy;
    }
    if (!p2.locked) {
      p2.x += ox;
      p2.y += oy;
    }
  }
}

class Character {
  late Point head, neck, chest, pelvis;
  late Point ls, rs, lp, rp;
  late Point lh, rh, le, re;
  late Point lf, rf, lk, rk;
  late List<Point> points;
  late List<Stick> sticks;

  Character(double startX, double startY, BodyType bodyType) {
    final bm = bodyMultipliers(bodyType);
    final w = bm.width;
    head = Point(startX, startY + 68, 'head');
    neck = Point(startX, startY + 42, 'neck');
    chest = Point(startX, startY + 22, 'chest');
    pelvis = Point(startX, startY - 32, 'pelvis');

    ls = Point(startX - 24 * w, startY + 26, 'LS');
    rs = Point(startX + 24 * w, startY + 26, 'RS');
    lp = Point(startX - 20 * w, startY - 32, 'LP');
    rp = Point(startX + 20 * w, startY - 32, 'RP');

    lh = Point(startX - 75, startY + 100, 'LH');
    rh = Point(startX + 75, startY + 100, 'RH');
    le = Point(startX - 55, startY + 62, 'LE');
    re = Point(startX + 55, startY + 62, 'RE');

    lf = Point(startX - 60, startY - 110, 'LF');
    rf = Point(startX + 60, startY - 110, 'RF');
    lk = Point(startX - 42, startY - 68, 'LK');
    rk = Point(startX + 42, startY - 68, 'RK');

    points = [
      head, neck, chest, pelvis,
      ls, rs, lp, rp,
      lh, rh, le, re,
      lf, rf, lk, rk,
    ];

    sticks = [
      Stick(head, neck, length: 25),
      Stick(neck, chest, length: 20),
      Stick(chest, pelvis, length: 54), // longer torso
      Stick(chest, ls, length: 24 * w),
      Stick(chest, rs, length: 24 * w),
      Stick(ls, rs, length: 48 * w), // wider shoulders
      Stick(neck, ls, length: 28),
      Stick(neck, rs, length: 28),
      Stick(pelvis, lp, length: 20 * w),
      Stick(pelvis, rp, length: 20 * w),
      Stick(lp, rp, length: 40 * w), // wider hips
      Stick(ls, rp, length: 78, stiffness: 0.8),
      Stick(rs, lp, length: 78, stiffness: 0.8),
      Stick(ls, lp, length: 58, stiffness: 0.8),
      Stick(rs, rp, length: 58, stiffness: 0.8),
      Stick(ls, le, length: 42), // longer upper arm
      Stick(le, lh, minLength: 36, maxLength: 48, stiffness: 0.95), // longer forearm
      Stick(rs, re, length: 42),
      Stick(re, rh, minLength: 36, maxLength: 48, stiffness: 0.95),
      Stick(lp, lk, length: 42), // longer thigh
      Stick(lk, lf, minLength: 38, maxLength: 50, stiffness: 0.95), // longer shin
      Stick(rp, rk, length: 42),
      Stick(rk, rf, minLength: 38, maxLength: 50, stiffness: 0.95),
    ];
  }

  Point limbByKey(String k) {
    switch (k) {
      case 'LH':
        return lh;
      case 'RH':
        return rh;
      case 'LF':
        return lf;
      case 'RF':
        return rf;
      default:
        return lh;
    }
  }

  Point anchorForLimb(String k) {
    switch (k) {
      case 'LH':
        return ls;
      case 'RH':
        return rs;
      case 'LF':
        return lp;
      case 'RF':
        return rp;
      default:
        return ls;
    }
  }
}
