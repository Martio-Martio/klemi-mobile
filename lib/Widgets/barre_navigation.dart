import 'package:flutter/material.dart';

import '../Configuration/app_theme.dart';

/// Onglets de la barre du bas : Feed · Explorer · Créer · Biblio · Profil.
enum OngletApp { feed, explorer, creer, biblio, profil }

class BarreNavigation extends StatelessWidget {
  final OngletApp actif;
  final ValueChanged<OngletApp> onChanged;

  const BarreNavigation({
    super.key,
    required this.actif,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bas = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, bas > 0 ? bas : 12),
      decoration: const BoxDecoration(
        color: AppTheme.beige,
        border: Border(top: BorderSide(color: AppTheme.bordure)),
      ),
      child: Row(
        children: [
          _item(OngletApp.feed, Icons.home_outlined, Icons.home, 'Feed'),
          _item(OngletApp.explorer, Icons.search, Icons.search, 'Explorer'),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(OngletApp.creer),
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Container(
                    width: 48,
                    height: 34,
                    decoration: BoxDecoration(
                      color: actif == OngletApp.creer ? AppTheme.navy : AppTheme.bleu,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add,
                      size: 24,
                      color: actif == OngletApp.creer ? AppTheme.blanc : AppTheme.navy,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _item(OngletApp.biblio, Icons.folder_outlined, Icons.folder, 'Biblio'),
          _item(OngletApp.profil, Icons.person_outline, Icons.person, 'Profil'),
        ],
      ),
    );
  }

  Widget _item(OngletApp onglet, IconData icone, IconData iconeActive, String libelle) {
    final estActif = actif == onglet;
    final couleur = estActif ? AppTheme.navy : AppTheme.texteDiscret;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(onglet),
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(estActif ? iconeActive : icone, size: 24, color: couleur),
              const SizedBox(height: 4),
              Text(
                libelle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: estActif ? FontWeight.w700 : FontWeight.w500,
                  color: couleur,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
