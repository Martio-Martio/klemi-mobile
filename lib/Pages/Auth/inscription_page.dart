import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Configuration/longueurs_telephone.dart';
import '../../Configuration/matieres.dart';
import '../../Models/pays.dart';
import '../../Providers/app_state.dart';
import '../../Services/api_exception.dart';
import '../../Services/mobile_auth_api.dart';
import '../../Widgets/klemi_widgets.dart';
import '../../Widgets/matieres_widgets.dart';
import '../../Widgets/selecteur_indicatif.dart';
import 'code_page.dart';
import 'connexion_page.dart';

/// 1.1 · Inscription — rôle, nom, numéro WhatsApp, classe/établissement.
class InscriptionPage extends StatefulWidget {
  final MobileAuthApi? api; // injectable pour les tests
  const InscriptionPage({super.key, this.api});

  @override
  State<InscriptionPage> createState() => _InscriptionPageState();
}

class _InscriptionPageState extends State<InscriptionPage> {
  int _role = 0; // 0 élève, 1 enseignant
  bool _cgu = true;
  NiveauEtudes _niveau = NiveauEtudes.college;
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _classe = TextEditingController();
  final _etablissement = TextEditingController();
  Pays _pays = paysMaliSecours;
  bool _enCours = false;

  late final MobileAuthApi _api = widget.api ?? MobileAuthApi();

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _classe.dispose();
    _etablissement.dispose();
    super.dispose();
  }

  Future<void> _valider() async {
    if (_enCours) return;
    final etat = context.read<AppState>();
    // Pré-requis minimaux côté client — l'API validera à nouveau.
    if (_telephone.text.trim().isEmpty || _nom.text.trim().isEmpty) {
      _afficherErreur('Renseigne ton nom et ton numéro WhatsApp.');
      return;
    }
    final numero = composerNumero(_pays.callingCodes, _telephone.text);

    setState(() => _enCours = true);
    EasyLoading.show(status: 'Création du compte…');
    try {
      final demarrage = await _api.signup(
        phone: numero,
        role: _role == 0 ? RoleInscription.eleve : RoleInscription.enseignant,
        nom: _nom.text,
        niveauEtudes: _niveau,
        classe: _classe.text,
        etablissement: _role == 1 ? _etablissement.text : null,
        langue: etat.langue.id,
      );
      // Pré-remplir ce qui peut l'être avant la vérification OTP ; tout
      // sera refetch depuis /mobile/me après connexion effective.
      await etat.choisirNiveau(_niveau);
      if (_classe.text.trim().isNotEmpty) etat.classe = _classe.text.trim();
      if (!mounted) return;
      EasyLoading.dismiss();
      Navigator.of(context).push(routeGlissante(
        CodePage(numero: numero, tempToken: demarrage.tempToken),
      ));
    } on ApiException catch (e) {
      if (!mounted) return;
      EasyLoading.dismiss();
      _afficherErreur(e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  void _choisirPays(Pays pays) {
    final recoupe = recouperNumero(
      _telephone.text,
      longueurMaxIndicatif(pays.callingCodes),
    );
    if (_telephone.text != recoupe) {
      _telephone.value = TextEditingValue(
        text: recoupe,
        selection: TextSelection.collapsed(offset: recoupe.length),
      );
    }
    setState(() => _pays = pays);
  }

  void _afficherErreur(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  LogoKlemi(taille: 44),
                  ChipLangue(),
                ],
              ),
              const SizedBox(height: 24),
              Text('Crée ton compte', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              const Text(
                "Gratuit. Moins d'une minute, aucun e‑mail obligatoire.",
                style: TextStyle(fontSize: 14, color: AppTheme.texteSecondaire),
              ),
              const SizedBox(height: 18),
              const Text('Je suis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              KlemiSegments(
                libelles: const ['Élève / étudiant', 'Enseignant'],
                index: _role,
                onChanged: (i) => setState(() => _role = i),
              ),
              const SizedBox(height: 16),
              KlemiChamp(etiquette: 'Prénom et nom', indice: 'Aminata Traoré', controleur: _nom),
              const SizedBox(height: 16),
              KlemiChamp(
                etiquette: 'Numéro WhatsApp',
                indice: 'Max ${longueurMaxIndicatif(_pays.callingCodes)} chiffres',
                type: TextInputType.phone,
                controleur: _telephone,
                formateurs: formateursNumero(longueurMaxIndicatif(_pays.callingCodes)),
                prefixe: SelecteurIndicatif(pays: _pays, onChanged: _choisirPays),
              ),
              const SizedBox(height: 16),
              if (_role == 0) ...[
                const Text("Niveau d'études",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                SelecteurNiveau(
                  valeur: _niveau,
                  onChanged: (n) => setState(() => _niveau = n),
                ),
                const SizedBox(height: 12),
                KlemiChamp(
                  etiquette: 'Classe, filière ou année',
                  indice: _niveau.exempleClasse,
                  controleur: _classe,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Les matières seront proposées selon ton niveau ; tu pourras en ajouter (université, concours…).',
                  style: TextStyle(fontSize: 12, color: AppTheme.texteDiscret),
                ),
              ] else
                KlemiChamp(
                  etiquette: 'Établissement (facultatif)',
                  indice: 'Lycée Askia, Bamako',
                  controleur: _etablissement,
                ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setState(() => _cgu = !_cgu),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _cgu,
                      onChanged: (v) => setState(() => _cgu = v ?? false),
                      activeColor: AppTheme.bleuFonce,
                      visualDensity: VisualDensity.compact,
                    ),
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          "J'accepte les conditions d'utilisation et la politique de confidentialité. Mon numéro ne sert qu'à la connexion.",
                          style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.texteSecondaire),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              KlemiBouton(
                libelle: 'Créer mon compte',
                icone: Icons.arrow_forward,
                onPressed: _cgu ? _valider : null,
              ),
              const SizedBox(height: 12),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Déjà un compte ? ', style: TextStyle(color: AppTheme.texteSecondaire)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        routeGlissante(const ConnexionPage()),
                      ),
                      child: const Text(
                        'Se connecter',
                        style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.bleuFonce),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

