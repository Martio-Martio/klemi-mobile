import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Configuration/api_url.dart';
import '../Data/mock_feed.dart';
import '../Models/feed_item.dart';
import '../Services/api_exception.dart';
import '../Services/mobile_feed_api.dart';

/// Limite d'items persistés par tab (plan Phase 7).
const int kCacheMaxItems = 20;

/// État d'un onglet du feed : items chargés, curseur, drapeaux UI.
class EtatFeed {
  final List<FeedItem> items;
  final String? curseurSuivant;
  final bool enChargement;
  final ApiException? erreur;
  final bool fini;

  const EtatFeed({
    this.items = const [],
    this.curseurSuivant,
    this.enChargement = false,
    this.erreur,
    this.fini = false,
  });

  bool get estVide => items.isEmpty && !enChargement && erreur == null;

  EtatFeed copier({
    List<FeedItem>? items,
    String? curseurSuivant,
    bool? enChargement,
    ApiException? erreur,
    bool? fini,
    bool viderErreur = false,
    bool viderCurseur = false,
  }) {
    return EtatFeed(
      items: items ?? this.items,
      curseurSuivant: viderCurseur ? null : (curseurSuivant ?? this.curseurSuivant),
      enChargement: enChargement ?? this.enChargement,
      erreur: viderErreur ? null : (erreur ?? this.erreur),
      fini: fini ?? this.fini,
    );
  }
}

/// Garde en cache les pages chargées par tab. Doit être invalidé quand la
/// langue de lecture ou d'écoute change — l'appelant (`FeedPage`) écoute
/// `AppState` et appelle [invaliderPour] en conséquence.
///
/// Singleton via [FeedRepository.instance] — la plupart des pages du feed
/// partagent le même cache. Pour les tests, instancier directement.
class FeedRepository extends ChangeNotifier {
  final MobileFeedApi _api;
  final bool _utiliserMock;

  final Map<TabFeed, EtatFeed> _etats = {};

  FeedRepository({MobileFeedApi? api, bool? utiliserMock})
      : _api = api ?? MobileFeedApi(),
        _utiliserMock = utiliserMock ?? ApiUrl.useMock;

  static FeedRepository? _instance;
  static FeedRepository get instance => _instance ??= FeedRepository();
  static void brancher(FeedRepository repo) => _instance = repo;

  EtatFeed etat(TabFeed tab) => _etats[tab] ?? const EtatFeed();

  /// Charge la première page si pas encore fait. Idempotent — si l'onglet a
  /// déjà des items, retourne l'état existant.
  Future<EtatFeed> amorcer(TabFeed tab, {String? lang, String? langAudio}) async {
    final courant = etat(tab);
    if (courant.items.isNotEmpty || courant.enChargement) return courant;
    return _chargerPage(tab, cursor: null, lang: lang, langAudio: langAudio, rafraichir: false);
  }

  /// Vide l'état et recharge depuis le début (pull-to-refresh).
  Future<EtatFeed> rafraichir(TabFeed tab, {String? lang, String? langAudio}) async {
    _etats[tab] = const EtatFeed();
    return _chargerPage(tab, cursor: null, lang: lang, langAudio: langAudio, rafraichir: true);
  }

  /// Charge la page suivante si le curseur existe et qu'il n'y a pas déjà un
  /// chargement en cours. No-op sinon.
  Future<EtatFeed> pageSuivante(TabFeed tab, {String? lang, String? langAudio}) async {
    final courant = etat(tab);
    if (courant.enChargement || courant.fini || courant.curseurSuivant == null) {
      return courant;
    }
    return _chargerPage(
      tab,
      cursor: courant.curseurSuivant,
      lang: lang,
      langAudio: langAudio,
      rafraichir: false,
    );
  }

