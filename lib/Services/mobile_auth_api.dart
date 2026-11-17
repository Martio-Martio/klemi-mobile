import '../Configuration/api_client.dart';
import '../Configuration/matieres.dart';

/// Résultat d'un `signup` ou `login` : un token temporaire à présenter lors
/// de la vérification OTP. Le token final (JWT) n'est pas encore émis à ce
/// stade.
class MobileAuthDemarrage {
  final String tempToken;
  final String? userId; // seulement présent au signup
  const MobileAuthDemarrage({required this.tempToken, this.userId});
}

/// Résultat d'un `verifyOtp` ou `refresh` : session JWT complète.
class MobileAuthSession {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic>? user;
  const MobileAuthSession({
    required this.accessToken,
    required this.refreshToken,
    this.user,
  });
}

/// Rôle choisi au signup. Les libellés API sont en français — ils seront
/// mappés côté backend vers `UserRole.STUDENT` / `UserRole.TEACHER`.
enum RoleInscription { eleve, enseignant }

/// Wrapper des endpoints `/api/mobile-auth/*` (plan Phase 1). N'implémente
/// aucune logique métier : parse les réponses JSON en modèles typés et
/// propage les erreurs via [ApiException].
class MobileAuthApi {
  final ApiClient _client;

  MobileAuthApi([ApiClient? client]) : _client = client ?? ApiClient.instance;

  Future<MobileAuthDemarrage> signup({
    required String phone,
    required RoleInscription role,
    required String nom,
    required NiveauEtudes niveauEtudes,
    required String classe,
    String? etablissement,
    required String langue,
  }) async {
    final body = {
      'phone': phone.trim(),
      'role': role.name,
      'nom': nom.trim(),
      'niveauEtudes': niveauEtudes.name,
      'classe': classe.trim(),
      if (etablissement != null && etablissement.trim().isNotEmpty) 'etablissement': etablissement.trim(),
      'langue': langue,
    };
    final reponse = await _client.post('/mobile-auth/signup', body: body) as Map<String, dynamic>;
    return MobileAuthDemarrage(
      tempToken: reponse['tempToken'] as String,
      userId: reponse['userId'] as String?,
    );
  }

  Future<MobileAuthDemarrage> login(String phone) async {
    final reponse = await _client.post('/mobile-auth/login', body: {'phone': phone.trim()})
        as Map<String, dynamic>;
    return MobileAuthDemarrage(tempToken: reponse['tempToken'] as String);
  }

  /// Échange un ID token Google contre la même session que `verifyOtp`.
  Future<MobileAuthSession> connexionGoogle(String idToken) async {
    final reponse = await _client.post(
      '/mobile-auth/google',
      body: {'idToken': idToken},
    ) as Map<String, dynamic>;
    return _parserSession(reponse);
  }

  Future<MobileAuthSession> verifyOtp({required String tempToken, required String code}) async {
    final reponse = await _client.post(
      '/mobile-auth/verify-otp',
      body: {'tempToken': tempToken, 'code': code},
    ) as Map<String, dynamic>;
    return _parserSession(reponse);
  }

  Future<void> resendOtp(String tempToken) async {
    await _client.post('/mobile-auth/resend-otp', body: {'tempToken': tempToken});
  }

  Future<MobileAuthSession> refresh(String refreshToken) async {
    final reponse = await _client.post(
      '/mobile-auth/refresh',
      body: {'refreshToken': refreshToken},
    ) as Map<String, dynamic>;
    return _parserSession(reponse);
  }

  Future<void> logout() async {
    await _client.post('/mobile-auth/logout');
  }

  MobileAuthSession _parserSession(Map<String, dynamic> reponse) {
    return MobileAuthSession(
      accessToken: reponse['accessToken'] as String,
      refreshToken: reponse['refreshToken'] as String,
      user: reponse['user'] is Map<String, dynamic> ? reponse['user'] as Map<String, dynamic> : null,
    );
  }
}
