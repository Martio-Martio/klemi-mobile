import 'package:flutter/material.dart';

import '../../Configuration/app_theme.dart';
import '../../Data/mock_feed.dart';
import '../../Models/feed_item.dart';
import '../../Models/social.dart';
import '../../Widgets/klemi_widgets.dart';
import 'abonnements_page.dart';
import 'carte_fiche.dart';
import 'carte_podcast.dart';
import 'carte_quiz.dart';
import 'mes_cours_page.dart';

/// 2.x · Feed : onglets « Pour toi » (scroll vertical infini), « Mes cours »
/// et « Abonnements ».
class FeedPage extends StatefulWidget {
  /// Demande d'ouverture d'un contenu depuis un autre onglet (Explorer…).
  final ValueNotifier<ContenuResume?>? ouverture;
  const FeedPage({super.key, this.ouverture});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final _controleur = PageController();
  int _onglet = 0;
  final List<FeedItem> _items = List.of(feedDemo);

  @override
  void initState() {
    super.initState();
    widget.ouverture?.addListener(_surDemandeOuverture);
  }

  @override
  void dispose() {
    widget.ouverture?.removeListener(_surDemandeOuverture);
    _controleur.dispose();
    super.dispose();
  }

  void _surDemandeOuverture() {
    final c = widget.ouverture?.value;
    if (c != null) ouvrir(c);
  }

  /// Ouvre un contenu dans « Pour toi » (recherche par titre dans le flux
  /// de démo ; avec l'API ce sera `GET /feed?start=<id>`).
  void ouvrir(ContenuResume contenu) {
    setState(() => _onglet = 0);
    final index = _items.indexWhere((i) => i.titre == contenu.titre);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controleur.hasClients) return;
      _controleur.jumpToPage(index < 0 ? 0 : index);
    });
  }

  /// Simule le chargement de la page suivante de `GET /feed` : on boucle sur
  /// les contenus de démo quand on approche de la fin.
  void _chargerSuite(int index) {
    if (index >= _items.length - 2) {
      setState(() => _items.addAll(feedDemo));
    }
  }

  void _suivant() {
    _controleur.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  String _libelleProchain(int index) {
    final suivant = _items[(index + 1) % _items.length];
    switch (suivant.type) {
      case TypeContenu.quiz:
        return 'Quiz suivant';
      case TypeContenu.fiche:
        return 'Fiche de révision';
      case TypeContenu.podcast:
        return 'Podcast';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Row(
            children: [
              _construireOnglet('Pour toi', 0),
              const SizedBox(width: 18),
              _construireOnglet('Mes cours', 1),
              const SizedBox(width: 18),
              _construireOnglet('Abonnements', 2),
              const Spacer(),
              const ChipLangue(),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _onglet,
            children: [
              _pourToi(),
              MesCoursPage(onOuvrir: ouvrir),
              AbonnementsPage(onOuvrir: ouvrir),
            ],
          ),
        ),
      ],
    );
  }

  Widget _pourToi() {
    return PageView.builder(
      controller: _controleur,
      scrollDirection: Axis.vertical,
      onPageChanged: _chargerSuite,
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        final prochain = _libelleProchain(index);
        switch (item.type) {
          case TypeContenu.quiz:
            return CarteQuiz(
              key: ValueKey('$index-${item.id}'),
              quiz: item as QuizItem,
              prochain: prochain,
              onSuivant: _suivant,
            );
          case TypeContenu.fiche:
            return CarteFiche(
              key: ValueKey('$index-${item.id}'),
              fiche: item as FicheItem,
              prochain: prochain,
            );
          case TypeContenu.podcast:
            return CartePodcast(
              key: ValueKey('$index-${item.id}'),
              podcast: item as PodcastItem,
              prochain: prochain,
            );
        }
      },
    );
  }

  Widget _construireOnglet(String libelle, int index) {
    final actif = _onglet == index;
    return GestureDetector(
      onTap: () => setState(() => _onglet = index),
      child: Container(
        padding: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(width: 3, color: actif ? AppTheme.orange : Colors.transparent),
          ),
        ),
        child: Text(
          libelle,
          style: TextStyle(
            fontSize: actif ? 17 : 16,
            fontWeight: actif ? FontWeight.w800 : FontWeight.w500,
            color: actif ? AppTheme.navy : AppTheme.texteDiscret,
          ),
        ),
      ),
    );
  }
}
