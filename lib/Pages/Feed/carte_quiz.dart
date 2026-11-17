import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Models/feed_item.dart';
import '../../Providers/app_state.dart';
import '../../Services/mobile_feed_api.dart';
import '../../Services/social_api.dart';
import '../../Widgets/carte_feed.dart';
import '../../Widgets/klemi_widgets.dart';
import '../Social/commentaires_sheet.dart';
import 'resultat_page.dart';

/// 2.1 · Carte quiz jouable dans le feed.
class CarteQuiz extends StatefulWidget {
  final QuizItem quiz;
  final String prochain;
  final VoidCallback onSuivant;
  final MobileFeedApi? api; // injectable pour les tests

  const CarteQuiz({
    super.key,
    required this.quiz,
    required this.prochain,
    required this.onSuivant,
    this.api,
  });

  @override
  State<CarteQuiz> createState() => _CarteQuizState();
}

class _CarteQuizState extends State<CarteQuiz> {
  int? _choix;
  String? _explicationServeur;
  int? _pointsGagnesServeur;
  bool _envoiEnCours = false;
  bool _aime = false;
  late int _likes = widget.quiz.likes;

  late final MobileFeedApi _api = widget.api ?? MobileFeedApi();
  late final SocialApi _social = SocialApi();

  bool get _repondu => _choix != null;
  bool get _bonne => _choix == widget.quiz.bonneReponse;
  int get _points => _pointsGagnesServeur ?? (_bonne ? 20 : 0);
  String get _explication => _explicationServeur ?? widget.quiz.explication;

  Future<void> _repondre(int i) async {
    if (_repondu || _envoiEnCours) return;

    // Optimiste : on affiche immédiatement la correction locale, puis on
    // réconcilie avec la réponse serveur (points + explication).
    setState(() {
      _choix = i;
      _envoiEnCours = true;
    });

    final etat = context.read<AppState>();
    try {
      final reponse = await _api.answerQuiz(widget.quiz.id, i);
      if (!mounted) return;
      setState(() {
        _explicationServeur = reponse.explication;
        _pointsGagnesServeur = reponse.pointsGagnes;
        _envoiEnCours = false;
      });
      if (reponse.pointsGagnes > 0) etat.ajouterPoints(reponse.pointsGagnes);
    } catch (_) {
      // Mode offline, backend indisponible, ou ApiClient pas encore branché
      // (contexte test) : on tombe en fallback local — jamais bloquer l'UX.
      if (!mounted) return;
      setState(() => _envoiEnCours = false);
      if (_bonne) etat.ajouterPoints(20);
    }
  }

  /// Toggle like optimiste : flip local immédiat, rollback si l'API échoue.
  Future<void> _toggleLike() async {
    final etaitAime = _aime;
    setState(() {
      _aime = !_aime;
      _likes += _aime ? 1 : -1;
    });
    try {
      if (etaitAime) {
        await _social.unlikeItem(widget.quiz.id);
      } else {
        await _social.likeItem(widget.quiz.id);
      }
    } catch (_) {
      // Rollback silencieux — resync au prochain fetch du feed.
      if (!mounted) return;
      setState(() {
        _aime = etaitAime;
        _likes = widget.quiz.likes + (etaitAime ? 1 : 0);
      });
    }
  }

  /// Actions sociales encore non livrées côté API (save/share). On informe
  /// l'utilisateur sans échouer.
  void _bientot(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bientôt disponible.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quiz;
    return CarteFeed(
      item: q,
      prochain: widget.prochain,
      couleurAccent: AppTheme.orange,
      actions: [
        ActionRail(
          _aime ? Icons.favorite : Icons.favorite_border,
          formatCompteur(_likes),
          onTap: _toggleLike,
        ),
        ActionRail(
          Icons.chat_bubble_outline,
          '318',
          onTap: () => ouvrirCommentaires(context, titre: q.titre, contentId: q.id),
        ),
        ActionRail(Icons.bookmark_border, 'Garder', onTap: () => _bientot(context)),
        ActionRail(Icons.ios_share, 'Partager', onTap: () => _bientot(context)),
      ],
      contenu: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ChipType(libelle: 'Quiz', icone: Icons.help_outline, couleur: AppTheme.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Question ${q.numero} / ${q.total} · ${q.matiere}',
                  style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            q.titre,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
              color: AppTheme.navy,
              fontFamilyFallback: AppTheme.famillesSecours,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < q.reponses.length; i++) ...[
            _Reponse(
              lettre: String.fromCharCode(65 + i),
              texte: q.reponses[i],
              etat: !_repondu
                  ? _EtatReponse.neutre
                  : i == q.bonneReponse
                      ? _EtatReponse.bonne
                      : i == _choix
                          ? _EtatReponse.mauvaise
                          : _EtatReponse.estompee,
              onTap: () => _repondre(i),
            ),
            const SizedBox(height: 10),
          ],
          if (_repondu) ...[
            const SizedBox(height: 4),
            CarteBlanche(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _bonne
                        ? 'Bonne réponse ! +$_points pts'
                        : 'Pas tout à fait — la bonne réponse est ${String.fromCharCode(65 + q.bonneReponse)}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _bonne ? AppTheme.vertFonce : AppTheme.rougeFonce,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(_explication,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppTheme.texteCorps,
                        fontFamilyFallback: AppTheme.famillesSecours,
                      )),
                  const SizedBox(height: 12),
                  KlemiBouton(
                    libelle: q.numero >= q.total ? 'Voir le résultat' : 'Question suivante',
                    icone: Icons.arrow_forward,
                    couleur: AppTheme.orange,
                    hauteur: 46,
                    onPressed: () {
                      if (q.numero >= q.total || q.numero == 3) {
                        // Démo : la 3e question clôt la série pour montrer l'écran résultat.
                        Navigator.of(context).push(routeGlissante(const ResultatPage()));
                      } else {
                        widget.onSuivant();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _EtatReponse { neutre, bonne, mauvaise, estompee }

class _Reponse extends StatelessWidget {
  final String lettre;
  final String texte;
  final _EtatReponse etat;
  final VoidCallback onTap;

  const _Reponse({
    required this.lettre,
    required this.texte,
    required this.etat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bordure = AppTheme.bordure;
    Color fond = AppTheme.blanc;
    Color texteCouleur = AppTheme.navy;
    Color badgeFond = AppTheme.sable;
    switch (etat) {
      case _EtatReponse.bonne:
        bordure = AppTheme.vert;
        fond = AppTheme.vertClair;
        badgeFond = AppTheme.vert;
        break;
      case _EtatReponse.mauvaise:
        bordure = AppTheme.rouge;
        fond = AppTheme.rougeClair;
        badgeFond = AppTheme.rouge;
        break;
      case _EtatReponse.estompee:
        texteCouleur = AppTheme.texteDiscret;
        break;
      case _EtatReponse.neutre:
        break;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: fond,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: bordure, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: badgeFond,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(lettre,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texte,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: texteCouleur,
                  fontFamilyFallback: AppTheme.famillesSecours,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
