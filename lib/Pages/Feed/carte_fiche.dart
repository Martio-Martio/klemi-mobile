import 'package:flutter/material.dart';

import '../../Configuration/app_theme.dart';
import '../../Models/feed_item.dart';
import '../../Widgets/carte_feed.dart';
import '../../Widgets/klemi_widgets.dart';
import '../Social/commentaires_sheet.dart';

/// 2.3 · Carte fiche de révision : Essentiel · Dates clés · Lexique.
class CarteFiche extends StatefulWidget {
  final FicheItem fiche;
  final String prochain;

  const CarteFiche({super.key, required this.fiche, required this.prochain});

  @override
  State<CarteFiche> createState() => _CarteFicheState();
}

class _CarteFicheState extends State<CarteFiche> {
  int _onglet = 0;

  @override
  Widget build(BuildContext context) {
    final f = widget.fiche;
    return CarteFeed(
      item: f,
      prochain: widget.prochain,
      couleurAccent: AppTheme.vert,
      actions: [
        ActionRail(Icons.favorite_border, formatCompteur(f.likes)),
        const ActionRail(Icons.volume_up_outlined, 'Écouter'),
        ActionRail(Icons.chat_bubble_outline, 'Avis', onTap: () => ouvrirCommentaires(context)),
        const ActionRail(Icons.bookmark_border, 'Garder'),
        const ActionRail(Icons.download_outlined, 'PDF'),
      ],
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ChipType(libelle: 'Fiche', icone: Icons.description_outlined, couleur: AppTheme.vert),
              const SizedBox(width: 8),
              Expanded(
                child: Text(f.sousTitre,
                    style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            f.titre,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.3),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _construireOnglet('Essentiel', 0),
                const SizedBox(width: 6),
                _construireOnglet('Dates clés', 1),
                const SizedBox(width: 6),
                _construireOnglet('Lexique FR · BM', 2),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 280),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.blanc,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.bordure),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (_onglet) {
                0 => _Essentiel(f, key: const ValueKey(0)),
                1 => _Dates(f, key: const ValueKey(1)),
                _ => _Lexique(f, key: const ValueKey(2)),
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: KlemiBouton(
                  libelle: 'Me tester',
                  icone: Icons.auto_awesome,
                  iconeADroite: false,
                  couleur: AppTheme.vert,
                  hauteur: 46,
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: KlemiBoutonSecondaire(
                  libelle: 'Fiche complète',
                  hauteur: 46,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _construireOnglet(String libelle, int index) {
    final actif = _onglet == index;
    return InkWell(
      onTap: () => setState(() => _onglet = index),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: actif ? AppTheme.vert : AppTheme.blanc,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: actif ? AppTheme.vert : AppTheme.bordure),
        ),
        alignment: Alignment.center,
        child: Text(libelle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Essentiel extends StatelessWidget {
  final FicheItem f;
  const _Essentiel(this.f, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < f.essentiel.length; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.vert,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text('${i + 1}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(f.essentiel[i],
                    style: const TextStyle(fontSize: 15, height: 1.45, color: AppTheme.navy)),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.vertClair,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC7E4D9)),
          ),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, height: 1.45, color: AppTheme.vertFonce, fontFamily: 'Lato'),
              children: [
                const TextSpan(
                    text: 'Le savais‑tu ? ', style: TextStyle(fontWeight: FontWeight.w800)),
                TextSpan(text: f.leSaviezVous),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Dates extends StatelessWidget {
  final FicheItem f;
  const _Dates(this.f, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final d in f.dates)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                SizedBox(
                  width: 64,
                  child: Text(d.annee,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Expanded(child: Text(d.evenement, style: const TextStyle(fontSize: 14, height: 1.4))),
              ],
            ),
          ),
      ],
    );
  }
}

class _Lexique extends StatelessWidget {
  final FicheItem f;
  const _Lexique(this.f, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in f.lexique)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.mot, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 14, color: AppTheme.navy, fontFamily: 'Lato'),
                    children: [
                      TextSpan(text: '${e.definition} · bm : '),
                      TextSpan(
                          text: e.traduction, style: const TextStyle(fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
