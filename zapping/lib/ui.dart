import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'game.dart';
import 'gfx.dart';
import 'prefs.dart';
import 'sfx.dart';

/// Texto con la fuente de plastilina (los mismos sprites que dentro del juego), con su temblor a 12 fps.
class ClayText extends StatefulWidget {
  final String text;
  final double size;
  final Color color;
  final double? maxWidth;
  final double align;
  const ClayText(this.text, {super.key, this.size = 24, this.color = Pal.ink, this.maxWidth, this.align = .5});

  @override
  State<ClayText> createState() => _ClayTextState();
}

class _ClayTextState extends State<ClayText> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((e) {
      final t = e.inMicroseconds / 1e6;
      // solo repinta cuando cambia el fotograma de 12 fps
      if ((t * 12).floor() != (_t * 12).floor()) setState(() => _t = t);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = Gfx.measure(widget.text, widget.size, maxW: widget.maxWidth);
    return Semantics(
      label: widget.text,
      child: CustomPaint(
        size: Size(widget.maxWidth ?? sz.width, sz.height),
        painter: _ClayTextPainter(widget, _t, sz),
      ),
    );
  }
}

class _ClayTextPainter extends CustomPainter {
  final ClayText w;
  final double t;
  final Size sz;
  _ClayTextPainter(this.w, this.t, this.sz);

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width * w.align;
    Gfx.text(canvas, w.text, x, size.height / 2, w.size,
        color: w.color, maxW: w.maxWidth, align: w.align, t: t, fitW: size.width);
  }

  @override
  bool shouldRepaint(_ClayTextPainter old) => old.t != t || old.w.text != w.text || old.w.color != w.color;
}

