import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiClient injection des headers', () {
    test('injecte x-language, x-device-id, x-platform, Authorization sur GET', () async {
      late http.Request requeteCapturee;
      final mock = MockClient((req) async {
        requeteCapturee = req;
        return http.Response('{"ok":true}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'bm',
        resoudreToken: () async => 'token-123',
        client: mock,
      );

      final reponse = await client.get('/ping');

      expect(reponse, {'ok': true});
      expect(requeteCapturee.headers['x-language'], 'bm');
      expect(requeteCapturee.headers['x-platform'], isNotEmpty);
      expect(requeteCapturee.headers['x-device-id'], isNotEmpty);
      expect(requeteCapturee.headers['x-device-name'], isNotEmpty);
      expect(requeteCapturee.headers['Authorization'], 'Bearer token-123');
    });

    test('injecte x-language-audio quand le résolveur est fourni', () async {
      late http.Request requeteCapturee;
      final mock = MockClient((req) async {
        requeteCapturee = req;
        return http.Response('{}', 200);
      });
      final client = ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreLangueAudio: () => 'bm',
        resoudreToken: () async => null,
        client: mock,
      );
      await client.get('/mobile/feed');
      expect(requeteCapturee.headers['x-language'], 'fr');
      expect(requeteCapturee.headers['x-language-audio'], 'bm');
    });

    test('n\'injecte pas x-language-audio quand le résolveur retourne null', () async {
      late http.Request requeteCapturee;
      final mock = MockClient((req) async {
        requeteCapturee = req;
        return http.Response('{}', 200);
      });
      final client = ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreLangueAudio: () => null,
        resoudreToken: () async => null,
        client: mock,
      );
      await client.get('/ping');
      expect(requeteCapturee.headers.containsKey('x-language-audio'), isFalse);
    });

    test('n\'injecte pas Authorization quand le token est null', () async {
      late http.Request requeteCapturee;
      final mock = MockClient((req) async {
        requeteCapturee = req;
        return http.Response('{}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreToken: () async => null,
        client: mock,
      );

      await client.get('/platform/features');
      expect(requeteCapturee.headers.containsKey('Authorization'), isFalse);
      expect(requeteCapturee.headers['x-language'], 'fr');
    });

    test('reflète un changement de langue à chaque requête', () async {
      final languesVues = <String>[];
      final mock = MockClient((req) async {
        languesVues.add(req.headers['x-language'] ?? '');
        return http.Response('{}', 200);
      });

      var langue = 'fr';
      final client = ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => langue,
        resoudreToken: () async => null,
        client: mock,
      );

      await client.get('/a');
      langue = 'sus';
      await client.get('/b');
      langue = 'ful';
      await client.get('/c');

      expect(languesVues, ['fr', 'sus', 'ful']);
    });

    test('lève ApiException avec statusCode et message sur 4xx', () async {
      final mock = MockClient((req) async {
        return http.Response(
          '{"statusCode":404,"message":"Utilisateur introuvable","error":"Not Found","code":"USER_NOT_FOUND"}',
          404,
        );
      });

      final client = ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreToken: () async => null,
        client: mock,
      );

      await expectLater(
        () => client.get('/mobile-auth/login'),
        throwsA(predicate((e) {
          return e.toString().contains('404') &&
              e.toString().contains('USER_NOT_FOUND') &&
              e.toString().contains('Utilisateur introuvable');
        })),
      );
    });

    test('ajoute les query params en encodant correctement', () async {
      late http.Request requeteCapturee;
      final mock = MockClient((req) async {
        requeteCapturee = req;
        return http.Response('{}', 200);
      });

      final client = ApiClient(
        baseUrl: 'https://exemple.test/api',
        resoudreLangue: () => 'fr',
        resoudreToken: () async => null,
        client: mock,
      );

      await client.get('/mobile/feed', query: {'lang': 'bm', 'limit': 20});
      expect(requeteCapturee.url.queryParameters['lang'], 'bm');
      expect(requeteCapturee.url.queryParameters['limit'], '20');
    });
  });
}
