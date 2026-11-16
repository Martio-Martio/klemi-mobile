import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Data/mock_social.dart';
import '../../Models/social.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';
import '../../Widgets/ligne_contenu.dart';
import '../Social/profil_createur_page.dart';

/// Onglet « Abonnements » du feed : créateurs suivis + leurs nouveautés,
/// dans l'ordre chronologique.
class AbonnementsPage extends StatelessWidget {
  final void Function(ContenuResume)? onOuvrir;
  const AbonnementsPage({super.key, this.onOuvrir});

  @override
  Widget build(BuildContext context) {
    final etat = context.watch<AppState>();
    final suivis = createurs.where((c) => etat.suit(c.id)).toList();
    final suggestions = createurs.where((c) => !etat.suit(c.id)).toList();
    final nouveautes = nouveautesAbonnements.where((n) => etat.suit(n.createurId)).toList()
      ..sort((a, b) => b.publieLe.compareTo(a.publieLe));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${suivis.length} abonnements',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            TextButton(onPressed: () {}, child: const Text('Gérer')),
          ],
        ),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in suivis)
                InkWell(
                  onTap: () => Navigator.of(context).push(
                    routeGlissante(ProfilCreateurPage(createur: c)),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.orange, width: 2),
                          ),
                          child: Avatar(initiales: c.initiales, taille: 52,
                              couleur: c.id == 'klemi' ? AppTheme.bleu : AppTheme.orange),
                        ),
                        const SizedBox(height: 6),
                        Text(c.pseudo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text('Nouveautés', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (nouveautes.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              "Suis des enseignants pour voir leurs nouveaux contenus ici.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.texteDiscret),
            ),
          ),
        for (final n in nouveautes) ...[
          _Nouveaute(contenu: n, onTap: () => onOuvrir?.call(n)),
          const SizedBox(height: 8),
        ],
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Text('À suivre aussi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final c in suggestions) ...[
            CarteBlanche(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Avatar(initiales: c.initiales, taille: 40, couleur: AppTheme.vert),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.nom, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        Text('${c.etablissement} · ${c.contenus} contenus',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  BoutonSuivre(
                    compact: true,
                    suivi: false,
                    onTap: () => context.read<AppState>().basculerSuivi(c.id),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _Nouveaute extends StatelessWidget {
  final ContenuResume contenu;
  final VoidCallback onTap;
  const _Nouveaute({required this.contenu, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = createurParId(contenu.createurId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Row(
            children: [
              Avatar(initiales: c.initiales, taille: 20),
              const SizedBox(width: 6),
              Text(c.pseudo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              Text(' · ${ilYA(contenu.publieLe)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
            ],
          ),
        ),
        LigneContenu(contenu: contenu, onTap: onTap),
      ],
    );
  }
}
