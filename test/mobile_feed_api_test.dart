import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Models/feed_item.dart';
import 'package:klemi/Services/api_exception.dart';
import 'package:klemi/Services/mobile_feed_api.dart';

Map<String, dynamic> _quizJson({String id = 'q-1'}) => {
      'id': id,
      'type': 'quiz',
      'titre': 'Qui a fondé Tombouctou ?',
      'langue': 'fr',
      'auteur': {'pseudo': '@prof', 'etablissement': 'Lycée', 'initiales': 'PK'},
      'legende': 'Histoire du Mali',
      'hashtags': ['histoire', 'mali'],
      'likes': 42,
      'matiere': 'Histoire',
      'numero': 1,
      'total': 5,
      'reponses': ['Askia', 'Soundiata', 'Les Touaregs', 'Mansa Moussa'],
      'bonneReponse': 2,
      'explication': 'Les Touaregs y ont établi un campement.',
    };

Map<String, dynamic> _ficheJson() => {
      'id': 'f-1',
      'type': 'fiche',
      'titre': 'La révolution française',
      'langue': 'fr',
      'auteur': {'pseudo': '@prof', 'etablissement': 'Lycée', 'initiales': 'PK'},
      'legende': '1789-1799',
      'sousTitre': 'De la Bastille à Thermidor',
      'essentiel': ['Chute de la Bastille', 'DDHC', 'Convention'],
      'leSaviezVous': 'Marat fut assassiné dans sa baignoire.',
      'dates': [
        {'annee': '1789', 'evenement': 'Prise de la Bastille'},
        {'annee': '1793', 'evenement': 'Louis XVI guillotiné'},
      ],
      'lexique': [
        {'mot': 'Sans-culottes', 'definition': 'Révolutionnaires parisiens', 'traduction': 'Les sans-pantalon'},
      ],
      'dureeLectureMin': 5,
    };

Map<String, dynamic> _podcastJson() => {
      'id': 'p-1',
      'type': 'podcast',
      'titre': 'Soundiata Keita, l\'empereur du Mali',
      'langue': 'bm',
      'auteur': {'pseudo': 'Klemi IA', 'etablissement': 'Mandé', 'initiales': 'K'},
      'legende': 'Épopée mandingue',
      'nomLangue': 'bamanankan',
      'voix': ['Fanta', 'Musa'],
      'transcript': [
        {'voix': 'Fanta', 'texte': 'I ni cɛ Musa.', 'debutMs': 0},
        {'voix': 'Musa', 'texte': 'Nse i ni cɛ.', 'debutMs': 2400},
      ],
      'dureeSec': 720,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Parsing JSON FeedItem', () {
    test('quiz → QuizItem complet', () {
      final item = feedItemDepuisJson(_quizJson());
      expect(item, isA<QuizItem>());
      final q = item as QuizItem;
      expect(q.id, 'q-1');
      expect(q.matiere, 'Histoire');
      expect(q.reponses.length, 4);
      expect(q.bonneReponse, 2);
      expect(q.explication, contains('Touaregs'));
      expect(q.auteur.pseudo, '@prof');
      expect(q.hashtags, ['histoire', 'mali']);
    });

    test('fiche → FicheItem avec dates et lexique', () {
      final item = feedItemDepuisJson(_ficheJson());
      expect(item, isA<FicheItem>());
      final f = item as FicheItem;
      expect(f.sousTitre, 'De la Bastille à Thermidor');
      expect(f.dates.length, 2);
      expect(f.dates[0].annee, '1789');
      expect(f.lexique.first.mot, 'Sans-culottes');
      expect(f.dureeLectureMin, 5);
    });

    test('podcast → PodcastItem avec transcript timestamps', () {
      final item = feedItemDepuisJson(_podcastJson());
      expect(item, isA<PodcastItem>());
      final p = item as PodcastItem;
      expect(p.langue, 'bm');
      expect(p.voix, ['Fanta', 'Musa']);
      expect(p.transcript.length, 2);
      expect(p.transcript[0].texte, 'I ni cɛ Musa.');
      expect(p.transcript[1].debutMs, 2400);
      expect(p.dureeSec, 720);
    });

    test('type inconnu → FormatException', () {
      expect(() => feedItemDepuisJson({'id': 'x', 'type': 'video'}),
          throwsA(isA<FormatException>()));
    });
  });

  group('MobileFeedApi', () {
    test('fetchFeed envoie tab, lang, langAudio, cursor dans la query', () async {
      late http.Request req;
      final mock = MockClient((r) async {
        req = r;
        return http.Response(jsonEncode({'items': [], 'nextCursor': null}), 200);
      });
      final api = MobileFeedApi(ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreToken: () async => 'tok',
        client: mock,
      ));

      await api.fetchFeed(
        tab: TabFeed.pourToi,
        lang: 'fr',
        langAudio: 'bm',
        cursor: 'c-10',
        limit: 15,
      );
      expect(req.url.path, '/api/mobile/feed');
      expect(req.url.queryParameters['tab'], 'pour-toi');
      expect(req.url.queryParameters['lang'], 'fr');
      expect(req.url.queryParameters['langAudio'], 'bm');
      expect(req.url.queryParameters['cursor'], 'c-10');
      expect(req.url.queryParameters['limit'], '15');
    });

    test('fetchFeed parse items + nextCursor', () async {
      final mock = MockClient((r) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'items': [_quizJson(), _ficheJson(), _podcastJson()],
            'nextCursor': 'c-20',
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });
      final api = MobileFeedApi(ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreToken: () async => null,
        client: mock,
      ));

      final page = await api.fetchFeed(tab: TabFeed.pourToi);
      expect(page.items.length, 3);
      expect(page.curseurSuivant, 'c-20');
      expect(page.aPageSuivante, isTrue);
      expect(page.items[0], isA<QuizItem>());
      expect(page.items[1], isA<FicheItem>());
      expect(page.items[2], isA<PodcastItem>());
    });

    test('answerQuiz envoie answerIndex et parse correct/pointsGagnes/explication', () async {
      late http.Request req;
      final mock = MockClient((r) async {
        req = r;
        return http.Response(
          jsonEncode({'correct': true, 'pointsGagnes': 25, 'explication': 'Bravo.'}),
          200,
        );
      });
      final api = MobileFeedApi(ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreToken: () async => 'tok',
        client: mock,
      ));

      final r = await api.answerQuiz('q-1', 2);
      expect(req.url.path, '/api/mobile/feed/q-1/answer');
      expect(jsonDecode(req.body), {'answerIndex': 2});
      expect(r.correct, isTrue);
      expect(r.pointsGagnes, 25);
      expect(r.explication, 'Bravo.');
    });

    test('likeItem lève ApiException 501 reconnue comme NOT_IMPLEMENTED', () async {
      final mock = MockClient((r) async {
        return http.Response(
          jsonEncode({'statusCode': 501, 'code': 'NOT_IMPLEMENTED', 'message': 'Bientôt.'}),
          501,
        );
      });
      final api = MobileFeedApi(ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreToken: () async => 'tok',
        client: mock,
      ));

      try {
        await api.likeItem('q-1');
        fail('Devait lever ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 501);
        expect(estBientotDisponible(e), isTrue);
      }
    });
  });
}
