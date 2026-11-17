import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';

import 'Configuration/api_client.dart';
import 'Configuration/app_theme.dart';
import 'Pages/Profil/forfaits_page.dart';
import 'Pages/Social/notifications_page.dart';
import 'Providers/app_state.dart';
import 'Services/fcm_push_service.dart';
import 'Services/offline_queue.dart';
import 'Services/push_router.dart';
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
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<Map<String, dynamic>>? _abonnementForeground;
  StreamSubscription<Map<String, dynamic>>? _abonnementOuverts;

  @override
  void initState() {
    super.initState();
    final push = PushService.instance;
    _abonnementForeground = push.messagesForeground.listen(_surMessageForeground);
    _abonnementOuverts = push.messagesOuverts.listen(_surMessageTappe);
    // Cold start : si l'app a été lancée depuis un push, le router doit
    // attendre que l'arbre soit monté avant de pouvoir pousser une route.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initial = await push.messageInitial();
      if (initial != null) _surMessageTappe(initial);
    });
  }

  @override
  void dispose() {
    _abonnementForeground?.cancel();
    _abonnementOuverts?.cancel();
    super.dispose();
  }

  void _surMessageForeground(Map<String, dynamic> payload) {
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

  /// Un push a été tapé — route vers l'écran pertinent selon le type.
  /// - `forfaits` / `notifications` : push simple (reste au-dessus de l'écran courant).
  /// - `feedContenu` / `commentaires` avec `contentId` : retour à l'`AppShell` +
  ///   dépôt de l'intent dans `AppState.intentPush` → l'`AppShell` écoute,
  ///   bascule sur l'onglet feed, assure le contenu via le repo, et ouvre la
  ///   sheet commentaires si c'était la destination.
  void _surMessageTappe(Map<String, dynamic> payload) {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    final decision = routerPourPush(payload);
    switch (decision.destination) {
      case DestinationPush.forfaits:
        nav.push(MaterialPageRoute(builder: (_) => const ForfaitsPage()));
      case DestinationPush.notifications:
        nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
      case DestinationPush.feedContenu:
      case DestinationPush.commentaires:
        if (decision.contentId == null) {
          // Pas d'ID utilisable → repli sur la page notifications pour que
          // l'utilisateur voie quand même le message.
          nav.push(MaterialPageRoute(builder: (_) => const NotificationsPage()));
          return;
        }
        // Retour à la racine (AppShell) puis signal via AppState — l'écoute
        // dans `AppShell.initState` fait le reste. Si l'utilisateur n'est pas
        // connecté, l'intent reste en attente jusqu'à l'ouverture d'AppShell.
        nav.popUntil((r) => r.isFirst);
        widget.etat.intentPush.value = decision;
    }
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
        navigatorKey: _navigatorKey,
        home: const SplashScreen(),
        builder: EasyLoading.init(),
      ),
    );
  }
}
