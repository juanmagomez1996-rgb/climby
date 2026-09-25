import 'package:flutter/material.dart';

import 'game.dart';
import 'gfx.dart';
import 'prefs.dart';
import 'sfx.dart';

const _display = TextStyle(fontFamily: kDisplay, color: Pal.ink, height: 1.05, shadows: [
  Shadow(color: Pal.dark, offset: Offset(0, 3), blurRadius: 0),
  Shadow(color: Pal.dark, offset: Offset(0, 0), blurRadius: 4),
]);
const _body = TextStyle(fontFamily: kBody, color: Pal.ink, fontSize: 16, height: 1.35);

/// Botón de plastilina con rebote al pulsar.
class ClayButton extends StatefulWidget {
  final String label;
  final String image;
  final VoidCallback onTap;
  final double width;
  const ClayButton(this.label, {super.key, required this.onTap, this.image = 'btn_gold', this.width = 260});

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
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
            height: widget.width * .42,
            child: Stack(alignment: Alignment.center, children: [
              Positioned.fill(child: Image.asset('assets/images/${widget.image}.webp', fit: BoxFit.fill)),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 18, right: 18),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(widget.label, style: _display.copyWith(fontSize: 26)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  final Widget child;
  const _Scrim({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xB31A1424),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SafeArea(child: Center(child: SingleChildScrollView(child: child))),
      );
}

class _Toggle extends StatelessWidget {
  final IconData on, off;
  final bool value;
  final String label;
  final ValueChanged<bool> onChanged;
  const _Toggle({required this.on, required this.off, required this.value, required this.label, required this.onChanged});
  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        label: label,
        child: InkResponse(
          onTap: () => onChanged(!value),
          radius: 30,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF4A3B60),
              shape: BoxShape.circle,
              border: Border.all(color: Pal.dark, width: 3),
              boxShadow: const [BoxShadow(color: Color(0x77000000), offset: Offset(0, 4))],
            ),
            child: Icon(value ? on : off, color: value ? Pal.ink : Pal.dim),
          ),
        ),
      );
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
    return SafeArea(
      child: LayoutBuilder(builder: (context, box) {
        return Column(children: [
          SizedBox(height: box.maxHeight * .02),
          Image.asset('assets/images/logo.webp', width: box.maxWidth * .74),
          const Spacer(),
          if (_help)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xEE2E2340),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Pal.dark, width: 3),
              ),
              child: const Text(
                'Tu tele pilla canales de otras dimensiones. Cada canal es un reto de unos segundos: '
                'haz lo que grite la pantalla.\n\n'
                '• Toca, arrastra o gira el dedo según el canal.\n'
                '• Tienes 4 vidas.\n'
                '• Cada 5 canales todo va más rápido.\n'
                '• Cada 10 canales aparece un jefe (y si lo vences, recuperas una vida).',
                style: _body,
              ),
            ),
          const SizedBox(height: 14),
          ClayButton('ENCENDER LA TELE', onTap: widget.game.startRun, width: 290),
          const SizedBox(height: 10),
          Text('Récord: ${Prefs.best} canales', style: _body.copyWith(color: Pal.gold, fontSize: 18)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _Toggle(
                on: Icons.volume_up_rounded,
                off: Icons.volume_off_rounded,
                label: 'Sonido',
                value: Prefs.sound,
                onChanged: (v) => setState(() => Prefs.setSound(v))),
            const SizedBox(width: 16),
            _Toggle(
                on: Icons.vibration_rounded,
                off: Icons.mobile_off_rounded,
                label: 'Vibración',
                value: Prefs.vibration,
                onChanged: (v) => setState(() => Prefs.setVibration(v))),
            const SizedBox(width: 16),
            _Toggle(
                on: Icons.help_rounded,
                off: Icons.help_outline_rounded,
                label: 'Cómo se juega',
                value: _help,
                onChanged: (v) => setState(() => _help = v)),
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
          Text('PAUSA', style: _display.copyWith(fontSize: 54, color: Pal.gold)),
          const SizedBox(height: 24),
          ClayButton('SEGUIR', image: 'btn_teal', onTap: game.resume),
          const SizedBox(height: 12),
          ClayButton('APAGAR LA TELE', image: 'btn_pink', onTap: game.toMenu),
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
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('FIN DE LA EMISIÓN', style: _body.copyWith(color: Pal.teal, fontSize: 18, letterSpacing: 2)),
        const SizedBox(height: 6),
        Text(r.record ? '¡Nuevo récord de audiencia!' : 'Se acabó la señal',
            textAlign: TextAlign.center, style: _display.copyWith(fontSize: 34, color: Pal.gold)),
        const SizedBox(height: 8),
        Text('${r.score}', style: _display.copyWith(fontSize: 96, color: Pal.lime)),
        Text('canales superados · llegaste al canal ${r.channel}', textAlign: TextAlign.center, style: _body),
        const SizedBox(height: 4),
        Text('Récord: ${Prefs.best}', style: _body.copyWith(color: Pal.gold, fontWeight: FontWeight.w700)),
        const SizedBox(height: 22),
        ClayButton('VOLVER A ZAPEAR', onTap: game.startRun, width: 290),
        const SizedBox(height: 10),
        ClayButton('MENÚ', image: 'btn_teal', onTap: game.toMenu, width: 200),
      ]),
    );
  }
}
