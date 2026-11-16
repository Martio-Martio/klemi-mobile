import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Configuration/matieres.dart';
import '../../Data/mock_social.dart';
import '../../Models/feed_item.dart';
import '../../Models/social.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';
import '../../Widgets/ligne_contenu.dart';
import '../../Widgets/matieres_widgets.dart';
import '../Social/profil_createur_page.dart';

/// Onglet Explorer : recherche, matières, enseignants, tendances.
class ExplorerPage extends StatefulWidget {
  final void Function(ContenuResume)? onOuvrir;
  const ExplorerPage({super.key, this.onOuvrir});

  @override
  State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  final _recherche = TextEditingController();
  String _requete = '';
  String? _matiere;
  TypeContenu? _type;

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  List<ContenuResume> get _resultats {
    final q = _requete.toLowerCase();
    return tendances.where((t) {
      final okTexte = q.isEmpty ||
          t.titre.toLowerCase().contains(q) ||
          createurParId(t.createurId).pseudo.toLowerCase().contains(q);
      final okType = _type == null || t.type == _type;
      return okTexte && okType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final enRecherche = _requete.isNotEmpty || _type != null || _matiere != null;
    final resultats = _resultats;
    final etat = context.watch<AppState>();
    final matieres = etat.matieres;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Text('Explorer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _recherche,
            onChanged: (v) => setState(() => _requete = v),
            decoration: InputDecoration(
              hintText: 'Matière, niveau, enseignant, mot‑clé…',
              prefixIcon: const Icon(Icons.search, color: AppTheme.texteDiscret),
              suffixIcon: _requete.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _recherche.clear();
                        _requete = '';
                      }),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chipType('Tout', null),
                const SizedBox(width: 6),
                _chipType('Quiz', TypeContenu.quiz),
                const SizedBox(width: 6),
                _chipType('Fiches', TypeContenu.fiche),
                const SizedBox(width: 6),
                _chipType('Podcasts', TypeContenu.podcast),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!enRecherche) ...[
            Row(
              children: [
                const Expanded(child: _Titre('Mes matières')),
                Text(
                  etat.niveauEtudes.libelle,
                  style: const TextStyle(fontSize: 12, color: AppTheme.texteDiscret),
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
              children: [
                for (var i = 0; i < matieres.length; i++)
                  InkWell(
                    onTap: () => setState(() {
                      _matiere = matieres[i];
                      _recherche.text = matieres[i];
                      _requete = matieres[i];
                    }),
                    onLongPress: () => context.read<AppState>().retirerMatiere(matieres[i]),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.blanc,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.bordure),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: [AppTheme.orange, AppTheme.vert, AppTheme.bleu][i % 3],
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: Icon(_iconeMatiere(matieres[i]), size: 16, color: AppTheme.navy),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(matieres[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                InkWell(
                  onTap: () => ouvrirAjoutMatiere(context),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bleuClair,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.bleu, width: 2),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 26, color: AppTheme.navy),
                        SizedBox(height: 4),
                        Text('Ajouter', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Appui long sur une matière pour la retirer · modifiable aussi dans Paramètres.',
                  style: TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
            ),
            const SizedBox(height: 18),
            const _Titre('Enseignants à suivre'),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: createurs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final c = createurs[i];
                  return InkWell(
                    onTap: () => Navigator.of(context).push(
                      routeGlissante(ProfilCreateurPage(createur: c)),
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 132,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.blanc,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.bordure),
                      ),
                      child: Column(
                        children: [
                          Avatar(initiales: c.initiales, taille: 40,
                              couleur: c.id == 'klemi' ? AppTheme.bleu : AppTheme.orange),
                          const SizedBox(height: 6),
                          Text(c.pseudo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          Text('${c.contenus} contenus',
                              style: const TextStyle(fontSize: 11, color: AppTheme.texteDiscret)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            const _Titre('Tendances cette semaine'),
          ] else
            _Titre(resultats.isEmpty ? 'Aucun résultat' : '${resultats.length} résultats'),
          for (final t in resultats) ...[
            LigneContenu(
              contenu: t,
              sousTitre: createurParId(t.createurId).pseudo,
              onTap: () => widget.onOuvrir?.call(t),
            ),
            const SizedBox(height: 8),
          ],
          if (enRecherche && resultats.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Essaie un autre mot‑clé, ou crée ce contenu toi‑même avec le bouton « + ».',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.texteDiscret),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipType(String libelle, TypeContenu? type) {
    final actif = _type == type;
    return ChoiceChip(
      label: Text(libelle),
      selected: actif,
      onSelected: (_) => setState(() => _type = type),
      selectedColor: AppTheme.navy,
      backgroundColor: AppTheme.blanc,
      showCheckmark: false,
      labelStyle: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: actif ? AppTheme.blanc : AppTheme.navy),
      side: BorderSide(color: actif ? AppTheme.navy : AppTheme.bordure),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      visualDensity: VisualDensity.compact,
    );
  }

  static IconData _iconeMatiere(String m) {
    final x = m.toLowerCase();
    if (x.contains('histoire')) return Icons.account_balance_outlined;
    if (x.contains('géo')) return Icons.public;
    if (x.contains('math') || x.contains('stat')) return Icons.functions;
    if (x.contains('svt') || x.contains('bio') || x.contains('agro')) return Icons.eco_outlined;
    if (x.contains('phys') || x.contains('chim') || x.contains('électro')) return Icons.bolt_outlined;
    if (x.contains('français') || x.contains('philo') || x.contains('socio')) return Icons.menu_book_outlined;
    if (x.contains('anglais') || x.contains('arabe') || x.contains('espagnol') || x.contains('allemand')) return Icons.translate;
    if (x.contains('droit') || x.contains('admin') || x.contains('politi')) return Icons.gavel_outlined;
    if (x.contains('éco') || x.contains('gestion') || x.contains('compta') || x.contains('finance') || x.contains('market')) return Icons.trending_up;
    if (x.contains('info') || x.contains('génie') || x.contains('méca') || x.contains('archi')) return Icons.memory_outlined;
    if (x.contains('méde') || x.contains('pharma') || x.contains('anat') || x.contains('nutri')) return Icons.medical_services_outlined;
    return Icons.school_outlined;
  }
}

class _Titre extends StatelessWidget {
  final String t;
  const _Titre(this.t);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
    );
  }
}
