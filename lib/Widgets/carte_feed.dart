import 'package:flutter/material.dart';

import '../Configuration/app_theme.dart';
import '../Data/mock_social.dart';
import '../Models/feed_item.dart';
import '../Pages/Social/profil_createur_page.dart';
import 'klemi_widgets.dart';

/// Gabarit commun des cartes du feed : contenu au centre, rail d'actions à
/// droite, légende de l'auteur et poignée « glisse vers le haut » en bas.
class CarteFeed extends StatelessWidget {
  final FeedItem item;
  final Widget contenu;
  final String prochain; // libellé du contenu suivant (« Fiche de révision »)
  final List<ActionRail> actions;
  final Color couleurAccent;

  const CarteFeed({
    super.key,
    required this.item,
    required this.contenu,
    required this.prochain,
    required this.actions,
    required this.couleurAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 84, 8),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [contenu],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 84, 10),
              child: _Legende(item: item, couleurAccent: couleurAccent),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.keyboard_arrow_up, size: 16, color: AppTheme.texteDiscret),
                  Text(
                    'Glisse vers le haut · $prochain',
                    style: const TextStyle(fontSize: 12, color: AppTheme.texteDiscret),
                  ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          right: 8,
          bottom: 120,
          child: _Rail(item: item, actions: actions),
        ),
      ],
    );
  }
}

class ActionRail {
  final IconData icone;
  final String libelle;
  final VoidCallback? onTap;
  const ActionRail(this.icone, this.libelle, {this.onTap});
}

class _Rail extends StatelessWidget {
  final FeedItem item;
  final List<ActionRail> actions;
  const _Rail({required this.item, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            final c = createurs.where((x) => x.pseudo == item.auteur.pseudo);
            if (c.isEmpty) return;
            Navigator.of(context).push(routeGlissante(ProfilCreateurPage(createur: c.first)));
          },
          customBorder: const CircleBorder(),
          child: SizedBox(
          width: 52,
          height: 56,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Avatar(initiales: item.auteur.initiales, taille: 46, bordure: true),
              Positioned(
                bottom: 0,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppTheme.navy,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, size: 13, color: AppTheme.blanc),
                ),
              ),
            ],
          ),
          ),
        ),
        const SizedBox(height: 10),
        for (final a in actions) ...[
          _BoutonRail(action: a),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _BoutonRail extends StatelessWidget {
  final ActionRail action;
  const _BoutonRail({required this.action});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: action.onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 52,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icone, size: 28, color: AppTheme.navy),
            const SizedBox(height: 2),
            Text(
              action.libelle,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legende extends StatelessWidget {
  final FeedItem item;
  final Color couleurAccent;
  const _Legende({required this.item, required this.couleurAccent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 15, color: AppTheme.navy, fontFamily: 'Lato'),
            children: [
              TextSpan(
                text: item.auteur.pseudo,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(
                text: ' · ${item.auteur.etablissement}',
                style: const TextStyle(color: AppTheme.texteSecondaire),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          item.legende,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14, height: 1.4, color: AppTheme.texteCorps),
        ),
        if (item.hashtags.isNotEmpty) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final h in item.hashtags)
                Text(
                  h,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.orangeFonce,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

String formatCompteur(int n) {
  if (n >= 1000) {
    final k = n / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1).replaceAll('.', ',')} k';
  }
  return '$n';
}
