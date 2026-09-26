import 'package:flutter/material.dart';

import 'audio.dart';
import 'game.dart';
import 'gfx.dart';
import 'life.dart';
import 'prefs.dart';

/// Coloca [child] en un lienzo lógico de 540×960 escalado igual que el juego.
class Stage540 extends StatelessWidget {
  const Stage540({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Center(
        child: FittedBox(fit: BoxFit.contain, child: SizedBox(width: kW, height: kH, child: child)),
      );
}

const _chewy = TextStyle(fontFamily: 'Chewy', color: kInk);
const _hand = TextStyle(fontFamily: 'PatrickHand', color: kInk);

BoxDecoration paperDeco() => BoxDecoration(
      color: kPaper,
      border: Border.all(color: kInk, width: 3),
      borderRadius: const BorderRadius.only(
          topLeft: Radius.elliptical(22, 16), topRight: Radius.elliptical(18, 24), bottomRight: Radius.elliptical(26, 18), bottomLeft: Radius.elliptical(16, 26)),
      boxShadow: const [BoxShadow(color: Color(0x593B2416), offset: Offset(0, 8)), BoxShadow(color: Color(0x59000000), blurRadius: 40, offset: Offset(0, 18))],
    );

/// Botón de plastilina de papel: se hunde al pulsarlo.
class PaperButton extends StatefulWidget {
  const PaperButton(this.label, this.onTap, {super.key, this.big = false, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool big, small;
  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final fs = widget.big ? 40.0 : widget.small ? 22.0 : 30.0;
    return GestureDetector(
      onTapDown: (_) => setState(() => down = true),
      onTapCancel: () => setState(() => down = false),
      onTapUp: (_) {
        setState(() => down = false);
        Audio.play('choose');
        widget.onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        transform: Matrix4.translationValues(0, down ? 4 : 0, 0),
        padding: EdgeInsets.symmetric(horizontal: widget.big ? 44 : widget.small ? 18 : 28, vertical: widget.big ? 12 : widget.small ? 6 : 10),
        decoration: BoxDecoration(
          color: widget.small ? const Color(0xFF8C6A4A) : kAccent,
          border: Border.all(color: kInk, width: 3),
          borderRadius: const BorderRadius.all(Radius.elliptical(18, 14)),
          boxShadow: [BoxShadow(color: kInk, offset: Offset(0, down ? 2 : 6))],
        ),
        child: Text(widget.label, style: _chewy.copyWith(fontSize: fs, color: kCream, letterSpacing: 1)),
      ),
    );
  }
}

// ---------------- Menú ----------------
class MenuOverlay extends StatelessWidget {
  const MenuOverlay(this.game, {super.key});
  final VidaGame game;
  @override
  Widget build(BuildContext context) => Stage540(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 70, 0, 60),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Image.asset('assets/ui/logo.webp', width: 480),
            Column(children: [
              PaperButton('VIVIR', game.play, big: true),
              const SizedBox(height: 12),
              Text(Prefs.best > 0 ? 'Récord: ${Prefs.best} pts · ${Prefs.lives} vidas vividas' : 'Una vida entera en unos minutos.',
                  style: _hand.copyWith(fontSize: 22, color: const Color(0xFFFFF4DC), shadows: const [Shadow(color: Color(0x66000000), offset: Offset(0, 2))])),
              const SizedBox(height: 10),
              Row(mainAxisSize: MainAxisSize.min, children: [
                PaperButton('Caminos', () => showDialog(context: context, builder: (_) => PathsDialog(game.data)), small: true),
                const SizedBox(width: 10),
                PaperButton('Ajustes', () => showDialog(context: context, builder: (_) => const SettingsDialog()), small: true),
              ]),
            ]),
          ]),
        ),
      );
}

// ---------------- HUD (botón de pausa) ----------------
class HudOverlay extends StatelessWidget {
  const HudOverlay(this.game, {super.key});
  final VidaGame game;
  @override
  Widget build(BuildContext context) => Stage540(
        child: Stack(children: [
          Positioned(
            right: 14,
            top: 16,
            child: GestureDetector(
              onTap: game.pause,
              child: Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: kPaper, shape: BoxShape.circle, border: Border.all(color: kInk, width: 3), boxShadow: const [BoxShadow(color: kInk, offset: Offset(0, 4))]),
                child: Text('II', style: _chewy.copyWith(fontSize: 26)),
              ),
            ),
          ),
        ]),
      );
}

// ---------------- Carta de decisión ----------------
class CardOverlay extends StatefulWidget {
  const CardOverlay(this.game, {super.key});
  final VidaGame game;
  @override
  State<CardOverlay> createState() => _CardOverlayState();
}

