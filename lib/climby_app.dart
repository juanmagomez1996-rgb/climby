import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'climby_game.dart';
import 'level.dart';
import 'storage.dart';
import 'audio.dart';
import 'render.dart';

class ClimbyApp extends StatelessWidget {
  const ClimbyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climby',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF4EAD5),
        fontFamily: 'Georgia',
      ),
      home: const MenuScreen(),
    );
  }
}

// ============ EPIC SPLASH ============
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..forward();
    Future.delayed(const Duration(milliseconds: 3400), () {
      if (!mounted) return;
      Navigator.pushReplacement(context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) => const MenuScreen(),
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
          ));
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EAD5),
      body: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) {
          return CustomPaint(
            size: Size(MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height),
            painter: _SplashPainter(progress: _ctl.value),
          );
        },
      ),
    );
  }
}

class _SplashPainter extends CustomPainter {
  final double progress;
  _SplashPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sky gradient (animated)
    final paint = Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [
        Color.lerp(const Color(0xFFD6E4EC), const Color(0xFFFFE5B4), progress)!,
        Color.lerp(const Color(0xFFF4EAD5), const Color(0xFFFFD89B), progress)!,
        const Color(0xFFD8C89A),
      ],
    ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), paint);

    // Mountains in distance (parallax)
    final mt1 = Path()
      ..moveTo(0, h * 0.6)
      ..lineTo(w * 0.2, h * 0.45)
      ..lineTo(w * 0.35, h * 0.55)
      ..lineTo(w * 0.55, h * 0.4)
      ..lineTo(w * 0.7, h * 0.5)
      ..lineTo(w, h * 0.42)
      ..lineTo(w, h)..lineTo(0, h)..close();
    canvas.drawPath(mt1, Paint()..color = const Color(0xFF8B7355).withOpacity(0.5));

    // CLIMBY title with bouncy elastic entrance
    final titleP = math.min(1.0, progress * 1.8);
    final titleScale = Curves.elasticOut.transform(titleP);
    final titleY = h * 0.32 + (1 - titleP) * 100;
    canvas.save();
    canvas.translate(w / 2, titleY);
    canvas.scale(titleScale);
    _drawTitle(canvas);
    canvas.restore();

    // Subtitle slides in
    if (progress > 0.4) {
      final p = ((progress - 0.4) / 0.3).clamp(0.0, 1.0);
      final slidIn = (1 - Curves.easeOutCubic.transform(p)) * 50;
      final tp = TextPainter(
        text: const TextSpan(text: '— escalada de plastilina —',
          style: TextStyle(
              fontSize: 16, fontStyle: FontStyle.italic,
              color: Color(0xFF3A2E1F))),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.48 - slidIn));
    }

    // Holds falling from top
    if (progress > 0.2) {
      final colors = [
        const Color(0xFFE85D3C), const Color(0xFFF2B134),
        const Color(0xFF5A8A3A), const Color(0xFF4A7BA6),
        const Color(0xFFFF7EB9), const Color(0xFF8B5FBF),
      ];
      for (int i = 0; i < 8; i++) {
        final delay = i * 0.05;
        final p = ((progress - 0.2 - delay) * 1.5).clamp(0.0, 1.0);
        if (p <= 0) continue;
        final startX = w * (0.1 + i * 0.11);
        final endY = h * (0.55 + (i % 3) * 0.05);
        final y = -40 + p * (endY + 40);
        final rotation = p * (i.isEven ? 4.0 : -4.0);
        canvas.save();
        canvas.translate(startX, y);
        canvas.rotate(rotation);
        final r = 14.0 + (i % 3) * 4;
        canvas.drawCircle(Offset.zero, r,
            Paint()..color = colors[i % colors.length]);
        canvas.drawCircle(Offset.zero, r,
            Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2.5);
        canvas.restore();
      }
    }

    // Character climbing in from bottom
    if (progress > 0.5) {
      final p = ((progress - 0.5) / 0.4).clamp(0.0, 1.0);
      final cp = Curves.easeOutBack.transform(p);
      final charY = h * 1.1 - cp * h * 0.45;
      final charX = w / 2;
      _drawSplashCharacter(canvas, charX, charY, progress);
    }

    // Sparkles when fully revealed
    if (progress > 0.85) {
      final p = ((progress - 0.85) / 0.15).clamp(0.0, 1.0);
      for (int i = 0; i < 12; i++) {
        final ang = (i / 12) * math.pi * 2;
        final r = 100 + p * 80;
        final sx = w / 2 + math.cos(ang) * r;
        final sy = h * 0.32 + math.sin(ang) * r * 0.5;
        final size = 4 + math.sin(progress * 20 + i) * 2;
        canvas.drawCircle(Offset(sx, sy), size,
            Paint()..color = const Color(0xFFF2B134).withOpacity(p * 0.8));
      }
    }
  }

  void _drawTitle(Canvas canvas) {
    final layouts = <TextPainter>[];
    final colors = [const Color(0xFFE85D3C), const Color(0xFFF2B134), const Color(0xFF3A2E1F)];
    final offsets = [const Offset(8, 8), const Offset(4, 4), Offset.zero];
    for (int i = 0; i < 3; i++) {
      final tp = TextPainter(
        text: TextSpan(text: 'CLIMBY',
          style: TextStyle(
            fontSize: 84, fontWeight: FontWeight.w900,
            color: colors[i], letterSpacing: -2,
          )),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      layouts.add(tp);
    }
    for (int i = 0; i < 3; i++) {
      layouts[i].paint(canvas,
        Offset(offsets[i].dx - layouts[i].width / 2, offsets[i].dy - layouts[i].height / 2));
    }
  }

  void _drawSplashCharacter(Canvas canvas, double cx, double cy, double progress) {
    final cust = Prefs.customization;
    // Animated hands climbing motion
    final wave = math.sin(progress * 8) * 0.5 + 0.5;
    final handY = -wave * 12;
    final headPos = Offset(cx, cy - 90);
    final chestPos = Offset(cx, cy - 50);
    final lsPos = Offset(cx - 22, cy - 50);
    final rsPos = Offset(cx + 22, cy - 50);
    final lpPos = Offset(cx - 18, cy + 0);
    final rpPos = Offset(cx + 18, cy + 0);
    final lhPos = Offset(cx - 60, cy - 70 + handY);
    final rhPos = Offset(cx + 60, cy - 70 + handY * 1.2);
    final lePos = Offset(cx - 42, cy - 50);
    final rePos = Offset(cx + 42, cy - 50);
    final lfPos = Offset(cx - 30, cy + 78);
    final rfPos = Offset(cx + 30, cy + 78);
    final lkPos = Offset(cx - 22, cy + 38);
    final rkPos = Offset(cx + 22, cy + 38);
    GameRenderer.drawCharacterAt(canvas,
      headPos: headPos, chestPos: chestPos,
      lsPos: lsPos, rsPos: rsPos,
      lpPos: lpPos, rpPos: rpPos,
      lhPos: lhPos, rhPos: rhPos,
      lePos: lePos, rePos: rePos,
      lfPos: lfPos, rfPos: rfPos,
      lkPos: lkPos, rkPos: rkPos,
      cust: cust, headR: 24,
      faceState: FaceState.happy,
    );
  }

  @override
  bool shouldRepaint(_SplashPainter old) => old.progress != progress;
}

