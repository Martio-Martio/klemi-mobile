import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Configuration/matieres.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';
import '../../Widgets/matieres_widgets.dart';
import 'code_page.dart';
import 'connexion_page.dart';

/// 1.1 · Inscription — rôle, nom, numéro WhatsApp, classe/établissement.
class InscriptionPage extends StatefulWidget {
  const InscriptionPage({super.key});

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

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _classe.dispose();
    super.dispose();
  }

  void _valider() {
    final etat = context.read<AppState>();
    etat.choisirNiveau(_niveau);
    if (_classe.text.trim().isNotEmpty) etat.classe = _classe.text.trim();
    Navigator.of(context).push(routeGlissante(CodePage(numero: _telephone.text)));
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
                indice: '70 00 00 00',
                type: TextInputType.phone,
                controleur: _telephone,
                prefixe: const IndicatifPays(),
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
                const KlemiChamp(
                  etiquette: 'Établissement (facultatif)',
                  indice: 'Lycée Askia, Bamako',
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

