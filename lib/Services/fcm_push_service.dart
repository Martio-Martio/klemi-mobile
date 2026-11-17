import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'push_service.dart';

/// Implémentation concrète de [PushService] sur Firebase Cloud Messaging.
///
/// L'init utilise `Firebase.initializeApp()` **sans options** : FCM lit
/// automatiquement `android/app/google-services.json` (Android) et
/// `ios/Runner/GoogleService-Info.plist` (iOS) déposés par
/// `flutterfire configure`. Pour ajouter plus tard du Web/Desktop, remplacer
/// par `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
/// (import `firebase_options.dart`).
class FcmPushService implements PushService {
  final FirebaseMessaging _messaging;
  final StreamController<Map<String, dynamic>> _foreground =
      StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<RemoteMessage>? _abonnement;

  FcmPushService._(this._messaging);

  /// Initialise Firebase et retourne l'instance prête à l'emploi.
  /// Lève si les configs natives sont absentes — l'appelant (main.dart)
  /// doit catcher pour retomber sur [PushService.stub()].
  static Future<FcmPushService> initialiser() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    final messaging = FirebaseMessaging.instance;
    final instance = FcmPushService._(messaging);
    instance._abonnement = FirebaseMessaging.onMessage.listen((msg) {
      instance._foreground.add(_versPayload(msg));
    });
    return instance;
  }

  @override
  Future<bool> demanderPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> obtenirToken() async {
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  String get plateforme {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  @override
  Stream<Map<String, dynamic>> get messagesForeground => _foreground.stream;

  /// Libère le stream et l'abonnement — utilisé au logout.
  Future<void> arreter() async {
    await _abonnement?.cancel();
    _abonnement = null;
    await _foreground.close();
  }
}

Map<String, dynamic> _versPayload(RemoteMessage msg) {
  return {
    if (msg.notification?.title != null) 'titre': msg.notification!.title,
    if (msg.notification?.body != null) 'detail': msg.notification!.body,
    ...msg.data,
  };
}
