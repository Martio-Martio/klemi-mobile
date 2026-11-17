import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Providers/app_state.dart';
import 'package:klemi/Repositories/profile_repository.dart';
import 'package:klemi/Services/profile_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProfileApi apiAvec(http.Response Function(http.BaseRequest, int) handler) {
    var appels = 0;
    final mock = MockClient((req) async => handler(req, appels++));
    return ProfileApi(ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => 'tok',
      client: mock,
    ));
  }

  test('charger pousse points/forfait/préférences dans AppState', () async {
    final api = apiAvec((_, _) {
      return http.Response(
        jsonEncode({
          'profil': {'nom': 'A', 'langue': 'en', 'langueAudio': 'ful'},
          'progression': {'points': 999, 'niveau': 7},
          'forfait': {'nom': 'Premium', 'generationsRestantes': 50},
          'preferences': {'notifStreak': false, 'lectureAutoPodcast': false},
        }),
        200,
      );
    });
    final repo = ProfileRepository(api: api);
    final etat = AppState();

    await repo.charger(etat);
    expect(etat.points, 999);
    expect(etat.niveau, 7);
    expect(etat.forfait, 'Premium');
    expect(etat.generationsRestantes, 50);
    expect(etat.langue.id, 'en');
    expect(etat.langueAudio.id, 'ful');
    expect(etat.notifStreak, isFalse);
    expect(etat.lectureAutoPodcast, isFalse);
    expect(repo.enChargement, isFalse);
  });

  test('pingStreakSiNecessaire : premier appel du jour → POST, deuxième no-op', () async {
    var pings = 0;
    final api = apiAvec((r, _) {
      if (r.url.path.endsWith('/streak/ping')) pings++;
      return http.Response('', 204);
    });
    final repo = ProfileRepository(api: api);

    await repo.pingStreakSiNecessaire();
    await repo.pingStreakSiNecessaire();
    expect(pings, 1);
  });

  test('mettreAJourPreference optimiste : applique localement, PATCH en arrière-plan', () async {
    var patchs = 0;
    Map<String, dynamic>? dernierPatch;
    final api = apiAvec((r, _) {
      if (r is http.Request) {
        patchs++;
        dernierPatch = jsonDecode(r.body) as Map<String, dynamic>;
      }
      return http.Response('{}', 200);
    });
    final repo = ProfileRepository(api: api);

    var local = true;
    final ok = await repo.mettreAJourPreference(
      patch: {'notifStreak': false},
      appliquerLocal: () => local = false,
      rollbackLocal: () => local = true,
    );
    expect(ok, isTrue);
    expect(local, isFalse);
    expect(patchs, 1);
    expect(dernierPatch, {'notifStreak': false});
  });

  test('mettreAJourPreference : si l\'API répond 500, rollback appelé', () async {
    final api = apiAvec((r, _) {
      if (r.url.path.endsWith('/preferences')) {
        return http.Response(jsonEncode({'statusCode': 500, 'message': 'boom'}), 500);
      }
      return http.Response('{}', 200);
    });
    final repo = ProfileRepository(api: api);

    var local = true;
    final ok = await repo.mettreAJourPreference(
      patch: {'notifStreak': false},
      appliquerLocal: () => local = false,
      rollbackLocal: () => local = true,
    );
    expect(ok, isFalse);
    expect(local, isTrue); // rollback effectif
  });
}
