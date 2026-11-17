import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Models/feed_item.dart';
import 'package:klemi/Services/mobile_feed_api.dart';
import 'package:klemi/Services/offline_queue.dart';
import 'package:klemi/Services/social_api.dart';

// Fake connectivity sans flux : on contrôle manuellement (pas d'auto-flush).
class _FakeConnectivity implements Connectivity {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.none];

  // Les autres membres de l'interface non utilisés par la queue.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ApiClient _clientAvec(http.Response Function(http.BaseRequest) handler) {
  final mock = MockClient((req) async => handler(req));
  return ApiClient(
    baseUrl: 'https://exemple.test/api',
    resoudreLangue: () => 'fr',
    resoudreToken: () async => 'tok',
    client: mock,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FeedItem.toJson/fromJson round-trip', () {
    test('QuizItem — round-trip préserve tous les champs', () {
      final original = feedItemDepuisJson({
        'id': 'q-1',
        'type': 'quiz',
        'titre': 'Qui a fondé Tombouctou ?',
        'langue': 'fr',
        'auteur': {'pseudo': '@prof', 'etablissement': 'Lycée', 'initiales': 'PK'},
        'legende': 'Histoire',
        'hashtags': ['histoire'],
        'likes': 42,
        'matiere': 'Histoire',
        'numero': 2,
        'total': 10,
        'reponses': ['Askia', 'Soundiata', 'Touaregs'],
        'bonneReponse': 2,
        'explication': 'Les Touaregs.',
      });

      final json = feedItemVersJson(original);
      // Simule le passage par SharedPreferences.
      final apres = feedItemDepuisJson(jsonDecode(jsonEncode(json)) as Map<String, dynamic>);
      expect(apres, isA<QuizItem>());
      final q = apres as QuizItem;
      expect(q.id, 'q-1');
      expect(q.matiere, 'Histoire');
      expect(q.numero, 2);
      expect(q.reponses, ['Askia', 'Soundiata', 'Touaregs']);
      expect(q.bonneReponse, 2);
      expect(q.likes, 42);
      expect(q.auteur.pseudo, '@prof');
    });

    test('PodcastItem avec ɛ ɔ dans transcript survit au round-trip', () {
      final original = feedItemDepuisJson({
        'id': 'p-1',
        'type': 'podcast',
        'titre': 'Soundiata Keita',
        'langue': 'bm',
        'auteur': {'pseudo': 'Klemi IA', 'etablissement': '', 'initiales': 'K'},
        'legende': 'Épopée',
        'hashtags': [],
        'likes': 0,
        'nomLangue': 'bamanankan',
        'voix': ['Fanta', 'Musa'],
        'transcript': [
          {'voix': 'Fanta', 'texte': 'I ni cɛ Musa.', 'debutMs': 0},
          {'voix': 'Musa', 'texte': 'Nse i ni cɛ.', 'debutMs': 2400},
        ],
        'dureeSec': 720,
      });
      final apres = feedItemDepuisJson(
          jsonDecode(jsonEncode(feedItemVersJson(original))) as Map<String, dynamic>);
      expect(apres, isA<PodcastItem>());
      final p = apres as PodcastItem;
      expect(p.transcript[0].texte, 'I ni cɛ Musa.');
      expect(p.transcript[1].debutMs, 2400);
      expect(p.dureeSec, 720);
    });

    test('FicheItem avec dates + lexique round-trip', () {
      final original = feedItemDepuisJson({
        'id': 'f-1',
        'type': 'fiche',
        'titre': 'Révolution française',
        'langue': 'fr',
        'auteur': {'pseudo': '@p', 'etablissement': '', 'initiales': 'P'},
        'legende': '1789',
        'hashtags': [],
        'likes': 0,
        'sousTitre': 'Chute de la Bastille',
        'essentiel': ['DDHC'],
        'leSaviezVous': 'Marat baignoire',
        'dates': [
          {'annee': '1789', 'evenement': 'Prise de la Bastille'}
        ],
        'lexique': [
          {'mot': 'Sans-culottes', 'definition': 'Révolutionnaires', 'traduction': 'Les sans-pantalon'}
        ],
        'dureeLectureMin': 5,
      });
      final apres = feedItemDepuisJson(
          jsonDecode(jsonEncode(feedItemVersJson(original))) as Map<String, dynamic>);
      expect(apres, isA<FicheItem>());
      final f = apres as FicheItem;
      expect(f.dates.first.annee, '1789');
      expect(f.lexique.first.mot, 'Sans-culottes');
      expect(f.dureeLectureMin, 5);
    });
  });

  group('OfflineQueue', () {
    test('enfiler persiste dans SharedPreferences (round-trip)', () async {
      SharedPreferences.setMockInitialValues({});
      // API qui laisse toute action passer → mais on n'appelle pas flush ici.
      final api = SocialApi(_clientAvec((_) => http.Response('', 204)));
      final feedApi = MobileFeedApi(_clientAvec((_) => http.Response('{}', 200)));
      final q = OfflineQueue(socialApi: api, feedApi: feedApi, connectivity: _FakeConnectivity());

      await q.enfiler(ActionDifferee.like, 'q-1');
      await q.enfiler(ActionDifferee.follow, 'c-1');
      expect(q.enAttente, 2);

      // Instancier une 2e queue → lit depuis SharedPreferences.
      final q2 = OfflineQueue(socialApi: api, feedApi: feedApi, connectivity: _FakeConnectivity());
      await q2.enfiler(ActionDifferee.unlike, 'ignore'); // force chargement
      // La seconde queue avait récupéré 2 entrées persistées + ajouté 1.
      expect(q2.enAttente, 3);
    });

    test('flush rejoue les actions dans l\'ordre et vide la file', () async {
      SharedPreferences.setMockInitialValues({});
      final appels = <String>[];
      final social = SocialApi(_clientAvec((r) {
        appels.add('${r.method} ${r.url.path}');
        return http.Response('', 204);
      }));
      final feed = MobileFeedApi(_clientAvec((r) {
        appels.add('${r.method} ${r.url.path}');
        return http.Response(jsonEncode({'correct': true, 'pointsGagnes': 20, 'explication': ''}), 200);
      }));
      final q = OfflineQueue(socialApi: social, feedApi: feed, connectivity: _FakeConnectivity());

      await q.enfiler(ActionDifferee.like, 'q-1');
      await q.enfiler(ActionDifferee.follow, 'c-1');
      await q.enfiler(ActionDifferee.repondreQuiz, 'q-2', extra: {'answerIndex': 1});

      await q.flush();
      expect(q.enAttente, 0);
      expect(appels, [
        'POST /api/mobile/content/q-1/like',
        'POST /api/mobile/follows/c-1',
        'POST /api/mobile/feed/q-2/answer',
      ]);
    });

    test('flush garde l\'action quand c\'est une erreur réseau transitoire (0/408/429)', () async {
      SharedPreferences.setMockInitialValues({});
      final social = SocialApi(ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreToken: () async => 'tok',
        client: MockClient((_) async {
          throw http.ClientException('offline');
        }),
      ));
      final feed = MobileFeedApi(_clientAvec((_) => http.Response('{}', 200)));
      final q = OfflineQueue(socialApi: social, feedApi: feed, connectivity: _FakeConnectivity());

      await q.enfiler(ActionDifferee.like, 'q-1');
      await q.flush();
      // L'action reste en file — l'appel réseau a échoué (ApiException statusCode=0).
      expect(q.enAttente, 1);
    });

    test('flush abandonne les actions sur erreur 4xx non récupérable (ex. 403)', () async {
      SharedPreferences.setMockInitialValues({});
      final social = SocialApi(_clientAvec((_) {
        return http.Response(jsonEncode({'statusCode': 403, 'message': 'forbidden'}), 403);
      }));
      final feed = MobileFeedApi(_clientAvec((_) => http.Response('{}', 200)));
      final q = OfflineQueue(socialApi: social, feedApi: feed, connectivity: _FakeConnectivity());

      await q.enfiler(ActionDifferee.follow, 'c-interdit');
      await q.flush();
      expect(q.enAttente, 0); // on ne reboucle pas sur une erreur définitive
    });
  });
}
