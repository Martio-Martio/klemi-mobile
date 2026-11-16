import 'package:flutter/material.dart';

import '../../Configuration/app_theme.dart';
import '../../Widgets/klemi_widgets.dart';
import 'code_page.dart';
import 'inscription_page.dart';
import 'langue_page.dart';

/// 1.2 · Connexion — numéro + code WhatsApp (défaut) ou e‑mail + mot de passe.
class ConnexionPage extends StatefulWidget {
  const ConnexionPage({super.key});

  @override
  State<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends State<ConnexionPage> {
  int _mode = 0; // 0 numéro, 1 e‑mail
  final _telephone = TextEditingController();

  @override
  void dispose() {
    _telephone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [LogoKlemi(), ChipLangue()],
              ),
              const SizedBox(height: 28),
              Text('Content de te revoir', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Connecte‑toi avec ton numéro. Tu recevras un code sur WhatsApp, pas besoin de mot de passe.',
                style: TextStyle(fontSize: 15, height: 1.5, color: AppTheme.texteSecondaire),
              ),
              const SizedBox(height: 22),
              KlemiSegments(
                libelles: const ['Numéro', 'E‑mail'],
                index: _mode,
                onChanged: (i) => setState(() => _mode = i),
              ),
              const SizedBox(height: 20),
              if (_mode == 0) ...[
                KlemiChamp(
                  etiquette: 'Numéro de téléphone',
                  indice: '70 00 00 00',
                  type: TextInputType.phone,
                  controleur: _telephone,
                  prefixe: const IndicatifPays(),
                ),
                const SizedBox(height: 14),
                KlemiBouton(
                  libelle: 'Recevoir mon code sur WhatsApp',
                  icone: Icons.chat_bubble_outline,
                  iconeADroite: false,
                  couleur: AppTheme.whatsapp,
                  onPressed: () => Navigator.of(context).push(
                    routeGlissante(CodePage(numero: _telephone.text)),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Recevoir le code par SMS à la place',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.bleuFonce),
                  ),
                ),
              ] else ...[
                const KlemiChamp(
                  etiquette: 'Adresse e‑mail',
                  indice: 'aminata@exemple.ml',
                  type: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),
                const KlemiChamp(etiquette: 'Mot de passe', indice: '••••••••', secret: true),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text('Mot de passe oublié ?',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.bleuFonce)),
                  ),
                ),
                KlemiBouton(
                  libelle: 'Se connecter',
                  icone: Icons.arrow_forward,
                  onPressed: () => Navigator.of(context).pushReplacement(
                    routeGlissante(const LanguePage()),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                children: const [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('ou continuer avec',
                        style: TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: KlemiBoutonSecondaire(
                      libelle: 'Google',
                      icone: Icons.language,
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: KlemiBoutonSecondaire(
                      libelle: 'Code établissement',
                      icone: Icons.qr_code_2,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Nouveau sur Klemi ? ',
                        style: TextStyle(color: AppTheme.texteSecondaire)),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pushReplacement(
                        routeGlissante(const InscriptionPage()),
                      ),
                      child: const Text('Créer un compte',
                          style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.bleuFonce)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "En continuant, tu acceptes les conditions d'utilisation et la politique de confidentialité.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.texteDiscret),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
