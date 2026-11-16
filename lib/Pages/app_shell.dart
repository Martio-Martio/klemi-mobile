import 'package:flutter/material.dart';

import '../Models/social.dart';
import '../Widgets/barre_navigation.dart';
import 'Creer/creer_page.dart';
import 'Explorer/explorer_page.dart';
import 'Feed/feed_page.dart';
import 'Profil/profil_page.dart';

/// Coque de l'application connectée : barre du bas à 5 onglets.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  OngletApp _onglet = OngletApp.feed;
  final _ouverture = ValueNotifier<ContenuResume?>(null);

  @override
  void dispose() {
    _ouverture.dispose();
    super.dispose();
  }

  /// Ouvre un contenu dans le feed depuis un autre onglet.
  void _ouvrirDansFeed(ContenuResume c) {
    setState(() => _onglet = OngletApp.feed);
    _ouverture.value = c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _onglet.index,
        children: [
          SafeArea(bottom: false, child: FeedPage(ouverture: _ouverture)),
          ExplorerPage(onOuvrir: _ouvrirDansFeed),
          CreerPage(onGenere: () => setState(() => _onglet = OngletApp.feed)),
          const ProfilPage(ouvrirBiblio: true),
          const ProfilPage(),
        ],
      ),
      bottomNavigationBar: BarreNavigation(
        actif: _onglet,
        onChanged: (o) => setState(() => _onglet = o),
      ),
    );
  }
}
