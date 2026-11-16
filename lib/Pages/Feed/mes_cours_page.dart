import 'package:flutter/material.dart';

import '../../Configuration/app_theme.dart';
import '../../Data/mock_social.dart';
import '../../Models/social.dart';
import '../../Widgets/klemi_widgets.dart';
import '../../Widgets/ligne_contenu.dart';
import '../Social/profil_createur_page.dart';

/// Onglet « Mes cours » du feed : les contenus publiés par les enseignants
/// des classes/groupes de l'élève, dans l'ordre du programme.
class MesCoursPage extends StatefulWidget {
  final void Function(ContenuResume)? onOuvrir;
  const MesCoursPage({super.key, this.onOuvrir});

  @override
  State<MesCoursPage> createState() => _MesCoursPageState();
}

class _MesCoursPageState extends State<MesCoursPage> {
  String _coursId = mesCours.first.id;

  @override
  Widget build(BuildContext context) {
    final cours = mesCours.firstWhere((c) => c.id == _coursId);
    final enseignant = createurParId(cours.enseignantId);
    final progression = cours.total == 0 ? 0.0 : cours.faits / cours.total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      children: [
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in mesCours) ...[
                ChoiceChip(
                  label: Text(c.matiere),
                  selected: c.id == _coursId,
                  onSelected: (_) => setState(() => _coursId = c.id),
                  selectedColor: AppTheme.navy,
                  backgroundColor: AppTheme.blanc,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.id == _coursId ? AppTheme.blanc : AppTheme.navy,
                  ),
                  side: BorderSide(color: c.id == _coursId ? AppTheme.navy : AppTheme.bordure),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        CarteBlanche(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Avatar(initiales: enseignant.initiales, taille: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cours.classe,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                        Text('${enseignant.nom} · ${enseignant.pseudo}',
                            style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: "Profil de l'enseignant",
                    onPressed: () => Navigator.of(context).push(
                      routeGlissante(ProfilCreateurPage(createur: enseignant)),
                    ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Progression du programme',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('${cours.faits} / ${cours.total} contenus',
                      style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progression,
                  minHeight: 10,
                  backgroundColor: AppTheme.bordure,
                  color: AppTheme.vert,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        for (final ch in cours.chapitres) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(ch.titre, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          for (final c in ch.contenus) ...[
            LigneContenu(
              contenu: c,
              afficherFait: true,
              sousTitre: ilYA(c.publieLe),
              onTap: () => widget.onOuvrir?.call(c),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.bordurePointillee, width: 2),
          ),
          child: Row(
            children: [
              const Icon(Icons.qr_code_2, color: AppTheme.navy),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Rejoindre une autre classe avec un code établissement',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              TextButton(onPressed: () {}, child: const Text('Entrer le code')),
            ],
          ),
        ),
      ],
    );
  }
}
