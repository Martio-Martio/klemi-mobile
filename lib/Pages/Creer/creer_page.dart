import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Configuration/langues.dart';
import '../../Configuration/matieres.dart';
import '../../Models/feed_item.dart';
import '../../Providers/app_state.dart';
import '../../Services/api_exception.dart';
import '../../Services/creation_api.dart';
import '../../Widgets/klemi_widgets.dart';
import '../../Widgets/klemi_zone_photos.dart';
import '../Auth/langue_page.dart';

/// 3.1 · Créer un contenu : type, source, langue effective, options, génération.
class CreerPage extends StatefulWidget {
  final VoidCallback? onGenere; // retour au feed après génération
  final CreationApi? api; // injectable pour tests
  const CreerPage({super.key, this.onGenere, this.api});

  @override
  State<CreerPage> createState() => _CreerPageState();
}

class _CreerPageState extends State<CreerPage> {
  TypeContenu _type = TypeContenu.quiz;
  String _source = 'file';
  int _questions = 10;
  int _duree = 0; // 0 court, 1 moyen
  bool _fichierDepose = true;
  List<File> _photos = const [];
  bool _enCours = false;

  late final CreationApi _api = widget.api ?? CreationApi();

  Color get _couleurType => switch (_type) {
        TypeContenu.quiz => AppTheme.orange,
        TypeContenu.fiche => AppTheme.vert,
        TypeContenu.podcast => AppTheme.bleu,
      };

  String get _libelleCta => switch (_type) {
        TypeContenu.quiz => 'Générer le quiz',
        TypeContenu.fiche => 'Générer la fiche',
        TypeContenu.podcast => 'Générer le podcast',
      };

  /// Langue effective = `langue` pour quiz/fiche, `langueAudio` pour podcast.
  /// Règle split Phase 2 — l'API renverra 400 `UNSUPPORTED_LANGUAGE` si la
  /// langue n'est pas cohérente avec le type.
  Langue _langueEffective(AppState etat) => switch (_type) {
        TypeContenu.quiz || TypeContenu.fiche => etat.langue,
        TypeContenu.podcast => etat.langueAudio,
      };

