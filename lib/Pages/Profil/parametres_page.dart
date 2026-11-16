import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Configuration/langues.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';
import '../../Widgets/langue_widgets.dart';
import '../../Widgets/matieres_widgets.dart';
import '../Auth/connexion_page.dart';
import 'forfaits_page.dart';

/// Paramètres : compte, langues, notifications, hors ligne, appareils, aide, déconnexion.
class ParametresPage extends StatelessWidget {
  const ParametresPage({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const BoutonRetour(),
                  Text('Paramètres', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  _Section(
                    titre: 'Compte',
                    enfants: [
                      _LigneValeur('Nom', 'Aminata Traoré', onTap: () {}),
                      _LigneValeur('Numéro WhatsApp', '+223 70 •• •• 12', onTap: () {}),
                      _LigneValeur('Classe', '${etat.classe} · ${etat.etablissement}', onTap: () {}),
                      _LigneValeur('Forfait', 'Klemi ${etat.forfait}',
                          onTap: () => Navigator.of(context).push(routeGlissante(const ForfaitsPage()))),
                    ],
                  ),
                  _Section(
                    titre: 'Niveau et matières',
                    sousTitre: 'Collège, lycée, université, concours : les matières proposées s\'adaptent, et tu peux en ajouter.',
                    enfants: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Niveau d'études",
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            SelecteurNiveau(
                              valeur: etat.niveauEtudes,
                              onChanged: (n) => context.read<AppState>().choisirNiveau(n),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Mes matières (${etat.matieres.length})',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                TextButton(
                                  onPressed: () => context.read<AppState>().reinitialiserMatieres(),
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                  child: const Text('Liste par défaut', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const MatieresEditables(compact: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    titre: 'Langues',
                    sousTitre: 'La langue des contenus s\'applique au feed et aux générations IA.',
                    enfants: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Langue des contenus',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final l in languesDisponibles)
                                  ChoiceChip(
                                    label: Text(l.nom),
                                    selected: etat.langue.id == l.id,
                                    onSelected: (_) => context.read<AppState>().choisirLangue(l),
                                    selectedColor: AppTheme.navy,
                                    backgroundColor: AppTheme.beige,
                                    showCheckmark: false,
                                    labelStyle: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: etat.langue.id == l.id ? AppTheme.blanc : AppTheme.navy,
                                    ),
                                    side: BorderSide(
                                        color: etat.langue.id == l.id ? AppTheme.navy : AppTheme.bordure),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(999)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      _LigneValeur("Langue de l'interface", etat.langue.nom,
                          onTap: () => ouvrirSelecteurLangue(context)),
                    ],
                  ),
                  _Section(
                    titre: 'Notifications',
                    enfants: [
                      _LigneSwitch(
                        'Rappel de série',
                        'Un rappel le soir si tu n\'as pas encore joué',
                        etat.notifStreak,
                        (v) => context.read<AppState>().majPreference(() => etat.notifStreak = v),
                      ),
                      _LigneSwitch(
                        'Nouveaux contenus',
                        'Quand un enseignant suivi publie',
                        etat.notifNouveauxContenus,
                        (v) => context.read<AppState>().majPreference(() => etat.notifNouveauxContenus = v),
                      ),
                      _LigneSwitch(
                        'Résultats et classement',
                        'Fin de série, position dans la classe',
                        etat.notifResultats,
                        (v) => context.read<AppState>().majPreference(() => etat.notifResultats = v),
                      ),
                    ],
                  ),
                  _Section(
                    titre: 'Hors ligne',
                    enfants: [
                      _LigneSwitch(
                        'Télécharger en Wi‑Fi seulement',
                        'Économise ton forfait data',
                        etat.telechargerWifiSeulement,
                        (v) => context.read<AppState>().majPreference(() => etat.telechargerWifiSeulement = v),
                      ),
                      _LigneSwitch(
                        'Lecture automatique des podcasts',
                        'Démarre quand la carte apparaît',
                        etat.lectureAutoPodcast,
                        (v) => context.read<AppState>().majPreference(() => etat.lectureAutoPodcast = v),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Stockage utilisé',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                                Text('${etat.stockageHorsLigneMo} Mo / 500 Mo',
                                    style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: etat.stockageHorsLigneMo / 500,
                                minHeight: 8,
                                backgroundColor: AppTheme.bordure,
                                color: AppTheme.bleu,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: etat.stockageHorsLigneMo == 0
                                  ? null
                                  : () => context.read<AppState>().viderStockage(),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero),
                              child: const Text('Libérer l\'espace (garde la liste, retire les fichiers)'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _Section(
                    titre: 'Sécurité',
                    enfants: [
                      _LigneValeur('Appareils connectés', '2 appareils', onTap: () {}),
                      _LigneValeur('Mot de passe (connexion e‑mail)', 'Modifier', onTap: () {}),
                    ],
                  ),
                  _Section(
                    titre: 'Aide',
                    enfants: [
                      _LigneValeur('Centre d\'aide et WhatsApp support', '', onTap: () {}),
                      _LigneValeur('Suggérer une fonctionnalité', '', onTap: () {}),
                      _LigneValeur("Conditions d'utilisation · Confidentialité", '', onTap: () {}),
                      const _LigneValeur('Version', '1.0.0'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  KlemiBoutonSecondaire(
                    libelle: 'Se déconnecter',
                    icone: Icons.logout,
                    onPressed: () async {
                      await context.read<AppState>().deconnecter();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const ConnexionPage()),
                        (_) => false,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Supprimer mon compte',
                          style: TextStyle(color: AppTheme.rougeFonce, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String titre;
  final String? sousTitre;
  final List<Widget> enfants;
  const _Section({required this.titre, this.sousTitre, required this.enfants});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          if (sousTitre != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(sousTitre!,
                  style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
            ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.blanc,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.bordure),
            ),
            child: Column(
              children: [
                for (var i = 0; i < enfants.length; i++) ...[
                  enfants[i],
                  if (i < enfants.length - 1) const Divider(height: 1, indent: 14, endIndent: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneValeur extends StatelessWidget {
  final String libelle;
  final String valeur;
  final VoidCallback? onTap;
  const _LigneValeur(this.libelle, this.valeur, {this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(libelle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
            if (valeur.isNotEmpty)
              Text(valeur, style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppTheme.texteDiscret),
            ],
          ],
        ),
      ),
    );
  }
}

class _LigneSwitch extends StatelessWidget {
  final String libelle;
  final String detail;
  final bool valeur;
  final ValueChanged<bool> onChanged;
  const _LigneSwitch(this.libelle, this.detail, this.valeur, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(detail, style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
              ],
            ),
          ),
          Switch(
            value: valeur,
            onChanged: onChanged,
            activeThumbColor: AppTheme.navy,
            activeTrackColor: AppTheme.bleu,
          ),
        ],
      ),
    );
  }
}
