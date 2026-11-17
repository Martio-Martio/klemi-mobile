import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Models/feed_item.dart';
import '../../Models/social.dart';
import '../../Providers/app_state.dart';
import '../../Repositories/feed_repository.dart';
import '../../Services/mobile_feed_api.dart';
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

  late final FeedRepository _repo = FeedRepository.instance;
  late AppState _etat;

  // Mémorise les langues en cours pour détecter un changement et invalider.
  String? _langueCourante;
  String? _langueAudioCourante;

  @override
  void initState() {
    super.initState();
    widget.ouverture?.addListener(_surDemandeOuverture);
    _repo.addListener(_surChangementRepo);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _etat = context.watch<AppState>();
    final nouvelleLangue = _etat.langue.id;
    final nouvelleLangueAudio = _etat.langueAudio.id;
    final premierAppel = _langueCourante == null;
    final langueAChange = _langueCourante != nouvelleLangue ||
        _langueAudioCourante != nouvelleLangueAudio;

    if (langueAChange && !premierAppel) {
      _repo.invaliderTout();
    }
    _langueCourante = nouvelleLangue;
    _langueAudioCourante = nouvelleLangueAudio;

    // Amorçage initial (ou après invalidation) pour l'onglet actif.
    if (_repo.etat(_tabCourant).items.isEmpty) {
      _repo.amorcer(_tabCourant, lang: _langueCourante, langAudio: _langueAudioCourante);
    }
  }

  @override
  void dispose() {
    widget.ouverture?.removeListener(_surDemandeOuverture);
    _repo.removeListener(_surChangementRepo);
    _controleur.dispose();
    super.dispose();
  }

  void _surChangementRepo() {
    if (mounted) setState(() {});
  }

  TabFeed get _tabCourant => switch (_onglet) {
        0 => TabFeed.pourToi,
        1 => TabFeed.mesCours,
        _ => TabFeed.abonnements,
      };

  void _changerOnglet(int index) {
    setState(() => _onglet = index);
    // Amorçage lazy du nouvel onglet.
    _repo.amorcer(_tabCourant, lang: _langueCourante, langAudio: _langueAudioCourante);
  }

  void _surDemandeOuverture() {
    final c = widget.ouverture?.value;
    if (c != null) ouvrir(c);
  }

  /// Ouvre un contenu dans « Pour toi » (recherche par titre dans les items
  /// chargés ; une amélioration Phase 2+ serait `GET /feed/:id` deep-link).
  void ouvrir(ContenuResume contenu) {
    setState(() => _onglet = 0);
    final items = _repo.etat(TabFeed.pourToi).items;
    final index = items.indexWhere((i) => i.titre == contenu.titre);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controleur.hasClients) return;
      _controleur.jumpToPage(index < 0 ? 0 : index);
    });
  }

  /// Charge la page suivante quand l'utilisateur approche de la fin.
  void _surChangementPage(int index) {
    final etat = _repo.etat(TabFeed.pourToi);
    if (index >= etat.items.length - 3 && etat.curseurSuivant != null) {
      _repo.pageSuivante(
        TabFeed.pourToi,
        lang: _langueCourante,
        langAudio: _langueAudioCourante,
      );
    }
  }

  Future<void> _rafraichirPourToi() async {
    await _repo.rafraichir(
      TabFeed.pourToi,
      lang: _langueCourante,
      langAudio: _langueAudioCourante,
    );
  }

  void _suivant() {
    _controleur.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  String _libelleProchain(List<FeedItem> items, int index) {
    if (items.isEmpty) return '';
    final suivant = items[(index + 1) % items.length];
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
    final etat = _repo.etat(TabFeed.pourToi);

    if (etat.enChargement && etat.items.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.bleu));
    }
    if (etat.erreur != null && etat.items.isEmpty) {
      return _vueErreur(etat.erreur!.message);
    }
    if (etat.estVide) {
      return _vueVide();
    }

    return RefreshIndicator(
      color: AppTheme.bleu,
      onRefresh: _rafraichirPourToi,
      child: PageView.builder(
        controller: _controleur,
        scrollDirection: Axis.vertical,
        onPageChanged: _surChangementPage,
        itemCount: etat.items.length,
        itemBuilder: (context, index) {
          final item = etat.items[index];
          final prochain = _libelleProchain(etat.items, index);
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
      ),
    );
  }

  Widget _vueVide() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.auto_stories_outlined, size: 56, color: AppTheme.texteDiscret),
            const SizedBox(height: 14),
            Text(
              'Pas encore de contenu en ${_etat.langue.nom}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.navy,
                fontFamilyFallback: AppTheme.famillesSecours,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sois le premier à en créer !',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppTheme.texteSecondaire),
            ),
          ],
        ),
      ),
    );
  }

  Widget _vueErreur(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: AppTheme.rouge),
            const SizedBox(height: 12),
            const Text(
              'Impossible de charger le feed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.navy),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
            ),
            const SizedBox(height: 14),
            TextButton(
              onPressed: _rafraichirPourToi,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _construireOnglet(String libelle, int index) {
    final actif = _onglet == index;
    return GestureDetector(
      onTap: () => _changerOnglet(index),
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
