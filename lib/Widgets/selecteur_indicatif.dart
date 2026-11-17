import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../Configuration/app_theme.dart';
import '../Data/catalogue_pays.dart';
import '../Models/pays.dart';

/// Bouton d'indicatif qui ouvre une feuille de recherche sur le catalogue.
class SelecteurIndicatif extends StatefulWidget {
  final Pays pays;
  final ValueChanged<Pays> onChanged;

  const SelecteurIndicatif({
    super.key,
    required this.pays,
    required this.onChanged,
  });

  @override
  State<SelecteurIndicatif> createState() => _SelecteurIndicatifState();
}

class _SelecteurIndicatifState extends State<SelecteurIndicatif> {
  List<Pays> _catalogue = const [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final liste = await CataloguePays.charger();
    if (!mounted) return;
    setState(() => _catalogue = liste);
  }

  Future<void> _ouvrir() async {
    final liste = _catalogue.isEmpty ? await CataloguePays.charger() : _catalogue;
    if (!mounted) return;
    if (_catalogue.isEmpty) setState(() => _catalogue = liste);
    final choisi = await showModalBottomSheet<Pays>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.beige,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _FeuilleIndicatif(
        pays: liste,
        identifiant: widget.pays.identifiant,
      ),
    );
    if (choisi != null) widget.onChanged(choisi);
  }

  @override
  Widget build(BuildContext context) {
    final pays = widget.pays;
    final drapeau = pays.map;
    return Material(
      color: AppTheme.blanc,
      borderRadius: BorderRadius.circular(AppTheme.radiusChamp),
      child: InkWell(
        onTap: _ouvrir,
        borderRadius: BorderRadius.circular(AppTheme.radiusChamp),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusChamp),
            border: Border.all(color: AppTheme.bordure),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (drapeau != null && drapeau.isNotEmpty) ...[
                Text(drapeau, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
              ],
              Text(
                pays.callingCodes,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  fontFamilyFallback: AppTheme.famillesSecours,
                ),
              ),
              const Icon(Icons.expand_more, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeuilleIndicatif extends StatefulWidget {
  final List<Pays> pays;
  final String identifiant;

  const _FeuilleIndicatif({required this.pays, required this.identifiant});

  @override
  State<_FeuilleIndicatif> createState() => _FeuilleIndicatifState();
}

class _FeuilleIndicatifState extends State<_FeuilleIndicatif> {
  final _recherche = TextEditingController();
  String _requete = '';

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtres = filtrerPays(widget.pays, _requete);
    final bas = MediaQuery.viewPaddingOf(context).bottom;
    final clavier = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, controleur) {
        return Padding(
          padding: EdgeInsets.only(bottom: clavier),
          child: Column(
            children: [
              const SizedBox(height: 14),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.bordurePointillee,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Indicatif',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFamilyFallback: AppTheme.famillesSecours,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _recherche,
                  autofocus: true,
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamilyFallback: AppTheme.famillesSecours,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un pays',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                  onChanged: (valeur) => setState(() => _requete = valeur),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  controller: controleur,
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bas),
                  itemCount: filtres.isEmpty ? 1 : filtres.length,
                  itemBuilder: (context, index) {
                    if (filtres.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            'Aucun pays',
                            style: TextStyle(
                              color: AppTheme.texteSecondaire,
                              fontFamilyFallback: AppTheme.famillesSecours,
                            ),
                          ),
                        ),
                      );
                    }
                    final pays = filtres[index];
                    return _LignePays(
                      pays: pays,
                      selectionne: pays.identifiant == widget.identifiant,
                      onTap: () => Navigator.of(context).pop(pays),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LignePays extends StatelessWidget {
  final Pays pays;
  final bool selectionne;
  final VoidCallback onTap;

  const _LignePays({
    required this.pays,
    required this.selectionne,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final drapeau = pays.map;
    return Material(
      color: selectionne ? AppTheme.sable : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              if (drapeau != null && drapeau.isNotEmpty) ...[
                Text(drapeau, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  pays.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    fontFamilyFallback: AppTheme.famillesSecours,
                  ),
                ),
              ),
              Text(
                pays.callingCodes,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.texteSecondaire,
                  fontFamilyFallback: AppTheme.famillesSecours,
                ),
              ),
              if (selectionne) ...[
                const SizedBox(width: 6),
                const Icon(Icons.check, size: 18, color: AppTheme.navy),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chiffres seuls, plafonnés à la longueur de l'indicatif choisi.
List<TextInputFormatter> formateursNumero(int maximum) => [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(maximum),
    ];