  /// Garantit qu'un contenu précis est présent en tête du cache `pourToi`.
  /// Utilisé par le deep-link push : au tap sur une notif, on doit pouvoir
  /// afficher l'item même s'il n'était pas déjà chargé par scroll.
  ///
  /// Idempotent : si l'item est déjà dans le cache, aucun appel réseau.
  /// Retourne l'item résolu, ou `null` en cas d'échec (erreur réseau,
  /// contenu supprimé…).
  Future<FeedItem?> assurerContenu(String id) async {
    for (final etat in _etats.values) {
      for (final item in etat.items) {
        if (item.id == id) return item;
      }
    }
    try {
      final item = await _api.fetchOne(id);
      final etatPourToi = etat(TabFeed.pourToi);
      _etats[TabFeed.pourToi] = etatPourToi.copier(
        items: [item, ...etatPourToi.items],
      );
      notifyListeners();
      return item;
    } on ApiException {
      return null;
    }
  }

  /// Invalide le cache pour tous les onglets — à appeler quand la langue
  /// de lecture ou d'écoute change.
  void invaliderTout() {
    _etats.clear();
    notifyListeners();
  }

  /// Variante ciblée (pour debug ou tests).
  void invaliderPour(TabFeed tab) {
    _etats.remove(tab);
    notifyListeners();
  }

  Future<EtatFeed> _chargerPage(
    TabFeed tab, {
    required String? cursor,
    required String? lang,
    required String? langAudio,
    required bool rafraichir,
  }) async {
    _etats[tab] = etat(tab).copier(enChargement: true, viderErreur: true);
    notifyListeners();

    try {
      final PageFeed page = _utiliserMock
          ? _pageMock(tab)
          : await _api.fetchFeed(
              tab: tab,
              cursor: cursor,
              lang: lang,
              langAudio: langAudio,
            );
      final itemsCourants = rafraichir ? <FeedItem>[] : etat(tab).items;
      _etats[tab] = EtatFeed(
        items: [...itemsCourants, ...page.items],
        curseurSuivant: page.curseurSuivant,
        enChargement: false,
        fini: !page.aPageSuivante,
      );
    } on ApiException catch (e) {
      // Si c'est le chargement initial (pas de curseur) et qu'on n'a rien
      // en mémoire, on tente de servir le cache persisté avant d'afficher
      // une erreur.
      if (cursor == null && etat(tab).items.isEmpty) {
        final cache = await _lireCache(tab);
        if (cache.isNotEmpty) {
          _etats[tab] = EtatFeed(
            items: cache,
            enChargement: false,
            fini: true,
            erreur: e,
          );
          notifyListeners();
          return etat(tab);
        }
      }
      _etats[tab] = etat(tab).copier(enChargement: false, erreur: e);
    }
    // Persister les N derniers items pour le prochain boot offline.
    unawaited(_ecrireCache(tab, etat(tab).items));
    notifyListeners();
    return etat(tab);
  }

  // ─── Cache offline (Phase 7) ───────────────────────────────────────────

  static String _cleCache(TabFeed tab) => 'feedCache_${tab.cle}_v1';

  Future<void> _ecrireCache(TabFeed tab, List<FeedItem> items) async {
    if (items.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final atLimite = items.take(kCacheMaxItems).toList();
      final brut = jsonEncode(atLimite.map(feedItemVersJson).toList());
      await prefs.setString(_cleCache(tab), brut);
    } catch (_) {
      // Pas critique — le cache est best-effort.
    }
  }

  Future<List<FeedItem>> _lireCache(TabFeed tab) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_cleCache(tab));
      if (brut == null || brut.isEmpty) return const [];
      final liste = jsonDecode(brut) as List;
      return liste.cast<Map<String, dynamic>>().map(feedItemDepuisJson).toList();
    } catch (_) {
      return const [];
    }
  }

  PageFeed _pageMock(TabFeed tab) {
    // Mode mock : sert toujours la même liste, pagination infinie désactivée.
    return PageFeed(items: List.of(feedDemo), curseurSuivant: null);
  }
}
