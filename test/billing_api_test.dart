import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Services/api_exception.dart';
import 'package:klemi/Services/billing_api.dart';

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

  group('BillingApi.fetchPlans', () {
    test('parse la liste quand enveloppée dans { plans: [...] }', () async {
      final api = BillingApi(clientAvec((_) {
        return http.Response(
          jsonEncode({
            'plans': [
              {
                'id': 'STUDENT',
                'nom': 'Student',
                'prixMensuel': 2000,
                'prixAnnuel': 20000,
                'accroche': 'Idéal pour les lycéens',
                'avantages': ['40 quiz', '5 podcasts'],
                'recommande': true,
              },
              {
                'id': 'PREMIUM',
                'nom': 'Premium',
                'prixMensuel': 5000,
                'prixAnnuel': 50000,
                'accroche': 'Pour les enseignants',
                'avantages': ['100 quiz'],
              },
            ]
          }),
          200,
        );
      }));
      final plans = await api.fetchPlans();
      expect(plans.length, 2);
      expect(plans[0].id, 'STUDENT');
      expect(plans[0].recommande, isTrue);
      expect(plans[0].avantages, ['40 quiz', '5 podcasts']);
      expect(plans[1].prixAnnuel, 50000);
    });

    test('parse la liste quand renvoyée à nu (array)', () async {
      final api = BillingApi(clientAvec((_) {
        return http.Response(
          jsonEncode([
            {
              'id': 'FREE',
              'nom': 'Gratuit',
              'prixMensuel': 0,
              'prixAnnuel': 0,
              'accroche': 'Pour découvrir',
              'avantages': ['3 quiz'],
            }
          ]),
          200,
        );
      }));
      final plans = await api.fetchPlans();
      expect(plans.length, 1);
      expect(plans.first.nom, 'Gratuit');
    });
  });

  group('BillingApi.checkout', () {
    test('envoie planId, duree, moyen, numero dans le body', () async {
      late http.Request req;
      final api = BillingApi(clientAvec((r) {
        req = r as http.Request;
        return http.Response(
          jsonEncode({'invoiceId': 'inv-1', 'status': 'PENDING'}),
          201,
        );
      }));
      final res = await api.checkout(
        planId: 'STUDENT',
        duree: DureeAbo.annual,
        moyen: MoyenPaiement.wave,
        numero: '70 11 22 33',
      );
      expect(req.url.path, '/api/mobile/subscription/checkout');
      expect(jsonDecode(req.body), {
        'planId': 'STUDENT',
        'duree': 'annual',
        'moyen': 'wave',
        'numero': '70 11 22 33',
      });
      expect(res.invoiceId, 'inv-1');
      expect(res.statut, 'PENDING');
    });

    test('parse paymentUrl quand présent', () async {
      final api = BillingApi(clientAvec((_) {
        return http.Response(
          jsonEncode({
            'invoiceId': 'inv-2',
            'status': 'PENDING',
            'paymentUrl': 'https://pay.wave.com/x',
          }),
          201,
        );
      }));
      final res = await api.checkout(
        planId: 'PREMIUM',
        duree: DureeAbo.monthly,
        moyen: MoyenPaiement.orange,
        numero: '70 00 00 00',
      );
      expect(res.paymentUrl, 'https://pay.wave.com/x');
    });
  });

  group('BillingApi.fetchStatus', () {
    test('PAID → StatutPaiement.paye', () async {
      final api = BillingApi(clientAvec((r) {
        expect(r.url.path, '/api/mobile/subscription/status/inv-1');
        return http.Response(jsonEncode({'status': 'PAID'}), 200);
      }));
      final s = await api.fetchStatus('inv-1');
      expect(s.paye, isTrue);
      expect(s.enAttente, isFalse);
      expect(s.echoue, isFalse);
    });

    test('FAILED → StatutPaiement.echoue + message', () async {
      final api = BillingApi(clientAvec((_) {
        return http.Response(
          jsonEncode({'status': 'FAILED', 'error': 'Solde insuffisant.'}),
          200,
        );
      }));
      final s = await api.fetchStatus('inv-2');
      expect(s.echoue, isTrue);
      expect(s.messageErreur, 'Solde insuffisant.');
    });

    test('PENDING par défaut si statut inconnu', () async {
      final api = BillingApi(clientAvec((_) {
        return http.Response('{}', 200);
      }));
      final s = await api.fetchStatus('inv-3');
      expect(s.statut, 'PENDING');
      expect(s.enAttente, isTrue);
    });

    test('propagate ApiException sur 500', () async {
      final api = BillingApi(clientAvec((_) {
        return http.Response(
          jsonEncode({'statusCode': 500, 'message': 'provider down'}),
          500,
        );
      }));
      await expectLater(
        () => api.fetchStatus('inv-x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });
}
