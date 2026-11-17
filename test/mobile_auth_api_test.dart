import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Configuration/matieres.dart';
import 'package:klemi/Services/api_exception.dart';
import 'package:klemi/Services/mobile_auth_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  ApiClient clientAvecReponses(List<Map<String, dynamic>> scripts) {
    var i = 0;
    final mock = MockClient((req) async {
      final script = scripts[i++];
      return http.Response(jsonEncode(script['body']), script['status'] as int);
    });
    return ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => null,
      client: mock,
    );
  }

  test('signup envoie le bon payload et parse userId + tempToken', () async {
    late http.Request requete;
    final mock = MockClient((req) async {
      requete = req;
      return http.Response(
        jsonEncode({'userId': 'uid-1', 'tempToken': 'tmp-abc'}),
        201,
      );
    });
    final client = ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'bm',
      resoudreToken: () async => null,
      client: mock,
    );
    final api = MobileAuthApi(client);

    final res = await api.signup(
      phone: ' 70 00 00 00 ',
      role: RoleInscription.eleve,
      nom: 'Aminata Traoré',
      niveauEtudes: NiveauEtudes.lycee,
      classe: 'Terminale D',
      etablissement: 'Lycée Askia',
      langue: 'bm',
    );

    expect(res.tempToken, 'tmp-abc');
    expect(res.userId, 'uid-1');
    expect(requete.url.path, '/api/mobile-auth/signup');
    final body = jsonDecode(requete.body) as Map<String, dynamic>;
    expect(body['phone'], '70 00 00 00'); // trim appliqué
    expect(body['role'], 'eleve');
    expect(body['nom'], 'Aminata Traoré');
    expect(body['niveauEtudes'], 'lycee');
    expect(body['classe'], 'Terminale D');
    expect(body['etablissement'], 'Lycée Askia');
    expect(body['langue'], 'bm');
    expect(requete.headers['x-language'], 'bm');
  });

  test('signup omet etablissement quand null ou vide', () async {
    late http.Request requete;
    final mock = MockClient((req) async {
      requete = req;
      return http.Response(jsonEncode({'tempToken': 'x'}), 201);
    });
    final api = MobileAuthApi(ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => null,
      client: mock,
    ));

    await api.signup(
      phone: '70000000',
      role: RoleInscription.enseignant,
      nom: 'Mamadou',
      niveauEtudes: NiveauEtudes.formation,
      classe: '',
      etablissement: '   ',
      langue: 'fr',
    );
    final body = jsonDecode(requete.body) as Map<String, dynamic>;
    expect(body.containsKey('etablissement'), isFalse);
  });

  test('login propage USER_NOT_FOUND via ApiException.code', () async {
    final client = clientAvecReponses([
      {'status': 404, 'body': {'statusCode': 404, 'message': 'Utilisateur introuvable', 'code': 'USER_NOT_FOUND'}},
    ]);
    final api = MobileAuthApi(client);

    await expectLater(
      () => api.login('70000000'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 404)
          .having((e) => e.code, 'code', 'USER_NOT_FOUND')),
    );
  });

  test('connexionGoogle envoie l\'idToken et parse accessToken, refreshToken et user', () async {
    late http.Request requete;
    final mock = MockClient((req) async {
      requete = req;
      return http.Response(
        jsonEncode({
          'accessToken': 'at-g',
          'refreshToken': 'rt-g',
          'user': {'id': 'u-g', 'nom': 'Awa', 'role': 'STUDENT'},
        }),
        200,
      );
    });
    final api = MobileAuthApi(ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => null,
      client: mock,
    ));

    final session = await api.connexionGoogle('id-token-google');

    expect(requete.url.path, '/api/mobile-auth/google');
    final body = jsonDecode(requete.body) as Map<String, dynamic>;
    expect(body['idToken'], 'id-token-google');
    expect(session.accessToken, 'at-g');
    expect(session.refreshToken, 'rt-g');
    expect(session.user?['nom'], 'Awa');
    expect(session.user?['role'], 'STUDENT');
  });

  test('connexionGoogle propage un jeton refusé', () async {
    final client = clientAvecReponses([
      {
        'status': 401,
        'body': {
          'statusCode': 401,
          'message': 'Jeton Google invalide ou expiré.',
          'code': 'GOOGLE_TOKEN_INVALID',
        },
      },
    ]);
    final api = MobileAuthApi(client);

    await expectLater(
      () => api.connexionGoogle('mauvais'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 401)
          .having((e) => e.code, 'code', 'GOOGLE_TOKEN_INVALID')
          .having((e) => e.message, 'message', 'Jeton Google invalide ou expiré.')),
    );
  });

  test('verifyOtp parse accessToken, refreshToken et user', () async {
    final client = clientAvecReponses([
      {
        'status': 200,
        'body': {
          'accessToken': 'at-1',
          'refreshToken': 'rt-1',
          'user': {'id': 'u1', 'nom': 'Aminata'},
        }
      },
    ]);
    final api = MobileAuthApi(client);

    final session = await api.verifyOtp(tempToken: 'tmp', code: '123456');
    expect(session.accessToken, 'at-1');
    expect(session.refreshToken, 'rt-1');
    expect(session.user?['nom'], 'Aminata');
  });

  test('refresh renvoie une nouvelle session', () async {
    final client = clientAvecReponses([
      {'status': 200, 'body': {'accessToken': 'at-2', 'refreshToken': 'rt-2'}},
    ]);
    final api = MobileAuthApi(client);

    final session = await api.refresh('old-rt');
    expect(session.accessToken, 'at-2');
    expect(session.refreshToken, 'rt-2');
    expect(session.user, isNull);
  });

  test('resendOtp et logout se contentent d\'un POST sans parser de corps', () async {
    var appels = <String>[];
    final mock = MockClient((req) async {
      appels.add(req.url.path);
      return http.Response('', 204);
    });
    final api = MobileAuthApi(ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => 'at',
      client: mock,
    ));

    await api.resendOtp('tmp');
    await api.logout();

    expect(appels, ['/api/mobile-auth/resend-otp', '/api/mobile-auth/logout']);
  });
}
