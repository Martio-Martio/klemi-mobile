/// Interface des notifications push mobile. On garde un contrat abstrait pour
/// deux raisons :
///   1) Les credentials Firebase (`google-services.json` / `GoogleService-Info.plist`)
///      peuvent être absents (dev sans config, CI). Un `PushService.stub()`
///      permet au reste du code de compiler et de tourner sans dépendre de
///      Firebase.
///   2) Côté tests, on injecte un stub pour vérifier le flow login → enregistrement
///      du token sans réellement toucher au plugin natif.
///
/// La vraie implémentation vit dans `fcm_push_service.dart` et est câblée
/// via [PushService.brancher] au boot (main.dart) après init réussie de Firebase.
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

  /// Factory par défaut — renvoie un stub inerte.
  factory PushService.stub() = _StubPushService;

  // ─── Singleton ───────────────────────────────────────────────────────

  static PushService _instance = _StubPushService();

  /// Récupère l'instance courante. Par défaut : stub. Remplacée par
  /// `FcmPushService` depuis `main.dart` après init Firebase réussie.
  static PushService get instance => _instance;

  /// Branche l'implémentation concrète — appelé au boot après init Firebase.
  static void brancher(PushService service) {
    _instance = service;
  }
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
