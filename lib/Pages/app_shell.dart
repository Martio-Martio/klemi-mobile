import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../Models/social.dart';
import '../Providers/app_state.dart';
import '../Repositories/feed_repository.dart';
import '../Services/push_router.dart';
import '../Widgets/barre_navigation.dart';
import 'Creer/creer_page.dart';
import 'Explorer/explorer_page.dart';
import 'Feed/feed_page.dart';
import 'Profil/profil_page.dart';
import 'Social/commentaires_sheet.dart';

/// Coque de l'application connectée : barre du bas à 5 onglets.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  OngletApp _onglet = OngletApp.feed;
  final _ouverture = ValueNotifier<ContenuResume?>(null);
  AppState? _etatEcoute;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final etat = context.read<AppState>();
    // On ne s'abonne qu'une seule fois — Provider peut rappeler plusieurs
    // fois le didChangeDependencies selon le cycle des parents.
    if (_etatEcoute != etat) {
      _etatEcoute?.intentPush.removeListener(_consommerIntent);
      _etatEcoute = etat;
      etat.intentPush.addListener(_consommerIntent);
      // Si un intent a été posé avant notre abonnement (cold start), on le
      // traite maintenant.
      if (etat.intentPush.value != null) _consommerIntent();
    }
  }

  @override
  void dispose() {
    _etatEcoute?.intentPush.removeListener(_consommerIntent);
    _ouverture.dispose();
    super.dispose();
  }

  /// Traite un intent de deep-link push posé par `MyApp._surMessageTappe`.
  Future<void> _consommerIntent() async {
    final etat = _etatEcoute;
    if (etat == null) return;
    final decision = etat.intentPush.value;
    if (decision == null) return;
    etat.intentPush.value = null; // consomme AVANT l'appel async pour éviter la double-exécution

    final id = decision.contentId;
    if (id == null) return;

    // 1) Switch sur l'onglet feed pour que l'utilisateur voie bien l'item.
    if (mounted) setState(() => _onglet = OngletApp.feed);

    // 2) Assure la présence de l'item dans le cache du feed. Retourne
    // null si l'API échoue ou si le contenu a été supprimé — on arrête
    // alors proprement sans crasher.
    final item = await FeedRepository.instance.assurerContenu(id);
    if (!mounted || item == null) return;

    // 3) Déclenche le scroll vers l'item depuis `FeedPage.ouvrir`. On utilise
    // un `ContenuResume` minimal construit depuis le FeedItem — le champ
    // `titre` est le pivot utilisé par `FeedPage.ouvrir.indexWhere`.
    _ouverture.value = ContenuResume(
      id: item.id,
      type: item.type,
      titre: item.titre,
      meta: '',
      createurId: decision.creatorId ?? '',
      publieLe: DateTime.now(),
    );

    // 4) Si la destination demande les commentaires, ouvrir la sheet
    // par-dessus. On passe `contentId` pour que `commentaires_sheet` fetch
    // les vrais commentaires.
    if (decision.destination == DestinationPush.commentaires) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ouvrirCommentaires(context, titre: item.titre, contentId: id);
      });
    }
  }

  /// Ouvre un contenu dans le feed depuis un autre onglet (Explorer…).
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
