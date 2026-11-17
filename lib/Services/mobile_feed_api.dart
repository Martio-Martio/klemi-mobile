import '../Configuration/api_client.dart';
import '../Models/feed_item.dart';
import 'api_exception.dart';

/// Onglet logique côté UI → paramètre `tab` côté API.
enum TabFeed { pourToi, mesCours, abonnements }

extension TabFeedCle on TabFeed {
  String get cle => switch (this) {
        TabFeed.pourToi => 'pour-toi',
        TabFeed.mesCours => 'mes-cours',
        TabFeed.abonnements => 'abonnements',
      };
}

/// Une page du feed : liste d'items + curseur pour la page suivante.
class PageFeed {
  final List<FeedItem> items;
  final String? curseurSuivant;
  const PageFeed({required this.items, required this.curseurSuivant});

  bool get aPageSuivante => curseurSuivant != null;
}

/// Résultat d'un `answerQuiz` (/mobile/feed/:id/answer) côté API.
class ReponseQuiz {
  final bool correct;
  final int pointsGagnes;
  final String explication;
  const ReponseQuiz({
    required this.correct,
    required this.pointsGagnes,
    required this.explication,
  });
}

/// Wrapper des endpoints `/api/mobile/feed/*` (plan Phase 2). Les endpoints
/// `like/unlike/save` renvoient aujourd'hui **501 NOT_IMPLEMENTED** côté API
/// — on laisse l'`ApiException` remonter, les écrans UI doivent la gérer.
class MobileFeedApi {
  final ApiClient _client;

  MobileFeedApi([ApiClient? client]) : _client = client ?? ApiClient.instance;

  Future<PageFeed> fetchFeed({
    required TabFeed tab,
    String? cursor,
    int limit = 20,
    String? lang,
    String? langAudio,
  }) async {
    final reponse = await _client.get('/mobile/feed', query: {
      'tab': tab.cle,
      'limit': limit,
      'cursor': ?cursor,
      'lang': ?lang,
      'langAudio': ?langAudio,
    }) as Map<String, dynamic>;

    final items = ((reponse['items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(feedItemDepuisJson)
        .toList();
    return PageFeed(items: items, curseurSuivant: reponse['nextCursor'] as String?);
  }

  Future<FeedItem> fetchOne(String id) async {
    final reponse = await _client.get('/mobile/feed/$id') as Map<String, dynamic>;
    return feedItemDepuisJson(reponse);
  }

  Future<ReponseQuiz> answerQuiz(String id, int answerIndex) async {
    final reponse = await _client.post(
      '/mobile/feed/$id/answer',
      body: {'answerIndex': answerIndex},
    ) as Map<String, dynamic>;
    return ReponseQuiz(
      correct: reponse['correct'] as bool? ?? false,
      pointsGagnes: (reponse['pointsGagnes'] as num?)?.toInt() ?? 0,
      explication: reponse['explication'] as String? ?? '',
    );
  }

  /// Like / unlike / save — endpoints exposés par le plan mais placeholder
  /// côté API (501). Les appelants UI doivent catcher [ApiException] et
  /// afficher un message « Bientôt ».
  Future<void> likeItem(String id) => _client.post('/mobile/feed/$id/like');
  Future<void> unlikeItem(String id) => _client.delete('/mobile/feed/$id/like');
  Future<void> saveItem(String id) => _client.post('/mobile/feed/$id/save');
}

/// Prédicat utilitaire pour les callers UI : vrai si l'erreur traduit une
/// feature pas encore livrée côté backend (code = `NOT_IMPLEMENTED` ou
/// statut 501). Permet d'afficher un message « Bientôt disponible »
/// uniformément.
bool estBientotDisponible(ApiException e) =>
    e.statusCode == 501 || e.code == 'NOT_IMPLEMENTED';
