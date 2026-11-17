import '../Configuration/api_client.dart';
import '../Models/feed_item.dart';

/// Payload agrégé de `GET /api/mobile/me` (plan Phase 4). On garde des maps
/// opaques sous le capot pour tolérer l'évolution des sous-structures côté
/// backend ; seuls les accesseurs utilisés par `AppState` sont typés.
class ProfilUtilisateur {
  final Map<String, dynamic> profil;
  final Map<String, dynamic> progression;
  final Map<String, dynamic> forfait;
  final Map<String, dynamic> preferences;

  const ProfilUtilisateur({
    required this.profil,
    required this.progression,
    required this.forfait,
    required this.preferences,
  });

  factory ProfilUtilisateur.depuisJson(Map<String, dynamic> json) => ProfilUtilisateur(
        profil: _carteOrVide(json['profil']),
        progression: _carteOrVide(json['progression']),
        forfait: _carteOrVide(json['forfait']),
        preferences: _carteOrVide(json['preferences']),
      );

  static Map<String, dynamic> _carteOrVide(Object? raw) =>
      raw is Map<String, dynamic> ? raw : const {};
}

/// Entrée de la biblio (contenu sauvegardé ou fait).
class EntreeBiblio {
  final FeedItem item;
  final DateTime? sauvegardeLe;
  final bool disponibleHorsLigne;
  const EntreeBiblio({
    required this.item,
    this.sauvegardeLe,
    this.disponibleHorsLigne = false,
  });
}

class PageBiblio {
  final List<EntreeBiblio> entrees;
  final String? curseurSuivant;
  const PageBiblio({required this.entrees, required this.curseurSuivant});
}

/// Quota de génération IA restant (plan Phase 3 — endpoint implémenté en
/// Phase 4 pour centraliser les appels profil).
class QuotaGeneration {
  final int restantes;
  final DateTime? resetAt;
  final String forfait;
  const QuotaGeneration({
    required this.restantes,
    this.resetAt,
    required this.forfait,
  });
}

/// Wrapper des endpoints `/api/mobile/me/*` (plan Phase 4).
class ProfileApi {
  final ApiClient _client;

  ProfileApi([ApiClient? client]) : _client = client ?? ApiClient.instance;

  Future<ProfilUtilisateur> chargerProfil() async {
    final reponse = await _client.get('/mobile/me') as Map<String, dynamic>;
    return ProfilUtilisateur.depuisJson(reponse);
  }

  Future<void> mettreAJourProfil(Map<String, dynamic> champs) async {
    await _client.patch('/mobile/me/profile', body: champs);
  }

  Future<Map<String, dynamic>> chargerPreferences() async {
    final reponse = await _client.get('/mobile/me/preferences') as Map<String, dynamic>;
    final data = reponse['data'];
    return data is Map<String, dynamic> ? data : reponse;
  }

  /// PATCH partiel : accepte une map contenant uniquement les clés modifiées
  /// (deep-merge côté serveur).
  Future<void> mettreAJourPreferences(Map<String, dynamic> patch) async {
    await _client.patch('/mobile/me/preferences', body: patch);
  }

  Future<PageBiblio> chargerBiblio({String? cursor, int limit = 20}) async {
    final reponse = await _client.get('/mobile/me/library', query: {
      'limit': limit,
      'cursor': ?cursor,
    }) as Map<String, dynamic>;
    final entrees = ((reponse['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(_entreeDepuisJson)
        .toList();
    return PageBiblio(
      entrees: entrees,
      curseurSuivant: reponse['nextCursor'] as String?,
    );
  }

  Future<QuotaGeneration> chargerQuota() async {
    final reponse = await _client.get('/mobile/me/generation-quota') as Map<String, dynamic>;
    return QuotaGeneration(
      restantes: (reponse['restantes'] as num?)?.toInt() ?? 0,
      resetAt: reponse['resetAt'] is String ? DateTime.tryParse(reponse['resetAt'] as String) : null,
      forfait: reponse['forfait'] as String? ?? 'Gratuit',
    );
  }

  /// Ping idempotent côté serveur : la première fois de la journée incrémente
  /// `serieJours`, les suivantes sont no-op.
  Future<void> pingStreak() async {
    await _client.post('/mobile/me/streak/ping');
  }

  // ─── Helpers privés ────────────────────────────────────────────────────

  EntreeBiblio _entreeDepuisJson(Map<String, dynamic> json) {
    final itemBrut = json['item'] is Map<String, dynamic>
        ? json['item'] as Map<String, dynamic>
        : json;
    final sauvegardeLe = json['savedAt'] is String
        ? DateTime.tryParse(json['savedAt'] as String)
        : null;
    return EntreeBiblio(
      item: feedItemDepuisJson(itemBrut),
      sauvegardeLe: sauvegardeLe,
      disponibleHorsLigne: json['offlineAvailable'] as bool? ?? false,
    );
  }
}
