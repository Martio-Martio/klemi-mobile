import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:klemi/Configuration/langues.dart';
import 'package:klemi/Providers/app_state.dart';
import 'package:klemi/Widgets/klemi_widgets.dart';

Langue _langue(String id) => languesDisponibles.firstWhere((l) => l.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fr/en reste la langue de lecture et s\'affiche sur le chip', () async {
    final etat = AppState();

    await etat.choisirLangue(_langue('en'));

    expect(etat.langue.id, 'en');
    expect(etat.langueInterface.id, 'en');
    expect(etat.langueAudio.id, 'bm');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('langue'), 'en');
    expect(prefs.getString('langueInterface'), 'en');
  });

  test('une langue locale met à jour le chip sans changer la lecture', () async {
    final etat = AppState();
    await etat.choisirLangue(_langue('en'));

    await etat.choisirLangue(_langue('bm'));

    expect(etat.langue.id, 'en');
    expect(etat.langueAudio.id, 'bm');
    expect(etat.langueInterface.id, 'bm');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('langue'), 'en');
    expect(prefs.getString('langueAudio'), 'bm');
    expect(prefs.getString('langueInterface'), 'bm');
  });

  test('revenir à une langue de lecture réaffiche son code', () async {
    final etat = AppState();
    await etat.choisirLangue(_langue('ful'));

    await etat.choisirLangue(_langue('fr'));

    expect(etat.langue.id, 'fr');
    expect(etat.langueInterface.id, 'fr');
    expect(etat.langueAudio.id, 'ful');
  });

  test('la langue audio des paramètres ne change pas le chip', () async {
    final etat = AppState();
    await etat.choisirLangue(_langue('en'));

    await etat.choisirLangueAudio(_langue('sus'));

    expect(etat.langue.id, 'en');
    expect(etat.langueAudio.id, 'sus');
    expect(etat.langueInterface.id, 'en');
  });

  test('le choix d\'interface est rétabli au chargement', () async {
    final etat = AppState();
    await etat.choisirLangue(_langue('sus'));

    final recharge = AppState();
    await recharge.charger();

    expect(recharge.langue.id, 'fr');
    expect(recharge.langueAudio.id, 'sus');
    expect(recharge.langueInterface.id, 'sus');
  });

  test('une ancienne langue locale persistée comme lecture réapparaît sur le chip', () async {
    SharedPreferences.setMockInitialValues({'langue': 'ful'});
    final etat = AppState();

    await etat.charger();

    expect(etat.langue.id, 'fr');
    expect(etat.langueAudio.id, 'ful');
    expect(etat.langueInterface.id, 'ful');
  });

  testWidgets('le chip de connexion affiche le code choisi', (tester) async {
    final etat = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: etat,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: ChipLangue())),
        ),
      ),
    );

    expect(find.text('FR'), findsOneWidget);

    await etat.choisirLangue(_langue('en'));
    await tester.pump();
    expect(find.text('EN'), findsOneWidget);

    await etat.choisirLangue(_langue('ful'));
    await tester.pump();
    expect(find.text('FF'), findsOneWidget);
    expect(etat.langue.id, 'en');
    expect(etat.langueAudio.id, 'ful');
  });
}
