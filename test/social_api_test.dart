import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Models/social.dart';
import 'package:klemi/Services/api_exception.dart';
import 'package:klemi/Services/social_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ApiClient clientAvec(http.Response Function(http.BaseRequest) handler) {
    final mock = MockClient((req) async => handler(req));
    return ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => 'tok',
      client: mock,
    );
  }

  group('SocialApi — creators & follows', () {
    test('getCreator parse createur + contenus + suivi', () async {
      final api = SocialApi(clientAvec((r) {
        expect(r.url.path, '/api/mobile/creators/c-1');
        return http.Response(
          jsonEncode({
            'createur': {
              'id': 'c-1',
              'pseudo': '@prof',
              'nom': 'Prof Koné',
              'etablissement': 'Lycée Askia',
              'initiales': 'PK',
              'abonnes': 1250,
              'contenus': 42,
              'bio': 'Enseignant d\'histoire.',
            },
            'suivi': true,
            'contenus': [
              {
                'id': 'q-1',
                'type': 'quiz',
                'titre': 'Tombouctou',
                'meta': 'Quiz · 10 questions · FR',
                'createurId': 'c-1',
                'publieLe': '2026-11-15T08:00:00Z',
              }
            ],
          }),
          200,
        );
      }));
      final res = await api.getCreator('c-1');
      expect(res.createur.id, 'c-1');
      expect(res.createur.abonnes, 1250);
      expect(res.suivi, isTrue);
      expect(res.contenus.length, 1);
      expect(res.contenus.first.titre, 'Tombouctou');
    });

    test('follow/unfollow envoient les bonnes méthodes HTTP', () async {
      final appels = <String>[];
      final api = SocialApi(clientAvec((r) {
        appels.add('${r.method} ${r.url.path}');
        return http.Response('', 204);
      }));
      await api.follow('c-1');
      await api.unfollow('c-1');
      expect(appels, [
        'POST /api/mobile/follows/c-1',
        'DELETE /api/mobile/follows/c-1',
      ]);
    });

    test('getFollowing parse le set d\'IDs', () async {
      final api = SocialApi(clientAvec((_) {
        return http.Response(
          jsonEncode({
            'items': [
              {'creatorId': 'c-1'},
              {'creatorId': 'c-2'},
              {'id': 'c-3'},
            ]
          }),
          200,
        );
      }));
      final ids = await api.getFollowing();
      expect(ids, {'c-1', 'c-2', 'c-3'});
    });
  });

  group('SocialApi — likes & comments', () {
    test('likeItem/unlikeItem envoient POST/DELETE sur le bon chemin', () async {
      final appels = <String>[];
      final api = SocialApi(clientAvec((r) {
        appels.add('${r.method} ${r.url.path}');
        return http.Response('', 204);
      }));
      await api.likeItem('q-1');
      await api.unlikeItem('q-1');
      expect(appels, [
        'POST /api/mobile/content/q-1/like',
        'DELETE /api/mobile/content/q-1/like',
      ]);
    });

    test('listComments parse items + nextCursor + total', () async {
      final api = SocialApi(clientAvec((r) {
        expect(r.url.path, '/api/mobile/content/q-1/comments');
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'c1', 'auteur': '@a', 'initiales': 'A', 'texte': 'Bravo', 'ilYA': '1h'},
              {'id': 'c2', 'auteur': '@b', 'initiales': 'B', 'texte': 'Merci', 'ilYA': '45m', 'likes': 3},
            ],
            'nextCursor': 'cur-2',
            'total': 42,
          }),
          200,
        );
      }));
      final page = await api.listComments('q-1');
      expect(page.commentaires.length, 2);
      expect(page.total, 42);
      expect(page.curseurSuivant, 'cur-2');
      expect(page.commentaires[1].likes, 3);
    });

    test('postComment envoie texte + éventuel parentId', () async {
      late http.Request req;
      final api = SocialApi(clientAvec((r) {
        req = r as http.Request;
        return http.Response(
          jsonEncode({
            'id': 'c-new',
            'auteur': '@me',
            'initiales': 'M',
            'texte': 'Super',
            'ilYA': 'à l\'instant',
          }),
          201,
        );
      }));
      final c = await api.postComment('q-1', 'Super', parentId: 'c-root');
      expect(req.url.path, '/api/mobile/content/q-1/comments');
      expect(jsonDecode(req.body), {'texte': 'Super', 'parentId': 'c-root'});
      expect(c.id, 'c-new');
      expect(c.auteur, '@me');
    });
  });

  group('SocialApi — notifications & push', () {
    test('listNotifications parse items + nonLues', () async {
      final api = SocialApi(clientAvec((_) {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 'n1',
                'type': 'NEW_CONTENT_FROM_FOLLOWED_CREATOR',
                'titre': 'Nouveau contenu',
                'detail': 'Prof Koné vient de publier.',
                'ilYA': '5m',
                'isRead': false,
              },
              {
                'id': 'n2',
                'type': 'STREAK_REMINDER',
                'titre': 'Garde ta série !',
                'detail': 'Encore un quiz avant minuit.',
                'ilYA': '2h',
                'lue': true,
              }
            ],
            'nextCursor': null,
            'nonLues': 1,
          }),
          200,
        );
      }));
      final page = await api.listNotifications();
      expect(page.notifications.length, 2);
      expect(page.nonLues, 1);
      expect(page.notifications[0].type, TypeNotification.nouveauContenu);
      expect(page.notifications[1].type, TypeNotification.streak);
      expect(page.notifications[0].lue, isFalse);
      expect(page.notifications[1].lue, isTrue);
    });

    test('markNotificationRead PATCH sur le bon chemin', () async {
      late http.Request req;
      final api = SocialApi(clientAvec((r) {
        req = r as http.Request;
        return http.Response('', 204);
      }));
      await api.markNotificationRead('n-1');
      expect(req.method, 'PATCH');
      expect(req.url.path, '/api/mobile/me/notifications/n-1/read');
    });

    test('registerPushToken envoie token + platform', () async {
      late http.Request req;
      final api = SocialApi(clientAvec((r) {
        req = r as http.Request;
        return http.Response('{}', 200);
      }));
      await api.registerPushToken(token: 'fcm-xyz', platform: 'ios');
      expect(req.url.path, '/api/mobile/me/push-token');
      expect(jsonDecode(req.body), {'token': 'fcm-xyz', 'platform': 'ios'});
    });

    test('unregisterPushToken DELETE avec body token', () async {
      late http.Request req;
      final api = SocialApi(clientAvec((r) {
        req = r as http.Request;
        return http.Response('', 204);
      }));
      await api.unregisterPushToken('fcm-xyz');
      expect(req.method, 'DELETE');
      expect(jsonDecode(req.body), {'token': 'fcm-xyz'});
    });
  });

  group('SocialApi — erreurs', () {
    test('listComments propagate ApiException sur 500', () async {
      final api = SocialApi(clientAvec((_) {
        return http.Response(jsonEncode({'statusCode': 500, 'message': 'boom'}), 500);
      }));
      await expectLater(
        () => api.listComments('q-1'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
