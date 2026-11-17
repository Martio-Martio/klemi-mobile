import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Data/mock_social.dart';
import '../../Models/feed_item.dart';
import '../../Models/social.dart';
import '../../Providers/app_state.dart';
import '../../Services/api_exception.dart';
import '../../Services/social_api.dart';
import '../../Widgets/klemi_widgets.dart';
import '../../Widgets/ligne_contenu.dart';

/// Profil public d'un enseignant / créateur, avec bouton Suivre.
class ProfilCreateurPage extends StatefulWidget {
  final Createur createur;
  final SocialApi? api; // injectable pour les tests
  const ProfilCreateurPage({super.key, required this.createur, this.api});

  @override
  State<ProfilCreateurPage> createState() => _ProfilCreateurPageState();
}

class _ProfilCreateurPageState extends State<ProfilCreateurPage> {
  TypeContenu? _filtre;
  bool _switchEnCours = false;
  late final SocialApi _api = widget.api ?? SocialApi();

  Future<void> _basculerSuivi(BuildContext context, AppState etat, String id) async {
    if (_switchEnCours) return;
    final etaitSuivi = etat.suit(id);
    // Capture AVANT l'await pour éviter le lint use_build_context_synchronously.
    final messenger = ScaffoldMessenger.of(context);

    etat.basculerSuivi(id);
    setState(() => _switchEnCours = true);
    try {
      if (etaitSuivi) {
        await _api.unfollow(id);
      } else {
        await _api.follow(id);
      }
    } on ApiException catch (e) {
      etat.basculerSuivi(id); // rollback
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
      );
    } catch (_) {
      // ApiClient pas branché (tests widget sans setup) : on garde l'état local.
    } finally {
      if (mounted) setState(() => _switchEnCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.createur;
    final etat = context.watch<AppState>();
    final suivi = etat.suit(c.id);
    final contenus = tendances
        .where((t) => t.createurId == c.id && (_filtre == null || t.type == _filtre))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const BoutonRetour(),
                IconButton(
                  tooltip: 'Partager le profil',
                  onPressed: () {},
                  icon: const Icon(Icons.ios_share, color: AppTheme.navy),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Avatar(
                  initiales: c.initiales,
                  taille: 72,
                  couleur: c.id == 'klemi' ? AppTheme.bleu : AppTheme.orange,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nom, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text('${c.pseudo} · ${c.etablissement}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Chiffre('${c.contenus}', 'contenus'),
                const SizedBox(width: 24),
                _Chiffre(_milliers(c.abonnes + (suivi ? 1 : 0)), 'abonnés'),
                const SizedBox(width: 24),
                const _Chiffre('4,8', 'note'),
              ],
            ),
            const SizedBox(height: 12),
            Text(c.bio, style: const TextStyle(fontSize: 14, height: 1.45, color: AppTheme.texteCorps)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: BoutonSuivre(
                    suivi: suivi,
                    onTap: () {
                      if (_switchEnCours) return;
                      _basculerSuivi(context, context.read<AppState>(), c.id);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: KlemiBoutonSecondaire(
                    libelle: 'Message',
                    icone: Icons.chat_bubble_outline,
                    hauteur: 44,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _filtreChip('Tout', null),
                const SizedBox(width: 6),
                _filtreChip('Quiz', TypeContenu.quiz),
                const SizedBox(width: 6),
                _filtreChip('Fiches', TypeContenu.fiche),
                const SizedBox(width: 6),
                _filtreChip('Podcasts', TypeContenu.podcast),
              ],
            ),
            const SizedBox(height: 10),
            if (contenus.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucun contenu dans cette catégorie pour le moment.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppTheme.texteDiscret)),
              ),
            for (final t in contenus) ...[
              LigneContenu(contenu: t, sousTitre: ilYA(t.publieLe), onTap: () {}),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filtreChip(String libelle, TypeContenu? type) {
    final actif = _filtre == type;
    return ChoiceChip(
      label: Text(libelle),
      selected: actif,
      onSelected: (_) => setState(() => _filtre = type),
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

  static String _milliers(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1).replaceAll('.0', '').replaceAll('.', ',')} k';
    return '$n';
  }
}

class _Chiffre extends StatelessWidget {
  final String valeur;
  final String libelle;
  const _Chiffre(this.valeur, this.libelle);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(valeur, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text(libelle, style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
      ],
    );
  }
}
