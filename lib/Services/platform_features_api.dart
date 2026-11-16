import '../Configuration/api_client.dart';
import 'api_exception.dart';

/// Catalogue public des features backend (YouTube, podcast, mobile money…).
/// Endpoint public confirmé par l'audit : `GET /platform/features`
/// (`src/controllers/platform-features.controller.ts:36-45`).
class PlatformFeaturesApi {
  final ApiClient _client;

  PlatformFeaturesApi([ApiClient? client]) : _client = client ?? ApiClient.instance;

  /// Charge le catalogue. Retourne une map vide en cas d'échec réseau — on
  /// ne bloque pas le démarrage de l'app pour un feature flag indisponible.
  Future<Map<String, dynamic>> charger() async {
    try {
      final reponse = await _client.get('/platform/features');
      if (reponse is Map<String, dynamic>) return reponse;
      return const {};
    } on ApiException {
      return const {};
    }
  }
}
