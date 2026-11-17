import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/api_client.dart';
import 'package:klemi/Configuration/app_theme.dart';
import 'package:klemi/Pages/Auth/langue_page.dart';
import 'package:klemi/Pages/Feed/feed_page.dart';
import 'package:klemi/Providers/app_state.dart';
import 'package:klemi/Repositories/feed_repository.dart';
import 'package:klemi/Widgets/langue_widgets.dart';

Widget _envelopper(Widget page) {
  return ChangeNotifierProvider(
    create: (_) => AppState(),
    child: MaterialApp(theme: AppTheme.theme(), home: Scaffold(body: page)),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Branche un ApiClient inerte pour permettre aux pages du feed de
    // construire leur repository sans erreur. Les requêtes sortantes sont
    // interceptées par le MockClient ci-dessous (répond toujours 204 vide).
    ApiClient.brancher(ApiClient(
      baseUrl: 'https://exemple.test/api',
      resoudreLangue: () => 'fr',
      resoudreToken: () async => null,
      client: MockClient((_) async => http.Response('', 204)),
    ));
    // Force le repository en mode mock pour que la page feed affiche les
    // données de démo (indépendantes du réseau).
    FeedRepository.brancher(FeedRepository(utiliserMock: true));
  });

  testWidgets('Le choix de langue propose les cinq langues', (tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_envelopper(const LanguePage()));
    await tester.pump();

    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Bamanankan'), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('Pular'), 80, scrollable: scrollable);
    await tester.pump();
    expect(find.text('Soso'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);
    // Phase 2 : la langue de lecture par défaut est fr (seules fr/en sont des
    // langues de lecture valides). Le CTA affiche donc le libellé français.
    expect(find.text('Commencer'), findsOneWidget);
  });

  testWidgets('Le feed affiche une carte quiz jouable', (tester) async {
    await tester.pumpWidget(_envelopper(const FeedPage()));
    await tester.pump();

    expect(find.text('Pour toi'), findsOneWidget);
    expect(find.textContaining('Kankou Moussa'), findsWidgets);

    await tester.tap(find.text('1325'));
    await tester.pumpAndSettle();
    expect(find.text('Bonne réponse ! +20 pts'), findsOneWidget);
  });

  testWidgets('Le sélecteur de langue défile et enregistre le choix', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late AppState etat;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => etat = AppState(),
        child: MaterialApp(
          theme: AppTheme.theme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => ouvrirSelecteurLangue(context),
                  child: const Text('ouvrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Français'), findsOneWidget);
    final scrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.text('Pular'), 80, scrollable: scrollable);
    await tester.pump();
    expect(find.textContaining('Fulɓe'), findsOneWidget);

    await tester.tap(find.text('Pular'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Pular n'est pas une langue de lecture : la lecture reste fr, l'audio
    // passe à ful, et le chip d'interface affiche quand même ce choix.
    expect(etat.langue.id, 'fr');
    expect(etat.langueAudio.id, 'ful');
    expect(etat.langueInterface.id, 'ful');
    expect(find.text('ouvrir'), findsOneWidget);
  });
}