// ============ MENU ============
class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  void _go(BuildContext context, Level level, String mode) {
    Navigator.push(context,
      MaterialPageRoute(builder: (_) => PregameScreen(level: level, mode: mode)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/ui/logo_climby.png',
                        width: 280, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _TitleStack(size: 64)),
                    const SizedBox(height: 6),
                    const Text('— escalada de plastilina —',
                        style: TextStyle(fontSize: 14,
                            fontStyle: FontStyle.italic, color: Color(0xFF3A2E1F))),
                    const SizedBox(height: 24),
                    _Btn(label: 'JUGAR', primary: true, onTap: () {
                      audio.click();
                      _go(context, Level.procedural(), 'normal');
                    }),
                    const SizedBox(height: 8),
                    _Btn(label: '⚡ BOSS CLIMB',
                      background: const Color(0xFF8B5FBF), textColor: Colors.white,
                      onTap: () {
                        audio.click();
                        _go(context, Level.boss(), 'boss');
                      }),
                    const SizedBox(height: 8),
                    _Btn(label: '📅 RETO DIARIO', onTap: () {
                      audio.click();
                      _go(context, Level.procedural(dailySeed()), 'daily');
                    }),
                    const SizedBox(height: 8),
                    _Btn(label: 'PERSONALIZAR',
                      background: const Color(0xFFF2B134),
                      onTap: () {
                        audio.click();
                        Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CustomizeScreen()))
                          .then((_) => setState(() {}));
                      }),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16, right: 16,
              child: Row(
                children: [
                  _MiniBtn(
                    label: Prefs.musicEnabled ? '🎵' : '🎵̶',
                    opacity: Prefs.musicEnabled ? 1.0 : 0.4,
                    onTap: () async {
                      await audio.setMusicEnabled(!Prefs.musicEnabled);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),
                  _MiniBtn(
                    label: Prefs.sfxEnabled ? '🔊' : '🔇',
                    onTap: () async {
                      await audio.setSfxEnabled(!Prefs.sfxEnabled);
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleStack extends StatelessWidget {
  final double size;
  const _TitleStack({required this.size});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Transform.translate(offset: Offset(size * 0.09, size * 0.09),
          child: Text('CLIMBY', style: TextStyle(
              fontSize: size, fontWeight: FontWeight.w900,
              color: const Color(0xFFE85D3C), letterSpacing: -2))),
        Transform.translate(offset: Offset(size * 0.046, size * 0.046),
          child: Text('CLIMBY', style: TextStyle(
              fontSize: size, fontWeight: FontWeight.w900,
              color: const Color(0xFFF2B134), letterSpacing: -2))),
        Text('CLIMBY', style: TextStyle(
            fontSize: size, fontWeight: FontWeight.w900,
            color: const Color(0xFF3A2E1F), letterSpacing: -2)),
      ],
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final bool primary;
  final Color? background;
  final Color? textColor;
  final VoidCallback onTap;
  const _Btn({required this.label, this.primary = false,
    this.background, this.textColor, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final bg = primary ? const Color(0xFFE85D3C) : (background ?? const Color(0xFFF4EAD5));
    Color tc;
    if (textColor != null) tc = textColor!;
    else if (primary) tc = Colors.white;
    else if (background == const Color(0xFFF2B134)) tc = const Color(0xFF3A2E1F);
    else if (background != null) tc = Colors.white;
    else tc = const Color(0xFF3A2E1F);
    return SizedBox(
      width: 320,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: const Color(0xFF3A2E1F), width: 3),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0xFF3A2E1F), offset: Offset(4, 4))],
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: tc)),
        ),
      ),
    );
  }
}

