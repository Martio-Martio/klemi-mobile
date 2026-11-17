import '../Configuration/api_client.dart';
import '../Models/social.dart';

/// Wrapper des 5 modules sociaux côté API (`creators`, `follows`,
/// `content-likes`, `content-comments`, `push-notifications`) + le centre de
/// notifications. On regroupe tout dans une seule façade pour simplifier
/// l'injection côté UI.

/// Résultat paginé de `GET /mobile/content/:id/comments`.
class PageCommentaires {
  final List<Commentaire> commentaires;
  final String? curseurSuivant;
  final int total;
  const PageCommentaires({
    required this.commentaires,
    required this.curseurSuivant,
    required this.total,
  });
}

/// Résultat paginé de `GET /mobile/me/notifications`.
class PageNotifications {
  final List<NotificationApp> notifications;
  final String? curseurSuivant;
  final int nonLues;
  const PageNotifications({
    required this.notifications,
    required this.curseurSuivant,
    required this.nonLues,
  });
}

/// Détails d'un créateur + ses contenus — sortie de `GET /mobile/creators/:id`.
class CreateurAvecContenus {
  final Createur createur;
  final bool suivi;
  final List<ContenuResume> contenus;
  const CreateurAvecContenus({
    required this.createur,
    required this.suivi,
    required this.contenus,
  });
}

class SocialApi {
  final ApiClient _client;

  SocialApi([ApiClient? client]) : _client = client ?? ApiClient.instance;

  // ─── Creators ──────────────────────────────────────────────────────────

  Future<CreateurAvecContenus> getCreator(String id) async {
    final reponse = await _client.get('/mobile/creators/$id') as Map<String, dynamic>;
    final createurBrut = reponse['createur'] is Map<String, dynamic>
        ? reponse['createur'] as Map<String, dynamic>
        : reponse;
    final contenusBrut = (reponse['contenus'] as List?) ?? const [];
    return CreateurAvecContenus(
      createur: CreateurJson.depuisJson(createurBrut),
      suivi: reponse['suivi'] as bool? ?? false,
      contenus: contenusBrut
          .cast<Map<String, dynamic>>()
          .map(ContenuResumeJson.depuisJson)
          .toList(),
    );
  }

  Future<List<ContenuResume>> getCreatorContenus(String id, {String? type, String? cursor}) async {
    final reponse = await _client.get('/mobile/creators/$id/contents', query: {
      'type': ?type,
      'cursor': ?cursor,
    }) as Map<String, dynamic>;
    final items = (reponse['items'] as List?) ?? const [];
    return items.cast<Map<String, dynamic>>().map(ContenuResumeJson.depuisJson).toList();
  }

  // ─── Follows ───────────────────────────────────────────────────────────

  Future<void> follow(String creatorId) =>
      _client.post('/mobile/follows/$creatorId');

  Future<void> unfollow(String creatorId) =>
      _client.delete('/mobile/follows/$creatorId');

  /// Retourne les IDs des créateurs suivis par l'utilisateur courant.
  /// Pratique pour synchroniser `AppState.suivis` au startup.
  Future<Set<String>> getFollowing({String? cursor}) async {
    final reponse = await _client.get('/mobile/me/following', query: {
      'cursor': ?cursor,
    }) as Map<String, dynamic>;
    final items = (reponse['items'] as List?) ?? const [];
    return items
        .cast<Map<String, dynamic>>()
        .map((e) => (e['creatorId'] ?? e['id'] ?? '') as String)
        .where((s) => s.isNotEmpty)
        .toSet();
  }

  // ─── Content-likes ─────────────────────────────────────────────────────

  Future<void> likeItem(String contentId) =>
      _client.post('/mobile/content/$contentId/like');

  Future<void> unlikeItem(String contentId) =>
      _client.delete('/mobile/content/$contentId/like');

  // ─── Content-comments ──────────────────────────────────────────────────

  Future<PageCommentaires> listComments(
    String contentId, {
    String? cursor,
    int limit = 20,
  }) async {
    final reponse = await _client.get('/mobile/content/$contentId/comments', query: {
      'limit': limit,
      'cursor': ?cursor,
    }) as Map<String, dynamic>;
    final items = ((reponse['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Commentaire.depuisJson)
        .toList();
    return PageCommentaires(
      commentaires: items,
      curseurSuivant: reponse['nextCursor'] as String?,
      total: (reponse['total'] as num?)?.toInt() ?? items.length,
    );
  }

  Future<Commentaire> postComment(String contentId, String texte, {String? parentId}) async {
    final reponse = await _client.post(
      '/mobile/content/$contentId/comments',
      body: {
        'texte': texte,
        'parentId': ?parentId,
      },
    ) as Map<String, dynamic>;
    return Commentaire.depuisJson(reponse);
  }

  Future<void> deleteComment(String commentId) =>
      _client.delete('/mobile/comments/$commentId');

  // ─── Notifications ─────────────────────────────────────────────────────

  Future<PageNotifications> listNotifications({String? cursor, int limit = 30}) async {
    final reponse = await _client.get('/mobile/me/notifications', query: {
      'limit': limit,
      'cursor': ?cursor,
    }) as Map<String, dynamic>;
    final items = ((reponse['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(NotificationApp.depuisJson)
        .toList();
    return PageNotifications(
      notifications: items,
      curseurSuivant: reponse['nextCursor'] as String?,
      nonLues: (reponse['nonLues'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> markNotificationRead(String id) =>
      _client.patch('/mobile/me/notifications/$id/read');

  Future<int> countUnread() async {
    final reponse = await _client.get('/mobile/me/notifications/unread-count');
    if (reponse is Map<String, dynamic>) {
      return (reponse['count'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  // ─── Push notifications ────────────────────────────────────────────────

  Future<void> registerPushToken({required String token, required String platform}) =>
      _client.post('/mobile/me/push-token', body: {'token': token, 'platform': platform});

  Future<void> unregisterPushToken(String token) =>
      _client.delete('/mobile/me/push-token', body: {'token': token});
}
