import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/app_theme.dart';
import 'package:klemi/Pages/Auth/langue_page.dart';
import 'package:klemi/Pages/Feed/feed_page.dart';
import 'package:klemi/Providers/app_state.dart';
import 'package:klemi/Widgets/langue_widgets.dart';

Widget _envelopper(Widget page) {
  return ChangeNotifierProvider(
    create: (_) => AppState(),
    child: MaterialApp(theme: AppTheme.theme(), home: Scaffold(body: page)),
  );
}

void main() {
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
    // Phase 2 : Pular n'est pas une langue de lecture — le choix est redirigé
    // sur `langueAudio` par `AppState.choisirLangue` pour préserver l'intention.
    // `langue` reste donc à sa valeur par défaut (fr) et `langueAudio` passe à ful.
    expect(etat.langue.id, 'fr');
    expect(etat.langueAudio.id, 'ful');
    expect(find.text('ouvrir'), findsOneWidget);
  });
}