class _MiniBtn extends StatelessWidget {
  final String label;
  final double opacity;
  final VoidCallback onTap;
  const _MiniBtn({required this.label, this.opacity = 1.0, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: opacity,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF4EAD5),
            border: Border.all(color: const Color(0xFF3A2E1F), width: 2.5),
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [BoxShadow(color: Color(0xFF3A2E1F), offset: Offset(2, 2))],
          ),
          child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ============ PREGAME WITH ANIMATED TUTORIAL ============
class PregameScreen extends StatefulWidget {
  final Level level;
  final String mode;
  const PregameScreen({super.key, required this.level, required this.mode});
  @override
  State<PregameScreen> createState() => _PregameScreenState();
}

class _PregameScreenState extends State<PregameScreen>
    with SingleTickerProviderStateMixin {
  bool skipTips = false;
  int tutorialStep = 0;
  late AnimationController _animCtl;

  static const tutSteps = [
    {'caption': '🟠 La muñequera naranja es tu mano izquierda. Arrástrala para moverla.', 'limb': 'LH'},
    {'caption': '🔵 La muñequera azul es tu mano derecha.', 'limb': 'RH'},
    {'caption': '🟢 El calcetín verde es tu pie izquierdo. Los pies llegan más lejos.', 'limb': 'LF'},
    {'caption': '🟡 El calcetín amarillo es tu pie derecho. Si una extremidad brilla, va a soltarse.', 'limb': 'RF'},
  ];

  @override
  void initState() {
    super.initState();
    skipTips = Prefs.skipTips;
    _animCtl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (!mounted) return;
          setState(() => tutorialStep = (tutorialStep + 1) % tutSteps.length);
          _animCtl.forward(from: 0);
        }
      })
      ..forward();
  }

  @override
  void dispose() { _animCtl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hasPlayed = Prefs.playedModes[widget.mode] ?? false;
    String modeBadge;
    Color modeColor;
    if (widget.mode == 'boss') {
      modeBadge = '⚡ BOSS CLIMB'; modeColor = const Color(0xFF8B5FBF);
    } else if (widget.mode == 'daily') {
      modeBadge = '📅 RETO DIARIO'; modeColor = const Color(0xFF4A7BA6);
    } else {
      modeBadge = 'JUGAR'; modeColor = const Color(0xFFE85D3C);
    }
    final showAnimated = !hasPlayed && widget.mode == 'normal';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFF3A2E1F), width: 3),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [BoxShadow(color: Color(0xFF3A2E1F), offset: Offset(6, 6))],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: modeColor,
                      border: Border.all(color: const Color(0xFF3A2E1F), width: 2.5),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [BoxShadow(color: Color(0xFF3A2E1F), offset: Offset(2, 2))],
                    ),
                    child: Text(modeBadge, style: const TextStyle(
                            color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w900, letterSpacing: 2)),
                  ),
                  const SizedBox(height: 14),
                  Text(showAnimated ? 'Aprende a escalar'
                          : (hasPlayed ? '💡 Consejo' : 'Cómo jugar'),
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 14),
                  if (showAnimated) _buildAnimatedTutorial()
                  else if (!hasPlayed) _buildStaticTutorial(widget.mode)
                  else _buildTip(),
                  const SizedBox(height: 16),
                  _Btn(label: '▶ EMPEZAR', primary: true, onTap: () async {
                      audio.click();
                      _animCtl.stop();
                      await Prefs.setSkipTips(skipTips);
                      await Prefs.markPlayed(widget.mode);
                      if (!mounted) return;
                      Navigator.pushReplacement(context,
                        MaterialPageRoute(builder: (_) => CountdownScreen(level: widget.level)));
                    }),
                  const SizedBox(height: 8),
                  _Btn(label: '← Volver', onTap: () {
                      audio.click();
                      _animCtl.stop();
                      Navigator.pop(context);
                    }),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => skipTips = !skipTips),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(skipTips ? Icons.check_box : Icons.check_box_outline_blank,
                            size: 18, color: const Color(0xFF3A2E1F)),
                        const SizedBox(width: 6),
                        const Text('No mostrar consejos',
                            style: TextStyle(fontSize: 12, color: Color(0xFF3A2E1F))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTutorial() {
    final step = tutSteps[tutorialStep];
    return Column(
      children: [
        Text('Paso ${tutorialStep + 1} de ${tutSteps.length}',
            style: const TextStyle(fontSize: 11, color: Color(0x993A2E1F),
                fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _animCtl,
          builder: (_, __) {
            return CustomPaint(
              size: const Size(280, 250),
              painter: _CharPainter(
                activeLimb: step['limb']!,
                animValue: _animCtl.value,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(step['caption']!, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3)),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(tutSteps.length, (i) {
            final active = i == tutorialStep;
            return GestureDetector(
              onTap: () {
                _animCtl.stop();
                setState(() => tutorialStep = i);
                _animCtl.forward(from: 0);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 12 : 8,
                height: active ? 12 : 8,
                decoration: BoxDecoration(
                  color: active ? const Color(0xFFE85D3C) : const Color(0x33000000),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF3A2E1F), width: 1.5),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildStaticTutorial(String mode) {
    final rows = mode == 'boss'
        ? [
            _TutRow(color: const Color(0xFFFF5722), icon: '🔥', text: 'Lava sube por debajo. Sigue subiendo.'),
            _TutRow(color: const Color(0xFFD33333), icon: '✕', text: 'Más presas frágiles, móviles y resbaladizas.'),
            _TutRow(color: const Color(0xFF8B5FBF), icon: '⛈', text: 'Tormenta posible: vientos fuertes.'),
          ]
        : mode == 'daily'
            ? [
                _TutRow(color: const Color(0xFF4A7BA6), icon: '📅', text: 'Mismo nivel para todos hoy.'),
                _TutRow(color: const Color(0xFFF2B134), icon: '🏆', text: 'Compite contra tu récord personal.'),
              ]
            : [
                _TutRow(color: const Color(0xFFE85D3C), icon: 'M', text: 'Cada extremidad tiene un color único'),
                _TutRow(color: const Color(0xFF5A8A3A), icon: 'P', text: 'Pies alcanzan más lejos que las manos'),
                _TutRow(color: const Color(0xFFE85D3C), icon: '⚠', text: 'Si brilla y titila, va a soltarse'),
                _TutRow(color: const Color(0xFF222222), icon: '★', text: 'Llega a la línea de META arriba'),
              ];
    return Column(children: rows);
  }

  Widget _buildTip() {
    final tips = [
      '🦵 Tus piernas alcanzan más lejos que tus brazos.',
      '✋ Las manos se cansan rápido. Apóyate en los pies.',
      '⚠️ Con solo 2 puntos de apoyo gastas mucha más energía.',
      '🟡 Las amarillas son medianas, las verdes grandes y seguras.',
      '🔴 Las presas frágiles solo aguantan 2 usos.',
      '🧲 Los imanes (gris) atraen tu mano cuando estás cerca.',
      '💧 Las resbaladizas (celeste) te sueltan en 1 segundo.',
      '⤴ Trampolín (rosa): te impulsa al soltarla.',
      '⬢ Pegajosa (marrón): cansa muy poco, ideal para descansar.',
    ];
    final tip = tips[DateTime.now().millisecondsSinceEpoch % tips.length];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EAD5),
        border: Border.all(color: const Color(0xFF3A2E1F), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(tip, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.4)),
    );
  }
}

class _TutRow extends StatelessWidget {
  final Color color;
  final String icon;
  final String text;
  const _TutRow({required this.color, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4EAD5),
        border: Border.all(color: const Color(0xFF3A2E1F), width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(width: 32, height: 32,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF3A2E1F), width: 2)),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ====== CHARACTER PAINTER (uses shared GameRenderer.drawCharacterAt) ======
class _CharPainter extends CustomPainter {
  final String activeLimb; // 'NONE' for static preview
  final double animValue;
  _CharPainter({required this.activeLimb, this.animValue = 0});

  static const limbColors = {
    'LH': Color(0xFFE85D3C),
    'RH': Color(0xFF4A7BA6),
    'LF': Color(0xFF5A8A3A),
    'RF': Color(0xFFF2B134),
  };

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2 + 10;
    final cust = Prefs.customization;
    final wave = activeLimb != 'NONE' ? (math.sin(animValue * math.pi * 2) + 1) / 2 : 0.0;

    // Default positions
    final positions = <String, Offset>{
      'head': Offset(cx, cy - 78),
      'chest': Offset(cx, cy - 32),
      'LS': Offset(cx - 20, cy - 36),
      'RS': Offset(cx + 20, cy - 36),
      'LP': Offset(cx - 16, cy + 18),
      'RP': Offset(cx + 16, cy + 18),
      'LE': Offset(cx - 42, cy - 16),
      'RE': Offset(cx + 42, cy - 16),
      'LK': Offset(cx - 28, cy + 50),
      'RK': Offset(cx + 28, cy + 50),
      'LH': Offset(cx - 56, cy - 4),
      'RH': Offset(cx + 56, cy - 4),
      'LF': Offset(cx - 32, cy + 88),
      'RF': Offset(cx + 32, cy + 88),
    };

    // Animate active limb
    if (activeLimb == 'LH') {
      positions['LH'] = Offset(cx - 56 - wave * 28, cy - 12 - wave * 22);
    } else if (activeLimb == 'RH') {
      positions['RH'] = Offset(cx + 56 + wave * 28, cy - 12 - wave * 22);
    } else if (activeLimb == 'LF') {
      positions['LF'] = Offset(cx - 32 - wave * 24, cy + 88 - wave * 16);
    } else if (activeLimb == 'RF') {
      positions['RF'] = Offset(cx + 32 + wave * 24, cy + 88 - wave * 16);
    }

    // Pulse + arrow on active limb
    if (activeLimb != 'NONE') {
      final activePos = positions[activeLimb]!;
      final idColor = limbColors[activeLimb]!;
      final pulseR = 32 + wave * 12;
      canvas.drawCircle(activePos, pulseR,
          Paint()..color = idColor.withOpacity(0.15 + wave * 0.15));
      canvas.drawCircle(activePos, pulseR,
          Paint()..color = idColor.withOpacity(0.4 + wave * 0.4)
            ..style = PaintingStyle.stroke..strokeWidth = 2);
      // Arrow
      final isLeft = activeLimb == 'LH' || activeLimb == 'LF';
      final dir = isLeft ? -1 : 1;
      final ax = activePos.dx + dir * (44 + wave * 6);
      final ay = activePos.dy;
      canvas.save();
      canvas.translate(ax, ay);
      if (dir == -1) canvas.scale(-1, 1);
      final arrow = Path()
        ..moveTo(0, 0)..lineTo(-12, -7)..lineTo(-12, -3)
        ..lineTo(-22, -3)..lineTo(-22, 3)..lineTo(-12, 3)
        ..lineTo(-12, 7)..close();
      canvas.drawPath(arrow, Paint()..color = idColor);
      canvas.drawPath(arrow,
          Paint()..color = const Color(0xFF3A2E1F)..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.restore();
    }

    // Use shared renderer
    GameRenderer.drawCharacterAt(canvas,
      headPos: positions['head']!,
      chestPos: positions['chest']!,
      lsPos: positions['LS']!, rsPos: positions['RS']!,
      lpPos: positions['LP']!, rpPos: positions['RP']!,
      lhPos: positions['LH']!, rhPos: positions['RH']!,
      lePos: positions['LE']!, rePos: positions['RE']!,
      lfPos: positions['LF']!, rfPos: positions['RF']!,
      lkPos: positions['LK']!, rkPos: positions['RK']!,
      cust: cust,
      headR: 18,
      faceState: FaceState.happy,
      scale: 0.8,
    );
  }

  @override
  bool shouldRepaint(_CharPainter old) =>
      old.activeLimb != activeLimb || old.animValue != animValue;
}

// ============ COUNTDOWN ============
class CountdownScreen extends StatefulWidget {
  final Level level;
  const CountdownScreen({super.key, required this.level});
  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  int n = 3;
  String? showText;
  @override
  void initState() { super.initState(); _tick(); }
  void _tick() async {
    if (!mounted) return;
    audio.countdown(n);
    setState(() => showText = n == 0 ? '¡YA!' : '$n');
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    if (n == 0) {
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => GameScreen(level: widget.level)));
      return;
    }
    n--;
    _tick();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EAD5),
      body: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.2).animate(anim),
              child: FadeTransition(opacity: anim, child: child)),
          child: Text(showText ?? '', key: ValueKey(showText),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 120, fontWeight: FontWeight.w900,
              color: Color(0xFFE85D3C),
              letterSpacing: -3,
              shadows: [
                Shadow(color: Color(0xFF3A2E1F), offset: Offset(4, 4), blurRadius: 0),
                Shadow(color: Color(0xFF3A2E1F), offset: Offset(-1, -1), blurRadius: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ GAME ============
class GameScreen extends StatefulWidget {
  final Level level;
  const GameScreen({super.key, required this.level});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late ClimbyGame _game;
  @override
  void initState() { super.initState(); _build(); }
  void _build() {
    _game = ClimbyGame();
    _game.loadLevel(widget.level);
    _game.onFell = _showFallDialog;
    _game.onWon = _showWinDialog;
    Future.delayed(const Duration(milliseconds: 100), () => _game.start());
  }
  @override
  void dispose() { audio.stopMusic(); super.dispose(); }
  void _showFallDialog() {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false,
      builder: (ctx) => _ResultDialog(
        title: _game.ballPit?.reason ?? '¡Te caíste!',
        body: 'Llegaste a ${_game.maxHeight.toStringAsFixed(1)}m\nRécord: ${_game.recordHeight.toStringAsFixed(1)}m',
        onRetry: () { Navigator.pop(ctx); setState(_build); },
        onMenu: () {
          Navigator.pop(ctx); audio.stopMusic();
          Navigator.popUntil(context, (r) => r.isFirst);
        },
      ));
  }
  void _showWinDialog() {
    if (!mounted) return;
    showDialog(context: context, barrierDismissible: false,
      builder: (ctx) => _ResultDialog(
        title: '¡Llegaste a la cima! 🎉',
        body: 'Altura final: ${_game.maxHeight.toStringAsFixed(1)}m',
        onRetry: () { Navigator.pop(ctx); setState(_build); },
        onMenu: () {
          Navigator.pop(ctx); audio.stopMusic();
          Navigator.popUntil(context, (r) => r.isFirst);
        },
      ));
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Listener(
            onPointerDown: (e) => _game.handlePointerDown(e.localPosition.dx, e.localPosition.dy),
            onPointerMove: (e) => _game.handlePointerMove(e.localPosition.dx, e.localPosition.dy),
            onPointerUp: (e) => _game.handlePointerUp(),
            onPointerCancel: (e) => _game.handlePointerUp(),
            child: GameWidget(game: _game),
          ),
          Positioned(
            top: 16, right: 16,
            child: SafeArea(
              child: Row(
                children: [
                  _MiniBtn(
                    label: Prefs.musicEnabled ? '🎵' : '🎵̶',
                    opacity: Prefs.musicEnabled ? 1.0 : 0.4,
                    onTap: () async {
                      await audio.setMusicEnabled(!Prefs.musicEnabled);
                      if (Prefs.musicEnabled && _game.started) {
                        if (_game.bossMode) audio.startBossMusic();
                        else audio.startMusic();
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),
                  _MiniBtn(
                    label: Prefs.sfxEnabled ? '🔊' : '🔇',
                    onTap: () async {
                      await audio.setSfxEnabled(!Prefs.sfxEnabled);
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 6),
                  _MiniBtn(label: '↻', onTap: () { audio.click(); setState(_build); }),
                  const SizedBox(width: 6),
                  _MiniBtn(label: '✕', onTap: () {
                      audio.click(); audio.stopMusic();
                      Navigator.popUntil(context, (r) => r.isFirst);
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onRetry;
  final VoidCallback onMenu;
  const _ResultDialog({required this.title, required this.body,
    required this.onRetry, required this.onMenu});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF4EAD5),
          border: Border.all(color: const Color(0xFF3A2E1F), width: 3),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0xFF3A2E1F), offset: Offset(6, 6))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            _Btn(label: 'Reintentar', primary: true, onTap: onRetry),
            const SizedBox(height: 8),
            _Btn(label: 'Menú', onTap: onMenu),
          ],
        ),
      ),
    );
  }
}

// ============ CUSTOMIZE WITH WORKING PREVIEW ============
class CustomizeScreen extends StatefulWidget {
  const CustomizeScreen({super.key});
  @override
  State<CustomizeScreen> createState() => _CustomizeScreenState();
}

class _CustomizeScreenState extends State<CustomizeScreen> {
  final skinColors = const [
    Color(0xFFF4D3A8), Color(0xFFE3B88A), Color(0xFFC69365),
    Color(0xFFA87850), Color(0xFF7D5C3F), Color(0xFF4A3525),
  ];
  final hairColors = const [
    Color(0xFF2A1A0D), Color(0xFF5A3A1A), Color(0xFF8B5A2B),
    Color(0xFFC4A060), Color(0xFFE85D3C), Color(0xFFFF7EB9),
    Color(0xFF8B5FBF), Color(0xFFCCCCCC),
  ];
  final shirtColors = const [
    Color(0xFFD94E7A), Color(0xFFE85D3C), Color(0xFFF2B134),
    Color(0xFF5A8A3A), Color(0xFF4A7BA6), Color(0xFF8B5FBF),
    Color(0xFF222222), Color(0xFFFFFFFF),
  ];
  final shortColors = const [
    Color(0xFF3A3A55), Color(0xFF222222), Color(0xFF5A8A3A),
    Color(0xFF4A7BA6), Color(0xFFA83A5E), Color(0xFF8B5FBF),
  ];
  final shoeColors = const [
    Color(0xFF5A8A3A), Color(0xFFE85D3C), Color(0xFF222222),
    Color(0xFF4A7BA6), Color(0xFFF2B134), Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final c = Prefs.customization;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar', style: TextStyle(color: Color(0xFF3A2E1F))),
        backgroundColor: const Color(0xFFF4EAD5),
        iconTheme: const IconThemeData(color: Color(0xFF3A2E1F)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PREVIEW (now uses _CharPainter with NONE → static character with current customization)
            Center(
              child: Container(
                width: 240, height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4EAD5),
                  border: Border.all(color: const Color(0xFF3A2E1F), width: 3),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [BoxShadow(color: Color(0xFF3A2E1F), offset: Offset(4, 4))],
                ),
                child: CustomPaint(
                  // Force repaint by using Key with hash of all colors
                  key: ValueKey('${c.skin.value}-${c.hair.value}-${c.shirt.value}-${c.shorts.value}-${c.shoes.value}'),
                  painter: _CharPainter(activeLimb: 'NONE'),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _section('Piel', skinColors, c.skin, (col) => setState(() => c.skin = col)),
            _section('Pelo', hairColors, c.hair, (col) => setState(() => c.hair = col)),
            _section('Camiseta', shirtColors, c.shirt, (col) => setState(() => c.shirt = col)),
            _section('Pantalón', shortColors, c.shorts, (col) => setState(() => c.shorts = col)),
            _section('Zapatos', shoeColors, c.shoes, (col) => setState(() => c.shoes = col)),
            const SizedBox(height: 20),
            Center(
              child: _Btn(label: 'Guardar', primary: true, onTap: () async {
                  await Prefs.saveCustomization();
                  if (!mounted) return;
                  Navigator.pop(context);
                }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label, List<Color> colors, Color current, Function(Color) onPick) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: colors.map((col) {
              final active = col.value == current.value;
              return GestureDetector(
                onTap: () { audio.click(); onPick(col); },
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: col, shape: BoxShape.circle,
                    border: Border.all(
                        color: active ? const Color(0xFFE85D3C) : const Color(0xFF3A2E1F),
                        width: active ? 4 : 2),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
