import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Providers/app_state.dart';
import '../Services/api_exception.dart';
import '../Services/profile_api.dart';

/// Orchestre le chargement et la MAJ du profil depuis l'API backend. Les
/// pages `Profil` et `Paramètres` observent ce repository ; `AppState` reste
/// le miroir local reflété dans l'UI.
///
/// Singleton via [ProfileRepository.instance] — un même utilisateur a un
/// seul profil courant. Pour les tests on construit une instance dédiée.
class ProfileRepository extends ChangeNotifier {
  static const _cleDernierPing = 'derniereDatePingStreak';

  final ProfileApi _api;

  bool _enChargement = false;
  ApiException? _derniereErreur;

  ProfileRepository({ProfileApi? api}) : _api = api ?? ProfileApi();

  static ProfileRepository? _instance;
  static ProfileRepository get instance => _instance ??= ProfileRepository();
  static void brancher(ProfileRepository repo) => _instance = repo;

  bool get enChargement => _enChargement;
  ApiException? get derniereErreur => _derniereErreur;

  /// Charge `/mobile/me` et pousse le résultat dans [etat]. Silencieux en cas
  /// d'erreur réseau : les valeurs locales de l'AppState restent valides, la
  /// prochaine tentative sera déclenchée par un autre appel (pull-to-refresh
  /// futur, bascule d'onglet…).
  Future<void> charger(AppState etat) async {
    if (_enChargement) return;
    _enChargement = true;
    _derniereErreur = null;
    notifyListeners();
    try {
      final profil = await _api.chargerProfil();
      etat.definirDepuisProfil(profil);
    } on ApiException catch (e) {
      _derniereErreur = e;
    } finally {
      _enChargement = false;
      notifyListeners();
    }
  }

  /// Récupère uniquement le quota IA — appelé par `CreerPage` après chaque
  /// génération réussie (plan Phase 3).
  Future<void> rafraichirQuota(AppState etat) async {
    try {
      final quota = await _api.chargerQuota();
      etat.definirQuota(quota);
    } on ApiException catch (_) {
      // best-effort — ne bloque pas l'UX si le quota n'est pas joignable.
    }
  }

  /// Ping idempotent : incrémente `serieJours` côté serveur la première fois
  /// de la journée. On vérifie côté client la date du dernier ping pour
  /// éviter N appels par app launch.
  Future<void> pingStreakSiNecessaire() async {
    final prefs = await SharedPreferences.getInstance();
    final dernier = prefs.getString(_cleDernierPing);
    final aujourdhui = _datePure(DateTime.now()).toIso8601String();
    if (dernier == aujourdhui) return;
    try {
      await _api.pingStreak();
      await prefs.setString(_cleDernierPing, aujourdhui);
    } on ApiException catch (_) {
      // réessaiera au prochain launch.
    }
  }

  /// MAJ d'une préférence : met à jour l'état local immédiatement (UX
  /// réactive), puis envoie le PATCH ; en cas d'échec, rollback.
  ///
  /// [patch] = partial map (ex. `{'notifStreak': false}`).
  /// [appliquerLocal] applique le changement sur `AppState` ; [rollbackLocal]
  /// annule le même changement si l'appel API échoue.
  Future<bool> mettreAJourPreference({
    required Map<String, dynamic> patch,
    required VoidCallback appliquerLocal,
    required VoidCallback rollbackLocal,
  }) async {
    appliquerLocal();
    try {
      await _api.mettreAJourPreferences(patch);
      return true;
    } on ApiException catch (_) {
      rollbackLocal();
      return false;
    }
  }

  /// Patch profil (nom, classe, établissement, langue, langueAudio, niveauEtudes).
  /// Même pattern optimiste que [mettreAJourPreference].
  Future<bool> mettreAJourProfil(Map<String, dynamic> patch) async {
    try {
      await _api.mettreAJourProfil(patch);
      return true;
    } on ApiException catch (e) {
      _derniereErreur = e;
      notifyListeners();
      return false;
    }
  }

  DateTime _datePure(DateTime dt) => DateTime(dt.year, dt.month, dt.day);
}
