import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';

import 'Configuration/api_client.dart';
import 'Configuration/app_theme.dart';
import 'Providers/app_state.dart';
import 'Widgets/custom_animation.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configLoading();

  // AppState est injecté plus bas dans le Provider ; on en crée l'instance
  // ici pour pouvoir brancher l'ApiClient (langue + token) avant toute requête.
  final etat = AppState();
  ApiClient.brancher(ApiClient(resoudreLangue: () => etat.langue.id));

  // Application en portrait uniquement
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) => runApp(MyApp(etat: etat)));
}

void configLoading() {
  EasyLoading.instance
    ..displayDuration = const Duration(seconds: 2)
    ..indicatorType = EasyLoadingIndicatorType.doubleBounce
    ..maskType = EasyLoadingMaskType.custom
    ..loadingStyle = EasyLoadingStyle.custom
    ..indicatorSize = 45.0
    ..radius = 10.0
    ..progressColor = AppTheme.bleu
    ..backgroundColor = AppTheme.navy
    ..indicatorColor = Colors.white
    ..textColor = Colors.white
    ..maskColor = Colors.black45
    ..userInteractions = false
    ..dismissOnTap = false
    ..customAnimation = CustomAnimation();
}

class MyApp extends StatelessWidget {
  final AppState etat;
  const MyApp({super.key, required this.etat});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );

    return ChangeNotifierProvider.value(
      value: etat,
      child: MaterialApp(
        title: 'Klemi',
        theme: AppTheme.theme(),
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        builder: EasyLoading.init(),
      ),
    );
  }
}
