import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Configuration/app_theme.dart';
import '../Configuration/langues.dart';
import '../Providers/app_state.dart';

/// Feuille de sélection de la langue (interface + contenus), ouverte depuis
/// le chip « FR ▾ » présent sur les écrans.
Future<void> ouvrirSelecteurLangue(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.beige,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final etat = ctx.watch<AppState>();
      final bas = MediaQuery.viewPaddingOf(ctx).bottom;
      // La feuille du système ne donne qu'une hauteur limitée. La liste
      // défile dedans au lieu d'étirer une Column au-delà de cette hauteur.
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.45,
        maxChildSize: 0.92,
        builder: (context, controleur) {
          return ListView(
            controller: controleur,
            primary: false,
            padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bas),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.bordurePointillee,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Langue',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                "S'applique à l'interface, au feed et aux contenus générés par l'IA.",
                style: TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
              ),
              const SizedBox(height: 12),
              for (final l in languesDisponibles)
                _Ligne(
                  langue: l,
                  selectionnee: l.id == etat.langue.id,
                  onTap: () async {
                    await ctx.read<AppState>().choisirLangue(l);
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in languesBientot)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppTheme.bordurePointillee),
                      ),
                      child: Text(
                        '$n · bientôt',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.texteDiscret,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      );
    },
  );
}

class _Ligne extends StatelessWidget {
  final Langue langue;
  final bool selectionnee;
  final VoidCallback onTap;
  const _Ligne({
    required this.langue,
    required this.selectionnee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selectionnee ? AppTheme.blanc : AppTheme.beigeClair,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selectionnee ? AppTheme.bleu : AppTheme.bordure,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.blanc,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.bordure),
              ),
              alignment: Alignment.center,
              child: Text(
                langue.code,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFamilyFallback: AppTheme.famillesSecours,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langue.nom,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamilyFallback: AppTheme.famillesSecours,
                    ),
                  ),
                  Text(
                    langue.description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.texteSecondaire,
                      fontFamilyFallback: AppTheme.famillesSecours,
                    ),
                  ),
                ],
              ),
            ),
            if (selectionnee)
              const Icon(
                Icons.check_circle,
                color: AppTheme.bleuFonce,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
