import 'package:flutter/material.dart';

import '../Configuration/app_theme.dart';
import '../Models/feed_item.dart';
import '../Models/social.dart';
import 'klemi_widgets.dart';

Color couleurType(TypeContenu t) => switch (t) {
      TypeContenu.quiz => AppTheme.orange,
      TypeContenu.fiche => AppTheme.vert,
      TypeContenu.podcast => AppTheme.bleu,
    };

IconData iconeType(TypeContenu t) => switch (t) {
      TypeContenu.quiz => Icons.help_outline,
      TypeContenu.fiche => Icons.description_outlined,
      TypeContenu.podcast => Icons.mic_none,
    };

String libelleType(TypeContenu t) => switch (t) {
      TypeContenu.quiz => 'Quiz',
      TypeContenu.fiche => 'Fiche',
      TypeContenu.podcast => 'Podcast',
    };

String ilYA(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.isNegative) return 'à venir';
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  return 'il y a ${diff.inDays} j';
}

/// Ligne compacte d'un contenu (icône colorée, titre, méta, état).
class LigneContenu extends StatelessWidget {
  final ContenuResume contenu;
  final String? sousTitre; // ex. auteur ou « il y a 5 h »
  final VoidCallback? onTap;
  final bool afficherFait;

  const LigneContenu({
    super.key,
    required this.contenu,
    this.sousTitre,
    this.onTap,
    this.afficherFait = false,
  });

  @override
  Widget build(BuildContext context) {
    final aVenir = contenu.publieLe.isAfter(DateTime.now());
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: aVenir ? 0.55 : 1,
        child: CarteBlanche(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: couleurType(contenu.type),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(iconeType(contenu.type), size: 20, color: AppTheme.navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contenu.titre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    Text(
                      sousTitre == null ? contenu.meta : '${contenu.meta} · $sousTitre',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (afficherFait)
                Icon(
                  contenu.fait ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 22,
                  color: contenu.fait ? AppTheme.vertFonce : AppTheme.bordurePointillee,
                )
              else if (contenu.horsLigne)
                const Text('Hors ligne',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.vertFonce))
              else
                const Icon(Icons.chevron_right, color: AppTheme.texteDiscret),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bouton « Suivre » / « Suivi ».
class BoutonSuivre extends StatelessWidget {
  final bool suivi;
  final VoidCallback onTap;
  final bool compact;
  const BoutonSuivre({super.key, required this.suivi, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 34 : 44,
      child: suivi
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.navy,
                backgroundColor: AppTheme.blanc,
                side: const BorderSide(color: AppTheme.bordure),
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Suivi', style: TextStyle(fontSize: compact ? 12 : 14, fontWeight: FontWeight.w800)),
            )
          : FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.navy,
                foregroundColor: AppTheme.blanc,
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Suivre', style: TextStyle(fontSize: compact ? 12 : 14, fontWeight: FontWeight.w800)),
            ),
    );
  }
}
