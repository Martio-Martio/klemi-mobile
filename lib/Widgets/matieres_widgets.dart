import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Configuration/app_theme.dart';
import '../Configuration/matieres.dart';
import '../Providers/app_state.dart';

/// Sélecteur de niveau d'études (chips horizontaux).
class SelecteurNiveau extends StatelessWidget {
  final NiveauEtudes valeur;
  final ValueChanged<NiveauEtudes> onChanged;
  const SelecteurNiveau({super.key, required this.valeur, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final n in NiveauEtudes.values) ...[
            ChoiceChip(
              label: Text(n.libelle),
              selected: n == valeur,
              onSelected: (_) => onChanged(n),
              selectedColor: AppTheme.navy,
              backgroundColor: AppTheme.blanc,
              showCheckmark: false,
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: n == valeur ? AppTheme.blanc : AppTheme.navy,
              ),
              side: BorderSide(color: n == valeur ? AppTheme.navy : AppTheme.bordure),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Liste des matières de l'utilisateur, modifiable (retirer / ajouter).
class MatieresEditables extends StatelessWidget {
  final bool compact;
  const MatieresEditables({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final etat = context.watch<AppState>();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in etat.matieres)
          InputChip(
            label: Text(m),
            onDeleted: () => context.read<AppState>().retirerMatiere(m),
            deleteIconColor: AppTheme.texteDiscret,
            backgroundColor: AppTheme.blanc,
            side: const BorderSide(color: AppTheme.bordure),
            labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navy),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 16, color: AppTheme.navy),
          label: const Text('Ajouter'),
          onPressed: () => ouvrirAjoutMatiere(context),
          backgroundColor: AppTheme.bleuClair,
          side: const BorderSide(color: AppTheme.bleu),
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.navy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
        ),
      ],
    );
  }
}

/// Feuille « Ajouter une matière » : saisie libre + suggestions.
Future<void> ouvrirAjoutMatiere(BuildContext context) {
  final controleur = TextEditingController();
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.beige,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final etat = ctx.read<AppState>();
      final deja = etat.matieres.map((m) => m.toLowerCase()).toSet();
      final suggestions = [
        ...matieresParDefaut.values.expand((l) => l),
        ...matieresSuggerees,
      ].where((m) => !deja.contains(m.toLowerCase())).toSet().toList();

      void valider(String nom) {
        etat.ajouterMatiere(nom);
        Navigator.of(ctx).pop();
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const Text('Ajouter une matière',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
              'Collège, lycée, université, concours… écris le nom exact de ta matière.',
              style: TextStyle(fontSize: 13, color: AppTheme.texteSecondaire),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controleur,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: valider,
                    decoration: const InputDecoration(hintText: 'Ex. Droit constitutionnel'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => valider(controleur.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.bleu,
                    foregroundColor: AppTheme.navy,
                    minimumSize: const Size(0, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('Suggestions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in suggestions)
                      ActionChip(
                        label: Text(s),
                        onPressed: () => valider(s),
                        backgroundColor: AppTheme.blanc,
                        side: const BorderSide(color: AppTheme.bordure),
                        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.navy),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
