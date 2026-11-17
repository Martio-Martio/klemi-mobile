import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Services/api_exception.dart';
import 'package:klemi/Services/config_google.dart';
import 'package:klemi/Services/connexion_google.dart';
import 'package:klemi/Services/mobile_auth_api.dart';

const _clientIos = '1234567890-abc.apps.googleusercontent.com';
const _schemeIos = 'com.googleusercontent.apps.1234567890-abc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    lecteurFaitsConfigGoogle = lireFaitsConfigGoogleNatif;
  });

  group('schemeInverseDepuisClientId', () {
    test('dérive le REVERSED_CLIENT_ID d\'un client iOS', () {
      expect(schemeInverseDepuisClientId(_clientIos), _schemeIos);
      expect(schemeInverseDepuisClientId('  $_clientIos  '), _schemeIos);
    });

    test('refuse un identifiant absent ou d\'une autre forme', () {
      expect(schemeInverseDepuisClientId(null), isNull);
      expect(schemeInverseDepuisClientId(''), isNull);
      expect(schemeInverseDepuisClientId('pas-un-client'), isNull);
      expect(
        schemeInverseDepuisClientId('.apps.googleusercontent.com'),
        isNull,
      );
    });
  });

  group('evaluerConfigGoogle', () {
    test('iOS sans GIDClientID interdit l\'appel au SDK', () {
      final verdict = evaluerConfigGoogle(
        const FaitsConfigGoogle(plateforme: PlateformeMobile.ios),
      );
      expect(verdict.appelSdkAutorise, isFalse);
      expect(verdict.message, contains('GIDClientID'));
      expect(verdict.message, contains('REVERSED_CLIENT_ID'));
    });

    test(
      'iOS avec client mais sans schéma d\'URL interdit l\'appel au SDK',
      () {
        final verdict = evaluerConfigGoogle(
          const FaitsConfigGoogle(
            plateforme: PlateformeMobile.ios,
            gidClientId: _clientIos,
          ),
        );
        expect(verdict.appelSdkAutorise, isFalse);
        expect(verdict.message, contains('REVERSED_CLIENT_ID'));
      },
    );

    test('iOS avec GIDClientID et le schéma correspondant autorise le SDK', () {
      final verdict = evaluerConfigGoogle(
        const FaitsConfigGoogle(
          plateforme: PlateformeMobile.ios,
          gidClientId: _clientIos,
          schemesUrl: [_schemeIos],
        ),
      );
      expect(verdict.appelSdkAutorise, isTrue);
      expect(verdict.message, isEmpty);
    });

    test('Android sans client web interdit l\'appel au SDK', () {
      final verdict = evaluerConfigGoogle(
        const FaitsConfigGoogle(plateforme: PlateformeMobile.android),
      );
      expect(verdict.appelSdkAutorise, isFalse);
      expect(verdict.message, contains('oauth_client'));
    });

    test('Android avec default_web_client_id autorise le SDK', () {
      final verdict = evaluerConfigGoogle(
        const FaitsConfigGoogle(
          plateforme: PlateformeMobile.android,
          clientWebAndroidPresent: true,
        ),
      );
      expect(verdict.appelSdkAutorise, isTrue);
    });
  });

  test(
    'obtenirIdTokenGoogle s\'arrête avant le SDK si la config iOS est absente',
    () async {
      lecteurFaitsConfigGoogle = () async =>
          const FaitsConfigGoogle(plateforme: PlateformeMobile.ios);

      await expectLater(
        obtenirIdTokenGoogle(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'GOOGLE_NON_CONFIGURE')
              .having((e) => e.message, 'message', contains('GIDClientID')),
        ),
      );
    },
  );

  test(
    'obtenirIdTokenGoogle s\'arrête avant le SDK si oauth_client Android est vide',
    () async {
      lecteurFaitsConfigGoogle = () async =>
          const FaitsConfigGoogle(plateforme: PlateformeMobile.android);

      await expectLater(
        obtenirIdTokenGoogle(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'GOOGLE_NON_CONFIGURE')
              .having((e) => e.message, 'message', contains('oauth_client')),
        ),
      );
    },
  );

  test(
    'ConnexionGoogle envoie l\'idToken à l\'API puis ouvre la session',
    () async {
      late http.Request requete;
      final mock = MockClient((req) async {
        requete = req;
        return http.Response(
          jsonEncode({
            'accessToken': 'at-g',
            'refreshToken': 'rt-g',
            'user': {'id': 'u-g', 'nom': 'Awa'},
          }),
          200,
        );
      });
      final google = ConnexionGoogle(
        api: MobileAuthApi(
          ApiClient(
            baseUrl: 'https://exemple.test/api',
            resoudreLangue: () => 'fr',
            resoudreToken: () async => null,
            client: mock,
          ),
        ),
        obtenirIdToken: () async => 'id-token-google',
      );

      final session = await google.connecter();

      expect(requete.url.path, '/api/mobile-auth/google');
      expect(jsonDecode(requete.body)['idToken'], 'id-token-google');
      expect(session?.accessToken, 'at-g');
      expect(session?.refreshToken, 'rt-g');
      expect(session?.user?['nom'], 'Awa');
    },
  );

  test('une annulation ne contacte pas l\'API', () async {
    var appels = 0;
    final mock = MockClient((req) async {
      appels++;
      return http.Response('{}', 200);
    });
    final google = ConnexionGoogle(
      api: MobileAuthApi(
        ApiClient(
          baseUrl: 'https://exemple.test/api',
          resoudreLangue: () => 'fr',
          resoudreToken: () async => null,
          client: mock,
        ),
      ),
      obtenirIdToken: () async => null,
    );

    expect(await google.connecter(), isNull);
    expect(appels, 0);
  });

  test('une config absente remonte sans appeler l\'API', () async {
    var appels = 0;
    final mock = MockClient((req) async {
      appels++;
      return http.Response('{}', 200);
    });
    final google = ConnexionGoogle(
      api: MobileAuthApi(
        ApiClient(
          baseUrl: 'https://exemple.test/api',
          resoudreLangue: () => 'fr',
          resoudreToken: () async => null,
          client: mock,
        ),
      ),
      obtenirIdToken: () async {
        throw const ApiException(
          statusCode: 0,
          code: 'GOOGLE_NON_CONFIGURE',
          message: _messagePourTest,
        );
      },
    );

    await expectLater(
      google.connecter(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          'GOOGLE_NON_CONFIGURE',
        ),
      ),
    );
    expect(appels, 0);
  });
}

const _messagePourTest =
    'Connexion Google indisponible : GIDClientID et le schéma d\'URL REVERSED_CLIENT_ID manquent dans Info.plist.';
