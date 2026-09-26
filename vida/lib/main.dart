import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio.dart';
import 'game.dart';
import 'prefs.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const VidaApp());
}

class VidaApp extends StatefulWidget {
  const VidaApp({super.key});
  @override
  State<VidaApp> createState() => _VidaAppState();
}

class _VidaAppState extends State<VidaApp> with WidgetsBindingObserver {
  final game = VidaGame();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Al salir de la app: pausa la partida y la música.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      game.pause();
      Audio.pauseAll();
    } else if (state == AppLifecycleState.resumed && game.mode != Mode.paused) {
      Audio.resumeAll();
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Una Vida',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'PatrickHand', colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE0673C))),
        home: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            switch (game.mode) {
              case Mode.playing:
                game.pause();
              case Mode.paused:
                game.resume();
              case Mode.over:
                game.toMenu();
              default:
                SystemNavigator.pop();
            }
          },
          child: Scaffold(
            backgroundColor: const Color(0xFF2B1D14),
            body: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) => game.tap(e.localPosition),
              child: GameWidget<VidaGame>(
                game: game,
                loadingBuilder: (_) => const ColoredBox(
                  color: Color(0xFF2B1D14),
                  child: Center(child: Text('Pintando la vida…', style: TextStyle(fontFamily: 'PatrickHand', fontSize: 24, color: Color(0xFFFFF4DC)))),
                ),
                overlayBuilderMap: {
                  'menu': (_, g) => MenuOverlay(g),
                  'hud': (_, g) => HudOverlay(g),
                  'card': (_, g) => CardOverlay(g),
                  'pause': (_, g) => PauseOverlay(g),
                  'over': (_, g) => OverOverlay(g),
                },
              ),
            ),
          ),
        ),
      );
}