class _CardOverlayState extends State<CardOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 350))..forward();
  late final Json? ev = widget.game.life?.card;

  @override
  void initState() {
    super.initState();
    widget.game.onUi = () {
      if (mounted) setState(() {});
    };
  }

  @override
  void dispose() {
    widget.game.onUi = null;
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.game, l = g.life, e = ev;
    if (l == null || e == null) return const SizedBox();
    final opts = (e['o'] as List).cast<Json>();
    return Stage540(
      child: Stack(children: [
        Positioned(
          left: 35,
          right: 35,
          top: 104,
          child: AnimatedBuilder(
            animation: _in,
            builder: (_, child) {
              final k = Curves.easeOutBack.transform(_in.value);
              return Opacity(opacity: _in.value, child: Transform.translate(offset: Offset(0, (1 - k) * 40), child: Transform.scale(scale: 0.9 + 0.1 * k, child: child)));
            },
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              decoration: paperDeco(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: kInk, width: 3), borderRadius: BorderRadius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 2,
                      child: Image.asset('assets/ev/${l.cardImg(e)}.webp', fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF3E2C0))),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text('A LOS ${l.age} AÑOS', style: _chewy.copyWith(fontSize: 22, color: kAccent, letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(l.tr(e['q'] as String), style: _hand.copyWith(fontSize: 30, height: 1.1)),
                const SizedBox(height: 12),
                for (var i = 0; i < opts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptButton(l.tr(opts[i]['t'] as String), () => g.choose(i)),
                  ),
                const SizedBox(height: 4),
                Container(
                  height: 10,
                  decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kInk, width: 2), borderRadius: BorderRadius.circular(6)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (1 - g.cardT / 10).clamp(0.0, 1.0),
                    child: const ColoredBox(color: kAccent),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _OptButton extends StatefulWidget {
  const _OptButton(this.text, this.onTap);
  final String text;
  final VoidCallback onTap;
  @override
  State<_OptButton> createState() => _OptButtonState();
}

class _OptButtonState extends State<_OptButton> {
  bool down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => widget.onTap(),
        child: Container(
          transform: Matrix4.translationValues(0, down ? 3 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: down ? const Color(0xFFFFE8B8) : Colors.white,
            border: Border.all(color: kInk, width: 3),
            borderRadius: const BorderRadius.all(Radius.elliptical(14, 10)),
            boxShadow: [BoxShadow(color: kInk, offset: Offset(0, down ? 1 : 4))],
          ),
          child: Text(widget.text, style: _hand.copyWith(fontSize: 26)),
        ),
      );
}

// ---------------- Pausa ----------------
class PauseOverlay extends StatelessWidget {
  const PauseOverlay(this.game, {super.key});
  final VidaGame game;
  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0x882B1D14),
        child: Stage540(
          child: Center(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: paperDeco(),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('PAUSA', style: _chewy.copyWith(fontSize: 34, color: kAccent, letterSpacing: 2)),
                const SizedBox(height: 10),
                const SettingsRows(),
                const SizedBox(height: 16),
                PaperButton('Seguir', game.resume),
                const SizedBox(height: 12),
                PaperButton('Salir al menú', game.toMenu, small: true),
              ]),
            ),
          ),
        ),
      );
}

class SettingsRows extends StatefulWidget {
  const SettingsRows({super.key});
  @override
  State<SettingsRows> createState() => _SettingsRowsState();
}

class _SettingsRowsState extends State<SettingsRows> {
  Widget row(String label, bool v, ValueChanged<bool> f) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: _hand.copyWith(fontSize: 30)),
        Switch(value: v, activeThumbColor: kAccent, onChanged: (x) => setState(() => f(x))),
      ]);
  @override
  Widget build(BuildContext context) => Column(children: [
        row('Música', Prefs.music, (x) {
          Prefs.setMusic(x);
          Audio.refresh(null);
        }),
        row('Efectos', Prefs.sfx, Prefs.setSfx),
        row('Vibración', Prefs.vibration, Prefs.setVibration),
      ]);
}

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({super.key});
  @override
  Widget build(BuildContext context) => Stage540(
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              decoration: paperDeco(),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('AJUSTES', style: _chewy.copyWith(fontSize: 34, color: kAccent, letterSpacing: 2)),
                const SizedBox(height: 10),
                const SettingsRows(),
                const SizedBox(height: 12),
                PaperButton('Borrar récord', Prefs.reset, small: true),
                const SizedBox(height: 14),
                PaperButton('Volver', () => Navigator.pop(context)),
              ]),
            ),
          ),
        ),
      );
}

