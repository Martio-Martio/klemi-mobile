import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../Configuration/app_theme.dart';
import '../../Configuration/langues.dart';
import '../../Providers/app_state.dart';
import '../../Widgets/klemi_widgets.dart';
import '../Social/notifications_page.dart';
import 'forfaits_page.dart';
import 'parametres_page.dart';

/// 3.2 · Profil + bibliothèque (contenus gardés, hors ligne, certificats).
class ProfilPage extends StatefulWidget {
  final bool ouvrirBiblio; // onglet « Biblio » de la barre : scroll vers la bibliothèque
  const ProfilPage({super.key, this.ouvrirBiblio = false});

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  int _filtre = 0; // 0 tout, 1 hors ligne

  @override
  Widget build(BuildContext context) {
    final etat = context.watch<AppState>();
    final items = _biblio.where((e) => _filtre == 0 || e.horsLigne).toList();

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
                Text(widget.ouvrirBiblio ? 'Ma bibliothèque' : 'Mon espace',
                    style: Theme.of(context).textTheme.titleLarge),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Notifications',
                      onPressed: () =>
                          Navigator.of(context).push(routeGlissante(const NotificationsPage())),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.blanc,
                        side: const BorderSide(color: AppTheme.bordure),
                      ),
                      icon: const Badge(
                        label: Text('2'),
                        backgroundColor: AppTheme.rougeFonce,
                        child: Icon(Icons.notifications_none, color: AppTheme.navy),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Paramètres',
                      onPressed: () =>
                          Navigator.of(context).push(routeGlissante(const ParametresPage())),
                      style: IconButton.styleFrom(
                        backgroundColor: AppTheme.blanc,
                        side: const BorderSide(color: AppTheme.bordure),
                      ),
                      icon: const Icon(Icons.settings_outlined, color: AppTheme.navy),
                    ),
                  ],
                ),
              ],
            ),
            if (!widget.ouvrirBiblio) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Avatar(initiales: 'AT', couleur: AppTheme.bleu, taille: 64),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Aminata Traoré',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const Text('3e · Lycée Askia, Bamako',
                            style: TextStyle(fontSize: 13, color: AppTheme.texteSecondaire)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          children: [
                            for (final l in languesDisponibles.take(3))
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: l.id == etat.langue.id ? AppTheme.bleu : AppTheme.blanc,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                      color: l.id == etat.langue.id ? AppTheme.bleu : AppTheme.bordure),
                                ),
                                child: Text(l.code,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _Stat('${etat.serieJours} j', 'série en cours')),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat('${etat.points}', 'points')),
                  const SizedBox(width: 10),
                  const Expanded(child: _Stat('3', 'certificats')),
                ],
              ),
              const SizedBox(height: 12),
              CarteBlanche(
                couleurBordure: AppTheme.bleu,
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Klemi ${etat.forfait}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          Text("${etat.generationsRestantes} générations IA restantes aujourd'hui",
                              style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).push(routeGlissante(const ForfaitsPage())),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.bleu,
                        foregroundColor: AppTheme.navy,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Voir les forfaits',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ma bibliothèque',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  _filtres(),
                ],
              ),
            ] else ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: _filtres()),
            ],
            const SizedBox(height: 10),
            for (final e in items) ...[
              _LigneBiblio(e),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filtres() {
    Widget chip(String l, int i) => ChoiceChip(
          label: Text(l),
          selected: _filtre == i,
          onSelected: (_) => setState(() => _filtre = i),
          selectedColor: AppTheme.bleu,
          backgroundColor: AppTheme.blanc,
          showCheckmark: false,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.navy),
          side: BorderSide(color: _filtre == i ? AppTheme.bleu : AppTheme.bordure),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          visualDensity: VisualDensity.compact,
        );
    return Wrap(spacing: 6, children: [chip('Tout', 0), chip('Hors ligne', 1)]);
  }
}

class _ElementBiblio {
  final String titre;
  final String detail;
  final IconData icone;
  final Color couleur;
  final bool horsLigne;
  final String? badge;
  const _ElementBiblio(this.titre, this.detail, this.icone, this.couleur,
      {this.horsLigne = false, this.badge});
}

const _biblio = [
  _ElementBiblio('Les grands empires du Sahel', 'Quiz · 10 questions · 8/10 · FR',
      Icons.help_outline, AppTheme.orange, horsLigne: true),
  _ElementBiblio('Kankou Moussa et Tombouctou', 'Fiche · 3 min · FR · BM',
      Icons.description_outlined, AppTheme.vert, horsLigne: true),
  _ElementBiblio('Mali mansaya : Kankou Musa ni Tumutu', 'Podcast · 12 min · BM · 03:12',
      Icons.mic_none, AppTheme.bleu, badge: '6,4 Mo'),
  _ElementBiblio('Certificat · Histoire 3e, trimestre 1', 'Délivré par Lycée Askia · PDF',
      Icons.workspace_premium_outlined, AppTheme.blanc),
];

class _LigneBiblio extends StatelessWidget {
  final _ElementBiblio e;
  const _LigneBiblio(this.e);

  @override
  Widget build(BuildContext context) {
    return CarteBlanche(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: e.couleur,
              borderRadius: BorderRadius.circular(12),
              border: e.couleur == AppTheme.blanc ? Border.all(color: AppTheme.bordure) : null,
            ),
            child: Icon(e.icone, size: 20, color: AppTheme.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.titre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                Text(e.detail, style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
              ],
            ),
          ),
          if (e.horsLigne)
            const Text('Hors ligne',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.vertFonce))
          else if (e.badge != null)
            Text(e.badge!,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.texteDiscret)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String valeur;
  final String libelle;
  const _Stat(this.valeur, this.libelle);

  @override
  Widget build(BuildContext context) {
    return CarteBlanche(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(valeur, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(libelle, style: const TextStyle(fontSize: 12, color: AppTheme.texteSecondaire)),
        ],
      ),
    );
  }
}
