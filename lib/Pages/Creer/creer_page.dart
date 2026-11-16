import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Configuration/langues.dart';
import '../../Configuration/matieres.dart';
import '../../Models/feed_item.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';

/// 3.1 · Créer un contenu : type, source, langue, options, génération.
class CreerPage extends StatefulWidget {
  final VoidCallback? onGenere; // retour au feed après génération
  const CreerPage({super.key, this.onGenere});

  @override
  State<CreerPage> createState() => _CreerPageState();
}

class _CreerPageState extends State<CreerPage> {
  TypeContenu _type = TypeContenu.quiz;
  String _source = 'file';
  late String _langue;
  int _questions = 10;
  int _duree = 0; // 0 court, 1 moyen
  bool _fichierDepose = true;

  @override
  void initState() {
    super.initState();
    _langue = context.read<AppState>().langue.id;
  }

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

  @override
  Widget build(BuildContext context) {
    final etat = context.watch<AppState>();
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
            const SizedBox(height: 16),
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
            if (_fichierDepose)
              Container(
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
              )
            else
              OutlinedButton.icon(
                onPressed: () => setState(() => _fichierDepose = true),
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Choisir un fichier'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppTheme.navy,
                  side: const BorderSide(color: AppTheme.bordurePointillee, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            const SizedBox(height: 16),
            _titre('Langue du contenu'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final l in languesDisponibles)
                  ChoiceChip(
                    label: Text(l.nom),
                    selected: _langue == l.id,
                    onSelected: (_) => setState(() => _langue = l.id),
                    selectedColor: AppTheme.navy,
                    backgroundColor: AppTheme.blanc,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _langue == l.id ? AppTheme.blanc : AppTheme.navy,
                    ),
                    side: BorderSide(color: _langue == l.id ? AppTheme.navy : AppTheme.bordure),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            switch (_type) {
              TypeContenu.quiz => Row(
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
                                _plusMoins(Icons.remove, () => setState(() => _questions = (_questions - 5).clamp(5, 40).toInt())),
                                Text('$_questions',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                _plusMoins(Icons.add, () => setState(() => _questions = (_questions + 5).clamp(5, 40).toInt())),
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
                ),
              TypeContenu.podcast => CarteBlanche(
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
                ),
              TypeContenu.fiche => const CarteBlanche(
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
                ),
            },
            const SizedBox(height: 24),
            KlemiBouton(
              libelle: _libelleCta,
              icone: Icons.auto_awesome,
              iconeADroite: false,
              couleur: _couleurType,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$_libelleCta… il apparaîtra dans ton feed dans quelques minutes.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                widget.onGenere?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

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
