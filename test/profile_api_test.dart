import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Services/profile_api.dart';

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

  group('ProfileApi.chargerProfil', () {
    test('parse les 4 sous-objets du payload', () async {
      final api = ProfileApi(clientAvec((r) {
        expect(r.url.path, '/api/mobile/me');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'profil': {
              'nom': 'Aminata Traoré',
              'langue': 'fr',
              'langueAudio': 'bm',
              'niveauEtudes': 'lycee',
              'classe': 'Terminale D',
              'etablissement': 'Lycée Askia',
            },
            'progression': {
              'points': 1500,
              'serieJours': 7,
              'niveau': 5,
              'nomNiveau': 'Djeli',
              'pointsNiveauSuivant': 2000,
            },
            'forfait': {'nom': 'Premium', 'generationsRestantes': 20},
            'preferences': {
              'notifStreak': false,
              'telechargerWifiSeulement': true,
            },
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));

      final profil = await api.chargerProfil();
      expect(profil.profil['nom'], 'Aminata Traoré');
      expect(profil.profil['langue'], 'fr');
      expect(profil.profil['langueAudio'], 'bm');
      expect(profil.progression['points'], 1500);
      expect(profil.forfait['nom'], 'Premium');
      expect(profil.preferences['notifStreak'], false);
    });

    test('tolère les sous-objets absents (nouveau user)', () async {
      final api = ProfileApi(clientAvec((_) {
        return http.Response(jsonEncode({'profil': {'nom': 'Nouveau'}}), 200);
      }));
      final p = await api.chargerProfil();
      expect(p.profil['nom'], 'Nouveau');
      expect(p.progression, isEmpty);
      expect(p.forfait, isEmpty);
      expect(p.preferences, isEmpty);
    });
  });

  group('ProfileApi.mettreAJourProfil / preferences', () {
    test('mettreAJourProfil envoie un PATCH avec les champs transmis', () async {
      late http.Request req;
      final api = ProfileApi(clientAvec((r) {
        req = r as http.Request;
        return http.Response('{}', 200);
      }));
      await api.mettreAJourProfil({'langue': 'en', 'classe': '2nde'});
      expect(req.method, 'PATCH');
      expect(req.url.path, '/api/mobile/me/profile');
      expect(jsonDecode(req.body), {'langue': 'en', 'classe': '2nde'});
    });

    test('mettreAJourPreferences envoie PATCH partiel', () async {
      late http.Request req;
      final api = ProfileApi(clientAvec((r) {
        req = r as http.Request;
        return http.Response('{}', 200);
      }));
      await api.mettreAJourPreferences({'notifStreak': false});
      expect(req.url.path, '/api/mobile/me/preferences');
      expect(jsonDecode(req.body), {'notifStreak': false});
    });
  });

  group('ProfileApi.chargerQuota / pingStreak / biblio', () {
    test('chargerQuota parse restantes + forfait', () async {
      final api = ProfileApi(clientAvec((_) {
        return http.Response(
          jsonEncode({
            'restantes': 7,
            'resetAt': '2026-11-18T00:00:00Z',
            'forfait': 'Student',
          }),
          200,
        );
      }));
      final q = await api.chargerQuota();
      expect(q.restantes, 7);
      expect(q.forfait, 'Student');
      expect(q.resetAt?.year, 2026);
    });

    test('pingStreak fait un POST sans body', () async {
      late http.Request req;
      final api = ProfileApi(clientAvec((r) {
        req = r as http.Request;
        return http.Response('', 204);
      }));
      await api.pingStreak();
      expect(req.method, 'POST');
      expect(req.url.path, '/api/mobile/me/streak/ping');
    });

    test('chargerBiblio parse items + nextCursor', () async {
      final api = ProfileApi(clientAvec((r) {
        expect(r.url.queryParameters['limit'], '20');
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'items': [
              {
                'savedAt': '2026-11-16T10:00:00Z',
                'offlineAvailable': true,
                'item': {
                  'id': 'q-1',
                  'type': 'quiz',
                  'titre': 'Titre',
                  'langue': 'fr',
                  'auteur': {'pseudo': 'p', 'etablissement': 'e', 'initiales': 'i'},
                  'legende': '',
                  'hashtags': [],
                  'likes': 0,
                  'matiere': 'M',
                  'numero': 1,
                  'total': 1,
                  'reponses': ['a', 'b'],
                  'bonneReponse': 0,
                  'explication': '',
                }
              }
            ],
            'nextCursor': 'c-2',
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }));
      final p = await api.chargerBiblio();
      expect(p.entrees.length, 1);
      expect(p.entrees.first.item.id, 'q-1');
      expect(p.entrees.first.disponibleHorsLigne, isTrue);
      expect(p.entrees.first.sauvegardeLe?.year, 2026);
      expect(p.curseurSuivant, 'c-2');
    });
  });
}