  @override
  Widget build(BuildContext context) {
    final etat = context.watch<AppState>();
    final langue = _langueEffective(etat);
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Créer', style: Theme.of(context).textTheme.titleLarge),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.blanc,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppTheme.bordure),
                  ),
                  child: Text('${etat.generationsRestantes} générations restantes',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.texteDiscret)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _bandeauLangue(langue),
            const SizedBox(height: 14),
            _titre('Que veux‑tu créer ?'),
            Row(
              children: [
                _carteType(TypeContenu.quiz, 'Quiz', Icons.help_outline, AppTheme.orange),
                const SizedBox(width: 8),
                _carteType(TypeContenu.fiche, 'Fiche', Icons.description_outlined, AppTheme.vert),
                const SizedBox(width: 8),
                _carteType(TypeContenu.podcast, 'Podcast', Icons.mic_none, AppTheme.bleu),
              ],
            ),
            const SizedBox(height: 16),
            _titre('À partir de'),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 3,
              children: [
                _carteSource('file', 'Fichier', 'PDF, DOCX, PPTX', Icons.insert_drive_file_outlined),
                _carteSource('photo', 'Photo du cours', 'Appareil photo', Icons.photo_camera_outlined),
                _carteSource('youtube', 'YouTube', 'Lien vidéo', Icons.smart_display_outlined),
                _carteSource('text', 'Texte', 'Coller ou dicter', Icons.notes),
              ],
            ),
            const SizedBox(height: 12),
            _zoneSource(),
            const SizedBox(height: 16),
            switch (_type) {
              TypeContenu.quiz => _optionsQuiz(etat),
              TypeContenu.podcast => _optionsPodcast(),
              TypeContenu.fiche => _optionsFiche(),
            },
            const SizedBox(height: 24),
            KlemiBouton(
              libelle: _libelleCta,
              icone: Icons.auto_awesome,
              iconeADroite: false,
              couleur: _couleurType,
              onPressed: _enCours ? null : () => _soumettre(etat),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Bandeau langue ────────────────────────────────────────────────────

  Widget _bandeauLangue(Langue langue) {
    final usePolicesSecours = langue.id == 'bm' || langue.id == 'sus' || langue.id == 'ful';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: AppTheme.bleuClair,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.bleu.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.bleuFonce),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 13, color: AppTheme.navy),
                    children: [
                      TextSpan(text: 'Ce $_motType sera généré en '),
                      TextSpan(
                        text: langue.nom,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontFamilyFallback: AppTheme.famillesSecours,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                if (usePolicesSecours)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'Le contenu utilisera les lettres ɛ ɔ ɓ ɗ ŋ.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.texteSecondaire,
                        fontFamilyFallback: AppTheme.famillesSecours,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).push(routeGlissante(const LanguePage())),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Changer',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.bleuFonce)),
          ),
        ],
      ),
    );
  }

  String get _motType => switch (_type) {
        TypeContenu.quiz => 'quiz',
        TypeContenu.fiche => 'fiche',
        TypeContenu.podcast => 'podcast',
      };

  // ─── Zone source ───────────────────────────────────────────────────────

  Widget _zoneSource() {
    if (_source == 'photo') {
      return KlemiZonePhotos(
        photos: _photos,
        onChanged: (liste) => setState(() => _photos = liste),
      );
    }
    // Pour les autres sources on garde le mock temporaire (sera remplacé par
    // un vrai picker / champ URL / champ texte quand l'API sera branchée).
    if (_fichierDepose) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.beigeClair,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.bordurePointillee, width: 2),
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
              child: const Icon(Icons.upload_outlined, size: 20, color: AppTheme.navy),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('cours_histoire_3e.pdf',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('12 pages · 1,8 Mo · prêt',
                      style: TextStyle(fontSize: 12, color: AppTheme.texteDiscret)),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Retirer le fichier',
              onPressed: () => setState(() => _fichierDepose = false),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => setState(() => _fichierDepose = true),
      icon: const Icon(Icons.upload_outlined),
      label: const Text('Choisir un fichier'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppTheme.navy,
        side: const BorderSide(color: AppTheme.bordurePointillee, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ─── Options par type ──────────────────────────────────────────────────

  Widget _optionsQuiz(AppState etat) {
    return Row(
      children: [
        Expanded(
          child: CarteBlanche(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Questions',
                    style: TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _plusMoins(Icons.remove,
                        () => setState(() => _questions = (_questions - 5).clamp(5, 40).toInt())),
                    Text('$_questions',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    _plusMoins(Icons.add,
                        () => setState(() => _questions = (_questions + 5).clamp(5, 40).toInt())),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: CarteBlanche(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Niveau', style: TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text('${etat.classe} · ${etat.niveauEtudes.libelle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    ),
                    const Icon(Icons.expand_more, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _optionsPodcast() {
    return CarteBlanche(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Durée · deux voix (Fanta et Musa)',
              style: TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
          const SizedBox(height: 6),
          KlemiSegments(
            libelles: const ['Court · 5 min', 'Moyen · 12 min'],
            index: _duree,
            onChanged: (i) => setState(() => _duree = i),
          ),
        ],
      ),
    );
  }

  Widget _optionsFiche() {
    return const CarteBlanche(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sections', style: TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
          SizedBox(height: 4),
          Text('Essentiel · Dates clés · Lexique bilingue',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ─── Submit ────────────────────────────────────────────────────────────

  Future<void> _soumettre(AppState etat) async {
    if (_enCours) return;

    // Validation côté UI : les combos impossibles ne doivent pas atteindre
    // l'API (sinon 400 UNSUPPORTED_LANGUAGE ou 400 PODCAST_IMAGES_NON_SUPPORTE).
    if (_type == TypeContenu.podcast && _source == 'photo') {
      _snack('Les podcasts ne se génèrent pas depuis des photos — choisis texte, fichier ou YouTube.');
      return;
    }
    if (_source == 'photo' && _photos.isEmpty) {
      _snack('Ajoute au moins une photo de ton cours.');
      return;
    }

    final langue = _langueEffective(etat).id;
    final options = OptionsCreation(
      nombreQuestions: _questions,
      dureePodcast: _duree == 0 ? 'court' : 'moyen',
    );

    setState(() => _enCours = true);
    EasyLoading.show(status: '${_libelleCta.toLowerCase()}…');
    try {
      final job = await _lancerGeneration(langue, options);
      if (!mounted) return;
      EasyLoading.dismiss();
      _snack('Lancée. ID job : ${job.jobId}. Elle apparaîtra dans ton feed sous peu.');
      widget.onGenere?.call();
    } on ApiException catch (e) {
      if (!mounted) return;
      EasyLoading.dismiss();
      _surErreurApi(e);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<JobCreation> _lancerGeneration(String langue, OptionsCreation options) async {
    final source = _construireSource();
    return switch (_type) {
      TypeContenu.quiz => switch (source) {
          SourceFichier() => _api.genererQuizDepuisFichier(source, language: langue, options: options),
          SourceImages() => _api.genererQuizDepuisImages(source, language: langue, options: options),
          SourceYoutube() => _api.genererQuizDepuisYoutube(source, language: langue, options: options),
          SourceTexte() => _api.genererQuizDepuisTexte(source, language: langue, options: options),
        },
      TypeContenu.fiche => switch (source) {
          SourceFichier() => _api.genererFicheDepuisFichier(source, language: langue, options: options),
          SourceImages() => _api.genererFicheDepuisImages(source, language: langue, options: options),
          SourceYoutube() => _api.genererFicheDepuisYoutube(source, language: langue, options: options),
          SourceTexte() => _api.genererFicheDepuisTexte(source, language: langue, options: options),
        },
      TypeContenu.podcast =>
        _api.genererPodcast(source, language: langue, options: options),
    };
  }

  SourceCreation _construireSource() {
    switch (_source) {
      case 'photo':
        return SourceImages(_photos);
      case 'youtube':
        // Pas encore de champ URL dans l'UI — placeholder en attendant.
        return const SourceYoutube('https://youtube.com/watch?v=xxxx');
      case 'text':
        return const SourceTexte('Contenu dicté par l\'utilisateur.');
      case 'file':
      default:
        // Pas encore de file picker PDF — placeholder en attendant.
        throw ApiException(
          statusCode: 400,
          message: 'Le picker de fichier PDF arrive bientôt. Utilise « Photo du cours » ou « Texte ».',
          code: 'FILE_PICKER_NON_IMPLEMENTE',
        );
    }
  }

  void _surErreurApi(ApiException e) {
    if (e.code == 'UNSUPPORTED_LANGUAGE') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cette langue n\'est pas supportée pour ce type de contenu.'),
          action: SnackBarAction(
            label: 'Changer',
            onPressed: () => Navigator.of(context).push(routeGlissante(const LanguePage())),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (e.statusCode == 402 || e.code == 'QUOTA_DEPASSE') {
      _snack('Quota de générations atteint. Pense à passer Premium !');
      return;
    }
    _snack(e.message);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  // ─── Petits widgets utilitaires ────────────────────────────────────────

  Widget _titre(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _carteType(TypeContenu type, String libelle, IconData icone, Color couleur) {
    final actif = _type == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _type = type),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 80,
          decoration: BoxDecoration(
            color: AppTheme.blanc,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: actif ? couleur : AppTheme.bordure, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: couleur, borderRadius: BorderRadius.circular(10)),
                child: Icon(icone, size: 18, color: AppTheme.navy),
              ),
              const SizedBox(height: 6),
              Text(libelle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteSource(String id, String libelle, String indice, IconData icone) {
    final actif = _source == id;
    return InkWell(
      onTap: () => setState(() => _source = id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.blanc,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: actif ? AppTheme.navy : AppTheme.bordure, width: 2),
        ),
        child: Row(
          children: [
            Icon(icone, size: 20, color: AppTheme.navy),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(libelle,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  Text(indice,
                      style: const TextStyle(fontSize: 11, color: AppTheme.texteDiscret),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plusMoins(IconData icone, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppTheme.beigeClair,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.bordure),
        ),
        child: Icon(icone, size: 16, color: AppTheme.navy),
      ),
    );
  }
}
