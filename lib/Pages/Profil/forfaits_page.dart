import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../Configuration/app_theme.dart';
import '../../Widgets/klemi_widgets.dart';
import 'paiement_page.dart';

/// Forfait Klemi (prix et avantages alignés sur `billing.config.ts` de l'API).
class Forfait {
  final String id;
  final String nom;
  final int prixMensuel; // F CFA
  final int prixAnnuel;
  final String accroche;
  final List<String> avantages;
  final bool recommande;

  const Forfait({
    required this.id,
    required this.nom,
    required this.prixMensuel,
    required this.prixAnnuel,
    required this.accroche,
    required this.avantages,
    this.recommande = false,
  });
}

const forfaits = [
  Forfait(
    id: 'FREE',
    nom: 'Gratuit',
    prixMensuel: 0,
    prixAnnuel: 0,
    accroche: 'Pour découvrir : tout le feed, et quelques créations.',
    avantages: ['3 quiz', '3 fiches', '1 podcast', '1 appareil'],
  ),
  Forfait(
    id: 'STUDENT',
    nom: 'Student',
    prixMensuel: 2000,
    prixAnnuel: 20000,
    accroche: "Pour réviser toute l'année avec tes propres cours.",
    avantages: ['40 quiz / mois', '40 fiches / mois', '5 podcasts / mois', '20 imports YouTube', 'Fichiers 10 Mo'],
    recommande: true,
  ),
  Forfait(
    id: 'PREMIUM',
    nom: 'Premium',
    prixMensuel: 5000,
    prixAnnuel: 50000,
    accroche: 'Pour les enseignants et les gros réviseurs.',
    avantages: [
      '100 quiz / mois',
      '100 fiches / mois',
      '15 podcasts / mois',
      '60 questions / quiz',
      'Analyses complètes',
      'Support prioritaire',
    ],
  ),
];

String formatFcfa(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return '$b F';
}

/// 3.3 · Choix du forfait avec avantages.
class ForfaitsPage extends StatefulWidget {
  const ForfaitsPage({super.key});

  @override
  State<ForfaitsPage> createState() => _ForfaitsPageState();
}

class _ForfaitsPageState extends State<ForfaitsPage> {
  bool _annuel = false;
  String _choix = 'STUDENT';

  /// Le forfait Pro n'affiche pas de tarif : on oriente vers le support.
  Future<void> _contacterServiceClient(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@klemi.ci',
      queryParameters: {'subject': 'Forfait Pro · établissements'},
    );
    final ouvert = await launchUrl(uri);
    if (!ouvert && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contactez le service client : support@klemi.ci')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final choisi = forfaits.firstWhere((f) => f.id == _choix);
    final montant = _annuel ? choisi.prixAnnuel : choisi.prixMensuel;

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
                  Text('Forfaits', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                children: [
                  const Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 14, height: 1.45, color: AppTheme.texteSecondaire),
                      children: [
                        TextSpan(text: 'Lire le feed reste gratuit. Les forfaits augmentent ce que tu peux '),
                        TextSpan(
                            text: 'créer',
                            style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.navy)),
                        TextSpan(text: " avec l'IA."),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SizedBox(
                      width: 280,
                      child: KlemiSegments(
                        libelles: const ['Mensuel', 'Annuel · 2 mois offerts'],
                        index: _annuel ? 1 : 0,
                        onChanged: (i) => setState(() => _annuel = i == 1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final f in forfaits) ...[
                    _CarteForfait(
                      forfait: f,
                      annuel: _annuel,
                      selectionne: f.id == _choix,
                      actuel: f.id == 'FREE',
                      onTap: () => setState(() => _choix = f.id),
                    ),
                    const SizedBox(height: 12),
                  ],
                  InkWell(
                    onTap: () => _contacterServiceClient(context),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                      decoration: BoxDecoration(
                        color: AppTheme.navy,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Pro · établissements',
                                    style: TextStyle(
                                        fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.blanc)),
                                Text(
                                  "Multi‑utilisateurs, sessions d'examen, anti‑triche, certificats",
                                  style: TextStyle(fontSize: 12, color: Color(0xFFBAE0FD)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Contactez le service client',
                                  style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.blanc),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Sur mesure',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.blanc)),
                          SizedBox(width: 8),
                          Icon(Icons.support_agent, color: AppTheme.blanc),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  KlemiBouton(
                    libelle: montant == 0
                        ? 'Rester en Gratuit'
                        : 'Passer à ${choisi.nom} · ${formatFcfa(montant)}${_annuel ? ' / an' : ' / mois'}',
                    icone: Icons.arrow_forward,
                    onPressed: montant == 0
                        ? () => Navigator.of(context).maybePop()
                        : () => Navigator.of(context).push(
                              routeGlissante(PaiementPage(forfait: choisi, annuel: _annuel)),
                            ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Paiement Orange Money, MTN, Moov, Wave · annulable à tout moment',
                      style: TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarteForfait extends StatelessWidget {
  final Forfait forfait;
  final bool annuel;
  final bool selectionne;
  final bool actuel;
  final VoidCallback onTap;

  const _CarteForfait({
    required this.forfait,
    required this.annuel,
    required this.selectionne,
    required this.actuel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final montant = annuel ? forfait.prixAnnuel : forfait.prixMensuel;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.blanc,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: selectionne ? AppTheme.bleu : AppTheme.bordure, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: selectionne ? AppTheme.bleu : AppTheme.bordure, width: 2),
                      ),
                      child: selectionne
                          ? const Center(
                              child: SizedBox(
                                width: 10,
                                height: 10,
                                child: DecoratedBox(
                                  decoration:
                                      BoxDecoration(color: AppTheme.navy, shape: BoxShape.circle),
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text(forfait.nom,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    if (actuel) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.sable,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text('Actuel',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.texteDiscret)),
                      ),
                    ],
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(montant == 0 ? '0 F' : formatFcfa(montant),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(
                          montant == 0 ? 'pour toujours' : (annuel ? 'par an' : 'par mois'),
                          style: const TextStyle(fontSize: 11, color: AppTheme.texteDiscret),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(forfait.accroche,
                    style: const TextStyle(fontSize: 13, height: 1.45, color: AppTheme.texteCorps)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in forfait.avantages)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: selectionne ? AppTheme.bleuClair : AppTheme.beige,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, size: 12, color: AppTheme.navy),
                            const SizedBox(width: 4),
                            Text(a,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (forfait.recommande)
          Positioned(
            top: -10,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.orange,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Le plus choisi',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}
