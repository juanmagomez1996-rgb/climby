import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'climby_app.dart';
import 'storage.dart';
import 'render.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  await GameAssets.loadAll();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ClimbyApp());
}
