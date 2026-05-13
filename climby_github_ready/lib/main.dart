import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'climby_app.dart';
import 'storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Prefs.init();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const ClimbyApp());
}
