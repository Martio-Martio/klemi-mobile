import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';

import 'Configuration/api_client.dart';
import 'Configuration/app_theme.dart';
import 'Providers/app_state.dart';
import 'Services/fcm_push_service.dart';
import 'Services/offline_queue.dart';
import 'Services/push_service.dart';
import 'Services/sentry_service.dart';
import 'Widgets/custom_animation.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configLoading();
  SentryService.brancherFlutterError();

  await SentryService.executerAppLive(() async {
    // AppState est injecté plus bas dans le Provider ; on en crée l'instance
    // ici pour pouvoir brancher l'ApiClient (langue + token + refresh) avant
    // toute requête.
    final etat = AppState();
    final apiClient = ApiClient(
      resoudreLangue: () => etat.langue.id,
      resoudreLangueAudio: () => etat.langueAudio.id,
      rafraichirSession: etat.tenterRafraichirSession,
    );
    ApiClient.brancher(apiClient);

    // Démarre la file d'actions offline (rejoue à la reconnexion).
    unawaited(OfflineQueue.instance.demarrer());

    // Tente d'activer FCM. Si les configs natives (google-services.json /
    // GoogleService-Info.plist) ne sont pas en place, on reste en mode stub
    // sans crasher — permet aux builds dev de tourner avant `flutterfire configure`.
    try {
      final fcm = await FcmPushService.initialiser();
      PushService.brancher(fcm);
    } catch (_) {
      // Mode stub silencieux : PushService.instance renvoie déjà un _StubPushService.
    }

    // Application en portrait uniquement.
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    runApp(MyApp(etat: etat));
  });
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

class MyApp extends StatefulWidget {
  final AppState etat;
  const MyApp({super.key, required this.etat});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<Map<String, dynamic>>? _abonnementPush;

  @override
  void initState() {
    super.initState();
    _abonnementPush = PushService.instance.messagesForeground.listen(_surMessagePush);
  }

  @override
  void dispose() {
    _abonnementPush?.cancel();
    super.dispose();
  }

  void _surMessagePush(Map<String, dynamic> payload) {
    final titre = payload['titre'] as String?;
    final detail = payload['detail'] as String?;
    if (titre == null && detail == null) return;
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text([titre, detail].whereType<String>().join(' · ')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

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
      value: widget.etat,
      child: MaterialApp(
        title: 'Klemi',
        theme: AppTheme.theme(),
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: _messengerKey,
        home: const SplashScreen(),
        builder: EasyLoading.init(),
      ),
    );
  }
}
