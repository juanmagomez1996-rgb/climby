import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'prefs.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ZappingApp());
}

class ZappingApp extends StatefulWidget {
  const ZappingApp({super.key});
  @override
  State<ZappingApp> createState() => _ZappingAppState();
}

class _ZappingAppState extends State<ZappingApp> {
  final game = ZappingGame();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zapping Infinito',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Atkinson'),
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
            case Mode.menu when game.overlays.isActive('sandbox'):
              game.toMenu();
            default:
              SystemNavigator.pop();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF1A1424),
          body: Builder(builder: (context) {
            game.safeArea = MediaQuery.viewPaddingOf(context);
            return Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (e) => game.pointerDown(e.pointer, e.localPosition),
            onPointerMove: (e) => game.pointerMove(e.pointer, e.localPosition),
            onPointerUp: (e) => game.pointerUp(e.pointer),
            onPointerCancel: (e) => game.pointerUp(e.pointer),
            child: GameWidget<ZappingGame>(
              game: game,
              loadingBuilder: (_) => const ColoredBox(
                color: Color(0xFF1A1424),
                child: Center(child: CircularProgressIndicator(color: Color(0xFFFFB23E))),
              ),
              overlayBuilderMap: {
                'menu': (_, g) => MenuOverlay(g),
                'pause': (_, g) => PauseOverlay(g),
                'over': (_, g) => GameOverOverlay(g),
                'sandbox': (_, g) => SandboxOverlay(g),
              },
            ),
          );
          }),
        ),
      ),
    );
  }
}
