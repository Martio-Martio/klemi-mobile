/// Interface des notifications push mobile. On garde un contrat abstrait pour
/// deux raisons :
///   1) Les credentials Firebase (`google-services.json` / `GoogleService-Info.plist`)
///      ne sont pas encore dans le repo — l'équipe backend les fournira avec
///      le projet Firebase. Jusque-là, un `PushService.stub()` permet au reste
///      du code de compiler et de tourner sans dépendre de Firebase.
///   2) Côté tests, on injecte un stub pour vérifier le flow login → enregistrement
///      du token sans réellement toucher au plugin natif.
///
/// Quand les credentials seront prêts, créer un `FcmPushService` qui implémente
/// cette interface via `firebase_core` + `firebase_messaging` (plan Phase 5).
abstract class PushService {
  /// Demande la permission de recevoir des notifications (modale système).
  /// Retourne `true` si l'utilisateur accepte ou si la permission est déjà
  /// accordée.
  Future<bool> demanderPermission();

  /// Récupère le token FCM courant. `null` si pas de permission, ou en cas
  /// d'échec d'init côté plugin natif.
  Future<String?> obtenirToken();

  /// Plateforme à envoyer avec le token (`ios` | `android`).
  String get plateforme;

  /// Stream des payloads reçus en foreground.
  Stream<Map<String, dynamic>> get messagesForeground;

  /// Factory par défaut — renvoie un stub tant que Firebase n'est pas câblé.
  /// À remplacer par `FcmPushService()` dans `main.dart` une fois le projet
  /// Firebase Klemi provisionné.
  factory PushService.stub() = _StubPushService;
}

class _StubPushService implements PushService {
  _StubPushService();

  @override
  Future<bool> demanderPermission() async => false;

  @override
  Future<String?> obtenirToken() async => null;

  @override
  String get plateforme => 'other';

  @override
  Stream<Map<String, dynamic>> get messagesForeground => const Stream.empty();
}
