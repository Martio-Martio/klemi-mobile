import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Services/api_exception.dart';
import 'package:klemi/Services/creation_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ApiClient clientAvecReponse(
    http.Response Function(http.BaseRequest req) handler, {
    String? langue,
    String? langueAudio,
  }) {
    final mock = MockClient((req) async => handler(req));
    return ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => langue ?? 'fr',
      resoudreLangueAudio: langueAudio == null ? null : () => langueAudio,
      resoudreToken: () async => 'tok',
      client: mock,
    );
  }

  group('CreationApi — langue propagée au body', () {
    test('genererQuizDepuisTexte envoie language=fr dans le body', () async {
      late http.Request req;
      final client = clientAvecReponse((r) {
        req = r as http.Request;
        return http.Response(jsonEncode({'jobId': 'j1'}), 201);
      }, langue: 'fr');
      final api = CreationApi(client);

      final job = await api.genererQuizDepuisTexte(
        const SourceTexte('Histoire du Mali'),
        language: 'fr',
        options: const OptionsCreation(nombreQuestions: 15),
      );
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['language'], 'fr');
      expect(body['texte'], 'Histoire du Mali');
      expect(body['type'], 'quiz');
      expect(body['numberOfQuestions'], '15');
      expect(req.headers['x-language'], 'fr');
      expect(job.jobId, 'j1');
    });

    test('genererPodcast(SourceTexte) envoie language=bm (langue audio)', () async {
      late http.Request req;
      final client = clientAvecReponse((r) {
        req = r as http.Request;
        return http.Response(jsonEncode({'jobId': 'p1'}), 201);
      }, langue: 'fr', langueAudio: 'bm');
      final api = CreationApi(client);

      await api.genererPodcast(
        const SourceTexte('Soundiata Keita'),
        language: 'bm',
        options: const OptionsCreation(dureePodcast: 'moyen'),
      );
      expect(req.url.path, '/api/podcasts');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body['language'], 'bm');
      expect(body['source'], 'TEXT');
      expect(body['texte'], 'Soundiata Keita');
      expect(body['longueur'], 'moyen');
      // Le header x-language-audio est bien propagé.
      expect(req.headers['x-language-audio'], 'bm');
    });

    test('genererPodcast(SourceImages) → ApiException locale avec code dédié', () async {
      final api = CreationApi(clientAvecReponse(
        (_) => http.Response('{}', 200),
      ));
      await expectLater(
        () => api.genererPodcast(
          SourceImages(const []),
          language: 'bm',
          options: const OptionsCreation(),
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', 'PODCAST_IMAGES_NON_SUPPORTE')),
      );
    });
  });

  group('CreationApi — propagation des erreurs backend', () {
    test('400 UNSUPPORTED_LANGUAGE → ApiException.code préservé', () async {
      final api = CreationApi(clientAvecReponse((_) => http.Response(
            jsonEncode({
              'statusCode': 400,
              'code': 'UNSUPPORTED_LANGUAGE',
              'message': 'Langue bm non supportée pour les quiz.'
            }),
            400,
          )));
      try {
        await api.genererQuizDepuisTexte(
          const SourceTexte('x'),
          language: 'bm',
          options: const OptionsCreation(),
        );
        fail('Devait lever ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 400);
        expect(e.code, 'UNSUPPORTED_LANGUAGE');
        expect(e.message, contains('bm'));
      }
    });

    test('402 QUOTA_DEPASSE → ApiException propagée', () async {
      final api = CreationApi(clientAvecReponse((_) => http.Response(
            jsonEncode(
                {'statusCode': 402, 'code': 'QUOTA_DEPASSE', 'message': 'Quota atteint.'}),
            402,
          )));
      await expectLater(
        () => api.genererFicheDepuisTexte(
          const SourceTexte('x'),
          language: 'fr',
          options: const OptionsCreation(),
        ),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 402)
            .having((e) => e.code, 'code', 'QUOTA_DEPASSE')),
      );
    });
  });

  group('CreationApi — polling job', () {
    test('statutJob done avec item → feed item parsé', () async {
      final api = CreationApi(clientAvecReponse((r) {
        expect(r.url.path, '/api/files/upload-status/j-1');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'status': 'done',
            'progress': 100,
            'item': {
              'id': 'q-new',
              'type': 'quiz',
              'titre': 'Nouveau quiz',
              'langue': 'fr',
              'auteur': {'pseudo': 'IA', 'etablissement': '', 'initiales': 'I'},
              'legende': '',
              'hashtags': [],
              'likes': 0,
              'matiere': 'Maths',
              'numero': 1,
              'total': 1,
              'reponses': ['a', 'b'],
              'bonneReponse': 0,
              'explication': '',
            }
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));

      final statut = await api.statutJob('j-1');
      expect(statut.termine, isTrue);
      expect(statut.pourcentage, 100);
      expect(statut.item, isNotNull);
      expect(statut.item!.titre, 'Nouveau quiz');
    });

    test('statutJob pending → termine=false', () async {
      final api = CreationApi(clientAvecReponse((_) {
        return http.Response(
          jsonEncode({'status': 'processing', 'progress': 42, 'message': 'En cours'}),
          200,
        );
      }));
      final s = await api.statutJob('j-2');
      expect(s.etat, 'processing');
      expect(s.termine, isFalse);
      expect(s.pourcentage, 42);
      expect(s.message, 'En cours');
    });
  });
}
