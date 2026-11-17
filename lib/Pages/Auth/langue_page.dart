import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Configuration/langues.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';
import '../app_shell.dart';

/// 1.4 · Choix de la langue d'apprentissage (interface + contenus générés).
class LanguePage extends StatelessWidget {
  const LanguePage({super.key});

  @override
  Widget build(BuildContext context) {
    final etat = context.watch<AppState>();
    final choisie = etat.langueInterface;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LogoKlemi(),
              const SizedBox(height: 22),
              Text('Dans quelle langue veux‑tu apprendre ?',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text(
                'Quiz, fiches et podcasts seront générés dans cette langue. Tu pourras changer à tout moment.',
                style: TextStyle(fontSize: 15, height: 1.5, color: AppTheme.texteSecondaire),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    for (final l in languesDisponibles) ...[
                      _OptionLangue(
                        langue: l,
                        selectionnee: l.id == choisie.id,
                        onTap: () => context.read<AppState>().choisirLangue(l),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final n in languesBientot)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: AppTheme.bordurePointillee),
                            ),
                            child: Text('$n · bientôt',
                                style: const TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              KlemiBouton(
                libelle: choisie.cta,
                icone: Icons.arrow_forward,
                onPressed: () async {
                  await context.read<AppState>().marquerConnecte(true);
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AppShell()),
                    (_) => false,
                  );
                },
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text('Gratuit · fonctionne hors connexion',
                    style: TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionLangue extends StatelessWidget {
  final Langue langue;
  final bool selectionnee;
  final VoidCallback onTap;

  const _OptionLangue({
    required this.langue,
    required this.selectionnee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(
          color: selectionnee ? AppTheme.blanc : AppTheme.beigeClair,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(width: 2, color: selectionnee ? AppTheme.bleu : AppTheme.bordure),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.blanc,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.bordure),
              ),
              alignment: Alignment.center,
              child: Text(langue.code,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    fontFamilyFallback: AppTheme.famillesSecours,
                  )),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(langue.nom,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        fontFamilyFallback: AppTheme.famillesSecours,
                      )),
                  Text(langue.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.texteSecondaire,
                        fontFamilyFallback: AppTheme.famillesSecours,
                      )),
                ],
              ),
            ),
            if (selectionnee)
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(color: AppTheme.bleu, shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 16, color: AppTheme.navy),
              ),
          ],
        ),
      ),
    );
  }
}