/// Botón de plastilina con rebote al pulsar; el texto solo ocupa su cara plana.
class ClayButton extends StatefulWidget {
  final String label;
  final String image;
  final VoidCallback onTap;
  final double width;
  const ClayButton(this.label, {super.key, required this.onTap, this.image = 'btn_gold', this.width = 250});

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.width * kButtonAspect;
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          Sfx.play('click');
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? .92 : 1,
          duration: const Duration(milliseconds: 90),
          child: SizedBox(
            width: widget.width,
            height: h,
            child: Stack(children: [
              Positioned.fill(child: Image.asset('assets/images/${widget.image}.webp', fit: BoxFit.fill)),
              Positioned(
                left: widget.width * kButtonFace.left,
                right: widget.width * (1 - kButtonFace.right),
                top: h * kButtonFace.top,
                bottom: h * (1 - kButtonFace.bottom),
                // margen extra para el temblor de las letras: nunca tocan el borde de la cara
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.width * .02, vertical: h * .03),
                  child: FittedBox(fit: BoxFit.scaleDown, child: ClayText(widget.label, size: 42)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Botón redondo de plastilina con icono (sprite).
class _IconButton extends StatelessWidget {
  final String image;
  final String label;
  final VoidCallback onTap;
  const _IconButton(this.image, {required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: () {
            Sfx.play('click');
            onTap();
          },
          child: Image.asset('assets/images/$image.webp', width: 58, height: 58),
        ),
      );
}

/// Escenario de los menús: se coloca exactamente sobre la tele (mismo encaje que el juego)
/// y escala un diseño fijo de 432x768, así todo cabe igual en cualquier pantalla.
class Stage extends StatelessWidget {
  final Widget child;
  static const Size design = Size(432, 768);
  const Stage({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final safe = MediaQuery.viewPaddingOf(context);
    return LayoutBuilder(builder: (context, box) {
      final r = ZappingGame.stageFor(box.biggest, safe);
      return Stack(children: [
        Positioned.fromRect(
          rect: r,
          child: FittedBox(
            child: SizedBox.fromSize(
              size: design,
              child: MediaQuery.removePadding(
                  context: context, removeTop: true, removeBottom: true, removeLeft: true, removeRight: true, child: child),
            ),
          ),
        ),
      ]);
    });
  }
}

class _Scrim extends StatelessWidget {
  final Widget child;
  const _Scrim({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xB31A1424),
        child: Stage(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(child: SingleChildScrollView(child: child)),
          ),
        ),
      );
}

/// Placa de plastilina (sprite estirado) detrás de un bloque de texto.
/// El relleno sale de la zona segura medida en el sprite (para una placa de ~400x180 el churro
/// del borde ocupa ~36 px de lado y ~28 arriba/abajo); las tarjetas bajas usan [compact].
class _ClayCard extends StatelessWidget {
  final Widget child;
  final bool compact;
  const _ClayCard({required this.child, this.compact = false});
  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _CardPainter(),
        child: Padding(
            padding: compact ? const EdgeInsets.fromLTRB(22, 16, 22, 16) : const EdgeInsets.fromLTRB(40, 32, 40, 32),
            child: child),
      );
}

class _CardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => Gfx.clayPanel(canvas, Offset.zero & size, const Color(0xF22A1F3A));
  @override
  bool shouldRepaint(_CardPainter old) => false;
}

class MenuOverlay extends StatefulWidget {
  final ZappingGame game;
  const MenuOverlay(this.game, {super.key});
  @override
  State<MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<MenuOverlay> {
  bool _help = false;

  @override
  Widget build(BuildContext context) {
    return Stage(
      child: LayoutBuilder(builder: (context, box) {
        return Column(children: [
          SizedBox(height: box.maxHeight * .02),
          Image.asset('assets/images/logo.webp', width: box.maxWidth * (_help ? .5 : .74)),
          const Spacer(),
          if (_help)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _ClayCard(
                child: ClayText(
                  'Tu tele pilla canales de otras dimensiones. Cada canal es un reto de unos segundos: '
                  'haz lo que grite la pantalla.\n'
                  'Tienes 4 vidas. Cada 5 canales todo va más rápido. '
                  'Cada 10 aparece un jefe y, si lo vences, recuperas una vida.',
                  size: 18,
                  maxWidth: box.maxWidth - 120,
                ),
              ),
            ),
          const SizedBox(height: 14),
          ClayButton('ENCENDER LA TELE', onTap: widget.game.startRun, width: 250),
          // «Probar canales» (sandbox) queda oculto por ahora; el código sigue en SandboxOverlay.
          const SizedBox(height: 6),
          ClayText('Récord: ${Prefs.best} canales', size: 22, color: Pal.gold),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _IconButton(Prefs.sound ? 'ico_sound' : 'ico_mute',
                label: 'Sonido', onTap: () => setState(() => Prefs.setSound(!Prefs.sound))),
            const SizedBox(width: 16),
            _IconButton(Prefs.vibration ? 'ico_vibe' : 'ico_novibe',
                label: 'Vibración', onTap: () => setState(() => Prefs.setVibration(!Prefs.vibration))),
            const SizedBox(width: 16),
            _IconButton('ico_help', label: 'Cómo se juega', onTap: () => setState(() => _help = !_help)),
          ]),
          SizedBox(height: box.maxHeight * .04),
        ]);
      }),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  final ZappingGame game;
  const PauseOverlay(this.game, {super.key});
  @override
  Widget build(BuildContext context) => _Scrim(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const ClayText('PAUSA', size: 64, color: Pal.gold),
          const SizedBox(height: 24),
          ClayButton('SEGUIR', image: 'btn_teal', onTap: game.resume, width: 230),
          if (game.practice != null) ...[
            const SizedBox(height: 12),
            ClayButton('LISTA DE CANALES', onTap: game.openSandbox, width: 230),
          ],
          const SizedBox(height: 12),
          ClayButton('SALIR AL MENÚ', image: 'btn_pink', onTap: game.toMenu, width: 230),
        ]),
      );
}

class GameOverOverlay extends StatelessWidget {
  final ZappingGame game;
  const GameOverOverlay(this.game, {super.key});
  @override
  Widget build(BuildContext context) {
    final r = game.lastRun ?? const RunResult(0, 0, false);
    return _Scrim(
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth.clamp(200.0, 420.0);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const ClayText('FIN DE LA EMISIÓN', size: 20, color: Pal.teal),
          const SizedBox(height: 6),
          ClayText(r.record ? '¡Nuevo récord de audiencia!' : 'Se acabó la señal',
              size: 36, color: Pal.gold, maxWidth: w),
          const SizedBox(height: 6),
          ClayText('${r.score}', size: 110, color: Pal.lime),
          ClayText('canales superados. Llegaste al canal ${r.channel}', size: 18, maxWidth: w),
          const SizedBox(height: 4),
          ClayText('Récord: ${Prefs.best}', size: 22, color: Pal.gold),
          const SizedBox(height: 22),
          ClayButton('VOLVER A ZAPEAR', onTap: game.startRun, width: 250),
          const SizedBox(height: 10),
          ClayButton('MENÚ', image: 'btn_teal', onTap: game.toMenu, width: 170),
        ]);
      }),
    );
  }
}


/// Sandbox: lista de todos los canales para probarlos uno a uno.
class SandboxOverlay extends StatelessWidget {
  final ZappingGame game;
  const SandboxOverlay(this.game, {super.key});

  @override
  Widget build(BuildContext context) {
    final names = [for (var i = 0; i < game.channelCount; i++) game.makeChannel(i).name];
    return Container(
      color: const Color(0xE61A1424),
      child: Stage(
        child: LayoutBuilder(builder: (context, box) {
          final w = box.maxWidth.clamp(200.0, 460.0) - 32;
          return Column(children: [
            const SizedBox(height: 12),
            const ClayText('PROBAR CANALES', size: 36, color: Pal.gold),
            ClayText('Vidas infinitas. Usa las flechas para cambiar de canal.', size: 17, maxWidth: w, color: Pal.teal),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: names.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: SizedBox(
                      width: w,
                      child: GestureDetector(
                        onTap: () {
                          Sfx.play('click');
                          game.startPractice(i);
                        },
                        child: _ClayCard(
                          compact: true,
                          child: Row(children: [
                            SizedBox(
                                width: 52,
                                child: ClayText('${i + 1}'.padLeft(2, '0'), size: 26,
                                    color: i == names.length - 1 ? Pal.pink : Pal.lime)),
                            const SizedBox(width: 8),
                            Expanded(child: ClayText(names[i], size: 20, maxWidth: w - 120, align: 0)),
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            ClayButton('VOLVER', image: 'btn_pink', onTap: game.toMenu, width: 170),
            const SizedBox(height: 10),
          ]);
        }),
      ),
    );
  }
}
