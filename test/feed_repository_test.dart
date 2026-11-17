import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Repositories/feed_repository.dart';
import 'package:klemi/Services/mobile_feed_api.dart';

Map<String, dynamic> _quizJson(String id) => {
      'id': id,
      'type': 'quiz',
      'titre': 'Q $id',
      'langue': 'fr',
      'auteur': {'pseudo': 'p', 'etablissement': 'e', 'initiales': 'i'},
      'legende': '',
      'hashtags': [],
      'likes': 0,
      'matiere': 'Maths',
      'numero': 1,
      'total': 1,
      'reponses': ['a', 'b'],
      'bonneReponse': 0,
      'explication': 'ok',
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  MobileFeedApi apiAvecPages(List<Map<String, dynamic>> pages) {
    var i = 0;
    final mock = MockClient((r) async {
      final page = pages[i++];
      return http.Response.bytes(
        utf8.encode(jsonEncode(page)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    return MobileFeedApi(ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => null,
      client: mock,
    ));
  }

  test('amorcer charge la première page et met en cache', () async {
    final api = apiAvecPages([
      {
        'items': [_quizJson('a'), _quizJson('b')],
        'nextCursor': 'c-1',
      }
    ]);
    final repo = FeedRepository(api: api, utiliserMock: false);

    final etat = await repo.amorcer(TabFeed.pourToi);
    expect(etat.items.length, 2);
    expect(etat.curseurSuivant, 'c-1');
    expect(etat.fini, isFalse);

    // Second appel : pas de nouvel appel réseau, sinon pages[1] serait lu.
    final rebelote = await repo.amorcer(TabFeed.pourToi);
    expect(rebelote.items.length, 2);
  });

  test('pageSuivante concatène et marque fini quand nextCursor null', () async {
    final api = apiAvecPages([
      {
        'items': [_quizJson('a')],
        'nextCursor': 'c-1',
      },
      {
        'items': [_quizJson('b'), _quizJson('c')],
        'nextCursor': null,
      },
    ]);
    final repo = FeedRepository(api: api, utiliserMock: false);
    await repo.amorcer(TabFeed.pourToi);
    final apresPage2 = await repo.pageSuivante(TabFeed.pourToi);
    expect(apresPage2.items.length, 3);
    expect(apresPage2.fini, isTrue);
    expect(apresPage2.curseurSuivant, isNull);
  });

  test('invaliderTout vide le cache et notifie', () async {
    final api = apiAvecPages([
      {'items': [_quizJson('a')], 'nextCursor': null},
    ]);
    final repo = FeedRepository(api: api, utiliserMock: false);
    await repo.amorcer(TabFeed.pourToi);
    expect(repo.etat(TabFeed.pourToi).items.length, 1);

    var notifie = false;
    repo.addListener(() => notifie = true);
    repo.invaliderTout();
    expect(repo.etat(TabFeed.pourToi).items.length, 0);
    expect(notifie, isTrue);
  });

  test('assurerContenu : skip si déjà en cache', () async {
    final api = apiAvecPages([
      {
        'items': [_quizJson('a')],
        'nextCursor': null,
      },
    ]);
    final repo = FeedRepository(api: api, utiliserMock: false);
    await repo.amorcer(TabFeed.pourToi);
    final res = await repo.assurerContenu('a');
    expect(res, isNotNull);
    expect(res!.id, 'a');
    // Le mock a été pré-rempli avec 1 page uniquement : si assurerContenu
    // avait fetchOne, pages[1] n'existerait pas et on aurait crashé.
  });

  test('assurerContenu : fetchOne et prepend quand absent', () async {
    var i = 0;
    final mock = MockClient((r) async {
      i++;
      if (i == 1) {
        // amorce
        return http.Response.bytes(
          utf8.encode(jsonEncode({'items': [_quizJson('x')], 'nextCursor': null})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      // fetchOne
      expect(r.url.path, '/api/mobile/feed/nouveau');
      return http.Response.bytes(
        utf8.encode(jsonEncode(_quizJson('nouveau'))),
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
    final repo = FeedRepository(api: api, utiliserMock: false);
    await repo.amorcer(TabFeed.pourToi);
    final res = await repo.assurerContenu('nouveau');
    expect(res, isNotNull);
    expect(res!.id, 'nouveau');
    // L'item est inséré en tête du cache.
    expect(repo.etat(TabFeed.pourToi).items.first.id, 'nouveau');
    expect(repo.etat(TabFeed.pourToi).items.length, 2);
  });

  test('assurerContenu : retourne null si fetchOne échoue (404/500)', () async {
    var i = 0;
    final mock = MockClient((r) async {
      i++;
      if (i == 1) {
        return http.Response.bytes(
          utf8.encode(jsonEncode({'items': [_quizJson('x')], 'nextCursor': null})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(jsonEncode({'statusCode': 404, 'message': 'absent'}), 404);
    });
    final api = MobileFeedApi(ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => null,
      client: mock,
    ));
    final repo = FeedRepository(api: api, utiliserMock: false);
    await repo.amorcer(TabFeed.pourToi);
    final res = await repo.assurerContenu('disparu');
    expect(res, isNull);
    // Le cache n'a pas été pollué.
    expect(repo.etat(TabFeed.pourToi).items.length, 1);
  });

  test('rafraichir recharge depuis zéro', () async {
    final api = apiAvecPages([
      {'items': [_quizJson('a')], 'nextCursor': null},
      {'items': [_quizJson('b'), _quizJson('c')], 'nextCursor': null},
    ]);
    final repo = FeedRepository(api: api, utiliserMock: false);
    await repo.amorcer(TabFeed.pourToi);
    expect(repo.etat(TabFeed.pourToi).items.first.id, 'a');

    final apres = await repo.rafraichir(TabFeed.pourToi);
    expect(apres.items.length, 2);
    expect(apres.items.first.id, 'b');
  });
}
