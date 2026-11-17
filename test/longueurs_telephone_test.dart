import 'package:flutter_test/flutter_test.dart';

import 'package:klemi/Configuration/longueurs_telephone.dart';
import 'package:klemi/Data/catalogue_pays.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('+223 limite le numéro malien à 8 chiffres', () {
    expect(longueurMaxIndicatif('+223'), 8);
  });

  test('+225 limite le numéro ivoirien à 10 chiffres', () {
    expect(longueurMaxIndicatif('+225'), 10);
  });

  test('un indicatif absent de la table est plafonné à 15 chiffres', () {
    expect(longueurMaxIndicatif('+999'), 15);
  });

  test('une saisie trop longue est coupée au plafond du pays choisi', () {
    expect(recouperNumero('70 12 34 56 99', longueurMaxIndicatif('+223')), '70123456');
    expect(composerNumero('+223', '7012345699'), '+22370123456');
  });

  test('le catalogue expose le Mali et se filtre sans accent', () async {
    final liste = await CataloguePays.charger();
    expect(paysParDefaut(liste).callingCodes, '+223');
    expect(
      filtrerPays(liste, 'senegal').map((p) => p.callingCodes),
      contains('+221'),
    );
  });
}