// ---------------- Final: «Sales del juego» ----------------
class OverOverlay extends StatelessWidget {
  const OverOverlay(this.game, {super.key});
  final VidaGame game;
  @override
  Widget build(BuildContext context) {
    final l = game.life!, rec = game.submitScore(), s = l.st;
    final tags = l.notable();
    return Stage540(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: 490,
          margin: const EdgeInsets.only(top: 26),
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
          decoration: paperDeco(),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('SALES DEL JUEGO', style: _chewy.copyWith(fontSize: 26, color: kAccent, letterSpacing: 2)),
            Text('Ramón (0 – ${l.age})', style: _chewy.copyWith(fontSize: 46)),
            const SizedBox(height: 6),
            Text(l.epitaph(), textAlign: TextAlign.center, style: _hand.copyWith(fontSize: 26, fontStyle: FontStyle.italic, height: 1.1)),
            const SizedBox(height: 4),
            Text.rich(
                TextSpan(children: [
                  if (l.pathData != null) ...[
                    const TextSpan(text: 'Camino: '),
                    TextSpan(text: l.pathData!['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (l.branchData != null) TextSpan(text: ' · ${l.branchData!['name']}'),
                  ] else
                    const TextSpan(text: 'Vivió una vida normal, sin vocación.'),
                  if (game.newFound.isNotEmpty) TextSpan(text: '  ¡Nuevo camino descubierto!', style: _chewy.copyWith(color: kAccent)),
                  TextSpan(text: '\nCaminos descubiertos: ${Prefs.foundBranches}/${LifeData.totalBranches}'),
                ]),
                textAlign: TextAlign.center,
                style: _hand.copyWith(fontSize: 21, height: 1.15)),
            const SizedBox(height: 6),
            Text('Murió a los ${l.age} años, ${l.cause}.', textAlign: TextAlign.center, style: _hand.copyWith(fontSize: 22, color: kInk.withValues(alpha: 0.8))),
            const SizedBox(height: 10),
            if (tags.isEmpty) Text('No tomó ninguna decisión memorable.', style: _hand.copyWith(fontSize: 21)),
            for (final t in tags)
              Align(alignment: Alignment.centerLeft, child: Text('•  A los ${t.age}, ${t.text}.', style: _hand.copyWith(fontSize: 21, height: 1.15))),
            const SizedBox(height: 8),
            Text('Salud ${s[0].round()} · Dinero ${s[1].round()} · Felicidad ${s[2].round()} · Relaciones ${s[3].round()}',
                style: _hand.copyWith(fontSize: 20, color: kInk.withValues(alpha: 0.8))),
            Text('${l.finalScore} pts', style: _chewy.copyWith(fontSize: 54, color: const Color(0xFF6C9A3C))),
            Text('${rec ? '¡La mejor vida hasta ahora! ' : ''}Récord: ${Prefs.best} · Vidas vividas: ${Prefs.lives}',
                textAlign: TextAlign.center, style: _hand.copyWith(fontSize: 22, fontWeight: rec ? FontWeight.bold : null)),
            const SizedBox(height: 12),
            PaperButton('Vivir otra vez', game.play, big: true),
            const SizedBox(height: 10),
            PaperButton('Menú', game.toMenu, small: true),
          ]),
        ),
      ),
    );
  }
}

// ---------------- Caminos de vida descubiertos ----------------
class PathsDialog extends StatelessWidget {
  const PathsDialog(this.data, {super.key});
  final LifeData data;
  @override
  Widget build(BuildContext context) {
    final rest = 10 - data.paths.length;
    Widget icon(String k) => Image.asset('assets/items/$k.webp', width: 34, height: 34, errorBuilder: (_, _, _) => const SizedBox(width: 34));
    return Stage540(
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 820),
            padding: const EdgeInsets.all(22),
            decoration: paperDeco(),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('CAMINOS DE VIDA', style: _chewy.copyWith(fontSize: 30, color: kAccent, letterSpacing: 2)),
              Text('${Prefs.foundBranches} de ${LifeData.totalBranches} finales descubiertos', style: _hand.copyWith(fontSize: 22, color: kInk.withValues(alpha: 0.8))),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(shrinkWrap: true, children: [
                  for (final e in data.paths.entries) _pathCard(e.key, e.value, icon),
                  if (rest > 0)
                    _box(true, [
                      Text('+$rest caminos más', style: _chewy.copyWith(fontSize: 28)),
                      Text('Próximamente', style: _hand.copyWith(fontSize: 19, fontStyle: FontStyle.italic)),
                    ]),
                ]),
              ),
              const SizedBox(height: 12),
              PaperButton('Volver', () => Navigator.pop(context)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _box(bool locked, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: locked ? const Color(0xFFEADCC2) : kCream,
          border: Border.all(color: kInk, width: 3),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Opacity(opacity: locked ? 0.6 : 1, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
      );

  Widget _pathCard(String id, Json p, Widget Function(String) icon) {
    final got = Prefs.found.contains(id);
    return _box(!got, [
      Row(children: [icon(p['icon'] as String), const SizedBox(width: 10), Text(got ? p['name'] as String : '???', style: _chewy.copyWith(fontSize: 28))]),
      for (final b in (p['branches'] as Map).entries)
        Opacity(
          opacity: Prefs.found.contains('${id}_${b.key}') ? 1 : 0.55,
          child: Row(children: [
            if (Prefs.found.contains('${id}_${b.key}')) ...[icon((b.value as Json)['icon'] as String), const SizedBox(width: 8)],
            Text(Prefs.found.contains('${id}_${b.key}') ? (b.value as Json)['name'] as String : '? ? ?', style: _hand.copyWith(fontSize: 22)),
          ]),
        ),
      if (!got) Text((p['hint'] ?? 'Lo que hagas de niño decide si lo descubres.') as String, style: _hand.copyWith(fontSize: 19, fontStyle: FontStyle.italic)),
    ]);
  }
}
